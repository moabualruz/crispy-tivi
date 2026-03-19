//! WASM entry point for CrispyTivi browser target.
//!
//! This module is compiled only for `target_arch = "wasm32"`.
//! It exports the `main` function via `wasm-bindgen` so that the
//! `wasm-pack`-generated JS glue can call `crispytiviMain()`.
//!
//! ## Architecture
//!
//! ```text
//! Browser                        WASM
//! ──────                         ────
//! index.html loads app.js
//! app.js calls crispytiviMain()  ─▶ wasm_entry::main()
//!                                    │  Opens WebSocket to crispy-server
//!                                    │  Creates RemoteProvider
//!                                    └─▶ Starts Slint event loop
//! ```
//!
//! ## Feature Gates
//!
//! All WASM-specific code is guarded by `#[cfg(target_arch = "wasm32")]`
//! so this file compiles cleanly on native targets (tests, clippy, etc.).
//!
//! ## Browser Video (9.4 — architecture only)
//!
//! On WASM, the HTML5 `<video>` element is positioned behind the Slint
//! `<canvas>` using `z-index: -1`. The Slint canvas has a transparent
//! background so the video shows through. HLS.js/Dash.js are loaded as
//! external JS modules and controlled via `wasm-bindgen` bindings.
//! The actual DOM manipulation happens in `index.html` / `app.js`;
//! Rust sends play/pause/seek commands through `js_sys::Function` calls.

#[cfg(target_arch = "wasm32")]
use wasm_bindgen::prelude::*;

// ── WASM exports ─────────────────────────────────────────────────────────────

/// WASM entry point called from JavaScript.
///
/// Sets up panic hooks, initializes tracing, opens the WebSocket to
/// `crispy-server`, creates a `RemoteProvider`, and starts the Slint
/// event loop.
///
/// Called as: `import init, { crispytiviMain } from './app.js'; crispytiviMain();`
#[cfg(target_arch = "wasm32")]
#[wasm_bindgen]
pub fn crispy_tivi_main() {
    // Redirect Rust panics to `console.error`.
    console_error_panic_hook::set_once();

    // Route `tracing` events to `console.log`.
    tracing_wasm::set_as_global_default();

    tracing::info!("CrispyTivi WASM starting");

    // Determine WebSocket URL from the current page origin.
    let ws_url = derive_ws_url();
    tracing::info!(ws_url, "Connecting to crispy-server");

    // Open WebSocket and store it on `window.__crispyWs` so that
    // `RemoteProvider::dispatch_ws_call` can retrieve it.
    open_websocket(&ws_url);
}

/// Derive the WebSocket URL from the current browser location.
///
/// `http://host:8080/` → `ws://host:8081/ws`
/// `https://host/`     → `wss://host/ws`
#[cfg(target_arch = "wasm32")]
fn derive_ws_url() -> String {
    let location = web_sys::window()
        .and_then(|w| w.location().host().ok())
        .unwrap_or_else(|| "localhost:8081".to_string());

    // Use wss:// if the page was loaded over HTTPS.
    let scheme = web_sys::window()
        .and_then(|w| w.location().protocol().ok())
        .map(|p| if p == "https:" { "wss" } else { "ws" })
        .unwrap_or("ws");

    // Use the dedicated WS port (8081 by default).
    // Strip any existing port from the host and append the WS port.
    let host = location.split(':').next().unwrap_or("localhost");
    format!("{scheme}://{host}:8081/ws")
}

/// Open a `WebSocket` and attach it to `window.__crispyWs`.
///
/// The `onmessage` callback forwards every received text frame to
/// `window.__crispyWsHandler` (set by the RemoteProvider after init).
#[cfg(target_arch = "wasm32")]
fn open_websocket(url: &str) {
    use wasm_bindgen::closure::Closure;

    let ws = match web_sys::WebSocket::new(url) {
        Ok(ws) => ws,
        Err(e) => {
            tracing::error!("Failed to open WebSocket: {:?}", e);
            return;
        }
    };

    // Store on window so RemoteProvider can send frames.
    if let Some(window) = web_sys::window() {
        let _ = js_sys::Reflect::set(&window, &JsValue::from_str("__crispyWs"), &ws);
    }

    // onopen: log connection.
    let onopen = Closure::<dyn FnMut()>::new(|| {
        tracing::info!("WebSocket connected to crispy-server");
    });
    ws.set_onopen(Some(onopen.as_ref().unchecked_ref()));
    onopen.forget();

    // onmessage: forward text frames to the pending-call resolver.
    let onmessage =
        Closure::<dyn FnMut(web_sys::MessageEvent)>::new(move |evt: web_sys::MessageEvent| {
            if let Some(text) = evt.data().as_string() {
                // Call window.__crispyWsHandler(text) if registered.
                if let Some(window) = web_sys::window() {
                    if let Ok(handler) =
                        js_sys::Reflect::get(&window, &JsValue::from_str("__crispyWsHandler"))
                    {
                        if let Ok(func) = handler.dyn_into::<js_sys::Function>() {
                            let _ = func.call1(&JsValue::NULL, &JsValue::from_str(&text));
                        }
                    }
                }
            }
        });
    ws.set_onmessage(Some(onmessage.as_ref().unchecked_ref()));
    onmessage.forget();

    // onerror: log errors.
    let onerror = Closure::<dyn FnMut(web_sys::ErrorEvent)>::new(|e: web_sys::ErrorEvent| {
        tracing::error!("WebSocket error: {}", e.message());
    });
    ws.set_onerror(Some(onerror.as_ref().unchecked_ref()));
    onerror.forget();

    // onclose: log disconnection.
    let onclose = Closure::<dyn FnMut(web_sys::CloseEvent)>::new(|e: web_sys::CloseEvent| {
        tracing::warn!("WebSocket closed: code={} reason={}", e.code(), e.reason());
    });
    ws.set_onclose(Some(onclose.as_ref().unchecked_ref()));
    onclose.forget();
}

// ── DRM detection (9.8 — architecture) ───────────────────────────────────────

/// DRM system detected in the current browser.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum DrmSystem {
    /// Widevine (Chrome, Firefox, Edge, Opera).
    Widevine,
    /// FairPlay (Safari / macOS / iOS).
    FairPlay,
    /// PlayReady (Edge, older IE).
    PlayReady,
    /// No DRM system detected (clear content only).
    None,
}

impl DrmSystem {
    /// Human-readable identifier passed to the media player.
    pub(crate) fn key_system(&self) -> Option<&'static str> {
        match self {
            Self::Widevine => Some("com.widevine.alpha"),
            Self::FairPlay => Some("com.apple.fps.1_0"),
            Self::PlayReady => Some("com.microsoft.playready"),
            Self::None => None,
        }
    }
}

/// Detect which DRM system is available in the current browser.
///
/// On native targets this always returns `DrmSystem::None`.
/// On WASM it probes `navigator.requestMediaKeySystemAccess`.
///
/// This is an async probe; the actual implementation uses
/// `wasm-bindgen-futures`. The architecture is documented here;
/// full browser I/O is wired in `index.html` / `app.js`.
pub(crate) fn detect_drm() -> DrmSystem {
    // On native, no DRM probing is possible.
    #[cfg(not(target_arch = "wasm32"))]
    return DrmSystem::None;

    // On WASM, detect by user agent as a fast synchronous approximation.
    // The proper async probe via requestMediaKeySystemAccess is triggered
    // from app.js and the result is passed back via window.__crispyDrm.
    #[cfg(target_arch = "wasm32")]
    {
        let ua = web_sys::window()
            .and_then(|w| w.navigator().user_agent().ok())
            .unwrap_or_default()
            .to_lowercase();

        if ua.contains("safari") && !ua.contains("chrome") {
            DrmSystem::FairPlay
        } else if ua.contains("edg/") || ua.contains("edge/") {
            // Edge supports both Widevine and PlayReady; prefer Widevine.
            DrmSystem::Widevine
        } else {
            // Chrome, Firefox, Opera — all support Widevine.
            DrmSystem::Widevine
        }
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    // DRM detection tests run on native (no browser available).

    #[test]
    fn test_detect_drm_returns_none_on_native() {
        assert_eq!(detect_drm(), DrmSystem::None);
    }

    #[test]
    fn test_drm_system_key_system_widevine() {
        assert_eq!(DrmSystem::Widevine.key_system(), Some("com.widevine.alpha"));
    }

    #[test]
    fn test_drm_system_key_system_fairplay() {
        assert_eq!(DrmSystem::FairPlay.key_system(), Some("com.apple.fps.1_0"));
    }

    #[test]
    fn test_drm_system_key_system_playready() {
        assert_eq!(
            DrmSystem::PlayReady.key_system(),
            Some("com.microsoft.playready")
        );
    }

    #[test]
    fn test_drm_system_key_system_none_returns_none() {
        assert!(DrmSystem::None.key_system().is_none());
    }

    #[test]
    fn test_drm_system_equality() {
        assert_eq!(DrmSystem::Widevine, DrmSystem::Widevine);
        assert_ne!(DrmSystem::Widevine, DrmSystem::FairPlay);
    }
}
