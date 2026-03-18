//! Xtream source synchronisation.
//!
//! Fetches live streams, VOD, and series from an Xtream-compatible
//! server, parses them with the existing Rust parsers, resolves
//! category names, and persists everything to the local database.

use anyhow::{Context, Result};

use crate::algorithms::categories;
use crate::http_client::get_fast_client;
use crate::http_resilience::fetch_json_list;
use crate::models::SyncReport;
use crate::parsers::{vod, xtream};
use crate::services::CrispyService;
use crate::sync_progress::emit_progress;

/// Validates that a source base URL is safe to fetch (M-067).
///
/// Only `http` and `https` schemes are accepted. Any other scheme
/// is logged at `WARN` level and rejected with an error.
fn validate_source_url(url: &str) -> Result<()> {
    let parsed =
        url::Url::parse(url).map_err(|e| anyhow::anyhow!("Invalid source URL '{}': {}", url, e))?;
    match parsed.scheme() {
        "http" | "https" => Ok(()),
        scheme => {
            tracing::warn!(
                security = "url_validation",
                url = url,
                scheme = scheme,
                "Rejected source URL with disallowed scheme"
            );
            Err(anyhow::anyhow!(
                "Disallowed URL scheme '{}' in source URL '{}': only http/https are permitted",
                scheme,
                url
            ))
        }
    }
}

/// Verifies Xtream credentials by calling the player API.
///
/// Returns `Ok(true)` if authenticated, `Ok(false)` if auth rejected,
/// or an error on network failure.
pub async fn verify_xtream_credentials(
    base_url: &str,
    username: &str,
    password: &str,
    accept_invalid_certs: bool,
) -> Result<bool> {
    validate_source_url(base_url)?;
    // Build URL: {base}/player_api.php?username=X&password=Y
    // (action omitted = returns account info)
    let url =
        xtream::build_xtream_action_url(base_url, username, password, "get_account_info", &[]);
    let resp = get_fast_client(accept_invalid_certs)
        .get(&url)
        .send()
        .await
        .context("Failed to connect to Xtream server")?;

    if !resp.status().is_success() {
        return Ok(false);
    }

    let data: serde_json::Value = resp
        .json()
        .await
        .context("Failed to parse Xtream auth response")?;

    // Check user_info.auth == 1
    Ok(data
        .get("user_info")
        .and_then(|u| u.get("auth"))
        .and_then(|a| a.as_i64())
        .is_some_and(|a| a == 1))
}

/// Full Xtream source sync: categories, live streams, VOD, series.
///
/// Fetches all data from the Xtream server, parses it, resolves
/// categories, and saves to the database. Returns a report.
pub async fn sync_xtream_source(
    service: &CrispyService,
    base_url: &str,
    username: &str,
    password: &str,
    source_id: &str,
    accept_invalid_certs: bool,
) -> Result<SyncReport> {
    validate_source_url(base_url)?;
    let base = xtream::normalize_base_url(base_url);
    emit_progress(source_id, "categories", 0.0, "Fetching categories");

    // 1. Fetch category lists — non-fatal; some servers omit endpoints.
    let live_cats = fetch_json_list(
        &xtream::build_xtream_action_url(&base, username, password, "get_live_categories", &[]),
        accept_invalid_certs,
    )
    .await
    .unwrap_or_default();

    let vod_cats = fetch_json_list(
        &xtream::build_xtream_action_url(&base, username, password, "get_vod_categories", &[]),
        accept_invalid_certs,
    )
    .await
    .unwrap_or_default();

    let series_cats = fetch_json_list(
        &xtream::build_xtream_action_url(&base, username, password, "get_series_categories", &[]),
        accept_invalid_certs,
    )
    .await
    .unwrap_or_default();

    let live_cat_map = categories::build_category_map(&live_cats);
    let vod_cat_map = categories::build_category_map(&vod_cats);
    let series_cat_map = categories::build_category_map(&series_cats);

    emit_progress(source_id, "channels", 0.2, "Fetching live streams");

    // 2. Fetch and parse live streams — non-fatal; server may be live-only or VOD-only.
    let live_data = fetch_json_list(
        &xtream::build_xtream_action_url(&base, username, password, "get_live_streams", &[]),
        accept_invalid_certs,
    )
    .await
    .unwrap_or_default();

    let mut channels = xtream::parse_xtream_live_streams(&live_data, &base, username, password);
    channels = categories::resolve_channel_categories(&channels, &live_cat_map);
    for ch in &mut channels {
        ch.source_id = Some(source_id.to_owned());
    }

    emit_progress(source_id, "vod", 0.4, "Fetching VOD streams");

    // 3. Fetch and parse VOD streams — non-fatal.
    let vod_data = fetch_json_list(
        &xtream::build_xtream_action_url(&base, username, password, "get_vod_streams", &[]),
        accept_invalid_certs,
    )
    .await
    .unwrap_or_default();

    let mut vod_items =
        vod::parse_vod_streams(&vod_data, &base, username, password, Some(source_id));
    vod_items = categories::resolve_vod_categories(&vod_items, &vod_cat_map);

    emit_progress(source_id, "series", 0.6, "Fetching series");

    // 4. Fetch and parse series — non-fatal.
    let series_data = fetch_json_list(
        &xtream::build_xtream_action_url(&base, username, password, "get_series", &[]),
        accept_invalid_certs,
    )
    .await
    .unwrap_or_default();

    let mut series_items = vod::parse_series(&series_data, Some(source_id));
    series_items = categories::resolve_vod_categories(&series_items, &series_cat_map);
    vod_items.extend(series_items);

    // 5. Extract sorted metadata before consuming the collections.
    let channel_groups = categories::extract_sorted_groups(&channels);
    let vod_categories_list = categories::extract_sorted_vod_categories(&vod_items);

    // 6. Collect IDs for stale-row deletion.
    let channels_count = channels.len();
    let vod_count = vod_items.len();
    let channel_ids: Vec<String> = channels.iter().map(|c| c.id.clone()).collect();
    let vod_ids: Vec<String> = vod_items.iter().map(|v| v.id.clone()).collect();

    emit_progress(source_id, "saving", 0.9, "Saving to database");

    // 7. Save to DB — single batch so the UI gets one BulkDataRefresh.
    service
        .save_sync_data(source_id, &channels, &channel_ids, &vod_items, &vod_ids)
        .context("Failed to persist Xtream sync data")?;

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
    use crate::services::test_helpers::make_service;

    #[tokio::test]
    async fn verify_xtream_credentials_success() {
        let mock_server = MockServer::start().await;

        Mock::given(method("GET"))
            .and(path("/player_api.php"))
            .and(query_param("username", "test"))
            .and(query_param("password", "test"))
            .and(query_param("action", "get_account_info"))
            .respond_with(ResponseTemplate::new(200).set_body_string(r#"{"user_info":{"auth":1}}"#))
            .mount(&mock_server)
            .await;

        let result = verify_xtream_credentials(&mock_server.uri(), "test", "test", false)
            .await
            .expect("request should succeed");

        assert!(result, "auth == 1 should return true");
    }

    #[tokio::test]
    async fn verify_xtream_credentials_failure() {
        let mock_server = MockServer::start().await;

        Mock::given(method("GET"))
            .and(path("/player_api.php"))
            .and(query_param("username", "test"))
            .and(query_param("password", "test"))
            .and(query_param("action", "get_account_info"))
            .respond_with(ResponseTemplate::new(200).set_body_string(r#"{"user_info":{"auth":0}}"#))
            .mount(&mock_server)
            .await;

        let result = verify_xtream_credentials(&mock_server.uri(), "test", "test", false)
            .await
            .expect("request should succeed");

        assert!(!result, "auth == 0 should return false");
    }

    #[tokio::test]
    async fn sync_xtream_source_basic() {
        let mock_server = MockServer::start().await;

        // Live categories
        Mock::given(method("GET"))
            .and(path("/player_api.php"))
            .and(query_param("action", "get_live_categories"))
            .respond_with(
                ResponseTemplate::new(200).set_body_string(
                    r#"[{"category_id":"1","category_name":"News"},{"category_id":"2","category_name":"Sports"}]"#,
                ),
            )
            .mount(&mock_server)
            .await;

        // VOD categories
        Mock::given(method("GET"))
            .and(path("/player_api.php"))
            .and(query_param("action", "get_vod_categories"))
            .respond_with(
                ResponseTemplate::new(200)
                    .set_body_string(r#"[{"category_id":"5","category_name":"Movies"}]"#),
            )
            .mount(&mock_server)
            .await;

        // Series categories
        Mock::given(method("GET"))
            .and(path("/player_api.php"))
            .and(query_param("action", "get_series_categories"))
            .respond_with(ResponseTemplate::new(200).set_body_string(r#"[]"#))
            .mount(&mock_server)
            .await;

        // Live streams
        Mock::given(method("GET"))
            .and(path("/player_api.php"))
            .and(query_param("action", "get_live_streams"))
            .respond_with(
                ResponseTemplate::new(200).set_body_string(
                    r#"[{"stream_id":1,"name":"Ch1","stream_type":"live","category_id":"1"},{"stream_id":2,"name":"Ch2","stream_type":"live","category_id":"2"}]"#,
                ),
            )
            .mount(&mock_server)
            .await;

        // VOD streams
        Mock::given(method("GET"))
            .and(path("/player_api.php"))
            .and(query_param("action", "get_vod_streams"))
            .respond_with(ResponseTemplate::new(200).set_body_string(
                r#"[{"stream_id":10,"name":"Movie1","stream_type":"movie","category_id":"5"}]"#,
            ))
            .mount(&mock_server)
            .await;

        // Series
        Mock::given(method("GET"))
            .and(path("/player_api.php"))
            .and(query_param("action", "get_series"))
            .respond_with(ResponseTemplate::new(200).set_body_string(r#"[]"#))
            .mount(&mock_server)
            .await;

        let service = make_service();
        let report =
            sync_xtream_source(&service, &mock_server.uri(), "test", "test", "src-1", false)
                .await
                .expect("sync should succeed");

        assert_eq!(report.channels_count, 2, "expected 2 live channels");
        assert_eq!(report.vod_count, 1, "expected 1 VOD item");
        assert!(
            report.channel_groups.contains(&"News".to_string()),
            "expected News group"
        );
        assert!(
            report.channel_groups.contains(&"Sports".to_string()),
            "expected Sports group"
        );
    }
}
