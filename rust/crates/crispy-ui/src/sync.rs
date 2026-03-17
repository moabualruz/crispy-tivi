//! Async sync engine for crispy-ui.
//!
//! Dispatches source synchronization to the appropriate sync function
//! based on source type (M3U, Xtream, Stalker) and updates UI state
//! when complete.

use crispy_core::services::{m3u_sync, stalker_sync, xtream_sync};
use tracing::{error, info};

/// Trigger synchronization of a single source.
///
/// Runs the sync operation in a tokio blocking task (since sync functions are async),
/// then updates the AppState with the result.
///
/// # Arguments
/// * `rt` - tokio runtime handle for spawning tasks
/// * `svc` - CrispyService instance for data access
/// * `source_id` - ID of the source to sync
/// * `source_type` - Type of source ("m3u", "xtream", "stalker")
/// * `ui_weak` - Weak reference to AppWindow for UI updates
pub(crate) fn trigger_sync(
    rt: &tokio::runtime::Handle,
    svc: crispy_server::CrispyService,
    source_id: String,
    source_type: String,
    ui_weak: slint::Weak<super::AppWindow>,
) {
    let svc_clone = svc.clone();
    let source_id_clone = source_id.clone();
    let source_type_clone = source_type.clone();

    // Spawn a blocking task to perform the sync
    rt.spawn_blocking(move || {
        info!(
            "Starting sync for source_id={}, type={}",
            source_id_clone, source_type_clone
        );

        // Fetch the source from the database
        let source = match svc_clone.get_source(&source_id_clone) {
            Ok(Some(s)) => s,
            Ok(None) => {
                error!("Source not found: {}", source_id_clone);
                update_ui(&ui_weak, &source_id_clone, "error", "Source not found");
                return;
            }
            Err(e) => {
                error!("Failed to fetch source: {:?}", e);
                update_ui(
                    &ui_weak,
                    &source_id_clone,
                    "error",
                    &format!("Database error: {:?}", e),
                );
                return;
            }
        };

        // Dispatch based on source type
        let result = match source_type_clone.as_str() {
            "m3u" => {
                let url = source.url.clone();
                let accept_certs = source.accept_self_signed;
                tokio::runtime::Handle::current().block_on(async {
                    m3u_sync::sync_m3u_source(&svc_clone, &url, &source_id_clone, accept_certs)
                        .await
                })
            }
            "xtream" => {
                let base_url = source.url.clone();
                let username = source.username.clone().unwrap_or_default();
                let password = source.password.clone().unwrap_or_default();
                let accept_certs = source.accept_self_signed;
                tokio::runtime::Handle::current().block_on(async {
                    xtream_sync::sync_xtream_source(
                        &svc_clone,
                        &base_url,
                        &username,
                        &password,
                        &source_id_clone,
                        accept_certs,
                    )
                    .await
                })
            }
            "stalker" => {
                let base_url = source.url.clone();
                let mac = source.mac_address.clone().unwrap_or_default();
                let accept_certs = source.accept_self_signed;
                tokio::runtime::Handle::current().block_on(async {
                    stalker_sync::sync_stalker_source(
                        &svc_clone,
                        &base_url,
                        &mac,
                        &source_id_clone,
                        accept_certs,
                    )
                    .await
                })
            }
            other => {
                error!("Unknown source type: {}", other);
                update_ui(
                    &ui_weak,
                    &source_id_clone,
                    "error",
                    &format!("Unknown source type: {}", other),
                );
                return;
            }
        };

        // Handle the result
        match result {
            Ok(report) => {
                info!(
                    "Sync completed for source_id={}. Channels: {}, VOD: {}",
                    source_id_clone, report.channels_count, report.vod_count
                );
                update_ui(
                    &ui_weak,
                    &source_id_clone,
                    "success",
                    &format!(
                        "Synced {} channels and {} VOD items",
                        report.channels_count, report.vod_count
                    ),
                );

                // Reload all data in the UI via the event loop.
                // Use the weak reference (Send) — upgrade inside the event loop closure.
                let svc_reload = svc_clone.clone();
                let ui_weak_reload = ui_weak.clone();
                slint::invoke_from_event_loop(move || {
                    if let Some(ui) = ui_weak_reload.upgrade() {
                        super::data::reload_all(&ui, &svc_reload);
                    }
                })
                .ok();
            }
            Err(e) => {
                error!("Sync failed for source_id={}: {:?}", source_id_clone, e);
                update_ui(
                    &ui_weak,
                    &source_id_clone,
                    "error",
                    &format!("Sync failed: {}", e),
                );
            }
        }
    });
}

/// Trigger synchronization of all enabled sources.
///
/// Iterates through all sources and calls `trigger_sync` for each enabled one.
///
/// # Arguments
/// * `rt` - tokio runtime handle for spawning tasks
/// * `svc` - CrispyService instance for data access
/// * `ui_weak` - Weak reference to AppWindow for UI updates
#[allow(dead_code)]
pub(crate) fn trigger_sync_all(
    rt: &tokio::runtime::Handle,
    svc: crispy_server::CrispyService,
    ui_weak: slint::Weak<super::AppWindow>,
) {
    let svc_clone = svc.clone();

    // Fetch all sources
    match svc_clone.get_sources() {
        Ok(sources) => {
            info!("Syncing {} sources", sources.len());
            for source in sources {
                if source.enabled {
                    trigger_sync(
                        rt,
                        svc_clone.clone(),
                        source.id.clone(),
                        source.source_type.clone(),
                        ui_weak.clone(),
                    );
                }
            }
        }
        Err(e) => {
            error!("Failed to fetch sources for sync_all: {:?}", e);
        }
    }
}

/// Helper to update UI state via event loop.
fn update_ui(
    ui_weak: &slint::Weak<super::AppWindow>,
    source_id: &str,
    status: &str,
    message: &str,
) {
    if ui_weak.upgrade().is_some() {
        let source_id_str = source_id.to_string();
        let status_str = status.to_string();
        let message_str = message.to_string();

        slint::invoke_from_event_loop(move || {
            // Update AppState.is-syncing = false
            // Update AppState.last-sync-result with status and message
            // These will be wired by the integration agent
            let _ = (source_id_str, status_str, message_str);
        })
        .ok();
    }
}
