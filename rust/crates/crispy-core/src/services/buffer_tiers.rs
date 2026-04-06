use std::collections::HashMap;

use rusqlite::params;

use super::ServiceContext;
use crate::database::{optional, DbError};
use crate::insert_or_replace;
use crate::models::BufferTierDecision;

// BufferTierDecision and its evaluate() method live in models/mod.rs (domain layer).

/// Domain service for buffer tier operations.
pub struct BufferTierService(pub ServiceContext);

impl BufferTierService {
    // ── DB persistence ──────────────────────────────

    /// Look up the persisted tier for a URL hash.
    ///
    /// Returns `None` if no entry exists.
    pub fn get_buffer_tier(&self, url_hash: &str) -> Result<Option<String>, DbError> {
        let conn = self.0.db.get()?;
        let result = conn.query_row(
            "SELECT tier FROM db_buffer_tiers WHERE url_hash = ?1",
            params![url_hash],
            |row| row.get(0),
        );
        optional(result)
    }

    /// Upsert a tier for a URL hash.
    pub fn set_buffer_tier(&self, url_hash: &str, tier: &str) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
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
        let conn = self.0.db.get()?;
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

        // Delegate pure tier logic to the domain value object.
        let decision = BufferTierDecision::evaluate(
            &current_tier,
            cache_duration_secs,
            low_count,
            healthy_count,
        );

        // Persist the new tier only when it changed.
        if decision.changed {
            self.set_buffer_tier(url_hash, &decision.tier)?;
        }

        Ok(format!(
            r#"{{"tier":"{}","changed":{},"readahead_secs":{}}}"#,
            decision.tier, decision.changed, decision.readahead_secs,
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


#[cfg(test)]
mod tests {
    use super::*;
    use crate::services::test_helpers::*;
    use super::BufferTierService;

    #[test]
    fn get_missing_tier_returns_none() {
        let svc = BufferTierService(make_service());
        assert_eq!(svc.get_buffer_tier("abc123").unwrap(), None);
    }

    #[test]
    fn set_and_get_tier() {
        let svc = BufferTierService(make_service());
        svc.set_buffer_tier("abc123", "aggressive").unwrap();
        assert_eq!(
            svc.get_buffer_tier("abc123").unwrap(),
            Some("aggressive".to_string()),
        );
    }

    #[test]
    fn upsert_overwrites_tier() {
        let svc = BufferTierService(make_service());
        svc.set_buffer_tier("abc123", "fast").unwrap();
        svc.set_buffer_tier("abc123", "normal").unwrap();
        assert_eq!(
            svc.get_buffer_tier("abc123").unwrap(),
            Some("normal".to_string()),
        );
    }

    #[test]
    fn prune_keeps_max_entries() {
        let svc = BufferTierService(make_service());
        for i in 0..10 {
            svc.set_buffer_tier(&format!("url_{i}"), "normal").unwrap();
            // Ensure distinct updated_at by sleeping briefly isn't
            // needed — SQLite timestamp resolution is 1s and our
            // inserts happen in the same second. Use explicit
            // timestamps instead.
            let conn = svc.0.db.get().unwrap();
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
        let svc = BufferTierService(make_service());
        svc.set_buffer_tier("url_a", "fast").unwrap();
        let deleted = svc.prune_buffer_tiers(200).unwrap();
        assert_eq!(deleted, 0);
    }

    #[test]
    fn evaluate_upgrades_after_3_low_samples() {
        let svc = BufferTierService(make_service());
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
        let svc = BufferTierService(make_service());
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
        let svc = BufferTierService(make_service());
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
        let svc = BufferTierService(make_service());
        svc.set_buffer_tier("u4", "fast").unwrap();
        let mut state = HashMap::new();

        for _ in 0..60 {
            let r = svc.evaluate_buffer_sample("u4", 10.0, &mut state).unwrap();
            assert!(r.contains(r#""tier":"fast""#));
        }
    }

    #[test]
    fn middle_zone_resets_counters() {
        let svc = BufferTierService(make_service());
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
        BufferTierService::reset_buffer_state("u6", &mut state);
        assert!(!state.contains_key("u6"));
    }

    #[test]
    fn get_buffer_cap_mb_heap_tiers() {
        assert_eq!(BufferTierService::get_buffer_cap_mb(128), 32);
        assert_eq!(BufferTierService::get_buffer_cap_mb(256), 32);
        assert_eq!(BufferTierService::get_buffer_cap_mb(384), 64);
        assert_eq!(BufferTierService::get_buffer_cap_mb(512), 64);
        assert_eq!(BufferTierService::get_buffer_cap_mb(1024), 100);
    }

}
