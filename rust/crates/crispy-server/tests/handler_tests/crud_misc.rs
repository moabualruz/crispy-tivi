//! CRUD tests for saved layouts, search history, reminders,
//! sync meta, bulk operations, and backup.

use serde_json::json;

use super::{make_svc, seed_source, send};

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
    seed_source(&svc, "src1");
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
    seed_source(&svc, "src1");
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
                "source_id": "src1",
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
    seed_source(&svc, "s1");
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
