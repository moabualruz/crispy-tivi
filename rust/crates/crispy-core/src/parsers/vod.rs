//! VOD JSON parser for Xtream Codes and M3U sources.
//!
//! Ported from Dart `vod_parser.dart`. Pure functions,
//! no DB access.

use std::sync::LazyLock;

use percent_encoding::{NON_ALPHANUMERIC, utf8_percent_encode};
use regex::Regex;
use serde_json::Value;

use crate::models::VodItem;

static RE_YEAR: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"(\d{4})").unwrap());

/// Percent-encode a credential value for safe URL path
/// interpolation.
fn encode_credential(value: &str) -> String {
    utf8_percent_encode(value, NON_ALPHANUMERIC).to_string()
}

/// Parse Xtream `get_vod_streams` JSON into movies.
///
/// Each JSON object is mapped to a [`VodItem`] with
/// `item_type = "movie"`. Stream URL is built from the
/// base URL, credentials, and stream ID.
pub fn parse_vod_streams(
    data: &[Value],
    base_url: &str,
    username: &str,
    password: &str,
    source_id: Option<&str>,
) -> Vec<VodItem> {
    let mut dropped = 0;
    let items: Vec<VodItem> = data
        .iter()
        .filter_map(|item| {
            let map = match item.as_object() {
                Some(m) => m,
                None => {
                    dropped += 1;
                    return None;
                }
            };
            let stream_id = match map.get("stream_id") {
                Some(id) => id,
                None => {
                    dropped += 1;
                    return None;
                }
            };
            let ext = map
                .get("container_extension")
                .and_then(Value::as_str)
                .unwrap_or("mp4");
            let name = map.get("name").and_then(Value::as_str).unwrap_or("Unknown");

            let enc_user = encode_credential(username);
            let enc_pass = encode_credential(password);
            let stream_url = format!(
                "{}/movie/{}/{}/{}.{}",
                base_url, enc_user, enc_pass, stream_id, ext,
            );

            let year = parse_year(map.get("releasedate").or_else(|| map.get("year")));

            Some(VodItem {
                id: format!("vod_{}", stream_id),
                name: name.to_string(),
                stream_url,
                item_type: "movie".to_string(),
                poster_url: map
                    .get("stream_icon")
                    .and_then(Value::as_str)
                    .map(String::from),
                backdrop_url: None,
                description: None,
                rating: map.get("rating").map(|v| {
                    v.as_str()
                        .map(String::from)
                        .unwrap_or_else(|| v.to_string())
                }),
                year,
                duration: None,
                category: map.get("category_id").map(|v| {
                    v.as_str()
                        .map(String::from)
                        .unwrap_or_else(|| v.to_string())
                }),
                series_id: None,
                season_number: None,
                episode_number: None,
                ext: Some(ext.to_string()),
                is_favorite: false,
                added_at: None,
                updated_at: None,
                source_id: source_id.map(String::from),
            })
        })
        .collect();

    if dropped > 0 {
        println!(
            "parse_vod_streams: Dropped {} items out of {}",
            dropped,
            data.len()
        );
    }
    items
}

/// Parse Xtream `get_series` JSON into series
/// containers.
///
/// Each JSON object is mapped to a [`VodItem`] with
/// `item_type = "series"`.
pub fn parse_series(data: &[Value], source_id: Option<&str>) -> Vec<VodItem> {
    let mut dropped = 0;
    let items: Vec<VodItem> = data
        .iter()
        .filter_map(|item| {
            let map = match item.as_object() {
                Some(m) => m,
                None => {
                    dropped += 1;
                    return None;
                }
            };
            let series_id = match map.get("series_id") {
                Some(id) => id,
                None => {
                    println!("Series Drop: Missing series_id: {:?}", map);
                    dropped += 1;
                    return None;
                }
            };
            let name = map.get("name").and_then(Value::as_str).unwrap_or("Unknown");

            let backdrop_url = match map.get("backdrop_path") {
                Some(Value::Array(arr)) => arr.first().and_then(Value::as_str).map(String::from),
                Some(Value::String(s)) => Some(s.clone()),
                _ => None,
            };

            let year = parse_year(map.get("releaseDate").or_else(|| map.get("year")));

            Some(VodItem {
                id: format!("series_{}", series_id),
                name: name.to_string(),
                stream_url: String::new(),
                item_type: "series".to_string(),
                poster_url: map.get("cover").and_then(Value::as_str).map(String::from),
                backdrop_url,
                description: map.get("plot").and_then(Value::as_str).map(String::from),
                rating: map.get("rating").map(|v| {
                    v.as_str()
                        .map(String::from)
                        .unwrap_or_else(|| v.to_string())
                }),
                year,
                duration: None,
                category: map.get("category_id").map(|v| {
                    v.as_str()
                        .map(String::from)
                        .unwrap_or_else(|| v.to_string())
                }),
                series_id: None,
                season_number: None,
                episode_number: None,
                ext: None,
                is_favorite: false,
                added_at: None,
                updated_at: None,
                source_id: source_id.map(String::from),
            })
        })
        .collect();

    if dropped > 0 {
        println!(
            "parse_series: Dropped {} items out of {}",
            dropped,
            data.len()
        );
    }
    items
}

/// Parse Xtream `get_series_info` episodes JSON.
///
/// The `episodes` field is a map keyed by season
/// number, each value an array of episode objects.
pub fn parse_episodes(
    series_info: &Value,
    base_url: &str,
    username: &str,
    password: &str,
    series_id: &str,
) -> Vec<VodItem> {
    let mut episodes = Vec::new();

    let episodes_data = match series_info.get("episodes") {
        Some(Value::Object(map)) => map,
        _ => return episodes,
    };

    for (season_key, season_eps) in episodes_data {
        let season_num: i32 = season_key.parse().unwrap_or(0);
        let ep_list = match season_eps.as_array() {
            Some(arr) => arr,
            None => continue,
        };

        for ep in ep_list {
            let map = match ep.as_object() {
                Some(m) => m,
                None => continue,
            };

            let ep_id = map
                .get("id")
                .map(|v| {
                    v.as_str()
                        .map(String::from)
                        .unwrap_or_else(|| v.to_string())
                })
                .unwrap_or_default();

            let ext = map
                .get("container_extension")
                .and_then(Value::as_str)
                .unwrap_or("mkv");

            let title = map
                .get("title")
                .and_then(Value::as_str)
                .unwrap_or("Episode");

            let enc_user = encode_credential(username);
            let enc_pass = encode_credential(password);
            let stream_url = format!(
                "{}/series/{}/{}/{}.{}",
                base_url, enc_user, enc_pass, ep_id, ext,
            );

            let episode_number = map.get("episode_num").and_then(|v| {
                v.as_i64()
                    .map(|n| n as i32)
                    .or_else(|| v.as_str().and_then(|s| s.parse().ok()))
            });

            let info = map.get("info").and_then(Value::as_object);

            let poster_url = info
                .and_then(|i| i.get("movie_image"))
                .and_then(Value::as_str)
                .map(String::from);

            let description = info
                .and_then(|i| i.get("plot"))
                .and_then(Value::as_str)
                .map(String::from);

            let duration = info
                .and_then(|i| i.get("duration_secs"))
                .and_then(Value::as_i64)
                .map(|s| (s / 60) as i32);

            episodes.push(VodItem {
                id: format!("ep_{}_{}", series_id, ep_id,),
                name: title.to_string(),
                stream_url,
                item_type: "episode".to_string(),
                poster_url,
                backdrop_url: None,
                description,
                rating: None,
                year: None,
                duration,
                category: None,
                series_id: Some(format!("series_{}", series_id,)),
                season_number: Some(season_num),
                episode_number,
                ext: Some(ext.to_string()),
                is_favorite: false,
                added_at: None,
                updated_at: None,
                source_id: None,
            });
        }
    }

    episodes
}

/// Parse VOD entries from M3U channel data.
///
/// Filters by file extension (mp4, mkv, avi, etc.)
/// or group containing "vod"/"movie"/"film".
pub fn parse_m3u_vod(channels: &[Value], source_id: Option<&str>) -> Vec<VodItem> {
    let vod_exts: &[&str] = &["mp4", "mkv", "avi", "mov", "wmv", "flv", "ts"];

    channels
        .iter()
        .filter_map(|ch| {
            let map = ch.as_object()?;
            let url = map
                .get("streamUrl")
                .or_else(|| map.get("stream_url"))
                .and_then(Value::as_str)
                .unwrap_or("");

            let ext = url.rsplit('.').next().unwrap_or("").to_lowercase();

            let group = map
                .get("group")
                .or_else(|| map.get("channel_group"))
                .and_then(Value::as_str)
                .unwrap_or("")
                .to_lowercase();

            let is_vod = vod_exts.contains(&ext.as_str())
                || group.contains("vod")
                || group.contains("movie")
                || group.contains("film");

            if !is_vod {
                return None;
            }

            let name = map.get("name").and_then(Value::as_str).unwrap_or("Unknown");

            let poster_url = map
                .get("logoUrl")
                .or_else(|| map.get("logo_url"))
                .and_then(Value::as_str)
                .map(String::from);

            let category = map
                .get("group")
                .or_else(|| map.get("channel_group"))
                .and_then(Value::as_str)
                .map(String::from);

            // Stable ID from URL hash.
            let id = format!("mvod_{:x}", simple_hash(url),);

            Some(VodItem {
                id,
                name: name.to_string(),
                stream_url: url.to_string(),
                item_type: "movie".to_string(),
                poster_url,
                backdrop_url: None,
                description: None,
                rating: None,
                year: None,
                duration: None,
                category,
                series_id: None,
                season_number: None,
                episode_number: None,
                ext: Some(ext),
                is_favorite: false,
                added_at: None,
                updated_at: None,
                source_id: source_id.map(String::from),
            })
        })
        .collect()
}

// ── Helpers ──────────────────────────────────────

/// Parse a year from a JSON value (int or date string).
fn parse_year(value: Option<&Value>) -> Option<i32> {
    let v = value?;
    if let Some(n) = v.as_i64() {
        return Some(n as i32);
    }
    if let Some(s) = v.as_str()
        && let Some(cap) = RE_YEAR.captures(s)
    {
        return cap.get(1).and_then(|m| m.as_str().parse().ok());
    }
    None
}

/// Simple hash for stable IDs (mirrors Dart hashCode
/// usage).
fn simple_hash(s: &str) -> u64 {
    use std::hash::{DefaultHasher, Hash, Hasher};
    let mut h = DefaultHasher::new();
    s.hash(&mut h);
    h.finish()
}

// ── Tests ────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn parse_vod_streams_basic() {
        let data = vec![
            json!({
                "stream_id": 101,
                "name": "Inception",
                "stream_icon": "http://img/inception.jpg",
                "container_extension": "mkv",
                "category_id": "5",
                "rating": "8.8",
                "releasedate": "2010-07-16",
            }),
            json!({
                "stream_id": 102,
                "name": "Avatar",
                "container_extension": "mp4",
                "year": 2009,
            }),
        ];

        let items = parse_vod_streams(
            &data,
            "http://api.example.com",
            "user1",
            "pass1",
            Some("src_1"),
        );

        assert_eq!(items.len(), 2);

        let i0 = &items[0];
        assert_eq!(i0.id, "vod_101");
        assert_eq!(i0.name, "Inception");
        assert_eq!(i0.item_type, "movie");
        assert_eq!(
            i0.stream_url,
            "http://api.example.com/movie/user1/pass1/101.mkv",
        );
        assert_eq!(i0.poster_url.as_deref(), Some("http://img/inception.jpg"),);
        assert_eq!(i0.year, Some(2010));
        assert_eq!(i0.source_id.as_deref(), Some("src_1"),);

        let i1 = &items[1];
        assert_eq!(i1.id, "vod_102");
        assert_eq!(i1.year, Some(2009));
    }

    #[test]
    fn parse_series_with_backdrop_list() {
        let data = vec![json!({
            "series_id": 200,
            "name": "Breaking Bad",
            "cover": "http://img/bb.jpg",
            "backdrop_path": [
                "http://img/bb_bg1.jpg",
                "http://img/bb_bg2.jpg"
            ],
            "plot": "A chemistry teacher turns to crime.",
            "rating": "9.5",
            "releaseDate": "2008-01-20",
            "category_id": "3",
        })];

        let items = parse_series(&data, None);
        assert_eq!(items.len(), 1);

        let s = &items[0];
        assert_eq!(s.id, "series_200");
        assert_eq!(s.item_type, "series");
        assert_eq!(s.backdrop_url.as_deref(), Some("http://img/bb_bg1.jpg"),);
        assert_eq!(
            s.description.as_deref(),
            Some("A chemistry teacher turns to crime."),
        );
        assert_eq!(s.year, Some(2008));
    }

    #[test]
    fn parse_series_with_backdrop_string() {
        let data = vec![json!({
            "series_id": 201,
            "name": "Dexter",
            "cover": "http://img/d.jpg",
            "backdrop_path": "http://img/d_bg.jpg",
        })];

        let items = parse_series(&data, None);
        assert_eq!(
            items[0].backdrop_url.as_deref(),
            Some("http://img/d_bg.jpg"),
        );
    }

    #[test]
    fn parse_episodes_basic() {
        let info = json!({
            "episodes": {
                "1": [
                    {
                        "id": "501",
                        "title": "Pilot",
                        "episode_num": 1,
                        "container_extension": "mkv",
                        "info": {
                            "movie_image": "http://img/pilot.jpg",
                            "plot": "The beginning.",
                            "duration_secs": 3600,
                        },
                    },
                    {
                        "id": "502",
                        "title": "Cat's in the Bag",
                        "episode_num": 2,
                        "container_extension": "mp4",
                    }
                ],
                "2": [
                    {
                        "id": "601",
                        "title": "Seven Thirty-Seven",
                        "episode_num": 1,
                    }
                ]
            }
        });

        let eps = parse_episodes(&info, "http://api.example.com", "user1", "pass1", "200");

        assert_eq!(eps.len(), 3);

        let e0 = &eps[0];
        assert_eq!(e0.id, "ep_200_501");
        assert_eq!(e0.name, "Pilot");
        assert_eq!(e0.item_type, "episode");
        assert_eq!(e0.series_id.as_deref(), Some("series_200"),);
        assert_eq!(e0.season_number, Some(1));
        assert_eq!(e0.episode_number, Some(1));
        assert_eq!(e0.duration, Some(60));
        assert_eq!(
            e0.stream_url,
            "http://api.example.com/series/user1/pass1/501.mkv",
        );

        let e2 = &eps[2];
        assert_eq!(e2.season_number, Some(2));
        assert_eq!(e2.ext.as_deref(), Some("mkv")); // default
    }

    #[test]
    fn parse_m3u_vod_basic() {
        let channels = vec![
            json!({
                "name": "Big Movie",
                "streamUrl": "http://s.example.com/big.mp4",
                "group": "VOD Movies",
                "logoUrl": "http://img/big.jpg",
            }),
            json!({
                "name": "Live Channel",
                "streamUrl": "http://s.example.com/live",
                "group": "News",
            }),
            json!({
                "name": "Film Classic",
                "streamUrl": "http://s.example.com/classic",
                "group": "Film Archive",
            }),
        ];

        let items = parse_m3u_vod(&channels, Some("src_2"));

        // "Big Movie" matches .mp4 extension.
        // "Live Channel" is skipped (no VOD ext/group).
        // "Film Classic" matches "film" in group.
        assert_eq!(items.len(), 2);
        assert_eq!(items[0].name, "Big Movie");
        assert_eq!(items[0].item_type, "movie");
        assert_eq!(items[0].source_id.as_deref(), Some("src_2"),);
        assert_eq!(items[1].name, "Film Classic");
    }

    #[test]
    fn parse_year_variants() {
        assert_eq!(parse_year(Some(&json!(2024))), Some(2024),);
        assert_eq!(parse_year(Some(&json!("2010-07-16"))), Some(2010),);
        assert_eq!(parse_year(Some(&json!("2024"))), Some(2024),);
        assert_eq!(parse_year(Some(&json!("none"))), None);
        assert_eq!(parse_year(None), None);
    }

    // ── Additional VOD tests ─────────────────────────

    #[test]
    fn parse_vod_streams_single_all_fields() {
        let data = vec![json!({
            "stream_id": 42,
            "name": "The Matrix",
            "stream_icon": "http://img/matrix.jpg",
            "container_extension": "avi",
            "category_id": "10",
            "rating": "8.7",
            "releasedate": "1999-03-31",
        })];

        let items = parse_vod_streams(&data, "http://srv.test", "neo", "trinity", Some("src_x"));

        assert_eq!(items.len(), 1);
        let m = &items[0];
        assert_eq!(m.id, "vod_42");
        assert_eq!(m.name, "The Matrix");
        assert_eq!(m.item_type, "movie");
        assert_eq!(m.stream_url, "http://srv.test/movie/neo/trinity/42.avi",);
        assert_eq!(m.poster_url.as_deref(), Some("http://img/matrix.jpg"),);
        assert_eq!(m.rating.as_deref(), Some("8.7"));
        assert_eq!(m.year, Some(1999));
        assert_eq!(m.category.as_deref(), Some("10"));
        assert_eq!(m.ext.as_deref(), Some("avi"));
        assert_eq!(m.source_id.as_deref(), Some("src_x"));
        assert!(!m.is_favorite);
        assert!(m.backdrop_url.is_none());
        assert!(m.description.is_none());
        assert!(m.duration.is_none());
        assert!(m.series_id.is_none());
        assert!(m.season_number.is_none());
        assert!(m.episode_number.is_none());
    }

    #[test]
    fn parse_vod_streams_missing_optional_fields() {
        let data = vec![json!({
            "stream_id": 77,
        })];

        let items = parse_vod_streams(&data, "http://srv.test", "u", "p", None);

        assert_eq!(items.len(), 1);
        let m = &items[0];
        assert_eq!(m.id, "vod_77");
        assert_eq!(m.name, "Unknown");
        // Default extension is mp4.
        assert_eq!(m.stream_url, "http://srv.test/movie/u/p/77.mp4",);
        assert_eq!(m.ext.as_deref(), Some("mp4"));
        assert!(m.poster_url.is_none());
        assert!(m.rating.is_none());
        assert!(m.year.is_none());
        assert!(m.category.is_none());
        assert!(m.source_id.is_none());
    }

    #[test]
    fn parse_vod_streams_empty_array() {
        let items = parse_vod_streams(&[], "http://srv.test", "u", "p", None);
        assert!(items.is_empty());
    }

    #[test]
    fn parse_vod_streams_skips_missing_stream_id() {
        let data = vec![
            json!({ "name": "No ID" }),
            json!({ "stream_id": 1, "name": "Has ID" }),
        ];

        let items = parse_vod_streams(&data, "http://srv.test", "u", "p", None);

        assert_eq!(items.len(), 1);
        assert_eq!(items[0].name, "Has ID");
    }

    #[test]
    fn parse_series_basic_single() {
        let data = vec![json!({
            "series_id": 300,
            "name": "The Wire",
            "cover": "http://img/wire.jpg",
            "plot": "Baltimore drug scene.",
            "rating": "9.3",
            "releaseDate": "2002-06-02",
            "category_id": "7",
        })];

        let items = parse_series(&data, Some("src_s"));

        assert_eq!(items.len(), 1);
        let s = &items[0];
        assert_eq!(s.id, "series_300");
        assert_eq!(s.name, "The Wire");
        assert_eq!(s.item_type, "series");
        assert!(s.stream_url.is_empty());
        assert_eq!(s.poster_url.as_deref(), Some("http://img/wire.jpg"),);
        assert_eq!(s.description.as_deref(), Some("Baltimore drug scene."),);
        assert_eq!(s.rating.as_deref(), Some("9.3"));
        assert_eq!(s.year, Some(2002));
        assert_eq!(s.category.as_deref(), Some("7"));
        assert_eq!(s.source_id.as_deref(), Some("src_s"));
        assert!(s.backdrop_url.is_none());
    }

    #[test]
    fn parse_series_missing_optional_fields() {
        let data = vec![json!({
            "series_id": 301,
        })];

        let items = parse_series(&data, None);

        assert_eq!(items.len(), 1);
        let s = &items[0];
        assert_eq!(s.id, "series_301");
        assert_eq!(s.name, "Unknown");
        assert!(s.poster_url.is_none());
        assert!(s.backdrop_url.is_none());
        assert!(s.description.is_none());
        assert!(s.rating.is_none());
        assert!(s.year.is_none());
        assert!(s.category.is_none());
        assert!(s.source_id.is_none());
    }

    #[test]
    fn parse_episodes_with_info_block() {
        let info = json!({
            "episodes": {
                "3": [
                    {
                        "id": "901",
                        "title": "Finale",
                        "episode_num": 10,
                        "container_extension": "mp4",
                        "info": {
                            "movie_image": "http://img/fin.jpg",
                            "plot": "It all ends here.",
                            "duration_secs": 5400,
                        },
                    }
                ]
            }
        });

        let eps = parse_episodes(&info, "http://api.test", "u", "p", "500");

        assert_eq!(eps.len(), 1);
        let e = &eps[0];
        assert_eq!(e.id, "ep_500_901");
        assert_eq!(e.name, "Finale");
        assert_eq!(e.item_type, "episode");
        assert_eq!(e.stream_url, "http://api.test/series/u/p/901.mp4",);
        assert_eq!(e.series_id.as_deref(), Some("series_500"));
        assert_eq!(e.season_number, Some(3));
        assert_eq!(e.episode_number, Some(10));
        assert_eq!(e.duration, Some(90)); // 5400/60
        assert_eq!(e.poster_url.as_deref(), Some("http://img/fin.jpg"),);
        assert_eq!(e.description.as_deref(), Some("It all ends here."),);
        assert_eq!(e.ext.as_deref(), Some("mp4"));
    }

    #[test]
    fn parse_episodes_empty_seasons() {
        // No "episodes" key at all.
        let info = json!({});
        let eps = parse_episodes(&info, "http://api.test", "u", "p", "1");
        assert!(eps.is_empty());

        // Episodes key present but not an object.
        let info2 = json!({ "episodes": null });
        let eps2 = parse_episodes(&info2, "http://api.test", "u", "p", "1");
        assert!(eps2.is_empty());

        // Episodes object with an empty array season.
        let info3 = json!({ "episodes": { "1": [] } });
        let eps3 = parse_episodes(&info3, "http://api.test", "u", "p", "1");
        assert!(eps3.is_empty());
    }

    #[test]
    fn parse_episodes_string_episode_num() {
        let info = json!({
            "episodes": {
                "1": [{
                    "id": "801",
                    "title": "Ep",
                    "episode_num": "5",
                }]
            }
        });

        let eps = parse_episodes(&info, "http://api.test", "u", "p", "99");

        assert_eq!(eps.len(), 1);
        assert_eq!(eps[0].episode_number, Some(5));
    }

    #[test]
    fn parse_m3u_vod_filters_by_extension() {
        let channels = vec![
            json!({
                "name": "MKV Movie",
                "streamUrl": "http://s.test/a.mkv",
                "group": "General",
            }),
            json!({
                "name": "AVI Classic",
                "streamUrl": "http://s.test/b.avi",
                "group": "General",
            }),
            json!({
                "name": "Live Stream",
                "streamUrl": "http://s.test/live",
                "group": "General",
            }),
        ];

        let items = parse_m3u_vod(&channels, None);

        assert_eq!(items.len(), 2);
        assert_eq!(items[0].name, "MKV Movie");
        assert_eq!(items[0].ext.as_deref(), Some("mkv"));
        assert_eq!(items[1].name, "AVI Classic");
        assert_eq!(items[1].ext.as_deref(), Some("avi"));
    }

    #[test]
    fn parse_m3u_vod_filters_by_group_keywords() {
        let channels = vec![
            json!({
                "name": "Action Flick",
                "streamUrl": "http://s.test/act",
                "group": "VOD Action",
            }),
            json!({
                "name": "Drama Film",
                "streamUrl": "http://s.test/drama",
                "group": "Film Drama",
            }),
            json!({
                "name": "Cinema Movie",
                "streamUrl": "http://s.test/cin",
                "group": "Movie Night",
            }),
            json!({
                "name": "News Live",
                "streamUrl": "http://s.test/news",
                "group": "News",
            }),
        ];

        let items = parse_m3u_vod(&channels, None);

        // "VOD Action" matches "vod", "Film Drama" matches
        // "film", "Movie Night" matches "movie". "News" has
        // no VOD keyword.
        assert_eq!(items.len(), 3);
        assert_eq!(items[0].name, "Action Flick");
        assert_eq!(items[1].name, "Drama Film");
        assert_eq!(items[2].name, "Cinema Movie");
    }

    #[test]
    fn parse_m3u_vod_alternate_field_names() {
        let channels = vec![json!({
            "name": "Alt Fields",
            "stream_url": "http://s.test/alt.mp4",
            "channel_group": "VOD Alt",
            "logo_url": "http://img/alt.png",
        })];

        let items = parse_m3u_vod(&channels, Some("src_a"));

        assert_eq!(items.len(), 1);
        let v = &items[0];
        assert_eq!(v.name, "Alt Fields");
        assert_eq!(v.stream_url, "http://s.test/alt.mp4");
        assert_eq!(v.poster_url.as_deref(), Some("http://img/alt.png"),);
        assert_eq!(v.category.as_deref(), Some("VOD Alt"),);
        assert_eq!(v.source_id.as_deref(), Some("src_a"));
        assert_eq!(v.item_type, "movie");
    }

    #[test]
    fn parse_m3u_vod_empty_input() {
        let items = parse_m3u_vod(&[], None);
        assert!(items.is_empty());
    }

    #[test]
    fn parse_vod_streams_rating_numeric() {
        let data = vec![json!({
            "stream_id": 55,
            "rating": 7.5,
        })];

        let items = parse_vod_streams(&data, "http://s", "u", "p", None);

        assert_eq!(items.len(), 1);
        // Numeric rating is converted to string.
        assert_eq!(items[0].rating.as_deref(), Some("7.5"));
    }

    #[test]
    fn parse_vod_streams_year_from_year_field() {
        let data = vec![json!({
            "stream_id": 60,
            "year": 2023,
        })];

        let items = parse_vod_streams(&data, "http://s", "u", "p", None);

        assert_eq!(items[0].year, Some(2023));
    }

    #[test]
    fn parse_m3u_vod_stable_id() {
        let channels = vec![json!({
            "name": "Movie A",
            "streamUrl": "http://s.test/movie_a.mp4",
            "group": "General",
        })];

        let items1 = parse_m3u_vod(&channels, None);
        let items2 = parse_m3u_vod(&channels, None);

        // Same URL produces same stable ID.
        assert_eq!(items1[0].id, items2[0].id);
        assert!(items1[0].id.starts_with("mvod_"));
    }

    // ── SEC-05: Credential encoding tests ────────

    #[test]
    fn parse_vod_streams_encodes_special_credentials() {
        let data = vec![json!({
            "stream_id": 1,
            "container_extension": "mp4",
        })];

        let items = parse_vod_streams(&data, "http://api.test", "user@host", "p@ss/word#1?x", None);

        assert_eq!(items.len(), 1);
        let url = &items[0].stream_url;
        // '@', '/', '#', '?' must be percent-encoded.
        assert!(!url.contains("user@host"), "username '@' must be encoded",);
        assert!(url.contains("user%40host"), "username '@' should be %40",);
        assert!(
            !url.contains("p@ss/word#1?x"),
            "password special chars must be encoded",
        );
        assert!(
            url.contains("p%40ss%2Fword%231%3Fx"),
            "password special chars should be percent-encoded",
        );
    }

    #[test]
    fn parse_episodes_encodes_special_credentials() {
        let info = json!({
            "episodes": {
                "1": [{
                    "id": "10",
                    "title": "Ep",
                    "container_extension": "mkv",
                }]
            }
        });

        let eps = parse_episodes(&info, "http://api.test", "user/name", "pass?word", "1");

        assert_eq!(eps.len(), 1);
        let url = &eps[0].stream_url;
        assert!(
            !url.contains("user/name/pass?word"),
            "credentials with / and ? must be encoded",
        );
        assert!(url.contains("user%2Fname"), "/ in username should be %2F",);
        assert!(url.contains("pass%3Fword"), "? in password should be %3F",);
    }
}
