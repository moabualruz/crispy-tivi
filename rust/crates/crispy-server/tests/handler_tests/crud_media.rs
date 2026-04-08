//! CRUD tests for VOD items, VOD favorites, categories,
//! favorite categories, source access, and channel order.

use serde_json::json;

use super::{make_svc, seed_source, send};

// ── CRUD: VOD Items ────────────────────────────────

#[test]
fn save_and_load_vod_items() {
    let svc = make_svc();
    seed_source(&svc, "src1");
    let item = json!({
        "id": "v1",
        "name": "Movie One",
        "stream_url": "http://x/movie1",
        "type": "movie",
        "source_id": "src1",
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
    seed_source(&svc, "src1");
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

#[test]
fn save_vod_items_with_missing_native_id_keeps_distinct_rows() {
    let svc = make_svc();
    seed_source(&svc, "src1");
    let resp = send(
        &svc,
        &json!({
            "cmd": "saveVodItems",
            "id": "r1",
            "args": {"items": [
                {
                    "id": "v1",
                    "name": "Movie One",
                    "stream_url": "http://x/movie1",
                    "type": "movie",
                    "source_id": "src1",
                    "native_id": ""
                },
                {
                    "id": "v2",
                    "name": "Movie Two",
                    "stream_url": "http://x/movie2",
                    "type": "movie",
                    "source_id": "src1",
                    "native_id": ""
                }
            ]},
        }),
    );
    assert_eq!(resp["ok"], true);
    assert_eq!(resp["count"], 2);

    let resp = send(&svc, &json!({"cmd": "loadVodItems", "id": "r2"}));
    let data = resp["data"].as_array().unwrap();
    assert_eq!(data.len(), 2);
    assert!(data.iter().any(|item| item["id"] == "v1"));
    assert!(data.iter().any(|item| item["id"] == "v2"));
}

// ── CRUD: VOD Favorites ───────────────────────────

#[test]
fn add_and_get_vod_favorites() {
    let svc = make_svc();
    seed_source(&svc, "src1");
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
                "source_id": "src1",
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
    seed_source(&svc, "src1");
    let cats = json!({
        "live": ["News", "Sports"],
        "vod": ["Action"],
    });
    let resp = send(
        &svc,
        &json!({
            "cmd": "saveCategories",
            "id": "r1",
            "args": {"sourceId": "src1", "categories": cats},
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
    seed_source(&svc, "s1");
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
    seed_source(&svc, "s1");
    seed_source(&svc, "s2");
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
    // Seed FK dependencies: source → channels, profile.
    seed_source(&svc, "src1");
    send(
        &svc,
        &json!({
            "cmd": "saveProfile",
            "id": "sp",
            "args": {"profile": {"id": "p1", "name": "User"}},
        }),
    );
    send(
        &svc,
        &json!({
            "cmd": "saveChannels",
            "id": "sc",
            "args": {"channels": [
                {"id": "c1", "name": "C1", "stream_url": "http://x/1",
                 "native_id": "n1", "source_id": "src1"},
                {"id": "c2", "name": "C2", "stream_url": "http://x/2",
                 "native_id": "n2", "source_id": "src1"},
                {"id": "c3", "name": "C3", "stream_url": "http://x/3",
                 "native_id": "n3", "source_id": "src1"},
            ]},
        }),
    );
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
