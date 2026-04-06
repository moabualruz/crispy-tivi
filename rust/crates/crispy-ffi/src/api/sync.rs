//! FFI wrappers for source synchronisation.
//!
//! Exposes credential verification and full sync for each
//! source type (Xtream, M3U, Stalker) to Flutter via FRB.

use std::sync::Arc;

use anyhow::Result;

use super::{ctx, into_anyhow, json_result};
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

/// Fetch Xtream account and server info.
/// Returns JSON `XtreamAccountInfo`.
pub async fn fetch_xtream_account_info(
    base_url: String,
    username: String,
    password: String,
    accept_invalid_certs: bool,
) -> Result<String> {
    let info = into_anyhow(
        crispy_core::services::xtream_sync::fetch_xtream_account_info(
            &base_url,
            &username,
            &password,
            accept_invalid_certs,
        )
        .await,
    )?;
    json_result(info)
}

/// Full Xtream source sync. Returns JSON `SyncReport`.
///
/// When `enrich_vod_on_sync` is `true`, calls `get_vod_info`
/// per movie to fetch plot, cast, duration, etc. This is slow
/// (~4 min for 12K items) and disabled by default.
pub async fn sync_xtream_source(
    base_url: String,
    username: String,
    password: String,
    source_id: String,
    accept_invalid_certs: bool,
    enrich_vod_on_sync: bool,
) -> Result<String> {
    let service = ctx()?;
    let report = into_anyhow(
        crispy_core::services::xtream_sync::sync_xtream_source(
            &service,
            &base_url,
            &username,
            &password,
            &source_id,
            accept_invalid_certs,
            enrich_vod_on_sync,
        )
        .await,
    )?;
    json_result(report)
}

/// Verify M3U URL connectivity. Returns `true` if reachable.
pub async fn verify_m3u_url(url: String, accept_invalid_certs: bool) -> Result<bool> {
    into_anyhow(crispy_core::services::m3u_sync::verify_m3u_url(&url, accept_invalid_certs).await)
}

/// Full M3U source sync. Returns JSON `SyncReport`.
pub async fn sync_m3u_source(
    url: String,
    source_id: String,
    accept_invalid_certs: bool,
) -> Result<String> {
    let service = ctx()?;
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
    let service = ctx()?;
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

/// Resolve an authenticated stream URL via Stalker's `create_link`.
/// Returns the temporary token-bearing URL for playback.
pub async fn resolve_stalker_stream_url(
    base_url: String,
    mac_address: String,
    cmd: String,
    stream_type: String,
    accept_invalid_certs: bool,
) -> Result<String> {
    into_anyhow(
        crispy_core::services::stalker_sync::resolve_stalker_stream_url(
            &base_url,
            &mac_address,
            &cmd,
            &stream_type,
            accept_invalid_certs,
        )
        .await,
    )
}

/// Fetch Stalker portal user profile. Returns JSON `StalkerProfile`.
pub async fn fetch_stalker_profile(
    base_url: String,
    mac_address: String,
    accept_invalid_certs: bool,
) -> Result<String> {
    let profile = into_anyhow(
        crispy_core::services::stalker_sync::fetch_stalker_profile(
            &base_url,
            &mac_address,
            accept_invalid_certs,
        )
        .await,
    )?;
    json_result(profile)
}

/// Fetch Stalker portal account/subscription info.
/// Returns JSON `StalkerAccountInfo`.
pub async fn fetch_stalker_account_info(
    base_url: String,
    mac_address: String,
    accept_invalid_certs: bool,
) -> Result<String> {
    let info = into_anyhow(
        crispy_core::services::stalker_sync::fetch_stalker_account_info(
            &base_url,
            &mac_address,
            accept_invalid_certs,
        )
        .await,
    )?;
    json_result(info)
}

/// Send a Stalker session keepalive (watchdog) during playback.
pub async fn stalker_keepalive(
    base_url: String,
    mac_address: String,
    cur_play_type: String,
    accept_invalid_certs: bool,
) -> Result<()> {
    into_anyhow(
        crispy_core::services::stalker_sync::stalker_keepalive(
            &base_url,
            &mac_address,
            &cur_play_type,
            accept_invalid_certs,
        )
        .await,
    )
}

/// Fetch detailed VOD metadata for a single movie from a Stalker portal.
/// Returns JSON `VodItem`.
pub async fn fetch_stalker_vod_detail(
    base_url: String,
    mac_address: String,
    movie_id: String,
    source_id: String,
    accept_invalid_certs: bool,
) -> Result<String> {
    let item = into_anyhow(
        crispy_core::services::stalker_sync::fetch_stalker_vod_detail(
            &base_url,
            &mac_address,
            &movie_id,
            &source_id,
            accept_invalid_certs,
        )
        .await,
    )?;
    json_result(item)
}

/// Fetch series season/episode structure from a Stalker portal.
/// Returns JSON array of `VodItem` episodes.
pub async fn fetch_stalker_series_detail(
    base_url: String,
    mac_address: String,
    movie_id: String,
    source_id: String,
    accept_invalid_certs: bool,
) -> Result<String> {
    let episodes = into_anyhow(
        crispy_core::services::stalker_sync::fetch_stalker_series_detail(
            &base_url,
            &mac_address,
            &movie_id,
            &source_id,
            accept_invalid_certs,
        )
        .await,
    )?;
    json_result(episodes)
}

/// Fetch server-side favorite IDs from a Stalker portal.
/// Returns JSON array of ID strings.
pub async fn get_stalker_favorites(
    base_url: String,
    mac_address: String,
    stream_type: String,
    accept_invalid_certs: bool,
) -> Result<String> {
    let favs = into_anyhow(
        crispy_core::services::stalker_sync::get_stalker_favorites(
            &base_url,
            &mac_address,
            &stream_type,
            accept_invalid_certs,
        )
        .await,
    )?;
    json_result(favs)
}

/// Set or remove a server-side favorite on a Stalker portal.
pub async fn set_stalker_favorite(
    base_url: String,
    mac_address: String,
    fav_id: String,
    stream_type: String,
    remove: bool,
    accept_invalid_certs: bool,
) -> Result<()> {
    into_anyhow(
        crispy_core::services::stalker_sync::set_stalker_favorite(
            &base_url,
            &mac_address,
            &fav_id,
            &stream_type,
            remove,
            accept_invalid_certs,
        )
        .await,
    )
}
