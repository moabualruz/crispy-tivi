//! L1 in-memory EPG cache backed by `moka`.
//!
//! Stores `Vec<EpgEntry>` per channel ID with per-entry TTL based
//! on the latest programme's end time. Entries auto-expire when the
//! current show ends (minimum 5 minutes to avoid churn).

use std::sync::Arc;
use std::time::{Duration, Instant};

use moka::sync::Cache;
use moka::Expiry;

use crate::models::EpgEntry;

/// Minimum TTL to avoid excessive cache churn.
const MIN_TTL: Duration = Duration::from_secs(5 * 60);

/// Maximum number of channel entries in the hot cache.
const MAX_CAPACITY: u64 = 2_000;

// ── Custom expiry ──────────────────────────────────────

/// Per-entry TTL: expires when the last programme in the cached
/// list ends. Falls back to `MIN_TTL` if no valid end time.
struct ProgrammeEndExpiry;

impl Expiry<String, Arc<Vec<EpgEntry>>> for ProgrammeEndExpiry {
    fn expire_after_create(
        &self,
        _key: &String,
        value: &Arc<Vec<EpgEntry>>,
        _current_time: Instant,
    ) -> Option<Duration> {
        Some(ttl_from_entries(value))
    }

    fn expire_after_update(
        &self,
        _key: &String,
        value: &Arc<Vec<EpgEntry>>,
        _current_time: Instant,
        _current_duration: Option<Duration>,
    ) -> Option<Duration> {
        Some(ttl_from_entries(value))
    }
}

/// Compute TTL from the latest programme's end time.
fn ttl_from_entries(entries: &[EpgEntry]) -> Duration {
    let now = chrono::Utc::now().naive_utc();
    // Find the programme currently airing (start <= now < end).
    let current_end = entries
        .iter()
        .filter(|e| e.start_time <= now && e.end_time > now)
        .map(|e| e.end_time)
        .max();

    match current_end {
        Some(end) => {
            let secs = (end - now).num_seconds().max(0) as u64;
            Duration::from_secs(secs).max(MIN_TTL)
        }
        None => MIN_TTL,
    }
}

// ── EpgHotCache ────────────────────────────────────────

/// Thread-safe L1 hot cache for EPG data.
#[derive(Clone)]
pub struct EpgHotCache {
    inner: Cache<String, Arc<Vec<EpgEntry>>>,
}

impl EpgHotCache {
    /// Create a new hot cache with programme-end-time TTL.
    pub fn new() -> Self {
        let cache = Cache::builder()
            .max_capacity(MAX_CAPACITY)
            .expire_after(ProgrammeEndExpiry)
            .build();
        Self { inner: cache }
    }

    /// Get cached EPG entries for a channel.
    pub fn get(&self, channel_id: &str) -> Option<Arc<Vec<EpgEntry>>> {
        self.inner.get(channel_id)
    }

    /// Insert EPG entries for a channel.
    pub fn insert(&self, channel_id: String, entries: Vec<EpgEntry>) {
        self.inner.insert(channel_id, Arc::new(entries));
    }

    /// Insert entries for multiple channels at once.
    pub fn insert_batch(&self, entries: impl IntoIterator<Item = (String, Vec<EpgEntry>)>) {
        for (channel_id, epg) in entries {
            self.insert(channel_id, epg);
        }
    }

    /// Invalidate a specific channel's cache.
    pub fn invalidate(&self, channel_id: &str) {
        self.inner.invalidate(channel_id);
    }

    /// Clear the entire cache.
    pub fn clear(&self) {
        self.inner.invalidate_all();
    }

    /// Number of entries currently cached.
    pub fn len(&self) -> u64 {
        self.inner.entry_count()
    }

    /// Whether the cache is empty.
    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }
}

impl Default for EpgHotCache {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::NaiveDateTime;

    fn make_entry(channel: &str, title: &str, start_ts: i64, end_ts: i64) -> EpgEntry {
        EpgEntry {
            channel_id: channel.to_string(),
            title: title.to_string(),
            start_time: NaiveDateTime::from_timestamp_opt(start_ts, 0).unwrap(),
            end_time: NaiveDateTime::from_timestamp_opt(end_ts, 0).unwrap(),
            ..EpgEntry::default()
        }
    }

    #[test]
    fn insert_and_get() {
        let cache = EpgHotCache::new();
        let entries = vec![make_entry("ch1", "News", 1000, 2000)];
        cache.insert("ch1".to_string(), entries.clone());
        let result = cache.get("ch1").unwrap();
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].title, "News");
    }

    #[test]
    fn get_missing_returns_none() {
        let cache = EpgHotCache::new();
        assert!(cache.get("nonexistent").is_none());
    }

    #[test]
    fn invalidate_removes_entry() {
        let cache = EpgHotCache::new();
        cache.insert("ch1".to_string(), vec![]);
        cache.invalidate("ch1");
        assert!(cache.get("ch1").is_none());
    }

    #[test]
    fn clear_empties_cache() {
        let cache = EpgHotCache::new();
        cache.insert("ch1".to_string(), vec![]);
        cache.insert("ch2".to_string(), vec![]);
        cache.clear();
        assert!(cache.is_empty());
    }

    #[test]
    fn ttl_from_entries_uses_min_for_past_shows() {
        let entries = vec![make_entry("ch1", "Old", 100, 200)];
        let ttl = ttl_from_entries(&entries);
        assert_eq!(ttl, MIN_TTL);
    }

    #[test]
    fn ttl_from_entries_uses_min_for_empty() {
        let ttl = ttl_from_entries(&[]);
        assert_eq!(ttl, MIN_TTL);
    }

    #[test]
    fn insert_batch_inserts_multiple() {
        let cache = EpgHotCache::new();
        let batch = vec![
            ("ch1".to_string(), vec![make_entry("ch1", "A", 100, 200)]),
            ("ch2".to_string(), vec![make_entry("ch2", "B", 100, 200)]),
        ];
        cache.insert_batch(batch);
        // Verify via get (entry_count is eventually consistent in moka).
        assert!(cache.get("ch1").is_some());
        assert!(cache.get("ch2").is_some());
    }
}
