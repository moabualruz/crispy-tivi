//! Async sync engine for crispy-ui.
//!
//! Dispatches source synchronization to the appropriate sync function
//! based on source type (M3U, Xtream, Stalker) and updates UI state
//! when complete.

use std::sync::Arc;

use crispy_core::services::{m3u_sync, stalker_sync, xtream_sync};
use slint::ComponentHandle;
use tracing::{error, info};

use super::data::AsyncDataState;

/// Trigger synchronization of a single source.
pub(crate) fn trigger_sync(
    rt: &tokio::runtime::Handle,
    svc: crispy_server::CrispyService,
    source_id: String,
    source_type: String,
    ui_weak: slint::Weak<super::AppWindow>,
    state: Arc<AsyncDataState>,
) {
    let svc_clone = svc.clone();
    let source_id_clone = source_id.clone();
    let source_type_clone = source_type.clone();

    // Set syncing flag
    let ui_weak_flag = ui_weak.clone();
    slint::invoke_from_event_loop(move || {
        if let Some(ui) = ui_weak_flag.upgrade() {
            ui.global::<super::AppState>().set_is_syncing(true);
        }
    })
    .ok();

    rt.spawn_blocking(move || {
        info!(
            "Starting sync for source_id={}, type={}",
            source_id_clone, source_type_clone
        );

        let source = match svc_clone.get_source(&source_id_clone) {
            Ok(Some(s)) => s,
            Ok(None) => {
                error!("Source not found: {}", source_id_clone);
                return;
            }
            Err(e) => {
                error!("Failed to fetch source: {:?}", e);
                return;
            }
        };

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
                return;
            }
        };

        match result {
            Ok(report) => {
                info!(
                    "Sync completed for source_id={}. Channels: {}, VOD: {}",
                    source_id_clone, report.channels_count, report.vod_count
                );

                // Async reload — heavy data loads stay off UI thread
                let rt_handle = tokio::runtime::Handle::current();
                super::data::reload_all_async(
                    &rt_handle,
                    svc_clone.clone(),
                    ui_weak.clone(),
                    state,
                );
            }
            Err(e) => {
                error!("Sync failed for source_id={}: {:?}", source_id_clone, e);
            }
        }

        // Clear syncing flag
        slint::invoke_from_event_loop(move || {
            if let Some(ui) = ui_weak.upgrade() {
                ui.global::<super::AppState>().set_is_syncing(false);
            }
        })
        .ok();
    });
}

/// Trigger synchronization of all enabled sources.
#[allow(dead_code)]
pub(crate) fn trigger_sync_all(
    rt: &tokio::runtime::Handle,
    svc: crispy_server::CrispyService,
    ui_weak: slint::Weak<super::AppWindow>,
    state: Arc<AsyncDataState>,
) {
    let svc_clone = svc.clone();

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
                        state.clone(),
                    );
                }
            }
        }
        Err(e) => {
            error!("Failed to fetch sources for sync_all: {:?}", e);
        }
    }
}
