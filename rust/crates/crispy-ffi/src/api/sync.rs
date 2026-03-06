//! FFI wrappers for source synchronisation.
//!
//! Exposes credential verification and full sync for each
//! source type (Xtream, M3U, Stalker) to Flutter via FRB.

use std::sync::Arc;

use anyhow::Result;

use super::{into_anyhow, json_result, svc};
use crate::frb_generated::StreamSink;

/// Subscribe to sync progress events from Rust.
/// Returns a `Stream<String>` of JSON-encoded `SyncProgress`
/// objects on the Dart side.
pub fn subscribe_sync_progress(sink: StreamSink<String>) {
    let sink = Arc::new(sink);
    crispy_core::sync_progress::set_progress_callback(Arc::new(
        move |p: &crispy_core::models::SyncProgress| {
            if let Ok(json) = serde_json::to_string(p) {
                let _ = sink.add(json);
            }
        },
    ));
}

/// Verify Xtream credentials. Returns `true` if authenticated.
pub async fn verify_xtream_credentials(
    base_url: String,
    username: String,
    password: String,
    accept_invalid_certs: bool,
) -> Result<bool> {
    into_anyhow(
        crispy_core::services::xtream_sync::verify_xtream_credentials(
            &base_url,
            &username,
            &password,
            accept_invalid_certs,
        )
        .await,
    )
}

/// Full Xtream source sync. Returns JSON `SyncReport`.
pub async fn sync_xtream_source(
    base_url: String,
    username: String,
    password: String,
    source_id: String,
    accept_invalid_certs: bool,
) -> Result<String> {
    let service = svc()?;
    let report = into_anyhow(
        crispy_core::services::xtream_sync::sync_xtream_source(
            &service,
            &base_url,
            &username,
            &password,
            &source_id,
            accept_invalid_certs,
        )
        .await,
    )?;
    json_result(report)
}

/// Full M3U source sync. Returns JSON `SyncReport`.
pub async fn sync_m3u_source(
    url: String,
    source_id: String,
    accept_invalid_certs: bool,
) -> Result<String> {
    let service = svc()?;
    let report = into_anyhow(
        crispy_core::services::m3u_sync::sync_m3u_source(
            &service,
            &url,
            &source_id,
            accept_invalid_certs,
        )
        .await,
    )?;
    json_result(report)
}

/// Verify Stalker portal MAC authentication. Returns `true` if accepted.
pub async fn verify_stalker_portal(
    base_url: String,
    mac_address: String,
    accept_invalid_certs: bool,
) -> Result<bool> {
    into_anyhow(
        crispy_core::services::stalker_sync::verify_stalker_portal(
            &base_url,
            &mac_address,
            accept_invalid_certs,
        )
        .await,
    )
}

/// Full Stalker portal sync. Returns JSON `SyncReport`.
pub async fn sync_stalker_source(
    base_url: String,
    mac_address: String,
    source_id: String,
    accept_invalid_certs: bool,
) -> Result<String> {
    let service = svc()?;
    let report = into_anyhow(
        crispy_core::services::stalker_sync::sync_stalker_source(
            &service,
            &base_url,
            &mac_address,
            &source_id,
            accept_invalid_certs,
        )
        .await,
    )?;
    json_result(report)
}
