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

// ── Config ────────────────────────────────────────────────

/// Configuration for `FailoverManager` thresholds and backoff.
#[derive(Debug, Clone)]
pub(crate) struct FailoverConfig {
    /// Consecutive failures required to trigger failover. Default: 5.
    pub(crate) failures_before_failover: u32,
    /// How long to back off a stream after it reaches the failure threshold. Default: 15 min.
    pub(crate) retry_after: Duration,
}

impl Default for FailoverConfig {
    fn default() -> Self {
        Self {
            failures_before_failover: FAILURES_BEFORE_FAILOVER,
            retry_after: DEFAULT_RETRY_AFTER,
        }
    }
}

// ── Notification ──────────────────────────────────────────

/// Payload sent to a `FailoverListener` when the active stream changes.
#[derive(Debug, Clone)]
pub(crate) struct FailoverNotification {
    /// URL / label of the stream that failed.
    pub(crate) failed_source: String,
    /// URL / label of the new stream that was selected.
    pub(crate) new_source: String,
    /// Whether the user may undo this failover (switch back).
    pub(crate) can_undo: bool,
    /// Seconds the undo option remains available in the UI (toast timeout).
    pub(crate) undo_timeout_secs: u32,
}

impl FailoverNotification {
    /// Construct a notification with `can_undo = true` and the default 3-second undo window.
    pub(crate) fn new(failed_source: impl Into<String>, new_source: impl Into<String>) -> Self {
        Self {
            failed_source: failed_source.into(),
            new_source: new_source.into(),
            can_undo: true,
            undo_timeout_secs: 3,
        }
    }
}

// ── Listener ──────────────────────────────────────────────

/// Callback interface for UI components that react to stream failover events.
pub(crate) trait FailoverListener: Send + Sync {
    /// Called immediately after the active stream has changed.
    fn on_failover(&self, notification: FailoverNotification);
}

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
        self.record_failure_with_threshold(retry_after, FAILURES_BEFORE_FAILOVER);
    }

    fn record_failure_with_threshold(&mut self, retry_after: Duration, threshold: u32) {
        self.consecutive_failures += 1;
        self.total_failures += 1;
        // Multiplicative health degradation.
        self.health_score = (self.health_score * (1.0 - HEALTH_PENALTY_PER_FAILURE)).max(0.0);
        if self.consecutive_failures >= threshold {
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
pub(crate) struct FailoverManager {
    /// `channel_id → Vec<StreamState>` (ordered best-first).
    channels: HashMap<String, Vec<StreamState>>,
    /// How long to back off a failed stream.
    retry_after: Duration,
    /// Consecutive failures required before triggering failover.
    failures_before_failover: u32,
    /// Optional listener that receives UI notifications on failover.
    listener: Option<Box<dyn FailoverListener>>,
}

impl Default for FailoverManager {
    fn default() -> Self {
        Self::new(DEFAULT_RETRY_AFTER)
    }
}

impl FailoverManager {
    /// Create a manager with a custom retry window (failure threshold uses the default of 5).
    pub(crate) fn new(retry_after: Duration) -> Self {
        Self {
            channels: HashMap::new(),
            retry_after,
            failures_before_failover: FAILURES_BEFORE_FAILOVER,
            listener: None,
        }
    }

    /// Create a manager from a `FailoverConfig`.
    pub(crate) fn with_config(config: FailoverConfig) -> Self {
        Self {
            channels: HashMap::new(),
            retry_after: config.retry_after,
            failures_before_failover: config.failures_before_failover,
            listener: None,
        }
    }

    /// Attach a UI listener that is notified when a failover occurs.
    pub(crate) fn set_listener(&mut self, listener: impl FailoverListener + 'static) {
        self.listener = Some(Box::new(listener));
    }

    /// Register the ordered list of candidate streams for a channel.
    ///
    /// Streams should be ordered best-first (highest quality / most preferred).
    pub(crate) fn register_channel(&mut self, channel_id: &str, streams: Vec<StreamInfo>) {
        let states: Vec<StreamState> = streams.into_iter().map(StreamState::new).collect();
        self.channels.insert(channel_id.to_string(), states);
    }

    /// Report a failure for `stream_url` within `channel_id`.
    ///
    /// After `failures_before_failover` consecutive failures the stream is backed off and
    /// `trigger_failover` is called, which fires the `FailoverListener` if one is set.
    pub(crate) fn record_failure(&mut self, channel_id: &str, stream_url: &str) {
        self.report_failure(channel_id, stream_url);
    }

    /// Internal: record failure and optionally fire the listener.
    pub(crate) fn report_failure(&mut self, channel_id: &str, stream_url: &str) {
        let threshold = self.failures_before_failover;
        let retry_after = self.retry_after;

        let should_notify = if let Some(states) = self.channels.get_mut(channel_id) {
            if let Some(state) = states.iter_mut().find(|s| s.stream.url == stream_url) {
                state.record_failure(retry_after);
                state.consecutive_failures >= threshold
            } else {
                false
            }
        } else {
            false
        };

        if should_notify {
            let new_stream = self.get_best_stream(channel_id);
            self.trigger_failover(
                channel_id,
                stream_url,
                new_stream.as_ref().map(|s| s.url.as_str()),
            );
        }
    }

    /// Report a successful play for `stream_url` within `channel_id`.
    pub(crate) fn record_success(&mut self, channel_id: &str, stream_url: &str) {
        self.report_success(channel_id, stream_url);
    }

    /// Internal: record success and mark stream active.
    pub(crate) fn report_success(&mut self, channel_id: &str, stream_url: &str) {
        if let Some(states) = self.channels.get_mut(channel_id) {
            // Clear active flag on all streams first.
            for s in states.iter_mut() {
                s.is_active = false;
            }
            if let Some(state) = states.iter_mut().find(|s| s.stream.url == stream_url) {
                state.record_success();
                state.is_active = true;
            }
        }
    }

    /// Returns whether a failover should be triggered for `stream_url` in `channel_id`.
    ///
    /// `true` when consecutive failures have reached the configured threshold.
    pub(crate) fn should_failover(&self, channel_id: &str, stream_url: &str) -> bool {
        self.consecutive_failures(channel_id, stream_url) >= self.failures_before_failover
    }

    /// Trigger a failover: deactivate the failed stream and notify the listener.
    ///
    /// Called automatically by `report_failure` once the threshold is reached.
    /// May also be called manually (e.g. user-initiated skip).
    pub(crate) fn trigger_failover(
        &mut self,
        channel_id: &str,
        failed_url: &str,
        new_url: Option<&str>,
    ) {
        // Deactivate the failed stream.
        if let Some(state) = self
            .channels
            .get_mut(channel_id)
            .and_then(|states| states.iter_mut().find(|s| s.stream.url == failed_url))
        {
            state.is_active = false;
        }

        if let Some(listener) = &self.listener {
            let notification = FailoverNotification::new(failed_url, new_url.unwrap_or(""));
            listener.on_failover(notification);
        }
    }

    /// Get the best currently available stream for `channel_id`.
    ///
    /// Selection:
    /// 1. If the current active stream is available → keep it (stability).
    /// 2. Otherwise pick the first available stream in priority order
    ///    weighted by health score.
    pub(crate) fn get_best_stream(&self, channel_id: &str) -> Option<StreamInfo> {
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
    pub(crate) fn health_score(&self, channel_id: &str, stream_url: &str) -> Option<f64> {
        self.channels
            .get(channel_id)?
            .iter()
            .find(|s| s.stream.url == stream_url)
            .map(|s| s.health_score)
    }

    /// Returns consecutive failure count for a stream.
    pub(crate) fn consecutive_failures(&self, channel_id: &str, stream_url: &str) -> u32 {
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

    // ── Required spec tests ───────────────────────────────

    #[test]
    fn test_failover_triggers_after_5_consecutive_failures() {
        let mut mgr = FailoverManager::new(Duration::from_secs(3600));
        mgr.register_channel("ch1", vec![stream("url_a"), stream("url_b")]);
        for _ in 0..5 {
            mgr.report_failure("ch1", "url_a");
        }
        // After exactly 5 failures url_a must be backed off and url_b selected.
        let best = mgr.get_best_stream("ch1").unwrap();
        assert_eq!(best.url, "url_b");
        assert!(mgr.should_failover("ch1", "url_a"));
    }

    #[test]
    fn test_failover_does_not_trigger_before_5_failures() {
        let mut mgr = FailoverManager::new(Duration::from_secs(3600));
        mgr.register_channel("ch1", vec![stream("url_a"), stream("url_b")]);
        for _ in 0..4 {
            mgr.report_failure("ch1", "url_a");
        }
        // 4 failures — threshold not yet reached; url_a still available.
        assert!(!mgr.should_failover("ch1", "url_a"));
        let best = mgr.get_best_stream("ch1").unwrap();
        assert_eq!(best.url, "url_a");
    }

    #[test]
    fn test_success_resets_failure_count() {
        let mut mgr = FailoverManager::new(Duration::from_secs(3600));
        mgr.register_channel("ch1", vec![stream("url_a")]);
        for _ in 0..4 {
            mgr.report_failure("ch1", "url_a");
        }
        mgr.record_success("ch1", "url_a");
        assert_eq!(mgr.consecutive_failures("ch1", "url_a"), 0);
        assert!(!mgr.should_failover("ch1", "url_a"));
    }

    #[test]
    fn test_backoff_duration_is_15_minutes() {
        let config = FailoverConfig::default();
        assert_eq!(
            config.retry_after,
            Duration::from_secs(15 * 60),
            "default retry_after must be exactly 15 minutes"
        );
        assert_eq!(
            config.failures_before_failover, 5,
            "default failures_before_failover must be 5"
        );
    }

    #[test]
    fn test_failover_notification_has_undo() {
        use std::sync::{Arc, Mutex};

        #[derive(Default)]
        struct Captured(Mutex<Option<FailoverNotification>>);
        impl FailoverListener for Arc<Captured> {
            fn on_failover(&self, n: FailoverNotification) {
                *self.0.lock().unwrap() = Some(n);
            }
        }

        let captured = Arc::new(Captured::default());
        let mut mgr = FailoverManager::new(Duration::from_secs(3600));
        mgr.set_listener(Arc::clone(&captured));
        mgr.register_channel("ch1", vec![stream("url_a"), stream("url_b")]);

        for _ in 0..5 {
            mgr.report_failure("ch1", "url_a");
        }

        let notification = captured.0.lock().unwrap();
        let n = notification
            .as_ref()
            .expect("listener must have been called");
        assert_eq!(n.failed_source, "url_a");
        assert_eq!(n.new_source, "url_b");
        assert!(n.can_undo, "undo must be available");
        assert_eq!(n.undo_timeout_secs, 3);
    }
}
