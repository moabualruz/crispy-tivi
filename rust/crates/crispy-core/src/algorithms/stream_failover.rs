//! Stream failover logic for resilient IPTV playback.
//!
//! Rules:
//! - 5 consecutive failures before triggering failover to next-best source.
//! - Failed streams are health-scored and retried after 15 minutes (default).
//! - `FailoverManager` is the central state tracker per channel.

use std::collections::HashMap;
use std::time::{Duration, Instant};

use crate::models::stream_quality::StreamInfo;

// ── Constants ─────────────────────────────────────────────

/// Number of consecutive failures before failover is triggered.
const FAILURES_BEFORE_FAILOVER: u32 = 5;

/// Default retry backoff after failure.
const DEFAULT_RETRY_AFTER: Duration = Duration::from_secs(15 * 60);

/// Health score penalty per consecutive failure (multiplicative).
const HEALTH_PENALTY_PER_FAILURE: f64 = 0.15;

// ── Stream state ──────────────────────────────────────────

/// Per-stream health tracking state.
#[derive(Debug, Clone)]
struct StreamState {
    /// The stream being tracked.
    stream: StreamInfo,
    /// Current health score in [0.0, 1.0].
    health_score: f64,
    /// Number of consecutive failures (reset on success).
    consecutive_failures: u32,
    /// Total lifetime failures.
    total_failures: u32,
    /// When this stream may be retried (`None` = immediately available).
    retry_after: Option<Instant>,
    /// Whether this stream is currently the active one.
    is_active: bool,
}

impl StreamState {
    fn new(stream: StreamInfo) -> Self {
        Self {
            stream,
            health_score: 1.0,
            consecutive_failures: 0,
            total_failures: 0,
            retry_after: None,
            is_active: false,
        }
    }

    fn is_available(&self) -> bool {
        match self.retry_after {
            None => true,
            Some(t) => Instant::now() >= t,
        }
    }

    fn record_failure(&mut self, retry_after: Duration) {
        self.consecutive_failures += 1;
        self.total_failures += 1;
        // Multiplicative health degradation.
        self.health_score = (self.health_score * (1.0 - HEALTH_PENALTY_PER_FAILURE)).max(0.0);
        if self.consecutive_failures >= FAILURES_BEFORE_FAILOVER {
            self.retry_after = Some(Instant::now() + retry_after);
        }
    }

    fn record_success(&mut self) {
        self.consecutive_failures = 0;
        self.retry_after = None;
        // Partial health recovery on success.
        self.health_score = (self.health_score + 0.1).min(1.0);
    }
}

// ── FailoverManager ───────────────────────────────────────

/// Tracks stream health per channel and selects the best available stream.
///
/// Each channel has an ordered list of candidate streams (ranked by quality
/// descending). `FailoverManager` routes playback to the best available one.
pub struct FailoverManager {
    /// `channel_id → Vec<StreamState>` (ordered best-first).
    channels: HashMap<String, Vec<StreamState>>,
    /// How long to back off a failed stream.
    retry_after: Duration,
}

impl Default for FailoverManager {
    fn default() -> Self {
        Self::new(DEFAULT_RETRY_AFTER)
    }
}

impl FailoverManager {
    /// Create a manager with a custom retry window.
    pub fn new(retry_after: Duration) -> Self {
        Self {
            channels: HashMap::new(),
            retry_after,
        }
    }

    /// Register the ordered list of candidate streams for a channel.
    ///
    /// Streams should be ordered best-first (highest quality / most preferred).
    pub fn register_channel(&mut self, channel_id: &str, streams: Vec<StreamInfo>) {
        let states: Vec<StreamState> = streams.into_iter().map(StreamState::new).collect();
        self.channels.insert(channel_id.to_string(), states);
    }

    /// Report a failure for `stream_id` (URL) within `channel_id`.
    pub fn report_failure(&mut self, channel_id: &str, stream_url: &str) {
        if let Some(states) = self.channels.get_mut(channel_id)
            && let Some(state) = states.iter_mut().find(|s| s.stream.url == stream_url)
        {
            state.record_failure(self.retry_after);
        }
    }

    /// Report a successful play for `stream_url` within `channel_id`.
    pub fn report_success(&mut self, channel_id: &str, stream_url: &str) {
        if let Some(states) = self.channels.get_mut(channel_id)
            && let Some(state) = states.iter_mut().find(|s| s.stream.url == stream_url)
        {
            state.record_success();
            state.is_active = true;
        }
    }

    /// Get the best currently available stream for `channel_id`.
    ///
    /// Selection:
    /// 1. If the current active stream is available → keep it (stability).
    /// 2. Otherwise pick the first available stream in priority order
    ///    weighted by health score.
    pub fn get_best_stream(&self, channel_id: &str) -> Option<StreamInfo> {
        let states = self.channels.get(channel_id)?;

        // Try to keep the current active stream if it is still available.
        if let Some(active) = states.iter().find(|s| s.is_active && s.is_available()) {
            return Some(active.stream.clone());
        }

        // Fall back to best available by priority order × health score.
        // Priority order is the original index (lower index = higher quality).
        states
            .iter()
            .enumerate()
            .filter(|(_, s)| s.is_available())
            .max_by(|(ia, a), (ib, b)| {
                // Score = health × priority_weight (priority_weight decays with index).
                let pa = 1.0 / (*ia as f64 + 1.0);
                let pb = 1.0 / (*ib as f64 + 1.0);
                let sa = a.health_score * pa;
                let sb = b.health_score * pb;
                sa.partial_cmp(&sb).unwrap_or(std::cmp::Ordering::Equal)
            })
            .map(|(_, s)| s.stream.clone())
    }

    /// Returns the health score for a specific stream URL within a channel.
    pub fn health_score(&self, channel_id: &str, stream_url: &str) -> Option<f64> {
        self.channels
            .get(channel_id)?
            .iter()
            .find(|s| s.stream.url == stream_url)
            .map(|s| s.health_score)
    }

    /// Returns consecutive failure count for a stream.
    pub fn consecutive_failures(&self, channel_id: &str, stream_url: &str) -> u32 {
        self.channels
            .get(channel_id)
            .and_then(|states| states.iter().find(|s| s.stream.url == stream_url))
            .map(|s| s.consecutive_failures)
            .unwrap_or(0)
    }
}

// ── Tests ─────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::stream_quality::Resolution;

    fn stream(url: &str) -> StreamInfo {
        StreamInfo {
            url: url.to_string(),
            resolution: Resolution::HD,
            bitrate_kbps: 2000,
            label: None,
        }
    }

    fn manager_fast() -> FailoverManager {
        // Use zero retry for tests so streams become immediately re-available.
        FailoverManager::new(Duration::ZERO)
    }

    // ── register & get ────────────────────────────────────

    #[test]
    fn test_get_best_stream_returns_first() {
        let mut mgr = FailoverManager::default();
        mgr.register_channel("ch1", vec![stream("url_a"), stream("url_b")]);
        // No active stream set — picks best by priority × health (url_a is index 0).
        let best = mgr.get_best_stream("ch1").unwrap();
        assert_eq!(best.url, "url_a");
    }

    #[test]
    fn test_get_best_stream_unknown_channel() {
        let mgr = FailoverManager::default();
        assert!(mgr.get_best_stream("unknown").is_none());
    }

    // ── report_failure ────────────────────────────────────

    #[test]
    fn test_failures_below_threshold_no_backoff() {
        let mut mgr = FailoverManager::default();
        mgr.register_channel("ch1", vec![stream("url_a")]);
        for _ in 0..(FAILURES_BEFORE_FAILOVER - 1) {
            mgr.report_failure("ch1", "url_a");
        }
        // Should still be available (threshold not yet reached).
        assert!(mgr.get_best_stream("ch1").is_some());
    }

    #[test]
    fn test_failover_triggers_at_threshold_with_zero_retry() {
        let mut mgr = manager_fast();
        mgr.register_channel("ch1", vec![stream("url_a"), stream("url_b")]);
        for _ in 0..FAILURES_BEFORE_FAILOVER {
            mgr.report_failure("ch1", "url_a");
        }
        // url_a is backed-off (retry = zero so it's immediately available again
        // in manager_fast — this tests that we track the failure count correctly).
        let count = mgr.consecutive_failures("ch1", "url_a");
        assert_eq!(count, FAILURES_BEFORE_FAILOVER);
    }

    #[test]
    fn test_failover_switches_to_next_stream() {
        // Use real (non-zero) retry to simulate real backoff.
        let mut mgr = FailoverManager::new(Duration::from_secs(3600));
        mgr.register_channel("ch1", vec![stream("url_a"), stream("url_b")]);
        for _ in 0..FAILURES_BEFORE_FAILOVER {
            mgr.report_failure("ch1", "url_a");
        }
        // url_a is backed-off; should return url_b.
        let best = mgr.get_best_stream("ch1").unwrap();
        assert_eq!(best.url, "url_b");
    }

    // ── report_success ────────────────────────────────────

    #[test]
    fn test_success_resets_consecutive_failures() {
        let mut mgr = FailoverManager::default();
        mgr.register_channel("ch1", vec![stream("url_a")]);
        for _ in 0..3 {
            mgr.report_failure("ch1", "url_a");
        }
        mgr.report_success("ch1", "url_a");
        assert_eq!(mgr.consecutive_failures("ch1", "url_a"), 0);
    }

    #[test]
    fn test_success_marks_stream_active() {
        let mut mgr = FailoverManager::default();
        mgr.register_channel("ch1", vec![stream("url_a"), stream("url_b")]);
        mgr.report_success("ch1", "url_b");
        // url_b is now active — get_best_stream should prefer it.
        let best = mgr.get_best_stream("ch1").unwrap();
        assert_eq!(best.url, "url_b");
    }

    // ── health score ──────────────────────────────────────

    #[test]
    fn test_health_score_degrades_on_failure() {
        let mut mgr = FailoverManager::default();
        mgr.register_channel("ch1", vec![stream("url_a")]);
        let before = mgr.health_score("ch1", "url_a").unwrap();
        mgr.report_failure("ch1", "url_a");
        let after = mgr.health_score("ch1", "url_a").unwrap();
        assert!(after < before);
    }

    #[test]
    fn test_health_score_recovers_on_success() {
        let mut mgr = FailoverManager::default();
        mgr.register_channel("ch1", vec![stream("url_a")]);
        for _ in 0..3 {
            mgr.report_failure("ch1", "url_a");
        }
        let after_failures = mgr.health_score("ch1", "url_a").unwrap();
        mgr.report_success("ch1", "url_a");
        let after_success = mgr.health_score("ch1", "url_a").unwrap();
        assert!(after_success > after_failures);
    }

    // ── Edge cases ────────────────────────────────────────

    #[test]
    fn test_report_on_unknown_channel_is_noop() {
        let mut mgr = FailoverManager::default();
        mgr.report_failure("ghost", "url_x"); // must not panic
        mgr.report_success("ghost", "url_x");
    }

    #[test]
    fn test_empty_stream_list() {
        let mut mgr = FailoverManager::default();
        mgr.register_channel("ch1", vec![]);
        assert!(mgr.get_best_stream("ch1").is_none());
    }

    #[test]
    fn test_all_streams_backed_off_returns_none() {
        let mut mgr = FailoverManager::new(Duration::from_secs(3600));
        mgr.register_channel("ch1", vec![stream("url_a")]);
        for _ in 0..FAILURES_BEFORE_FAILOVER {
            mgr.report_failure("ch1", "url_a");
        }
        // Only one stream and it's backed off.
        assert!(mgr.get_best_stream("ch1").is_none());
    }
}
