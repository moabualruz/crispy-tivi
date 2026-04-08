//! Stalker Portal (MAG middleware) source synchronisation.
//!
//! Handles portal discovery, MAC authentication, and full
//! channel + VOD sync from a Stalker/MAG-compatible portal.
//! Authentication uses the two-step handshake + do_auth flow.

use std::collections::HashMap;
use std::fmt;

use anyhow::{Context, Result, anyhow};

use crate::algorithms::categories;
use crate::algorithms::normalize::{mac_to_device_id, validate_mac_address};
use crate::http_client::{get_fast_client, get_shared_client};
use crate::models::SyncReport;
use crate::parsers::stalker;
use crate::services::url_validator::validate_url;
use crate::services::{ServiceContext, SourceService};
use crate::sync_progress::emit_progress;

// ── Constants ────────────────────────────────────────

/// Candidate portal paths tried in order during discovery.
const PORTAL_PATHS: &[&str] = &[
    "/stalker_portal/server/load.php",
    "/portal.php",
    "/server/load.php",
    "/c/",
];

/// Hard page limit per content type to avoid infinite loops.
const MAX_PAGES: u32 = 100;

// ── Session ──────────────────────────────────────────

/// An authenticated Stalker portal session.
struct StalkerSession {
    /// Full portal URL including discovered path prefix.
    portal_url: String,
    /// Bearer token obtained from the handshake.
    // SECURITY: never expose this field in logs or debug output — it is a live
    // portal credential. See manual Debug impl below.
    token: String,
    /// Cookie header value: `mac={mac}; stb_lang=en; timezone=UTC`.
    mac_cookie: String,
}

/// Manual Debug impl that redacts the bearer token to prevent it appearing
/// in tracing spans, error messages, or debug-formatted log lines.
impl fmt::Debug for StalkerSession {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("StalkerSession")
            .field("portal_url", &self.portal_url)
            .field("token", &"[REDACTED]")
            .field("mac_cookie", &self.mac_cookie)
            .finish()
    }
}

// ── Auth helpers ─────────────────────────────────────

/// Percent-encodes a MAC address for use in the Cookie header.
///
/// The colon `:` is a reserved character in cookie values on some
/// implementations, so we encode it as `%3A`.
fn encode_mac_for_cookie(mac: &str) -> String {
    mac.replace(':', "%3A")
}

/// Attempts to authenticate against a single portal path.
///
/// Returns `Some(StalkerSession)` on success, `None` on auth failure.
async fn try_authenticate(
    base_url: &str,
    portal_path: &str,
    mac: &str,
    device_id: &str,
    accept_invalid_certs: bool,
) -> Option<StalkerSession> {
    let portal_url = format!("{}{}", base_url.trim_end_matches('/'), portal_path);
    let encoded_mac = encode_mac_for_cookie(mac);
    let cookie = format!("mac={}; stb_lang=en; timezone=UTC", encoded_mac);

    // ── Step 1: handshake ────────────────────────────
    let handshake_url = format!(
        "{}?type=stb&action=handshake&token=&JsHttpRequest=1-xml",
        portal_url
    );

    let resp = get_fast_client(accept_invalid_certs)
        .get(&handshake_url)
        .header("Cookie", &cookie)
        .header("User-Agent", "MAG250/1.0 (CrispyTivi)")
        .header("X-User-Agent", "Model: MAG250; Link: WiFi")
        .send()
        .await
        .ok()?;

    if !resp.status().is_success() {
        return None;
    }

    let text = resp.text().await.ok()?;
    let json: serde_json::Value = serde_json::from_str(&text).ok()?;

    // Extract token from js.token
    let token = json
        .get("js")
        .and_then(|js| js.get("token"))
        .and_then(|t| t.as_str())
        .filter(|s| !s.is_empty())
        .map(String::from)?;

    // ── Step 2: do_auth ──────────────────────────────
    let auth_url = format!(
        "{}?type=stb&action=do_auth&login=&password=&device_id={}&device_id2={}&JsHttpRequest=1-xml",
        portal_url, device_id, device_id
    );
    // Log only the base portal URL — the full auth_url contains login/password
    // query parameters and must never appear in logs.
    tracing::debug!(portal_url = %portal_url, "stalker do_auth request");

    let auth_resp = get_fast_client(accept_invalid_certs)
        .get(&auth_url)
        .header("Cookie", &cookie)
        .header("User-Agent", "MAG250/1.0 (CrispyTivi)")
        .header("X-User-Agent", "Model: MAG250; Link: WiFi")
        // SECURITY: token is a live credential — never log this header value.
        .header("Authorization", format!("Bearer {}", token))
        .send()
        .await
        .ok()?;

    if !auth_resp.status().is_success() {
        return None;
    }

    Some(StalkerSession {
        portal_url,
        token,
        mac_cookie: cookie,
    })
}

/// Authenticates against a Stalker portal, trying known paths in order.
///
/// Returns an authenticated session or an error if all paths fail.
async fn authenticate(
    base_url: &str,
    mac_address: &str,
    accept_invalid_certs: bool,
) -> Result<StalkerSession> {
    if !validate_mac_address(mac_address) {
        return Err(anyhow!(
            "Invalid MAC address format: {}. Expected XX:XX:XX:XX:XX:XX",
            mac_address
        ));
    }

    let device_id = mac_to_device_id(mac_address);

    for path in PORTAL_PATHS {
        if let Some(session) = try_authenticate(
            base_url,
            path,
            mac_address,
            &device_id,
            accept_invalid_certs,
        )
        .await
        {
            return Ok(session);
        }
    }

    Err(anyhow!(
        "Stalker authentication failed on all portal paths for base URL: {}",
        base_url
    ))
}

// ── Request builder ──────────────────────────────────

/// Sends an authenticated Stalker API request and returns the response body.
async fn stalker_get(
    session: &StalkerSession,
    query: &str,
    accept_invalid_certs: bool,
) -> Result<String> {
    let url = format!("{}{}&JsHttpRequest=1-xml", session.portal_url, query);
    let text = get_shared_client(accept_invalid_certs)
        .get(&url)
        .header("Cookie", &session.mac_cookie)
        .header("User-Agent", "MAG250/1.0 (CrispyTivi)")
        .header("X-User-Agent", "Model: MAG250; Link: WiFi")
        // SECURITY: session.token is a live credential — never log this header value.
        .header("Authorization", format!("Bearer {}", session.token))
        .send()
        .await
        .context("Stalker API request failed")?
        .text()
        .await
        .context("Failed to read Stalker API response")?;
    Ok(text)
}

// ── Category map builder ─────────────────────────────

/// Fetches and parses a Stalker category list, returning a HashMap of
/// id → title. Returns an empty map on error (non-fatal).
async fn fetch_category_map(
    session: &StalkerSession,
    type_action: &str,
    accept_invalid_certs: bool,
) -> HashMap<String, String> {
    match stalker_get(session, type_action, accept_invalid_certs).await {
        Ok(text) => {
            let cats = stalker::parse_stalker_categories(&text);
            cats.into_iter().map(|c| (c.id, c.title)).collect()
        }
        Err(_) => HashMap::new(),
    }
}

// ── Paginated fetch ──────────────────────────────────

/// Fetches all items from a paginated Stalker ordered-list endpoint.
///
/// Calls `parse_fn` on each page's raw JSON to extract the
/// `StalkerPaginatedResult`, then applies `item_fn` to each page's
/// items. Stops when all items are collected or the page limit is hit.
async fn fetch_all_pages<F, G, T>(
    session: &StalkerSession,
    base_query: &str,
    parse_fn: F,
    item_fn: G,
    accept_invalid_certs: bool,
) -> Vec<T>
where
    F: Fn(&str) -> stalker::StalkerPaginatedResult,
    G: Fn(&[serde_json::Value]) -> Vec<T>,
{
    let mut all_items: Vec<T> = Vec::new();
    let mut page: u32 = 1;
    let mut total_items: i32 = -1; // -1 = unknown until first response

    loop {
        let query = format!("{}&p={}", base_query, page);
        let text = match stalker_get(session, &query, accept_invalid_certs).await {
            Ok(t) => t,
            Err(_) => break,
        };

        let result = parse_fn(&text);

        // Capture total on first page.
        if total_items < 0 {
            total_items = result.total_items;
        }

        if result.items.is_empty() {
            break;
        }

        let parsed = item_fn(&result.items);
        all_items.extend(parsed);

        let collected = all_items.len() as i32;
        let has_more = total_items > 0 && collected < total_items && page < MAX_PAGES;
        if !has_more {
            break;
        }

        page += 1;
    }

    all_items
}

// ── Public API ───────────────────────────────────────

/// Verifies that a Stalker portal accepts the given MAC address.
///
/// Returns `Ok(true)` if the handshake + do_auth succeeds on any
/// known portal path, `Ok(false)` if authentication is rejected,
/// or an error on network failure / invalid MAC format.
pub async fn verify_stalker_portal(
    base_url: &str,
    mac_address: &str,
    accept_invalid_certs: bool,
) -> Result<bool> {
    validate_url(base_url).map_err(anyhow::Error::from)?;
    if !validate_mac_address(mac_address) {
        return Ok(false);
    }
    match authenticate(base_url, mac_address, accept_invalid_certs).await {
        Ok(_) => Ok(true),
        Err(e) => {
            // Auth failure is not a network error — return false.
            let msg = e.to_string();
            if msg.contains("authentication failed") {
                Ok(false)
            } else {
                Err(e)
            }
        }
    }
}

/// Full Stalker portal sync: live channels, VOD movies, and series.
///
/// Authenticates against the portal, fetches all content types with
/// category resolution, and persists to the database. Returns a report
/// describing what was saved.
pub async fn sync_stalker_source(
    service: &ServiceContext,
    base_url: &str,
    mac_address: &str,
    source_id: &str,
    accept_invalid_certs: bool,
) -> Result<SyncReport> {
    validate_url(base_url).map_err(anyhow::Error::from)?;
    let base = base_url.trim_end_matches('/').to_string();
    emit_progress(
        source_id,
        "authenticating",
        0.0,
        "Authenticating with portal",
    );

    // ── 1. Authenticate ──────────────────────────────
    let session = authenticate(&base, mac_address, accept_invalid_certs)
        .await
        .context("Stalker portal authentication failed")?;

    // ── 1a. Fetch profile (non-fatal) ─────────────
    match stalker_get(
        &session,
        "?type=stb&action=get_profile",
        accept_invalid_certs,
    )
    .await
    {
        Ok(text) => {
            let profile = stalker::parse_stalker_profile(&text);
            tracing::info!(
                timezone = ?profile.timezone,
                locale = ?profile.locale,
                "Stalker profile"
            );
        }
        Err(e) => tracing::warn!("Failed to fetch Stalker profile: {e}"),
    }

    // ── 1b. Fetch account info (non-fatal) ────────
    match stalker_get(
        &session,
        "?type=account_info&action=get_main_info",
        accept_invalid_certs,
    )
    .await
    {
        Ok(text) => {
            let info = stalker::parse_stalker_account_info(&text);
            tracing::info!(
                login = ?info.login,
                status = info.status,
                exp_date = ?info.exp_date,
                tariff = ?info.tariff_name,
                "Stalker account info"
            );
        }
        Err(e) => tracing::warn!("Failed to fetch Stalker account info: {e}"),
    }

    emit_progress(source_id, "channels", 0.1, "Fetching live channels");

    // ── 2. Live categories ───────────────────────────
    let live_cat_map = fetch_category_map(
        &session,
        "?type=itv&action=get_genres",
        accept_invalid_certs,
    )
    .await;

    // ── 3. Live channels (paginated) ─────────────────
    let source_id_owned = source_id.to_string();
    let base_clone = base.clone();

    let mut channels = fetch_all_pages(
        &session,
        "?type=itv&action=get_ordered_list&genre=*",
        stalker::parse_stalker_channels_result,
        move |items| stalker::channels_from_stalker_json(items, &source_id_owned, &base_clone),
        accept_invalid_certs,
    )
    .await;

    channels = categories::resolve_channel_categories(&channels, &live_cat_map);

    emit_progress(source_id, "vod", 0.4, "Fetching VOD items");

    // ── 4. VOD categories ────────────────────────────
    let vod_cat_map = fetch_category_map(
        &session,
        "?type=vod&action=get_categories",
        accept_invalid_certs,
    )
    .await;

    // ── 5. VOD movies (paginated) ────────────────────
    let base_for_vod = base.clone();
    let sid_for_vod = source_id.to_string();
    let mut vod_items = fetch_all_pages(
        &session,
        "?type=vod&action=get_ordered_list&category=*",
        stalker::parse_stalker_vod_result,
        move |items| stalker::vod_from_stalker_json(items, &sid_for_vod, &base_for_vod),
        accept_invalid_certs,
    )
    .await;

    vod_items = categories::resolve_vod_categories(&vod_items, &vod_cat_map);

    emit_progress(source_id, "series", 0.6, "Fetching series");

    // ── 6. Series (paginated) ────────────────────────
    // Series use the same VOD category map.
    let sid_for_series = source_id.to_string();
    let mut series_items = fetch_all_pages(
        &session,
        "?type=series&action=get_ordered_list&category=*",
        stalker::parse_stalker_vod_result,
        move |items| stalker::series_from_stalker_json(items, &sid_for_series),
        accept_invalid_certs,
    )
    .await;

    series_items = categories::resolve_vod_categories(&series_items, &vod_cat_map);
    vod_items.extend(series_items);

    // ── 7. Extract sorted metadata ───────────────────
    let channel_groups = categories::extract_sorted_groups(&channels);
    let vod_categories_list = categories::extract_sorted_vod_categories(&vod_items);

    // ── 8. Snapshot counts before persisting ─────────
    let channels_count = channels.len();
    let vod_count = vod_items.len();
    emit_progress(source_id, "saving", 0.9, "Saving to database");

    // ── 9. Persist in a single batch ─────────────────
    service
        .save_sync_data(source_id, &channels, &vod_items)
        .context("Failed to persist Stalker sync data")?;

    emit_progress(source_id, "complete", 1.0, "Sync complete");

    // Spawn background bulk EPG fetch for Stalker channels.
    if let Ok(Some(src)) = SourceService(service.clone()).get_source(source_id) {
        crate::services::epg_bulk_fetch::spawn_bulk_epg_fetch(service.clone(), src, channels);
    }

    Ok(SyncReport {
        channels_count,
        channel_groups,
        vod_count,
        vod_categories: vod_categories_list,
        epg_url: None,
    })
}

// ── On-demand endpoints ─────────────────────────

/// Resolves a temporary authenticated stream URL via Stalker's
/// `create_link` endpoint.
///
/// Some portals require this step to convert a stored `cmd` into a
/// time-limited, token-bearing URL suitable for playback.
pub async fn resolve_stalker_stream_url(
    base_url: &str,
    mac_address: &str,
    cmd: &str,
    stream_type: &str,
    accept_invalid_certs: bool,
) -> Result<String> {
    validate_url(base_url).map_err(anyhow::Error::from)?;
    let base = base_url.trim_end_matches('/').to_string();

    let session = authenticate(&base, mac_address, accept_invalid_certs)
        .await
        .context("Stalker authentication failed for create_link")?;

    let encoded_cmd = urlencoding::encode(cmd);
    let query = format!(
        "?type={}&action=create_link&cmd={}",
        stream_type, encoded_cmd
    );

    let text = stalker_get(&session, &query, accept_invalid_certs)
        .await
        .context("Stalker create_link request failed")?;

    stalker::parse_stalker_create_link(&text, &base)
        .ok_or_else(|| anyhow!("Failed to parse create_link response"))
}

/// Fetches user profile information from a Stalker portal.
///
/// Returns timezone, locale, and geographic data. This is called
/// during the sync flow after authentication to capture portal
/// settings.
pub async fn fetch_stalker_profile(
    base_url: &str,
    mac_address: &str,
    accept_invalid_certs: bool,
) -> Result<stalker::StalkerProfile> {
    validate_url(base_url).map_err(anyhow::Error::from)?;
    let base = base_url.trim_end_matches('/').to_string();

    let session = authenticate(&base, mac_address, accept_invalid_certs)
        .await
        .context("Stalker authentication failed for get_profile")?;

    let text = stalker_get(
        &session,
        "?type=stb&action=get_profile",
        accept_invalid_certs,
    )
    .await
    .context("Stalker get_profile request failed")?;

    let profile = stalker::parse_stalker_profile(&text);
    tracing::debug!(?profile, "Stalker profile fetched for {}", base_url);

    Ok(profile)
}

/// Fetches account/subscription information from a Stalker portal.
///
/// Returns login, MAC, account status, expiration date, and tariff
/// name. Useful for displaying subscription status in the UI.
pub async fn fetch_stalker_account_info(
    base_url: &str,
    mac_address: &str,
    accept_invalid_certs: bool,
) -> Result<stalker::StalkerAccountInfo> {
    validate_url(base_url).map_err(anyhow::Error::from)?;
    let base = base_url.trim_end_matches('/').to_string();

    let session = authenticate(&base, mac_address, accept_invalid_certs)
        .await
        .context("Stalker authentication failed for account_info")?;

    let text = stalker_get(
        &session,
        "?type=account_info&action=get_main_info",
        accept_invalid_certs,
    )
    .await
    .context("Stalker account_info request failed")?;

    let info = stalker::parse_stalker_account_info(&text);
    tracing::debug!(
        login = ?info.login,
        status = info.status,
        exp_date = ?info.exp_date,
        "Stalker account info fetched"
    );

    Ok(info)
}

/// Sends a session keepalive / watchdog event to the Stalker portal.
///
/// Should be called periodically during playback to prevent the portal
/// from terminating the session. `cur_play_type` is typically "itv"
/// for live or "vod" for on-demand.
pub async fn stalker_keepalive(
    base_url: &str,
    mac_address: &str,
    cur_play_type: &str,
    accept_invalid_certs: bool,
) -> Result<()> {
    validate_url(base_url).map_err(anyhow::Error::from)?;
    let base = base_url.trim_end_matches('/').to_string();

    let session = authenticate(&base, mac_address, accept_invalid_certs)
        .await
        .context("Stalker authentication failed for watchdog")?;

    let query = format!(
        "?type=watchdog&action=get_events&cur_play_type={}&event=cur_play",
        cur_play_type
    );

    stalker_get(&session, &query, accept_invalid_certs)
        .await
        .context("Stalker watchdog request failed")?;

    tracing::trace!("Stalker keepalive sent for {}", base_url);
    Ok(())
}

/// Fetches detailed VOD metadata for a single movie from a Stalker
/// portal.
///
/// Calls `type=vod&action=get_vod_info&movie_id={id}` and returns
/// an enriched [`crate::models::VodItem`] with full metadata.
pub async fn fetch_stalker_vod_detail(
    base_url: &str,
    mac_address: &str,
    movie_id: &str,
    source_id: &str,
    accept_invalid_certs: bool,
) -> Result<crate::models::VodItem> {
    validate_url(base_url).map_err(anyhow::Error::from)?;
    let base = base_url.trim_end_matches('/').to_string();

    let session = authenticate(&base, mac_address, accept_invalid_certs)
        .await
        .context("Stalker authentication failed for get_vod_info")?;

    let query = format!("?type=vod&action=get_vod_info&movie_id={}", movie_id);
    let text = stalker_get(&session, &query, accept_invalid_certs)
        .await
        .context("Stalker get_vod_info request failed")?;

    stalker::parse_stalker_vod_detail(&text, &base, source_id).ok_or_else(|| {
        anyhow!(
            "Failed to parse get_vod_info response for movie_id={}",
            movie_id
        )
    })
}

/// Fetches series season/episode structure from a Stalker portal.
///
/// Calls `type=series&action=get_series_info&movie_id={id}` and
/// returns a flat list of episode [`crate::models::VodItem`]s with
/// `series_id`, `season_number`, and `episode_number` populated.
pub async fn fetch_stalker_series_detail(
    base_url: &str,
    mac_address: &str,
    movie_id: &str,
    source_id: &str,
    accept_invalid_certs: bool,
) -> Result<Vec<crate::models::VodItem>> {
    validate_url(base_url).map_err(anyhow::Error::from)?;
    let base = base_url.trim_end_matches('/').to_string();

    let session = authenticate(&base, mac_address, accept_invalid_certs)
        .await
        .context("Stalker authentication failed for get_series_info")?;

    let query = format!("?type=series&action=get_series_info&movie_id={}", movie_id);
    let text = stalker_get(&session, &query, accept_invalid_certs)
        .await
        .context("Stalker get_series_info request failed")?;

    let episodes = stalker::parse_stalker_series_detail(&text, &base, movie_id, source_id);

    Ok(episodes)
}

/// Fetches server-side favorite IDs from a Stalker portal.
///
/// Returns a list of Stalker-internal IDs for channels/items
/// marked as favorites on the portal.
pub async fn get_stalker_favorites(
    base_url: &str,
    mac_address: &str,
    stream_type: &str,
    accept_invalid_certs: bool,
) -> Result<Vec<String>> {
    validate_url(base_url).map_err(anyhow::Error::from)?;
    let base = base_url.trim_end_matches('/').to_string();

    let session = authenticate(&base, mac_address, accept_invalid_certs)
        .await
        .context("Stalker authentication failed for get_fav")?;

    let query = format!("?type={}&action=get_fav", stream_type);
    let text = stalker_get(&session, &query, accept_invalid_certs)
        .await
        .context("Stalker get_fav request failed")?;

    Ok(stalker::parse_stalker_favorites(&text))
}

/// Sets or removes a server-side favorite on a Stalker portal.
///
/// When `remove` is `true`, the item is unfavorited; otherwise
/// it is added to favorites.
pub async fn set_stalker_favorite(
    base_url: &str,
    mac_address: &str,
    fav_id: &str,
    stream_type: &str,
    remove: bool,
    accept_invalid_certs: bool,
) -> Result<()> {
    validate_url(base_url).map_err(anyhow::Error::from)?;
    let base = base_url.trim_end_matches('/').to_string();

    let session = authenticate(&base, mac_address, accept_invalid_certs)
        .await
        .context("Stalker authentication failed for set_fav")?;

    let action = if remove { "del_fav" } else { "set_fav" };
    let query = format!("?type={}&action={}&fav_id={}", stream_type, action, fav_id);

    stalker_get(&session, &query, accept_invalid_certs)
        .await
        .context("Stalker set_fav request failed")?;

    tracing::debug!(fav_id, remove, stream_type, "Stalker favorite updated");
    Ok(())
}

#[cfg(test)]
mod tests {
    use wiremock::matchers::{method, path, query_param};
    use wiremock::{Mock, MockServer, ResponseTemplate};

    use super::*;

    /// A valid MAC address used across all Stalker tests.
    const TEST_MAC: &str = "00:1A:2B:3C:4D:5E";

    /// The first portal path the code tries.
    const PORTAL_PATH: &str = "/stalker_portal/server/load.php";

    #[tokio::test]
    async fn verify_stalker_portal_success() {
        let mock_server = MockServer::start().await;

        // Step 1: handshake — returns a token.
        Mock::given(method("GET"))
            .and(path(PORTAL_PATH))
            .and(query_param("type", "stb"))
            .and(query_param("action", "handshake"))
            .respond_with(
                ResponseTemplate::new(200).set_body_string(r#"{"js":{"token":"abc123"}}"#),
            )
            .mount(&mock_server)
            .await;

        // Step 2: do_auth — returns success (any non-error body is sufficient).
        Mock::given(method("GET"))
            .and(path(PORTAL_PATH))
            .and(query_param("type", "stb"))
            .and(query_param("action", "do_auth"))
            .respond_with(
                ResponseTemplate::new(200).set_body_string(r#"{"js":{"id":"1","name":"test"}}"#),
            )
            .mount(&mock_server)
            .await;

        let result = verify_stalker_portal(&mock_server.uri(), TEST_MAC, false)
            .await
            .expect("verify should succeed");

        assert!(result, "successful handshake + do_auth should return true");
    }

    #[tokio::test]
    async fn verify_stalker_portal_failure_empty_token() {
        let mock_server = MockServer::start().await;

        // Handshake returns an empty token on all portal paths → auth fails.
        for portal_path in PORTAL_PATHS {
            Mock::given(method("GET"))
                .and(path(*portal_path))
                .and(query_param("type", "stb"))
                .and(query_param("action", "handshake"))
                .respond_with(ResponseTemplate::new(200).set_body_string(r#"{"js":{"token":""}}"#))
                .mount(&mock_server)
                .await;
        }

        let result = verify_stalker_portal(&mock_server.uri(), TEST_MAC, false)
            .await
            .expect("verify should not error on auth failure");

        assert!(!result, "empty token should cause auth to fail → false");
    }

    /// Mounts handshake + do_auth mocks that succeed on the first portal path.
    async fn mount_auth_mocks(mock_server: &MockServer) {
        Mock::given(method("GET"))
            .and(path(PORTAL_PATH))
            .and(query_param("type", "stb"))
            .and(query_param("action", "handshake"))
            .respond_with(
                ResponseTemplate::new(200).set_body_string(r#"{"js":{"token":"tok123"}}"#),
            )
            .mount(mock_server)
            .await;

        Mock::given(method("GET"))
            .and(path(PORTAL_PATH))
            .and(query_param("type", "stb"))
            .and(query_param("action", "do_auth"))
            .respond_with(ResponseTemplate::new(200).set_body_string(r#"{"js":{"id":"1"}}"#))
            .mount(mock_server)
            .await;
    }

    #[tokio::test]
    async fn resolve_stalker_stream_url_success() {
        let mock_server = MockServer::start().await;
        mount_auth_mocks(&mock_server).await;

        Mock::given(method("GET"))
            .and(path(PORTAL_PATH))
            .and(query_param("type", "itv"))
            .and(query_param("action", "create_link"))
            .respond_with(
                ResponseTemplate::new(200)
                    .set_body_string(r#"{"js":{"cmd":"ffrt http://cdn/stream.m3u8?token=xyz"}}"#),
            )
            .mount(&mock_server)
            .await;

        let url = resolve_stalker_stream_url(
            &mock_server.uri(),
            TEST_MAC,
            "http://old/stream",
            "itv",
            false,
        )
        .await
        .expect("create_link should succeed");

        assert_eq!(url, "http://cdn/stream.m3u8?token=xyz");
    }

    #[tokio::test]
    async fn fetch_stalker_profile_success() {
        let mock_server = MockServer::start().await;
        mount_auth_mocks(&mock_server).await;

        Mock::given(method("GET"))
            .and(path(PORTAL_PATH))
            .and(query_param("type", "stb"))
            .and(query_param("action", "get_profile"))
            .respond_with(
                ResponseTemplate::new(200)
                    .set_body_string(r#"{"js":{"timezone":"Europe/London","locale":"en_GB"}}"#),
            )
            .mount(&mock_server)
            .await;

        let profile = fetch_stalker_profile(&mock_server.uri(), TEST_MAC, false)
            .await
            .expect("get_profile should succeed");

        assert_eq!(profile.timezone.as_deref(), Some("Europe/London"));
        assert_eq!(profile.locale.as_deref(), Some("en_GB"));
    }

    #[tokio::test]
    async fn fetch_stalker_account_info_success() {
        let mock_server = MockServer::start().await;
        mount_auth_mocks(&mock_server).await;

        Mock::given(method("GET"))
            .and(path(PORTAL_PATH))
            .and(query_param("type", "account_info"))
            .and(query_param("action", "get_main_info"))
            .respond_with(ResponseTemplate::new(200).set_body_string(
                r#"{"js":{"login":"user1","status":0,"exp_date":"2025-12-31","tariff_name":"HD"}}"#,
            ))
            .mount(&mock_server)
            .await;

        let info = fetch_stalker_account_info(&mock_server.uri(), TEST_MAC, false)
            .await
            .expect("account_info should succeed");

        assert_eq!(info.login.as_deref(), Some("user1"));
        assert_eq!(info.status, 0);
        assert_eq!(info.exp_date.as_deref(), Some("2025-12-31"));
        assert_eq!(info.tariff_name.as_deref(), Some("HD"));
    }

    #[tokio::test]
    async fn stalker_keepalive_success() {
        let mock_server = MockServer::start().await;
        mount_auth_mocks(&mock_server).await;

        Mock::given(method("GET"))
            .and(path(PORTAL_PATH))
            .and(query_param("type", "watchdog"))
            .and(query_param("action", "get_events"))
            .respond_with(ResponseTemplate::new(200).set_body_string(r#"{"js":true}"#))
            .mount(&mock_server)
            .await;

        let result = stalker_keepalive(&mock_server.uri(), TEST_MAC, "itv", false).await;
        assert!(result.is_ok(), "keepalive should succeed");
    }

    #[tokio::test]
    async fn fetch_stalker_vod_detail_success() {
        let mock_server = MockServer::start().await;
        mount_auth_mocks(&mock_server).await;

        Mock::given(method("GET"))
            .and(path(PORTAL_PATH))
            .and(query_param("type", "vod"))
            .and(query_param("action", "get_vod_info"))
            .and(query_param("movie_id", "501"))
            .respond_with(ResponseTemplate::new(200).set_body_string(
                r#"{"js":{"movie":{"id":"501","name":"Test Movie","cmd":"http://vod/501.mp4","description":"Great film"}}}"#,
            ))
            .mount(&mock_server)
            .await;

        let item = fetch_stalker_vod_detail(&mock_server.uri(), TEST_MAC, "501", "src_1", false)
            .await
            .expect("vod_detail should succeed");

        assert_eq!(item.name, "Test Movie");
        assert_eq!(item.description.as_deref(), Some("Great film"));
    }

    #[tokio::test]
    async fn fetch_stalker_series_detail_success() {
        let mock_server = MockServer::start().await;
        mount_auth_mocks(&mock_server).await;

        Mock::given(method("GET"))
            .and(path(PORTAL_PATH))
            .and(query_param("type", "series"))
            .and(query_param("action", "get_series_info"))
            .and(query_param("movie_id", "300"))
            .respond_with(ResponseTemplate::new(200).set_body_string(
                r#"{"js":{"seasons":[{"season_number":1,"episodes":[{"id":"301","name":"Pilot","cmd":"http://vod/301.mp4"}]}]}}"#,
            ))
            .mount(&mock_server)
            .await;

        let episodes =
            fetch_stalker_series_detail(&mock_server.uri(), TEST_MAC, "300", "src_1", false)
                .await
                .expect("series_detail should succeed");

        assert_eq!(episodes.len(), 1);
        assert_eq!(episodes[0].name, "Pilot");
        assert_eq!(episodes[0].season_number, Some(1));
        assert_eq!(episodes[0].series_id.as_deref(), Some("300"));
    }

    #[tokio::test]
    async fn get_stalker_favorites_success() {
        let mock_server = MockServer::start().await;
        mount_auth_mocks(&mock_server).await;

        Mock::given(method("GET"))
            .and(path(PORTAL_PATH))
            .and(query_param("type", "itv"))
            .and(query_param("action", "get_fav"))
            .respond_with(ResponseTemplate::new(200).set_body_string(r#"{"js":"1,2,3"}"#))
            .mount(&mock_server)
            .await;

        let favs = get_stalker_favorites(&mock_server.uri(), TEST_MAC, "itv", false)
            .await
            .expect("get_fav should succeed");

        assert_eq!(favs, vec!["1", "2", "3"]);
    }

    #[tokio::test]
    async fn set_stalker_favorite_success() {
        let mock_server = MockServer::start().await;
        mount_auth_mocks(&mock_server).await;

        Mock::given(method("GET"))
            .and(path(PORTAL_PATH))
            .and(query_param("type", "itv"))
            .and(query_param("action", "set_fav"))
            .and(query_param("fav_id", "42"))
            .respond_with(ResponseTemplate::new(200).set_body_string(r#"{"js":true}"#))
            .mount(&mock_server)
            .await;

        let result =
            set_stalker_favorite(&mock_server.uri(), TEST_MAC, "42", "itv", false, false).await;
        assert!(result.is_ok(), "set_fav should succeed");
    }
}
