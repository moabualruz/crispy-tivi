use super::from_json;
use anyhow::Result;

/// Parse M3U/M3U8 playlist content.
/// Returns JSON `{"channels":[...],"epg_url":...}`
pub fn parse_m3u(content: String) -> Result<String> {
    let result = crispy_core::parsers::m3u::parse_m3u(&content);
    Ok(serde_json::to_string(&result)?)
}

/// Parse XMLTV EPG content.
/// Returns JSON array of EPG entries.
pub fn parse_epg(content: String) -> Result<String> {
    let entries = crispy_core::parsers::epg::parse_epg(&content);
    Ok(serde_json::to_string(&entries)?)
}

/// Extract XMLTV channel display names.
/// Returns JSON `{"xmltv_id":"display_name",...}`
pub fn extract_epg_channel_names(content: String) -> Result<String> {
    let names = crispy_core::parsers::epg::extract_channel_names(&content);
    Ok(serde_json::to_string(&names)?)
}

/// Parse Xtream `get_vod_streams` JSON response.
/// Returns JSON array of VodItem.
pub fn parse_vod_streams(
    json: String,
    base_url: String,
    username: String,
    password: String,
    source_id: Option<String>,
) -> Result<String> {
    let data: Vec<serde_json::Value> = from_json(&json)?;
    let items = crispy_core::parsers::vod::parse_vod_streams(
        &data,
        &base_url,
        &username,
        &password,
        source_id.as_deref(),
    );
    Ok(serde_json::to_string(&items)?)
}

/// Parse Xtream `get_series` JSON response.
/// Returns JSON array of VodItem.
pub fn parse_series(json: String, source_id: Option<String>) -> Result<String> {
    let data: Vec<serde_json::Value> = from_json(&json)?;
    let items = crispy_core::parsers::vod::parse_series(&data, source_id.as_deref());
    Ok(serde_json::to_string(&items)?)
}

/// Parse episodes from `get_series_info` response.
/// Returns JSON array of VodItem.
pub fn parse_episodes(
    json: String,
    base_url: String,
    username: String,
    password: String,
    series_id: String,
) -> Result<String> {
    let data: serde_json::Value = from_json(&json)?;
    let items = crispy_core::parsers::vod::parse_episodes(
        &data, &base_url, &username, &password, &series_id,
    );
    Ok(serde_json::to_string(&items)?)
}

/// Parse VOD entries from M3U channel maps.
/// Returns JSON array of VodItem.
pub fn parse_m3u_vod(json: String, source_id: Option<String>) -> Result<String> {
    let channels: Vec<serde_json::Value> = from_json(&json)?;
    let items = crispy_core::parsers::vod::parse_m3u_vod(&channels, source_id.as_deref());
    Ok(serde_json::to_string(&items)?)
}

/// Parse WebVTT thumbnail sprite sheet.
/// Returns JSON of ThumbnailSprite or null.
pub fn parse_vtt_thumbnails(content: String, base_url: String) -> Result<Option<String>> {
    match crispy_core::parsers::vtt::parse_vtt(&content, &base_url) {
        Some(sprite) => Ok(Some(serde_json::to_string(&sprite)?)),
        None => Ok(None),
    }
}

// ── BIF Trickplay Parser ────────────────────────────

/// Parse a BIF file's index table.
/// Returns JSON array of `{timestamp_ms, offset, length}`.
pub fn parse_bif_index(data: Vec<u8>) -> Result<String> {
    let entries = crispy_core::parsers::bif::parse_bif_index(&data);
    Ok(serde_json::to_string(&entries)?)
}

/// Find the BIF thumbnail nearest to the target timestamp
/// and extract its JPEG bytes.
///
/// `index_json` is the JSON array returned by `parse_bif_index`.
/// Returns the JPEG bytes, or an empty vec if not found.
pub fn get_bif_thumbnail(data: Vec<u8>, index_json: String, timestamp_ms: i64) -> Result<Vec<u8>> {
    let entries: Vec<crispy_core::parsers::bif::BifEntry> = serde_json::from_str(&index_json)?;
    let ts = if timestamp_ms < 0 {
        0u64
    } else {
        timestamp_ms as u64
    };
    match crispy_core::parsers::bif::find_bif_entry(&entries, ts) {
        Some(entry) => {
            Ok(crispy_core::parsers::bif::extract_bif_thumbnail(&data, entry).unwrap_or_default())
        }
        None => Ok(Vec::new()),
    }
}

// ── Stalker Parsers ─────────────────────────────────

/// Parse Stalker EPG entries for a channel.
/// Returns JSON array of EpgEntry objects.
pub fn parse_stalker_epg(json: String, channel_id: String) -> Result<String> {
    let entries = crispy_core::parsers::stalker::parse_stalker_epg(&json, &channel_id);
    Ok(serde_json::to_string(&entries)?)
}

/// Parse Stalker VOD items list.
/// Returns JSON array of VodItem objects.
pub fn parse_stalker_vod_items(
    json: String,
    base_url: String,
    vod_type: Option<String>,
) -> Result<String> {
    let data: Vec<serde_json::Value> = from_json(&json)?;
    let vt = vod_type.as_deref().unwrap_or("movie");
    let items = crispy_core::parsers::stalker::parse_stalker_vod_items(&data, &base_url, vt);
    Ok(serde_json::to_string(&items)?)
}

/// Parse Stalker channels paginated result.
/// Returns JSON of StalkerPaginatedResult.
pub fn parse_stalker_channels(json: String) -> Result<String> {
    let result = crispy_core::parsers::stalker::parse_stalker_channels_result(&json);
    Ok(serde_json::to_string(&result)?)
}

/// Parse Stalker live streams into Channel objects.
/// Returns JSON array of Channel.
pub fn parse_stalker_live_streams(
    json: String,
    source_id: String,
    base_url: String,
) -> Result<String> {
    let data: Vec<serde_json::Value> = from_json(&json)?;
    let channels =
        crispy_core::parsers::stalker::parse_stalker_live_streams(&data, &source_id, &base_url);
    Ok(serde_json::to_string(&channels)?)
}

/// Build a stream URL from a Stalker `cmd` field.
/// Returns the resolved URL string.
#[flutter_rust_bridge::frb(sync)]
pub fn build_stalker_stream_url(cmd: String, base_url: String) -> String {
    crispy_core::parsers::stalker::build_stalker_stream_url(&cmd, &base_url)
}

/// Parse a Stalker `create_link` response.
/// Returns the authenticated stream URL or null.
pub fn parse_stalker_create_link(json: String, base_url: String) -> Result<Option<String>> {
    Ok(crispy_core::parsers::stalker::parse_stalker_create_link(
        &json, &base_url,
    ))
}

/// Parse Stalker categories from genres response.
/// Returns JSON array of StalkerCategory.
pub fn parse_stalker_categories(json: String) -> Result<String> {
    let cats = crispy_core::parsers::stalker::parse_stalker_categories(&json);
    Ok(serde_json::to_string(&cats)?)
}

/// Parse Stalker VOD paginated result.
/// Returns JSON of StalkerPaginatedResult.
pub fn parse_stalker_vod_result(json: String) -> Result<String> {
    let result = crispy_core::parsers::stalker::parse_stalker_vod_result(&json);
    Ok(serde_json::to_string(&result)?)
}

// ── Xtream Parsers ──────────────────────────────────

/// Build an Xtream API action URL.
#[flutter_rust_bridge::frb(sync)]
pub fn build_xtream_action_url(
    base_url: String,
    username: String,
    password: String,
    action: String,
    params_json: Option<String>,
) -> Result<String> {
    let params: Vec<(String, String)> = match params_json {
        Some(ref j) if !j.is_empty() => {
            let map: serde_json::Map<String, serde_json::Value> = from_json(j)?;
            map.into_iter()
                .map(|(k, v)| (k, v.as_str().unwrap_or("").to_string()))
                .collect()
        }
        _ => Vec::new(),
    };
    Ok(crispy_core::parsers::xtream::build_xtream_action_url(
        &base_url, &username, &password, &action, &params,
    ))
}

/// Build an Xtream stream URL.
#[flutter_rust_bridge::frb(sync)]
pub fn build_xtream_stream_url(
    base_url: String,
    username: String,
    password: String,
    stream_id: i64,
    stream_type: String,
    extension: String,
) -> String {
    crispy_core::parsers::xtream::build_xtream_stream_url(
        &base_url,
        &username,
        &password,
        stream_id,
        &stream_type,
        &extension,
    )
}

/// Build an Xtream catchup/timeshift URL.
#[flutter_rust_bridge::frb(sync)]
pub fn build_xtream_catchup_url(
    base_url: String,
    username: String,
    password: String,
    stream_id: i64,
    start_utc: i64,
    duration_minutes: i32,
) -> String {
    crispy_core::parsers::xtream::build_xtream_catchup_url(
        &base_url,
        &username,
        &password,
        stream_id,
        start_utc,
        duration_minutes,
    )
}

/// Parse Xtream live streams JSON into channels.
/// Returns JSON array of Channel.
pub fn parse_xtream_live_streams(
    json: String,
    base_url: String,
    username: String,
    password: String,
) -> Result<String> {
    let data: Vec<serde_json::Value> = from_json(&json)?;
    let channels = crispy_core::parsers::xtream::parse_xtream_live_streams(
        &data, &base_url, &username, &password,
    );
    Ok(serde_json::to_string(&channels)?)
}

/// Parse Xtream categories into sorted names.
/// Returns JSON array of strings.
pub fn parse_xtream_categories(json: String) -> Result<String> {
    let data: Vec<serde_json::Value> = from_json(&json)?;
    let names = crispy_core::parsers::xtream::parse_xtream_categories(&data);
    Ok(serde_json::to_string(&names)?)
}

// ── S3 Parser ─────────────────────────────────────

/// Parse S3 ListBucketResult XML response.
/// Returns JSON array of S3Object.
pub fn parse_s3_list_objects(xml: String) -> Result<String> {
    let objects = crispy_core::parsers::s3::parse_s3_list_objects(&xml);
    Ok(serde_json::to_string(&objects)?)
}
