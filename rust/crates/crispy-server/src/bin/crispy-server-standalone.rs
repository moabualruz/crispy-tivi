//! CrispyTivi standalone headless server.
//!
//! Runs `crispy-core` business logic as a WebSocket
//! server. Browser (Slint WASM) clients connect to
//! `/ws` for API access.
//!
//! ## Endpoints (HTTP server, `--port`)
//!
//! - `GET /health`        — liveness probe
//! - `GET /proxy?url=<u>` — CORS relay proxy (images, M3U8, TS)
//! - `GET /ws`            — WebSocket upgrade (API)
//! - `GET /`              — Static WASM files (when `--static-dir` set)
//!
//! ## WebSocket server (`--ws-port`)
//!
//! Dedicated port for WebSocket-only clients that want to avoid
//! sharing a port with the HTTP static-file server.
//! Serves only `/ws`.
//!
//! ## Configuration (CLI args take precedence over env vars)
//!
//! | CLI arg          | Env var                 | Default                             |
//! |------------------|-------------------------|-------------------------------------|
//! | `--port`         | `CRISPY_HTTP_PORT`      | `8080`                              |
//! | `--ws-port`      | `CRISPY_WS_PORT`        | `8081`                              |
//! | `--static-dir`   | `CRISPY_STATIC_DIR`     | *(unset — static serving disabled)* |
//! | `--db`           | `CRISPY_DB_PATH`        | `~/.crispytivi/data/…sqlite`        |

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
use tower_http::services::ServeDir;

use crispy_core::events::{DataChangeEvent, serialize_event};
use crispy_core::services::CrispyService;
use crispy_server::config::ServerConfig;
use crispy_server::handlers::handle_message;

// ── Shared state ────────────────────────────────────

/// Application state shared across handlers.
#[derive(Clone)]
struct AppState {
    svc: CrispyService,
    event_tx: broadcast::Sender<String>,
}

// ── Handlers ────────────────────────────────────────

/// Query parameters for the image proxy endpoint.
#[derive(serde::Deserialize)]
struct ProxyParams {
    url: String,
}

/// Returns `true` if the host string resolves to a private/loopback address
/// that must not be reachable via the proxy (SSRF prevention).
fn is_private_host(host: &str) -> bool {
    use std::net::IpAddr;
    use std::str::FromStr;

    // Reject plain "localhost" and any *.local / *.internal hostnames.
    let lower = host.to_ascii_lowercase();
    if lower == "localhost"
        || lower.ends_with(".local")
        || lower.ends_with(".internal")
        || lower.ends_with(".localhost")
    {
        return true;
    }

    // Parse as an IP address and check against private/reserved ranges.
    if let Ok(addr) = IpAddr::from_str(host) {
        return match addr {
            IpAddr::V4(v4) => {
                let o = v4.octets();
                // 127.0.0.0/8  — loopback
                o[0] == 127
                // 10.0.0.0/8   — RFC-1918
                || o[0] == 10
                // 172.16.0.0/12 — RFC-1918
                || (o[0] == 172 && (16..=31).contains(&o[1]))
                // 192.168.0.0/16 — RFC-1918
                || (o[0] == 192 && o[1] == 168)
                // 169.254.0.0/16 — link-local
                || (o[0] == 169 && o[1] == 254)
            }
            IpAddr::V6(v6) => {
                // ::1 loopback
                v6.is_loopback()
                // fd00::/8 — unique local (ULA)
                || v6.segments()[0] & 0xfe00 == 0xfc00
            }
        };
    }

    false
}

/// Validates a proxy target URL for SSRF safety (C-009).
///
/// Returns `Ok(())` when the URL is acceptable, or `Err(message)` with
/// a human-readable explanation of why it was rejected.
fn validate_proxy_url(raw: &str) -> Result<(), String> {
    let parsed = url::Url::parse(raw).map_err(|e| format!("Malformed URL: {e}"))?;

    match parsed.scheme() {
        "http" | "https" => {}
        scheme => {
            return Err(format!(
                "URL scheme '{scheme}' is not allowed; only http and https are permitted"
            ));
        }
    }

    let host = parsed
        .host_str()
        .ok_or_else(|| "URL has no host".to_string())?;

    if is_private_host(host) {
        return Err(format!(
            "URL host '{host}' resolves to a private or reserved address and cannot be proxied"
        ));
    }

    Ok(())
}

/// CORS relay proxy for browser-based playback.
///
/// Fetches the upstream URL server-side and re-serves the
/// content with CORS headers. For M3U8 playlists, rewrites
/// segment and key URLs to also route through the proxy.
///
/// Only `http://` and `https://` URLs targeting public hosts are allowed
/// (SSRF prevention — C-009).
async fn cors_proxy(Query(params): Query<ProxyParams>) -> impl IntoResponse {
    // Validate URL: scheme + private-IP check (C-009).
    if let Err(reason) = validate_proxy_url(&params.url) {
        tracing::warn!(
            security = "ssrf_block",
            url = %params.url,
            reason = %reason,
            "Proxy request rejected"
        );
        return (StatusCode::BAD_REQUEST, reason).into_response();
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

                        let svc = state.svc.clone();
                        let text_clone = text.clone();
                        let resp =
                            tokio::task::spawn_blocking(
                                move || {
                                    handle_message(
                                        &svc,
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

/// Build a CORS layer from a comma-separated origins string.
///
/// - Empty string → allow any origin (dev mode).
/// - Non-empty   → restrict to the listed origins.
fn build_cors_layer(origins: &str) -> CorsLayer {
    let base = CorsLayer::new()
        .allow_methods(tower_http::cors::Any)
        .allow_headers(tower_http::cors::Any);

    if origins.is_empty() {
        return base.allow_origin(tower_http::cors::Any);
    }

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

// ── CLI arg parsing ──────────────────────────────────

/// Parse CLI arguments, overlaying on top of `ServerConfig::from_env()`.
///
/// Recognized flags (all optional):
/// - `--port <u16>`        HTTP server port
/// - `--ws-port <u16>`     WebSocket-only server port
/// - `--static-dir <path>` Directory of WASM static files to serve
/// - `--db <path>`         SQLite database path
fn parse_cli_args(mut cfg: ServerConfig) -> ServerConfig {
    let mut args = std::env::args().peekable();
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--port" => {
                if let Some(v) = args.next()
                    && let Ok(p) = v.parse()
                {
                    cfg.http_port = p;
                }
            }
            "--ws-port" => {
                if let Some(v) = args.next()
                    && let Ok(p) = v.parse()
                {
                    cfg.ws_port = p;
                }
            }
            "--static-dir" => {
                if let Some(v) = args.next() {
                    cfg.static_dir = Some(v);
                }
            }
            "--db" => {
                if let Some(v) = args.next() {
                    cfg.db_path = v;
                }
            }
            _ => {}
        }
    }
    cfg
}

// ── Main ────────────────────────────────────────────

#[tokio::main]
async fn main() {
    // Config: env vars first, then CLI args override.
    let cfg = parse_cli_args(ServerConfig::from_env());

    println!("CrispyTivi standalone server");
    println!("  DB path   : {}", cfg.db_path);
    println!("  HTTP port : {}", cfg.http_port);
    println!("  WS port   : {}", cfg.ws_port);
    if let Some(ref dir) = cfg.static_dir {
        println!("  Static dir: {dir}");
    }

    let service = CrispyService::open(&cfg.db_path).expect("Failed to open database");

    let (event_tx, _) = broadcast::channel::<String>(256);
    let tx_clone = event_tx.clone();
    service.set_event_callback(Arc::new(move |event: &DataChangeEvent| {
        let json = serialize_event(event);
        let _ = tx_clone.send(json);
    }));

    let state = AppState {
        svc: service,
        event_tx: event_tx.clone(),
    };

    let cors = build_cors_layer(&cfg.cors_origins);

    // ── HTTP server router ───────────────────────────
    // Includes health, proxy, WS, and optional static files.
    let mut http_router = Router::new()
        .route("/health", get(health))
        .route("/proxy", get(cors_proxy))
        .route("/ws", get(ws_upgrade));

    if let Some(ref static_dir) = cfg.static_dir {
        // Serve static WASM build output.  `ServeDir` automatically
        // serves `index.html` for directory requests.
        http_router = http_router.nest_service("/", ServeDir::new(static_dir));
    } else {
        http_router = http_router.fallback(any(|| async { (StatusCode::NOT_FOUND, "Not Found") }));
    }

    let http_app = http_router.with_state(state.clone()).layer(cors.clone());

    // ── WS-only server router ────────────────────────
    // Dedicated port so WASM clients can connect to `/ws` directly
    // without sharing the static-file port.
    let ws_app = Router::new()
        .route("/ws", get(ws_upgrade))
        .route("/health", get(health))
        .fallback(any(|| async { (StatusCode::NOT_FOUND, "Not Found") }))
        .with_state(state)
        .layer(cors);

    // ── Bind both listeners ──────────────────────────
    let http_addr = format!("0.0.0.0:{}", cfg.http_port);
    let ws_addr = format!("0.0.0.0:{}", cfg.ws_port);

    let http_listener = tokio::net::TcpListener::bind(&http_addr)
        .await
        .unwrap_or_else(|e| panic!("Failed to bind HTTP {http_addr}: {e}"));

    let ws_listener = tokio::net::TcpListener::bind(&ws_addr)
        .await
        .unwrap_or_else(|e| panic!("Failed to bind WS {ws_addr}: {e}"));

    println!("HTTP server listening on http://{http_addr}");
    println!("WS   server listening on ws://{ws_addr}/ws");

    // ── Graceful shutdown ────────────────────────────
    // Both servers shut down together when SIGINT or SIGTERM arrives.
    let shutdown = async {
        let ctrl_c = async {
            tokio::signal::ctrl_c()
                .await
                .expect("Failed to install Ctrl+C handler");
        };

        #[cfg(unix)]
        let sigterm = async {
            tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
                .expect("Failed to install SIGTERM handler")
                .recv()
                .await;
        };

        #[cfg(not(unix))]
        let sigterm = std::future::pending::<()>();

        tokio::select! {
            _ = ctrl_c => {},
            _ = sigterm => {},
        }

        println!("Shutdown signal received — stopping servers.");
    };

    // Use a broadcast channel to fan-out the shutdown signal to both tasks.
    let (shutdown_tx, _) = broadcast::channel::<()>(1);
    let mut shutdown_rx1 = shutdown_tx.subscribe();
    let mut shutdown_rx2 = shutdown_tx.subscribe();

    // Spawn HTTP server
    let http_handle = tokio::spawn(async move {
        axum::serve(http_listener, http_app)
            .with_graceful_shutdown(async move {
                let _ = shutdown_rx1.recv().await;
            })
            .await
            .expect("HTTP server error");
    });

    // Spawn WS server
    let ws_handle = tokio::spawn(async move {
        axum::serve(ws_listener, ws_app)
            .with_graceful_shutdown(async move {
                let _ = shutdown_rx2.recv().await;
            })
            .await
            .expect("WS server error");
    });

    // Wait for shutdown signal, then notify both tasks.
    shutdown.await;
    let _ = shutdown_tx.send(());

    let _ = tokio::join!(http_handle, ws_handle);
    println!("Server stopped.");
}
