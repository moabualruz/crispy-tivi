use std::collections::HashMap;

use rusqlite::params;

use super::ServiceContext;
use crate::database::{DbError, optional};

// ── Failover thresholds ─────────────────────────────

/// Buffer duration below which a sample counts as "low".
const LOW_BUFFER_THRESHOLD: f64 = 1.0;

/// Buffer duration above which the low counter resets.
const LOW_BUFFER_RESET: f64 = 2.0;

/// Consecutive low-buffer polls before starting warm player.
const WARMING_TRIGGER_COUNT: u32 = 4;

/// Consecutive stall events before swapping to warm player.
const SWAP_TRIGGER_COUNT: u32 = 6;

// ── Health score weights ────────────────────────────

/// Weight for stall component in health score.
const WEIGHT_STALL: f64 = 0.5;

/// Weight for buffer component in health score.
const WEIGHT_BUFFER: f64 = 0.3;

/// Weight for TTFF component in health score.
const WEIGHT_TTFF: f64 = 0.2;

/// Decay half-life in hours (7 days).
const DECAY_HALF_LIFE_HOURS: f64 = 7.0 * 24.0;

/// Maximum TTFF in ms used for normalization.
const MAX_TTFF_MS: f64 = 10000.0;

/// Maximum average buffer duration used for normalization.
const MAX_AVG_BUFFER: f64 = 10.0;

/// Domain service for stream health operations.
pub struct StreamHealthService(pub ServiceContext);

impl StreamHealthService {
    // ── DB persistence ──────────────────────────────

    /// Record a stream stall event for a URL hash.
    ///
    /// Increments `stall_count` and updates `last_seen`.
    /// Creates a new row if none exists.
    pub fn record_stream_stall(&self, url_hash: &str) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        let now = chrono::Utc::now().timestamp();
        conn.execute(
            "INSERT INTO db_stream_health (url_hash, stall_count, buffer_sum, buffer_samples, ttff_ms, last_seen) \
             VALUES (?1, 1, 0, 0, 0, ?2) \
             ON CONFLICT(url_hash) DO UPDATE SET \
             stall_count = stall_count + 1, last_seen = ?2",
            params![url_hash, now],
        )?;
        Ok(())
    }

    /// Record a buffer sample for a URL hash.
    ///
    /// Adds to `buffer_sum`, increments `buffer_samples`,
    /// and updates `last_seen`.
    pub fn record_buffer_sample(
        &self,
        url_hash: &str,
        cache_duration_secs: f64,
    ) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        let now = chrono::Utc::now().timestamp();
        conn.execute(
            "INSERT INTO db_stream_health (url_hash, stall_count, buffer_sum, buffer_samples, ttff_ms, last_seen) \
             VALUES (?1, 0, ?2, 1, 0, ?3) \
             ON CONFLICT(url_hash) DO UPDATE SET \
             buffer_sum = buffer_sum + ?2, buffer_samples = buffer_samples + 1, last_seen = ?3",
            params![url_hash, cache_duration_secs, now],
        )?;
        Ok(())
    }

    /// Record time-to-first-frame for a URL hash.
    ///
    /// Keeps the latest TTFF value (overwrites previous).
    pub fn record_ttff(&self, url_hash: &str, ttff_ms: i64) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        let now = chrono::Utc::now().timestamp();
        conn.execute(
            "INSERT INTO db_stream_health (url_hash, stall_count, buffer_sum, buffer_samples, ttff_ms, last_seen) \
             VALUES (?1, 0, 0, 0, ?2, ?3) \
             ON CONFLICT(url_hash) DO UPDATE SET \
             ttff_ms = ?2, last_seen = ?3",
            params![url_hash, ttff_ms, now],
        )?;
        Ok(())
    }

    /// Compute a health score for a URL hash (0.0–1.0).
    ///
    /// Uses weighted formula with 7-day exponential decay:
    /// - Stall score (50%): `1.0 / (1.0 + stall_count * 0.3)`
    /// - Buffer score (30%): `(avg_buffer / 10.0).clamp(0, 1)`
    /// - TTFF score (20%): `(1.0 - ttff_ms / 10000.0).clamp(0, 1)`
    /// - Decay: `1.0 / (1.0 + age_hours / (7 * 24))`
    ///
    /// Returns 0.5 if no data exists for the URL.
    pub fn get_stream_health_score(&self, url_hash: &str) -> Result<f64, DbError> {
        let conn = self.0.db.get()?;
        let result = conn.query_row(
            "SELECT stall_count, buffer_sum, buffer_samples, ttff_ms, last_seen \
             FROM db_stream_health WHERE url_hash = ?1",
            params![url_hash],
            |row| {
                Ok((
                    row.get::<_, i64>(0)?,
                    row.get::<_, f64>(1)?,
                    row.get::<_, i64>(2)?,
                    row.get::<_, i64>(3)?,
                    row.get::<_, i64>(4)?,
                ))
            },
        );

        Ok(optional(result)?
            .map(
                |(stall_count, buffer_sum, buffer_samples, ttff_ms, last_seen)| {
                    compute_health_score(
                        stall_count,
                        buffer_sum,
                        buffer_samples,
                        ttff_ms,
                        last_seen,
                    )
                },
            )
            .unwrap_or(0.5))
    }

    /// Get health scores for multiple URL hashes.
    ///
    /// Returns a map of url_hash → score. Missing URLs
    /// get a default score of 0.5.
    pub fn get_stream_health_scores(
        &self,
        url_hashes: &[String],
    ) -> Result<HashMap<String, f64>, DbError> {
        let mut scores = HashMap::new();
        for hash in url_hashes {
            scores.insert(hash.clone(), self.get_stream_health_score(hash)?);
        }
        Ok(scores)
    }

    /// Keep only the newest `max_entries` rows, deleting
    /// the oldest by `last_seen` (LRU eviction).
    pub fn prune_stream_health(&self, max_entries: i64) -> Result<usize, DbError> {
        let conn = self.0.db.get()?;
        let deleted = conn.execute(
            "DELETE FROM db_stream_health WHERE url_hash NOT IN \
             (SELECT url_hash FROM db_stream_health ORDER BY last_seen DESC LIMIT ?1)",
            params![max_entries],
        )?;
        Ok(deleted)
    }

    /// Failover threshold decision algorithm.
    ///
    /// Maintains per-URL in-memory counters for low-buffer
    /// and stall events. Returns a JSON action string:
    /// `{"action":"none"|"start_warming"|"swap_warm"|"cold_failover"}`
    ///
    /// `state_map` maps url_hash → (low_buffer_count, stall_count).
    pub fn evaluate_failover_event(
        &self,
        url_hash: &str,
        event_type: &str,
        value: f64,
        state_map: &mut HashMap<String, (u32, u32)>,
    ) -> Result<String, DbError> {
        let (low_count, stall_count) = state_map.entry(url_hash.to_string()).or_insert((0, 0));

        let action = match event_type {
            "buffer" => {
                if value < LOW_BUFFER_THRESHOLD {
                    *low_count += 1;
                    if *low_count >= WARMING_TRIGGER_COUNT {
                        "start_warming"
                    } else {
                        "none"
                    }
                } else if value > LOW_BUFFER_RESET {
                    *low_count = 0;
                    "none"
                } else {
                    "none"
                }
            }
            "stall" => {
                *stall_count += 1;
                if *stall_count >= SWAP_TRIGGER_COUNT {
                    "swap_warm"
                } else {
                    "none"
                }
            }
            _ => "none",
        };

        Ok(format!(r#"{{"action":"{action}"}}"#))
    }

    /// Reset in-memory failover counters for a URL.
    ///
    /// Called on channel change to clear stale state.
    pub fn reset_failover_state(url_hash: &str, state_map: &mut HashMap<String, (u32, u32)>) {
        state_map.remove(url_hash);
    }
}

/// Compute health score from raw metrics.
fn compute_health_score(
    stall_count: i64,
    buffer_sum: f64,
    buffer_samples: i64,
    ttff_ms: i64,
    last_seen: i64,
) -> f64 {
    let now = chrono::Utc::now().timestamp();
    let age_hours = (now - last_seen) as f64 / 3600.0;
    let decay = 1.0 / (1.0 + age_hours / DECAY_HALF_LIFE_HOURS);

    let stall_score = 1.0 / (1.0 + stall_count as f64 * 0.3);

    let buffer_score = if buffer_samples > 0 {
        (buffer_sum / buffer_samples as f64 / MAX_AVG_BUFFER).clamp(0.0, 1.0)
    } else {
        0.5
    };

    let ttff_score = (1.0 - ttff_ms as f64 / MAX_TTFF_MS).clamp(0.0, 1.0);

    decay * (stall_score * WEIGHT_STALL + buffer_score * WEIGHT_BUFFER + ttff_score * WEIGHT_TTFF)
}

#[cfg(test)]
mod tests {
    use super::StreamHealthService;
    use super::*;
    use crate::services::test_helpers::*;

    #[test]
    fn record_stall_creates_entry() {
        let svc = StreamHealthService(make_service());
        svc.record_stream_stall("h1").unwrap();
        let score = svc.get_stream_health_score("h1").unwrap();
        // Fresh entry with 1 stall — score should be slightly below 1.0
        assert!(score > 0.0 && score < 1.0);
    }

    #[test]
    fn record_stall_increments() {
        let svc = StreamHealthService(make_service());
        svc.record_stream_stall("h1").unwrap();
        svc.record_stream_stall("h1").unwrap();
        svc.record_stream_stall("h1").unwrap();

        let conn = svc.0.db.get().unwrap();
        let count: i64 = conn
            .query_row(
                "SELECT stall_count FROM db_stream_health WHERE url_hash = ?1",
                params!["h1"],
                |row| row.get(0),
            )
            .unwrap();
        assert_eq!(count, 3);
    }

    #[test]
    fn record_buffer_sample_accumulates() {
        let svc = StreamHealthService(make_service());
        svc.record_buffer_sample("h2", 5.0).unwrap();
        svc.record_buffer_sample("h2", 3.0).unwrap();

        let conn = svc.0.db.get().unwrap();
        let (sum, samples): (f64, i64) = conn
            .query_row(
                "SELECT buffer_sum, buffer_samples FROM db_stream_health WHERE url_hash = ?1",
                params!["h2"],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )
            .unwrap();
        assert!((sum - 8.0).abs() < 0.001);
        assert_eq!(samples, 2);
    }

    #[test]
    fn record_ttff_overwrites() {
        let svc = StreamHealthService(make_service());
        svc.record_ttff("h3", 1000).unwrap();
        svc.record_ttff("h3", 500).unwrap();

        let conn = svc.0.db.get().unwrap();
        let ttff: i64 = conn
            .query_row(
                "SELECT ttff_ms FROM db_stream_health WHERE url_hash = ?1",
                params!["h3"],
                |row| row.get(0),
            )
            .unwrap();
        assert_eq!(ttff, 500);
    }

    #[test]
    fn missing_url_returns_default_score() {
        let svc = StreamHealthService(make_service());
        let score = svc.get_stream_health_score("nonexistent").unwrap();
        assert!((score - 0.5).abs() < 0.001);
    }

    #[test]
    fn healthy_stream_scores_high() {
        let svc = StreamHealthService(make_service());
        // Lots of good buffer samples, no stalls, fast TTFF
        for _ in 0..20 {
            svc.record_buffer_sample("h4", 8.0).unwrap();
        }
        svc.record_ttff("h4", 200).unwrap();

        let score = svc.get_stream_health_score("h4").unwrap();
        assert!(
            score > 0.7,
            "healthy stream should score > 0.7, got {score}"
        );
    }

    #[test]
    fn unhealthy_stream_scores_low() {
        let svc = StreamHealthService(make_service());
        // Many stalls, low buffer, slow TTFF
        for _ in 0..10 {
            svc.record_stream_stall("h5").unwrap();
            svc.record_buffer_sample("h5", 0.5).unwrap();
        }
        svc.record_ttff("h5", 8000).unwrap();

        let score = svc.get_stream_health_score("h5").unwrap();
        assert!(
            score < 0.4,
            "unhealthy stream should score < 0.4, got {score}"
        );
    }

    #[test]
    fn prune_keeps_max_entries() {
        let svc = StreamHealthService(make_service());
        for i in 0..10 {
            let hash = format!("url_{i}");
            svc.record_stream_stall(&hash).unwrap();
            // Set distinct last_seen timestamps
            let conn = svc.0.db.get().unwrap();
            conn.execute(
                "UPDATE db_stream_health SET last_seen = ?1 WHERE url_hash = ?2",
                params![1000 + i, hash],
            )
            .unwrap();
        }
        let deleted = svc.prune_stream_health(5).unwrap();
        assert_eq!(deleted, 5);
        // Newest 5 (url_5..url_9) remain
        assert!(
            svc.get_stream_health_score("url_9").unwrap() != 0.5,
            "url_9 should exist"
        );
        assert!(
            svc.get_stream_health_score("url_0").unwrap() == 0.5,
            "url_0 should be pruned"
        );
    }

    #[test]
    fn prune_noop_when_under_limit() {
        let svc = StreamHealthService(make_service());
        svc.record_stream_stall("h1").unwrap();
        let deleted = svc.prune_stream_health(100).unwrap();
        assert_eq!(deleted, 0);
    }

    #[test]
    fn evaluate_warming_after_4_low_buffers() {
        let svc = StreamHealthService(make_service());
        let mut state = HashMap::new();

        for i in 0..3 {
            let r = svc
                .evaluate_failover_event("u1", "buffer", 0.5, &mut state)
                .unwrap();
            assert!(
                r.contains(r#""action":"none""#),
                "sample {i} should be none"
            );
        }
        // 4th low sample triggers warming
        let r = svc
            .evaluate_failover_event("u1", "buffer", 0.5, &mut state)
            .unwrap();
        assert!(r.contains(r#""action":"start_warming""#));
    }

    #[test]
    fn evaluate_swap_after_6_stalls() {
        let svc = StreamHealthService(make_service());
        let mut state = HashMap::new();

        for i in 0..5 {
            let r = svc
                .evaluate_failover_event("u2", "stall", 0.0, &mut state)
                .unwrap();
            assert!(r.contains(r#""action":"none""#), "stall {i} should be none");
        }
        // 6th stall triggers swap
        let r = svc
            .evaluate_failover_event("u2", "stall", 0.0, &mut state)
            .unwrap();
        assert!(r.contains(r#""action":"swap_warm""#));
    }

    #[test]
    fn evaluate_buffer_above_reset_clears_counter() {
        let svc = StreamHealthService(make_service());
        let mut state = HashMap::new();

        // 3 low samples
        for _ in 0..3 {
            svc.evaluate_failover_event("u3", "buffer", 0.5, &mut state)
                .unwrap();
        }
        // Buffer recovers above reset threshold
        svc.evaluate_failover_event("u3", "buffer", 3.0, &mut state)
            .unwrap();

        // Need 4 more low samples to trigger (not 1)
        let r = svc
            .evaluate_failover_event("u3", "buffer", 0.5, &mut state)
            .unwrap();
        assert!(r.contains(r#""action":"none""#));
    }

    #[test]
    fn reset_failover_state_clears_counters() {
        let mut state = HashMap::new();
        state.insert("u4".to_string(), (5, 10));
        StreamHealthService::reset_failover_state("u4", &mut state);
        assert!(!state.contains_key("u4"));
    }

    #[test]
    fn get_stream_health_scores_batch() {
        let svc = StreamHealthService(make_service());
        svc.record_stream_stall("a").unwrap();
        svc.record_buffer_sample("b", 5.0).unwrap();

        let hashes = vec!["a".to_string(), "b".to_string(), "missing".to_string()];
        let scores = svc.get_stream_health_scores(&hashes).unwrap();

        assert_eq!(scores.len(), 3);
        assert!(scores["a"] > 0.0);
        assert!(scores["b"] > 0.0);
        assert!((scores["missing"] - 0.5).abs() < 0.001);
    }

    #[test]
    fn health_score_formula_known_values() {
        // Test the formula directly with known inputs:
        // stall_count=0, buffer_sum=50.0, buffer_samples=10, ttff_ms=500
        // → stall_score = 1.0, buffer_score = 0.5, ttff_score = 0.95
        // → raw = 1.0*0.5 + 0.5*0.3 + 0.95*0.2 = 0.5 + 0.15 + 0.19 = 0.84
        // decay ≈ 1.0 for fresh entry
        let now = chrono::Utc::now().timestamp();
        let score = compute_health_score(0, 50.0, 10, 500, now);
        assert!((score - 0.84).abs() < 0.05, "expected ~0.84, got {score}");
    }

    #[test]
    fn health_score_decay_7_days() {
        // An entry 7 days old should score roughly half of a fresh entry
        let now = chrono::Utc::now().timestamp();
        let seven_days_ago = now - 7 * 24 * 3600;
        let fresh = compute_health_score(0, 50.0, 10, 500, now);
        let old = compute_health_score(0, 50.0, 10, 500, seven_days_ago);
        let ratio = old / fresh;
        assert!(
            ratio > 0.4 && ratio < 0.6,
            "7-day-old entry should be ~50% of fresh, ratio={ratio}"
        );
    }

    #[test]
    fn evaluate_unknown_event_type_returns_none() {
        let svc = StreamHealthService(make_service());
        let mut state = HashMap::new();
        let r = svc
            .evaluate_failover_event("u5", "unknown", 0.0, &mut state)
            .unwrap();
        assert!(r.contains(r#""action":"none""#));
    }
}
