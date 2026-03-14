//! Error handling tests for command dispatcher.

use serde_json::json;

use super::{make_svc, send, send_raw};

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
