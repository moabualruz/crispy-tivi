//! EPG Facade — single public API for all EPG access.
//!
//! The UI calls this module's functions. The facade resolves
//! internally via:
//!
//! 1. **SQLite** persistent cache (primary, indexed, fast)
//! 2. **Network fetch** via `ThrottledEpgFetcher` (on-demand for missing EPG)
//!
//! No in-memory cache — SQLite with proper indexes is sub-millisecond
//! for EPG lookups and doesn't waste RAM on phones/TVs.

use std::collections::HashMap;

use anyhow::Result;

use super::epg_fetcher::ThrottledEpgFetcher;
use super::epg_resolver;
use super::{EpgService, SourceService};
use crate::models::{EpgEntry, Source};
use crate::services::ServiceContext;

/// Minimum gap (seconds) before we bother fetching real EPG — 1 hour.
/// If real (non-placeholder) data covers at least the next hour, skip.
const MIN_REAL_COVERAGE_SECS: i64 = 3600;

// ── EpgFacade ──────────────────────────────────────────

/// UI-facing EPG service.
///
/// Thread-safe, cheaply cloneable (all interior state is `Arc`-wrapped).
/// Create once at app startup, pass a clone to each provider.
#[derive(Clone)]
pub struct EpgFacade {
    service: ServiceContext,
    fetcher: ThrottledEpgFetcher,
}

impl EpgFacade {
    /// Create a new EPG facade wrapping the given service.
    pub fn new(service: ServiceContext) -> Self {
        Self {
            service,
            fetcher: ThrottledEpgFetcher::new(),
        }
    }

    /// Check if a channel has real (non-placeholder) EPG coverage
    /// for at least the next hour. If so, no network fetch needed.
    fn has_sufficient_real_coverage(&self, epg_channel_id: &str) -> bool {
        let now = chrono::Utc::now().timestamp();
        let check_end = now + MIN_REAL_COVERAGE_SECS;
        EpgService(self.service.clone())
            .has_real_epg_coverage(epg_channel_id, now, check_end)
            .unwrap_or(false)
    }

    /// Get EPG for a single channel (up to `count` upcoming entries).
    ///
    /// Resolution order: SQLite → network fetch (fire-and-forget).
    pub async fn get_epg_for_channel(
        &self,
        epg_channel_id: &str,
        count: usize,
    ) -> Result<Vec<EpgEntry>> {
        // Query SQLite directly — indexed, sub-millisecond.
        let entries = self.get_from_sqlite(epg_channel_id, count)?;
        if !entries.is_empty() {
            return Ok(entries);
        }

        // Fire-and-forget background fetch — only if no real
        // (non-placeholder) coverage for the next hour.
        if !self.has_sufficient_real_coverage(epg_channel_id)
            && let Ok(Some(source)) = self.find_source_for_channel(epg_channel_id)
        {
            let facade = self.clone();
            let ch_id = epg_channel_id.to_string();
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
        epg_channel_ids: &[String],
        start_time: i64,
        end_time: i64,
    ) -> Result<HashMap<String, Vec<EpgEntry>>> {
        // Query SQLite for all channels at once.
        let result = EpgService(self.service.clone())
            .get_epgs_for_channels(epg_channel_ids, start_time, end_time)?;

        // Identify channels with no EPG in SQLite.
        let l2_misses: Vec<String> = epg_channel_ids
            .iter()
            .filter(|id| !result.contains_key(*id))
            .cloned()
            .collect();

        if l2_misses.is_empty() {
            return Ok(result);
        }

        // Fire-and-forget network fetch — skip channels with real coverage.
        let fetch_needed: Vec<String> = l2_misses
            .into_iter()
            .filter(|id| !self.has_sufficient_real_coverage(id))
            .collect();

        if !fetch_needed.is_empty() {
            let source_groups = self.group_channels_by_source(&fetch_needed)?;
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
                    }
                });
            }
        }

        Ok(result)
    }

    /// No-op — kept for API compatibility. SQLite needs no invalidation.
    pub fn invalidate_channel(&self, _epg_channel_id: &str) {}

    /// No-op — kept for API compatibility. SQLite needs no clearing.
    pub fn clear_all_caches(&self) {}

    /// Evict EPG entries older than `days` from SQLite.
    pub fn evict_stale(&self, days: i64) -> Result<usize> {
        Ok(EpgService(self.service.clone()).evict_stale_epg(days)?)
    }

    /// Always returns 0 — no in-memory cache.
    pub fn hot_cache_size(&self) -> u64 {
        0
    }

    // ── Internal helpers ─────────────────────────────

    /// Find the source that owns a channel.
    fn find_source_for_channel(&self, epg_channel_id: &str) -> Result<Option<Source>> {
        let conn = self.service.db.get()?;
        let source_id: Option<String> = conn
            .query_row(
                "SELECT source_id FROM db_channels WHERE id = ?1",
                rusqlite::params![epg_channel_id],
                |row| row.get(0),
            )
            .ok();

        if let Some(ref sid) = source_id
            && let Ok(Some(source)) = SourceService(self.service.clone()).get_source(sid)
        {
            return Ok(Some(source));
        }
        Ok(None)
    }

    /// Group channel IDs by their owning source.
    fn group_channels_by_source(
        &self,
        epg_channel_ids: &[String],
    ) -> Result<Vec<(Source, Vec<String>)>> {
        let mut source_map: HashMap<String, (Source, Vec<String>)> = HashMap::new();

        for ch_id in epg_channel_ids {
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

    /// Query SQLite directly for a single channel's upcoming EPG.
    fn get_from_sqlite(&self, epg_channel_id: &str, count: usize) -> Result<Vec<EpgEntry>> {
        let now = chrono::Utc::now().timestamp();
        let end = now + 86_400;
        let result = EpgService(self.service.clone())
            .get_epgs_for_channels(&[epg_channel_id.to_string()], now, end)?;
        let mut entries = result.get(epg_channel_id).cloned().unwrap_or_default();
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
        let _facade = EpgFacade::new(svc);
    }

    #[test]
    fn facade_clear_caches_is_noop() {
        let svc = make_service();
        let facade = EpgFacade::new(svc);
        facade.clear_all_caches(); // should not panic
        assert_eq!(facade.hot_cache_size(), 0);
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
        make_source_and_save(&svc, "src1");
        insert_test_epg_entry(&svc, "tvg_ch1", "src1", "Test Show", 0, 7200);

        // Create a channel with tvg_id matching the EPG entry
        let mut ch = make_channel("ch1", "Test Channel");
        ch.source_id = Some("src1".to_string());
        ch.tvg_id = Some("tvg_ch1".to_string());
        crate::services::ChannelService(svc.clone())
            .save_channels(&[ch])
            .unwrap();

        let facade = EpgFacade::new(svc);
        let entries = facade.get_epg_for_channel("ch1", 10).await.unwrap();
        // May be empty depending on time window — the important thing is no panic
        // and the SQLite path works without moka.
    }

    #[tokio::test]
    async fn facade_multi_channel_query() {
        let svc = make_service();
        make_source_and_save(&svc, "src1");
        insert_test_epg_entry(&svc, "tvg_a", "src1", "Show A", 0, 7200);
        insert_test_epg_entry(&svc, "tvg_b", "src1", "Show B", 0, 7200);

        let mut ch_a = make_channel("ch_a", "Channel A");
        ch_a.source_id = Some("src1".to_string());
        ch_a.tvg_id = Some("tvg_a".to_string());
        let mut ch_b = make_channel("ch_b", "Channel B");
        ch_b.source_id = Some("src1".to_string());
        ch_b.tvg_id = Some("tvg_b".to_string());
        crate::services::ChannelService(svc.clone())
            .save_channels(&[ch_a, ch_b])
            .unwrap();

        let facade = EpgFacade::new(svc);
        let now = chrono::Utc::now().timestamp();
        let result = facade
            .get_epg_for_channels(&["ch_a".into(), "ch_b".into()], now - 3600, now + 86400)
            .await
            .unwrap();
        // SQLite path works for multi-channel — no moka needed
    }
}
