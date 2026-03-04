//! WebSocket message handlers.
//!
//! Maps incoming WebSocket commands to `crispy-core`
//! service calls and returns JSON responses.
//!
//! Protocol:
//! ```json
//! // Client -> Server
//! {"cmd":"loadChannels","id":"req-1"}
//! {"cmd":"setSetting","id":"req-2",
//!  "args":{"key":"theme","value":"dark"}}
//!
//! // Server -> Client
//! {"id":"req-1","data":[...]}
//! {"id":"req-2","ok":true}
//! {"id":"req-3","error":"Not found"}
//! ```

mod algorithms;
mod crud;
mod parsers;

use anyhow::{Context, Result, anyhow};
use serde_json::{Value, json};

use crispy_core::services::CrispyService;

// ── Arg extraction helpers ──────────────────────────

/// Extract a required string from `args`.
pub(super) fn get_str(args: &Value, key: &str) -> Result<String> {
    args.get(key)
        .and_then(|v| v.as_str())
        .map(|s| s.to_string())
        .ok_or_else(|| anyhow!("Missing string arg: {key}"))
}

/// Extract an optional string from `args`.
pub(super) fn get_str_opt(args: &Value, key: &str) -> Result<Option<String>> {
    match args.get(key) {
        Some(Value::Null) | None => Ok(None),
        Some(v) => Ok(Some(
            v.as_str()
                .ok_or_else(|| anyhow!("{key} is not a string"))?
                .to_string(),
        )),
    }
}

/// Extract a required i64 from `args`.
pub(super) fn get_i64(args: &Value, key: &str) -> Result<i64> {
    args.get(key)
        .and_then(|v| v.as_i64())
        .ok_or_else(|| anyhow!("Missing i64 arg: {key}"))
}

/// Extract a required `Vec<String>` from `args`.
pub(super) fn get_str_vec(args: &Value, key: &str) -> Result<Vec<String>> {
    let arr = args
        .get(key)
        .and_then(|v| v.as_array())
        .ok_or_else(|| anyhow!("Missing array arg: {key}"))?;
    arr.iter()
        .map(|v| {
            v.as_str()
                .map(|s| s.to_string())
                .ok_or_else(|| anyhow!("{key} contains non-string"))
        })
        .collect()
}

/// Extract the `args` object, defaulting to `{}`.
fn get_args(msg: &Value) -> Value {
    msg.get("args").cloned().unwrap_or(json!({}))
}

// ── Timestamp conversion ────────────────────────────

/// Convert Unix timestamp (seconds) to NaiveDateTime.
pub(super) fn ts_to_dt(ts: i64) -> Result<chrono::NaiveDateTime> {
    chrono::DateTime::from_timestamp(ts, 0)
        .map(|dt| dt.naive_utc())
        .ok_or_else(|| anyhow!("Invalid timestamp: {ts}"))
}

// ── Main dispatch ───────────────────────────────────

/// Handle a single WebSocket text message.
///
/// Returns the JSON response string to send back.
pub fn handle_message(svc: &CrispyService, text: &str) -> String {
    let result = dispatch(svc, text);
    match result {
        Ok(resp) => resp.to_string(),
        Err(e) => json!({"error": e.to_string()}).to_string(),
    }
}

/// Parse and dispatch a command message.
fn dispatch(svc: &CrispyService, text: &str) -> Result<Value> {
    let msg: Value = serde_json::from_str(text).context("Invalid JSON")?;

    let id = msg.get("id").cloned().unwrap_or(Value::Null);

    let cmd = msg
        .get("cmd")
        .and_then(|v| v.as_str())
        .ok_or_else(|| anyhow!("Missing cmd"))?;

    let args = get_args(&msg);

    let result = exec_cmd(svc, cmd, &args);

    match result {
        Ok(data) => {
            let mut resp = json!({"id": id});
            // Merge data fields into response
            if let Value::Object(map) = data {
                for (k, v) in map {
                    resp[&k] = v;
                }
            }
            Ok(resp)
        }
        Err(e) => Ok(json!({
            "id": id,
            "error": e.to_string(),
        })),
    }
}

/// Execute a single command against the service.
fn exec_cmd(svc: &CrispyService, cmd: &str, args: &Value) -> Result<Value> {
    if let Some(r) = crud::handle(svc, cmd, args) {
        return r;
    }
    if let Some(r) = parsers::handle(svc, cmd, args) {
        return r;
    }
    if let Some(r) = algorithms::handle(svc, cmd, args) {
        return r;
    }
    Err(anyhow!("Unknown command: {cmd}"))
}
