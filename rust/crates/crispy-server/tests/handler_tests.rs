//! Integration tests for WebSocket command handlers.
//!
//! Each test creates an in-memory `CrispyService`,
//! wraps it in `Arc<Mutex<_>>`, and calls
//! `handle_message` directly — no WebSocket needed.

// no longer needs Arc/Mutex

use crispy_core::services::CrispyService;
use crispy_server::handlers::handle_message;
use serde_json::{Value, json};

// ── Helpers ────────────────────────────────────────

/// Create a fresh in-memory service.
fn make_svc() -> CrispyService {
    CrispyService::open_in_memory().expect("open in-memory")
}

/// Send a JSON command and parse the response.
fn send(svc: &CrispyService, msg: &Value) -> Value {
    let resp = handle_message(svc, &msg.to_string());
    serde_json::from_str(&resp).expect("Response is valid JSON")
}

/// Send a raw string and parse the response.
fn send_raw(svc: &CrispyService, text: &str) -> Value {
    let resp = handle_message(svc, text);
    serde_json::from_str(&resp).expect("Response is valid JSON")
}

// ── Error Handling ─────────────────────────────────

#[test]
fn unknown_command_returns_error() {
    let svc = make_svc();
    let resp = send(&svc, &json!({"cmd": "noSuchCmd", "id": "r1"}));
    assert_eq!(resp["id"], "r1");
    assert!(resp["error"].as_str().unwrap().contains("Unknown command"),);
}

#[test]
fn malformed_json_returns_error() {
    let svc = make_svc();
    let resp = send_raw(&svc, "not valid json{{{");
    assert!(resp["error"].as_str().unwrap().contains("JSON"));
}

#[test]
fn missing_cmd_field_returns_error() {
    let svc = make_svc();
    let resp = send(&svc, &json!({"id": "r1"}));
    assert!(resp["error"].as_str().unwrap().contains("Missing cmd"),);
}

#[test]
fn empty_object_returns_error() {
    let svc = make_svc();
    let resp = send(&svc, &json!({}));
    assert!(resp["error"].is_string());
}

#[test]
fn null_cmd_returns_error() {
    let svc = make_svc();
    let resp = send(&svc, &json!({"cmd": null, "id": "r1"}));
    assert!(resp.get("error").is_some());
}

#[test]
fn numeric_cmd_returns_error() {
    let svc = make_svc();
    let resp = send(&svc, &json!({"cmd": 42, "id": "r1"}));
    assert!(resp.get("error").is_some());
}

#[test]
fn missing_id_still_works() {
    let svc = make_svc();
    let resp = send(&svc, &json!({"cmd": "loadChannels"}));
    // Should succeed with null id.
    assert!(resp.get("data").is_some());
    assert!(resp["id"].is_null());
}

#[test]
fn string_id_preserved() {
    let svc = make_svc();
    let resp = send(&svc, &json!({"cmd": "loadChannels", "id": "abc-123"}));
    assert_eq!(resp["id"], "abc-123");
}

#[test]
fn numeric_id_preserved() {
    let svc = make_svc();
    let resp = send(&svc, &json!({"cmd": "loadChannels", "id": 42}));
    assert_eq!(resp["id"], 42);
}

// ── CRUD: Channels ─────────────────────────────────

#[test]
fn load_channels_empty() {
    let svc = make_svc();
    let resp = send(&svc, &json!({"cmd": "loadChannels", "id": "r1"}));
    assert_eq!(resp["id"], "r1");
    assert!(resp["data"].as_array().unwrap().is_empty());
}

#[test]
fn save_and_load_channels() {
    let svc = make_svc();
    let ch = json!({
        "id": "ch1",
        "name": "Test Channel",
        "stream_url": "http://example.com/ch1",
    });
    let resp = send(
        &svc,
        &json!({
            "cmd": "saveChannels",
            "id": "r1",
            "args": {"channels": [ch]},
        }),
    );
    assert_eq!(resp["id"], "r1");
    assert_eq!(resp["ok"], true);
    assert_eq!(resp["count"], 1);

    let resp = send(&svc, &json!({"cmd": "loadChannels", "id": "r2"}));
    let data = resp["data"].as_array().unwrap();
    assert_eq!(data.len(), 1);
    assert_eq!(data[0]["name"], "Test Channel");
}

#[test]
fn save_channels_missing_arg() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "saveChannels",
            "id": "r1",
            "args": {},
        }),
    );
    assert!(resp["error"].is_string());
}

#[test]
fn get_channels_by_ids() {
    let svc = make_svc();
    let channels = json!([
        {"id": "c1", "name": "C1",
         "stream_url": "http://x/1"},
        {"id": "c2", "name": "C2",
         "stream_url": "http://x/2"},
        {"id": "c3", "name": "C3",
         "stream_url": "http://x/3"},
    ]);
    send(
        &svc,
        &json!({
            "cmd": "saveChannels",
            "id": "r1",
            "args": {"channels": channels},
        }),
    );

    let resp = send(
        &svc,
        &json!({
            "cmd": "getChannelsByIds",
            "id": "r2",
            "args": {"ids": ["c1", "c3"]},
        }),
    );
    let data = resp["data"].as_array().unwrap();
    assert_eq!(data.len(), 2);
}

#[test]
fn delete_removed_channels() {
    let svc = make_svc();
    let channels = json!([
        {"id": "c1", "name": "C1",
         "stream_url": "http://x/1",
         "source_id": "src1"},
        {"id": "c2", "name": "C2",
         "stream_url": "http://x/2",
         "source_id": "src1"},
    ]);
    send(
        &svc,
        &json!({
            "cmd": "saveChannels",
            "id": "r1",
            "args": {"channels": channels},
        }),
    );

    let resp = send(
        &svc,
        &json!({
            "cmd": "deleteRemovedChannels",
            "id": "r2",
            "args": {
                "sourceId": "src1",
                "keepIds": ["c1"],
            },
        }),
    );
    assert_eq!(resp["ok"], true);
    assert_eq!(resp["count"], 1);
}

// ── CRUD: Profiles ─────────────────────────────────

#[test]
fn save_and_load_profiles() {
    let svc = make_svc();
    let profile = json!({
        "id": "p1",
        "name": "Alice",
        "avatar_index": 2,
    });
    let resp = send(
        &svc,
        &json!({
            "cmd": "saveProfile",
            "id": "r1",
            "args": {"profile": profile},
        }),
    );
    assert_eq!(resp["ok"], true);

    let resp = send(&svc, &json!({"cmd": "loadProfiles", "id": "r2"}));
    let data = resp["data"].as_array().unwrap();
    assert_eq!(data.len(), 1);
    assert_eq!(data[0]["name"], "Alice");
}

#[test]
fn delete_profile() {
    let svc = make_svc();
    send(
        &svc,
        &json!({
            "cmd": "saveProfile",
            "id": "r1",
            "args": {"profile": {
                "id": "p1", "name": "Bob",
            }},
        }),
    );
    let resp = send(
        &svc,
        &json!({
            "cmd": "deleteProfile",
            "id": "r2",
            "args": {"id": "p1"},
        }),
    );
    assert_eq!(resp["ok"], true);

    let resp = send(&svc, &json!({"cmd": "loadProfiles", "id": "r3"}));
    assert!(resp["data"].as_array().unwrap().is_empty());
}

// ── CRUD: Favorites ────────────────────────────────

#[test]
fn add_and_get_favorites() {
    let svc = make_svc();
    // Need a profile and channel first.
    send(
        &svc,
        &json!({
            "cmd": "saveProfile",
            "id": "r1",
            "args": {"profile": {
                "id": "p1", "name": "User",
            }},
        }),
    );
    send(
        &svc,
        &json!({
            "cmd": "saveChannels",
            "id": "r2",
            "args": {"channels": [{
                "id": "ch1", "name": "News",
                "stream_url": "http://x/1",
            }]},
        }),
    );

    let resp = send(
        &svc,
        &json!({
            "cmd": "addFavorite",
            "id": "r3",
            "args": {
                "profileId": "p1",
                "channelId": "ch1",
            },
        }),
    );
    assert_eq!(resp["ok"], true);

    let resp = send(
        &svc,
        &json!({
            "cmd": "getFavorites",
            "id": "r4",
            "args": {"profileId": "p1"},
        }),
    );
    let data = resp["data"].as_array().unwrap();
    assert_eq!(data.len(), 1);
}

#[test]
fn remove_favorite() {
    let svc = make_svc();
    send(
        &svc,
        &json!({
            "cmd": "addFavorite",
            "id": "r1",
            "args": {
                "profileId": "p1",
                "channelId": "ch1",
            },
        }),
    );
    let resp = send(
        &svc,
        &json!({
            "cmd": "removeFavorite",
            "id": "r2",
            "args": {
                "profileId": "p1",
                "channelId": "ch1",
            },
        }),
    );
    assert_eq!(resp["ok"], true);
}

// ── CRUD: Settings ─────────────────────────────────

#[test]
fn set_and_get_setting() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "setSetting",
            "id": "r1",
            "args": {"key": "theme", "value": "dark"},
        }),
    );
    assert_eq!(resp["ok"], true);

    let resp = send(
        &svc,
        &json!({
            "cmd": "getSetting",
            "id": "r2",
            "args": {"key": "theme"},
        }),
    );
    assert_eq!(resp["data"], "dark");
}

#[test]
fn get_setting_not_found() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "getSetting",
            "id": "r1",
            "args": {"key": "nonexistent"},
        }),
    );
    assert!(resp["data"].is_null());
}

#[test]
fn remove_setting() {
    let svc = make_svc();
    send(
        &svc,
        &json!({
            "cmd": "setSetting",
            "id": "r1",
            "args": {"key": "k", "value": "v"},
        }),
    );
    let resp = send(
        &svc,
        &json!({
            "cmd": "removeSetting",
            "id": "r2",
            "args": {"key": "k"},
        }),
    );
    assert_eq!(resp["ok"], true);

    let resp = send(
        &svc,
        &json!({
            "cmd": "getSetting",
            "id": "r3",
            "args": {"key": "k"},
        }),
    );
    assert!(resp["data"].is_null());
}

#[test]
fn set_setting_missing_key() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "setSetting",
            "id": "r1",
            "args": {"value": "dark"},
        }),
    );
    assert!(resp["error"].is_string());
}

// ── CRUD: VOD Items ────────────────────────────────

#[test]
fn save_and_load_vod_items() {
    let svc = make_svc();
    let item = json!({
        "id": "v1",
        "name": "Movie One",
        "stream_url": "http://x/movie1",
        "type": "movie",
    });
    let resp = send(
        &svc,
        &json!({
            "cmd": "saveVodItems",
            "id": "r1",
            "args": {"items": [item]},
        }),
    );
    assert_eq!(resp["ok"], true);
    assert_eq!(resp["count"], 1);

    let resp = send(&svc, &json!({"cmd": "loadVodItems", "id": "r2"}));
    let data = resp["data"].as_array().unwrap();
    assert_eq!(data.len(), 1);
    assert_eq!(data[0]["name"], "Movie One");
}

#[test]
fn delete_removed_vod_items() {
    let svc = make_svc();
    let items = json!([
        {"id": "v1", "name": "M1",
         "stream_url": "http://x/1",
         "type": "movie", "source_id": "src1"},
        {"id": "v2", "name": "M2",
         "stream_url": "http://x/2",
         "type": "movie", "source_id": "src1"},
    ]);
    send(
        &svc,
        &json!({
            "cmd": "saveVodItems",
            "id": "r1",
            "args": {"items": items},
        }),
    );

    let resp = send(
        &svc,
        &json!({
            "cmd": "deleteRemovedVodItems",
            "id": "r2",
            "args": {
                "sourceId": "src1",
                "keepIds": ["v1"],
            },
        }),
    );
    assert_eq!(resp["ok"], true);
    assert_eq!(resp["count"], 1);
}

// ── CRUD: VOD Favorites ───────────────────────────

#[test]
fn add_and_get_vod_favorites() {
    let svc = make_svc();
    // FK: profile + VOD item must exist.
    send(
        &svc,
        &json!({
            "cmd": "saveProfile",
            "id": "s1",
            "args": {"profile": {
                "id": "p1", "name": "User",
            }},
        }),
    );
    send(
        &svc,
        &json!({
            "cmd": "saveVodItems",
            "id": "s2",
            "args": {"items": [{
                "id": "v1",
                "name": "Movie",
                "stream_url": "http://x/1",
                "type": "movie",
            }]},
        }),
    );

    let resp = send(
        &svc,
        &json!({
            "cmd": "addVodFavorite",
            "id": "r1",
            "args": {
                "profileId": "p1",
                "vodItemId": "v1",
            },
        }),
    );
    assert_eq!(resp["ok"], true);

    let resp = send(
        &svc,
        &json!({
            "cmd": "getVodFavorites",
            "id": "r2",
            "args": {"profileId": "p1"},
        }),
    );
    assert_eq!(resp["data"].as_array().unwrap().len(), 1,);
}

#[test]
fn remove_vod_favorite() {
    let svc = make_svc();
    send(
        &svc,
        &json!({
            "cmd": "addVodFavorite",
            "id": "r1",
            "args": {
                "profileId": "p1",
                "vodItemId": "v1",
            },
        }),
    );
    let resp = send(
        &svc,
        &json!({
            "cmd": "removeVodFavorite",
            "id": "r2",
            "args": {
                "profileId": "p1",
                "vodItemId": "v1",
            },
        }),
    );
    assert_eq!(resp["ok"], true);
}

// ── CRUD: Categories ──────────────────────────────

#[test]
fn save_and_load_categories() {
    let svc = make_svc();
    let cats = json!({
        "live": ["News", "Sports"],
        "vod": ["Action"],
    });
    let resp = send(
        &svc,
        &json!({
            "cmd": "saveCategories",
            "id": "r1",
            "args": {"categories": cats},
        }),
    );
    assert_eq!(resp["ok"], true);

    let resp = send(&svc, &json!({"cmd": "loadCategories", "id": "r2"}));
    assert!(resp["data"].is_object());
}

// ── CRUD: Favorite Categories ─────────────────────

#[test]
fn add_and_get_favorite_categories() {
    let svc = make_svc();
    // FK: profile must exist.
    send(
        &svc,
        &json!({
            "cmd": "saveProfile",
            "id": "s1",
            "args": {"profile": {
                "id": "p1", "name": "User",
            }},
        }),
    );

    let resp = send(
        &svc,
        &json!({
            "cmd": "addFavoriteCategory",
            "id": "r1",
            "args": {
                "profileId": "p1",
                "categoryType": "live",
                "categoryName": "Sports",
            },
        }),
    );
    assert_eq!(resp["ok"], true);

    let resp = send(
        &svc,
        &json!({
            "cmd": "getFavoriteCategories",
            "id": "r2",
            "args": {
                "profileId": "p1",
                "categoryType": "live",
            },
        }),
    );
    let data = resp["data"].as_array().unwrap();
    assert_eq!(data.len(), 1);
}

#[test]
fn remove_favorite_category() {
    let svc = make_svc();
    send(
        &svc,
        &json!({
            "cmd": "addFavoriteCategory",
            "id": "r1",
            "args": {
                "profileId": "p1",
                "categoryType": "live",
                "categoryName": "News",
            },
        }),
    );
    let resp = send(
        &svc,
        &json!({
            "cmd": "removeFavoriteCategory",
            "id": "r2",
            "args": {
                "profileId": "p1",
                "categoryType": "live",
                "categoryName": "News",
            },
        }),
    );
    assert_eq!(resp["ok"], true);
}

// ── CRUD: Source Access ───────────────────────────

#[test]
fn grant_and_get_source_access() {
    let svc = make_svc();
    // FK: profile must exist.
    send(
        &svc,
        &json!({
            "cmd": "saveProfile",
            "id": "s1",
            "args": {"profile": {
                "id": "p1", "name": "User",
            }},
        }),
    );

    let resp = send(
        &svc,
        &json!({
            "cmd": "grantSourceAccess",
            "id": "r1",
            "args": {
                "profileId": "p1",
                "sourceId": "s1",
            },
        }),
    );
    assert_eq!(resp["ok"], true);

    let resp = send(
        &svc,
        &json!({
            "cmd": "getSourceAccess",
            "id": "r2",
            "args": {"profileId": "p1"},
        }),
    );
    let data = resp["data"].as_array().unwrap();
    assert_eq!(data.len(), 1);
}

#[test]
fn revoke_source_access() {
    let svc = make_svc();
    send(
        &svc,
        &json!({
            "cmd": "grantSourceAccess",
            "id": "r1",
            "args": {
                "profileId": "p1",
                "sourceId": "s1",
            },
        }),
    );
    let resp = send(
        &svc,
        &json!({
            "cmd": "revokeSourceAccess",
            "id": "r2",
            "args": {
                "profileId": "p1",
                "sourceId": "s1",
            },
        }),
    );
    assert_eq!(resp["ok"], true);
}

#[test]
fn set_source_access() {
    let svc = make_svc();
    // FK: profile must exist.
    send(
        &svc,
        &json!({
            "cmd": "saveProfile",
            "id": "s1",
            "args": {"profile": {
                "id": "p1", "name": "User",
            }},
        }),
    );

    let resp = send(
        &svc,
        &json!({
            "cmd": "setSourceAccess",
            "id": "r1",
            "args": {
                "profileId": "p1",
                "sourceIds": ["s1", "s2"],
            },
        }),
    );
    assert_eq!(resp["ok"], true);
}

// ── CRUD: Channel Order ──────────────────────────

#[test]
fn save_and_load_channel_order() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "saveChannelOrder",
            "id": "r1",
            "args": {
                "profileId": "p1",
                "groupName": "News",
                "channelIds": ["c3", "c1", "c2"],
            },
        }),
    );
    assert_eq!(resp["ok"], true);

    let resp = send(
        &svc,
        &json!({
            "cmd": "loadChannelOrder",
            "id": "r2",
            "args": {
                "profileId": "p1",
                "groupName": "News",
            },
        }),
    );
    assert!(resp["data"].is_object());
}

#[test]
fn load_channel_order_not_found() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "loadChannelOrder",
            "id": "r1",
            "args": {
                "profileId": "p1",
                "groupName": "none",
            },
        }),
    );
    assert!(resp["data"].is_null());
}

#[test]
fn reset_channel_order() {
    let svc = make_svc();
    send(
        &svc,
        &json!({
            "cmd": "saveChannelOrder",
            "id": "r1",
            "args": {
                "profileId": "p1",
                "groupName": "G",
                "channelIds": ["c1"],
            },
        }),
    );
    let resp = send(
        &svc,
        &json!({
            "cmd": "resetChannelOrder",
            "id": "r2",
            "args": {
                "profileId": "p1",
                "groupName": "G",
            },
        }),
    );
    assert_eq!(resp["ok"], true);
}

// ── CRUD: EPG ─────────────────────────────────────

#[test]
fn save_and_load_epg_entries() {
    let svc = make_svc();
    let entries = json!({
        "ch1": [{
            "channel_id": "ch1",
            "title": "News",
            "start_time": "2024-01-01T10:00:00",
            "end_time": "2024-01-01T11:00:00",
        }],
    });
    let resp = send(
        &svc,
        &json!({
            "cmd": "saveEpgEntries",
            "id": "r1",
            "args": {"entries": entries},
        }),
    );
    assert_eq!(resp["ok"], true);
    assert_eq!(resp["count"], 1);

    let resp = send(&svc, &json!({"cmd": "loadEpgEntries", "id": "r2"}));
    assert!(resp["data"].is_object());
}

#[test]
fn clear_epg_entries() {
    let svc = make_svc();
    let resp = send(&svc, &json!({"cmd": "clearEpgEntries", "id": "r1"}));
    assert_eq!(resp["ok"], true);
}

#[test]
fn evict_stale_epg() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "evictStaleEpg",
            "id": "r1",
            "args": {"days": 7},
        }),
    );
    assert_eq!(resp["ok"], true);
}

// ── CRUD: Watch History ───────────────────────────

#[test]
fn save_and_load_watch_history() {
    let svc = make_svc();
    let entry = json!({
        "id": "wh1",
        "media_type": "channel",
        "name": "CNN",
        "stream_url": "http://x/cnn",
        "last_watched": "2024-06-01T12:00:00",
    });
    let resp = send(
        &svc,
        &json!({
            "cmd": "saveWatchHistory",
            "id": "r1",
            "args": {"entry": entry},
        }),
    );
    assert_eq!(resp["ok"], true);

    let resp = send(&svc, &json!({"cmd": "loadWatchHistory", "id": "r2"}));
    let data = resp["data"].as_array().unwrap();
    assert_eq!(data.len(), 1);
}

#[test]
fn delete_watch_history() {
    let svc = make_svc();
    send(
        &svc,
        &json!({
            "cmd": "saveWatchHistory",
            "id": "r1",
            "args": {"entry": {
                "id": "wh1",
                "media_type": "channel",
                "name": "BBC",
                "stream_url": "http://x/bbc",
                "last_watched": "2024-06-01T12:00:00",
            }},
        }),
    );
    let resp = send(
        &svc,
        &json!({
            "cmd": "deleteWatchHistory",
            "id": "r2",
            "args": {"id": "wh1"},
        }),
    );
    assert_eq!(resp["ok"], true);
}

#[test]
fn clear_all_watch_history() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "clearAllWatchHistory",
            "id": "r1",
        }),
    );
    assert_eq!(resp["ok"], true);
}

// ── CRUD: Recordings ──────────────────────────────

#[test]
fn save_and_load_recordings() {
    let svc = make_svc();
    let rec = json!({
        "id": "rec1",
        "channel_name": "ESPN",
        "program_name": "Football",
        "start_time": "2024-06-01T20:00:00",
        "end_time": "2024-06-01T22:00:00",
        "status": "scheduled",
    });
    let resp = send(
        &svc,
        &json!({
            "cmd": "saveRecording",
            "id": "r1",
            "args": {"recording": rec},
        }),
    );
    assert_eq!(resp["ok"], true);

    let resp = send(&svc, &json!({"cmd": "loadRecordings", "id": "r2"}));
    let data = resp["data"].as_array().unwrap();
    assert_eq!(data.len(), 1);
    assert_eq!(data[0]["program_name"], "Football");
}

#[test]
fn delete_recording() {
    let svc = make_svc();
    send(
        &svc,
        &json!({
            "cmd": "saveRecording",
            "id": "r1",
            "args": {"recording": {
                "id": "rec1",
                "channel_name": "ESPN",
                "program_name": "Game",
                "start_time": "2024-06-01T20:00:00",
                "end_time": "2024-06-01T22:00:00",
                "status": "completed",
            }},
        }),
    );
    let resp = send(
        &svc,
        &json!({
            "cmd": "deleteRecording",
            "id": "r2",
            "args": {"id": "rec1"},
        }),
    );
    assert_eq!(resp["ok"], true);
}

// ── CRUD: Storage Backends ────────────────────────

#[test]
fn save_and_load_storage_backends() {
    let svc = make_svc();
    let backend = json!({
        "id": "sb1",
        "name": "My S3",
        "backend_type": "s3",
        "config": "{}",
        "is_default": false,
    });
    let resp = send(
        &svc,
        &json!({
            "cmd": "saveStorageBackend",
            "id": "r1",
            "args": {"backend": backend},
        }),
    );
    assert_eq!(resp["ok"], true);

    let resp = send(
        &svc,
        &json!({
            "cmd": "loadStorageBackends",
            "id": "r2",
        }),
    );
    let data = resp["data"].as_array().unwrap();
    assert_eq!(data.len(), 1);
}

#[test]
fn delete_storage_backend() {
    let svc = make_svc();
    send(
        &svc,
        &json!({
            "cmd": "saveStorageBackend",
            "id": "r1",
            "args": {"backend": {
                "id": "sb1",
                "name": "Local",
                "backend_type": "local",
                "config": "{}",
            }},
        }),
    );
    let resp = send(
        &svc,
        &json!({
            "cmd": "deleteStorageBackend",
            "id": "r2",
            "args": {"id": "sb1"},
        }),
    );
    assert_eq!(resp["ok"], true);
}

// ── CRUD: Transfer Tasks ──────────────────────────

#[test]
fn save_and_load_transfer_tasks() {
    let svc = make_svc();
    let task = json!({
        "id": "tt1",
        "recording_id": "rec1",
        "backend_id": "sb1",
        "direction": "upload",
        "status": "queued",
        "created_at": "2024-06-01T10:00:00",
    });
    let resp = send(
        &svc,
        &json!({
            "cmd": "saveTransferTask",
            "id": "r1",
            "args": {"task": task},
        }),
    );
    assert_eq!(resp["ok"], true);

    let resp = send(
        &svc,
        &json!({
            "cmd": "loadTransferTasks",
            "id": "r2",
        }),
    );
    let data = resp["data"].as_array().unwrap();
    assert_eq!(data.len(), 1);
}

#[test]
fn delete_transfer_task() {
    let svc = make_svc();
    send(
        &svc,
        &json!({
            "cmd": "saveTransferTask",
            "id": "r1",
            "args": {"task": {
                "id": "tt1",
                "recording_id": "r1",
                "backend_id": "b1",
                "direction": "upload",
                "status": "queued",
                "created_at": "2024-06-01T10:00:00",
            }},
        }),
    );
    let resp = send(
        &svc,
        &json!({
            "cmd": "deleteTransferTask",
            "id": "r2",
            "args": {"id": "tt1"},
        }),
    );
    assert_eq!(resp["ok"], true);
}

// ── CRUD: Saved Layouts ──────────────────────────

#[test]
fn save_and_load_saved_layouts() {
    let svc = make_svc();
    let layout = json!({
        "id": "lay1",
        "name": "Quad View",
        "layout": "quad",
        "streams": "[]",
        "created_at": "2024-06-01T10:00:00",
    });
    let resp = send(
        &svc,
        &json!({
            "cmd": "saveSavedLayout",
            "id": "r1",
            "args": {"layout": layout},
        }),
    );
    assert_eq!(resp["ok"], true);

    let resp = send(
        &svc,
        &json!({
            "cmd": "loadSavedLayouts",
            "id": "r2",
        }),
    );
    let data = resp["data"].as_array().unwrap();
    assert_eq!(data.len(), 1);
}

#[test]
fn get_saved_layout_by_id() {
    let svc = make_svc();
    send(
        &svc,
        &json!({
            "cmd": "saveSavedLayout",
            "id": "r1",
            "args": {"layout": {
                "id": "lay1",
                "name": "PIP",
                "layout": "pip",
                "streams": "[]",
                "created_at": "2024-06-01T10:00:00",
            }},
        }),
    );
    let resp = send(
        &svc,
        &json!({
            "cmd": "getSavedLayoutById",
            "id": "r2",
            "args": {"id": "lay1"},
        }),
    );
    assert!(resp["data"].is_object());
}

#[test]
fn delete_saved_layout() {
    let svc = make_svc();
    send(
        &svc,
        &json!({
            "cmd": "saveSavedLayout",
            "id": "r1",
            "args": {"layout": {
                "id": "lay1",
                "name": "Grid",
                "layout": "grid",
                "streams": "[]",
                "created_at": "2024-06-01T10:00:00",
            }},
        }),
    );
    let resp = send(
        &svc,
        &json!({
            "cmd": "deleteSavedLayout",
            "id": "r2",
            "args": {"id": "lay1"},
        }),
    );
    assert_eq!(resp["ok"], true);
}

// ── CRUD: Search History ──────────────────────────

#[test]
fn save_and_load_search_history() {
    let svc = make_svc();
    let entry = json!({
        "id": "sh1",
        "query": "football",
        "searched_at": "2024-06-01T10:00:00",
        "result_count": 5,
    });
    let resp = send(
        &svc,
        &json!({
            "cmd": "saveSearchEntry",
            "id": "r1",
            "args": {"entry": entry},
        }),
    );
    assert_eq!(resp["ok"], true);

    let resp = send(
        &svc,
        &json!({
            "cmd": "loadSearchHistory",
            "id": "r2",
        }),
    );
    let data = resp["data"].as_array().unwrap();
    assert_eq!(data.len(), 1);
}

#[test]
fn delete_search_entry() {
    let svc = make_svc();
    send(
        &svc,
        &json!({
            "cmd": "saveSearchEntry",
            "id": "r1",
            "args": {"entry": {
                "id": "sh1",
                "query": "news",
                "searched_at": "2024-06-01T10:00:00",
            }},
        }),
    );
    let resp = send(
        &svc,
        &json!({
            "cmd": "deleteSearchEntry",
            "id": "r2",
            "args": {"id": "sh1"},
        }),
    );
    assert_eq!(resp["ok"], true);
}

#[test]
fn clear_search_history() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "clearSearchHistory",
            "id": "r1",
        }),
    );
    assert_eq!(resp["ok"], true);
}

#[test]
fn delete_search_by_query() {
    let svc = make_svc();
    send(
        &svc,
        &json!({
            "cmd": "saveSearchEntry",
            "id": "r1",
            "args": {"entry": {
                "id": "sh1",
                "query": "soccer",
                "searched_at": "2024-06-01T10:00:00",
            }},
        }),
    );
    let resp = send(
        &svc,
        &json!({
            "cmd": "deleteSearchByQuery",
            "id": "r2",
            "args": {"query": "soccer"},
        }),
    );
    assert_eq!(resp["ok"], true);
}

// ── CRUD: Reminders ───────────────────────────────

#[test]
fn save_and_load_reminders() {
    let svc = make_svc();
    let reminder = json!({
        "id": "rem1",
        "program_name": "Big Game",
        "channel_name": "ESPN",
        "start_time": "2024-06-01T20:00:00",
        "notify_at": "2024-06-01T19:50:00",
        "created_at": "2024-06-01T10:00:00",
    });
    let resp = send(
        &svc,
        &json!({
            "cmd": "saveReminder",
            "id": "r1",
            "args": {"reminder": reminder},
        }),
    );
    assert_eq!(resp["ok"], true);

    let resp = send(&svc, &json!({"cmd": "loadReminders", "id": "r2"}));
    let data = resp["data"].as_array().unwrap();
    assert_eq!(data.len(), 1);
}

#[test]
fn delete_reminder() {
    let svc = make_svc();
    send(
        &svc,
        &json!({
            "cmd": "saveReminder",
            "id": "r1",
            "args": {"reminder": {
                "id": "rem1",
                "program_name": "Show",
                "channel_name": "NBC",
                "start_time": "2024-06-01T21:00:00",
                "notify_at": "2024-06-01T20:50:00",
                "created_at": "2024-06-01T10:00:00",
            }},
        }),
    );
    let resp = send(
        &svc,
        &json!({
            "cmd": "deleteReminder",
            "id": "r2",
            "args": {"id": "rem1"},
        }),
    );
    assert_eq!(resp["ok"], true);
}

#[test]
fn mark_reminder_fired_and_clear() {
    let svc = make_svc();
    send(
        &svc,
        &json!({
            "cmd": "saveReminder",
            "id": "r1",
            "args": {"reminder": {
                "id": "rem1",
                "program_name": "Movie Night",
                "channel_name": "HBO",
                "start_time": "2024-06-01T21:00:00",
                "notify_at": "2024-06-01T20:50:00",
                "created_at": "2024-06-01T10:00:00",
            }},
        }),
    );
    let resp = send(
        &svc,
        &json!({
            "cmd": "markReminderFired",
            "id": "r2",
            "args": {"id": "rem1"},
        }),
    );
    assert_eq!(resp["ok"], true);

    let resp = send(
        &svc,
        &json!({
            "cmd": "clearFiredReminders",
            "id": "r3",
        }),
    );
    assert_eq!(resp["ok"], true);
}

// ── CRUD: Sync Meta ──────────────────────────────

#[test]
fn set_and_get_last_sync_time() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "setLastSyncTime",
            "id": "r1",
            "args": {
                "sourceId": "src1",
                "timestamp": 1717200000,
            },
        }),
    );
    assert_eq!(resp["ok"], true);

    let resp = send(
        &svc,
        &json!({
            "cmd": "getLastSyncTime",
            "id": "r2",
            "args": {"sourceId": "src1"},
        }),
    );
    assert!(resp["data"].is_number());
}

#[test]
fn get_last_sync_time_not_found() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "getLastSyncTime",
            "id": "r1",
            "args": {"sourceId": "none"},
        }),
    );
    assert!(resp["data"].is_null());
}

// ── CRUD: Bulk / Phase 8 ─────────────────────────

#[test]
fn clear_all() {
    let svc = make_svc();
    // Populate some data first.
    send(
        &svc,
        &json!({
            "cmd": "setSetting",
            "id": "r1",
            "args": {"key": "k", "value": "v"},
        }),
    );
    let resp = send(&svc, &json!({"cmd": "clearAll", "id": "r2"}));
    assert_eq!(resp["ok"], true);
}

#[test]
fn update_vod_favorite_flag() {
    let svc = make_svc();
    // Save a VOD item first.
    send(
        &svc,
        &json!({
            "cmd": "saveVodItems",
            "id": "r1",
            "args": {"items": [{
                "id": "v1",
                "name": "Movie",
                "stream_url": "http://x/m1",
                "type": "movie",
            }]},
        }),
    );
    let resp = send(
        &svc,
        &json!({
            "cmd": "updateVodFavorite",
            "id": "r2",
            "args": {
                "itemId": "v1",
                "isFavorite": true,
            },
        }),
    );
    assert_eq!(resp["ok"], true);
}

#[test]
fn get_profiles_for_source() {
    let svc = make_svc();
    send(
        &svc,
        &json!({
            "cmd": "saveProfile",
            "id": "r1",
            "args": {"profile": {
                "id": "p1", "name": "Alice",
            }},
        }),
    );
    send(
        &svc,
        &json!({
            "cmd": "grantSourceAccess",
            "id": "r2",
            "args": {
                "profileId": "p1",
                "sourceId": "s1",
            },
        }),
    );
    let resp = send(
        &svc,
        &json!({
            "cmd": "getProfilesForSource",
            "id": "r3",
            "args": {"sourceId": "s1"},
        }),
    );
    let data = resp["data"].as_array().unwrap();
    assert_eq!(data.len(), 1);
}

// ── CRUD: Backup ──────────────────────────────────

#[test]
fn export_and_import_backup() {
    let svc = make_svc();
    // Add some data.
    send(
        &svc,
        &json!({
            "cmd": "setSetting",
            "id": "r1",
            "args": {"key": "theme", "value": "dark"},
        }),
    );
    send(
        &svc,
        &json!({
            "cmd": "saveProfile",
            "id": "r1b",
            "args": {"profile": {
                "id": "p1", "name": "Alice",
            }},
        }),
    );

    let resp = send(&svc, &json!({"cmd": "exportBackup", "id": "r2"}));
    // exportBackup may return a string or object
    // depending on how serde serializes it.
    assert!(
        resp.get("data").is_some(),
        "expected data field, got: {resp}",
    );
    assert!(resp.get("error").is_none(), "export returned error: {resp}",);

    let backup_json = if resp["data"].is_string() {
        resp["data"].as_str().unwrap().to_string()
    } else {
        resp["data"].to_string()
    };

    // Import into fresh service.
    let svc2 = make_svc();
    let resp = send(
        &svc2,
        &json!({
            "cmd": "importBackup",
            "id": "r3",
            "args": {"json": backup_json},
        }),
    );
    assert!(resp.get("error").is_none(), "import returned error: {resp}",);
}

// ── Parser Commands ───────────────────────────────

#[test]
fn parse_m3u() {
    let svc = make_svc();
    let m3u = "#EXTM3U\n\
               #EXTINF:-1,Test Channel\n\
               http://example.com/stream";
    let resp = send(
        &svc,
        &json!({
            "cmd": "parseM3u",
            "id": "r1",
            "args": {"content": m3u},
        }),
    );
    // M3uParseResult is an object with "channels" array.
    assert!(resp["data"].is_object());
    assert!(resp["data"]["channels"].is_array());
}

#[test]
fn parse_epg() {
    let svc = make_svc();
    let xml = r#"<?xml version="1.0"?>
<tv>
  <programme start="20240101100000 +0000"
             stop="20240101110000 +0000"
             channel="ch1">
    <title>News</title>
  </programme>
</tv>"#;
    let resp = send(
        &svc,
        &json!({
            "cmd": "parseEpg",
            "id": "r1",
            "args": {"content": xml},
        }),
    );
    // parse_epg returns Vec<EpgEntry>.
    assert!(resp["data"].is_array());
    assert!(!resp["data"].as_array().unwrap().is_empty());
}

#[test]
fn extract_epg_channel_names() {
    let svc = make_svc();
    let xml = r#"<?xml version="1.0"?>
<tv>
  <channel id="ch1">
    <display-name>Channel One</display-name>
  </channel>
</tv>"#;
    let resp = send(
        &svc,
        &json!({
            "cmd": "extractEpgChannelNames",
            "id": "r1",
            "args": {"content": xml},
        }),
    );
    assert!(resp["data"].is_object());
}

#[test]
fn parse_m3u_missing_content() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "parseM3u",
            "id": "r1",
            "args": {},
        }),
    );
    assert!(resp["error"].is_string());
}

#[test]
fn parse_vtt_thumbnails() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "parseVttThumbnails",
            "id": "r1",
            "args": {
                "content": "WEBVTT\n\n",
                "baseUrl": "http://example.com",
            },
        }),
    );
    // May return null if no valid cues.
    assert!(resp["data"].is_null() || resp["data"].is_object());
}

#[test]
fn parse_stalker_epg() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "parseStalkerEpg",
            "id": "r1",
            "args": {
                "json": "[]",
                "channelId": "ch1",
            },
        }),
    );
    assert!(resp["data"].is_string());
}

#[test]
fn parse_stalker_categories() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "parseStalkerCategories",
            "id": "r1",
            "args": {"json": "[]"},
        }),
    );
    assert!(resp["data"].is_string());
}

#[test]
fn parse_xtream_categories() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "parseXtreamCategories",
            "id": "r1",
            "args": {"json": "[]"},
        }),
    );
    assert!(resp["data"].is_string());
}

#[test]
fn parse_s3_list_objects() {
    let svc = make_svc();
    let xml = r#"<?xml version="1.0"?>
<ListBucketResult>
  <Contents>
    <Key>file1.mp4</Key>
    <Size>1024</Size>
  </Contents>
</ListBucketResult>"#;
    let resp = send(
        &svc,
        &json!({
            "cmd": "parseS3ListObjects",
            "id": "r1",
            "args": {"xml": xml},
        }),
    );
    assert!(resp["data"].is_string());
}

#[test]
fn build_stalker_stream_url() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "buildStalkerStreamUrl",
            "id": "r1",
            "args": {
                "cmd": "http://xyz/cmd",
                "baseUrl": "http://portal.com",
            },
        }),
    );
    assert!(resp["data"].is_string());
}

#[test]
fn parse_stalker_create_link() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "parseStalkerCreateLink",
            "id": "r1",
            "args": {
                "json": r#"{"js":{"cmd":"http://x/y"}}"#,
                "baseUrl": "http://portal.com",
            },
        }),
    );
    // Returns Some(url) or None depending on parse.
    assert!(resp["data"].is_string() || resp["data"].is_null());
}

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

// ── Edge Cases ────────────────────────────────────

#[test]
fn empty_args_defaults_to_empty_object() {
    let svc = make_svc();
    // loadChannels doesn't need args.
    let resp = send(
        &svc,
        &json!({
            "cmd": "loadChannels",
            "id": "r1",
        }),
    );
    assert!(resp["data"].is_array());
}

#[test]
fn explicit_null_args_works() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "loadChannels",
            "id": "r1",
            "args": null,
        }),
    );
    // Should still work since get_args defaults.
    assert!(resp["data"].is_array());
}

#[test]
fn large_channel_payload() {
    let svc = make_svc();
    let channels: Vec<Value> = (0..500)
        .map(|i| {
            json!({
                "id": format!("ch{i}"),
                "name": format!("Channel {i}"),
                "stream_url": format!("http://x/{i}"),
            })
        })
        .collect();
    let resp = send(
        &svc,
        &json!({
            "cmd": "saveChannels",
            "id": "r1",
            "args": {"channels": channels},
        }),
    );
    assert_eq!(resp["ok"], true);
    assert_eq!(resp["count"], 500);

    let resp = send(&svc, &json!({"cmd": "loadChannels", "id": "r2"}));
    assert_eq!(resp["data"].as_array().unwrap().len(), 500);
}

#[test]
fn concurrent_like_sequential_calls() {
    // Simulates rapid sequential calls to the same
    // service (mutex protects state).
    let svc = make_svc();
    for i in 0..20 {
        let resp = send(
            &svc,
            &json!({
                "cmd": "setSetting",
                "id": format!("r{i}"),
                "args": {
                    "key": format!("k{i}"),
                    "value": format!("v{i}"),
                },
            }),
        );
        assert_eq!(resp["ok"], true);
    }
    // Verify all 20 are independent.
    for i in 0..20 {
        let resp = send(
            &svc,
            &json!({
                "cmd": "getSetting",
                "id": format!("g{i}"),
                "args": {"key": format!("k{i}")},
            }),
        );
        assert_eq!(resp["data"].as_str().unwrap(), format!("v{i}"),);
    }
}

#[test]
fn invalid_channels_json_returns_error() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "saveChannels",
            "id": "r1",
            "args": {"channels": "not an array"},
        }),
    );
    assert!(resp["error"].is_string());
}

#[test]
fn evict_stale_epg_missing_days() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "evictStaleEpg",
            "id": "r1",
            "args": {},
        }),
    );
    assert!(resp["error"].is_string());
}
