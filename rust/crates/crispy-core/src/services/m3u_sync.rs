//! M3U source synchronisation.
//!
//! Fetches an M3U/M3U8 playlist over HTTP, parses it with the
//! existing Rust parser, extracts VOD items, and persists
//! everything to the local database.

use anyhow::{Context, Result};

use crate::algorithms::categories;
use crate::http_client::get_shared_client;
use crate::models::SyncReport;
use crate::parsers::{m3u, vod};
use crate::services::CrispyService;
use crate::services::url_validator::validate_url;
use crate::sync_progress::emit_progress;

pub async fn verify_m3u_url(url: &str, accept_invalid_certs: bool) -> Result<bool> {
    validate_url(url).map_err(anyhow::Error::from)?;
    let client = get_shared_client(accept_invalid_certs);
    let req = client.head(url).send().await;
    match req {
        Ok(res) => {
            // 405 means server is reachable but doesn't support HEAD
            Ok(res.status().is_success() || res.status().as_u16() == 405)
        }
        Err(e) => Err(anyhow::anyhow!("Connection error: {}", e)),
    }
}

/// Fetches, parses, and saves an M3U playlist.
///
/// Downloads the M3U content, parses channels and EPG URL,
/// extracts VOD items, saves to DB, and returns a report.
pub async fn sync_m3u_source(
    service: &CrispyService,
    url: &str,
    source_id: &str,
    accept_invalid_certs: bool,
) -> Result<SyncReport> {
    validate_url(url).map_err(anyhow::Error::from)?;
    emit_progress(source_id, "downloading", 0.0, "Downloading M3U playlist");

    // 1. Download M3U content.
    let bytes = get_shared_client(accept_invalid_certs)
        .get(url)
        .send()
        .await
        .context("Failed to download M3U playlist")?
        .bytes()
        .await
        .context("Failed to read M3U payload")?;
    let content = String::from_utf8_lossy(&bytes).into_owned();

    if content.is_empty() {
        return Ok(SyncReport::default());
    }

    emit_progress(source_id, "parsing", 0.3, "Parsing M3U content");

    // 2. Parse M3U into channels + optional EPG URL.
    let result = m3u::parse_m3u(&content);
    let mut channels = result.channels;

    // Set source_id on all channels — the M3U parser leaves it None.
    for ch in &mut channels {
        ch.source_id = Some(source_id.to_owned());
    }

    // 3. Convert Channel structs to serde_json::Value for the VOD parser.
    //
    // `parse_m3u_vod` accepts &[Value] and reads both camelCase
    // (`streamUrl`, `logoUrl`) and snake_case (`stream_url`,
    // `logo_url`, `channel_group`) field names, so serialising
    // `Channel` directly (which uses snake_case) is correct.
    let channels_json: Vec<serde_json::Value> = channels
        .iter()
        .map(|ch| serde_json::to_value(ch).unwrap_or_default())
        .collect();
    let vod_items = vod::parse_m3u_vod(&channels_json, Some(source_id));

    // 4. Extract sorted group / category names for the report.
    let channel_groups = categories::extract_sorted_groups(&channels);
    let vod_categories = categories::extract_sorted_vod_categories(&vod_items);

    // 5. Snapshot counts and IDs before moving into the batch closure.
    let channels_count = channels.len();
    let vod_count = vod_items.len();
    let channel_ids: Vec<String> = channels.iter().map(|c| c.id.clone()).collect();
    let vod_ids: Vec<String> = vod_items.iter().map(|v| v.id.clone()).collect();

    emit_progress(source_id, "saving", 0.8, "Saving to database");

    // 6. Persist all data inside a single batch so Flutter gets one
    //    BulkDataRefresh event instead of four separate events.
    service
        .save_sync_data(source_id, &channels, &channel_ids, &vod_items, &vod_ids)
        .context("Failed to persist M3U sync data")?;

    emit_progress(source_id, "complete", 1.0, "Sync complete");

    Ok(SyncReport {
        channels_count,
        channel_groups,
        vod_count,
        vod_categories,
        epg_url: result.epg_url,
    })
}

#[cfg(test)]
mod tests {
    use wiremock::matchers::{method, path};
    use wiremock::{Mock, MockServer, ResponseTemplate};

    use super::*;
    use crate::services::test_helpers::make_service;

    #[tokio::test]
    async fn sync_m3u_source_basic() {
        let mock_server = MockServer::start().await;

        let m3u_content = "#EXTM3U\n\
            #EXTINF:-1 group-title=\"News\",Channel 1\n\
            http://example.com/stream1\n\
            #EXTINF:-1 group-title=\"Sports\",Channel 2\n\
            http://example.com/stream2\n";

        Mock::given(method("GET"))
            .and(path("/playlist.m3u"))
            .respond_with(ResponseTemplate::new(200).set_body_string(m3u_content))
            .mount(&mock_server)
            .await;

        let url = format!("{}/playlist.m3u", mock_server.uri());
        let service = make_service();
        let report = sync_m3u_source(&service, &url, "src-1", false)
            .await
            .expect("sync should succeed");

        assert_eq!(report.channels_count, 2, "expected 2 channels");
        assert!(
            report.channel_groups.contains(&"News".to_string()),
            "expected News group"
        );
        assert!(
            report.channel_groups.contains(&"Sports".to_string()),
            "expected Sports group"
        );
    }

    #[tokio::test]
    async fn sync_m3u_source_empty() {
        let mock_server = MockServer::start().await;

        Mock::given(method("GET"))
            .and(path("/empty.m3u"))
            .respond_with(ResponseTemplate::new(200).set_body_string("#EXTM3U\n"))
            .mount(&mock_server)
            .await;

        let url = format!("{}/empty.m3u", mock_server.uri());
        let service = make_service();
        let report = sync_m3u_source(&service, &url, "src-empty", false)
            .await
            .expect("sync should succeed");

        assert_eq!(
            report.channels_count, 0,
            "expected 0 channels for empty playlist"
        );
    }

    #[tokio::test]
    async fn sync_m3u_source_with_epg() {
        let mock_server = MockServer::start().await;

        let epg_url = "http://example.com/epg.xml";
        let m3u_content = format!(
            "#EXTM3U url-tvg=\"{epg_url}\"\n\
            #EXTINF:-1,Test Channel\n\
            http://example.com/stream1\n"
        );

        Mock::given(method("GET"))
            .and(path("/epg_playlist.m3u"))
            .respond_with(ResponseTemplate::new(200).set_body_string(m3u_content))
            .mount(&mock_server)
            .await;

        let url = format!("{}/epg_playlist.m3u", mock_server.uri());
        let service = make_service();
        let report = sync_m3u_source(&service, &url, "src-epg", false)
            .await
            .expect("sync should succeed");

        assert_eq!(report.channels_count, 1, "expected 1 channel");
        assert_eq!(
            report.epg_url.as_deref(),
            Some(epg_url),
            "expected EPG URL to be set"
        );
    }
}
