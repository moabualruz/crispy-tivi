//! Algorithm command handler tests.

use chrono::Utc;
use serde_json::json;

use super::{make_svc, send};

// ── Algorithm Commands ────────────────────────────

#[test]
fn normalize_channel_name() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "normalizeChannelName",
            "id": "r1",
            "args": {"name": "  CNN  HD  "},
        }),
    );
    let result = resp["data"].as_str().unwrap();
    assert!(!result.is_empty());
}

#[test]
fn normalize_stream_url() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "normalizeStreamUrl",
            "id": "r1",
            "args": {
                "url": "http://Example.COM/stream",
            },
        }),
    );
    assert!(resp["data"].is_string());
}

#[test]
fn try_base64_decode() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "tryBase64Decode",
            "id": "r1",
            "args": {"input": "aGVsbG8="},
        }),
    );
    assert!(resp["data"].is_string());
}

#[test]
fn hash_and_verify_pin() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "hashPin",
            "id": "r1",
            "args": {"pin": "1234"},
        }),
    );
    let hash = resp["data"].as_str().unwrap().to_string();

    let resp = send(
        &svc,
        &json!({
            "cmd": "verifyPin",
            "id": "r2",
            "args": {
                "inputPin": "1234",
                "storedHash": hash,
            },
        }),
    );
    assert_eq!(resp["data"], true);

    let resp = send(
        &svc,
        &json!({
            "cmd": "verifyPin",
            "id": "r3",
            "args": {
                "inputPin": "9999",
                "storedHash": hash,
            },
        }),
    );
    assert_eq!(resp["data"], false);
}

#[test]
fn is_hashed_pin() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "isHashedPin",
            "id": "r1",
            "args": {"value": "1234"},
        }),
    );
    // Raw "1234" is not a hashed pin.
    assert_eq!(resp["data"], false);
}

#[test]
fn validate_mac_address() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "validateMacAddress",
            "id": "r1",
            "args": {"mac": "00:1A:2B:3C:4D:5E"},
        }),
    );
    assert_eq!(resp["data"], true);

    let resp = send(
        &svc,
        &json!({
            "cmd": "validateMacAddress",
            "id": "r2",
            "args": {"mac": "invalid"},
        }),
    );
    assert_eq!(resp["data"], false);
}

#[test]
fn mac_to_device_id() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "macToDeviceId",
            "id": "r1",
            "args": {"mac": "00:1A:2B:3C:4D:5E"},
        }),
    );
    assert!(resp["data"].is_string());
}

#[test]
fn sanitize_filename() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "sanitizeFilename",
            "id": "r1",
            "args": {"name": "My/File:Name?.mp4"},
        }),
    );
    let result = resp["data"].as_str().unwrap();
    assert!(!result.contains('/'));
    assert!(!result.contains(':'));
    assert!(!result.contains('?'));
}

#[test]
fn format_epg_time() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "formatEpgTime",
            "id": "r1",
            "args": {
                "timestampMs": 1717200000000_i64,
                "offsetHours": 0.0,
            },
        }),
    );
    assert!(resp["data"].is_string());
}

#[test]
fn format_epg_datetime() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "formatEpgDatetime",
            "id": "r1",
            "args": {
                "timestampMs": 1717200000000_i64,
                "offsetHours": 2.0,
            },
        }),
    );
    assert!(resp["data"].is_string());
}

#[test]
fn format_duration_minutes() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "formatDurationMinutes",
            "id": "r1",
            "args": {"minutes": 125},
        }),
    );
    let result = resp["data"].as_str().unwrap();
    assert!(result.contains("2h"));
}

#[test]
fn duration_between_ms() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "durationBetweenMs",
            "id": "r1",
            "args": {
                "startMs": 1000,
                "endMs": 61000,
            },
        }),
    );
    // Returns i32 (minutes), not a string.
    assert!(resp["data"].is_number());
    assert_eq!(resp["data"], 1);
}

#[test]
fn detect_duplicate_channels() {
    let svc = make_svc();
    let channels = json!([
        {"id": "c1", "name": "CNN",
         "stream_url": "http://x/1"},
        {"id": "c2", "name": "CNN",
         "stream_url": "http://x/1"},
    ]);
    let resp = send(
        &svc,
        &json!({
            "cmd": "detectDuplicateChannels",
            "id": "r1",
            "args": {
                "json": serde_json::to_string(
                    &channels
                ).unwrap(),
            },
        }),
    );
    assert!(resp["data"].is_array());
}

#[test]
fn filter_and_sort_vod_items() {
    let svc = make_svc();
    let items = json!([
        {
            "id": "v1",
            "name": "Zulu Movie",
            "stream_url": "http://x/1",
            "type": "movie",
            "category": "Drama",
            "description": "quiet film",
            "director": "Someone",
            "cast": "Actor A"
        },
        {
            "id": "v2",
            "name": "Alpha Movie",
            "stream_url": "http://x/2",
            "type": "movie",
            "category": "Drama",
            "description": "space adventure",
            "director": "Director B",
            "cast": "Actor B"
        },
        {
            "id": "v3",
            "name": "Other Movie",
            "stream_url": "http://x/3",
            "type": "movie",
            "category": "Comedy",
            "description": "space comedy"
        }
    ]);

    let resp = send(
        &svc,
        &json!({
            "cmd": "filterAndSortVodItems",
            "id": "r1",
            "args": {
                "itemsJson": serde_json::to_string(&items).unwrap(),
                "category": "Drama",
                "query": "space",
                "sortBy": "name_asc",
            },
        }),
    );
    let result: Vec<serde_json::Value> =
        serde_json::from_str(resp["data"].as_str().unwrap()).unwrap();

    assert_eq!(result.len(), 1);
    assert_eq!(result[0]["id"], "v2");
}

#[test]
fn search_content_accepts_dart_epg_channel_id_key() {
    let svc = make_svc();
    let channels = json!([
        {
            "id": "xmltv-news",
            "name": "News Channel",
            "stream_url": "http://x/news"
        }
    ]);
    let vod_items = json!([]);
    let epg = json!({
        "xmltv-news": [{
            "channel_id": "xmltv-news",
            "title": "Evening News",
            "start_time": "2026-04-10T18:00:00",
            "end_time": "2026-04-10T19:00:00"
        }]
    });
    let filter = json!({
        "search_channels": false,
        "search_movies": false,
        "search_series": false,
        "search_epg": true,
        "search_in_description": false
    });

    let resp = send(
        &svc,
        &json!({
            "cmd": "searchContent",
            "id": "r1",
            "args": {
                "query": "Evening",
                "channelsJson": serde_json::to_string(&channels).unwrap(),
                "vodItemsJson": serde_json::to_string(&vod_items).unwrap(),
                "epgEntriesJson": serde_json::to_string(&epg).unwrap(),
                "filterJson": serde_json::to_string(&filter).unwrap(),
            },
        }),
    );

    let result: serde_json::Value = serde_json::from_str(resp["data"].as_str().unwrap()).unwrap();
    assert_eq!(result["epg_programs"].as_array().unwrap().len(), 1);
}

#[test]
fn build_xtream_action_url() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "buildXtreamActionUrl",
            "id": "r1",
            "args": {
                "baseUrl": "http://xtream.tv",
                "username": "user",
                "password": "pass",
                "action": "get_live_streams",
            },
        }),
    );
    let url = resp["data"].as_str().unwrap();
    assert!(url.contains("get_live_streams"));
}

#[test]
fn build_xtream_action_url_preserves_non_string_params() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "buildXtreamActionUrl",
            "id": "r1",
            "args": {
                "baseUrl": "http://xtream.tv",
                "username": "user",
                "password": "pass",
                "action": "get_live_streams",
                "paramsJson": serde_json::json!({
                    "limit": 25,
                    "include_adult": false,
                    "cat id": 5,
                    "search": "one & two",
                })
                .to_string(),
            },
        }),
    );
    let url = resp["data"].as_str().unwrap();
    assert!(url.contains("limit=25"));
    assert!(url.contains("include_adult=false"));
    assert!(url.contains("cat+id=5"));
    assert!(url.contains("search=one+%26+two"));
}

#[test]
fn build_xtream_stream_url() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "buildXtreamStreamUrl",
            "id": "r1",
            "args": {
                "baseUrl": "http://xtream.tv",
                "username": "user",
                "password": "pass",
                "streamId": 123,
                "streamType": "live",
                "extension": "ts",
            },
        }),
    );
    let url = resp["data"].as_str().unwrap();
    assert!(url.contains("123"));
}

#[test]
fn build_xtream_catchup_url() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "buildXtreamCatchupUrl",
            "id": "r1",
            "args": {
                "baseUrl": "http://xtream.tv",
                "username": "user",
                "password": "pass",
                "streamId": 42,
                "startUtc": 1717200000,
                "durationMinutes": 60,
            },
        }),
    );
    assert!(resp["data"].is_string());
}

#[test]
fn build_catchup_url_extracts_xtream_credentials_from_stream_url() {
    let svc = make_svc();
    let now = Utc::now().timestamp();
    let channel = json!({
        "id": "ch1",
        "native_id": "42",
        "name": "Xtream Ch",
        "stream_url": "http://xtream.tv/live/user/pass/42.ts",
        "xtream_stream_id": "42",
        "has_catchup": true,
        "catchup_days": 7,
        "catchup_type": "xc",
    });

    let resp = send(
        &svc,
        &json!({
            "cmd": "buildCatchupUrl",
            "id": "r1",
            "args": {
                "channelJson": serde_json::to_string(&channel).unwrap(),
                "startUtc": now - 3600,
                "endUtc": now - 1800,
            },
        }),
    );

    let url = resp["data"].as_str().expect("expected catchup URL");
    assert!(url.contains("/timeshift/user/pass/30/"));
    assert!(url.ends_with("/42.ts"));
}

#[test]
fn sort_channels() {
    let svc = make_svc();
    let channels = json!([
        {"id": "c2", "name": "ZZZ",
         "stream_url": "http://x/2"},
        {"id": "c1", "name": "AAA",
         "stream_url": "http://x/1"},
    ]);
    let resp = send(
        &svc,
        &json!({
            "cmd": "sortChannels",
            "id": "r1",
            "args": {
                "json": serde_json::to_string(
                    &channels
                ).unwrap(),
            },
        }),
    );
    assert!(resp["data"].is_string());
}

#[test]
fn guess_logo_domains() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "guessLogoDomains",
            "id": "r1",
            "args": {"name": "CNN"},
        }),
    );
    assert!(resp["data"].is_array());
}

#[test]
fn build_category_map() {
    let svc = make_svc();
    let cats = json!([
        {"category_id": "1",
         "category_name": "News"},
    ]);
    let resp = send(
        &svc,
        &json!({
            "cmd": "buildCategoryMap",
            "id": "r1",
            "args": {
                "categoriesJson": serde_json::to_string(
                    &cats
                ).unwrap(),
            },
        }),
    );
    assert!(resp["data"].is_string());
}

#[test]
fn extract_sorted_groups() {
    let svc = make_svc();
    let channels = json!([
        {"id": "c1", "name": "Ch1",
         "stream_url": "http://x/1",
         "channel_group": "Sports"},
        {"id": "c2", "name": "Ch2",
         "stream_url": "http://x/2",
         "channel_group": "News"},
    ]);
    let resp = send(
        &svc,
        &json!({
            "cmd": "extractSortedGroups",
            "id": "r1",
            "args": {
                "channelsJson": serde_json::to_string(
                    &channels
                ).unwrap(),
            },
        }),
    );
    let groups = resp["data"].as_array().unwrap();
    assert!(groups.len() >= 2);
}
