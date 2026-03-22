//! CRUD tests for channels, profiles, favorites, and settings.

use serde_json::json;

use super::{make_svc, seed_source, send};

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
    seed_source(&svc, "src1");
    let channels = json!([
        {"id": "c1", "name": "C1",
         "stream_url": "http://x/1",
         "native_id": "n1",
         "source_id": "src1"},
        {"id": "c2", "name": "C2",
         "stream_url": "http://x/2",
         "native_id": "n2",
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
