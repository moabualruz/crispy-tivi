use std::collections::HashMap;

use rusqlite::params;

use super::CrispyService;
use crate::database::DbError;
use crate::insert_or_replace;

// ── Tier constants ──────────────────────────────────

/// Valid tier names in upgrade order.
const TIER_ORDER: &[&str] = &["fast", "normal", "aggressive"];

/// Readahead seconds per tier.
fn tier_readahead(tier: &str) -> i64 {
    match tier {
        "fast" => 60,
        "normal" => 120,
        "aggressive" => 180,
        _ => 120,
    }
}

// ── Thresholds ──────────────────────────────────────

/// Buffer duration below which the stream is considered stressed.
const LOW_BUFFER_THRESHOLD: f64 = 1.5;

/// Buffer duration above which the stream is considered healthy.
const HEALTHY_BUFFER_THRESHOLD: f64 = 4.0;

/// Number of consecutive low-buffer samples before upgrading tier.
const UPGRADE_AFTER_STALL_COUNT: u32 = 3;

/// Number of consecutive healthy samples (at 2s intervals)
/// before downgrading tier. 30 samples × 2s = 60s.
const DOWNGRADE_AFTER_STABLE_COUNT: u32 = 30;

impl CrispyService {
    // ── DB persistence ──────────────────────────────

    /// Look up the persisted tier for a URL hash.
    ///
    /// Returns `None` if no entry exists.
    pub fn get_buffer_tier(&self, url_hash: &str) -> Result<Option<String>, DbError> {
        let conn = self.db.get()?;
        let result = conn.query_row(
            "SELECT tier FROM db_buffer_tiers WHERE url_hash = ?1",
            params![url_hash],
            |row| row.get(0),
        );
        match result {
            Ok(tier) => Ok(Some(tier)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(DbError::Sqlite(e)),
        }
    }

    /// Upsert a tier for a URL hash.
    pub fn set_buffer_tier(&self, url_hash: &str, tier: &str) -> Result<(), DbError> {
        let conn = self.db.get()?;
        let now = chrono::Utc::now().timestamp();
        insert_or_replace!(
            conn,
            "db_buffer_tiers",
            ["url_hash", "tier", "updated_at"],
            params![url_hash, tier, now],
        )?;
        Ok(())
    }

    /// Keep only the newest `max_entries` rows, deleting
    /// the oldest by `updated_at` (LRU eviction).
    pub fn prune_buffer_tiers(&self, max_entries: i64) -> Result<usize, DbError> {
        let conn = self.db.get()?;
        let deleted = conn.execute(
            "DELETE FROM db_buffer_tiers WHERE url_hash NOT IN \
             (SELECT url_hash FROM db_buffer_tiers ORDER BY updated_at DESC LIMIT ?1)",
            params![max_entries],
        )?;
        Ok(deleted)
    }

    /// Core tier decision algorithm.
    ///
    /// Accepts a raw buffer health sample and updates
    /// in-memory counters. Returns a JSON string:
    /// `{"tier":"normal","changed":false,"readahead_secs":120}`
    ///
    /// `state_map` is the mutable in-memory map held by
    /// the caller (the FFI layer stores it alongside the
    /// `OnceLock<Mutex<CrispyService>>`).
    pub fn evaluate_buffer_sample(
        &self,
        url_hash: &str,
        cache_duration_secs: f64,
        state_map: &mut HashMap<String, (u32, u32)>,
    ) -> Result<String, DbError> {
        // Load or init in-memory state.
        let (low_count, healthy_count) = state_map.entry(url_hash.to_string()).or_insert((0, 0));

        // Load current persisted tier.
        let current_tier = self
            .get_buffer_tier(url_hash)?
            .unwrap_or_else(|| "normal".to_string());

        let mut tier = current_tier.clone();
        let mut changed = false;

        if cache_duration_secs < LOW_BUFFER_THRESHOLD {
            *low_count += 1;
            *healthy_count = 0;

            if *low_count >= UPGRADE_AFTER_STALL_COUNT {
                if let Some(upgraded) = upgrade_tier(&tier) {
                    tier = upgraded;
                    changed = true;
                    self.set_buffer_tier(url_hash, &tier)?;
                }
                *low_count = 0;
            }
        } else if cache_duration_secs > HEALTHY_BUFFER_THRESHOLD {
            *healthy_count += 1;
            // Gradually decay stall count during healthy periods.
            if *low_count > 0 {
                *low_count -= 1;
            }

            if *healthy_count >= DOWNGRADE_AFTER_STABLE_COUNT {
                if let Some(downgraded) = downgrade_tier(&tier) {
                    tier = downgraded;
                    changed = true;
                    self.set_buffer_tier(url_hash, &tier)?;
                }
                *healthy_count = 0;
            }
        } else {
            // Middle zone — reset both counters.
            *low_count = 0;
            *healthy_count = 0;
        }

        let readahead = tier_readahead(&tier);
        Ok(format!(
            r#"{{"tier":"{}","changed":{},"readahead_secs":{}}}"#,
            tier, changed, readahead,
        ))
    }

    /// Reset in-memory counters for a URL (on channel change).
    pub fn reset_buffer_state(url_hash: &str, state_map: &mut HashMap<String, (u32, u32)>) {
        state_map.remove(url_hash);
    }

    /// Android heap-adaptive buffer cap.
    ///
    /// Returns maximum forward buffer in MB based on
    /// the device's max heap size.
    pub fn get_buffer_cap_mb(heap_max_mb: i64) -> i64 {
        if heap_max_mb <= 256 {
            32
        } else if heap_max_mb <= 512 {
            64
        } else {
            100
        }
    }
}

/// Move one tier up (more aggressive). Returns `None` at ceiling.
fn upgrade_tier(current: &str) -> Option<String> {
    let idx = TIER_ORDER.iter().position(|&t| t == current)?;
    if idx < TIER_ORDER.len() - 1 {
        Some(TIER_ORDER[idx + 1].to_string())
    } else {
        None
    }
}

/// Move one tier down (less aggressive). Returns `None` at floor.
fn downgrade_tier(current: &str) -> Option<String> {
    let idx = TIER_ORDER.iter().position(|&t| t == current)?;
    if idx > 0 {
        Some(TIER_ORDER[idx - 1].to_string())
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::services::test_helpers::*;

    #[test]
    fn get_missing_tier_returns_none() {
        let svc = make_service();
        assert_eq!(svc.get_buffer_tier("abc123").unwrap(), None);
    }

    #[test]
    fn set_and_get_tier() {
        let svc = make_service();
        svc.set_buffer_tier("abc123", "aggressive").unwrap();
        assert_eq!(
            svc.get_buffer_tier("abc123").unwrap(),
            Some("aggressive".to_string()),
        );
    }

    #[test]
    fn upsert_overwrites_tier() {
        let svc = make_service();
        svc.set_buffer_tier("abc123", "fast").unwrap();
        svc.set_buffer_tier("abc123", "normal").unwrap();
        assert_eq!(
            svc.get_buffer_tier("abc123").unwrap(),
            Some("normal".to_string()),
        );
    }

    #[test]
    fn prune_keeps_max_entries() {
        let svc = make_service();
        for i in 0..10 {
            svc.set_buffer_tier(&format!("url_{i}"), "normal").unwrap();
            // Ensure distinct updated_at by sleeping briefly isn't
            // needed — SQLite timestamp resolution is 1s and our
            // inserts happen in the same second. Use explicit
            // timestamps instead.
            let conn = svc.db.get().unwrap();
            conn.execute(
                "UPDATE db_buffer_tiers SET updated_at = ?1 WHERE url_hash = ?2",
                params![1000 + i, format!("url_{i}")],
            )
            .unwrap();
        }
        let deleted = svc.prune_buffer_tiers(5).unwrap();
        assert_eq!(deleted, 5);
        // The 5 newest (url_5..url_9) should remain.
        assert!(svc.get_buffer_tier("url_9").unwrap().is_some());
        assert!(svc.get_buffer_tier("url_0").unwrap().is_none());
    }

    #[test]
    fn prune_noop_when_under_limit() {
        let svc = make_service();
        svc.set_buffer_tier("url_a", "fast").unwrap();
        let deleted = svc.prune_buffer_tiers(200).unwrap();
        assert_eq!(deleted, 0);
    }

    #[test]
    fn evaluate_upgrades_after_3_low_samples() {
        let svc = make_service();
        let mut state = HashMap::new();

        // Start at normal (default).
        let r1 = svc.evaluate_buffer_sample("u1", 1.0, &mut state).unwrap();
        assert!(r1.contains(r#""changed":false"#));

        let r2 = svc.evaluate_buffer_sample("u1", 1.0, &mut state).unwrap();
        assert!(r2.contains(r#""changed":false"#));

        // 3rd low sample triggers upgrade to aggressive.
        let r3 = svc.evaluate_buffer_sample("u1", 1.0, &mut state).unwrap();
        assert!(r3.contains(r#""changed":true"#));
        assert!(r3.contains(r#""tier":"aggressive""#));
        assert!(r3.contains(r#""readahead_secs":180"#));

        // Persisted.
        assert_eq!(
            svc.get_buffer_tier("u1").unwrap(),
            Some("aggressive".to_string()),
        );
    }

    #[test]
    fn evaluate_downgrades_after_30_healthy_samples() {
        let svc = make_service();
        svc.set_buffer_tier("u2", "aggressive").unwrap();
        let mut state = HashMap::new();

        // 29 healthy samples — no change.
        for _ in 0..29 {
            let r = svc.evaluate_buffer_sample("u2", 5.0, &mut state).unwrap();
            assert!(r.contains(r#""changed":false"#));
        }

        // 30th healthy sample triggers downgrade.
        let r = svc.evaluate_buffer_sample("u2", 5.0, &mut state).unwrap();
        assert!(r.contains(r#""changed":true"#));
        assert!(r.contains(r#""tier":"normal""#));
    }

    #[test]
    fn no_upgrade_past_aggressive() {
        let svc = make_service();
        svc.set_buffer_tier("u3", "aggressive").unwrap();
        let mut state = HashMap::new();

        for _ in 0..10 {
            let r = svc.evaluate_buffer_sample("u3", 0.5, &mut state).unwrap();
            // Stays at aggressive — no change possible.
            assert!(r.contains(r#""tier":"aggressive""#));
        }
    }

    #[test]
    fn no_downgrade_past_fast() {
        let svc = make_service();
        svc.set_buffer_tier("u4", "fast").unwrap();
        let mut state = HashMap::new();

        for _ in 0..60 {
            let r = svc.evaluate_buffer_sample("u4", 10.0, &mut state).unwrap();
            assert!(r.contains(r#""tier":"fast""#));
        }
    }

    #[test]
    fn middle_zone_resets_counters() {
        let svc = make_service();
        let mut state = HashMap::new();

        // Two low samples.
        svc.evaluate_buffer_sample("u5", 1.0, &mut state).unwrap();
        svc.evaluate_buffer_sample("u5", 1.0, &mut state).unwrap();

        // One middle sample resets the streak.
        svc.evaluate_buffer_sample("u5", 3.0, &mut state).unwrap();

        // Need 3 more low samples to trigger upgrade (not 1).
        let r = svc.evaluate_buffer_sample("u5", 1.0, &mut state).unwrap();
        assert!(r.contains(r#""changed":false"#));
        svc.evaluate_buffer_sample("u5", 1.0, &mut state).unwrap();
        let r3 = svc.evaluate_buffer_sample("u5", 1.0, &mut state).unwrap();
        assert!(r3.contains(r#""changed":true"#));
    }

    #[test]
    fn reset_buffer_state_clears_counters() {
        let mut state = HashMap::new();
        state.insert("u6".to_string(), (5, 10));
        CrispyService::reset_buffer_state("u6", &mut state);
        assert!(!state.contains_key("u6"));
    }

    #[test]
    fn get_buffer_cap_mb_heap_tiers() {
        assert_eq!(CrispyService::get_buffer_cap_mb(128), 32);
        assert_eq!(CrispyService::get_buffer_cap_mb(256), 32);
        assert_eq!(CrispyService::get_buffer_cap_mb(384), 64);
        assert_eq!(CrispyService::get_buffer_cap_mb(512), 64);
        assert_eq!(CrispyService::get_buffer_cap_mb(1024), 100);
    }

    #[test]
    fn upgrade_and_downgrade_tier_functions() {
        assert_eq!(upgrade_tier("fast"), Some("normal".to_string()));
        assert_eq!(upgrade_tier("normal"), Some("aggressive".to_string()));
        assert_eq!(upgrade_tier("aggressive"), None);

        assert_eq!(downgrade_tier("aggressive"), Some("normal".to_string()));
        assert_eq!(downgrade_tier("normal"), Some("fast".to_string()));
        assert_eq!(downgrade_tier("fast"), None);
    }

    #[test]
    fn unknown_tier_returns_default_readahead() {
        assert_eq!(tier_readahead("unknown"), 120);
    }
}
