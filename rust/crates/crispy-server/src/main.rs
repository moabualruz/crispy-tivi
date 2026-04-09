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
//! - `CRISPY_BIND_ADDR` — listen address (default:
//!   `127.0.0.1`)
//! - `CRISPY_ALLOW_REMOTE_ACCESS` — must be enabled to
//!   honor a non-loopback bind address
//! - `CRISPY_SHARED_TOKEN` — required when exposing the
//!   server remotely
//! - `CRISPY_PROXY_ALLOWED_HOSTS` — comma-separated
//!   proxy allowlist
//! - `CRISPY_PROXY_ALLOW_PUBLIC_TARGETS` — explicit
//!   opt-in for proxying arbitrary public hosts

use std::{
    collections::HashSet,
    net::{IpAddr, SocketAddr},
    sync::Arc,
    time::Duration,
};

use axum::{
    Router,
    extract::{
        ConnectInfo, Query, State, WebSocketUpgrade,
        ws::{Message, WebSocket},
    },
    http::{HeaderMap, StatusCode, header},
    response::IntoResponse,
    routing::{any, get},
};
use tokio::sync::{broadcast, mpsc};
use tokio::time;
use tower_http::cors::{AllowOrigin, CorsLayer};
use url::Url;

use crispy_core::events::{DataChangeEvent, serialize_event};
use crispy_core::services::ServiceContext;
use crispy_server::handlers::handle_message;

// ── Shared state ────────────────────────────────────

/// Application state shared across handlers.
#[derive(Clone)]
struct AppState {
    ctx: ServiceContext,
    event_tx: broadcast::Sender<String>,
    security: Arc<SecurityConfig>,
}

#[derive(Clone, Debug)]
struct SecurityConfig {
    origin_policy: OriginPolicy,
    shared_token: Option<String>,
    proxy_allowed_hosts: Option<HashSet<String>>,
    proxy_denied_hosts: HashSet<String>,
    proxy_allow_remote_clients: bool,
    proxy_allow_public_targets: bool,
    proxy_allow_private_targets: bool,
}

#[derive(Clone, Debug)]
struct OriginPolicy {
    exact_origins: Option<HashSet<String>>,
}

// ── Handlers ────────────────────────────────────────

/// Query parameters for the image proxy endpoint.
#[derive(serde::Deserialize)]
struct ProxyParams {
    url: String,
    token: Option<String>,
}

/// Optional auth token for access-controlled endpoints.
#[derive(Default, serde::Deserialize)]
struct AccessParams {
    token: Option<String>,
}

fn env_flag(name: &str) -> bool {
    std::env::var(name)
        .ok()
        .map(|value| {
            matches!(
                value.trim().to_ascii_lowercase().as_str(),
                "1" | "true" | "yes" | "on"
            )
        })
        .unwrap_or(false)
}

fn env_flag_with_default(name: &str, default: bool) -> bool {
    std::env::var(name)
        .ok()
        .map(|value| {
            matches!(
                value.trim().to_ascii_lowercase().as_str(),
                "1" | "true" | "yes" | "on"
            )
        })
        .unwrap_or(default)
}

fn normalize_host(host: &str) -> String {
    host.trim().trim_end_matches('.').to_ascii_lowercase()
}

fn normalize_origin(origin: &str) -> Option<String> {
    let parsed = Url::parse(origin).ok()?;
    let host = normalize_host(parsed.host_str()?);
    let mut normalized = format!("{}://{host}", parsed.scheme().to_ascii_lowercase());
    if let Some(port) = parsed.port() {
        normalized.push(':');
        normalized.push_str(&port.to_string());
    }
    Some(normalized)
}

fn env_origin_set(name: &str) -> Option<HashSet<String>> {
    std::env::var(name).ok().and_then(|value| {
        let set = value
            .split(',')
            .filter_map(|origin| normalize_origin(origin.trim()))
            .collect::<HashSet<_>>();
        (!set.is_empty()).then_some(set)
    })
}

fn env_host_set(name: &str) -> Option<HashSet<String>> {
    std::env::var(name).ok().and_then(|value| {
        let set = value
            .split(',')
            .map(normalize_host)
            .filter(|host| !host.is_empty())
            .collect::<HashSet<_>>();
        (!set.is_empty()).then_some(set)
    })
}

fn resolve_security_config() -> SecurityConfig {
    SecurityConfig {
        origin_policy: OriginPolicy {
            exact_origins: env_origin_set("CRISPY_ALLOWED_ORIGINS"),
        },
        shared_token: std::env::var("CRISPY_SHARED_TOKEN")
            .ok()
            .map(|value| value.trim().to_string())
            .filter(|value| !value.is_empty()),
        proxy_allowed_hosts: env_host_set("CRISPY_PROXY_ALLOWED_HOSTS"),
        proxy_denied_hosts: env_host_set("CRISPY_PROXY_DENIED_HOSTS").unwrap_or_default(),
        proxy_allow_remote_clients: env_flag("CRISPY_PROXY_ALLOW_REMOTE"),
        proxy_allow_public_targets: env_flag_with_default(
            "CRISPY_PROXY_ALLOW_PUBLIC_TARGETS",
            true,
        ),
        proxy_allow_private_targets: env_flag("CRISPY_PROXY_ALLOW_PRIVATE_TARGETS"),
    }
}

fn is_local_host(host: &str) -> bool {
    let host = normalize_host(host);
    if host == "localhost" || host.ends_with(".localhost") {
        return true;
    }
    host.parse::<IpAddr>()
        .map(|ip| ip.is_loopback())
        .unwrap_or(false)
}

fn enforce_bind_addr_policy(requested_bind_addr: &str, allow_remote_access: bool) -> String {
    let requested = requested_bind_addr.trim();
    let requested = if requested.is_empty() {
        "127.0.0.1"
    } else {
        requested
    };

    if is_local_host(requested) || allow_remote_access {
        return requested.to_string();
    }

    "127.0.0.1".to_string()
}

fn validate_bind_security(bind_addr: &str, security: &SecurityConfig) -> Result<(), &'static str> {
    if !is_local_host(bind_addr) && security.shared_token.is_none() {
        return Err(
            "CRISPY_SHARED_TOKEN is required when CRISPY_ALLOW_REMOTE_ACCESS exposes crispy-server remotely",
        );
    }

    if security.shared_token.is_none()
        && security
            .origin_policy
            .exact_origins
            .as_ref()
            .is_some_and(|origins| {
                origins
                    .iter()
                    .any(|origin| !origin_targets_local_host(origin))
            })
    {
        return Err(
            "CRISPY_SHARED_TOKEN is required when CRISPY_ALLOWED_ORIGINS includes non-local origins",
        );
    }

    Ok(())
}

fn origin_targets_local_host(origin: &str) -> bool {
    Url::parse(origin)
        .ok()
        .and_then(|parsed| parsed.host_str().map(is_local_host))
        .unwrap_or(false)
}

fn origin_allowed(origin: &str, policy: &OriginPolicy) -> bool {
    if let Some(exact_origins) = &policy.exact_origins {
        return normalize_origin(origin)
            .map(|normalized| exact_origins.contains(&normalized))
            .unwrap_or(false);
    }

    origin_targets_local_host(origin)
}

fn request_origin_allowed(headers: &HeaderMap, policy: &OriginPolicy) -> bool {
    headers
        .get(header::ORIGIN)
        .and_then(|value| value.to_str().ok())
        .is_none_or(|origin| origin_allowed(origin, policy))
}

fn provided_token(headers: &HeaderMap, query_token: Option<&str>) -> Option<String> {
    if let Some(token) = query_token.filter(|token| !token.trim().is_empty()) {
        return Some(token.trim().to_string());
    }

    if let Some(header_token) = headers
        .get("x-crispy-token")
        .and_then(|value| value.to_str().ok())
        .map(str::trim)
        .filter(|value| !value.is_empty())
    {
        return Some(header_token.to_string());
    }

    headers
        .get(header::AUTHORIZATION)
        .and_then(|value| value.to_str().ok())
        .and_then(|value| {
            value
                .strip_prefix("Bearer ")
                .or_else(|| value.strip_prefix("bearer "))
        })
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(|value| value.to_string())
}

fn token_matches(
    headers: &HeaderMap,
    query_token: Option<&str>,
    security: &SecurityConfig,
) -> bool {
    security
        .shared_token
        .as_deref()
        .zip(provided_token(headers, query_token))
        .is_some_and(|(expected, provided)| provided == expected)
}

fn host_from_authority(value: &str) -> Option<String> {
    let value = value.trim().trim_matches('"');
    if value.is_empty() {
        return None;
    }

    if value.contains("://")
        && let Ok(parsed) = Url::parse(value)
    {
        return parsed.host_str().map(normalize_host);
    }

    if let Some(value) = value.strip_prefix('[') {
        let end = value.find(']')?;
        return Some(normalize_host(&value[..end]));
    }

    match value.rsplit_once(':') {
        Some((host, port)) if !host.contains(':') && port.chars().all(|ch| ch.is_ascii_digit()) => {
            Some(normalize_host(host))
        }
        _ => Some(normalize_host(value)),
    }
}

fn forwarded_hosts(headers: &HeaderMap, name: &'static str) -> Vec<String> {
    headers
        .get_all(name)
        .iter()
        .filter_map(|value| value.to_str().ok())
        .flat_map(|value| value.split(','))
        .filter_map(host_from_authority)
        .collect()
}

fn request_targets_local_server(headers: &HeaderMap) -> bool {
    let mut observed_host = false;

    if let Some(origin) = headers
        .get(header::ORIGIN)
        .and_then(|value| value.to_str().ok())
    {
        observed_host = true;
        if !origin_targets_local_host(origin) {
            return false;
        }
    }

    for header_name in [header::HOST.as_str(), "x-forwarded-host"] {
        let hosts = forwarded_hosts(headers, header_name);
        if !hosts.is_empty() {
            observed_host = true;
        }
        if hosts.iter().any(|host| !is_local_host(host)) {
            return false;
        }
    }

    observed_host
}

fn client_is_authorized(
    client_addr: &SocketAddr,
    headers: &HeaderMap,
    query_token: Option<&str>,
    security: &SecurityConfig,
) -> bool {
    if security.shared_token.is_some() {
        return token_matches(headers, query_token, security);
    }

    client_addr.ip().is_loopback() && request_targets_local_server(headers)
}

fn remote_proxy_allowed(
    client_addr: &SocketAddr,
    headers: &HeaderMap,
    query_token: Option<&str>,
    security: &SecurityConfig,
) -> bool {
    if client_addr.ip().is_loopback() {
        return client_is_authorized(client_addr, headers, query_token, security);
    }

    security.proxy_allow_remote_clients
        && client_is_authorized(client_addr, headers, query_token, security)
}

fn is_private_ip(ip: IpAddr) -> bool {
    match ip {
        IpAddr::V4(v4) => {
            v4.is_private()
                || v4.is_loopback()
                || v4.is_link_local()
                || v4.is_broadcast()
                || v4.is_documentation()
                || v4.is_multicast()
                || v4.is_unspecified()
        }
        IpAddr::V6(v6) => {
            v6.is_loopback()
                || v6.is_unique_local()
                || v6.is_unicast_link_local()
                || v6.is_multicast()
                || v6.is_unspecified()
        }
    }
}

fn parse_proxy_target(raw_url: &str) -> Option<Url> {
    let parsed = Url::parse(raw_url).ok()?;
    match parsed.scheme() {
        "http" | "https" => {}
        _ => return None,
    }
    parsed.host_str()?;
    Some(parsed)
}

fn proxy_path_for_url(absolute_url: &str, token: Option<&str>) -> String {
    let encoded_url =
        percent_encoding::utf8_percent_encode(absolute_url, percent_encoding::NON_ALPHANUMERIC);

    match token.map(str::trim).filter(|value| !value.is_empty()) {
        Some(token) => {
            let encoded_token =
                percent_encoding::utf8_percent_encode(token, percent_encoding::NON_ALPHANUMERIC);
            format!("/proxy?url={encoded_url}&token={encoded_token}")
        }
        None => format!("/proxy?url={encoded_url}"),
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum ProxyFetchError {
    ForbiddenTarget,
    BadGateway,
}

#[derive(Clone, Debug)]
struct ResolvedProxyTarget {
    url: Url,
    host: String,
    resolved_addrs: Vec<SocketAddr>,
}

fn resolve_proxy_redirect_target(current_url: &Url, location: &str) -> Option<Url> {
    let location = location.trim();
    if location.is_empty() {
        return None;
    }

    let resolved = current_url.join(location).ok()?;
    parse_proxy_target(resolved.as_str())
}

fn proxy_redirect_target(current_url: &Url, headers: &HeaderMap) -> Option<Url> {
    headers
        .get(header::LOCATION)
        .and_then(|value| value.to_str().ok())
        .and_then(|location| resolve_proxy_redirect_target(current_url, location))
}

async fn resolve_proxy_target(
    target: &Url,
    security: &SecurityConfig,
) -> Option<ResolvedProxyTarget> {
    let host = match target.host_str() {
        Some(host) => normalize_host(host),
        None => return None,
    };

    if is_local_host(&host) || security.proxy_denied_hosts.contains(&host) {
        return None;
    }

    if let Some(allowed_hosts) = &security.proxy_allowed_hosts
        && !allowed_hosts.contains(&host)
    {
        return None;
    }

    if security.proxy_allowed_hosts.is_none() && !security.proxy_allow_public_targets {
        return None;
    }

    let port = target.port_or_known_default().unwrap_or(80);
    let resolved_addrs = if let Ok(ip) = host.parse::<IpAddr>() {
        if !security.proxy_allow_private_targets && is_private_ip(ip) {
            return None;
        }
        vec![SocketAddr::new(ip, port)]
    } else {
        let Ok(addrs) = tokio::net::lookup_host((host.as_str(), port)).await else {
            return None;
        };
        let resolved_addrs = addrs.collect::<Vec<_>>();
        if resolved_addrs.is_empty() {
            return None;
        }
        if !security.proxy_allow_private_targets
            && resolved_addrs.iter().any(|addr| is_private_ip(addr.ip()))
        {
            return None;
        }
        resolved_addrs
    };

    Some(ResolvedProxyTarget {
        url: target.clone(),
        host,
        resolved_addrs,
    })
}

fn build_proxy_client(target: &ResolvedProxyTarget) -> Result<reqwest::Client, reqwest::Error> {
    let mut builder = reqwest::Client::builder()
        .timeout(Duration::from_secs(30))
        .redirect(reqwest::redirect::Policy::none())
        .no_proxy();

    if target.host.parse::<IpAddr>().is_err() {
        builder = builder.resolve_to_addrs(&target.host, &target.resolved_addrs);
    }

    builder.build()
}

async fn fetch_proxy_response(
    initial_target: ResolvedProxyTarget,
    security: &SecurityConfig,
) -> Result<reqwest::Response, ProxyFetchError> {
    const MAX_PROXY_REDIRECTS: usize = 10;

    let mut current_target = initial_target;
    for _ in 0..=MAX_PROXY_REDIRECTS {
        let client =
            build_proxy_client(&current_target).map_err(|_| ProxyFetchError::BadGateway)?;
        let response = client
            .get(current_target.url.clone())
            .send()
            .await
            .map_err(|_| ProxyFetchError::BadGateway)?;

        if !response.status().is_redirection() {
            return Ok(response);
        }

        let Some(next_target) = proxy_redirect_target(response.url(), response.headers()) else {
            return Err(ProxyFetchError::BadGateway);
        };

        current_target = resolve_proxy_target(&next_target, security)
            .await
            .ok_or(ProxyFetchError::ForbiddenTarget)?;
    }

    Err(ProxyFetchError::BadGateway)
}

/// CORS relay proxy for browser-based playback.
///
/// Fetches the upstream URL server-side and re-serves the
/// content with CORS headers. For M3U8 playlists, rewrites
/// segment and key URLs to also route through the proxy.
///
/// Only allows `http://` and `https://` URLs to prevent SSRF.
async fn cors_proxy(
    State(state): State<AppState>,
    ConnectInfo(client_addr): ConnectInfo<SocketAddr>,
    headers: HeaderMap,
    Query(params): Query<ProxyParams>,
) -> impl IntoResponse {
    if !request_origin_allowed(&headers, &state.security.origin_policy) {
        return StatusCode::FORBIDDEN.into_response();
    }

    if !remote_proxy_allowed(
        &client_addr,
        &headers,
        params.token.as_deref(),
        &state.security,
    ) {
        return StatusCode::UNAUTHORIZED.into_response();
    }

    let Some(target) = parse_proxy_target(&params.url) else {
        return StatusCode::BAD_REQUEST.into_response();
    };

    let Some(target) = resolve_proxy_target(&target, &state.security).await else {
        return StatusCode::FORBIDDEN.into_response();
    };

    let proxy_token = provided_token(&headers, params.token.as_deref());

    match fetch_proxy_response(target, &state.security).await {
        Ok(resp) => {
            let upstream_url = resp.url().clone();
            let content_type = resp
                .headers()
                .get("content-type")
                .and_then(|v| v.to_str().ok())
                .unwrap_or("application/octet-stream")
                .to_string();

            let is_m3u8 = content_type.contains("mpegurl")
                || upstream_url.path().ends_with(".m3u8")
                || upstream_url.path().ends_with(".m3u");

            match resp.bytes().await {
                Ok(bytes) => {
                    if is_m3u8 {
                        let body = String::from_utf8_lossy(&bytes);
                        let rewritten = rewrite_m3u8(&body, &upstream_url, proxy_token.as_deref());
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
        Err(ProxyFetchError::ForbiddenTarget) => StatusCode::FORBIDDEN.into_response(),
        Err(ProxyFetchError::BadGateway) => StatusCode::BAD_GATEWAY.into_response(),
    }
}

// ── M3U8 rewriting ─────────────────────────────────

/// Rewrite URLs in an M3U8 playlist to route through
/// the CORS proxy.
fn rewrite_m3u8(body: &str, base_url: &Url, token: Option<&str>) -> String {
    body.lines()
        .map(|line| {
            let trimmed = line.trim();
            if trimmed.is_empty() {
                return line.to_string();
            }
            if trimmed.starts_with('#') {
                return rewrite_tag_uri(line, base_url, token);
            }
            // Segment URL line
            let absolute = resolve_url(trimmed, base_url);
            proxy_path_for_url(&absolute, token)
        })
        .collect::<Vec<_>>()
        .join("\n")
}

/// Resolve a potentially relative URL against a base
/// directory URL.
fn resolve_url(url: &str, base_url: &Url) -> String {
    if let Some(absolute) = parse_proxy_target(url) {
        return absolute.to_string();
    }

    base_url
        .join(url)
        .map(|resolved| resolved.to_string())
        .unwrap_or_else(|_| url.to_string())
}

/// Rewrite `URI="..."` attributes in M3U8 tags
/// (`#EXT-X-KEY`, `#EXT-X-MAP`, etc.).
fn rewrite_tag_uri(line: &str, base_url: &Url, token: Option<&str>) -> String {
    if let Some(uri_start) = line.find("URI=\"") {
        let after_uri = &line[uri_start + 5..];
        if let Some(uri_end) = after_uri.find('"') {
            let uri = &after_uri[..uri_end];
            let proxied = proxy_path_for_url(&resolve_url(uri, base_url), token);
            return format!(
                "{}URI=\"{}\"{}",
                &line[..uri_start],
                proxied,
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
async fn ws_upgrade(
    State(state): State<AppState>,
    ConnectInfo(client_addr): ConnectInfo<SocketAddr>,
    headers: HeaderMap,
    Query(params): Query<AccessParams>,
    ws: WebSocketUpgrade,
) -> impl IntoResponse {
    if !request_origin_allowed(&headers, &state.security.origin_policy) {
        return StatusCode::FORBIDDEN.into_response();
    }

    if !client_is_authorized(
        &client_addr,
        &headers,
        params.token.as_deref(),
        &state.security,
    ) {
        return StatusCode::UNAUTHORIZED.into_response();
    }

    ws.on_upgrade(move |socket| ws_handler(socket, state))
}

/// Process WebSocket messages for a single client,
/// and forward server-pushed events via broadcast.
fn spawn_command_processor_with<F>(
    mut command_rx: mpsc::Receiver<String>,
    outbound_tx: mpsc::Sender<Message>,
    executor: F,
) -> tokio::task::JoinHandle<()>
where
    F: Fn(String) -> String + Send + Sync + 'static,
{
    let executor = Arc::new(executor);
    tokio::spawn(async move {
        while let Some(text) = command_rx.recv().await {
            let executor = executor.clone();
            let response = tokio::task::spawn_blocking(move || executor(text))
                .await
                .unwrap_or_else(|_| "{\"error\":\"Internal task panic\"}".to_string());
            if outbound_tx
                .send(Message::Text(response.into()))
                .await
                .is_err()
            {
                break;
            }
        }
    })
}

fn spawn_command_processor(
    ctx: ServiceContext,
    command_rx: mpsc::Receiver<String>,
    outbound_tx: mpsc::Sender<Message>,
) -> tokio::task::JoinHandle<()> {
    spawn_command_processor_with(command_rx, outbound_tx, move |text| {
        handle_message(&ctx, &text)
    })
}

async fn ws_handler(mut socket: WebSocket, state: AppState) {
    let mut event_rx = state.event_tx.subscribe();
    let mut heartbeat = time::interval(Duration::from_secs(30));
    let (command_tx, command_rx) = mpsc::channel::<String>(32);
    let (outbound_tx, mut outbound_rx) = mpsc::channel::<Message>(32);
    let command_processor = spawn_command_processor(state.ctx.clone(), command_rx, outbound_tx);
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

                        match command_tx.try_send(text.to_string()) {
                            Ok(()) => {}
                            Err(mpsc::error::TrySendError::Full(_)) => {
                                let busy = r#"{"error":"Too many in-flight commands"}"#;
                                if socket.send(Message::Text(busy.into())).await.is_err() {
                                    break;
                                }
                            }
                            Err(mpsc::error::TrySendError::Closed(_)) => break,
                        }
                    }
                    Message::Close(_) => break,
                    _ => {}
                }
            }
            Some(outbound) = outbound_rx.recv() => {
                if socket.send(outbound).await.is_err() {
                    break;
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

    command_processor.abort();
}

// ── CORS configuration ──────────────────────────────

/// Build a CORS layer from `CRISPY_ALLOWED_ORIGINS` env var.
fn build_cors_layer(security: &SecurityConfig) -> CorsLayer {
    let origin_policy = security.origin_policy.clone();
    CorsLayer::new()
        .allow_methods(tower_http::cors::Any)
        .allow_headers(tower_http::cors::Any)
        .allow_origin(AllowOrigin::predicate(move |origin, _parts| {
            origin
                .to_str()
                .ok()
                .is_some_and(|value| origin_allowed(value, &origin_policy))
        }))
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

fn resolve_bind_addr(security: &SecurityConfig) -> String {
    let requested = std::env::var("CRISPY_BIND_ADDR").unwrap_or_else(|_| "127.0.0.1".to_string());
    let bind_addr = enforce_bind_addr_policy(&requested, env_flag("CRISPY_ALLOW_REMOTE_ACCESS"));
    if bind_addr != requested.trim() {
        eprintln!(
            "CRISPY_BIND_ADDR={requested} ignored; set CRISPY_ALLOW_REMOTE_ACCESS=1 to expose crispy-server remotely",
        );
    }
    validate_bind_security(&bind_addr, security).expect("Invalid crispy-server bind security");
    bind_addr
}

// ── Main ────────────────────────────────────────────

#[tokio::main]
async fn main() {
    let db_path = resolve_db_path();
    let port = resolve_port();
    let security = Arc::new(resolve_security_config());
    let bind_addr = resolve_bind_addr(&security);

    println!("DB path: {db_path}");

    let ctx = ServiceContext::open(&db_path).expect("Failed to open database");

    let (event_tx, _) = broadcast::channel::<String>(256);
    let tx_clone = event_tx.clone();
    ctx.set_event_callback(Arc::new(move |event: &DataChangeEvent| {
        let json = serialize_event(event);
        let _ = tx_clone.send(json);
    }));

    let state = AppState {
        ctx,
        event_tx,
        security: security.clone(),
    };

    let cors = build_cors_layer(&security);

    let app = Router::new()
        .route("/health", get(health))
        .route("/proxy", get(cors_proxy))
        .route("/ws", get(ws_upgrade))
        .fallback(any(|| async { (StatusCode::NOT_FOUND, "Not Found") }))
        .with_state(state)
        .layer(cors);

    let addr = format!("{bind_addr}:{port}");
    println!("CrispyTivi server listening on {addr}");

    let listener = tokio::net::TcpListener::bind(&addr)
        .await
        .unwrap_or_else(|e| panic!("Failed to bind {addr}: {e}"));

    axum::serve(
        listener,
        app.into_make_service_with_connect_info::<SocketAddr>(),
    )
    .await
    .expect("Server error");
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::io::{AsyncReadExt, AsyncWriteExt};

    fn security_config() -> SecurityConfig {
        SecurityConfig {
            origin_policy: OriginPolicy {
                exact_origins: None,
            },
            shared_token: Some("secret".to_string()),
            proxy_allowed_hosts: None,
            proxy_denied_hosts: HashSet::new(),
            proxy_allow_remote_clients: false,
            proxy_allow_public_targets: false,
            proxy_allow_private_targets: false,
        }
    }

    async fn spawn_test_http_server(
        response: &'static str,
    ) -> (SocketAddr, tokio::task::JoinHandle<String>) {
        let listener = tokio::net::TcpListener::bind((std::net::Ipv4Addr::LOCALHOST, 0))
            .await
            .expect("bind test server");
        let addr = listener.local_addr().expect("server addr");
        let handle = tokio::spawn(async move {
            let (mut stream, _) = listener.accept().await.expect("accept");
            let mut buf = vec![0_u8; 4096];
            let read = stream.read(&mut buf).await.expect("read request");
            let request = String::from_utf8_lossy(&buf[..read]).to_string();
            stream
                .write_all(response.as_bytes())
                .await
                .expect("write response");
            request
        });
        (addr, handle)
    }

    #[test]
    fn non_loopback_bind_requires_explicit_remote_opt_in() {
        assert_eq!(enforce_bind_addr_policy("0.0.0.0", false), "127.0.0.1");
        assert_eq!(enforce_bind_addr_policy("0.0.0.0", true), "0.0.0.0");
        assert_eq!(enforce_bind_addr_policy("localhost", false), "localhost");
    }

    #[test]
    fn remote_bind_requires_shared_token() {
        let mut security = security_config();
        security.shared_token = None;
        assert!(validate_bind_security("0.0.0.0", &security).is_err());
        assert!(validate_bind_security("127.0.0.1", &security).is_ok());
    }

    #[test]
    fn non_local_allowed_origins_require_shared_token_even_on_loopback_bind() {
        let mut security = security_config();
        security.shared_token = None;
        security.origin_policy.exact_origins = Some(HashSet::from(["https://tv.example".into()]));
        assert!(validate_bind_security("127.0.0.1", &security).is_err());

        security.origin_policy.exact_origins =
            Some(HashSet::from(["http://localhost:3000".into()]));
        assert!(validate_bind_security("127.0.0.1", &security).is_ok());
    }

    #[test]
    fn default_origin_policy_allows_localhost_only() {
        let policy = OriginPolicy {
            exact_origins: None,
        };
        assert!(origin_allowed("http://localhost:3000", &policy));
        assert!(origin_allowed("http://127.0.0.1:8080", &policy));
        assert!(!origin_allowed("https://evil.example", &policy));
    }

    #[test]
    fn remote_clients_require_shared_token() {
        let headers = HeaderMap::new();
        let client = SocketAddr::from((std::net::Ipv4Addr::new(203, 0, 113, 10), 4242));
        assert!(!client_is_authorized(
            &client,
            &headers,
            None,
            &security_config()
        ));
    }

    #[test]
    fn loopback_clients_require_shared_token_when_configured() {
        let headers = HeaderMap::new();
        let client = SocketAddr::from((std::net::Ipv4Addr::LOCALHOST, 4242));
        assert!(!client_is_authorized(
            &client,
            &headers,
            None,
            &security_config(),
        ));
    }

    #[test]
    fn loopback_clients_without_shared_token_remain_trusted() {
        let mut headers = HeaderMap::new();
        headers.insert(
            header::HOST,
            "localhost:8080".parse().expect("valid header"),
        );
        let client = SocketAddr::from((std::net::Ipv4Addr::LOCALHOST, 4242));
        let mut security = security_config();
        security.shared_token = None;
        assert!(client_is_authorized(&client, &headers, None, &security));
    }

    #[test]
    fn loopback_clients_without_shared_token_reject_non_local_surface_hosts() {
        let client = SocketAddr::from((std::net::Ipv4Addr::LOCALHOST, 4242));
        let mut security = security_config();
        security.shared_token = None;

        let mut proxy_host_headers = HeaderMap::new();
        proxy_host_headers.insert(header::HOST, "tv.example".parse().expect("valid header"));
        assert!(!client_is_authorized(
            &client,
            &proxy_host_headers,
            None,
            &security,
        ));

        let mut proxied_origin_headers = HeaderMap::new();
        proxied_origin_headers.insert(
            header::HOST,
            "127.0.0.1:8080".parse().expect("valid header"),
        );
        proxied_origin_headers.insert(
            header::ORIGIN,
            "https://tv.example".parse().expect("valid header"),
        );
        assert!(!client_is_authorized(
            &client,
            &proxied_origin_headers,
            None,
            &security,
        ));

        let mut forwarded_host_headers = HeaderMap::new();
        forwarded_host_headers.insert(
            header::HOST,
            "127.0.0.1:8080".parse().expect("valid header"),
        );
        forwarded_host_headers.insert(
            "x-forwarded-host",
            "tv.example".parse().expect("valid header"),
        );
        assert!(!client_is_authorized(
            &client,
            &forwarded_host_headers,
            None,
            &security,
        ));
    }

    #[test]
    fn remote_clients_accept_bearer_token() {
        let mut headers = HeaderMap::new();
        headers.insert(
            header::AUTHORIZATION,
            "Bearer secret".parse().expect("valid header"),
        );
        let client = SocketAddr::from((std::net::Ipv4Addr::new(203, 0, 113, 10), 4242));
        assert!(client_is_authorized(
            &client,
            &headers,
            None,
            &security_config(),
        ));
    }

    #[test]
    fn loopback_proxy_clients_require_shared_token_when_configured() {
        let headers = HeaderMap::new();
        let client = SocketAddr::from((std::net::Ipv4Addr::LOCALHOST, 4242));
        assert!(!remote_proxy_allowed(
            &client,
            &headers,
            None,
            &security_config(),
        ));
    }

    #[test]
    fn loopback_proxy_clients_accept_query_token_when_configured() {
        let headers = HeaderMap::new();
        let client = SocketAddr::from((std::net::Ipv4Addr::LOCALHOST, 4242));
        assert!(remote_proxy_allowed(
            &client,
            &headers,
            Some("secret"),
            &security_config(),
        ));
    }

    #[tokio::test]
    async fn proxy_rejects_private_ip_targets() {
        let security = security_config();
        let target = Url::parse("http://127.0.0.1/internal").expect("valid URL");
        assert!(resolve_proxy_target(&target, &security).await.is_none());
    }

    #[tokio::test]
    async fn proxy_is_disabled_without_allowlist_or_explicit_public_opt_in() {
        let security = security_config();
        let target = Url::parse("http://1.1.1.1/stream").expect("valid URL");
        assert!(resolve_proxy_target(&target, &security).await.is_none());
    }

    #[tokio::test]
    async fn proxy_allows_allowlisted_public_target() {
        let mut security = security_config();
        security.proxy_allowed_hosts = Some(HashSet::from(["1.1.1.1".to_string()]));
        let target = Url::parse("http://1.1.1.1/stream").expect("valid URL");
        assert!(resolve_proxy_target(&target, &security).await.is_some());
    }

    #[test]
    fn proxy_redirect_resolution_supports_relative_locations() {
        let current = Url::parse("https://cdn.example/live/playlist.m3u8").expect("valid URL");
        let redirected =
            resolve_proxy_redirect_target(&current, "../alt/child.m3u8").expect("redirect URL");
        assert_eq!(redirected.as_str(), "https://cdn.example/alt/child.m3u8");
    }

    #[tokio::test]
    async fn proxy_rejects_redirects_into_disallowed_hosts() {
        let mut security = security_config();
        security.proxy_allowed_hosts = Some(HashSet::from(["allowed.example".to_string()]));
        let current = Url::parse("https://allowed.example/live/playlist.m3u8").expect("valid URL");
        let redirected = resolve_proxy_redirect_target(&current, "https://blocked.example/stream")
            .expect("redirect URL");
        assert!(resolve_proxy_target(&redirected, &security).await.is_none());
    }

    #[tokio::test]
    async fn proxy_rejects_redirects_into_private_targets() {
        let mut security = security_config();
        security.proxy_allow_public_targets = true;
        let current = Url::parse("https://allowed.example/live/playlist.m3u8").expect("valid URL");
        let redirected = resolve_proxy_redirect_target(&current, "http://127.0.0.1/internal")
            .expect("redirect URL");
        assert!(resolve_proxy_target(&redirected, &security).await.is_none());
    }

    #[tokio::test]
    async fn fetch_proxy_response_uses_pinned_resolver_addresses() {
        let (server_addr, request_task) = spawn_test_http_server(
            "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok",
        )
        .await;
        let target = ResolvedProxyTarget {
            url: Url::parse(&format!(
                "http://media.example:{}/stream.ts",
                server_addr.port()
            ))
            .expect("valid URL"),
            host: "media.example".to_string(),
            resolved_addrs: vec![server_addr],
        };

        let response = fetch_proxy_response(target, &security_config())
            .await
            .expect("pinned proxy response");

        assert_eq!(response.status(), StatusCode::OK);
        assert_eq!(response.text().await.expect("body"), "ok");

        let request = request_task.await.expect("captured request");
        let request = request.to_ascii_lowercase();
        assert!(
            request.starts_with("get /stream.ts http/1.1\r\n"),
            "{request}"
        );
        assert!(
            request.contains(&format!(
                "\r\nhost: media.example:{}\r\n",
                server_addr.port()
            )),
            "{request}"
        );
    }

    #[test]
    fn rewrite_m3u8_includes_proxy_token_when_present() {
        let base_url = Url::parse("http://example.com/live/playlist.m3u8").expect("valid URL");
        let rewritten = rewrite_m3u8("#EXTM3U\nsegment.ts", &base_url, Some("secret token"));
        assert!(rewritten.contains("token=secret%20token"), "{rewritten}");
    }

    #[test]
    fn rewrite_m3u8_uses_final_response_url_for_relative_paths() {
        let final_url =
            Url::parse("https://cdn.example/redirected/path/playlist.m3u8").expect("valid URL");
        let rewritten = rewrite_m3u8(
            "#EXTM3U\nsegment.ts\n#EXT-X-KEY:METHOD=AES-128,URI=\"keys/key.bin\"",
            &final_url,
            None,
        );

        let expected_segment =
            proxy_path_for_url("https://cdn.example/redirected/path/segment.ts", None);
        let expected_key = format!(
            "#EXT-X-KEY:METHOD=AES-128,URI=\"{}\"",
            proxy_path_for_url("https://cdn.example/redirected/path/keys/key.bin", None)
        );

        assert!(rewritten.lines().any(|line| line == expected_segment));
        assert!(
            rewritten.lines().any(|line| line == expected_key),
            "{rewritten}"
        );
    }

    #[tokio::test]
    async fn command_processor_preserves_request_order() {
        let (command_tx, command_rx) = mpsc::channel::<String>(4);
        let (outbound_tx, mut outbound_rx) = mpsc::channel::<Message>(4);

        let processor = spawn_command_processor_with(command_rx, outbound_tx, |text| {
            if text == "slow" {
                std::thread::sleep(Duration::from_millis(25));
            }
            text
        });

        command_tx.send("slow".to_string()).await.unwrap();
        command_tx.send("fast".to_string()).await.unwrap();

        let first = outbound_rx.recv().await.expect("first response");
        let second = outbound_rx.recv().await.expect("second response");

        match first {
            Message::Text(body) => assert_eq!(body.as_str(), "slow"),
            other => panic!("unexpected first message: {other:?}"),
        }
        match second {
            Message::Text(body) => assert_eq!(body.as_str(), "fast"),
            other => panic!("unexpected second message: {other:?}"),
        }

        processor.abort();
    }
}
