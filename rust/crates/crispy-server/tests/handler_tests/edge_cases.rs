//! Edge case tests for command dispatcher.

use serde_json::{Value, json};

use super::{make_svc, send};

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
