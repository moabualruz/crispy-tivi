//! Parental activity log — what was watched, when, and for how long.
//!
//! Activity entries record viewing events per profile. Entries older than
//! 90 days are pruned on each `purge_old_entries` call.
//!
//! This module provides in-process storage backed by the `Database`; the
//! caller must wire DB operations through `CrispyService`.

use std::sync::{Arc, Mutex};

use chrono::{Duration as ChronoDuration, NaiveDate, NaiveDateTime, Utc};

// ── ActivityEntry ─────────────────────────────────────────────────────────────

/// A single recorded viewing event.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ActivityEntry {
    /// Profile that watched this content.
    pub profile_id: String,
    /// Content identifier (channel ID, VOD item ID, etc.).
    pub content_id: String,
    /// Human-readable content title (for display in parent dashboard).
    pub content_title: String,
    /// Date-only field for grouping (time is intentionally omitted for privacy).
    pub date: NaiveDate,
    /// Wall-clock start time (UTC) — used for ordering and deduplication.
    pub started_at: NaiveDateTime,
    /// How long this session lasted.
    pub duration_secs: u64,
}

// ── ActivityLog ───────────────────────────────────────────────────────────────

/// In-process activity log store.
///
/// Entries are appended via `log_viewing`; old entries (>90 days) are pruned
/// by `purge_old_entries`. Queries return filtered/sorted slices.
#[derive(Clone, Default)]
pub struct ActivityLog {
    entries: Arc<Mutex<Vec<ActivityEntry>>>,
}

impl ActivityLog {
    pub fn new() -> Self {
        Self::default()
    }

    /// Log a viewing session.
    ///
    /// - `profile_id` — profile that watched
    /// - `content_id` — channel/VOD identifier
    /// - `content_title` — human-readable title
    /// - `started_at` — UTC timestamp of session start
    /// - `duration_secs` — how long the session lasted
    pub fn log_viewing(
        &self,
        profile_id: impl Into<String>,
        content_id: impl Into<String>,
        content_title: impl Into<String>,
        started_at: NaiveDateTime,
        duration_secs: u64,
    ) {
        let entry = ActivityEntry {
            profile_id: profile_id.into(),
            content_id: content_id.into(),
            content_title: content_title.into(),
            date: started_at.date(),
            started_at,
            duration_secs,
        };
        let mut entries = self.entries.lock().unwrap_or_else(|e| e.into_inner());
        entries.push(entry);
    }

    /// Retrieve activity for `profile_id` within `[from, to]` (inclusive dates).
    ///
    /// Results are sorted by `started_at` ascending.
    pub fn get_activity(
        &self,
        profile_id: &str,
        from: NaiveDate,
        to: NaiveDate,
    ) -> Vec<ActivityEntry> {
        let entries = self.entries.lock().unwrap_or_else(|e| e.into_inner());
        let mut result: Vec<ActivityEntry> = entries
            .iter()
            .filter(|e| e.profile_id == profile_id && e.date >= from && e.date <= to)
            .cloned()
            .collect();
        result.sort_by_key(|e| e.started_at);
        result
    }

    /// Remove all entries older than 90 days from UTC now.
    pub fn purge_old_entries(&self) {
        let cutoff = (Utc::now() - ChronoDuration::days(90)).naive_utc();
        let mut entries = self.entries.lock().unwrap_or_else(|e| e.into_inner());
        entries.retain(|e| e.started_at >= cutoff);
    }

    /// Total number of stored entries (for testing / diagnostics).
    pub fn entry_count(&self) -> usize {
        self.entries.lock().unwrap_or_else(|e| e.into_inner()).len()
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::TimeZone;

    fn dt(year: i32, month: u32, day: u32, h: u32, m: u32) -> NaiveDateTime {
        Utc.with_ymd_and_hms(year, month, day, h, m, 0)
            .unwrap()
            .naive_utc()
    }

    #[test]
    fn test_log_and_retrieve_activity() {
        let log = ActivityLog::new();
        let start = dt(2026, 3, 10, 20, 0);
        log.log_viewing("p1", "ch-news", "CNN", start, 1800);

        let from = NaiveDate::from_ymd_opt(2026, 3, 10).unwrap();
        let to = NaiveDate::from_ymd_opt(2026, 3, 10).unwrap();
        let entries = log.get_activity("p1", from, to);
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].content_id, "ch-news");
        assert_eq!(entries[0].duration_secs, 1800);
    }

    #[test]
    fn test_get_activity_date_range_filter() {
        let log = ActivityLog::new();
        log.log_viewing("p1", "ch1", "News", dt(2026, 3, 1, 10, 0), 600);
        log.log_viewing("p1", "ch2", "Movies", dt(2026, 3, 15, 10, 0), 600);
        log.log_viewing("p1", "ch3", "Sports", dt(2026, 3, 31, 10, 0), 600);

        let from = NaiveDate::from_ymd_opt(2026, 3, 10).unwrap();
        let to = NaiveDate::from_ymd_opt(2026, 3, 20).unwrap();
        let entries = log.get_activity("p1", from, to);
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].content_id, "ch2");
    }

    #[test]
    fn test_get_activity_isolates_profiles() {
        let log = ActivityLog::new();
        log.log_viewing("alice", "ch1", "News", dt(2026, 3, 10, 10, 0), 600);
        log.log_viewing("bob", "ch2", "Movies", dt(2026, 3, 10, 10, 0), 600);

        let from = NaiveDate::from_ymd_opt(2026, 3, 10).unwrap();
        let to = NaiveDate::from_ymd_opt(2026, 3, 10).unwrap();
        let alice = log.get_activity("alice", from, to);
        assert_eq!(alice.len(), 1);
        assert_eq!(alice[0].content_id, "ch1");
    }

    #[test]
    fn test_get_activity_sorted_by_started_at() {
        let log = ActivityLog::new();
        log.log_viewing("p1", "ch3", "C", dt(2026, 3, 10, 22, 0), 60);
        log.log_viewing("p1", "ch1", "A", dt(2026, 3, 10, 18, 0), 60);
        log.log_viewing("p1", "ch2", "B", dt(2026, 3, 10, 20, 0), 60);

        let from = NaiveDate::from_ymd_opt(2026, 3, 10).unwrap();
        let to = NaiveDate::from_ymd_opt(2026, 3, 10).unwrap();
        let entries = log.get_activity("p1", from, to);
        assert_eq!(entries[0].content_id, "ch1");
        assert_eq!(entries[1].content_id, "ch2");
        assert_eq!(entries[2].content_id, "ch3");
    }

    #[test]
    fn test_purge_removes_old_entries() {
        let log = ActivityLog::new();
        // Entry from 100 days ago (beyond 90-day window)
        let old = Utc::now().naive_utc() - ChronoDuration::days(100);
        log.log_viewing("p1", "old-ch", "Old Show", old, 600);
        // Recent entry
        let recent = Utc::now().naive_utc() - ChronoDuration::days(1);
        log.log_viewing("p1", "new-ch", "New Show", recent, 600);

        assert_eq!(log.entry_count(), 2);
        log.purge_old_entries();
        assert_eq!(log.entry_count(), 1);

        let from = NaiveDate::from_ymd_opt(2000, 1, 1).unwrap();
        let to = NaiveDate::from_ymd_opt(2099, 1, 1).unwrap();
        let remaining = log.get_activity("p1", from, to);
        assert_eq!(remaining[0].content_id, "new-ch");
    }

    #[test]
    fn test_purge_keeps_recent_entries() {
        let log = ActivityLog::new();
        let recent = Utc::now().naive_utc() - ChronoDuration::days(30);
        log.log_viewing("p1", "ch1", "Show", recent, 600);

        log.purge_old_entries();
        assert_eq!(log.entry_count(), 1);
    }

    #[test]
    fn test_empty_log_returns_empty() {
        let log = ActivityLog::new();
        let from = NaiveDate::from_ymd_opt(2026, 1, 1).unwrap();
        let to = NaiveDate::from_ymd_opt(2026, 12, 31).unwrap();
        assert!(log.get_activity("p1", from, to).is_empty());
    }
}
