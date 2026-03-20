//! Quality-of-Experience (QoE) event collection and aggregation.
//!
//! Collects playback events (TTFF, rebuffer, quality switches,
//! failures, session ends) tagged by source type, then computes
//! per-source aggregate metrics. No raw URLs or IP addresses are
//! stored in any event.
//!
//! # Privacy
//! - Profile IDs are SHA-256(raw_id || salt) — never stored in plain text.
//! - A rotating salt means the hash changes on each app session.
//! - Kids profiles (COPPA) produce **no events** — all `report_*` calls
//!   are no-ops when `is_coppa = true`.

use sha2::{Digest, Sha256};
use std::{
    collections::HashMap,
    sync::{Arc, Mutex},
    time::Duration,
};

// ── Profile ID hashing (11.3) ─────────────────────────────────────────────────

/// Hash a raw profile ID with a per-session salt.
///
/// The salt should be a random value generated once at app startup and
/// rotated on each launch so the hash is not linkable across sessions.
/// Returns a lowercase hex string of SHA-256(raw_id || salt).
pub fn hash_profile_id(raw_id: &str, salt: &str) -> String {
    let mut h = Sha256::new();
    h.update(raw_id.as_bytes());
    h.update(salt.as_bytes());
    h.finalize().iter().map(|b| format!("{b:02x}")).collect()
}

// ── Source type ───────────────────────────────────────────────────────────────

/// Which kind of content source produced the event.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum SourceType {
    Iptv,
    Plex,
    Jellyfin,
    Dvr,
}

impl SourceType {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Iptv => "iptv",
            Self::Plex => "plex",
            Self::Jellyfin => "jellyfin",
            Self::Dvr => "dvr",
        }
    }
}

// ── QoeEvent ──────────────────────────────────────────────────────────────────

/// A single QoE observation.
///
/// No raw URLs, hostnames, or IP addresses are included in
/// any variant — callers must not pass them in `reason`.
#[derive(Debug, Clone)]
pub enum QoeEvent {
    /// Time-to-first-frame.
    Ttff(Duration),
    /// Buffering stall event.
    Rebuffer { duration: Duration, count: u32 },
    /// Adaptive-quality level switch.
    QualitySwitch { from: String, to: String },
    /// Unrecoverable playback error.
    PlaybackFailure { reason: String },
    /// Normal session end.
    SessionEnd {
        duration: Duration,
        completion_pct: f32,
    },
}

// ── Tagged event ──────────────────────────────────────────────────────────────

#[derive(Debug, Clone)]
struct TaggedEvent {
    source_id: String,
    /// Retained for per-type aggregate queries (e.g. IPTV vs Jellyfin).
    #[allow(dead_code)]
    source_type: SourceType,
    event: QoeEvent,
}

// ── SourceMetrics ─────────────────────────────────────────────────────────────

/// Aggregate QoE metrics for one source.
#[derive(Debug, Clone, Default)]
pub struct SourceMetrics {
    /// Number of TTFF samples observed.
    pub ttff_samples: u32,
    /// Average TTFF in milliseconds.
    pub avg_ttff_ms: f64,
    /// Total rebuffer events.
    pub rebuffer_count: u32,
    /// Total rebuffer stall time in milliseconds.
    pub total_rebuffer_ms: f64,
    /// Total quality-switch events.
    pub quality_switch_count: u32,
    /// Total playback-failure events.
    pub failure_count: u32,
    /// Total completed sessions.
    pub session_count: u32,
    /// Average session completion percentage (0.0–1.0).
    pub avg_completion_pct: f32,
}

// ── QoeCollector ─────────────────────────────────────────────────────────────

/// Thread-safe QoE event collector.
///
/// All events are held in memory. `get_source_metrics` computes
/// aggregates on demand from the collected events.
///
/// # COPPA / Kids profiles (11.4)
/// When `is_coppa` is `true` all `report_*` calls are silent no-ops.
/// No events are recorded and no data leaves the device.
#[derive(Clone)]
pub struct QoeCollector {
    events: Arc<Mutex<Vec<TaggedEvent>>>,
    /// When `true` this collector is bound to a Kids profile.
    /// All event recording is suppressed for COPPA compliance.
    is_coppa: bool,
}

impl Default for QoeCollector {
    fn default() -> Self {
        Self {
            events: Arc::new(Mutex::new(Vec::new())),
            is_coppa: false,
        }
    }
}

impl QoeCollector {
    pub fn new() -> Self {
        Self::default()
    }

    /// Create a collector for a Kids profile (COPPA-compliant — no events recorded).
    pub fn new_coppa() -> Self {
        Self {
            events: Arc::new(Mutex::new(Vec::new())),
            is_coppa: true,
        }
    }

    /// Returns `true` if this collector is in COPPA / Kids mode.
    pub fn is_coppa(&self) -> bool {
        self.is_coppa
    }

    // ── Recording helpers ────────────────────────────────────────────────────

    fn record(&self, source_id: impl Into<String>, source_type: SourceType, event: QoeEvent) {
        // 11.4: Kids profiles produce no telemetry events.
        if self.is_coppa {
            return;
        }
        let tagged = TaggedEvent {
            source_id: source_id.into(),
            source_type,
            event,
        };
        let mut guard = self.events.lock().unwrap_or_else(|e| e.into_inner());
        guard.push(tagged);
    }

    /// Record a time-to-first-frame observation.
    pub fn report_ttff(
        &self,
        source_id: impl Into<String>,
        source_type: SourceType,
        duration: Duration,
    ) {
        self.record(source_id, source_type, QoeEvent::Ttff(duration));
    }

    /// Record a rebuffering stall event.
    pub fn report_rebuffer(
        &self,
        source_id: impl Into<String>,
        source_type: SourceType,
        duration: Duration,
    ) {
        let count = 1;
        self.record(
            source_id,
            source_type,
            QoeEvent::Rebuffer { duration, count },
        );
    }

    /// Record a session-end event.
    pub fn report_session_end(
        &self,
        source_id: impl Into<String>,
        source_type: SourceType,
        duration: Duration,
        completion_pct: f32,
    ) {
        self.record(
            source_id,
            source_type,
            QoeEvent::SessionEnd {
                duration,
                completion_pct,
            },
        );
    }

    /// Record a quality-level switch event.
    pub fn report_quality_switch(
        &self,
        source_id: impl Into<String>,
        source_type: SourceType,
        from: impl Into<String>,
        to: impl Into<String>,
    ) {
        self.record(
            source_id,
            source_type,
            QoeEvent::QualitySwitch {
                from: from.into(),
                to: to.into(),
            },
        );
    }

    /// Record a playback failure.
    ///
    /// `reason` must not contain raw URLs or IP addresses.
    pub fn report_failure(
        &self,
        source_id: impl Into<String>,
        source_type: SourceType,
        reason: impl Into<String>,
    ) {
        self.record(
            source_id,
            source_type,
            QoeEvent::PlaybackFailure {
                reason: reason.into(),
            },
        );
    }

    // ── Aggregation ──────────────────────────────────────────────────────────

    /// Compute aggregate QoE metrics for `source_id`.
    ///
    /// Returns a default (zero) `SourceMetrics` if no events have
    /// been recorded for that source.
    pub fn get_source_metrics(&self, source_id: &str) -> SourceMetrics {
        let guard = self.events.lock().unwrap_or_else(|e| e.into_inner());

        let mut ttff_total_ms = 0.0_f64;
        let mut ttff_count = 0u32;
        let mut rebuffer_count = 0u32;
        let mut rebuffer_ms = 0.0_f64;
        let mut quality_switches = 0u32;
        let mut failures = 0u32;
        let mut sessions = 0u32;
        let mut completion_total = 0.0_f32;

        for tagged in guard.iter().filter(|t| t.source_id == source_id) {
            match &tagged.event {
                QoeEvent::Ttff(d) => {
                    ttff_total_ms += d.as_millis() as f64;
                    ttff_count += 1;
                }
                QoeEvent::Rebuffer { duration, count } => {
                    rebuffer_ms += duration.as_millis() as f64;
                    rebuffer_count += count;
                }
                QoeEvent::QualitySwitch { .. } => quality_switches += 1,
                QoeEvent::PlaybackFailure { .. } => failures += 1,
                QoeEvent::SessionEnd { completion_pct, .. } => {
                    sessions += 1;
                    completion_total += completion_pct;
                }
            }
        }

        SourceMetrics {
            ttff_samples: ttff_count,
            avg_ttff_ms: if ttff_count > 0 {
                ttff_total_ms / ttff_count as f64
            } else {
                0.0
            },
            rebuffer_count,
            total_rebuffer_ms: rebuffer_ms,
            quality_switch_count: quality_switches,
            failure_count: failures,
            session_count: sessions,
            avg_completion_pct: if sessions > 0 {
                completion_total / sessions as f32
            } else {
                0.0
            },
        }
    }

    /// Aggregate metrics for every source that has events, keyed by source_id.
    pub fn all_source_metrics(&self) -> HashMap<String, SourceMetrics> {
        let guard = self.events.lock().unwrap_or_else(|e| e.into_inner());
        let ids: Vec<String> = guard
            .iter()
            .map(|t| t.source_id.clone())
            .collect::<std::collections::HashSet<_>>()
            .into_iter()
            .collect();
        drop(guard);

        ids.into_iter()
            .map(|id| {
                let m = self.get_source_metrics(&id);
                (id, m)
            })
            .collect()
    }

    /// Total number of events recorded across all sources.
    pub fn event_count(&self) -> usize {
        self.events.lock().unwrap_or_else(|e| e.into_inner()).len()
    }

    /// Drain all events (e.g. after a flush to persistent storage).
    pub fn clear(&self) {
        self.events
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .clear();
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn src() -> &'static str {
        "src-iptv-1"
    }

    #[test]
    fn test_report_ttff_records_event() {
        let c = QoeCollector::new();
        c.report_ttff(src(), SourceType::Iptv, Duration::from_millis(800));
        assert_eq!(c.event_count(), 1);
    }

    #[test]
    fn test_avg_ttff_single_sample() {
        let c = QoeCollector::new();
        c.report_ttff(src(), SourceType::Iptv, Duration::from_millis(1000));
        let m = c.get_source_metrics(src());
        assert_eq!(m.ttff_samples, 1);
        assert!((m.avg_ttff_ms - 1000.0).abs() < 0.01);
    }

    #[test]
    fn test_avg_ttff_multiple_samples() {
        let c = QoeCollector::new();
        c.report_ttff(src(), SourceType::Iptv, Duration::from_millis(1000));
        c.report_ttff(src(), SourceType::Iptv, Duration::from_millis(2000));
        let m = c.get_source_metrics(src());
        assert_eq!(m.ttff_samples, 2);
        assert!((m.avg_ttff_ms - 1500.0).abs() < 0.01);
    }

    #[test]
    fn test_rebuffer_accumulates() {
        let c = QoeCollector::new();
        c.report_rebuffer(src(), SourceType::Iptv, Duration::from_millis(500));
        c.report_rebuffer(src(), SourceType::Iptv, Duration::from_millis(300));
        let m = c.get_source_metrics(src());
        assert_eq!(m.rebuffer_count, 2);
        assert!((m.total_rebuffer_ms - 800.0).abs() < 0.01);
    }

    #[test]
    fn test_quality_switch_counted() {
        let c = QoeCollector::new();
        c.report_quality_switch(src(), SourceType::Jellyfin, "1080p", "720p");
        let m = c.get_source_metrics(src());
        assert_eq!(m.quality_switch_count, 1);
    }

    #[test]
    fn test_failure_counted() {
        let c = QoeCollector::new();
        c.report_failure(src(), SourceType::Plex, "decode error");
        let m = c.get_source_metrics(src());
        assert_eq!(m.failure_count, 1);
    }

    #[test]
    fn test_session_end_avg_completion() {
        let c = QoeCollector::new();
        c.report_session_end(src(), SourceType::Iptv, Duration::from_secs(3600), 1.0);
        c.report_session_end(src(), SourceType::Iptv, Duration::from_secs(1800), 0.5);
        let m = c.get_source_metrics(src());
        assert_eq!(m.session_count, 2);
        assert!((m.avg_completion_pct - 0.75).abs() < 0.01);
    }

    #[test]
    fn test_empty_source_returns_defaults() {
        let c = QoeCollector::new();
        let m = c.get_source_metrics("nonexistent");
        assert_eq!(m.ttff_samples, 0);
        assert_eq!(m.rebuffer_count, 0);
        assert_eq!(m.failure_count, 0);
    }

    #[test]
    fn test_events_isolated_by_source_id() {
        let c = QoeCollector::new();
        c.report_failure("src-a", SourceType::Iptv, "err");
        c.report_failure("src-b", SourceType::Iptv, "err");
        assert_eq!(c.get_source_metrics("src-a").failure_count, 1);
        assert_eq!(c.get_source_metrics("src-b").failure_count, 1);
    }

    #[test]
    fn test_all_source_metrics_keys() {
        let c = QoeCollector::new();
        c.report_ttff("s1", SourceType::Iptv, Duration::from_millis(100));
        c.report_ttff("s2", SourceType::Dvr, Duration::from_millis(200));
        let all = c.all_source_metrics();
        assert!(all.contains_key("s1"));
        assert!(all.contains_key("s2"));
    }

    #[test]
    fn test_clear_drains_all_events() {
        let c = QoeCollector::new();
        c.report_ttff(src(), SourceType::Iptv, Duration::from_millis(100));
        c.clear();
        assert_eq!(c.event_count(), 0);
    }

    #[test]
    fn test_source_type_as_str() {
        assert_eq!(SourceType::Iptv.as_str(), "iptv");
        assert_eq!(SourceType::Plex.as_str(), "plex");
        assert_eq!(SourceType::Jellyfin.as_str(), "jellyfin");
        assert_eq!(SourceType::Dvr.as_str(), "dvr");
    }

    // ── 11.3: Pseudonymized profile ID hashing ───────────────────────────────

    #[test]
    fn test_hash_profile_id_is_deterministic_same_salt() {
        let h1 = hash_profile_id("user-abc", "salt-session-1");
        let h2 = hash_profile_id("user-abc", "salt-session-1");
        assert_eq!(h1, h2);
    }

    #[test]
    fn test_hash_profile_id_differs_with_different_salt() {
        let h1 = hash_profile_id("user-abc", "salt-session-1");
        let h2 = hash_profile_id("user-abc", "salt-session-2");
        assert_ne!(h1, h2, "rotating salt must produce different hashes");
    }

    #[test]
    fn test_hash_profile_id_differs_for_different_users() {
        let h1 = hash_profile_id("user-abc", "salt");
        let h2 = hash_profile_id("user-xyz", "salt");
        assert_ne!(h1, h2);
    }

    #[test]
    fn test_hash_profile_id_does_not_contain_raw_id() {
        let raw = "sensitive-user-id-12345";
        let h = hash_profile_id(raw, "s");
        assert!(
            !h.contains(raw),
            "raw profile ID must not appear in hash output"
        );
    }

    #[test]
    fn test_hash_profile_id_output_is_hex_string() {
        let h = hash_profile_id("user", "salt");
        assert_eq!(h.len(), 64, "SHA-256 hex is 64 chars");
        assert!(h.chars().all(|c| c.is_ascii_hexdigit()));
    }

    // ── 11.4: COPPA / Kids profile — no events recorded ─────────────────────

    #[test]
    fn test_coppa_collector_records_no_ttff() {
        let c = QoeCollector::new_coppa();
        c.report_ttff(src(), SourceType::Iptv, Duration::from_millis(500));
        assert_eq!(c.event_count(), 0, "COPPA collector must not record TTFF");
    }

    #[test]
    fn test_coppa_collector_records_no_rebuffer() {
        let c = QoeCollector::new_coppa();
        c.report_rebuffer(src(), SourceType::Iptv, Duration::from_millis(200));
        assert_eq!(c.event_count(), 0);
    }

    #[test]
    fn test_coppa_collector_records_no_quality_switch() {
        let c = QoeCollector::new_coppa();
        c.report_quality_switch(src(), SourceType::Iptv, "1080p", "720p");
        assert_eq!(c.event_count(), 0);
    }

    #[test]
    fn test_coppa_collector_records_no_failure() {
        let c = QoeCollector::new_coppa();
        c.report_failure(src(), SourceType::Iptv, "decode error");
        assert_eq!(c.event_count(), 0);
    }

    #[test]
    fn test_coppa_collector_records_no_session_end() {
        let c = QoeCollector::new_coppa();
        c.report_session_end(src(), SourceType::Iptv, Duration::from_secs(600), 1.0);
        assert_eq!(c.event_count(), 0);
    }

    #[test]
    fn test_coppa_flag_is_true_on_coppa_collector() {
        let c = QoeCollector::new_coppa();
        assert!(c.is_coppa());
    }

    #[test]
    fn test_coppa_flag_is_false_on_normal_collector() {
        let c = QoeCollector::new();
        assert!(!c.is_coppa());
    }

    #[test]
    fn test_coppa_metrics_always_zero() {
        let c = QoeCollector::new_coppa();
        c.report_ttff(src(), SourceType::Iptv, Duration::from_millis(100));
        c.report_rebuffer(src(), SourceType::Iptv, Duration::from_millis(100));
        let m = c.get_source_metrics(src());
        assert_eq!(m.ttff_samples, 0);
        assert_eq!(m.rebuffer_count, 0);
    }
}
