//! Integration tests for WebSocket command handlers.
//!
//! Each test creates an in-memory `CrispyService`,
//! wraps it in `Arc<Mutex<_>>`, and calls
//! `handle_message` directly — no WebSocket needed.

use crispy_core::services::ServiceContext;
use crispy_server::handlers::handle_message;
use serde_json::Value;

#[path = "handler_tests/algorithms.rs"]
mod algorithms;
#[path = "handler_tests/crud_core.rs"]
mod crud_core;
#[path = "handler_tests/crud_data.rs"]
mod crud_data;
#[path = "handler_tests/crud_media.rs"]
mod crud_media;
#[path = "handler_tests/crud_misc.rs"]
mod crud_misc;
#[path = "handler_tests/edge_cases.rs"]
mod edge_cases;
#[path = "handler_tests/error_handling.rs"]
mod error_handling;
#[path = "handler_tests/parsers.rs"]
mod parsers;

// ── Helpers ────────────────────────────────────────

/// Create a fresh in-memory service.
pub fn make_svc() -> ServiceContext {
    ServiceContext::open_in_memory().expect("open in-memory")
}

/// Send a JSON command and parse the response.
pub fn send(svc: &ServiceContext, msg: &Value) -> Value {
    let resp = handle_message(svc, &msg.to_string());
    serde_json::from_str(&resp).expect("Response is valid JSON")
}

/// Send a raw string and parse the response.
pub fn send_raw(svc: &ServiceContext, text: &str) -> Value {
    let resp = handle_message(svc, text);
    serde_json::from_str(&resp).expect("Response is valid JSON")
}

/// Seed a source so FK constraints on channels/VOD/categories/etc. pass.
pub fn seed_source(svc: &ServiceContext, id: &str) {
    use serde_json::json;
    let resp = send(
        svc,
        &json!({
            "cmd": "saveSource",
            "id": "seed",
            "args": {
                "id": id,
                "name": format!("Test Source {id}"),
                "source_type": "m3u",
                "url": format!("http://example.com/{id}.m3u"),
            },
        }),
    );
    assert!(
        resp.get("error").is_none(),
        "seed_source({id}) failed: {resp}",
    );
}
