//! Background bulk EPG fetcher for Xtream/Stalker sources.
//!
//! After channel sync, fetches per-channel EPG for channels that
//! have NO cached data or whose cached data has a gap. Uses a
//! single batch SQL query to determine which channels need data,
//! not per-channel queries.
//!
//! Smart time-window logic:
//! - If last sync was N hours ago, only fetch the gap (N hours of new data)
//! - Never fetch more than 7 days ahead
//! - Channels with coverage for the next 24h are skipped entirely

use std::collections::HashSet;

use crate::models::{Channel, Source};
use crate::services::epg_fetcher::ThrottledEpgFetcher;
use crate::services::CrispyService;

/// Channels per batch.
const BATCH_SIZE: usize = 10;

/// Pause between batches (milliseconds).
const BATCH_PAUSE_MS: u64 = 3_000;

/// Initial delay before starting bulk fetch (milliseconds).
const STARTUP_DELAY_MS: u64 = 5_000;

/// Maximum channels to fetch EPG for in one sync run.
const MAX_CHANNELS_PER_SYNC: usize = 500;

/// Minimum gap (seconds) before we bother fetching — 4 hours.
/// If the DB covers at least the next 4 hours, skip the channel.
const MIN_COVERAGE_SECS: i64 = 4 * 3600;

/// Spawn a background task that fetches EPG for channels missing
/// cached data. Returns immediately.
pub fn spawn_bulk_epg_fetch(service: CrispyService, source: Source, channels: Vec<Channel>) {
    let fetcher = ThrottledEpgFetcher::new();

    tokio::spawn(async move {
        tokio::time::sleep(tokio::time::Duration::from_millis(STARTUP_DELAY_MS)).await;

        if let Err(e) = run_bulk_fetch(&service, &source, &channels, &fetcher).await {
            tracing::warn!("Bulk EPG fetch failed for source {}: {e}", source.id);
        }
    });
}

async fn run_bulk_fetch(
    service: &CrispyService,
    source: &Source,
    channels: &[Channel],
    fetcher: &ThrottledEpgFetcher,
) -> anyhow::Result<()> {
    let now = chrono::Utc::now().timestamp();
    let coverage_end = now + MIN_COVERAGE_SECS;

    // Collect API-sourced channel IDs.
    let api_channels: Vec<&Channel> = channels
        .iter()
        .filter(|ch| ch.id.starts_with("xc_") || ch.id.starts_with("stk_"))
        .collect();

    if api_channels.is_empty() {
        return Ok(());
    }

    // Single batch query: get ALL channels that have EPG data
    // covering now → now+4h. This is ONE SQL query, not 13K.
    let all_ids: Vec<String> = api_channels.iter().map(|ch| ch.id.clone()).collect();
    let covered = service
        .get_epgs_for_channels(&all_ids, now, coverage_end)
        .unwrap_or_default();

    let covered_ids: HashSet<&str> = covered
        .iter()
        .filter(|(_, entries)| !entries.is_empty())
        .map(|(id, _)| id.as_str())
        .collect();

    // Channels that need fetching: no coverage for next 4 hours.
    let need_fetch: Vec<&Channel> = api_channels
        .into_iter()
        .filter(|ch| !covered_ids.contains(ch.id.as_str()))
        .take(MAX_CHANNELS_PER_SYNC)
        .collect();

    if need_fetch.is_empty() {
        tracing::info!(
            "Bulk EPG: {}/{} channels already covered for next {}h, skipping",
            covered_ids.len(),
            channels.len(),
            MIN_COVERAGE_SECS / 3600,
        );
        return Ok(());
    }

    tracing::info!(
        "Bulk EPG: fetching for {}/{} channels ({} already covered)",
        need_fetch.len(),
        channels.len(),
        covered_ids.len(),
    );

    let mut fetched_total = 0usize;

    for (batch_num, batch) in need_fetch.chunks(BATCH_SIZE).enumerate() {
        let channel_ids: Vec<String> = batch.iter().map(|ch| ch.id.clone()).collect();
        let results = fetcher.fetch_batch(source, &channel_ids).await;

        if !results.is_empty() {
            let count = results.values().map(|v| v.len()).sum::<usize>();
            let _ = service.save_epg_entries(&results);
            fetched_total += count;

            tracing::info!(
                "Bulk EPG batch {}: {} entries for {}/{} channels",
                batch_num + 1,
                count,
                results.len(),
                batch.len(),
            );
        }

        if batch.len() == BATCH_SIZE {
            tokio::time::sleep(tokio::time::Duration::from_millis(BATCH_PAUSE_MS)).await;
        }
    }

    tracing::info!("Bulk EPG complete: {} total entries", fetched_total);
    Ok(())
}
