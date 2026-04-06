//! Stalker Portal (MAG middleware) response parsers.
//!
//! Ported from Dart `stalker_portal_client.dart`. Pure
//! functions, no DB or network access.

use chrono::DateTime;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::models::{Channel, EpgEntry, VodItem, new_entity_id};
use crate::value_objects::MediaType;

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

            // EPG ID: xmltv_id > epg_id > id
            let tvg_id = map
                .get("xmltv_id")
                .and_then(non_empty_str)
                .or_else(|| map.get("epg_id").and_then(non_empty_str))
                .map(String::from)
                .or_else(|| Some(id.clone()));

            let number = map.get("number").and_then(value_as_i32);

            let tv_archive = map.get("tv_archive").and_then(value_as_i64).unwrap_or(0);
            let tv_archive_dur = map
                .get("tv_archive_duration")
                .and_then(value_as_i32)
                .unwrap_or(0);

            let has_catchup = tv_archive == 1 && tv_archive_dur > 0;

            let stream_url = build_stalker_stream_url(cmd, base_url);

            // censored field: "1" or 1 means adult content
            let is_adult = map.get("censored").and_then(value_as_i64).unwrap_or(0) == 1;

            // added timestamp (Unix seconds)
            let added_at = map
                .get("added")
                .and_then(value_as_i64)
                .and_then(|ts| DateTime::from_timestamp(ts, 0))
                .map(|dt| dt.naive_utc());

            Some(Channel {
                id: new_entity_id(),
                native_id: id,
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
                added_at,
                updated_at: None,
                is_247: false,
                tvg_shift: None,
                tvg_language: None,
                tvg_country: None,
                parent_code: None,
                is_radio: false,
                tvg_rec: None,
                is_adult,
                custom_sid: None,
                direct_source: None,
                ..Default::default()
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
        epg_channel_id: channel_id.to_string(),
        title: title.to_string(),
        start_time,
        end_time,
        description,
        category,
        ..EpgEntry::default()
    })
}

// ── VOD items parser ──────────────────────────────

/// Converts Stalker VOD list into [`VodItem`] structs.
///
/// Skips items with empty `id` or `cmd`. Maps all
/// available Stalker fields including `o_name`,
/// `director`, `actors`, `tmdb_id`, `rating_mpaa`,
/// `censored`, timestamps, and genre IDs.
///
/// Rating priority: `rating_kinopoisk` > `rating_imdb`.
/// Duration: `length` (preferred, in minutes) > `time`.
pub fn parse_stalker_vod_items(
    data: &[Value],
    base_url: &str,
    vod_type: &str,
    source_id: &str,
) -> Vec<VodItem> {
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

            // Original/foreign title
            let original_name = map.get("o_name").and_then(non_empty_str).map(String::from);

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

            // Rating: kinopoisk > imdb (display string)
            let rating = rating_priority(map);

            // Numeric rating for 5-based scale (IMDb is 0-10)
            let rating_5based = map
                .get("rating_imdb")
                .and_then(|v| v.as_str())
                .and_then(|s| s.parse::<f64>().ok())
                .filter(|&r| r > 0.0)
                .map(|r| r / 2.0);

            let year = map.get("year").and_then(value_as_i32);

            // Duration: length (minutes) > time
            let duration = map
                .get("length")
                .and_then(non_empty_str)
                .and_then(parse_duration_str)
                .or_else(|| map.get("time").and_then(value_as_i32));

            let category = map.get("category_id").map(|v| {
                v.as_str()
                    .map(String::from)
                    .unwrap_or_else(|| v.to_string())
            });

            // Genre: build from genre_id_1..genre_id_4
            let genre = collect_genre_ids(map);

            // Director
            let director = map
                .get("director")
                .and_then(non_empty_str)
                .map(String::from);

            // Cast / actors
            let cast = map.get("actors").and_then(non_empty_str).map(String::from);

            // Content / parental rating (MPAA)
            let content_rating = map
                .get("rating_mpaa")
                .and_then(non_empty_str)
                .map(String::from);

            // TMDB ID
            let tmdb_id = map.get("tmdb_id").and_then(value_as_i64).filter(|&v| v > 0);

            // Adult content flag
            let is_adult = map.get("censored").and_then(value_as_i64).unwrap_or(0) == 1;

            // Timestamps
            let added_at = map
                .get("added")
                .and_then(value_as_i64)
                .and_then(|ts| DateTime::from_timestamp(ts, 0))
                .map(|dt| dt.naive_utc());

            let updated_at = map
                .get("last_modified")
                .and_then(value_as_i64)
                .and_then(|ts| DateTime::from_timestamp(ts, 0))
                .map(|dt| dt.naive_utc());

            let stalker_native_id = map
                .get("id")
                .and_then(|v| v.as_str().map(String::from).or_else(|| Some(v.to_string())))
                .unwrap_or_default();
            Some(VodItem {
                id: new_entity_id(),
                native_id: stalker_native_id,
                name: name.to_string(),
                stream_url,
                item_type: vod_type.try_into().unwrap_or_default(),
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
                added_at,
                updated_at,
                source_id: Some(source_id.to_string()),
                cast,
                director,
                genre,
                youtube_trailer: None,
                tmdb_id,
                rating_5based,
                original_name,
                is_adult,
                content_rating,
            })
        })
        .collect()
}

/// Collects genre IDs from `genre_id_1` through
/// `genre_id_4` into a comma-separated string.
fn collect_genre_ids(map: &serde_json::Map<String, Value>) -> Option<String> {
    let ids: Vec<String> = (1..=4)
        .filter_map(|i| {
            let key = format!("genre_id_{}", i);
            map.get(&key)
                .and_then(non_empty_str)
                .filter(|s| *s != "0")
                .map(String::from)
        })
        .collect();
    if ids.is_empty() {
        None
    } else {
        Some(ids.join(", "))
    }
}

/// Parses a duration string which may be "HH:MM:SS",
/// "MM:SS", or plain minutes.
fn parse_duration_str(s: &str) -> Option<i32> {
    if let Ok(mins) = s.parse::<i32>() {
        return Some(mins);
    }
    let parts: Vec<&str> = s.split(':').collect();
    match parts.len() {
        2 => {
            let m = parts[0].parse::<i32>().ok()?;
            let s = parts[1].parse::<i32>().ok()?;
            Some(m + if s > 0 { 1 } else { 0 })
        }
        3 => {
            let h = parts[0].parse::<i32>().ok()?;
            let m = parts[1].parse::<i32>().ok()?;
            let s = parts[2].parse::<i32>().ok()?;
            Some(h * 60 + m + if s > 0 { 1 } else { 0 })
        }
        _ => None,
    }
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

// ── Profile parser ───────────────────────────────

/// User profile information from Stalker portal.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct StalkerProfile {
    /// User timezone setting.
    pub timezone: Option<String>,
    /// User locale/language.
    pub locale: Option<String>,
    /// City name.
    pub city: Option<String>,
    /// Country code.
    pub country: Option<String>,
}

/// Parses a `get_profile` response.
///
/// Input JSON:
/// ```json
/// {"js": {"timezone": "UTC", "locale": "en_US", ...}}
/// ```
pub fn parse_stalker_profile(json: &str) -> StalkerProfile {
    let value: Value = match serde_json::from_str(json) {
        Ok(v) => v,
        Err(_) => return StalkerProfile::default(),
    };

    let js = match extract_js(&value) {
        Some(v) => v,
        None => return StalkerProfile::default(),
    };

    let map = match js.as_object() {
        Some(m) => m,
        None => return StalkerProfile::default(),
    };

    StalkerProfile {
        timezone: map
            .get("timezone")
            .and_then(non_empty_str)
            .map(String::from),
        locale: map.get("locale").and_then(non_empty_str).map(String::from),
        city: map.get("city").and_then(non_empty_str).map(String::from),
        country: map.get("country").and_then(non_empty_str).map(String::from),
    }
}

// ── Account info parser ──────────────────────────

/// Subscription/account information from Stalker portal.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct StalkerAccountInfo {
    /// Phone number on file.
    pub phone: Option<String>,
    /// Login/username.
    pub login: Option<String>,
    /// MAC address.
    pub mac: Option<String>,
    /// Account status (0 = active).
    pub status: i32,
    /// Subscription expiration date string.
    pub exp_date: Option<String>,
    /// Tariff/plan name.
    pub tariff_name: Option<String>,
}

/// Parses an `account_info/get_main_info` response.
///
/// Input JSON:
/// ```json
/// {"js": {"phone": "...", "login": "user",
///         "mac": "00:1A:...", "status": 0,
///         "exp_date": "2025-12-31", "tariff_name": "Premium"}}
/// ```
pub fn parse_stalker_account_info(json: &str) -> StalkerAccountInfo {
    let value: Value = match serde_json::from_str(json) {
        Ok(v) => v,
        Err(_) => return StalkerAccountInfo::default(),
    };

    let js = match extract_js(&value) {
        Some(v) => v,
        None => return StalkerAccountInfo::default(),
    };

    let map = match js.as_object() {
        Some(m) => m,
        None => return StalkerAccountInfo::default(),
    };

    StalkerAccountInfo {
        phone: map.get("phone").and_then(non_empty_str).map(String::from),
        login: map.get("login").and_then(non_empty_str).map(String::from),
        mac: map.get("mac").and_then(non_empty_str).map(String::from),
        status: map.get("status").and_then(value_as_i32).unwrap_or(-1),
        exp_date: map
            .get("exp_date")
            .and_then(non_empty_str)
            .map(String::from),
        tariff_name: map
            .get("tariff_name")
            .or_else(|| map.get("tariff"))
            .and_then(non_empty_str)
            .map(String::from),
    }
}

// ── VOD detail parser ────────────────────────────

/// Parses a `get_vod_info` response into a single [`VodItem`].
///
/// Input JSON:
/// ```json
/// {"js": {"movie": {"id": "101", "name": "...", "cmd": "...", ...}}}
/// ```
///
/// Falls back to parsing `js` directly if the `movie` key is absent.
pub fn parse_stalker_vod_detail(json: &str, base_url: &str, source_id: &str) -> Option<VodItem> {
    let value: Value = serde_json::from_str(json).ok()?;
    let js = extract_js(&value)?;

    // Stalker wraps vod_info in a "movie" key for single items.
    let item = if let Some(movie) = js.get("movie") {
        movie.clone()
    } else {
        js.clone()
    };

    let items = parse_stalker_vod_items(&[item], base_url, "movie", source_id);
    items.into_iter().next()
}

// ── Series info parser ───────────────────────────

/// Parses a `get_series_info` response into a flat
/// list of episode [`VodItem`]s.
///
/// Input JSON:
/// ```json
/// {"js": {"seasons": [
///   {"season_number": 1, "episodes": [
///     {"id": "301", "name": "Pilot", "cmd": "...", ...}
///   ]}
/// ]}}
/// ```
///
/// Handles the common Stalker series formats:
/// - `{"js": {"seasons": [...]}}` — structured seasons
/// - `{"js": {"data": [...]}}` — flat episode list
pub fn parse_stalker_series_detail(
    json: &str,
    base_url: &str,
    series_id: &str,
    source_id: &str,
) -> Vec<VodItem> {
    let value: Value = match serde_json::from_str(json) {
        Ok(v) => v,
        Err(_) => return Vec::new(),
    };

    let js = match extract_js(&value) {
        Some(v) => v,
        None => return Vec::new(),
    };

    let mut episodes: Vec<VodItem> = Vec::new();

    // Format 1: structured seasons array.
    if let Some(seasons) = js.get("seasons").and_then(Value::as_array) {
        for season in seasons {
            let season_num = season
                .get("season_number")
                .or_else(|| season.get("id"))
                .and_then(value_as_i32);

            let eps = season
                .get("episodes")
                .or_else(|| season.get("series"))
                .and_then(Value::as_array);

            if let Some(ep_list) = eps {
                for (idx, ep) in ep_list.iter().enumerate() {
                    if let Some(mut item) = parse_single_episode(ep, base_url, source_id) {
                        item.series_id = Some(series_id.to_string());
                        item.season_number = season_num;
                        if item.episode_number.is_none() {
                            item.episode_number = Some((idx + 1) as i32);
                        }
                        episodes.push(item);
                    }
                }
            }
        }
        return episodes;
    }

    // Format 2: flat episode list in data array.
    if let Some(data) = js.get("data").and_then(Value::as_array) {
        let items = parse_stalker_vod_items(data, base_url, "episode", source_id);
        for mut item in items {
            item.series_id = Some(series_id.to_string());
            episodes.push(item);
        }
        return episodes;
    }

    episodes
}

/// Parses a single episode JSON object into a [`VodItem`].
fn parse_single_episode(ep: &Value, base_url: &str, source_id: &str) -> Option<VodItem> {
    let map = ep.as_object()?;

    let id = map
        .get("id")
        .map(|v| {
            v.as_str()
                .map(String::from)
                .unwrap_or_else(|| v.to_string())
        })
        .unwrap_or_default();

    let cmd = map.get("cmd").and_then(|v| v.as_str()).unwrap_or("");
    if id.is_empty() && cmd.is_empty() {
        return None;
    }

    let name = map
        .get("name")
        .or_else(|| map.get("title"))
        .and_then(|v| v.as_str())
        .unwrap_or("Unknown");

    let stream_url = if cmd.is_empty() {
        String::new()
    } else {
        build_stalker_stream_url(cmd, base_url)
    };

    let episode_number = map
        .get("episode_number")
        .or_else(|| map.get("series"))
        .and_then(value_as_i32);

    let description = map
        .get("description")
        .and_then(non_empty_str)
        .map(String::from);

    let poster_url = map
        .get("screenshot_uri")
        .and_then(non_empty_str)
        .or_else(|| map.get("logo").and_then(non_empty_str))
        .map(String::from);

    let duration = map
        .get("length")
        .and_then(non_empty_str)
        .and_then(parse_duration_str)
        .or_else(|| map.get("time").and_then(value_as_i32));

    Some(VodItem {
        id: new_entity_id(),
        name: name.to_string(),
        stream_url,
        item_type: MediaType::Episode,
        poster_url,
        description,
        duration,
        episode_number,
        source_id: Some(source_id.to_string()),
        ..VodItem::default()
    })
}

// ── Favorites parser ─────────────────────────────

/// Parses a `get_fav` response to extract favorite channel/item IDs.
///
/// Stalker portals return favorites in various formats:
/// - `{"js": {"data": [{"id": "1"}, ...]}}` — object list
/// - `{"js": "1,2,3"}` — comma-separated string
/// - `{"js": ["1", "2"]}` — string array
pub fn parse_stalker_favorites(json: &str) -> Vec<String> {
    let value: Value = match serde_json::from_str(json) {
        Ok(v) => v,
        Err(_) => return Vec::new(),
    };

    let js = match extract_js(&value) {
        Some(v) => v,
        None => return Vec::new(),
    };

    // Format 1: comma-separated string.
    if let Some(s) = js.as_str() {
        return s
            .split(',')
            .map(|id| id.trim().to_string())
            .filter(|id| !id.is_empty())
            .collect();
    }

    // Format 2: direct array of strings/numbers.
    if let Some(arr) = js.as_array() {
        return arr
            .iter()
            .filter_map(|v| v.as_str().map(String::from).or_else(|| Some(v.to_string())))
            .filter(|s| !s.is_empty() && s != "null")
            .collect();
    }

    // Format 3: paginated data with objects.
    if let Some(map) = js.as_object()
        && let Some(data) = map.get("data").and_then(Value::as_array)
    {
        return data
            .iter()
            .filter_map(|item| {
                item.get("id").map(|v| {
                    v.as_str()
                        .map(String::from)
                        .unwrap_or_else(|| v.to_string())
                })
            })
            .filter(|s| !s.is_empty())
            .collect();
    }

    Vec::new()
}

// ── Adapter: crispy_stalker crate types ──────────

/// Convert a vec of [`StalkerChannel`] (from `crispy_stalker`) into
/// [`Channel`] models using `From<StalkerChannel>`.
///
/// The `base_url` is used to resolve `cmd` values into stream URLs.
pub fn channels_from_stalker(
    channels: Vec<crispy_stalker::types::StalkerChannel>,
    source_id: &str,
    base_url: &str,
) -> Vec<Channel> {
    channels
        .into_iter()
        .map(|sc| {
            // Resolve the cmd to a stream URL before converting.
            let stream_url = build_stalker_stream_url(&sc.cmd, base_url);
            let mut ch: Channel = sc.into();
            ch.stream_url = stream_url;
            ch.source_id = Some(source_id.to_string());
            ch
        })
        .collect()
}

/// Convert a vec of [`StalkerVodItem`] (from `crispy_stalker`) into
/// [`Movie`] models.
pub fn movies_from_stalker(
    items: Vec<crispy_stalker::types::StalkerVodItem>,
    source_id: &str,
    base_url: &str,
) -> Vec<crate::models::Movie> {
    items
        .into_iter()
        .map(|vi| {
            let resolved = build_stalker_stream_url(&vi.cmd, base_url);
            let mut movie: crate::models::Movie = vi.into();
            movie.source_id = source_id.to_string();
            movie.resolved_url = Some(resolved);
            movie
        })
        .collect()
}

/// Convert a vec of [`StalkerSeriesItem`] (from `crispy_stalker`) into
/// [`Series`] models.
pub fn series_from_stalker(
    items: Vec<crispy_stalker::types::StalkerSeriesItem>,
    source_id: &str,
) -> Vec<crate::models::Series> {
    items
        .into_iter()
        .map(|si| {
            let mut series: crate::models::Series = si.into();
            series.source_id = source_id.to_string();
            series
        })
        .collect()
}

// ── Bridge adapters: raw JSON → crate types → domain models ──

/// Parse raw portal JSON items into [`StalkerChannel`] crate types.
///
/// Mirrors the field extraction from `crispy_stalker::client::parse_channel`,
/// which maps portal-native field names (e.g. `tv_archive`, `censored`) to
/// the crate type's semantic names (e.g. `has_archive`, `is_censored`).
fn parse_value_to_stalker_channel(v: &Value) -> crispy_stalker::types::StalkerChannel {
    crispy_stalker::types::StalkerChannel {
        id: v
            .get("id")
            .map(|id| {
                id.as_str()
                    .map(String::from)
                    .unwrap_or_else(|| id.to_string())
            })
            .unwrap_or_default(),
        name: non_empty_str(v.get("name").unwrap_or(&Value::Null))
            .unwrap_or("Unknown")
            .to_string(),
        number: v.get("number").and_then(value_as_i32).map(|n| n as u32),
        cmd: non_empty_str(v.get("cmd").unwrap_or(&Value::Null))
            .unwrap_or("")
            .to_string(),
        tv_genre_id: v.get("tv_genre_id").map(|g| {
            g.as_str()
                .map(String::from)
                .unwrap_or_else(|| g.to_string())
        }),
        logo: v
            .get("logo")
            .and_then(|l| l.as_str())
            .filter(|s| !s.is_empty())
            .map(String::from),
        epg_channel_id: v
            .get("xmltv_id")
            .and_then(|x| x.as_str())
            .filter(|s| !s.is_empty())
            .or_else(|| {
                v.get("epg_id")
                    .and_then(|x| x.as_str())
                    .filter(|s| !s.is_empty())
            })
            .map(String::from),
        has_archive: value_as_i64(v.get("tv_archive").unwrap_or(&Value::Null)).unwrap_or(0) == 1,
        archive_days: v
            .get("tv_archive_duration")
            .and_then(value_as_i32)
            .unwrap_or(0) as u32,
        is_censored: value_as_i64(v.get("censored").unwrap_or(&Value::Null)).unwrap_or(0) == 1,
    }
}

/// Parse raw portal JSON items into [`StalkerVodItem`] crate types.
///
/// Mirrors the field extraction from `crispy_stalker::client::parse_vod_item`.
fn parse_value_to_stalker_vod(v: &Value) -> crispy_stalker::types::StalkerVodItem {
    crispy_stalker::types::StalkerVodItem {
        id: v
            .get("id")
            .map(|id| {
                id.as_str()
                    .map(String::from)
                    .unwrap_or_else(|| id.to_string())
            })
            .unwrap_or_default(),
        name: non_empty_str(v.get("name").unwrap_or(&Value::Null))
            .unwrap_or("Unknown")
            .to_string(),
        cmd: non_empty_str(v.get("cmd").unwrap_or(&Value::Null))
            .unwrap_or("")
            .to_string(),
        category_id: v.get("category_id").and_then(|c| {
            c.as_str()
                .filter(|s| !s.is_empty())
                .map(String::from)
                .or_else(|| Some(c.to_string()))
        }),
        logo: v
            .get("screenshot_uri")
            .and_then(|l| l.as_str())
            .filter(|s| !s.is_empty())
            .or_else(|| {
                v.get("logo")
                    .and_then(|l| l.as_str())
                    .filter(|s| !s.is_empty())
            })
            .map(String::from),
        description: v
            .get("description")
            .and_then(|d| d.as_str())
            .filter(|s| !s.is_empty())
            .map(String::from),
        year: v
            .get("year")
            .and_then(|y| y.as_str())
            .filter(|s| !s.is_empty())
            .map(String::from),
        genre: v
            .get("genre_str")
            .or_else(|| v.get("genres_str"))
            .and_then(|g| g.as_str())
            .filter(|s| !s.is_empty())
            .map(String::from),
        rating: v
            .get("rating_imdb")
            .or_else(|| v.get("rating_kinopoisk"))
            .and_then(|r| r.as_str())
            .filter(|s| !s.is_empty() && s != &"0")
            .map(String::from),
        director: v
            .get("director")
            .and_then(|d| d.as_str())
            .filter(|s| !s.is_empty())
            .map(String::from),
        cast: v
            .get("actors")
            .and_then(|a| a.as_str())
            .filter(|s| !s.is_empty())
            .map(String::from),
        duration: v
            .get("time")
            .or_else(|| v.get("length"))
            .and_then(|t| t.as_str())
            .filter(|s| !s.is_empty())
            .map(String::from),
        tmdb_id: v.get("tmdb_id").and_then(value_as_i64),
    }
}

/// Parse raw portal JSON items into [`StalkerSeriesItem`] crate types.
fn parse_value_to_stalker_series(v: &Value) -> crispy_stalker::types::StalkerSeriesItem {
    crispy_stalker::types::StalkerSeriesItem {
        id: v
            .get("id")
            .map(|id| {
                id.as_str()
                    .map(String::from)
                    .unwrap_or_else(|| id.to_string())
            })
            .unwrap_or_default(),
        name: non_empty_str(v.get("name").unwrap_or(&Value::Null))
            .unwrap_or("Unknown")
            .to_string(),
        category_id: v.get("category_id").and_then(|c| {
            c.as_str()
                .filter(|s| !s.is_empty())
                .map(String::from)
                .or_else(|| Some(c.to_string()))
        }),
        logo: v
            .get("screenshot_uri")
            .and_then(|l| l.as_str())
            .filter(|s| !s.is_empty())
            .or_else(|| {
                v.get("logo")
                    .and_then(|l| l.as_str())
                    .filter(|s| !s.is_empty())
            })
            .map(String::from),
        description: v
            .get("description")
            .and_then(|d| d.as_str())
            .filter(|s| !s.is_empty())
            .map(String::from),
        year: v
            .get("year")
            .and_then(|y| y.as_str())
            .filter(|s| !s.is_empty())
            .map(String::from),
        genre: v
            .get("genre_str")
            .or_else(|| v.get("genres_str"))
            .and_then(|g| g.as_str())
            .filter(|s| !s.is_empty())
            .map(String::from),
        rating: v
            .get("rating_imdb")
            .or_else(|| v.get("rating_kinopoisk"))
            .and_then(|r| r.as_str())
            .filter(|s| !s.is_empty() && s != &"0")
            .map(String::from),
        director: v
            .get("director")
            .and_then(|d| d.as_str())
            .filter(|s| !s.is_empty())
            .map(String::from),
        cast: v
            .get("actors")
            .and_then(|a| a.as_str())
            .filter(|s| !s.is_empty())
            .map(String::from),
    }
}

/// Parse raw Stalker portal channel JSON via crate types into [`Channel`] models.
///
/// Bridges the raw portal JSON items through [`StalkerChannel`] crate types,
/// then delegates to [`channels_from_stalker`] for the final domain conversion.
pub fn channels_from_stalker_json(data: &[Value], source_id: &str, base_url: &str) -> Vec<Channel> {
    let typed: Vec<crispy_stalker::types::StalkerChannel> =
        data.iter().map(parse_value_to_stalker_channel).collect();
    channels_from_stalker(typed, source_id, base_url)
}

/// Parse raw Stalker portal VOD JSON via crate types into [`VodItem`] models.
///
/// Bridges raw portal JSON through [`StalkerVodItem`] crate types into
/// [`Movie`] models, then converts to [`VodItem`] for DB compatibility.
pub fn vod_from_stalker_json(
    data: &[Value],
    source_id: &str,
    base_url: &str,
) -> Vec<crate::models::VodItem> {
    let typed: Vec<crispy_stalker::types::StalkerVodItem> =
        data.iter().map(parse_value_to_stalker_vod).collect();
    movies_from_stalker(typed, source_id, base_url)
        .into_iter()
        .map(crate::models::VodItem::from)
        .collect()
}

/// Parse raw Stalker portal series JSON via crate types into [`VodItem`] models.
///
/// Bridges raw portal JSON through [`StalkerSeriesItem`] crate types into
/// [`Series`] models, then converts to [`VodItem`] for DB compatibility.
pub fn series_from_stalker_json(data: &[Value], source_id: &str) -> Vec<crate::models::VodItem> {
    let typed: Vec<crispy_stalker::types::StalkerSeriesItem> =
        data.iter().map(parse_value_to_stalker_series).collect();
    series_from_stalker(typed, source_id)
        .into_iter()
        .map(crate::models::VodItem::from)
        .collect()
}

// ── Tests ─────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::value_objects::MediaType;
    use serde_json::json;

    fn assert_uuid_v7(id: &str) {
        let parsed = uuid::Uuid::parse_str(id).expect("valid UUID");
        assert_eq!(parsed.get_version_num(), 7);
    }

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
        assert_uuid_v7(&ch.id);
        assert_eq!(ch.native_id, "42");
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
        assert_eq!(e.epg_channel_id, "ch_1");
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

        let items = parse_stalker_vod_items(&data, "http://portal.com", "movie", "src_test");

        assert_eq!(items.len(), 1);
        let v = &items[0];
        assert_uuid_v7(&v.id);
        assert_eq!(v.name, "Inception");
        assert_eq!(v.stream_url, "http://vod/101.mp4",);
        assert_eq!(v.item_type, MediaType::Movie);
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

        let items = parse_stalker_vod_items(&data, "http://portal.com", "movie", "src_test");

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

        let items = parse_stalker_vod_items(&data, "http://portal.com", "movie", "src_test");

        assert!(items[0].rating.is_none());
    }

    #[test]
    fn vod_items_skip_empty_id() {
        let data = vec![json!({
            "id": "",
            "name": "Bad",
            "cmd": "http://vod/x.mp4",
        })];

        let items = parse_stalker_vod_items(&data, "http://portal.com", "movie", "src_test");

        assert!(items.is_empty());
    }

    #[test]
    fn vod_items_skip_empty_cmd() {
        let data = vec![json!({
            "id": "104",
            "name": "NoCmd",
            "cmd": "",
        })];

        let items = parse_stalker_vod_items(&data, "http://portal.com", "movie", "src_test");

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

        let items = parse_stalker_vod_items(&data, "http://portal.com", "movie", "src_test");

        assert_eq!(items[0].poster_url.as_deref(), Some("http://img/logo.png"),);
    }

    #[test]
    fn vod_items_series_type() {
        let data = vec![json!({
            "id": "200",
            "name": "Breaking Bad",
            "cmd": "http://vod/200",
        })];

        let items = parse_stalker_vod_items(&data, "http://portal.com", "series", "src_test");

        assert_eq!(items[0].item_type, MediaType::Series);
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

    // ── live streams: new field mappings ─────

    #[test]
    fn live_streams_censored_maps_to_is_adult() {
        let data = vec![json!({
            "id": "50",
            "name": "Adult Ch",
            "cmd": "http://tv/50",
            "censored": 1,
        })];

        let channels = parse_stalker_live_streams(&data, "s1", "http://portal.com");

        assert!(channels[0].is_adult);
    }

    #[test]
    fn live_streams_censored_zero_is_not_adult() {
        let data = vec![json!({
            "id": "51",
            "name": "Normal Ch",
            "cmd": "http://tv/51",
            "censored": 0,
        })];

        let channels = parse_stalker_live_streams(&data, "s1", "http://portal.com");

        assert!(!channels[0].is_adult);
    }

    #[test]
    fn live_streams_censored_string_one_is_adult() {
        let data = vec![json!({
            "id": "52",
            "name": "Adult Ch Str",
            "cmd": "http://tv/52",
            "censored": "1",
        })];

        let channels = parse_stalker_live_streams(&data, "s1", "http://portal.com");

        assert!(channels[0].is_adult);
    }

    #[test]
    fn live_streams_added_timestamp_maps_to_added_at() {
        let data = vec![json!({
            "id": "53",
            "name": "NewCh",
            "cmd": "http://tv/53",
            "added": "1705312800",
        })];

        let channels = parse_stalker_live_streams(&data, "s1", "http://portal.com");

        assert!(channels[0].added_at.is_some());
        assert_eq!(
            channels[0].added_at.unwrap(),
            DateTime::from_timestamp(1705312800, 0).unwrap().naive_utc(),
        );
    }

    #[test]
    fn live_streams_epg_id_fallback() {
        let data = vec![json!({
            "id": "54",
            "name": "EpgCh",
            "cmd": "http://tv/54",
            "xmltv_id": "",
            "epg_id": "epg_channel_54",
        })];

        let channels = parse_stalker_live_streams(&data, "s1", "http://portal.com");

        assert_eq!(channels[0].tvg_id.as_deref(), Some("epg_channel_54"));
    }

    // ── VOD: new field mappings ─────────────

    #[test]
    fn vod_items_maps_all_stalker_fields() {
        let data = vec![json!({
            "id": "201",
            "name": "The Matrix",
            "o_name": "Matrix",
            "cmd": "ffrt http://vod/201.mp4",
            "screenshot_uri": "http://img/matrix.jpg",
            "description": "A computer hacker learns about the true nature of reality",
            "director": "The Wachowskis",
            "actors": "Keanu Reeves, Laurence Fishburne",
            "rating_kinopoisk": "8.5",
            "rating_imdb": "8.7",
            "rating_mpaa": "R",
            "year": "1999",
            "length": "136",
            "time": "999",
            "genre_id_1": "3",
            "genre_id_2": "7",
            "genre_id_3": "0",
            "genre_id_4": "",
            "tmdb_id": "603",
            "censored": 0,
            "added": "1705312800",
            "last_modified": "1705400000",
            "category_id": "5",
        })];

        let items = parse_stalker_vod_items(&data, "http://portal.com", "movie", "src_stalker");

        assert_eq!(items.len(), 1);
        let v = &items[0];

        // Basic fields
        assert_uuid_v7(&v.id);
        assert_eq!(v.name, "The Matrix");
        assert_eq!(v.stream_url, "http://vod/201.mp4");
        assert_eq!(v.item_type, MediaType::Movie);

        // Original name
        assert_eq!(v.original_name.as_deref(), Some("Matrix"));

        // Poster
        assert_eq!(v.poster_url.as_deref(), Some("http://img/matrix.jpg"));

        // Description
        assert_eq!(
            v.description.as_deref(),
            Some("A computer hacker learns about the true nature of reality"),
        );

        // Director
        assert_eq!(v.director.as_deref(), Some("The Wachowskis"));

        // Cast (from actors)
        assert_eq!(v.cast.as_deref(), Some("Keanu Reeves, Laurence Fishburne"),);

        // Rating: kinopoisk preferred
        assert_eq!(v.rating.as_deref(), Some("8.5"));

        // Rating 5-based (IMDb 8.7 / 2 = 4.35)
        assert!((v.rating_5based.unwrap() - 4.35).abs() < 0.01);

        // Content rating (MPAA)
        assert_eq!(v.content_rating.as_deref(), Some("R"));

        // Year
        assert_eq!(v.year, Some(1999));

        // Duration: length preferred over time
        assert_eq!(v.duration, Some(136));

        // Category
        assert_eq!(v.category.as_deref(), Some("5"));

        // Genre (from genre_id_1..4, zero/empty excluded)
        assert_eq!(v.genre.as_deref(), Some("3, 7"));

        // TMDB ID
        assert_eq!(v.tmdb_id, Some(603));

        // Not adult
        assert!(!v.is_adult);

        // Source ID
        assert_eq!(v.source_id.as_deref(), Some("src_stalker"));

        // Timestamps
        assert!(v.added_at.is_some());
        assert_eq!(
            v.added_at.unwrap(),
            DateTime::from_timestamp(1705312800, 0).unwrap().naive_utc(),
        );
        assert!(v.updated_at.is_some());
        assert_eq!(
            v.updated_at.unwrap(),
            DateTime::from_timestamp(1705400000, 0).unwrap().naive_utc(),
        );
    }

    #[test]
    fn vod_items_censored_maps_to_is_adult() {
        let data = vec![json!({
            "id": "202",
            "name": "Adult Movie",
            "cmd": "http://vod/202.mp4",
            "censored": 1,
        })];

        let items = parse_stalker_vod_items(&data, "http://portal.com", "movie", "src_test");

        assert!(items[0].is_adult);
    }

    #[test]
    fn vod_items_duration_hh_mm_ss_format() {
        let data = vec![json!({
            "id": "203",
            "name": "Long Movie",
            "cmd": "http://vod/203.mp4",
            "length": "02:15:30",
        })];

        let items = parse_stalker_vod_items(&data, "http://portal.com", "movie", "src_test");

        // 2*60 + 15 + 1 (rounding for 30s) = 136
        assert_eq!(items[0].duration, Some(136));
    }

    #[test]
    fn vod_items_duration_mm_ss_format() {
        let data = vec![json!({
            "id": "204",
            "name": "Short Film",
            "cmd": "http://vod/204.mp4",
            "length": "45:00",
        })];

        let items = parse_stalker_vod_items(&data, "http://portal.com", "movie", "src_test");

        assert_eq!(items[0].duration, Some(45));
    }

    #[test]
    fn vod_items_falls_back_to_time_when_no_length() {
        let data = vec![json!({
            "id": "205",
            "name": "Fallback Duration",
            "cmd": "http://vod/205.mp4",
            "time": "90",
        })];

        let items = parse_stalker_vod_items(&data, "http://portal.com", "movie", "src_test");

        assert_eq!(items[0].duration, Some(90));
    }

    // ── Helper function tests ───────────────

    #[test]
    fn parse_duration_str_plain_minutes() {
        assert_eq!(parse_duration_str("120"), Some(120));
    }

    #[test]
    fn parse_duration_str_hh_mm_ss() {
        assert_eq!(parse_duration_str("01:30:00"), Some(90));
    }

    #[test]
    fn parse_duration_str_hh_mm_ss_with_seconds() {
        assert_eq!(parse_duration_str("01:30:45"), Some(91));
    }

    #[test]
    fn parse_duration_str_mm_ss() {
        assert_eq!(parse_duration_str("45:30"), Some(46));
    }

    #[test]
    fn parse_duration_str_invalid() {
        assert_eq!(parse_duration_str("abc"), None);
        assert_eq!(parse_duration_str("1:2:3:4"), None);
    }

    #[test]
    fn collect_genre_ids_all_present() {
        let obj: serde_json::Map<String, Value> = serde_json::from_str(
            r#"{"genre_id_1":"5","genre_id_2":"12","genre_id_3":"0","genre_id_4":"8"}"#,
        )
        .unwrap();
        let result = collect_genre_ids(&obj);
        assert_eq!(result.as_deref(), Some("5, 12, 8"));
    }

    #[test]
    fn collect_genre_ids_all_zero_or_empty() {
        let obj: serde_json::Map<String, Value> =
            serde_json::from_str(r#"{"genre_id_1":"0","genre_id_2":"","genre_id_3":"0"}"#).unwrap();
        assert!(collect_genre_ids(&obj).is_none());
    }

    // ── parse_stalker_profile ─────────────────

    #[test]
    fn profile_basic() {
        let json = json!({
            "js": {
                "timezone": "Europe/London",
                "locale": "en_GB",
                "city": "London",
                "country": "GB",
            }
        })
        .to_string();

        let profile = parse_stalker_profile(&json);
        assert_eq!(profile.timezone.as_deref(), Some("Europe/London"));
        assert_eq!(profile.locale.as_deref(), Some("en_GB"));
        assert_eq!(profile.city.as_deref(), Some("London"));
        assert_eq!(profile.country.as_deref(), Some("GB"));
    }

    #[test]
    fn profile_empty_returns_defaults() {
        let profile = parse_stalker_profile("{}");
        assert!(profile.timezone.is_none());
        assert!(profile.locale.is_none());
    }

    #[test]
    fn profile_invalid_json() {
        let profile = parse_stalker_profile("not json");
        assert!(profile.timezone.is_none());
    }

    // ── parse_stalker_account_info ────────────

    #[test]
    fn account_info_basic() {
        let json = json!({
            "js": {
                "phone": "+1234567890",
                "login": "user1",
                "mac": "00:1A:2B:3C:4D:5E",
                "status": 0,
                "exp_date": "2025-12-31",
                "tariff_name": "Premium HD",
            }
        })
        .to_string();

        let info = parse_stalker_account_info(&json);
        assert_eq!(info.phone.as_deref(), Some("+1234567890"));
        assert_eq!(info.login.as_deref(), Some("user1"));
        assert_eq!(info.mac.as_deref(), Some("00:1A:2B:3C:4D:5E"));
        assert_eq!(info.status, 0);
        assert_eq!(info.exp_date.as_deref(), Some("2025-12-31"));
        assert_eq!(info.tariff_name.as_deref(), Some("Premium HD"));
    }

    #[test]
    fn account_info_tariff_fallback() {
        let json = json!({
            "js": {
                "tariff": "Basic",
            }
        })
        .to_string();

        let info = parse_stalker_account_info(&json);
        assert_eq!(info.tariff_name.as_deref(), Some("Basic"));
    }

    #[test]
    fn account_info_invalid_json() {
        let info = parse_stalker_account_info("bad");
        // Default status is 0 since the entire struct defaults.
        assert_eq!(info.status, 0);
        assert!(info.login.is_none());
    }

    // ── parse_stalker_vod_detail ──────────────

    #[test]
    fn vod_detail_with_movie_key() {
        let json = json!({
            "js": {
                "movie": {
                    "id": "501",
                    "name": "Test Movie",
                    "cmd": "http://vod/501.mp4",
                    "description": "A test movie",
                }
            }
        })
        .to_string();

        let item = parse_stalker_vod_detail(&json, "http://portal.com", "src_1");
        assert!(item.is_some());
        let v = item.unwrap();
        assert_uuid_v7(&v.id);
        assert_eq!(v.name, "Test Movie");
        assert_eq!(v.description.as_deref(), Some("A test movie"));
    }

    #[test]
    fn vod_detail_without_movie_key() {
        let json = json!({
            "js": {
                "id": "502",
                "name": "Direct VOD",
                "cmd": "http://vod/502.mp4",
            }
        })
        .to_string();

        let item = parse_stalker_vod_detail(&json, "http://portal.com", "src_1");
        assert!(item.is_some());
        assert_eq!(item.unwrap().name, "Direct VOD");
    }

    #[test]
    fn vod_detail_invalid_json() {
        let item = parse_stalker_vod_detail("bad", "http://portal.com", "src_1");
        assert!(item.is_none());
    }

    // ── parse_stalker_series_detail ───────────

    #[test]
    fn series_detail_structured_seasons() {
        let json = json!({
            "js": {
                "seasons": [
                    {
                        "season_number": 1,
                        "episodes": [
                            {"id": "601", "name": "Pilot", "cmd": "http://vod/601.mp4"},
                            {"id": "602", "name": "Second", "cmd": "http://vod/602.mp4"},
                        ]
                    },
                    {
                        "season_number": 2,
                        "episodes": [
                            {"id": "603", "name": "S2E1", "cmd": "http://vod/603.mp4"},
                        ]
                    }
                ]
            }
        })
        .to_string();

        let eps = parse_stalker_series_detail(&json, "http://portal.com", "series_100", "src_1");
        assert_eq!(eps.len(), 3);
        assert_eq!(eps[0].name, "Pilot");
        assert_eq!(eps[0].season_number, Some(1));
        assert_eq!(eps[0].episode_number, Some(1));
        assert_eq!(eps[0].series_id.as_deref(), Some("series_100"));
        assert_eq!(eps[2].season_number, Some(2));
        assert_eq!(eps[2].episode_number, Some(1));
    }

    #[test]
    fn series_detail_flat_data() {
        let json = json!({
            "js": {
                "data": [
                    {"id": "701", "name": "Ep1", "cmd": "http://vod/701.mp4"},
                    {"id": "702", "name": "Ep2", "cmd": "http://vod/702.mp4"},
                ]
            }
        })
        .to_string();

        let eps = parse_stalker_series_detail(&json, "http://portal.com", "series_200", "src_1");
        assert_eq!(eps.len(), 2);
        assert_eq!(eps[0].series_id.as_deref(), Some("series_200"));
    }

    #[test]
    fn series_detail_empty() {
        let eps = parse_stalker_series_detail("{}", "http://portal.com", "s1", "src_1");
        assert!(eps.is_empty());
    }

    // ── parse_stalker_favorites ───────────────

    #[test]
    fn favorites_comma_string() {
        let json = json!({"js": "1,2,3"}).to_string();
        let favs = parse_stalker_favorites(&json);
        assert_eq!(favs, vec!["1", "2", "3"]);
    }

    #[test]
    fn favorites_array() {
        let json = json!({"js": ["10", "20"]}).to_string();
        let favs = parse_stalker_favorites(&json);
        assert_eq!(favs, vec!["10", "20"]);
    }

    #[test]
    fn favorites_data_objects() {
        let json = json!({
            "js": {
                "data": [
                    {"id": "100"},
                    {"id": "200"},
                ]
            }
        })
        .to_string();

        let favs = parse_stalker_favorites(&json);
        assert_eq!(favs, vec!["100", "200"]);
    }

    #[test]
    fn favorites_empty() {
        let favs = parse_stalker_favorites("{}");
        assert!(favs.is_empty());
    }

    #[test]
    fn favorites_invalid_json() {
        let favs = parse_stalker_favorites("not json");
        assert!(favs.is_empty());
    }
}
