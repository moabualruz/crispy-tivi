//! Stalker Portal (MAG middleware) source synchronisation.
//!
//! Handles portal discovery, MAC authentication, and full
//! channel + VOD sync from a Stalker/MAG-compatible portal.
//! Authentication uses the two-step handshake + do_auth flow.

use std::collections::HashMap;

use anyhow::{Context, Result, anyhow};

use crate::algorithms::categories;
use crate::algorithms::normalize::{mac_to_device_id, validate_mac_address};
use crate::http_client::{get_fast_client, get_shared_client};
use crate::models::SyncReport;
use crate::parsers::stalker;
use crate::services::CrispyService;
use crate::services::url_validator::validate_url;
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
    token: String,
    /// Cookie header value: `mac={mac}; stb_lang=en; timezone=UTC`.
    mac_cookie: String,
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
    service: &CrispyService,
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
        move |items| stalker::parse_stalker_live_streams(items, &source_id_owned, &base_clone),
        accept_invalid_certs,
    )
    .await;

    channels = categories::resolve_channel_categories(&channels, &live_cat_map);
    for ch in &mut channels {
        ch.source_id = Some(source_id.to_string());
    }

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
    let mut vod_items = fetch_all_pages(
        &session,
        "?type=vod&action=get_ordered_list&category=*",
        stalker::parse_stalker_vod_result,
        move |items| stalker::parse_stalker_vod_items(items, &base_for_vod, "movie"),
        accept_invalid_certs,
    )
    .await;

    vod_items = categories::resolve_vod_categories(&vod_items, &vod_cat_map);
    for v in &mut vod_items {
        v.source_id = Some(source_id.to_string());
    }

    emit_progress(source_id, "series", 0.6, "Fetching series");

    // ── 6. Series (paginated) ────────────────────────
    // Series use the same VOD category map.
    let base_for_series = base.clone();
    let mut series_items = fetch_all_pages(
        &session,
        "?type=series&action=get_ordered_list&category=*",
        stalker::parse_stalker_vod_result,
        move |items| stalker::parse_stalker_vod_items(items, &base_for_series, "series"),
        accept_invalid_certs,
    )
    .await;

    series_items = categories::resolve_vod_categories(&series_items, &vod_cat_map);
    for v in &mut series_items {
        v.source_id = Some(source_id.to_string());
    }
    vod_items.extend(series_items);

    // ── 7. Extract sorted metadata ───────────────────
    let channel_groups = categories::extract_sorted_groups(&channels);
    let vod_categories_list = categories::extract_sorted_vod_categories(&vod_items);

    // ── 8. Collect IDs for stale-row deletion ────────
    let channels_count = channels.len();
    let vod_count = vod_items.len();
    let channel_ids: Vec<String> = channels.iter().map(|c| c.id.clone()).collect();
    let vod_ids: Vec<String> = vod_items.iter().map(|v| v.id.clone()).collect();

    emit_progress(source_id, "saving", 0.9, "Saving to database");

    // ── 9. Persist in a single batch ─────────────────
    service
        .save_sync_data(source_id, &channels, &channel_ids, &vod_items, &vod_ids)
        .context("Failed to persist Stalker sync data")?;

    emit_progress(source_id, "complete", 1.0, "Sync complete");

    Ok(SyncReport {
        channels_count,
        channel_groups,
        vod_count,
        vod_categories: vod_categories_list,
        epg_url: None,
    })
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
}
