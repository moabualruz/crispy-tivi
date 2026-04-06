//! CrispyTivi companion server for Flutter web
//! clients.
//!
//! Runs `crispy-core` business logic as a WebSocket
//! server. Flutter web connects to `/ws` instead of
//! using browser-local storage.
//!
//! ## Endpoints
//!
//! - `GET /health` — liveness probe
//! - `GET /proxy?url=<url>` — CORS relay proxy
//!   (images, M3U8 playlists with URL rewriting,
//!   TS segments)
//! - `GET /ws` — WebSocket upgrade
//!
//! ## Configuration
//!
//! - `CRISPY_DB_PATH` — SQLite path (default:
//!   `~/.crispytivi/crispy_tivi_v2.sqlite`)
//! - `CRISPY_PORT` — listen port (default: `8080`)

use std::sync::Arc;

use axum::{
    Router,
    extract::{
        Query, State, WebSocketUpgrade,
        ws::{Message, WebSocket},
    },
    http::{HeaderValue, StatusCode, header},
    response::IntoResponse,
    routing::{any, get},
};
use tokio::sync::broadcast;
use tokio::time;
use tower_http::cors::{AllowOrigin, CorsLayer};

use crispy_core::events::{DataChangeEvent, serialize_event};
use crispy_core::services::ServiceContext;
use crispy_server::handlers::handle_message;

// ── Shared state ────────────────────────────────────

/// Application state shared across handlers.
#[derive(Clone)]
struct AppState {
    ctx: ServiceContext,
    event_tx: broadcast::Sender<String>,
}

// ── Handlers ────────────────────────────────────────

/// Query parameters for the image proxy endpoint.
#[derive(serde::Deserialize)]
struct ProxyParams {
    url: String,
}

/// CORS relay proxy for browser-based playback.
///
/// Fetches the upstream URL server-side and re-serves the
/// content with CORS headers. For M3U8 playlists, rewrites
/// segment and key URLs to also route through the proxy.
///
/// Only allows `http://` and `https://` URLs to prevent SSRF.
async fn cors_proxy(Query(params): Query<ProxyParams>) -> impl IntoResponse {
    // Validate URL scheme to prevent SSRF
    if !params.url.starts_with("http://") && !params.url.starts_with("https://") {
        return StatusCode::BAD_REQUEST.into_response();
    }

    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(30))
        .build()
        .unwrap_or_default();

    match client.get(&params.url).send().await {
        Ok(resp) => {
            let content_type = resp
                .headers()
                .get("content-type")
                .and_then(|v| v.to_str().ok())
                .unwrap_or("application/octet-stream")
                .to_string();

            let is_m3u8 = content_type.contains("mpegurl")
                || params.url.ends_with(".m3u8")
                || params.url.ends_with(".m3u");

            match resp.bytes().await {
                Ok(bytes) => {
                    if is_m3u8 {
                        let body = String::from_utf8_lossy(&bytes);
                        let rewritten = rewrite_m3u8(&body, &params.url);
                        (
                            [
                                (
                                    header::CONTENT_TYPE,
                                    "application/vnd.apple.mpegurl".to_string(),
                                ),
                                (header::CACHE_CONTROL, "no-cache".to_string()),
                            ],
                            rewritten,
                        )
                            .into_response()
                    } else {
                        (
                            [
                                (header::CONTENT_TYPE, content_type),
                                (header::CACHE_CONTROL, "public, max-age=86400".to_string()),
                            ],
                            bytes,
                        )
                            .into_response()
                    }
                }
                Err(_) => StatusCode::BAD_GATEWAY.into_response(),
            }
        }
        Err(_) => StatusCode::BAD_GATEWAY.into_response(),
    }
}

// ── M3U8 rewriting ─────────────────────────────────

/// Rewrite URLs in an M3U8 playlist to route through
/// the CORS proxy.
fn rewrite_m3u8(body: &str, base_url: &str) -> String {
    let base_dir = base_url.rsplit_once('/').map_or(base_url, |(dir, _)| dir);

    body.lines()
        .map(|line| {
            let trimmed = line.trim();
            if trimmed.is_empty() {
                return line.to_string();
            }
            if trimmed.starts_with('#') {
                return rewrite_tag_uri(line, base_dir);
            }
            // Segment URL line
            let absolute = resolve_url(trimmed, base_dir);
            format!(
                "/proxy?url={}",
                percent_encoding::utf8_percent_encode(
                    &absolute,
                    percent_encoding::NON_ALPHANUMERIC,
                )
            )
        })
        .collect::<Vec<_>>()
        .join("\n")
}

/// Resolve a potentially relative URL against a base
/// directory URL.
fn resolve_url(url: &str, base_dir: &str) -> String {
    if url.starts_with("http://") || url.starts_with("https://") {
        return url.to_string();
    }
    if url.starts_with('/') {
        // Root-relative — extract scheme + host from base.
        if let Some(idx) = base_dir.find("://")
            && let Some(host_end) = base_dir[idx + 3..].find('/')
        {
            return format!("{}{url}", &base_dir[..idx + 3 + host_end]);
        }
        return format!("{base_dir}{url}");
    }
    // Relative — append to base directory.
    format!("{base_dir}/{url}")
}

/// Rewrite `URI="..."` attributes in M3U8 tags
/// (`#EXT-X-KEY`, `#EXT-X-MAP`, etc.).
fn rewrite_tag_uri(line: &str, base_dir: &str) -> String {
    if let Some(uri_start) = line.find("URI=\"") {
        let after_uri = &line[uri_start + 5..];
        if let Some(uri_end) = after_uri.find('"') {
            let uri = &after_uri[..uri_end];
            let absolute = resolve_url(uri, base_dir);
            let encoded = percent_encoding::utf8_percent_encode(
                &absolute,
                percent_encoding::NON_ALPHANUMERIC,
            );
            return format!(
                "{}URI=\"/proxy?url={}\"{}",
                &line[..uri_start],
                encoded,
                &line[uri_start + 5 + uri_end + 1..],
            );
        }
    }
    line.to_string()
}

/// Health check endpoint.
async fn health() -> impl IntoResponse {
    concat!("crispy-server ", env!("CARGO_PKG_VERSION"))
}

/// WebSocket upgrade handler.
async fn ws_upgrade(State(state): State<AppState>, ws: WebSocketUpgrade) -> impl IntoResponse {
    ws.on_upgrade(move |socket| ws_handler(socket, state))
}

/// Process WebSocket messages for a single client,
/// and forward server-pushed events via broadcast.
async fn ws_handler(mut socket: WebSocket, state: AppState) {
    let mut event_rx = state.event_tx.subscribe();
    let mut heartbeat = time::interval(time::Duration::from_secs(30));
    // Skip the first immediate tick so the ping fires
    // 30 seconds after connection, not immediately.
    heartbeat.tick().await;

    loop {
        tokio::select! {
            msg = socket.recv() => {
                let msg = match msg {
                    Some(Ok(m)) => m,
                    _ => break,
                };
                match msg {
                    Message::Text(text) => {
                        // Handle client-side JSON ping
                        if let Ok(parsed) =
                            serde_json::from_str::<serde_json::Value>(&text)
                            && parsed.get("ping").is_some()
                        {
                            let pong = r#"{"pong":true}"#;
                            if socket
                                .send(Message::Text(pong.into()))
                                .await
                                .is_err()
                            {
                                break;
                            }
                            continue;
                        }

                        let ctx = state.ctx.clone();
                        let text_clone = text.clone();
                        let resp =
                            tokio::task::spawn_blocking(
                                move || {
                                    handle_message(
                                        &ctx,
                                        &text_clone,
                                    )
                                },
                            )
                            .await
                            .unwrap_or_else(|_| {
                                "{\"error\":\"Internal task panic\"}"
                                    .to_string()
                            });
                        if socket
                            .send(Message::Text(resp.into()))
                            .await
                            .is_err()
                        {
                            break;
                        }
                    }
                    Message::Close(_) => break,
                    _ => {}
                }
            }
            event = event_rx.recv() => {
                match event {
                    Ok(json) => {
                        let push = format!(
                            r#"{{"event":{json}}}"#
                        );
                        if socket
                            .send(Message::Text(push.into()))
                            .await
                            .is_err()
                        {
                            break;
                        }
                    }
                    Err(broadcast::error::RecvError::Lagged(_)) => {
                        let fallback =
                            r#"{"event":{"type":"BulkDataRefresh"}}"#;
                        let _ = socket
                            .send(Message::Text(
                                fallback.into(),
                            ))
                            .await;
                    }
                    Err(_) => break,
                }
            }
            _ = heartbeat.tick() => {
                // Send a WebSocket-protocol ping frame every 30s.
                // Proxies/firewalls use this to keep connections alive.
                if socket
                    .send(Message::Ping(vec![].into()))
                    .await
                    .is_err()
                {
                    break;
                }
            }
        }
    }
}

// ── CORS configuration ──────────────────────────────

/// Build a CORS layer from `CRISPY_ALLOWED_ORIGINS` env var.
///
/// - Unset / empty → allow any origin (dev mode).
/// - Set → restrict to the comma-separated list of origins.
fn build_cors_layer() -> CorsLayer {
    let base = CorsLayer::new()
        .allow_methods(tower_http::cors::Any)
        .allow_headers(tower_http::cors::Any);

    match std::env::var("CRISPY_ALLOWED_ORIGINS").ok().as_deref() {
        None | Some("") => base.allow_origin(tower_http::cors::Any),
        Some(origins) => {
            let list: Vec<HeaderValue> = origins
                .split(',')
                .filter_map(|o| o.trim().parse::<HeaderValue>().ok())
                .collect();
            if list.is_empty() {
                base.allow_origin(tower_http::cors::Any)
            } else {
                base.allow_origin(AllowOrigin::list(list))
            }
        }
    }
}

// ── DB path resolution ──────────────────────────────

/// Resolve the database path from env or default.
fn resolve_db_path() -> String {
    if let Ok(p) = std::env::var("CRISPY_DB_PATH") {
        return p;
    }
    // Default: ~/.crispytivi/data/crispy_tivi_v2.sqlite
    let home = std::env::var("HOME")
        .or_else(|_| std::env::var("USERPROFILE"))
        .unwrap_or_else(|_| ".".to_string());
    let dir = format!("{home}/.crispytivi/data");
    // Ensure the directory exists.
    let _ = std::fs::create_dir_all(&dir);
    format!("{dir}/crispy_tivi_v2.sqlite")
}

/// Resolve the port from CLI args, env, config json, or default 8080.
fn resolve_port() -> u16 {
    // 1. Check CLI args: --port <number>
    let mut args = std::env::args();
    while let Some(arg) = args.next() {
        if arg == "--port"
            && let Some(port_str) = args.next()
            && let Ok(port) = port_str.parse()
        {
            return port;
        }
    }

    // 2. Check Environment Variable
    if let Ok(port_str) = std::env::var("CRISPY_PORT")
        && let Ok(port) = port_str.parse()
    {
        return port;
    }

    // 3. Fallback to `assets/config/app_config.json` if available
    if let Ok(config_str) = std::fs::read_to_string("../../assets/config/app_config.json")
        && let Ok(json) = serde_json::from_str::<serde_json::Value>(&config_str)
        && let Some(port) = json
            .get("api")
            .and_then(|a| a.get("backendPort"))
            .and_then(serde_json::Value::as_u64)
    {
        return port as u16;
    }

    // 4. Default
    8080
}

// ── Main ────────────────────────────────────────────

#[tokio::main]
async fn main() {
    let db_path = resolve_db_path();
    let port = resolve_port();

    println!("DB path: {db_path}");

    let ctx = ServiceContext::open(&db_path).expect("Failed to open database");

    let (event_tx, _) = broadcast::channel::<String>(256);
    let tx_clone = event_tx.clone();
    ctx.set_event_callback(Arc::new(move |event: &DataChangeEvent| {
        let json = serialize_event(event);
        let _ = tx_clone.send(json);
    }));

    let state = AppState { ctx, event_tx };

    let cors = build_cors_layer();

    let app = Router::new()
        .route("/health", get(health))
        .route("/proxy", get(cors_proxy))
        .route("/ws", get(ws_upgrade))
        .fallback(any(|| async { (StatusCode::NOT_FOUND, "Not Found") }))
        .with_state(state)
        .layer(cors);

    let addr = format!("0.0.0.0:{port}");
    println!("CrispyTivi server listening on :{port}");

    let listener = tokio::net::TcpListener::bind(&addr)
        .await
        .unwrap_or_else(|e| panic!("Failed to bind {addr}: {e}"));

    axum::serve(listener, app).await.expect("Server error");
}
