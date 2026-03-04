//! Search result grouping algorithm.
//!
//! Ports the `_groupEnriched()` function from Dart
//! `search_repository_impl.dart` that groups enriched
//! search results by media type with metadata
//! enrichment from original entities.

use std::collections::HashMap;

use crate::algorithms::normalize::EPG_FORMAT;
use serde::{Deserialize, Serialize};
use serde_json::Value;

/// A single enriched search result from the Rust search
/// engine.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EnrichedResult {
    /// Item ID.
    pub id: String,
    /// Display name.
    pub name: String,
    /// Media type: "channel", "movie", "series", "epg".
    pub media_type: String,
    /// Optional metadata map.
    pub metadata: Option<HashMap<String, Value>>,
}

/// A grouped search result item for the Dart layer.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GroupedItem {
    /// Item ID.
    pub id: String,
    /// Display name.
    pub name: String,
    /// Media type string.
    pub media_type: String,
    /// Logo or poster URL.
    pub logo_url: Option<String>,
    /// Stream URL.
    pub stream_url: Option<String>,
    /// Rating string.
    pub rating: Option<String>,
    /// Release year.
    pub year: Option<i32>,
    /// Duration in milliseconds.
    pub duration_ms: Option<i64>,
    /// Description/overview.
    pub overview: Option<String>,
    /// Category name.
    pub category: Option<String>,
    /// Source identifier.
    pub source: String,
    /// EPG-specific: entry map.
    pub epg_entry: Option<Value>,
}

/// Grouped search results by content type.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct GroupedResults {
    /// Matching live channels.
    pub channels: Vec<GroupedItem>,
    /// Matching movies.
    pub movies: Vec<GroupedItem>,
    /// Matching series.
    pub series: Vec<GroupedItem>,
    /// Matching EPG programmes.
    pub epg_programs: Vec<GroupedItem>,
}

/// Group enriched search results by media type.
///
/// Takes:
/// - `results_json`: JSON array of `EnrichedResult`
/// - `channels_json`: JSON array of channel objects
///   (for logo/stream fallback)
/// - `vod_json`: JSON array of VOD item objects
///   (for poster/stream/rating fallback)
/// - `epg_json`: unused (reserved for future)
///
/// Returns JSON of `GroupedResults`.
pub fn group_search_results(
    results_json: &str,
    channels_json: &str,
    vod_json: &str,
    _epg_json: &str,
) -> String {
    let results: Vec<EnrichedResult> = match serde_json::from_str(results_json) {
        Ok(v) => v,
        Err(_) => return default_json(),
    };

    if results.is_empty() {
        return default_json();
    }

    // Build lookup maps.
    let ch_map = build_lookup_map(channels_json);
    let vod_map = build_lookup_map(vod_json);

    let mut grouped = GroupedResults::default();

    for r in &results {
        let meta = r.metadata.as_ref();

        match r.media_type.as_str() {
            "channel" => {
                let ch = ch_map.get(&r.id);
                let item = GroupedItem {
                    id: r.id.clone(),
                    name: r.name.clone(),
                    media_type: "channel".to_string(),
                    logo_url: get_meta_str(meta, "logo_url")
                        .or_else(|| get_field_str(ch, "logo_url")),
                    stream_url: get_meta_str(meta, "stream_url")
                        .or_else(|| get_field_str(ch, "stream_url")),
                    rating: None,
                    year: None,
                    duration_ms: None,
                    overview: None,
                    category: None,
                    source: "iptv".to_string(),
                    epg_entry: None,
                };
                grouped.channels.push(item);
            }
            "movie" => {
                let v = vod_map.get(&r.id);
                let item = build_vod_item(&r.id, &r.name, "movie", meta, v, "iptv_vod");
                grouped.movies.push(item);
            }
            "series" => {
                let v = vod_map.get(&r.id);
                let item = build_vod_item(&r.id, &r.name, "series", meta, v, "iptv_vod");
                grouped.series.push(item);
            }
            "epg" => {
                let ch = ch_map.get(&r.id);
                let entry_val = meta.and_then(|m| m.get("entry").cloned());
                let icon_url = entry_val
                    .as_ref()
                    .and_then(|e| e.get("icon_url").and_then(|v| v.as_str()).map(String::from));
                let title = entry_val
                    .as_ref()
                    .and_then(|e| e.get("title").and_then(|v| v.as_str()).map(String::from))
                    .unwrap_or_else(|| r.name.clone());
                let description = entry_val.as_ref().and_then(|e| {
                    e.get("description")
                        .and_then(|v| v.as_str())
                        .map(String::from)
                });
                let start_time = entry_val.as_ref().and_then(|e| {
                    e.get("start_time")
                        .and_then(|v| v.as_str())
                        .map(String::from)
                });
                let end_time = entry_val
                    .as_ref()
                    .and_then(|e| e.get("end_time").and_then(|v| v.as_str()).map(String::from));
                let dur_ms = compute_duration_ms(start_time.as_deref(), end_time.as_deref());
                let start_ms = parse_iso_ms(start_time.as_deref());
                let epg_id = format!("{}_{}", r.id, start_ms.unwrap_or(0),);

                let item = GroupedItem {
                    id: epg_id,
                    name: title,
                    media_type: "epg".to_string(),
                    logo_url: icon_url
                        .or_else(|| get_meta_str(meta, "logo_url"))
                        .or_else(|| get_field_str(ch, "logo_url")),
                    stream_url: get_meta_str(meta, "stream_url")
                        .or_else(|| get_field_str(ch, "stream_url")),
                    rating: None,
                    year: None,
                    duration_ms: dur_ms,
                    overview: description,
                    category: None,
                    source: "iptv_epg".to_string(),
                    epg_entry: entry_val,
                };
                grouped.epg_programs.push(item);
            }
            _ => {}
        }
    }

    serde_json::to_string(&grouped).unwrap_or_else(|_| default_json())
}

fn default_json() -> String {
    r#"{"channels":[],"movies":[],"series":[],"epg_programs":[]}"#.to_string()
}

fn build_lookup_map(json: &str) -> HashMap<String, HashMap<String, Value>> {
    let items: Vec<HashMap<String, Value>> = serde_json::from_str(json).unwrap_or_default();
    let mut map = HashMap::new();
    for item in items {
        if let Some(id) = item.get("id").and_then(|v| v.as_str()) {
            map.insert(id.to_string(), item);
        }
    }
    map
}

fn get_meta_str(meta: Option<&HashMap<String, Value>>, key: &str) -> Option<String> {
    meta.and_then(|m| m.get(key).and_then(|v| v.as_str()).map(String::from))
}

fn get_meta_i64(meta: Option<&HashMap<String, Value>>, key: &str) -> Option<i64> {
    meta.and_then(|m| m.get(key).and_then(|v| v.as_i64()))
}

fn get_field_str(obj: Option<&HashMap<String, Value>>, key: &str) -> Option<String> {
    obj.and_then(|m| m.get(key).and_then(|v| v.as_str()).map(String::from))
}

fn get_field_i64(obj: Option<&HashMap<String, Value>>, key: &str) -> Option<i64> {
    obj.and_then(|m| m.get(key).and_then(|v| v.as_i64()))
}

fn build_vod_item(
    id: &str,
    name: &str,
    media_type: &str,
    meta: Option<&HashMap<String, Value>>,
    vod: Option<&HashMap<String, Value>>,
    source: &str,
) -> GroupedItem {
    let year = get_meta_i64(meta, "year")
        .or_else(|| get_field_i64(vod, "year"))
        .map(|y| y as i32);
    let poster = get_meta_str(meta, "poster_url")
        .or_else(|| get_field_str(vod, "poster_url"))
        .or_else(|| get_field_str(vod, "backdrop_url"));
    let stream = get_meta_str(meta, "stream_url").or_else(|| get_field_str(vod, "stream_url"));
    let rating = get_meta_str(meta, "rating").or_else(|| get_field_str(vod, "rating"));
    let duration = get_meta_i64(meta, "duration").or_else(|| get_field_i64(vod, "duration"));
    let overview = get_meta_str(meta, "description").or_else(|| get_field_str(vod, "description"));
    let category = get_meta_str(meta, "category").or_else(|| get_field_str(vod, "category"));

    GroupedItem {
        id: id.to_string(),
        name: name.to_string(),
        media_type: media_type.to_string(),
        logo_url: poster,
        stream_url: stream,
        rating,
        year,
        duration_ms: duration,
        overview,
        category,
        source: source.to_string(),
        epg_entry: None,
    }
}

/// Parse ISO-8601 datetime string to milliseconds since
/// epoch. Returns None on parse failure.
fn parse_iso_ms(s: Option<&str>) -> Option<i64> {
    s.and_then(|ts| {
        chrono::NaiveDateTime::parse_from_str(ts, "%Y-%m-%dT%H:%M:%S")
            .or_else(|_| chrono::NaiveDateTime::parse_from_str(ts, EPG_FORMAT))
            .ok()
            .map(|dt| dt.and_utc().timestamp_millis())
    })
}

/// Compute duration in milliseconds between two
/// ISO-8601 timestamps.
fn compute_duration_ms(start: Option<&str>, end: Option<&str>) -> Option<i64> {
    let s = parse_iso_ms(start)?;
    let e = parse_iso_ms(end)?;
    if e > s { Some(e - s) } else { None }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_results() {
        let r = group_search_results("[]", "[]", "[]", "{}");
        let g: GroupedResults = serde_json::from_str(&r).unwrap();
        assert!(g.channels.is_empty());
        assert!(g.movies.is_empty());
        assert!(g.series.is_empty());
        assert!(g.epg_programs.is_empty());
    }

    #[test]
    fn invalid_json() {
        let r = group_search_results("bad", "[]", "[]", "{}");
        let g: GroupedResults = serde_json::from_str(&r).unwrap();
        assert!(g.channels.is_empty());
    }

    #[test]
    fn groups_channels() {
        let results = r#"[
            {"id":"ch1","name":"Test Channel","media_type":"channel","metadata":{"logo_url":"http://logo.png","stream_url":"http://stream"}}
        ]"#;
        let r = group_search_results(results, "[]", "[]", "{}");
        let g: GroupedResults = serde_json::from_str(&r).unwrap();
        assert_eq!(g.channels.len(), 1);
        assert_eq!(g.channels[0].id, "ch1");
        assert_eq!(g.channels[0].source, "iptv");
        assert_eq!(g.channels[0].logo_url.as_deref(), Some("http://logo.png"));
    }

    #[test]
    fn groups_movies() {
        let results = r#"[
            {"id":"m1","name":"Test Movie","media_type":"movie","metadata":{"year":2024,"rating":"8.5"}}
        ]"#;
        let r = group_search_results(results, "[]", "[]", "{}");
        let g: GroupedResults = serde_json::from_str(&r).unwrap();
        assert_eq!(g.movies.len(), 1);
        assert_eq!(g.movies[0].year, Some(2024));
        assert_eq!(g.movies[0].rating.as_deref(), Some("8.5"));
    }

    #[test]
    fn groups_series() {
        let results = r#"[
            {"id":"s1","name":"Test Series","media_type":"series","metadata":{}}
        ]"#;
        let r = group_search_results(results, "[]", "[]", "{}");
        let g: GroupedResults = serde_json::from_str(&r).unwrap();
        assert_eq!(g.series.len(), 1);
        assert_eq!(g.series[0].source, "iptv_vod");
    }

    #[test]
    fn groups_epg() {
        let results = r#"[
            {"id":"ch1","name":"Channel","media_type":"epg","metadata":{"entry":{"title":"News","description":"Evening News","start_time":"2024-03-01T18:00:00","end_time":"2024-03-01T19:00:00"}}}
        ]"#;
        let r = group_search_results(results, "[]", "[]", "{}");
        let g: GroupedResults = serde_json::from_str(&r).unwrap();
        assert_eq!(g.epg_programs.len(), 1);
        assert_eq!(g.epg_programs[0].name, "News");
        assert_eq!(g.epg_programs[0].overview.as_deref(), Some("Evening News"));
        assert_eq!(g.epg_programs[0].duration_ms, Some(3600000));
        assert_eq!(g.epg_programs[0].source, "iptv_epg");
    }

    #[test]
    fn mixed_types() {
        let results = r#"[
            {"id":"ch1","name":"Ch1","media_type":"channel","metadata":{}},
            {"id":"m1","name":"Movie1","media_type":"movie","metadata":{}},
            {"id":"s1","name":"Series1","media_type":"series","metadata":{}},
            {"id":"ch2","name":"Ch2","media_type":"epg","metadata":{"entry":{"title":"Show","start_time":"2024-01-01T00:00:00","end_time":"2024-01-01T01:00:00"}}}
        ]"#;
        let r = group_search_results(results, "[]", "[]", "{}");
        let g: GroupedResults = serde_json::from_str(&r).unwrap();
        assert_eq!(g.channels.len(), 1);
        assert_eq!(g.movies.len(), 1);
        assert_eq!(g.series.len(), 1);
        assert_eq!(g.epg_programs.len(), 1);
    }

    #[test]
    fn channel_fallback_metadata() {
        let results = r#"[
            {"id":"ch1","name":"Test","media_type":"channel","metadata":{}}
        ]"#;
        let channels = r#"[
            {"id":"ch1","logo_url":"http://fallback.png","stream_url":"http://fallback"}
        ]"#;
        let r = group_search_results(results, channels, "[]", "{}");
        let g: GroupedResults = serde_json::from_str(&r).unwrap();
        assert_eq!(
            g.channels[0].logo_url.as_deref(),
            Some("http://fallback.png")
        );
        assert_eq!(g.channels[0].stream_url.as_deref(), Some("http://fallback"));
    }

    #[test]
    fn vod_fallback_metadata() {
        let results = r#"[
            {"id":"v1","name":"Movie","media_type":"movie","metadata":{}}
        ]"#;
        let vod = r#"[
            {"id":"v1","poster_url":"http://poster.jpg","rating":"7.5","year":2023,"description":"A great movie","category":"Action"}
        ]"#;
        let r = group_search_results(results, "[]", vod, "{}");
        let g: GroupedResults = serde_json::from_str(&r).unwrap();
        assert_eq!(g.movies[0].logo_url.as_deref(), Some("http://poster.jpg"));
        assert_eq!(g.movies[0].rating.as_deref(), Some("7.5"));
        assert_eq!(g.movies[0].year, Some(2023));
        assert_eq!(g.movies[0].overview.as_deref(), Some("A great movie"));
        assert_eq!(g.movies[0].category.as_deref(), Some("Action"));
    }

    #[test]
    fn meta_overrides_fallback() {
        let results = r#"[
            {"id":"v1","name":"Movie","media_type":"movie","metadata":{"poster_url":"http://meta.jpg","rating":"9.0"}}
        ]"#;
        let vod = r#"[
            {"id":"v1","poster_url":"http://fallback.jpg","rating":"7.5"}
        ]"#;
        let r = group_search_results(results, "[]", vod, "{}");
        let g: GroupedResults = serde_json::from_str(&r).unwrap();
        assert_eq!(g.movies[0].logo_url.as_deref(), Some("http://meta.jpg"));
        assert_eq!(g.movies[0].rating.as_deref(), Some("9.0"));
    }
}
