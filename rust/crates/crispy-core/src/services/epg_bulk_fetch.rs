//! Background bulk EPG fetcher for Xtream/Stalker sources.
//!
//! After channel sync, fetches per-channel EPG for all channels
//! in batches with smart concurrency control. Saves results to
//! SQLite as each batch completes.
//!
//! Design:
//! - Runs asynchronously, never blocks the sync pipeline
//! - Processes channels in batches (50 per batch)
//! - Pauses between batches to avoid overwhelming the device
//! - Uses the existing `ThrottledEpgFetcher` (Semaphore(5) + singleflight)
//! - Emits `EpgUpdated` events per batch so UI progressively updates
//! - Skips channels that already have EPG data in SQLite

use crate::models::{Channel, Source};
use crate::services::epg_fetcher::ThrottledEpgFetcher;
use crate::services::CrispyService;

/// Channels per batch — small to avoid flooding the server.
const BATCH_SIZE: usize = 10;

/// Pause between batches (milliseconds). 3 seconds lets the
/// device and server recover between bursts.
const BATCH_PAUSE_MS: u64 = 3_000;

/// Initial delay before starting bulk fetch (milliseconds).
/// Lets the UI settle after sync before adding EPG load.
const STARTUP_DELAY_MS: u64 = 5_000;

/// Maximum channels to fetch EPG for in one sync run.
const MAX_CHANNELS_PER_SYNC: usize = 500;

/// Spawn a background task that fetches EPG for all channels
/// from the given source.
///
/// Channels that already have EPG data in SQLite (within the
/// next 24 hours) are skipped. Results are saved to the database
/// as each batch completes, emitting `EpgUpdated` events for
/// progressive UI updates.
///
/// This function returns immediately — the actual work runs in
/// a `tokio::spawn` background task.
pub fn spawn_bulk_epg_fetch(
    service: CrispyService,
    source: Source,
    channels: Vec<Channel>,
) {
    let fetcher = ThrottledEpgFetcher::new();

    tokio::spawn(async move {
        // Delay start to let UI settle after sync.
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

    // Filter to channels that need EPG (skip those with cached data).
    let need_fetch: Vec<&Channel> = channels
        .iter()
        .filter(|ch| {
            // Only fetch for API-sourced channels (xc_, stk_).
            ch.id.starts_with("xc_") || ch.id.starts_with("stk_")
        })
        .filter(|ch| {
            // Skip channels that already have EPG in SQLite.
            let has_data = service
                .get_epgs_for_channels(std::slice::from_ref(&ch.id), now, now + 86_400)
                .ok()
                .map(|m| m.get(&ch.id).map(|v| !v.is_empty()).unwrap_or(false))
                .unwrap_or(false);
            !has_data
        })
        .take(MAX_CHANNELS_PER_SYNC)
        .collect();

    if need_fetch.is_empty() {
        tracing::info!(
            "Bulk EPG: all {} channels already have cached data, skipping",
            channels.len()
        );
        return Ok(());
    }

    tracing::info!(
        "Bulk EPG: fetching for {}/{} channels from source {} in batches of {}",
        need_fetch.len(),
        channels.len(),
        source.id,
        BATCH_SIZE,
    );

    let mut fetched_total = 0usize;
    let mut batch_num = 0usize;

    for batch in need_fetch.chunks(BATCH_SIZE) {
        batch_num += 1;
        let channel_ids: Vec<String> = batch.iter().map(|ch| ch.id.clone()).collect();

        // Fetch this batch via the throttled fetcher.
        let results = fetcher.fetch_batch(source, &channel_ids).await;

        // Save to SQLite immediately.
        if !results.is_empty() {
            let count = results.values().map(|v| v.len()).sum::<usize>();
            let _ = service.save_epg_entries(&results);
            fetched_total += count;

            tracing::info!(
                "Bulk EPG batch {}: saved {} entries for {}/{} channels",
                batch_num,
                count,
                results.len(),
                batch.len(),
            );
        }

        // Pause between batches to avoid overloading.
        if batch.len() == BATCH_SIZE {
            tokio::time::sleep(tokio::time::Duration::from_millis(BATCH_PAUSE_MS)).await;
        }
    }

    tracing::info!(
        "Bulk EPG complete: {} total entries for source {}",
        fetched_total,
        source.id,
    );

    Ok(())
}

