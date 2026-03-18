//! axum WebSocket upgrade handler and per-connection session.
//!
//! Integrates `ws_protocol` message parsing with the `handlers`
//! dispatch layer and broadcasts server-pushed events to all
//! connected clients via a `tokio::sync::broadcast` channel.

use axum::{
    extract::{
        State, WebSocketUpgrade,
        ws::{Message, WebSocket},
    },
    response::IntoResponse,
};
use tokio::sync::broadcast;
use tokio::time;

use crate::handlers::handle_message;
use crate::ws_protocol::{RequestId, WsEvent, WsResponse, parse_request};
use crispy_core::services::CrispyService;

// ── Shared application state ─────────────────────────

/// Application state injected by axum's `State` extractor.
///
/// Cloned per-request; all fields are cheap-to-clone handles.
#[derive(Clone)]
pub struct WsState {
    /// Service handle — all domain operations go through here.
    pub svc: CrispyService,
    /// Broadcast channel for server-pushed data-change events.
    /// The standalone binary (or `crispy-ui` server mode) creates
    /// the sender; each WS connection subscribes to a receiver.
    pub event_tx: broadcast::Sender<String>,
}

impl WsState {
    pub fn new(svc: CrispyService) -> (Self, broadcast::Sender<String>) {
        let (event_tx, _) = broadcast::channel(256);
        let state = Self {
            svc,
            event_tx: event_tx.clone(),
        };
        (state, event_tx)
    }
}

// ── axum upgrade handler ─────────────────────────────

/// axum route handler: upgrades the HTTP connection to WebSocket
/// and hands it to `run_connection`.
pub async fn ws_upgrade(State(state): State<WsState>, ws: WebSocketUpgrade) -> impl IntoResponse {
    ws.on_upgrade(move |socket| run_connection(socket, state))
}

// ── Per-connection loop ──────────────────────────────

/// Handle a single connected WebSocket client.
///
/// Responsibilities:
/// - Parse incoming JSON-RPC messages and route them via `handle_message`.
/// - Respond to JSON-level `{"ping":true}` keep-alives with `{"pong":true}`.
/// - Send a WebSocket-protocol `Ping` frame every 30 s (proxy/firewall keepalive).
/// - Forward broadcast events (server-pushed changes) to the client.
/// - On `RecvError::Lagged`, send a `BulkDataRefresh` fallback event.
async fn run_connection(mut socket: WebSocket, state: WsState) {
    let mut event_rx = state.event_tx.subscribe();
    let mut heartbeat = time::interval(time::Duration::from_secs(30));
    // Skip the first immediate tick so the WS ping fires 30s after
    // connection, not right away.
    heartbeat.tick().await;

    loop {
        tokio::select! {
            msg = socket.recv() => {
                let msg = match msg {
                    Some(Ok(m)) => m,
                    _ => break, // client disconnected or error
                };

                match msg {
                    Message::Text(text) => {
                        let reply = process_text_message(&state.svc, &text);
                        if socket.send(Message::Text(reply.into())).await.is_err() {
                            break;
                        }
                    }
                    Message::Close(_) => break,
                    // Binary, Ping, Pong frames — no action needed.
                    _ => {}
                }
            }

            event = event_rx.recv() => {
                match event {
                    Ok(json) => {
                        // `json` is already a serialized JSON string of the
                        // DataChangeEvent; wrap it in an event envelope.
                        let ev_json = match serde_json::from_str::<serde_json::Value>(&json) {
                            Ok(v) => WsEvent::new(v).to_json(),
                            Err(_) => WsEvent::new(serde_json::json!({"type":"BulkDataRefresh"})).to_json(),
                        };
                        if socket.send(Message::Text(ev_json.into())).await.is_err() {
                            break;
                        }
                    }
                    Err(broadcast::error::RecvError::Lagged(_)) => {
                        // Too many events missed — tell the client to do a full reload.
                        let fallback = WsEvent::new(
                            serde_json::json!({"type":"BulkDataRefresh"})
                        ).to_json();
                        let _ = socket.send(Message::Text(fallback.into())).await;
                    }
                    Err(_) => break,
                }
            }

            _ = heartbeat.tick() => {
                if socket.send(Message::Ping(vec![].into())).await.is_err() {
                    break;
                }
            }
        }
    }
}

// ── Message processing ───────────────────────────────

/// Parse one text frame and return the JSON string to send back.
///
/// Handles:
/// - `{"ping":true}` → `{"pong":true}` (JSON-level heartbeat)
/// - Valid JSON-RPC request → dispatched via `handle_message`
/// - Invalid JSON → JSON-RPC parse error response
fn process_text_message(svc: &CrispyService, text: &str) -> String {
    // Fast path: JSON-level ping (used by WASM clients that can't send
    // raw WebSocket Ping frames).
    if let Ok(v) = serde_json::from_str::<serde_json::Value>(text)
        && v.get("ping").is_some()
    {
        return r#"{"pong":true}"#.to_string();
    }

    // Parse into WsRequest so we can echo `id` in any error response.
    // If parsing fails we still need an id to satisfy the protocol; use -1.
    match parse_request(text) {
        Ok(req) => {
            let id = req.id.clone();
            // Delegate to the existing handlers dispatch (which uses the
            // old `{"cmd":...}` format internally).  The handlers layer
            // returns a complete JSON response string.
            //
            // TODO: once all callers migrate to the JSON-RPC format,
            // pass `req` directly instead of the raw text.
            let raw = handle_message(svc, text);

            // If the handler already returned an error envelope, pass it through.
            // Otherwise, re-wrap to ensure the `id` field is present.
            match serde_json::from_str::<serde_json::Value>(&raw) {
                Ok(v) if v.get("error").is_some() => {
                    let msg = v["error"].as_str().unwrap_or("internal error").to_string();
                    WsResponse::internal_error(id, msg).to_json()
                }
                Ok(v) => {
                    // Wrap the handler's result under the `result` key.
                    let result = v.get("data").cloned().unwrap_or(v);
                    WsResponse::ok(id, result).to_json()
                }
                Err(_) => WsResponse::internal_error(id, "handler response was not JSON").to_json(),
            }
        }
        Err(parse_err) => {
            // Could not parse the id — use -1.
            WsResponse::parse_error(Some(RequestId::Int(-1)), parse_err).to_json()
        }
    }
}

// ── Tests ─────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ws_protocol::error_codes;
    use crispy_core::services::CrispyService;

    fn make_svc() -> CrispyService {
        CrispyService::open_in_memory().expect("in-memory DB")
    }

    #[test]
    fn test_process_text_message_returns_pong_for_ping() {
        let svc = make_svc();
        let resp = process_text_message(&svc, r#"{"ping":true}"#);
        assert_eq!(resp, r#"{"pong":true}"#);
    }

    #[test]
    fn test_process_text_message_returns_parse_error_for_invalid_json() {
        let svc = make_svc();
        let resp = process_text_message(&svc, "not json");
        let v: serde_json::Value = serde_json::from_str(&resp).unwrap();
        assert!(v.get("error").is_some());
        assert_eq!(v["error"]["code"], error_codes::PARSE_ERROR);
    }

    #[test]
    fn test_process_text_message_echoes_id_in_response() {
        let svc = make_svc();
        // "loadChannels" is a known command; should return a result.
        let req = r#"{"id":42,"method":"loadChannels","params":{}}"#;
        let resp = process_text_message(&svc, req);
        let v: serde_json::Value = serde_json::from_str(&resp).unwrap();
        assert_eq!(v["id"], 42);
    }

    #[test]
    fn test_ws_state_new_creates_valid_state() {
        let svc = make_svc();
        let (state, _tx) = WsState::new(svc);
        // Sender should work (receiver count starts at 0 after we drop _tx's receiver).
        assert_eq!(state.event_tx.receiver_count(), 0);
    }
}
