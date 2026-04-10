//! Xtream API parsers and URL builders.
//!
//! Ports Xtream functionality from Dart:
//! - `_parseShortEpg` / `_parseEpgTimestamp` from
//!   `playlist_sync_service.dart`
//! - URL builders and live-stream parser from
//!   `xtream_client.dart`

use std::collections::HashSet;

use percent_encoding::{NON_ALPHANUMERIC, utf8_percent_encode};
use serde_json::Value;
use url::Url;
use url::form_urlencoded::Serializer;

use chrono::DateTime;

use crate::algorithms::normalize::{parse_epg_timestamp, try_base64_decode};
use crate::models::{Channel, EpgEntry, new_entity_id};
use crate::utils::image_sanitizer::sanitize_image_url;

/// Percent-encode a credential value for safe URL
/// interpolation.
fn encode_credential(value: &str) -> String {
    utf8_percent_encode(value, NON_ALPHANUMERIC).to_string()
}

/// Parsed credential-bearing Xtream stream URL components.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct XtreamStreamCredentials {
    /// Canonical API base URL (`scheme://host[:port]`).
    pub base_url: String,
    /// Decoded Xtream username.
    pub username: String,
    /// Decoded Xtream password.
    pub password: String,
}

/// Parse Xtream `get_short_epg` listings into
/// [`EpgEntry`] vec.
///
/// Titles may be base64-encoded. If base64 decode
/// succeeds and the result is valid UTF-8, the decoded
/// string is used; otherwise the original title is kept.
/// Entries missing title, start, or end are skipped.
pub fn parse_short_epg(listings: &[Value], channel_id: &str) -> Vec<EpgEntry> {
    let mut entries = Vec::new();

    for item in listings {
        let Some(obj) = item.as_object() else {
            continue;
        };

        // ── Title (may be base64-encoded) ────────
        let raw_title = obj.get("title").and_then(Value::as_str).unwrap_or("");
        let title = try_base64_decode(raw_title);
        if title.is_empty() {
            continue;
        }

        // ── Timestamps ───────────────────────────
        let start_str = obj.get("start").and_then(Value::as_str).unwrap_or("");
        let end_str = obj.get("end").and_then(Value::as_str).unwrap_or("");

        let Some(start_time) = parse_epg_timestamp(start_str) else {
            continue;
        };
        let Some(end_time) = parse_epg_timestamp(end_str) else {
            continue;
        };

        // ── Description (optional) ───────────────
        let description = obj
            .get("description")
            .and_then(Value::as_str)
            .filter(|s| !s.is_empty())
            .map(try_base64_decode);

        entries.push(EpgEntry {
            epg_channel_id: channel_id.to_string(),
            title,
            start_time,
            end_time,
            description,
            ..EpgEntry::default()
        });
    }

    entries
}

// ── URL Builders ─────────────────────────────────

/// Normalize a base URL to `scheme://host[:port]` form.
///
/// Strips any path component. If the URL has no scheme,
/// `http://` is prepended. Delegates to
/// [`url_normalize::normalize_api_base_url`] for the
/// canonical implementation.
pub fn normalize_base_url(base_url: &str) -> String {
    crate::algorithms::url_normalize::normalize_api_base_url(base_url)
        .unwrap_or_else(|_| base_url.to_string())
}

/// Build an Xtream API action URL.
///
/// Format:
/// `{base}/player_api.php?username={u}&password={p}&action={action}&{params}`
pub fn build_xtream_action_url(
    base_url: &str,
    username: &str,
    password: &str,
    action: &str,
    params: &[(String, String)],
) -> String {
    let base = normalize_base_url(base_url);
    let mut serializer = Serializer::new(String::new());
    serializer.append_pair("username", username);
    serializer.append_pair("password", password);
    serializer.append_pair("action", action);
    for (k, v) in params {
        serializer.append_pair(k, v);
    }
    let query = serializer.finish();
    format!("{base}/player_api.php?{query}")
}

/// Build the XMLTV EPG URL for an Xtream server.
///
/// Endpoint: `{base}/xmltv.php?username={user}&password={pass}`
pub fn build_xmltv_url(base_url: &str, username: &str, password: &str) -> String {
    let base = normalize_base_url(base_url);
    let enc_user = encode_credential(username);
    let enc_pass = encode_credential(password);
    format!("{base}/xmltv.php?username={enc_user}&password={enc_pass}")
}

/// Build an Xtream stream URL.
///
/// Format depends on `stream_type`:
/// - `"live"`:
///   `{base}/live/{user}/{pass}/{stream_id}.ts`
/// - `"movie"` | `"vod"`:
///   `{base}/movie/{user}/{pass}/{stream_id}.{ext}`
/// - `"series"`:
///   `{base}/series/{user}/{pass}/{stream_id}.{ext}`
/// - anything else defaults to the `live` format.
pub fn build_xtream_stream_url(
    base_url: &str,
    username: &str,
    password: &str,
    stream_id: i64,
    stream_type: &str,
    extension: &str,
) -> String {
    let base = normalize_base_url(base_url);
    let enc_user = encode_credential(username);
    let enc_pass = encode_credential(password);
    match stream_type {
        "live" => format!(
            "{base}/live/{enc_user}/{enc_pass}\
             /{stream_id}.ts",
        ),
        "movie" | "vod" => format!(
            "{base}/movie/{enc_user}/{enc_pass}\
             /{stream_id}.{extension}",
        ),
        "series" => format!(
            "{base}/series/{enc_user}/{enc_pass}\
             /{stream_id}.{extension}",
        ),
        _ => format!(
            "{base}/live/{enc_user}/{enc_pass}\
             /{stream_id}.ts",
        ),
    }
}

/// Build an Xtream catchup/timeshift URL.
///
/// Format:
/// `{base}/timeshift/{user}/{pass}/{duration_min}/{start_utc}/{stream_id}.ts`
pub fn build_xtream_catchup_url(
    base_url: &str,
    username: &str,
    password: &str,
    stream_id: i64,
    start_utc: i64,
    duration_minutes: i32,
) -> String {
    let base = normalize_base_url(base_url);
    let enc_user = encode_credential(username);
    let enc_pass = encode_credential(password);
    format!(
        "{base}/timeshift/{enc_user}/{enc_pass}\
         /{duration_minutes}/{start_utc}/{stream_id}.ts",
    )
}

/// Extract Xtream credentials from a canonical stream URL.
pub fn extract_xtream_stream_credentials(stream_url: &str) -> Option<XtreamStreamCredentials> {
    let parsed = Url::parse(stream_url).ok()?;
    match parsed.scheme() {
        "http" | "https" => {}
        _ => return None,
    }

    let mut segments = parsed.path_segments()?;
    let stream_type = segments.next()?;
    if !matches!(stream_type, "live" | "movie" | "series") {
        return None;
    }

    let username = percent_encoding::percent_decode_str(segments.next()?)
        .decode_utf8()
        .ok()?
        .into_owned();
    let password = percent_encoding::percent_decode_str(segments.next()?)
        .decode_utf8()
        .ok()?
        .into_owned();

    let host = parsed.host_str()?;
    let base_url = match parsed.port() {
        Some(port) => format!("{}://{}:{port}", parsed.scheme(), host),
        None => format!("{}://{host}", parsed.scheme()),
    };

    Some(XtreamStreamCredentials {
        base_url,
        username,
        password,
    })
}

// ── Live-Stream & Category Parsers ───────────────

/// Extract an `i64` from a JSON value that may be
/// a number or a numeric string.
fn json_as_i64(val: &Value) -> Option<i64> {
    val.as_i64()
        .or_else(|| val.as_str().and_then(|s| s.parse::<i64>().ok()))
}

/// Parse Xtream `get_live_streams` JSON into
/// [`Channel`] objects.
///
/// Each item has: `stream_id`, `name`,
/// `epg_channel_id`, `stream_icon`, `category_name`,
/// `tv_archive`, `tv_archive_duration`, `num`.
pub fn parse_xtream_live_streams(
    data: &[Value],
    base_url: &str,
    username: &str,
    password: &str,
) -> Vec<Channel> {
    let mut channels = Vec::with_capacity(data.len());

    for item in data {
        let Some(obj) = item.as_object() else {
            continue;
        };

        // stream_id (required)
        let stream_id = obj.get("stream_id").and_then(json_as_i64).unwrap_or(0);

        let name = obj
            .get("name")
            .and_then(Value::as_str)
            .unwrap_or("Unknown")
            .to_string();

        let epg_channel_id = obj
            .get("epg_channel_id")
            .and_then(Value::as_str)
            .unwrap_or("")
            .to_string();

        let stream_icon = sanitize_image_url(
            obj.get("stream_icon")
                .and_then(Value::as_str)
                .map(|s| s.to_string()),
        );

        let mut category_name = obj
            .get("category_name")
            .and_then(Value::as_str)
            .unwrap_or("")
            .to_string();

        if category_name.is_empty() {
            category_name = obj
                .get("category_id")
                .map(|v| {
                    v.as_str()
                        .map(String::from)
                        .unwrap_or_else(|| v.to_string())
                })
                .unwrap_or_default();
        }

        let tv_archive = obj.get("tv_archive").and_then(json_as_i64).unwrap_or(0);

        let tv_archive_duration = obj
            .get("tv_archive_duration")
            .and_then(json_as_i64)
            .unwrap_or(0) as i32;

        let number = obj.get("num").and_then(json_as_i64).map(|n| n as i32);

        let stream_url =
            build_xtream_stream_url(base_url, username, password, stream_id, "live", "");

        let tvg_id = if epg_channel_id.is_empty() {
            stream_id.to_string()
        } else {
            epg_channel_id
        };

        let has_catchup = tv_archive == 1 && tv_archive_duration > 0;

        // ── Xtream-specific fields ─────────────
        let is_adult = obj.get("is_adult").and_then(json_as_i64).unwrap_or(0) == 1;

        let custom_sid = obj
            .get("custom_sid")
            .and_then(Value::as_str)
            .filter(|s| !s.is_empty())
            .map(String::from);

        let direct_source = obj
            .get("direct_source")
            .and_then(Value::as_str)
            .filter(|s| !s.is_empty())
            .map(String::from);

        // ── added timestamp (unix epoch) ───────
        let added_at = obj
            .get("added")
            .and_then(|v| {
                // May be a numeric string or integer.
                v.as_i64()
                    .or_else(|| v.as_str().and_then(|s| s.parse::<i64>().ok()))
            })
            .and_then(|ts| DateTime::from_timestamp(ts, 0))
            .map(|dt| dt.naive_utc());

        let epg_channel_id = obj
            .get("epg_channel_id")
            .and_then(Value::as_str)
            .filter(|s| !s.is_empty())
            .map(String::from);

        channels.push(Channel {
            id: new_entity_id(),
            native_id: stream_id.to_string(),
            name: name.clone(),
            stream_url,
            number,
            channel_group: if category_name.is_empty() {
                None
            } else {
                Some(category_name)
            },
            logo_url: stream_icon,
            tvg_id: Some(tvg_id),
            xtream_stream_id: Some(stream_id.to_string()),
            epg_channel_id,
            tvg_name: Some(name),
            is_favorite: false,
            user_agent: None,
            has_catchup,
            catchup_days: tv_archive_duration,
            catchup_type: None,
            catchup_source: None,
            resolution: None,
            source_id: None,
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
            custom_sid,
            direct_source,
            ..Default::default()
        });
    }

    channels
}

/// Parse Xtream categories response into sorted
/// unique names.
///
/// Input: JSON array of `{category_id, category_name}`.
/// Returns sorted unique category names.
pub fn parse_xtream_categories(data: &[Value]) -> Vec<String> {
    if data.is_empty() {
        return Vec::new();
    }
    let mut names = HashSet::new();
    for item in data {
        if let Some(name) = item.get("category_name").and_then(Value::as_str)
            && !name.is_empty()
        {
            names.insert(name.to_string());
        }
    }
    let mut sorted: Vec<String> = names.into_iter().collect();
    sorted.sort();
    sorted
}

// ── Adapter: crispy_xtream crate types ───────────

/// Convert a slice of [`XtreamChannel`] (from `crispy_xtream`) into
/// [`Channel`] models using `From<XtreamChannel>`.
///
/// This is a thin adapter for callers that already have typed
/// Xtream channel data. The stream URL must be pre-populated on
/// each `XtreamChannel.url` before calling.
pub fn channels_from_xtream(
    channels: Vec<crispy_xtream::types::XtreamChannel>,
    source_id: Option<&str>,
) -> Vec<Channel> {
    channels
        .into_iter()
        .map(|xc| {
            let mut ch: Channel = xc.into();
            if let Some(sid) = source_id {
                ch.source_id = Some(sid.to_string());
            }
            ch
        })
        .collect()
}

/// Convert a slice of [`XtreamMovieListing`] (from `crispy_xtream`)
/// into [`Movie`] models.
pub fn movies_from_xtream(
    listings: Vec<crispy_xtream::types::XtreamMovieListing>,
    source_id: &str,
) -> Vec<crate::models::Movie> {
    listings
        .into_iter()
        .map(|ml| {
            let mut movie: crate::models::Movie = ml.into();
            movie.source_id = source_id.to_string();
            movie
        })
        .collect()
}

/// Convert a slice of [`XtreamShowListing`] (from `crispy_xtream`)
/// into [`Series`] models.
pub fn series_from_xtream(
    listings: Vec<crispy_xtream::types::XtreamShowListing>,
    source_id: &str,
) -> Vec<crate::models::Series> {
    listings
        .into_iter()
        .map(|sl| {
            let mut series: crate::models::Series = sl.into();
            series.source_id = source_id.to_string();
            series
        })
        .collect()
}

// ── Bridge adapters: raw JSON → crate types → domain models ──

/// Parse Xtream `get_live_streams` JSON via the `crispy_xtream` crate types.
///
/// Deserializes each `Value` into [`XtreamChannel`], populates the stream
/// URL from the provided credentials, then delegates to [`channels_from_xtream`].
/// Items that fail deserialization are silently skipped (non-fatal).
pub fn channels_from_xtream_json(
    data: &[Value],
    base_url: &str,
    username: &str,
    password: &str,
    source_id: Option<&str>,
) -> Vec<Channel> {
    let mut channels = parse_xtream_live_streams(data, base_url, username, password);
    for channel in &mut channels {
        if channel.tvg_id.as_deref() == Some(channel.native_id.as_str()) {
            channel.tvg_id = None;
        }
    }
    if let Some(sid) = source_id {
        for channel in &mut channels {
            channel.source_id = Some(sid.to_string());
        }
    }
    channels
}

/// Parse Xtream `get_vod_streams` JSON via the `crispy_xtream` crate types.
///
/// Deserializes each `Value` into [`XtreamMovieListing`], then delegates to
/// [`movies_from_xtream`]. Returns [`VodItem`] for backward compatibility
/// with the current DB layer.
pub fn vod_from_xtream_json(
    data: &[Value],
    base_url: &str,
    username: &str,
    password: &str,
    source_id: Option<&str>,
) -> Vec<crate::models::VodItem> {
    let typed: Vec<crispy_xtream::types::XtreamMovieListing> = data
        .iter()
        .filter_map(|v| serde_json::from_value(v.clone()).ok())
        .collect();

    let categories: Vec<Option<String>> =
        typed.iter().map(|item| item.category_id.clone()).collect();

    crate::parsers::vod::movies_from_xtream_listings(typed, base_url, username, password, source_id)
        .into_iter()
        .zip(categories)
        .map(|(movie, category_id)| {
            let mut vod = crate::models::VodItem::from(movie);
            vod.category = category_id;
            vod
        })
        .collect()
}

/// Parse Xtream `get_series` JSON via the `crispy_xtream` crate types.
///
/// Deserializes each `Value` into [`XtreamShowListing`], then delegates to
/// [`series_from_xtream`]. Returns [`VodItem`] for backward compatibility.
pub fn series_from_xtream_json(
    data: &[Value],
    source_id: Option<&str>,
) -> Vec<crate::models::VodItem> {
    let typed: Vec<crispy_xtream::types::XtreamShowListing> = data
        .iter()
        .filter_map(|v| serde_json::from_value(v.clone()).ok())
        .collect();

    let categories: Vec<Option<String>> =
        typed.iter().map(|item| item.category_id.clone()).collect();
    let sid = source_id.unwrap_or("");
    series_from_xtream(typed, sid)
        .into_iter()
        .zip(categories)
        .map(|(series, category_id)| {
            let mut vod = crate::models::VodItem::from(series);
            vod.category = category_id;
            vod
        })
        .collect()
}

// ── Tests ────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use base64::{Engine, engine::general_purpose::STANDARD};
    use chrono::NaiveDateTime;
    use serde_json::json;

    fn assert_uuid_v7(id: &str) {
        let parsed = uuid::Uuid::parse_str(id).expect("valid UUID");
        assert_eq!(parsed.get_version_num(), 7);
    }

    fn make_listing(title: &str, start: &str, end: &str, desc: Option<&str>) -> Value {
        let mut obj = json!({
            "title": title,
            "start": start,
            "end": end,
        });
        if let Some(d) = desc {
            obj["description"] = json!(d);
        }
        obj
    }

    #[test]
    fn base64_title_decoded() {
        // "Morning Show" base64-encoded
        let b64 = STANDARD.encode("Morning Show");
        let listings = vec![make_listing(
            &b64,
            "2024-01-15 06:00:00",
            "2024-01-15 07:00:00",
            None,
        )];
        let entries = parse_short_epg(&listings, "ch1");
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].title, "Morning Show");
    }

    #[test]
    fn plain_text_title_kept() {
        // "News@9" is not valid base64 padding →
        // decode fails → kept as-is.
        let listings = vec![make_listing(
            "News@9",
            "2024-01-15 21:00:00",
            "2024-01-15 22:00:00",
            Some("Evening news"),
        )];
        let entries = parse_short_epg(&listings, "ch2");
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].title, "News@9");
        assert_eq!(entries[0].description.as_deref(), Some("Evening news"),);
    }

    #[test]
    fn invalid_base64_keeps_original() {
        let listings = vec![make_listing(
            "Not!!Valid==Base64",
            "2024-01-15 08:00:00",
            "2024-01-15 09:00:00",
            None,
        )];
        let entries = parse_short_epg(&listings, "ch3");
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].title, "Not!!Valid==Base64",);
    }

    #[test]
    fn timestamps_parsed() {
        let listings = vec![make_listing(
            "Show",
            "2024-01-15 06:30:00",
            "2024-01-15 07:30:00",
            None,
        )];
        let entries = parse_short_epg(&listings, "ch1");
        assert_eq!(entries.len(), 1);
        assert_eq!(
            entries[0].start_time,
            NaiveDateTime::new(
                chrono::NaiveDate::from_ymd_opt(2024, 1, 15,).unwrap(),
                chrono::NaiveTime::from_hms_opt(6, 30, 0,).unwrap(),
            ),
        );
        assert_eq!(
            entries[0].end_time,
            NaiveDateTime::new(
                chrono::NaiveDate::from_ymd_opt(2024, 1, 15,).unwrap(),
                chrono::NaiveTime::from_hms_opt(7, 30, 0,).unwrap(),
            ),
        );
    }

    #[test]
    fn missing_start_skips_entry() {
        let listings = vec![make_listing("Show", "", "2024-01-15 07:00:00", None)];
        let entries = parse_short_epg(&listings, "ch1");
        assert!(entries.is_empty());
    }

    #[test]
    fn missing_end_skips_entry() {
        let listings = vec![make_listing("Show", "2024-01-15 06:00:00", "", None)];
        let entries = parse_short_epg(&listings, "ch1");
        assert!(entries.is_empty());
    }

    #[test]
    fn empty_title_skips_entry() {
        let listings = vec![make_listing(
            "",
            "2024-01-15 06:00:00",
            "2024-01-15 07:00:00",
            None,
        )];
        let entries = parse_short_epg(&listings, "ch1");
        assert!(entries.is_empty());
    }

    #[test]
    fn empty_listings_returns_empty() {
        let entries = parse_short_epg(&[], "ch1");
        assert!(entries.is_empty());
    }

    #[test]
    fn non_object_items_skipped() {
        let listings = vec![json!("string"), json!(42), json!(null)];
        let entries = parse_short_epg(&listings, "ch1");
        assert!(entries.is_empty());
    }

    #[test]
    fn rfc3339_fallback() {
        let listings = vec![make_listing(
            "Show",
            "2024-01-15T06:00:00Z",
            "2024-01-15T07:00:00Z",
            None,
        )];
        let entries = parse_short_epg(&listings, "ch1");
        assert_eq!(entries.len(), 1);
        assert_eq!(
            entries[0].start_time,
            NaiveDateTime::new(
                chrono::NaiveDate::from_ymd_opt(2024, 1, 15,).unwrap(),
                chrono::NaiveTime::from_hms_opt(6, 0, 0,).unwrap(),
            ),
        );
    }

    #[test]
    fn channel_id_set_correctly() {
        let listings = vec![make_listing(
            "Show",
            "2024-01-15 06:00:00",
            "2024-01-15 07:00:00",
            None,
        )];
        let entries = parse_short_epg(&listings, "my_channel");
        assert_eq!(entries[0].epg_channel_id, "my_channel",);
    }

    // ── URL Builder Tests ────────────────────────

    #[test]
    fn action_url_with_params() {
        let url = build_xtream_action_url(
            "http://example.com:8080/extra/path",
            "user1",
            "pass1",
            "get_live_streams",
            &[("category_id".into(), "5".into())],
        );
        assert_eq!(
            url,
            "http://example.com:8080\
             /player_api.php\
             ?username=user1\
             &password=pass1\
             &action=get_live_streams\
             &category_id=5",
        );
    }

    #[test]
    fn action_url_encodes_query_components() {
        let url = build_xtream_action_url(
            "http://example.com",
            "user",
            "pass",
            "get live streams",
            &[
                ("cat id".into(), "5".into()),
                ("search".into(), "one & two".into()),
            ],
        );
        assert!(url.contains("action=get+live+streams"));
        assert!(url.contains("cat+id=5"));
        assert!(url.contains("search=one+%26+two"));
    }

    #[test]
    fn stream_url_live() {
        let url = build_xtream_stream_url("http://tv.example.com:8080", "u", "p", 42, "live", "");
        assert_eq!(
            url,
            "http://tv.example.com:8080\
             /live/u/p/42.ts",
        );
    }

    #[test]
    fn stream_url_movie() {
        let url =
            build_xtream_stream_url("http://tv.example.com:8080", "u", "p", 99, "movie", "mp4");
        assert_eq!(
            url,
            "http://tv.example.com:8080\
             /movie/u/p/99.mp4",
        );
    }

    #[test]
    fn stream_url_series() {
        let url = build_xtream_stream_url("http://tv.example.com", "u", "p", 7, "series", "mkv");
        assert_eq!(
            url,
            "http://tv.example.com\
             /series/u/p/7.mkv",
        );
    }

    #[test]
    fn catchup_url_format() {
        let url =
            build_xtream_catchup_url("http://tv.example.com:8080", "u", "p", 123, 1700000000, 60);
        assert_eq!(
            url,
            "http://tv.example.com:8080\
             /timeshift/u/p/60/1700000000/123.ts",
        );
    }

    // ── Live-Stream Parser Tests ─────────────────

    #[allow(clippy::too_many_arguments)]
    fn make_live_stream(
        stream_id: i64,
        name: &str,
        epg_channel_id: &str,
        icon: &str,
        category: &str,
        tv_archive: i64,
        archive_dur: i64,
        num: Option<i64>,
    ) -> Value {
        let mut obj = json!({
            "stream_id": stream_id,
            "name": name,
            "epg_channel_id": epg_channel_id,
            "stream_icon": icon,
            "category_name": category,
            "tv_archive": tv_archive,
            "tv_archive_duration": archive_dur,
        });
        if let Some(n) = num {
            obj["num"] = json!(n);
        }
        obj
    }

    #[test]
    fn parse_live_stream_basic() {
        let data = vec![make_live_stream(
            100,
            "BBC One",
            "bbc1",
            "http://icon.png",
            "UK",
            0,
            0,
            Some(1),
        )];
        let channels = parse_xtream_live_streams(&data, "http://tv.example.com:8080", "u", "p");
        assert_eq!(channels.len(), 1);
        let ch = &channels[0];
        assert_uuid_v7(&ch.id);
        assert_eq!(ch.name, "BBC One");
        assert_eq!(ch.tvg_id.as_deref(), Some("bbc1"),);
        assert_eq!(ch.logo_url.as_deref(), Some("http://icon.png"),);
        assert_eq!(ch.channel_group.as_deref(), Some("UK"),);
        assert_eq!(ch.number, Some(1));
        assert!(!ch.has_catchup);
        assert_eq!(ch.catchup_days, 0);
        assert!(ch.stream_url.contains("/live/u/p/100.ts"));
    }

    #[test]
    fn parse_live_stream_with_catchup() {
        let data = vec![make_live_stream(200, "CNN", "cnn", "", "News", 1, 7, None)];
        let channels = parse_xtream_live_streams(&data, "http://tv.example.com", "u", "p");
        assert_eq!(channels.len(), 1);
        let ch = &channels[0];
        assert!(ch.has_catchup);
        assert_eq!(ch.catchup_days, 7);
    }

    #[test]
    fn parse_live_stream_epg_fallback() {
        // Empty epg_channel_id → falls back to
        // stream_id as string.
        let data = vec![make_live_stream(
            300, "Local TV", "", "", "Local", 0, 0, None,
        )];
        let channels = parse_xtream_live_streams(&data, "http://tv.example.com", "u", "p");
        assert_eq!(channels[0].tvg_id.as_deref(), Some("300"),);
    }

    // ── Category Parser Tests ────────────────────

    #[test]
    fn parse_categories_dedup_and_sort() {
        let data = vec![
            json!({"category_id": "1",
                   "category_name": "Sports"}),
            json!({"category_id": "2",
                   "category_name": "News"}),
            json!({"category_id": "3",
                   "category_name": "Sports"}),
            json!({"category_id": "4",
                   "category_name": "Movies"}),
        ];
        let cats = parse_xtream_categories(&data);
        assert_eq!(cats, vec!["Movies", "News", "Sports"],);
    }

    #[test]
    fn parse_categories_empty_and_null_skipped() {
        let data = vec![
            json!({"category_id": "1",
                   "category_name": ""}),
            json!({"category_id": "2",
                   "category_name": null}),
            json!({"category_id": "3",
                   "category_name": "Valid"}),
        ];
        let cats = parse_xtream_categories(&data);
        assert_eq!(cats, vec!["Valid"]);
    }

    // ── SEC-05: Credential encoding tests ────────

    #[test]
    fn action_url_encodes_special_credentials() {
        let url = build_xtream_action_url(
            "http://example.com",
            "user@host",
            "p@ss/word#1",
            "get_live_streams",
            &[],
        );
        assert!(
            url.contains("username=user%40host"),
            "@ in username must be encoded",
        );
        assert!(
            url.contains("password=p%40ss%2Fword%231"),
            "special chars in password must be encoded",
        );
    }

    #[test]
    fn stream_url_encodes_special_credentials() {
        let url = build_xtream_stream_url(
            "http://tv.example.com",
            "user/slash",
            "pass?query",
            42,
            "live",
            "",
        );
        assert!(
            url.contains("user%2Fslash"),
            "/ in username must be encoded",
        );
        assert!(
            url.contains("pass%3Fquery"),
            "? in password must be encoded",
        );
        assert!(
            !url.contains("user/slash/pass?query"),
            "raw credentials must not appear",
        );
    }

    #[test]
    fn catchup_url_encodes_special_credentials() {
        let url = build_xtream_catchup_url(
            "http://tv.example.com",
            "u#ser",
            "p@ss",
            123,
            1700000000,
            60,
        );
        assert!(url.contains("u%23ser"), "# in username must be encoded",);
        assert!(url.contains("p%40ss"), "@ in password must be encoded",);
    }

    #[test]
    fn extract_xtream_stream_credentials_from_live_url() {
        let creds =
            extract_xtream_stream_credentials("http://tv.example.com:8080/live/user/pass/42.ts")
                .expect("expected Xtream credentials");
        assert_eq!(creds.base_url, "http://tv.example.com:8080");
        assert_eq!(creds.username, "user");
        assert_eq!(creds.password, "pass");
    }

    #[test]
    fn extract_xtream_stream_credentials_decodes_segments() {
        let creds = extract_xtream_stream_credentials(
            "https://tv.example.com/live/user%40name/pass%2Fword/42.ts",
        )
        .expect("expected Xtream credentials");
        assert_eq!(creds.base_url, "https://tv.example.com");
        assert_eq!(creds.username, "user@name");
        assert_eq!(creds.password, "pass/word");
    }

    #[test]
    fn extract_xtream_stream_credentials_rejects_non_xtream_urls() {
        assert!(extract_xtream_stream_credentials("http://tv.example.com/channel/42.ts").is_none());
    }

    #[test]
    fn live_stream_parser_encodes_credentials_in_url() {
        let data = vec![make_live_stream(100, "Ch", "ch1", "", "Cat", 0, 0, None)];
        let channels = parse_xtream_live_streams(&data, "http://tv.test", "user@host", "p/w");
        assert_eq!(channels.len(), 1);
        let url = &channels[0].stream_url;
        assert!(
            url.contains("user%40host"),
            "@ in username must be encoded in stream URL",
        );
        assert!(
            url.contains("p%2Fw"),
            "/ in password must be encoded in stream URL",
        );
    }

    // ── Xtream extended field mapping tests ────

    #[test]
    fn parse_live_stream_is_adult_mapped() {
        let mut item = make_live_stream(400, "Adult Ch", "adult1", "", "Adult", 0, 0, None);
        item["is_adult"] = json!(1);
        let channels = parse_xtream_live_streams(&[item], "http://tv.example.com", "u", "p");
        assert!(channels[0].is_adult, "is_adult=1 must map to true");
    }

    #[test]
    fn parse_live_stream_is_adult_zero_is_false() {
        let mut item = make_live_stream(401, "Normal Ch", "ch1", "", "General", 0, 0, None);
        item["is_adult"] = json!(0);
        let channels = parse_xtream_live_streams(&[item], "http://tv.example.com", "u", "p");
        assert!(!channels[0].is_adult, "is_adult=0 must map to false");
    }

    #[test]
    fn parse_live_stream_is_adult_string() {
        // Some providers send is_adult as a string "1".
        let mut item = make_live_stream(402, "Adult Str", "a2", "", "Adult", 0, 0, None);
        item["is_adult"] = json!("1");
        let channels = parse_xtream_live_streams(&[item], "http://tv.example.com", "u", "p");
        assert!(channels[0].is_adult, "is_adult=\"1\" must map to true");
    }

    #[test]
    fn parse_live_stream_is_adult_missing_defaults_false() {
        // No is_adult field at all.
        let item = make_live_stream(403, "No Adult", "na", "", "General", 0, 0, None);
        let channels = parse_xtream_live_streams(&[item], "http://tv.example.com", "u", "p");
        assert!(
            !channels[0].is_adult,
            "missing is_adult must default to false",
        );
    }

    #[test]
    fn parse_live_stream_custom_sid_mapped() {
        let mut item = make_live_stream(500, "Custom", "c1", "", "General", 0, 0, None);
        item["custom_sid"] = json!("my_custom_sid_123");
        let channels = parse_xtream_live_streams(&[item], "http://tv.example.com", "u", "p");
        assert_eq!(channels[0].custom_sid.as_deref(), Some("my_custom_sid_123"),);
    }

    #[test]
    fn parse_live_stream_custom_sid_empty_is_none() {
        let mut item = make_live_stream(501, "Empty SID", "c2", "", "General", 0, 0, None);
        item["custom_sid"] = json!("");
        let channels = parse_xtream_live_streams(&[item], "http://tv.example.com", "u", "p");
        assert!(
            channels[0].custom_sid.is_none(),
            "empty custom_sid must map to None",
        );
    }

    #[test]
    fn parse_live_stream_direct_source_mapped() {
        let mut item = make_live_stream(600, "Direct", "d1", "", "General", 0, 0, None);
        item["direct_source"] = json!("http://direct.example.com/stream");
        let channels = parse_xtream_live_streams(&[item], "http://tv.example.com", "u", "p");
        assert_eq!(
            channels[0].direct_source.as_deref(),
            Some("http://direct.example.com/stream"),
        );
    }

    #[test]
    fn parse_live_stream_direct_source_empty_is_none() {
        let mut item = make_live_stream(601, "No Direct", "d2", "", "General", 0, 0, None);
        item["direct_source"] = json!("");
        let channels = parse_xtream_live_streams(&[item], "http://tv.example.com", "u", "p");
        assert!(
            channels[0].direct_source.is_none(),
            "empty direct_source must map to None",
        );
    }

    #[test]
    fn parse_live_stream_added_timestamp_mapped() {
        let mut item = make_live_stream(700, "Added", "a1", "", "General", 0, 0, None);
        // 2024-01-15 12:00:00 UTC
        item["added"] = json!("1705320000");
        let channels = parse_xtream_live_streams(&[item], "http://tv.example.com", "u", "p");
        let added = channels[0].added_at.expect("added_at must be Some");
        assert_eq!(added.and_utc().timestamp(), 1705320000);
    }

    #[test]
    fn parse_live_stream_added_numeric_timestamp() {
        let mut item = make_live_stream(701, "Added Num", "a2", "", "General", 0, 0, None);
        item["added"] = json!(1705320000_i64);
        let channels = parse_xtream_live_streams(&[item], "http://tv.example.com", "u", "p");
        let added = channels[0].added_at.expect("added_at must be Some");
        assert_eq!(added.and_utc().timestamp(), 1705320000);
    }

    #[test]
    fn parse_live_stream_added_missing_is_none() {
        // No `added` field.
        let item = make_live_stream(702, "No Added", "a3", "", "General", 0, 0, None);
        let channels = parse_xtream_live_streams(&[item], "http://tv.example.com", "u", "p");
        assert!(
            channels[0].added_at.is_none(),
            "missing added must result in None",
        );
    }

    #[test]
    fn parse_live_stream_all_xtream_fields() {
        // Full Xtream response with all fields.
        let item = json!({
            "stream_id": 999,
            "name": "Full Channel",
            "stream_type": "live",
            "epg_channel_id": "full_epg",
            "stream_icon": "http://icon.example.com/full.png",
            "category_id": "42",
            "category_name": "Premium",
            "num": 5,
            "added": "1705320000",
            "custom_sid": "custom_999",
            "tv_archive": 1,
            "tv_archive_duration": 14,
            "direct_source": "http://direct.example.com/full",
            "is_adult": 1,
        });
        let channels = parse_xtream_live_streams(&[item], "http://tv.example.com", "u", "p");
        assert_eq!(channels.len(), 1);
        let ch = &channels[0];
        assert_uuid_v7(&ch.id);
        assert_eq!(ch.name, "Full Channel");
        assert_eq!(ch.tvg_id.as_deref(), Some("full_epg"));
        assert_eq!(
            ch.logo_url.as_deref(),
            Some("http://icon.example.com/full.png"),
        );
        assert_eq!(ch.channel_group.as_deref(), Some("Premium"));
        assert_eq!(ch.number, Some(5));
        assert!(ch.has_catchup);
        assert_eq!(ch.catchup_days, 14);
        assert!(ch.is_adult);
        assert_eq!(ch.custom_sid.as_deref(), Some("custom_999"));
        assert_eq!(
            ch.direct_source.as_deref(),
            Some("http://direct.example.com/full"),
        );
        assert!(ch.added_at.is_some());
        assert_eq!(ch.added_at.unwrap().and_utc().timestamp(), 1705320000);
    }

    #[test]
    fn channels_from_xtream_json_accepts_numeric_bool_fields() {
        let item = json!({
            "stream_id": 123,
            "name": "Provider Channel",
            "stream_type": "live",
            "category_name": "News",
            "num": 7,
            "tv_archive": 0,
            "tv_archive_duration": 0,
            "is_adult": 0
        });

        let channels =
            channels_from_xtream_json(&[item], "http://tv.example.com", "user", "pass", Some("s1"));

        assert_eq!(channels.len(), 1);
        let ch = &channels[0];
        assert_eq!(ch.native_id, "123");
        assert_eq!(ch.name, "Provider Channel");
        assert!(ch.tvg_id.is_none());
        assert_eq!(ch.source_id.as_deref(), Some("s1"));
        assert_eq!(ch.channel_group.as_deref(), Some("News"));
    }
}
