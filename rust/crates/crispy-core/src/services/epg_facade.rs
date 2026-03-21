//! EPG Facade — single public API for all EPG access.
//!
//! The UI calls this module's functions. The facade resolves
//! internally via the 3-layer cache:
//!
//! 1. **L1**: `EpgHotCache` (moka in-memory, per-entry TTL)
//! 2. **L2**: SQLite persistent cache
//! 3. **L3**: Network fetch via `ThrottledEpgFetcher`
//!
//! The UI never needs to know the source type.

use std::collections::HashMap;

use anyhow::Result;

use super::epg_fetcher::ThrottledEpgFetcher;
use super::epg_hot_cache::EpgHotCache;
use super::epg_resolver;
use crate::models::{EpgEntry, Source};
use crate::services::CrispyService;

// ── EpgFacade ──────────────────────────────────────────

/// UI-facing EPG service.
///
/// Thread-safe, cheaply cloneable (all interior state is `Arc`-wrapped).
/// Create once at app startup, pass a clone to each provider.
#[derive(Clone)]
pub struct EpgFacade {
    service: CrispyService,
    hot_cache: EpgHotCache,
    fetcher: ThrottledEpgFetcher,
}

impl EpgFacade {
    /// Create a new EPG facade wrapping the given service.
    pub fn new(service: CrispyService) -> Self {
        Self {
            service,
            hot_cache: EpgHotCache::new(),
            fetcher: ThrottledEpgFetcher::new(),
        }
    }

    /// Get EPG for a single channel (up to `count` upcoming entries).
    ///
    /// Resolution order: L1 hot cache → L2 SQLite → L3 network fetch.
    /// Results are written through to both caches.
    pub async fn get_epg_for_channel(
        &self,
        channel_id: &str,
        count: usize,
    ) -> Result<Vec<EpgEntry>> {
        // L1: Check hot cache.
        if let Some(cached) = self.hot_cache.get(channel_id) {
            let now = chrono::Utc::now().naive_utc();
            let mut upcoming: Vec<EpgEntry> = cached
                .iter()
                .filter(|e| e.end_time > now)
                .cloned()
                .collect();
            if !upcoming.is_empty() {
                upcoming.sort_by_key(|e| e.start_time);
                upcoming.truncate(count);
                return Ok(upcoming);
            }
        }

        // L2: Check SQLite.
        let l2_entries = self.get_from_sqlite_only(channel_id, count)?;
        if !l2_entries.is_empty() {
            self.hot_cache
                .insert(channel_id.to_string(), l2_entries.clone());
            return Ok(l2_entries);
        }

        // L3: Fire-and-forget background fetch for this channel.
        // Return empty now — EpgUpdated event will trigger re-read.
        if let Ok(Some(source)) = self.find_source_for_channel(channel_id) {
            let facade = self.clone();
            let ch_id = channel_id.to_string();
            tokio::spawn(async move {
                let _ = epg_resolver::resolve_epg_for_channel(
                    &facade.service,
                    &source,
                    &ch_id,
                    count,
                    &facade.fetcher,
                )
                .await;
            });
        }

        Ok(vec![])
    }

    /// Get EPG for multiple channels within a time window.
    ///
    /// Used by the EPG grid/timeline view.
    pub async fn get_epg_for_channels(
        &self,
        channel_ids: &[String],
        start_time: i64,
        end_time: i64,
    ) -> Result<HashMap<String, Vec<EpgEntry>>> {
        // Check L1 for all channels.
        let mut result: HashMap<String, Vec<EpgEntry>> = HashMap::new();
        let mut l1_misses: Vec<String> = Vec::new();

        let start_dt = chrono::DateTime::from_timestamp(start_time, 0)
            .unwrap_or_default()
            .naive_utc();
        let end_dt = chrono::DateTime::from_timestamp(end_time, 0)
            .unwrap_or_default()
            .naive_utc();

        for ch_id in channel_ids {
            if let Some(cached) = self.hot_cache.get(ch_id) {
                let windowed: Vec<EpgEntry> = cached
                    .iter()
                    .filter(|e| e.end_time > start_dt && e.start_time < end_dt)
                    .cloned()
                    .collect();
                if !windowed.is_empty() {
                    result.insert(ch_id.clone(), windowed);
                    continue;
                }
            }
            l1_misses.push(ch_id.clone());
        }

        if l1_misses.is_empty() {
            return Ok(result);
        }

        // L2: Query SQLite for all misses at once.
        let l2_result = self
            .service
            .get_epgs_for_channels(&l1_misses, start_time, end_time)?;

        // Identify channels still missing after L2.
        let mut l3_needed: Vec<String> = Vec::new();
        for ch_id in &l1_misses {
            if let Some(entries) = l2_result.get(ch_id)
                && !entries.is_empty()
            {
                // L1 fill.
                self.hot_cache.insert(ch_id.clone(), entries.clone());
                result.insert(ch_id.clone(), entries.clone());
                continue;
            }
            l3_needed.push(ch_id.clone());
        }

        if l3_needed.is_empty() {
            return Ok(result);
        }

        // L3: Fire-and-forget background fetch for missing channels.
        // Return L1+L2 results immediately — don't block the UI.
        // Fetched data is saved to SQLite (L2) and EpgUpdated events
        // notify Flutter to re-read via the invalidation pipeline.
        let source_groups = self.group_channels_by_source(&l3_needed)?;
        if !source_groups.is_empty() {
            let facade = self.clone();
            tokio::spawn(async move {
                for (source, ch_ids) in source_groups {
                    let _ = epg_resolver::resolve_epg_for_channels(
                        &facade.service,
                        &source,
                        &ch_ids,
                        start_time,
                        end_time,
                        &facade.fetcher,
                    )
                    .await;
                    // Results are already saved to L2 by the resolver.
                    // Hot cache fill happens on next read.
                }
            });
        }

        Ok(result)
    }

    /// Invalidate the hot cache for a channel (e.g. after manual EPG refresh).
    pub fn invalidate_channel(&self, channel_id: &str) {
        self.hot_cache.invalidate(channel_id);
    }

    /// Clear all caches.
    pub fn clear_all_caches(&self) {
        self.hot_cache.clear();
    }

    /// Evict EPG entries older than `days` from SQLite.
    pub fn evict_stale(&self, days: i64) -> Result<usize> {
        Ok(self.service.evict_stale_epg(days)?)
    }

    /// Number of channels in the L1 hot cache.
    pub fn hot_cache_size(&self) -> u64 {
        self.hot_cache.len()
    }

    // ── Internal helpers ─────────────────────────────

    /// Find the source that owns a channel.
    fn find_source_for_channel(&self, channel_id: &str) -> Result<Option<Source>> {
        let conn = self.service.db.get()?;
        let source_id: Option<String> = conn
            .query_row(
                "SELECT source_id FROM db_channels WHERE id = ?1",
                rusqlite::params![channel_id],
                |row| row.get(0),
            )
            .ok();

        if let Some(ref sid) = source_id
            && let Ok(Some(source)) = self.service.get_source(sid)
        {
            return Ok(Some(source));
        }
        Ok(None)
    }

    /// Group channel IDs by their owning source.
    fn group_channels_by_source(
        &self,
        channel_ids: &[String],
    ) -> Result<Vec<(Source, Vec<String>)>> {
        let mut source_map: HashMap<String, (Source, Vec<String>)> = HashMap::new();

        for ch_id in channel_ids {
            if let Ok(Some(source)) = self.find_source_for_channel(ch_id) {
                source_map
                    .entry(source.id.clone())
                    .or_insert_with(|| (source, Vec::new()))
                    .1
                    .push(ch_id.clone());
            }
        }

        Ok(source_map.into_values().collect())
    }

    /// Fallback: query SQLite directly for channels without a
    /// recognizable source (e.g. M3U with XMLTV EPG stored by tvg_id).
    fn get_from_sqlite_only(&self, channel_id: &str, count: usize) -> Result<Vec<EpgEntry>> {
        let now = chrono::Utc::now().timestamp();
        let end = now + 86_400;
        let result = self
            .service
            .get_epgs_for_channels(&[channel_id.to_string()], now, end)?;
        let mut entries = result.get(channel_id).cloned().unwrap_or_default();
        entries.sort_by_key(|e| e.start_time);
        entries.truncate(count);
        Ok(entries)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::services::test_helpers::*;

    #[test]
    fn facade_creation() {
        let svc = make_service();
        let facade = EpgFacade::new(svc);
        assert_eq!(facade.hot_cache_size(), 0);
    }

    #[test]
    fn facade_clear_caches() {
        let svc = make_service();
        let facade = EpgFacade::new(svc);
        facade.hot_cache.insert("ch1".to_string(), vec![]);
        facade.clear_all_caches();
        assert!(facade.hot_cache.is_empty());
    }

    #[tokio::test]
    async fn facade_returns_empty_for_unknown_channel() {
        let svc = make_service();
        let facade = EpgFacade::new(svc);
        let result = facade.get_epg_for_channel("nonexistent", 10).await.unwrap();
        assert!(result.is_empty());
    }

    #[tokio::test]
    async fn facade_returns_cached_sqlite_data() {
        let svc = make_service();
        let ch = make_channel("ch1", "Test");
        svc.save_channels(&[ch]).unwrap();

        let now = chrono::Utc::now().timestamp();
        let entry = EpgEntry {
            channel_id: "ch1".to_string(),
            title: "Current Show".to_string(),
            start_time: chrono::DateTime::from_timestamp(now - 1800, 0)
                .unwrap()
                .naive_utc(),
            end_time: chrono::DateTime::from_timestamp(now + 1800, 0)
                .unwrap()
                .naive_utc(),
            ..EpgEntry::default()
        };
        let mut map = HashMap::new();
        map.insert("ch1".to_string(), vec![entry]);
        svc.save_epg_entries(&map).unwrap();

        let facade = EpgFacade::new(svc);
        let result = facade.get_epg_for_channel("ch1", 10).await.unwrap();
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].title, "Current Show");

        // Second call should hit L1 cache.
        assert!(facade.hot_cache.get("ch1").is_some());
    }

    #[tokio::test]
    async fn facade_multi_channel_query() {
        let svc = make_service();
        let ch1 = make_channel("ch1", "One");
        let ch2 = make_channel("ch2", "Two");
        svc.save_channels(&[ch1, ch2]).unwrap();

        let now = chrono::Utc::now().timestamp();
        let make_entry = |ch: &str, title: &str| EpgEntry {
            channel_id: ch.to_string(),
            title: title.to_string(),
            start_time: chrono::DateTime::from_timestamp(now - 1800, 0)
                .unwrap()
                .naive_utc(),
            end_time: chrono::DateTime::from_timestamp(now + 1800, 0)
                .unwrap()
                .naive_utc(),
            ..EpgEntry::default()
        };
        let mut map = HashMap::new();
        map.insert("ch1".to_string(), vec![make_entry("ch1", "Show A")]);
        map.insert("ch2".to_string(), vec![make_entry("ch2", "Show B")]);
        svc.save_epg_entries(&map).unwrap();

        let facade = EpgFacade::new(svc);
        let result = facade
            .get_epg_for_channels(
                &["ch1".to_string(), "ch2".to_string()],
                now - 3600,
                now + 3600,
            )
            .await
            .unwrap();

        assert_eq!(result.len(), 2);
        assert!(result.contains_key("ch1"));
        assert!(result.contains_key("ch2"));
    }

    #[test]
    fn evict_stale_delegates_to_service() {
        let svc = make_service();
        let facade = EpgFacade::new(svc);
        // No entries to evict — should return 0.
        let deleted = facade.evict_stale(7).unwrap();
        assert_eq!(deleted, 0);
    }
}
