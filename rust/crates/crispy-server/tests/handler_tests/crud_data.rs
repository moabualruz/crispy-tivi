//! CRUD tests for EPG, watch history, recordings,
//! storage backends, and transfer tasks.

use serde_json::json;

use super::{make_svc, send};

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

    let resp = send(
        &svc,
        &json!({"cmd": "loadRecordings", "id": "r2", "args": {"profileId": "default", "role": "admin"}}),
    );
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
            "args": {"id": "rec1", "profileId": "default", "role": "admin"},
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
