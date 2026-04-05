//! Xtream source synchronisation.
//!
//! Fetches live streams, VOD, and series from an Xtream-compatible
//! server, parses them with the existing Rust parsers, resolves
//! category names, and persists everything to the local database.
//!
//! ## tvg_id mapping via M3U temp table
//!
//! Xtream API streams lack tvg_id metadata. We download the M3U
//! playlist, parse it into a SQLite TEMP TABLE keyed by normalised
//! stream URL, then join that against the Xtream channels after
//! creation to populate tvg_id. The temp table is dropped (or
//! auto-cleaned on connection close) after the mapping step.
//! M3U channels are never persisted to `db_channels`.

use std::collections::HashMap;
use std::time::Duration;

use crate::algorithms::categories;
use crate::algorithms::normalize::normalize_url;
use crate::http_client::get_fast_client;
use crate::http_resilience::{fetch_json_list, fetch_json_object};
use crate::models::{Channel, SyncReport, XtreamAccountInfo};
use crate::parsers::{vod, xtream};
use crate::services::CrispyService;
use crate::services::url_validator::validate_url;
use crate::sync_progress::emit_progress;
use anyhow::{Context, Result};

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
    validate_url(base_url).map_err(anyhow::Error::from)?;
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

/// Fetch and parse the full Xtream authentication response.
///
/// Calls `player_api.php?username=X&password=Y&action=get_account_info`
/// and parses both `user_info` and `server_info` blocks into an
/// `XtreamAccountInfo` struct.
///
/// Returns the populated struct on success, or an error on network
/// or parse failure.
pub async fn fetch_xtream_account_info(
    base_url: &str,
    username: &str,
    password: &str,
    accept_invalid_certs: bool,
) -> Result<XtreamAccountInfo> {
    validate_url(base_url).map_err(anyhow::Error::from)?;
    let url =
        xtream::build_xtream_action_url(base_url, username, password, "get_account_info", &[]);
    let resp = get_fast_client(accept_invalid_certs)
        .get(&url)
        .send()
        .await
        .context("Failed to connect to Xtream server")?;

    if !resp.status().is_success() {
        anyhow::bail!("Xtream server returned HTTP {}", resp.status());
    }

    let data: serde_json::Value = resp
        .json()
        .await
        .context("Failed to parse Xtream auth response")?;

    Ok(parse_xtream_account_info(&data))
}

/// Parse an Xtream authentication JSON response into `XtreamAccountInfo`.
///
/// Handles both `user_info` and `server_info` top-level objects.
/// Missing or malformed fields gracefully default to `None` / default values.
fn parse_xtream_account_info(data: &serde_json::Value) -> XtreamAccountInfo {
    let user = data.get("user_info").cloned().unwrap_or_default();
    let server = data.get("server_info").cloned().unwrap_or_default();

    let str_field = |obj: &serde_json::Value, key: &str| -> Option<String> {
        obj.get(key).and_then(|v| match v {
            serde_json::Value::String(s) => Some(s.clone()),
            serde_json::Value::Number(n) => Some(n.to_string()),
            _ => None,
        })
    };

    let allowed_formats = user
        .get("allowed_output_formats")
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|v| v.as_str().map(String::from))
                .collect()
        })
        .unwrap_or_default();

    XtreamAccountInfo {
        username: str_field(&user, "username"),
        message: str_field(&user, "message"),
        auth: user.get("auth").and_then(|a| a.as_i64()).unwrap_or(0) as i32,
        status: str_field(&user, "status"),
        exp_date: str_field(&user, "exp_date"),
        is_trial: str_field(&user, "is_trial"),
        active_cons: str_field(&user, "active_cons"),
        created_at: str_field(&user, "created_at"),
        max_connections: str_field(&user, "max_connections"),
        allowed_output_formats: allowed_formats,
        server_url: str_field(&server, "url"),
        server_port: str_field(&server, "port"),
        server_https_port: str_field(&server, "https_port"),
        server_protocol: str_field(&server, "server_protocol"),
        server_rtmp_port: str_field(&server, "rtmp_port"),
        server_timezone: str_field(&server, "timezone"),
        server_timestamp_now: server.get("timestamp_now").and_then(|v| v.as_i64()),
        server_time_now: str_field(&server, "time_now"),
    }
}

/// Build a `{normalised_stream_url → tvg_id}` map from an M3U playlist.
///
/// Downloads the M3U from the Xtream `get.php` endpoint, parses every
/// `#EXTINF` entry, normalises each stream URL, and stores the mapping in
/// Downloads the M3U playlist for an Xtream source and stores it in a
/// **SQLite temp table** — never holding all channels in RAM. Parses the
/// M3U line-by-line, inserting each entry directly into the temp table
/// in batches.
///
/// The temp table holds: `stream_url_normalized`, `tvg_id`, `name`,
/// `logo`, `group_title` — enough to enrich Xtream channels after
/// the API fetch.
///
/// The caller is responsible for calling `drop_m3u_temp_table()` after
/// Xtream mapping is complete.
///
/// Returns the number of rows inserted, or 0 on failure.
async fn download_m3u_to_temp_table(
    service: &CrispyService,
    base: &str,
    username: &str,
    password: &str,
    source_id: &str,
    accept_invalid_certs: bool,
) -> usize {
    let m3u_url = {
        let enc_user =
            percent_encoding::utf8_percent_encode(username, percent_encoding::NON_ALPHANUMERIC)
                .to_string();
        let enc_pass =
            percent_encoding::utf8_percent_encode(password, percent_encoding::NON_ALPHANUMERIC)
                .to_string();
        format!("{base}/get.php?username={enc_user}&password={enc_pass}&type=m3u_plus&output=ts")
    };

    let content = match tokio::time::timeout(
        Duration::from_secs(60),
        crate::http_client::get_shared_client(accept_invalid_certs)
            .get(&m3u_url)
            .send(),
    )
    .await
    {
        Ok(Ok(resp)) if resp.status().is_success() => match resp.bytes().await {
            Ok(bytes) => String::from_utf8_lossy(&bytes).into_owned(),
            Err(e) => {
                tracing::warn!(source_id, error = %e, "Failed to read M3U body");
                return 0;
            }
        },
        Ok(Ok(resp)) => {
            tracing::warn!(source_id, status = %resp.status(), "M3U endpoint non-success");
            return 0;
        }
        Ok(Err(e)) => {
            tracing::warn!(source_id, error = %e, "M3U download failed");
            return 0;
        }
        Err(_) => {
            tracing::warn!(source_id, "M3U download timed out after 60s");
            return 0;
        }
    };

    if content.is_empty() {
        return 0;
    }

    // Get a DB connection and create the temp table
    let conn = match service.db.get() {
        Ok(c) => c,
        Err(e) => {
            tracing::warn!(source_id, error = %e, "DB connection unavailable");
            return 0;
        }
    };

    if let Err(e) = conn.execute_batch(
        "CREATE TEMP TABLE IF NOT EXISTS tmp_m3u_channels (
             stream_url_normalized TEXT PRIMARY KEY,
             tvg_id TEXT,
             name TEXT,
             logo TEXT,
             group_title TEXT
         );
         DELETE FROM tmp_m3u_channels;",
    ) {
        tracing::warn!(source_id, error = %e, "Failed to create temp table");
        return 0;
    }

    // Parse M3U line-by-line and insert into temp table directly.
    // We extract only the fields we need — no full Channel struct allocation.
    let mut inserted = 0usize;
    let mut current_extinf: Option<(Option<String>, Option<String>, Option<String>, Option<String>)> = None;

    for line in content.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with("#EXTINF") {
            let tvg_id = extract_m3u_attr(trimmed, "tvg-id");
            let tvg_name = extract_m3u_attr(trimmed, "tvg-name");
            let tvg_logo = extract_m3u_attr(trimmed, "tvg-logo");
            let group = extract_m3u_attr(trimmed, "group-title");
            current_extinf = Some((tvg_id, tvg_name, tvg_logo, group));
        } else if !trimmed.is_empty() && !trimmed.starts_with('#') {
            // URL line — pair with previous #EXTINF
            if let Some((tvg_id, name, logo, group)) = current_extinf.take() {
                let norm = normalize_url(trimmed);
                if !norm.is_empty() {
                    if let Err(e) = conn.execute(
                        "INSERT OR IGNORE INTO tmp_m3u_channels
                         (stream_url_normalized, tvg_id, name, logo, group_title)
                         VALUES (?1, ?2, ?3, ?4, ?5)",
                        rusqlite::params![norm, tvg_id, name, logo, group],
                    ) {
                        tracing::debug!(error = %e, "temp table insert skipped");
                    } else {
                        inserted += 1;
                    }
                }
            }
            current_extinf = None;
        }
    }

    // Drop the raw M3U content now — data is in SQLite
    drop(content);

    tracing::debug!(source_id, inserted, "M3U channels loaded into temp table");
    inserted
}

/// Apply tvg_id and metadata from the M3U temp table to Xtream channels.
/// Matches by normalized stream URL.
fn apply_m3u_metadata_from_temp_table(
    service: &CrispyService,
    channels: &mut [Channel],
) {
    let conn = match service.db.get() {
        Ok(c) => c,
        Err(_) => return,
    };

    let mut stmt = match conn.prepare(
        "SELECT tvg_id, name, logo, group_title
         FROM tmp_m3u_channels WHERE stream_url_normalized = ?1",
    ) {
        Ok(s) => s,
        Err(_) => return, // temp table may not exist if M3U download failed
    };

    for ch in channels.iter_mut() {
        let norm = normalize_url(&ch.stream_url);
        if norm.is_empty() {
            continue;
        }
        if let Ok(row) = stmt.query_row(rusqlite::params![norm], |row| {
            Ok((
                row.get::<_, Option<String>>(0)?,
                row.get::<_, Option<String>>(1)?,
                row.get::<_, Option<String>>(2)?,
                row.get::<_, Option<String>>(3)?,
            ))
        }) {
            let (tvg_id, _name, logo, group) = row;
            // Only set tvg_id if channel doesn't already have one from Xtream API
            if ch.tvg_id.as_ref().map_or(true, |t| t.is_empty()) {
                ch.tvg_id = tvg_id;
            }
            // Enrich logo if missing
            if ch.logo_url.as_ref().map_or(true, |l| l.is_empty()) {
                ch.logo_url = logo;
            }
            // group_title from M3U is not stored on Channel directly —
            // Xtream API provides category_id which is resolved separately.
        }
    }
}

/// Drop the M3U temp table after Xtream mapping is complete.
fn drop_m3u_temp_table(service: &CrispyService) {
    if let Ok(conn) = service.db.get() {
        let _ = conn.execute_batch("DROP TABLE IF EXISTS tmp_m3u_channels");
    }
}

/// Extract a named attribute value from an #EXTINF line.
/// e.g. `tvg-id="BBC.One"` → `Some("BBC.One")`
fn extract_m3u_attr(line: &str, attr_name: &str) -> Option<String> {
    let needle = format!("{attr_name}=\"");
    let start = line.find(&needle)? + needle.len();
    let rest = &line[start..];
    let end = rest.find('"')?;
    let val = rest[..end].trim().to_string();
    if val.is_empty() { None } else { Some(val) }
}

/// Apply tvg_id values from the M3U map to Xtream channels.
///
/// For each channel, normalises its stream URL and looks it up in
/// `tvg_map`.  Only sets `tvg_id` when the channel has none or an
/// empty one, so a value already provided by the Xtream API
/// (e.g. `epg_channel_id`) is not overwritten.
fn apply_tvg_ids(channels: &mut Vec<Channel>, tvg_map: &HashMap<String, String>) {
    if tvg_map.is_empty() {
        return;
    }
    for ch in channels.iter_mut() {
        let has_tvg_id = ch.tvg_id.as_deref().is_some_and(|s| !s.is_empty());
        if has_tvg_id {
            continue;
        }
        let norm = normalize_url(&ch.stream_url);
        if let Some(tvg_id) = tvg_map.get(&norm) {
            ch.tvg_id = Some(tvg_id.clone());
        }
    }
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
    enrich_vod_on_sync: bool,
) -> Result<SyncReport> {
    validate_url(base_url).map_err(anyhow::Error::from)?;
    let base = xtream::normalize_base_url(base_url);

    // 0. Download M3U and build a {normalised_url → tvg_id} map.
    //    M3U channels are NOT saved to the database — the map is used
    //    only to populate tvg_id on the Xtream API channels created below.
    //    Failure is non-fatal: we get an empty map and skip tvg_id population.
    emit_progress(
        source_id,
        "m3u_prefetch",
        0.0,
        "Pre-fetching M3U for tvg_id metadata",
    );
    // Step 1: Download M3U into SQLite temp table (not RAM)
    let m3u_count = download_m3u_to_temp_table(
        service,
        &base,
        username,
        password,
        source_id,
        accept_invalid_certs,
    )
    .await;
    tracing::debug!(
        source_id,
        m3u_count,
        "M3U channels loaded into temp table"
    );

    emit_progress(source_id, "categories", 0.05, "Fetching categories");

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

    let mut channels =
        xtream::channels_from_xtream_json(&live_data, &base, username, password, Some(source_id));
    channels = categories::resolve_channel_categories(&channels, &live_cat_map);
    // Populate tvg_id + metadata from M3U temp table before saving.
    // Matches by normalized stream URL against tmp_m3u_channels.
    if m3u_count > 0 {
        apply_m3u_metadata_from_temp_table(service, &mut channels);
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
        xtream::vod_from_xtream_json(&vod_data, &base, username, password, Some(source_id));
    vod_items = categories::resolve_vod_categories(&vod_items, &vod_cat_map);

    // 3b. Optionally enrich each VOD item with full metadata from
    //     `get_vod_info`. Gated by the `enrich_vod_on_sync` setting
    //     because it makes one HTTP request per movie (~4 min for 12K items).
    if enrich_vod_on_sync && !vod_items.is_empty() {
        let total_vod = vod_items.len();
        for (idx, item) in vod_items.iter_mut().enumerate() {
            if idx % 50 == 0 || idx + 1 == total_vod {
                emit_progress(
                    source_id,
                    "vod_enrich",
                    0.4 + 0.15 * (idx as f64 / total_vod.max(1) as f64),
                    &format!("Enriching VOD {}/{}", idx + 1, total_vod),
                );
            }

            // Stream IDs are stored as "vod_<num>"; strip prefix to
            // get the numeric ID for the API call.
            let vod_num_id = item.id.strip_prefix("vod_").unwrap_or(&item.id);

            let info_url = xtream::build_xtream_action_url(
                &base,
                username,
                password,
                "get_vod_info",
                &[("vod_id".to_string(), vod_num_id.to_string())],
            );

            match fetch_json_object(&info_url, accept_invalid_certs).await {
                Ok(info) if !info.is_null() => {
                    vod::enrich_vod_from_info(item, &info);
                }
                // Non-fatal: one item failure must not block the rest.
                Ok(_) | Err(_) => continue,
            }
        }
    }

    emit_progress(source_id, "series", 0.6, "Fetching series");

    // 4. Fetch and parse series — non-fatal.
    let series_data = fetch_json_list(
        &xtream::build_xtream_action_url(&base, username, password, "get_series", &[]),
        accept_invalid_certs,
    )
    .await
    .unwrap_or_default();

    let mut series_items = xtream::series_from_xtream_json(&series_data, Some(source_id));
    series_items = categories::resolve_vod_categories(&series_items, &series_cat_map);

    // 4b. Fetch episodes for each series (Xtream requires a per-series info call).
    //     Capped at 100 to avoid timeout on servers with thousands of series.
    let series_limit = series_items.len().min(100);
    let total_series = series_limit;
    let mut episode_items: Vec<crate::models::VodItem> = Vec::new();

    for (idx, series_item) in series_items.iter().take(series_limit).enumerate() {
        // Series IDs are stored as "series_<num>"; strip prefix to get the numeric ID.
        let series_num_id = series_item
            .id
            .strip_prefix("series_")
            .unwrap_or(&series_item.id);

        emit_progress(
            source_id,
            "episodes",
            0.6 + 0.25 * (idx as f64 / total_series.max(1) as f64),
            &format!("Fetching episodes {}/{}", idx + 1, total_series),
        );

        let info_url = xtream::build_xtream_action_url(
            &base,
            username,
            password,
            "get_series_info",
            &[("series_id".to_string(), series_num_id.to_string())],
        );

        match fetch_json_object(&info_url, accept_invalid_certs).await {
            Ok(info) if !info.is_null() => {
                let mut eps = vod::parse_episodes(&info, &base, username, password, series_num_id);
                // Stamp source_id — parse_episodes leaves it None.
                for ep in &mut eps {
                    ep.source_id = Some(source_id.to_owned());
                }
                episode_items.append(&mut eps);
            }
            // Non-fatal: one series failure must not block the rest.
            Ok(_) | Err(_) => continue,
        }
    }

    vod_items.extend(series_items);
    vod_items.extend(episode_items);

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

    // Drop the M3U temp table now that Xtream mapping is done
    drop_m3u_temp_table(service);

    emit_progress(source_id, "complete", 1.0, "Sync complete");

    Ok(SyncReport {
        channels_count,
        channel_groups,
        vod_count,
        vod_categories: vod_categories_list,
        epg_url: Some(xtream::build_xmltv_url(&base, username, password)),
    })
}

#[cfg(test)]
mod tests {
    use wiremock::matchers::{method, path, query_param};
    use wiremock::{Mock, MockServer, ResponseTemplate};

    use super::*;
    use crate::services::test_helpers::{make_channel, make_service, make_source};

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
    async fn fetch_xtream_account_info_full_response() {
        let mock_server = MockServer::start().await;

        Mock::given(method("GET"))
            .and(path("/player_api.php"))
            .and(query_param("username", "testuser"))
            .and(query_param("password", "testpass"))
            .and(query_param("action", "get_account_info"))
            .respond_with(ResponseTemplate::new(200).set_body_string(
                r#"{
                    "user_info": {
                        "username": "testuser",
                        "password": "testpass",
                        "message": "Welcome",
                        "auth": 1,
                        "status": "Active",
                        "exp_date": "1735689600",
                        "is_trial": "0",
                        "active_cons": "1",
                        "created_at": "1609459200",
                        "max_connections": "2",
                        "allowed_output_formats": ["m3u8", "ts", "rtmp"]
                    },
                    "server_info": {
                        "url": "server.example.com",
                        "port": "80",
                        "https_port": "443",
                        "server_protocol": "http",
                        "rtmp_port": "8088",
                        "timezone": "Europe/London",
                        "timestamp_now": 1711000000,
                        "time_now": "2024-03-21 12:00:00",
                        "process": true
                    }
                }"#,
            ))
            .mount(&mock_server)
            .await;

        let info = fetch_xtream_account_info(&mock_server.uri(), "testuser", "testpass", false)
            .await
            .expect("should parse account info");

        assert_eq!(info.auth, 1);
        assert_eq!(info.username.as_deref(), Some("testuser"));
        assert_eq!(info.message.as_deref(), Some("Welcome"));
        assert_eq!(info.status.as_deref(), Some("Active"));
        assert_eq!(info.exp_date.as_deref(), Some("1735689600"));
        assert_eq!(info.is_trial.as_deref(), Some("0"));
        assert_eq!(info.active_cons.as_deref(), Some("1"));
        assert_eq!(info.created_at.as_deref(), Some("1609459200"));
        assert_eq!(info.max_connections.as_deref(), Some("2"));
        assert_eq!(info.allowed_output_formats, vec!["m3u8", "ts", "rtmp"]);
        assert_eq!(info.server_url.as_deref(), Some("server.example.com"));
        assert_eq!(info.server_port.as_deref(), Some("80"));
        assert_eq!(info.server_https_port.as_deref(), Some("443"));
        assert_eq!(info.server_protocol.as_deref(), Some("http"));
        assert_eq!(info.server_rtmp_port.as_deref(), Some("8088"));
        assert_eq!(info.server_timezone.as_deref(), Some("Europe/London"));
        assert_eq!(info.server_timestamp_now, Some(1711000000));
        assert_eq!(info.server_time_now.as_deref(), Some("2024-03-21 12:00:00"));
    }

    #[tokio::test]
    async fn fetch_xtream_account_info_minimal_response() {
        let mock_server = MockServer::start().await;

        Mock::given(method("GET"))
            .and(path("/player_api.php"))
            .and(query_param("username", "user"))
            .and(query_param("password", "pass"))
            .and(query_param("action", "get_account_info"))
            .respond_with(ResponseTemplate::new(200).set_body_string(r#"{"user_info":{"auth":1}}"#))
            .mount(&mock_server)
            .await;

        let info = fetch_xtream_account_info(&mock_server.uri(), "user", "pass", false)
            .await
            .expect("should parse minimal response");

        assert_eq!(info.auth, 1);
        assert!(info.username.is_none());
        assert!(info.status.is_none());
        assert!(info.exp_date.is_none());
        assert!(info.server_url.is_none());
        assert!(info.allowed_output_formats.is_empty());
    }

    #[tokio::test]
    async fn fetch_xtream_account_info_http_error() {
        let mock_server = MockServer::start().await;

        Mock::given(method("GET"))
            .and(path("/player_api.php"))
            .respond_with(ResponseTemplate::new(403))
            .mount(&mock_server)
            .await;

        let result = fetch_xtream_account_info(&mock_server.uri(), "user", "pass", false).await;

        assert!(result.is_err(), "HTTP 403 should return error");
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
        service
            .save_source(&make_source("src-1", "Xtream Source", "xtream"))
            .unwrap();
        let report = sync_xtream_source(
            &service,
            &mock_server.uri(),
            "test",
            "test",
            "src-1",
            false,
            false,
        )
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

    #[test]
    fn apply_tvg_ids_sets_tvg_id_from_normalised_url_match() {
        let mut ch = make_channel("xt-42", "BBC API");
        ch.stream_url = "HTTP://example.com/live/test/test/42.ts?token=abc".to_string();
        ch.tvg_id = None;

        let mut map = HashMap::new();
        // Insert with the normalised form of the URL (lowercase, no token).
        let norm = normalize_url("HTTP://example.com/live/test/test/42.ts?token=abc");
        map.insert(norm, "bbc.xmltv".to_string());

        let mut channels = vec![ch];
        apply_tvg_ids(&mut channels, &map);

        assert_eq!(
            channels[0].tvg_id.as_deref(),
            Some("bbc.xmltv"),
            "tvg_id should be populated from the map"
        );
    }

    #[test]
    fn apply_tvg_ids_does_not_overwrite_existing_tvg_id() {
        let mut ch = make_channel("xt-99", "CNN");
        ch.stream_url = "http://example.com/live/u/p/99.ts".to_string();
        ch.tvg_id = Some("cnn.existing".to_string());

        let mut map = HashMap::new();
        map.insert(normalize_url(&ch.stream_url), "cnn.from_m3u".to_string());

        let mut channels = vec![ch];
        apply_tvg_ids(&mut channels, &map);

        assert_eq!(
            channels[0].tvg_id.as_deref(),
            Some("cnn.existing"),
            "existing tvg_id must not be overwritten"
        );
    }

    #[test]
    fn apply_tvg_ids_skips_channels_with_no_map_entry() {
        let mut ch = make_channel("xt-1", "Unknown");
        ch.stream_url = "http://example.com/live/u/p/1.ts".to_string();
        ch.tvg_id = None;

        let map: HashMap<String, String> = HashMap::new();
        let mut channels = vec![ch];
        apply_tvg_ids(&mut channels, &map);

        assert!(
            channels[0].tvg_id.is_none(),
            "tvg_id should remain None when map has no entry"
        );
    }
}
