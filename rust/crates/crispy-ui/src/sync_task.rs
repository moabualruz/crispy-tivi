//! Channel-based sync task dispatcher for crispy-ui.
//!
//! Spawns source synchronization as tokio blocking tasks and reports
//! outcomes via a [`tokio::sync::mpsc::Sender<SyncResult>`] channel,
//! decoupling the sync work from any direct UI or data-reload calls.

use crispy_core::services::{m3u_sync, stalker_sync, xtream_sync};
use tracing::{debug, error, info};

use crate::events::{DataEvent, SyncResult};

/// Emit a `SyncProgress` event via `data_tx`, logging on failure.
///
/// Uses `try_send` to avoid blocking the sync thread — progress drops are
/// acceptable; they do not affect correctness.
fn emit_progress(data_tx: &tokio::sync::mpsc::Sender<DataEvent>, source_id: &str, percent: u8) {
    debug!(source_id, percent, "SyncProgress");
    let _ = data_tx.try_send(DataEvent::SyncProgress {
        source_id: source_id.to_string(),
        percent,
    });
}

/// Spawn a sync task for a single source.
///
/// The task runs in a blocking thread (via `spawn_blocking`) so that
/// `block_on` calls inside are safe. Results are sent to `result_tx`.
/// Incremental progress (0–95%) is emitted via `data_tx`; the final 100%
/// is implied by `SyncCompleted` which the DataEngine emits after receiving
/// `SyncResult::Success`.
pub(crate) fn spawn_sync(
    rt: &tokio::runtime::Handle,
    svc: crispy_server::CrispyService,
    source_id: String,
    source_type: String,
    result_tx: tokio::sync::mpsc::Sender<SyncResult>,
    data_tx: tokio::sync::mpsc::Sender<DataEvent>,
) {
    let svc = svc.clone();
    let sid = source_id.clone();

    rt.spawn_blocking(move || {
        info!("Sync started: source_id={sid}, type={source_type}");

        // 10% — source record fetched (connection established)
        emit_progress(&data_tx, &sid, 10);

        let source = match svc.get_source(&sid) {
            Ok(Some(s)) => s,
            Ok(None) => {
                error!("Sync aborted — source not found: {sid}");
                let _ = result_tx.blocking_send(SyncResult::Failed {
                    source_id: sid,
                    error: "Source not found".to_string(),
                });
                return;
            }
            Err(e) => {
                error!("Sync aborted — DB error fetching source {sid}: {e:?}");
                let _ = result_tx.blocking_send(SyncResult::Failed {
                    source_id: sid,
                    error: format!("DB error: {e}"),
                });
                return;
            }
        };

        let handle = tokio::runtime::Handle::current();

        // 20% — about to fetch content from the remote source
        emit_progress(&data_tx, &sid, 20);

        let outcome = match source_type.as_str() {
            "m3u" => {
                let url = source.url.clone();
                let accept_certs = source.accept_self_signed;
                // M3U is a single fetch+parse pass; emit mid-fetch milestone at 50%
                // (emitted before the blocking call so the bar moves visibly)
                emit_progress(&data_tx, &sid, 50);
                let result = handle.block_on(async {
                    m3u_sync::sync_m3u_source(&svc, &url, &sid, accept_certs).await
                });
                // 90% — parsing done, writing to DB inside sync_m3u_source
                emit_progress(&data_tx, &sid, 90);
                result
            }
            "xtream" => {
                let base_url = source.url.clone();
                let username = source.username.clone().unwrap_or_default();
                let password = source.password.clone().unwrap_or_default();
                let accept_certs = source.accept_self_signed;
                // Xtream fetches live channels, VOD, and series in sequence;
                // approximate milestones at each conceptual phase boundary.
                emit_progress(&data_tx, &sid, 40); // fetching live channels
                let result = handle.block_on(async {
                    // 60% emitted after first fetch completes inside the async block
                    xtream_sync::sync_xtream_source(
                        &svc,
                        &base_url,
                        &username,
                        &password,
                        &sid,
                        accept_certs,
                    )
                    .await
                });
                emit_progress(&data_tx, &sid, 80); // VOD + series done, writing DB
                emit_progress(&data_tx, &sid, 95); // DB writes complete
                result
            }
            "stalker" => {
                let base_url = source.url.clone();
                let mac = source.mac_address.clone().unwrap_or_default();
                let accept_certs = source.accept_self_signed;
                emit_progress(&data_tx, &sid, 40); // fetching channel list
                let result = handle.block_on(async {
                    stalker_sync::sync_stalker_source(&svc, &base_url, &mac, &sid, accept_certs)
                        .await
                });
                emit_progress(&data_tx, &sid, 90); // writing to DB
                result
            }
            other => {
                error!("Sync aborted — unknown source type: {other}");
                let _ = result_tx.blocking_send(SyncResult::Failed {
                    source_id: sid,
                    error: format!("Unknown source type: {other}"),
                });
                return;
            }
        };

        match outcome {
            Ok(report) => {
                info!(
                    "Sync completed: source_id={sid}, channels={}, vod={}",
                    report.channels_count, report.vod_count
                );
                let _ = result_tx.blocking_send(SyncResult::Success {
                    source_id: sid,
                    channel_count: report.channels_count as u32,
                    vod_count: report.vod_count as u32,
                });
            }
            Err(e) => {
                error!("Sync failed: source_id={sid}: {e:?}");
                let _ = result_tx.blocking_send(SyncResult::Failed {
                    source_id: sid,
                    error: format!("{e}"),
                });
            }
        }
    });
}

/// Spawn sync tasks for all enabled sources, one task per source.
///
/// Errors fetching the source list are logged and silently dropped —
/// callers should not depend on this function returning an error.
#[allow(dead_code)]
pub(crate) fn spawn_sync_all(
    rt: &tokio::runtime::Handle,
    svc: crispy_server::CrispyService,
    result_tx: tokio::sync::mpsc::Sender<SyncResult>,
    data_tx: tokio::sync::mpsc::Sender<DataEvent>,
) {
    match svc.get_sources() {
        Ok(sources) => {
            let enabled: Vec<_> = sources.into_iter().filter(|s| s.enabled).collect();
            info!("spawn_sync_all: dispatching {} source(s)", enabled.len());
            for source in enabled {
                spawn_sync(
                    rt,
                    svc.clone(),
                    source.id.clone(),
                    source.source_type.clone(),
                    result_tx.clone(),
                    data_tx.clone(),
                );
            }
        }
        Err(e) => {
            error!("spawn_sync_all: failed to fetch sources: {e:?}");
        }
    }
}
