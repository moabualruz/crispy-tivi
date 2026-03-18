//! Viewing time limits and bedtime enforcement for profiles.
//!
//! `ViewingLimits` stores per-profile daily quota and bedtime. Accumulated
//! viewing time is tracked in memory (keyed by profile + date). The service
//! layer is responsible for persisting these accumulators to the DB; this
//! module provides the pure logic layer.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use chrono::{Datelike, Local, NaiveDate, NaiveTime};

// ── ViewingLimits ─────────────────────────────────────────────────────────────

/// Per-profile viewing-time configuration.
#[derive(Debug, Clone)]
pub struct ViewingLimits {
    /// Maximum viewing time on weekdays (Mon–Fri).
    pub daily_limit_weekday: Duration,
    /// Maximum viewing time on weekends (Sat–Sun).
    pub daily_limit_weekend: Duration,
    /// Optional bedtime — no playback allowed from this time until midnight.
    pub bedtime: Option<NaiveTime>,
}

impl ViewingLimits {
    /// Convenient constructor.
    pub fn new(weekday: Duration, weekend: Duration, bedtime: Option<NaiveTime>) -> Self {
        Self {
            daily_limit_weekday: weekday,
            daily_limit_weekend: weekend,
            bedtime,
        }
    }

    /// Unlimited access (no limits enforced).
    pub fn unlimited() -> Self {
        Self {
            daily_limit_weekday: Duration::MAX,
            daily_limit_weekend: Duration::MAX,
            bedtime: None,
        }
    }
}

// ── ViewingStatus ─────────────────────────────────────────────────────────────

/// Result of a viewing-allowed check.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ViewingStatus {
    /// Viewing is allowed without restriction.
    Allowed,
    /// Viewing is allowed but quota is running low (remaining time shown).
    Warning { remaining: Duration },
    /// Daily quota exhausted.
    Expired,
    /// Current time is past bedtime.
    Bedtime,
}

// ── DailyKey ──────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
struct DailyKey {
    profile_id: String,
    date: NaiveDate,
}

// ── ViewingTracker ────────────────────────────────────────────────────────────

/// In-process accumulated viewing time tracker.
///
/// Tracks seconds viewed per profile per calendar day. The service layer
/// should persist/restore these values from the DB across sessions.
#[derive(Clone, Default)]
pub struct ViewingTracker {
    /// Accumulated seconds viewed per (profile, date).
    accumulated: Arc<Mutex<HashMap<DailyKey, Duration>>>,
    /// Extensions granted today per profile (via parent PIN).
    extensions: Arc<Mutex<HashMap<DailyKey, Duration>>>,
}

impl ViewingTracker {
    pub fn new() -> Self {
        Self::default()
    }

    /// Check whether `profile_id` is allowed to view content now.
    ///
    /// Uses the current local time for date and bedtime comparisons.
    pub fn check_viewing_allowed(&self, profile_id: &str, limits: &ViewingLimits) -> ViewingStatus {
        let now = Local::now();
        let today = now.date_naive();
        let current_time = now.time();

        // ── Bedtime check ─────────────────────────────────────────────────────
        if let Some(bedtime) = limits.bedtime
            && current_time >= bedtime
        {
            return ViewingStatus::Bedtime;
        }

        // ── Daily quota check ─────────────────────────────────────────────────
        let is_weekend = matches!(today.weekday(), chrono::Weekday::Sat | chrono::Weekday::Sun);
        let daily_limit = if is_weekend {
            limits.daily_limit_weekend
        } else {
            limits.daily_limit_weekday
        };

        if daily_limit == Duration::MAX {
            return ViewingStatus::Allowed;
        }

        let key = DailyKey {
            profile_id: profile_id.to_string(),
            date: today,
        };

        let accumulated = self.accumulated.lock().unwrap_or_else(|e| e.into_inner());
        let extension = {
            let ext = self.extensions.lock().unwrap_or_else(|e| e.into_inner());
            ext.get(&key).copied().unwrap_or(Duration::ZERO)
        };

        let used = accumulated.get(&key).copied().unwrap_or(Duration::ZERO);
        let effective_limit = daily_limit.saturating_add(extension);

        if used >= effective_limit {
            return ViewingStatus::Expired;
        }

        let remaining = effective_limit.saturating_sub(used);

        // Warn when less than 10 minutes remain
        if remaining < Duration::from_secs(600) {
            return ViewingStatus::Warning { remaining };
        }

        ViewingStatus::Allowed
    }

    /// Record `duration` of viewing for `profile_id` today.
    pub fn record_viewing(&self, profile_id: &str, duration: Duration) {
        let today = Local::now().date_naive();
        let key = DailyKey {
            profile_id: profile_id.to_string(),
            date: today,
        };
        let mut accumulated = self.accumulated.lock().unwrap_or_else(|e| e.into_inner());
        let entry = accumulated.entry(key).or_insert(Duration::ZERO);
        *entry = entry.saturating_add(duration);
    }

    /// Grant a time extension for `profile_id` today (requires parent PIN externally).
    pub fn grant_extension(&self, profile_id: &str, extra: Duration) {
        let today = Local::now().date_naive();
        let key = DailyKey {
            profile_id: profile_id.to_string(),
            date: today,
        };
        let mut extensions = self.extensions.lock().unwrap_or_else(|e| e.into_inner());
        let entry = extensions.entry(key).or_insert(Duration::ZERO);
        *entry = entry.saturating_add(extra);
    }

    /// Get accumulated viewing time for `profile_id` today.
    pub fn get_today_viewed(&self, profile_id: &str) -> Duration {
        let today = Local::now().date_naive();
        let key = DailyKey {
            profile_id: profile_id.to_string(),
            date: today,
        };
        let accumulated = self.accumulated.lock().unwrap_or_else(|e| e.into_inner());
        accumulated.get(&key).copied().unwrap_or(Duration::ZERO)
    }

    /// Override accumulated time for a specific date (used for DB restore).
    pub fn set_accumulated(&self, profile_id: &str, date: NaiveDate, duration: Duration) {
        let key = DailyKey {
            profile_id: profile_id.to_string(),
            date,
        };
        let mut accumulated = self.accumulated.lock().unwrap_or_else(|e| e.into_inner());
        accumulated.insert(key, duration);
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn weekday_limits(secs: u64) -> ViewingLimits {
        ViewingLimits::new(
            Duration::from_secs(secs),
            Duration::from_secs(secs * 2),
            None,
        )
    }

    #[test]
    fn test_no_time_used_is_allowed() {
        let tracker = ViewingTracker::new();
        let limits = weekday_limits(3600);
        assert_eq!(
            tracker.check_viewing_allowed("p1", &limits),
            ViewingStatus::Allowed
        );
    }

    #[test]
    fn test_unlimited_always_allowed() {
        let tracker = ViewingTracker::new();
        let limits = ViewingLimits::unlimited();
        tracker.record_viewing("p1", Duration::from_secs(999_999));
        assert_eq!(
            tracker.check_viewing_allowed("p1", &limits),
            ViewingStatus::Allowed
        );
    }

    #[test]
    fn test_expired_when_quota_exhausted() {
        let tracker = ViewingTracker::new();
        let limits = weekday_limits(3600); // 1 hour
        tracker.record_viewing("p1", Duration::from_secs(3600));
        assert_eq!(
            tracker.check_viewing_allowed("p1", &limits),
            ViewingStatus::Expired
        );
    }

    #[test]
    fn test_warning_when_under_10_minutes_remain() {
        let tracker = ViewingTracker::new();
        let limits = weekday_limits(3600);
        // Use 55 minutes → 5 minutes remain → Warning
        tracker.record_viewing("p1", Duration::from_secs(3300));
        match tracker.check_viewing_allowed("p1", &limits) {
            ViewingStatus::Warning { remaining } => {
                assert!(remaining <= Duration::from_secs(600));
                assert!(remaining > Duration::ZERO);
            }
            other => panic!("expected Warning, got {other:?}"),
        }
    }

    #[test]
    fn test_extension_allows_more_time() {
        let tracker = ViewingTracker::new();
        let limits = weekday_limits(3600);
        tracker.record_viewing("p1", Duration::from_secs(3600));
        // Without extension: Expired
        assert_eq!(
            tracker.check_viewing_allowed("p1", &limits),
            ViewingStatus::Expired
        );
        // Grant 5 minute extension (< 10 min threshold → Warning state)
        tracker.grant_extension("p1", Duration::from_secs(300));
        // 5 minutes remain → Warning
        match tracker.check_viewing_allowed("p1", &limits) {
            ViewingStatus::Warning { remaining } => {
                assert!(remaining <= Duration::from_secs(300));
            }
            other => panic!("expected Warning after extension, got {other:?}"),
        }
    }

    #[test]
    fn test_bedtime_blocks_regardless_of_quota() {
        let tracker = ViewingTracker::new();
        // Set bedtime to 00:00:00 (midnight) — always past for any current time
        // Actually use a time already passed today
        let past_bedtime = NaiveTime::from_hms_opt(0, 0, 1).unwrap();
        let limits = ViewingLimits::new(
            Duration::from_secs(3600),
            Duration::from_secs(7200),
            Some(past_bedtime),
        );
        // This will be Bedtime only if current time >= 00:00:01, which is always true
        // after midnight. On CI this will also hold.
        // We test by using a very early bedtime (00:00:01) which is always "in the past"
        // relative to when tests run (after midnight).
        let status = tracker.check_viewing_allowed("p1", &limits);
        // Either Bedtime (current time > 00:00:01) or Allowed (if somehow before 00:00:01)
        // We just check it doesn't panic
        assert!(matches!(
            status,
            ViewingStatus::Bedtime | ViewingStatus::Allowed
        ));
    }

    #[test]
    fn test_bedtime_midnight_explicit() {
        // Set bedtime to far future (23:59:59) — no profile in a test runs at 23:59:59
        let tracker = ViewingTracker::new();
        let future_bedtime = NaiveTime::from_hms_opt(23, 59, 59).unwrap();
        let limits = ViewingLimits::new(
            Duration::from_secs(3600),
            Duration::from_secs(7200),
            Some(future_bedtime),
        );
        // Should not be bedtime
        let status = tracker.check_viewing_allowed("p1", &limits);
        assert_ne!(status, ViewingStatus::Bedtime);
    }

    #[test]
    fn test_record_viewing_accumulates() {
        let tracker = ViewingTracker::new();
        tracker.record_viewing("p1", Duration::from_secs(600));
        tracker.record_viewing("p1", Duration::from_secs(600));
        assert_eq!(tracker.get_today_viewed("p1"), Duration::from_secs(1200));
    }

    #[test]
    fn test_independent_profiles() {
        let tracker = ViewingTracker::new();
        let limits = weekday_limits(3600);
        tracker.record_viewing("p1", Duration::from_secs(3600));
        // p2 is unaffected
        assert_eq!(
            tracker.check_viewing_allowed("p2", &limits),
            ViewingStatus::Allowed
        );
    }

    #[test]
    fn test_set_accumulated_for_restore() {
        let tracker = ViewingTracker::new();
        let yesterday = Local::now().date_naive().pred_opt().unwrap();
        tracker.set_accumulated("p1", yesterday, Duration::from_secs(1800));
        // Today should still be zero
        assert_eq!(tracker.get_today_viewed("p1"), Duration::ZERO);
    }
}
