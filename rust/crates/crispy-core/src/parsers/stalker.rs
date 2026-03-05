//! Stalker Portal (MAG middleware) response parsers.
//!
//! Ported from Dart `stalker_portal_client.dart`. Pure
//! functions, no DB or network access.

use chrono::DateTime;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::models::{Channel, EpgEntry, VodItem};

// ── Public types ──────────────────────────────────

/// A category parsed from Stalker genres response.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StalkerCategory {
    /// Category identifier.
    pub id: String,
    /// Human-readable title.
    pub title: String,
}

/// Paginated result from Stalker ordered-list endpoints.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StalkerPaginatedResult {
    /// Raw JSON items from the `data` array.
    pub items: Vec<Value>,
    /// Total items available on the server.
    pub total_items: i32,
    /// Maximum items per page (default 25).
    pub max_page_items: i32,
}

// ── Internal helpers ──────────────────────────────

/// Extracts the `js` field from a Stalker wrapped
/// response. If the value is an object with a `js`
/// key, returns that. Otherwise returns the value
/// itself.
fn extract_js(value: &Value) -> Option<&Value> {
    match value {
        Value::Object(map) => map.get("js").or(Some(value)),
        Value::Null => None,
        _ => Some(value),
    }
}

/// Parses a JSON value as an i64, handling both
/// integer and string representations.
fn value_as_i64(v: &Value) -> Option<i64> {
    v.as_i64()
        .or_else(|| v.as_str().and_then(|s| s.parse::<i64>().ok()))
}

/// Parses a JSON value as an i32, handling both
/// integer and string representations.
fn value_as_i32(v: &Value) -> Option<i32> {
    value_as_i64(v).map(|n| n as i32)
}

/// Extracts a non-empty string from a JSON value.
fn non_empty_str(v: &Value) -> Option<&str> {
    v.as_str().filter(|s| !s.is_empty())
}

// ── Stream URL builder ────────────────────────────

/// Builds a stream URL from a Stalker `cmd` field.
///
/// Stalker `cmd` values may be:
/// - Full URL: `http://...`
/// - Relative path: `/live/...`
/// - Command format: `ffrt http://...`
/// - Command format: `ffmpeg http://...`
pub fn build_stalker_stream_url(cmd: &str, base_url: &str) -> String {
    let url = cmd.trim();

    // Handle "ffrt ..." or "ffmpeg ..." prefix.
    let url = if url.starts_with("ffrt ") || url.starts_with("ffmpeg ") {
        match url.find(' ') {
            Some(pos) => url[pos + 1..].trim(),
            None => url,
        }
    } else {
        url
    };

    // Already absolute URL.
    if url.starts_with("http://") || url.starts_with("https://") {
        return url.to_string();
    }

    // Relative path.
    if url.starts_with('/') {
        return format!("{}{}", base_url, url);
    }

    format!("{}/{}", base_url, url)
}

// ── Category parser ───────────────────────────────

/// Parses categories from Stalker genres response.
///
/// Input JSON: `{"js": [{"id": "1", "title": "News"}, ...]}`
pub fn parse_stalker_categories(json: &str) -> Vec<StalkerCategory> {
    let value: Value = match serde_json::from_str(json) {
        Ok(v) => v,
        Err(_) => return Vec::new(),
    };

    let js = match extract_js(&value) {
        Some(v) => v,
        None => return Vec::new(),
    };

    let arr = match js.as_array() {
        Some(a) => a,
        None => return Vec::new(),
    };

    arr.iter()
        .filter_map(|item| {
            let map = item.as_object()?;
            let id = map
                .get("id")
                .map(|v| {
                    v.as_str()
                        .map(String::from)
                        .unwrap_or_else(|| v.to_string())
                })
                .unwrap_or_default();
            let title = map
                .get("title")
                .and_then(|v| v.as_str())
                .unwrap_or("Unknown");
            Some(StalkerCategory {
                id,
                title: title.to_string(),
            })
        })
        .collect()
}

// ── Channels result parser ────────────────────────

/// Parses a paginated channels result from Stalker.
///
/// Input JSON:
/// ```json
/// {"js": {"total_items": 100, "max_page_items": 25,
///         "data": [...]}}
/// ```
pub fn parse_stalker_channels_result(json: &str) -> StalkerPaginatedResult {
    parse_paginated_result(json)
}

/// Parses a paginated VOD result from Stalker.
///
/// Same structure as channels result.
pub fn parse_stalker_vod_result(json: &str) -> StalkerPaginatedResult {
    parse_paginated_result(json)
}

/// Shared implementation for paginated results.
fn parse_paginated_result(json: &str) -> StalkerPaginatedResult {
    let empty = StalkerPaginatedResult {
        items: Vec::new(),
        total_items: 0,
        max_page_items: 25,
    };

    let value: Value = match serde_json::from_str(json) {
        Ok(v) => v,
        Err(_) => return empty,
    };

    let js = match extract_js(&value) {
        Some(v) => v,
        None => return empty,
    };

    let map = match js.as_object() {
        Some(m) => m,
        None => return empty,
    };

    let total_items = map.get("total_items").and_then(value_as_i32).unwrap_or(0);
    let max_page_items = map
        .get("max_page_items")
        .and_then(value_as_i32)
        .unwrap_or(25);
    let items = map
        .get("data")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();

    StalkerPaginatedResult {
        items,
        total_items,
        max_page_items,
    }
}

// ── Live streams parser ───────────────────────────

/// Converts Stalker channel list into [`Channel`]
/// structs.
///
/// Each item must have `id` and `cmd` fields.
/// `base_url` is used to resolve relative stream
/// URLs.
pub fn parse_stalker_live_streams(data: &[Value], source_id: &str, base_url: &str) -> Vec<Channel> {
    data.iter()
        .filter_map(|item| {
            let map = item.as_object()?;

            let id = map
                .get("id")
                .map(|v| {
                    v.as_str()
                        .map(String::from)
                        .unwrap_or_else(|| v.to_string())
                })
                .unwrap_or_default();

            let cmd = map.get("cmd").and_then(|v| v.as_str()).unwrap_or("");

            let name = map
                .get("name")
                .and_then(|v| v.as_str())
                .unwrap_or("Unknown");

            let group = map.get("tv_genre_id").map(|v| {
                v.as_str()
                    .map(String::from)
                    .unwrap_or_else(|| v.to_string())
            });

            let logo_url = map.get("logo").and_then(|v| v.as_str()).map(String::from);

            let xmltv_id = map
                .get("xmltv_id")
                .and_then(non_empty_str)
                .map(String::from);

            let tvg_id = xmltv_id.clone().or_else(|| Some(id.clone()));

            let number = map.get("number").and_then(value_as_i32);

            let tv_archive = map.get("tv_archive").and_then(value_as_i64).unwrap_or(0);
            let tv_archive_dur = map
                .get("tv_archive_duration")
                .and_then(value_as_i32)
                .unwrap_or(0);

            let has_catchup = tv_archive == 1 && tv_archive_dur > 0;

            let stream_url = build_stalker_stream_url(cmd, base_url);

            Some(Channel {
                id: format!("stk_{}", id),
                name: name.to_string(),
                stream_url,
                number,
                channel_group: group,
                logo_url,
                tvg_id,
                tvg_name: None,
                is_favorite: false,
                user_agent: None,
                has_catchup,
                catchup_days: tv_archive_dur,
                catchup_type: None,
                catchup_source: None,
                resolution: None,
                source_id: Some(source_id.to_string()),
                added_at: None,
                updated_at: None,
            })
        })
        .collect()
}

// ── EPG parser ────────────────────────────────────

/// Parses EPG entries from Stalker short_epg or
/// epg_info response.
///
/// Handles multiple timestamp key variants:
/// - `t_time` / `t_time_to`
/// - `start` / `stop`
/// - `time` / `time_to`
///
/// Timestamps are Unix seconds (int or string).
pub fn parse_stalker_epg(json: &str, channel_id: &str) -> Vec<EpgEntry> {
    let value: Value = match serde_json::from_str(json) {
        Ok(v) => v,
        Err(_) => return Vec::new(),
    };

    let js = match extract_js(&value) {
        Some(v) => v,
        None => return Vec::new(),
    };

    // Handle both direct list and {data: [...]}
    let entries: &[Value] = if let Some(arr) = js.as_array() {
        arr
    } else if let Some(map) = js.as_object() {
        match map.get("data").and_then(Value::as_array) {
            Some(arr) => arr,
            None => return Vec::new(),
        }
    } else {
        return Vec::new();
    };

    entries
        .iter()
        .filter_map(|item| parse_single_epg_entry(item, channel_id))
        .collect()
}

/// Parses one EPG entry from a Stalker JSON object.
fn parse_single_epg_entry(item: &Value, channel_id: &str) -> Option<EpgEntry> {
    let map = item.as_object()?;

    let title = map.get("name").and_then(|v| v.as_str()).unwrap_or("");
    if title.is_empty() {
        return None;
    }

    // Start timestamp: t_time > start > time
    let start_val = map
        .get("t_time")
        .or_else(|| map.get("start"))
        .or_else(|| map.get("time"))?;
    let start_secs = value_as_i64(start_val)?;

    let start_time = DateTime::from_timestamp(start_secs, 0).map(|dt| dt.naive_utc())?;

    // End timestamp: t_time_to > stop > time_to
    let end_val = map
        .get("t_time_to")
        .or_else(|| map.get("stop"))
        .or_else(|| map.get("time_to"));

    let end_time = if let Some(ev) = end_val {
        if let Some(end_secs) = value_as_i64(ev) {
            DateTime::from_timestamp(end_secs, 0).map(|dt| dt.naive_utc())?
        } else {
            // Unparseable end → default 30 min
            start_time + chrono::Duration::minutes(30)
        }
    } else {
        // No end field → use duration or default 30
        let dur_min = map.get("duration").and_then(value_as_i64).unwrap_or(30);
        start_time + chrono::Duration::minutes(dur_min)
    };

    let description = map
        .get("descr")
        .or_else(|| map.get("description"))
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty())
        .map(String::from);

    let category = map
        .get("category")
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty())
        .map(String::from);

    Some(EpgEntry {
        channel_id: channel_id.to_string(),
        title: title.to_string(),
        start_time,
        end_time,
        description,
        category,
        icon_url: None,
        source_id: None,
    })
}

// ── VOD items parser ──────────────────────────────

/// Converts Stalker VOD list into [`VodItem`] structs.
///
/// Skips items with empty `id` or `cmd`. Rating
/// priority: `rating_kinopoisk` > `rating_imdb`.
pub fn parse_stalker_vod_items(data: &[Value], base_url: &str, vod_type: &str) -> Vec<VodItem> {
    data.iter()
        .filter_map(|item| {
            let map = item.as_object()?;

            let id = map
                .get("id")
                .map(|v| {
                    v.as_str()
                        .map(String::from)
                        .unwrap_or_else(|| v.to_string())
                })
                .unwrap_or_default();

            let cmd = map.get("cmd").and_then(|v| v.as_str()).unwrap_or("");

            if id.is_empty() || cmd.is_empty() {
                return None;
            }

            let name = map
                .get("name")
                .and_then(|v| v.as_str())
                .unwrap_or("Unknown");

            let stream_url = build_stalker_stream_url(cmd, base_url);

            // Poster: screenshot_uri > logo
            let poster_url = map
                .get("screenshot_uri")
                .and_then(non_empty_str)
                .or_else(|| map.get("logo").and_then(non_empty_str))
                .map(String::from);

            let description = map
                .get("description")
                .and_then(non_empty_str)
                .map(String::from);

            // Rating: kinopoisk > imdb
            let rating = rating_priority(map);

            let year = map.get("year").and_then(value_as_i32);

            let duration = map.get("time").and_then(value_as_i32);

            let category = map.get("category_id").map(|v| {
                v.as_str()
                    .map(String::from)
                    .unwrap_or_else(|| v.to_string())
            });

            Some(VodItem {
                id: format!("stk_vod_{}", id),
                name: name.to_string(),
                stream_url,
                item_type: vod_type.to_string(),
                poster_url,
                backdrop_url: None,
                description,
                rating,
                year,
                duration,
                category,
                series_id: None,
                season_number: None,
                episode_number: None,
                ext: None,
                is_favorite: false,
                added_at: None,
                updated_at: None,
                source_id: None,
            })
        })
        .collect()
}

/// Picks the best rating: kinopoisk if non-zero,
/// else imdb if non-zero, else None.
fn rating_priority(map: &serde_json::Map<String, Value>) -> Option<String> {
    let kp = map
        .get("rating_kinopoisk")
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty() && *s != "0");

    if kp.is_some() {
        return kp.map(String::from);
    }

    map.get("rating_imdb")
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty() && *s != "0")
        .map(String::from)
}

// ── Create link parser ────────────────────────────

/// Parses a `create_link` response to extract the
/// authenticated stream URL.
///
/// Input JSON:
/// ```json
/// {"js": {"cmd": "ffrt http://server/stream.m3u8?token=xyz"}}
/// ```
pub fn parse_stalker_create_link(json: &str, base_url: &str) -> Option<String> {
    let value: Value = serde_json::from_str(json).ok()?;

    let js = extract_js(&value)?;
    let map = js.as_object()?;
    let cmd = map
        .get("cmd")
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty())?;

    let url = build_stalker_stream_url(cmd, base_url);
    if url.is_empty() { None } else { Some(url) }
}

// ── Tests ─────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    // ── build_stalker_stream_url ──────────────

    #[test]
    fn stream_url_ffrt_prefix() {
        let url = build_stalker_stream_url("ffrt http://server/stream.m3u8", "http://portal.com");
        assert_eq!(url, "http://server/stream.m3u8");
    }

    #[test]
    fn stream_url_ffmpeg_prefix() {
        let url = build_stalker_stream_url("ffmpeg http://server/live.ts", "http://portal.com");
        assert_eq!(url, "http://server/live.ts");
    }

    #[test]
    fn stream_url_absolute() {
        let url = build_stalker_stream_url("https://cdn.example.com/ch1.m3u8", "http://portal.com");
        assert_eq!(url, "https://cdn.example.com/ch1.m3u8",);
    }

    #[test]
    fn stream_url_relative_with_slash() {
        let url = build_stalker_stream_url("/live/stream/1.ts", "http://portal.com");
        assert_eq!(url, "http://portal.com/live/stream/1.ts",);
    }

    #[test]
    fn stream_url_relative_without_slash() {
        let url = build_stalker_stream_url("live/stream/1.ts", "http://portal.com");
        assert_eq!(url, "http://portal.com/live/stream/1.ts",);
    }

    #[test]
    fn stream_url_whitespace_trimmed() {
        let url = build_stalker_stream_url("  http://server/stream.ts  ", "http://portal.com");
        assert_eq!(url, "http://server/stream.ts");
    }

    // ── parse_stalker_categories ──────────────

    #[test]
    fn categories_basic() {
        let json = json!({
            "js": [
                {"id": "1", "title": "News"},
                {"id": 2, "title": "Sports"},
            ]
        })
        .to_string();

        let cats = parse_stalker_categories(&json);
        assert_eq!(cats.len(), 2);
        assert_eq!(cats[0].id, "1");
        assert_eq!(cats[0].title, "News");
        assert_eq!(cats[1].id, "2");
        assert_eq!(cats[1].title, "Sports");
    }

    #[test]
    fn categories_empty_js() {
        let json = json!({"js": null}).to_string();
        let cats = parse_stalker_categories(&json);
        assert!(cats.is_empty());
    }

    #[test]
    fn categories_invalid_json() {
        let cats = parse_stalker_categories("not json");
        assert!(cats.is_empty());
    }

    #[test]
    fn categories_missing_title() {
        let json = json!({
            "js": [{"id": "1"}]
        })
        .to_string();

        let cats = parse_stalker_categories(&json);
        assert_eq!(cats.len(), 1);
        assert_eq!(cats[0].title, "Unknown");
    }

    // ── parse_stalker_channels_result ─────────

    #[test]
    fn channels_result_basic() {
        let json = json!({
            "js": {
                "total_items": 50,
                "max_page_items": 10,
                "data": [
                    {"id": "1", "name": "BBC"},
                    {"id": "2", "name": "CNN"},
                ]
            }
        })
        .to_string();

        let result = parse_stalker_channels_result(&json);
        assert_eq!(result.total_items, 50);
        assert_eq!(result.max_page_items, 10);
        assert_eq!(result.items.len(), 2);
    }

    #[test]
    fn channels_result_empty() {
        let json = json!({"js": null}).to_string();
        let result = parse_stalker_channels_result(&json);
        assert_eq!(result.total_items, 0);
        assert_eq!(result.max_page_items, 25);
        assert!(result.items.is_empty());
    }

    #[test]
    fn channels_result_string_total() {
        let json = json!({
            "js": {
                "total_items": "100",
                "max_page_items": "20",
                "data": []
            }
        })
        .to_string();

        let result = parse_stalker_channels_result(&json);
        assert_eq!(result.total_items, 100);
        assert_eq!(result.max_page_items, 20);
    }

    // ── parse_stalker_live_streams ────────────

    #[test]
    fn live_streams_basic() {
        let data = vec![json!({
            "id": "42",
            "name": "Channel One",
            "cmd": "ffrt http://cdn.tv/ch1.m3u8",
            "tv_genre_id": "5",
            "logo": "http://img/ch1.png",
            "xmltv_id": "ch1.epg",
            "number": "7",
            "tv_archive": 1,
            "tv_archive_duration": 3,
        })];

        let channels = parse_stalker_live_streams(&data, "src_1", "http://portal.com");

        assert_eq!(channels.len(), 1);
        let ch = &channels[0];
        assert_eq!(ch.id, "stk_42");
        assert_eq!(ch.name, "Channel One");
        assert_eq!(ch.stream_url, "http://cdn.tv/ch1.m3u8",);
        assert_eq!(ch.channel_group.as_deref(), Some("5"),);
        assert_eq!(ch.logo_url.as_deref(), Some("http://img/ch1.png"),);
        assert_eq!(ch.tvg_id.as_deref(), Some("ch1.epg"),);
        assert_eq!(ch.number, Some(7));
        assert!(ch.has_catchup);
        assert_eq!(ch.catchup_days, 3);
        assert_eq!(ch.source_id.as_deref(), Some("src_1"),);
    }

    #[test]
    fn live_streams_empty_xmltv_uses_id() {
        let data = vec![json!({
            "id": "99",
            "name": "Test",
            "cmd": "http://tv/99",
            "xmltv_id": "",
        })];

        let channels = parse_stalker_live_streams(&data, "s1", "http://portal.com");

        assert_eq!(channels[0].tvg_id.as_deref(), Some("99"),);
    }

    #[test]
    fn live_streams_no_catchup() {
        let data = vec![json!({
            "id": "10",
            "name": "NoCatchup",
            "cmd": "http://tv/10",
            "tv_archive": 0,
            "tv_archive_duration": 0,
        })];

        let channels = parse_stalker_live_streams(&data, "s1", "http://portal.com");

        assert!(!channels[0].has_catchup);
        assert_eq!(channels[0].catchup_days, 0);
    }

    // ── parse_stalker_epg ─────────────────────

    #[test]
    fn epg_with_t_time_keys() {
        let json = json!({
            "js": {
                "data": [
                    {
                        "name": "News Hour",
                        "t_time": "1705312800",
                        "t_time_to": "1705316400",
                        "descr": "Top stories",
                        "category": "News",
                    }
                ]
            }
        })
        .to_string();

        let entries = parse_stalker_epg(&json, "ch_1");
        assert_eq!(entries.len(), 1);

        let e = &entries[0];
        assert_eq!(e.channel_id, "ch_1");
        assert_eq!(e.title, "News Hour");
        assert_eq!(e.description.as_deref(), Some("Top stories"),);
        assert_eq!(e.category.as_deref(), Some("News"),);
        // 1705312800 = 2024-01-15 10:00:00 UTC
        assert_eq!(
            e.start_time,
            DateTime::from_timestamp(1705312800, 0,)
                .unwrap()
                .naive_utc(),
        );
        assert_eq!(
            e.end_time,
            DateTime::from_timestamp(1705316400, 0,)
                .unwrap()
                .naive_utc(),
        );
    }

    #[test]
    fn epg_with_start_stop_keys() {
        let json = json!({
            "js": [
                {
                    "name": "Movie",
                    "start": 1705312800,
                    "stop": 1705320000,
                }
            ]
        })
        .to_string();

        let entries = parse_stalker_epg(&json, "ch_2");
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].title, "Movie");
        assert_eq!(
            entries[0].start_time,
            DateTime::from_timestamp(1705312800, 0,)
                .unwrap()
                .naive_utc(),
        );
        assert_eq!(
            entries[0].end_time,
            DateTime::from_timestamp(1705320000, 0,)
                .unwrap()
                .naive_utc(),
        );
    }

    #[test]
    fn epg_with_time_keys() {
        let json = json!({
            "js": {
                "data": [
                    {
                        "name": "Show",
                        "time": "1705312800",
                        "time_to": "1705316400",
                    }
                ]
            }
        })
        .to_string();

        let entries = parse_stalker_epg(&json, "ch_3");
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].title, "Show");
    }

    #[test]
    fn epg_int_timestamps() {
        let json = json!({
            "js": [
                {
                    "name": "Live",
                    "t_time": 1705312800,
                    "t_time_to": 1705316400,
                }
            ]
        })
        .to_string();

        let entries = parse_stalker_epg(&json, "ch_4");
        assert_eq!(entries.len(), 1);
        assert_eq!(
            entries[0].start_time,
            DateTime::from_timestamp(1705312800, 0,)
                .unwrap()
                .naive_utc(),
        );
    }

    #[test]
    fn epg_missing_end_uses_duration() {
        let json = json!({
            "js": [
                {
                    "name": "Short",
                    "t_time": "1705312800",
                    "duration": "45",
                }
            ]
        })
        .to_string();

        let entries = parse_stalker_epg(&json, "ch_5");
        assert_eq!(entries.len(), 1);
        // 1705312800 + 45*60 = 1705315500
        assert_eq!(
            entries[0].end_time,
            DateTime::from_timestamp(1705315500, 0,)
                .unwrap()
                .naive_utc(),
        );
    }

    #[test]
    fn epg_missing_end_default_30_min() {
        let json = json!({
            "js": [
                {
                    "name": "Default",
                    "t_time": "1705312800",
                }
            ]
        })
        .to_string();

        let entries = parse_stalker_epg(&json, "ch_6");
        assert_eq!(entries.len(), 1);
        // 1705312800 + 30*60 = 1705314600
        assert_eq!(
            entries[0].end_time,
            DateTime::from_timestamp(1705314600, 0,)
                .unwrap()
                .naive_utc(),
        );
    }

    #[test]
    fn epg_skips_empty_title() {
        let json = json!({
            "js": [
                {
                    "name": "",
                    "t_time": "1705312800",
                    "t_time_to": "1705316400",
                },
                {
                    "name": "Valid",
                    "t_time": "1705312800",
                    "t_time_to": "1705316400",
                }
            ]
        })
        .to_string();

        let entries = parse_stalker_epg(&json, "ch_7");
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].title, "Valid");
    }

    #[test]
    fn epg_empty_json() {
        assert!(parse_stalker_epg("", "ch").is_empty());
        assert!(parse_stalker_epg("{}", "ch").is_empty());
        assert!(parse_stalker_epg(r#"{"js": null}"#, "ch",).is_empty());
    }

    #[test]
    fn epg_description_fallback() {
        let json = json!({
            "js": [
                {
                    "name": "A",
                    "t_time": 1705312800,
                    "t_time_to": 1705316400,
                    "description": "Fallback desc",
                }
            ]
        })
        .to_string();

        let entries = parse_stalker_epg(&json, "ch_8");
        assert_eq!(entries[0].description.as_deref(), Some("Fallback desc"),);
    }

    // ── parse_stalker_vod_result ──────────────

    #[test]
    fn vod_result_basic() {
        let json = json!({
            "js": {
                "total_items": 200,
                "max_page_items": 50,
                "data": [{"id": "1"}]
            }
        })
        .to_string();

        let result = parse_stalker_vod_result(&json);
        assert_eq!(result.total_items, 200);
        assert_eq!(result.max_page_items, 50);
        assert_eq!(result.items.len(), 1);
    }

    // ── parse_stalker_vod_items ───────────────

    #[test]
    fn vod_items_basic() {
        let data = vec![json!({
            "id": "101",
            "name": "Inception",
            "cmd": "ffrt http://vod/101.mp4",
            "screenshot_uri": "http://img/inc.jpg",
            "description": "A mind-bending thriller",
            "rating_kinopoisk": "8.7",
            "rating_imdb": "8.8",
            "year": "2010",
            "time": "148",
            "category_id": "5",
        })];

        let items = parse_stalker_vod_items(&data, "http://portal.com", "movie");

        assert_eq!(items.len(), 1);
        let v = &items[0];
        assert_eq!(v.id, "stk_vod_101");
        assert_eq!(v.name, "Inception");
        assert_eq!(v.stream_url, "http://vod/101.mp4",);
        assert_eq!(v.item_type, "movie");
        assert_eq!(v.poster_url.as_deref(), Some("http://img/inc.jpg"),);
        assert_eq!(v.description.as_deref(), Some("A mind-bending thriller"),);
        // kinopoisk preferred over imdb
        assert_eq!(v.rating.as_deref(), Some("8.7"),);
        assert_eq!(v.year, Some(2010));
        assert_eq!(v.duration, Some(148));
        assert_eq!(v.category.as_deref(), Some("5"),);
    }

    #[test]
    fn vod_items_imdb_fallback() {
        let data = vec![json!({
            "id": "102",
            "name": "Avatar",
            "cmd": "http://vod/102.mp4",
            "rating_kinopoisk": "0",
            "rating_imdb": "7.9",
        })];

        let items = parse_stalker_vod_items(&data, "http://portal.com", "movie");

        assert_eq!(items[0].rating.as_deref(), Some("7.9"),);
    }

    #[test]
    fn vod_items_no_rating() {
        let data = vec![json!({
            "id": "103",
            "name": "Unrated",
            "cmd": "http://vod/103.mp4",
            "rating_kinopoisk": "0",
            "rating_imdb": "0",
        })];

        let items = parse_stalker_vod_items(&data, "http://portal.com", "movie");

        assert!(items[0].rating.is_none());
    }

    #[test]
    fn vod_items_skip_empty_id() {
        let data = vec![json!({
            "id": "",
            "name": "Bad",
            "cmd": "http://vod/x.mp4",
        })];

        let items = parse_stalker_vod_items(&data, "http://portal.com", "movie");

        assert!(items.is_empty());
    }

    #[test]
    fn vod_items_skip_empty_cmd() {
        let data = vec![json!({
            "id": "104",
            "name": "NoCmd",
            "cmd": "",
        })];

        let items = parse_stalker_vod_items(&data, "http://portal.com", "movie");

        assert!(items.is_empty());
    }

    #[test]
    fn vod_items_poster_fallback_to_logo() {
        let data = vec![json!({
            "id": "105",
            "name": "WithLogo",
            "cmd": "http://vod/105.mp4",
            "logo": "http://img/logo.png",
        })];

        let items = parse_stalker_vod_items(&data, "http://portal.com", "movie");

        assert_eq!(items[0].poster_url.as_deref(), Some("http://img/logo.png"),);
    }

    #[test]
    fn vod_items_series_type() {
        let data = vec![json!({
            "id": "200",
            "name": "Breaking Bad",
            "cmd": "http://vod/200",
        })];

        let items = parse_stalker_vod_items(&data, "http://portal.com", "series");

        assert_eq!(items[0].item_type, "series");
    }

    // ── parse_stalker_create_link ─────────────

    #[test]
    fn create_link_ffrt() {
        let json = json!({
            "js": {
                "cmd": "ffrt http://cdn/stream.m3u8?token=abc",
            }
        })
        .to_string();

        let url = parse_stalker_create_link(&json, "http://portal.com");
        assert_eq!(url.as_deref(), Some("http://cdn/stream.m3u8?token=abc"),);
    }

    #[test]
    fn create_link_absolute() {
        let json = json!({
            "js": {
                "cmd": "http://cdn/stream.ts",
            }
        })
        .to_string();

        let url = parse_stalker_create_link(&json, "http://portal.com");
        assert_eq!(url.as_deref(), Some("http://cdn/stream.ts"),);
    }

    #[test]
    fn create_link_relative() {
        let json = json!({
            "js": {
                "cmd": "/live/stream.ts",
            }
        })
        .to_string();

        let url = parse_stalker_create_link(&json, "http://portal.com");
        assert_eq!(url.as_deref(), Some("http://portal.com/live/stream.ts"),);
    }

    #[test]
    fn create_link_null() {
        let json = json!({"js": {"cmd": null}}).to_string();
        let url = parse_stalker_create_link(&json, "http://portal.com");
        assert!(url.is_none());
    }

    #[test]
    fn create_link_empty_cmd() {
        let json = json!({"js": {"cmd": ""}}).to_string();
        let url = parse_stalker_create_link(&json, "http://portal.com");
        assert!(url.is_none());
    }

    #[test]
    fn create_link_invalid_json() {
        let url = parse_stalker_create_link("not json", "http://portal.com");
        assert!(url.is_none());
    }

    // ── extract_js ────────────────────────────

    #[test]
    fn extract_js_from_wrapped() {
        let v = json!({"js": [1, 2, 3]});
        let js = extract_js(&v).unwrap();
        assert!(js.is_array());
    }

    #[test]
    fn extract_js_from_non_object() {
        let v = json!([1, 2, 3]);
        let js = extract_js(&v).unwrap();
        assert!(js.is_array());
    }

    #[test]
    fn extract_js_null() {
        let v = Value::Null;
        assert!(extract_js(&v).is_none());
    }

    #[test]
    fn extract_js_object_without_js_key() {
        let v = json!({"data": "foo"});
        // Returns the object itself.
        let js = extract_js(&v).unwrap();
        assert!(js.is_object());
    }
}
