//! WebSocket JSON-RPC-like protocol types.
//!
//! ## Wire format
//!
//! ### Request (Client → Server)
//! ```json
//! { "id": 1, "method": "get_channels", "params": { "source_id": 1 } }
//! ```
//!
//! ### Success response (Server → Client)
//! ```json
//! { "id": 1, "result": [...] }
//! ```
//!
//! ### Error response (Server → Client)
//! ```json
//! { "id": 1, "error": { "code": -32600, "message": "Invalid request" } }
//! ```
//!
//! ### Server-pushed event (Server → Client, no `id`)
//! ```json
//! { "event": { "type": "BulkDataRefresh" } }
//! ```
//!
//! ### Heartbeat ping/pong
//! ```json
//! { "ping": true }   // Client → Server
//! { "pong": true }   // Server → Client
//! ```

use serde::{Deserialize, Serialize};
use serde_json::Value;

// ── Standard error codes ─────────────────────────────

/// JSON-RPC 2.0 standard error codes.
pub mod error_codes {
    /// Parse error — invalid JSON was received.
    pub const PARSE_ERROR: i32 = -32700;
    /// Invalid request — required fields missing.
    pub const INVALID_REQUEST: i32 = -32600;
    /// Method not found.
    pub const METHOD_NOT_FOUND: i32 = -32601;
    /// Invalid params — method exists but params are wrong.
    pub const INVALID_PARAMS: i32 = -32602;
    /// Internal error — service or DB failure.
    pub const INTERNAL_ERROR: i32 = -32603;
}

// ── Request ──────────────────────────────────────────

/// Inbound JSON-RPC-style request from a WebSocket client.
#[derive(Debug, Deserialize)]
pub struct WsRequest {
    /// Caller-supplied correlation ID. Echoed back in the response.
    pub id: RequestId,
    /// Method name (e.g. `"get_channels"`, `"add_source"`).
    pub method: String,
    /// Optional parameters object. Methods that need no params
    /// may omit this field; handlers must treat `None` as `{}`.
    #[serde(default)]
    pub params: Value,
}

/// A request correlation ID — either an integer or a string.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(untagged)]
pub enum RequestId {
    Int(i64),
    Str(String),
}

// ── Response ─────────────────────────────────────────

/// Outbound response sent back to the requesting client.
#[derive(Debug, Serialize)]
pub struct WsResponse {
    /// Echoed correlation ID from the original request.
    pub id: RequestId,
    /// Present on success; absent on error.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<Value>,
    /// Present on error; absent on success.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<WsError>,
}

impl WsResponse {
    /// Build a success response.
    pub fn ok(id: RequestId, result: Value) -> Self {
        Self {
            id,
            result: Some(result),
            error: None,
        }
    }

    /// Build an error response with an explicit code.
    pub fn err(id: RequestId, code: i32, message: impl Into<String>) -> Self {
        Self {
            id,
            result: None,
            error: Some(WsError {
                code,
                message: message.into(),
            }),
        }
    }

    /// Convenience: internal error (code -32603).
    pub fn internal_error(id: RequestId, message: impl Into<String>) -> Self {
        Self::err(id, error_codes::INTERNAL_ERROR, message)
    }

    /// Convenience: method-not-found error (code -32601).
    pub fn method_not_found(id: RequestId, method: &str) -> Self {
        Self::err(
            id,
            error_codes::METHOD_NOT_FOUND,
            format!("Method not found: {method}"),
        )
    }

    /// Convenience: parse error (code -32700).
    pub fn parse_error(raw_id: Option<RequestId>, message: impl Into<String>) -> Self {
        Self::err(
            raw_id.unwrap_or(RequestId::Int(-1)),
            error_codes::PARSE_ERROR,
            message,
        )
    }

    /// Serialize the response to a JSON string.
    pub fn to_json(&self) -> String {
        serde_json::to_string(self).unwrap_or_else(|_| {
            r#"{"id":-1,"error":{"code":-32603,"message":"Serialization failure"}}"#.to_string()
        })
    }
}

// ── Error detail ─────────────────────────────────────

/// Error object embedded in a `WsResponse`.
#[derive(Debug, Serialize, Deserialize)]
pub struct WsError {
    pub code: i32,
    pub message: String,
}

// ── Server-pushed event ──────────────────────────────

/// An unsolicited event pushed from server to all connected clients.
#[derive(Debug, Serialize)]
pub struct WsEvent {
    pub event: Value,
}

impl WsEvent {
    pub fn new(event: Value) -> Self {
        Self { event }
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string(self)
            .unwrap_or_else(|_| r#"{"event":{"type":"BulkDataRefresh"}}"#.to_string())
    }
}

// ── Parse helper ─────────────────────────────────────

/// Parse a raw text message into a `WsRequest`.
///
/// Returns `Err` with a human-readable message if JSON is invalid
/// or required fields are missing.
pub fn parse_request(text: &str) -> Result<WsRequest, String> {
    serde_json::from_str(text).map_err(|e| format!("Parse error: {e}"))
}

// ── Tests ─────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    // ── parse_request ────────────────────────────────

    #[test]
    fn test_parse_request_returns_request_when_valid_json() {
        let text = r#"{"id":1,"method":"get_channels","params":{"source_id":2}}"#;
        let req = parse_request(text).unwrap();
        assert_eq!(req.id, RequestId::Int(1));
        assert_eq!(req.method, "get_channels");
        assert_eq!(req.params["source_id"], 2);
    }

    #[test]
    fn test_parse_request_returns_error_when_invalid_json() {
        let result = parse_request("not json");
        assert!(result.is_err());
    }

    #[test]
    fn test_parse_request_accepts_string_id() {
        let text = r#"{"id":"req-abc","method":"ping","params":{}}"#;
        let req = parse_request(text).unwrap();
        assert_eq!(req.id, RequestId::Str("req-abc".to_string()));
    }

    #[test]
    fn test_parse_request_defaults_params_to_null_when_omitted() {
        let text = r#"{"id":5,"method":"health"}"#;
        let req = parse_request(text).unwrap();
        assert!(req.params.is_null());
    }

    // ── WsResponse::ok ───────────────────────────────

    #[test]
    fn test_response_ok_serializes_result_field() {
        let resp = WsResponse::ok(RequestId::Int(1), json!({"channels": []}));
        let json: Value = serde_json::from_str(&resp.to_json()).unwrap();
        assert_eq!(json["id"], 1);
        assert!(json.get("result").is_some());
        assert!(json.get("error").is_none());
    }

    // ── WsResponse::err ──────────────────────────────

    #[test]
    fn test_response_err_serializes_error_field() {
        let resp = WsResponse::err(
            RequestId::Int(2),
            error_codes::METHOD_NOT_FOUND,
            "no such method",
        );
        let json: Value = serde_json::from_str(&resp.to_json()).unwrap();
        assert_eq!(json["id"], 2);
        assert!(json.get("error").is_some());
        assert!(json.get("result").is_none());
        assert_eq!(json["error"]["code"], error_codes::METHOD_NOT_FOUND);
    }

    #[test]
    fn test_method_not_found_includes_method_name() {
        let resp = WsResponse::method_not_found(RequestId::Int(3), "unknown_method");
        let json: Value = serde_json::from_str(&resp.to_json()).unwrap();
        assert!(
            json["error"]["message"]
                .as_str()
                .unwrap()
                .contains("unknown_method")
        );
    }

    #[test]
    fn test_parse_error_uses_minus_one_id_when_no_id() {
        let resp = WsResponse::parse_error(None, "bad json");
        let json: Value = serde_json::from_str(&resp.to_json()).unwrap();
        assert_eq!(json["id"], -1);
        assert_eq!(json["error"]["code"], error_codes::PARSE_ERROR);
    }

    // ── WsEvent ──────────────────────────────────────

    #[test]
    fn test_ws_event_serializes_event_field() {
        let ev = WsEvent::new(json!({"type": "ChannelAdded", "id": 42}));
        let json: Value = serde_json::from_str(&ev.to_json()).unwrap();
        assert_eq!(json["event"]["type"], "ChannelAdded");
    }

    // ── error_codes ──────────────────────────────────

    #[test]
    fn test_error_codes_are_negative() {
        assert!(error_codes::PARSE_ERROR < 0);
        assert!(error_codes::INVALID_REQUEST < 0);
        assert!(error_codes::METHOD_NOT_FOUND < 0);
        assert!(error_codes::INVALID_PARAMS < 0);
        assert!(error_codes::INTERNAL_ERROR < 0);
    }
}
