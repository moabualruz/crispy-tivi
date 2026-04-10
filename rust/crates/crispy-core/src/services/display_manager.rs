//! Display / monitor abstraction.
//!
//! Provides a platform-neutral view of connected displays.
//! `StubDisplayService` returns a single synthetic primary display
//! on platforms that do not expose a display enumeration API.

/// Information about a connected display.
#[derive(Debug, Clone, PartialEq)]
pub struct DisplayInfo {
    pub id: String,
    pub name: String,
    pub width: u32,
    pub height: u32,
    pub scale_factor: f64,
    pub is_primary: bool,
}

/// Platform display service.
pub trait DisplayService: Send + Sync {
    /// Return all connected displays.
    fn list_displays(&self) -> Vec<DisplayInfo>;

    /// Return the primary display, if any.
    fn get_primary(&self) -> Option<DisplayInfo>;

    /// Request that fullscreen be presented on the display with the given `id`.
    fn set_fullscreen_display(&self, id: &str);
}

// ── Resizable-window support (12.12) ─────────────────────────────────────────

/// Platforms that support dynamic window resizing.
///
/// - **Samsung DeX** — Android app running in desktop mode with a freely
///   resizable floating window.
/// - **iPad Stage Manager** — iPadOS app running in a resizable overlapping
///   window alongside other apps.
///
/// Both platforms expose an `onMultiWindowModeChanged` / Scene lifecycle
/// callback. This enum and trait provide a platform-neutral abstraction.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ResizableWindowPlatform {
    /// Samsung DeX (Android desktop mode).
    SamsungDex,
    /// iPadOS Stage Manager.
    IpadStageManager,
    /// Standard windowed desktop (Windows / macOS / Linux).
    Desktop,
}

/// A display that supports arbitrary window resizing.
pub trait ResizableWindowService: Send + Sync {
    /// Returns which resizable platform is active, if any.
    fn platform(&self) -> Option<ResizableWindowPlatform>;

    /// Returns `true` when the app is currently in a resizable-window mode.
    fn is_resizable(&self) -> bool;

    /// Called by the platform when the window bounds change.
    fn on_window_resize(&self, callback: Box<dyn Fn(u32, u32) + Send + Sync>);
}

/// Stub implementation used on platforms with no resizable-window API.
#[derive(Debug, Default)]
pub struct StubResizableWindow;

impl ResizableWindowService for StubResizableWindow {
    fn platform(&self) -> Option<ResizableWindowPlatform> {
        None
    }
    fn is_resizable(&self) -> bool {
        false
    }
    fn on_window_resize(&self, _callback: Box<dyn Fn(u32, u32) + Send + Sync>) {}
}

// ── WebOS / Tizen platform detection (12.9, 12.10) ───────────────────────────

/// TV platform identifier for packaging and remote-control routing.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TvPlatform {
    /// LG WebOS — app packaged as `.ipk`, remote events via WebOS API.
    WebOs,
    /// Samsung Tizen — app packaged as `.wgt`, remote events via Tizen API.
    Tizen,
}

/// Returns the detected TV platform, or `None` on non-TV targets.
///
/// Detection is compile-time only — runtime probing is not needed because
/// packaging is always platform-specific.  `wasm32` targets build for the
/// browser; at runtime the JS bootstrap will know whether it is inside a
/// WebOS / Tizen container and can pass `--platform webos|tizen` via a
/// URL parameter that the WASM app reads from `web_sys::window().location()`.
///
/// For native builds this function is always `None` (compiled out on
/// non-WASM targets).
pub fn detect_tv_platform() -> Option<TvPlatform> {
    // LG WebOS and Samsung Tizen both use wasm32 targets; the distinction
    // is made at runtime from a JS environment variable injected by the
    // platform launcher.  Native (non-WASM) builds return None.
    #[cfg(target_arch = "wasm32")]
    {
        // Deferred WASM bridge: read `window.__CRISPY_PLATFORM__` via
        // web_sys and return WebOS/Tizen when the web bootstrap injects it.
        None
    }
    #[cfg(not(target_arch = "wasm32"))]
    {
        None
    }
}

// ── Stub impl ────────────────────────────────────────────────────────────────

/// Stub implementation returning a single synthetic 1920×1080 primary display.
#[derive(Debug, Default)]
pub struct StubDisplayService;

impl StubDisplayService {
    fn synthetic_display() -> DisplayInfo {
        DisplayInfo {
            id: "primary".to_string(),
            name: "Primary Display".to_string(),
            width: 1920,
            height: 1080,
            scale_factor: 1.0,
            is_primary: true,
        }
    }
}

impl DisplayService for StubDisplayService {
    fn list_displays(&self) -> Vec<DisplayInfo> {
        vec![Self::synthetic_display()]
    }

    fn get_primary(&self) -> Option<DisplayInfo> {
        Some(Self::synthetic_display())
    }

    fn set_fullscreen_display(&self, _id: &str) {}
}

// ── Tests ────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn display_info_fields() {
        let d = DisplayInfo {
            id: "d0".to_string(),
            name: "HDMI-1".to_string(),
            width: 3840,
            height: 2160,
            scale_factor: 2.0,
            is_primary: true,
        };
        assert_eq!(d.width, 3840);
        assert_eq!(d.height, 2160);
        assert!((d.scale_factor - 2.0).abs() < f64::EPSILON);
        assert!(d.is_primary);
    }

    #[test]
    fn stub_list_displays_returns_one_entry() {
        let svc = StubDisplayService;
        let displays = svc.list_displays();
        assert_eq!(displays.len(), 1);
    }

    #[test]
    fn stub_primary_display_is_1920x1080() {
        let svc = StubDisplayService;
        let primary = svc.get_primary().expect("primary should be present");
        assert_eq!(primary.width, 1920);
        assert_eq!(primary.height, 1080);
        assert!(primary.is_primary);
    }

    #[test]
    fn stub_primary_scale_factor_is_one() {
        let svc = StubDisplayService;
        let primary = svc.get_primary().unwrap();
        assert!((primary.scale_factor - 1.0).abs() < f64::EPSILON);
    }

    #[test]
    fn stub_set_fullscreen_display_does_not_panic() {
        let svc = StubDisplayService;
        svc.set_fullscreen_display("primary");
    }

    #[test]
    fn stub_list_and_primary_agree() {
        let svc = StubDisplayService;
        let list = svc.list_displays();
        let primary = svc.get_primary().unwrap();
        assert_eq!(list[0], primary);
    }

    // ── ResizableWindowService stub ───────────────────────────────────────────

    #[test]
    fn stub_resizable_window_platform_is_none() {
        let svc = StubResizableWindow;
        assert!(svc.platform().is_none());
    }

    #[test]
    fn stub_resizable_window_is_not_resizable() {
        let svc = StubResizableWindow;
        assert!(!svc.is_resizable());
    }

    #[test]
    fn stub_resizable_window_on_resize_does_not_panic() {
        let svc = StubResizableWindow;
        svc.on_window_resize(Box::new(|_w, _h| {}));
    }

    #[test]
    fn resizable_window_platform_variants_are_distinct() {
        assert_ne!(
            ResizableWindowPlatform::SamsungDex,
            ResizableWindowPlatform::IpadStageManager
        );
        assert_ne!(
            ResizableWindowPlatform::SamsungDex,
            ResizableWindowPlatform::Desktop
        );
    }

    // ── TV platform detection ─────────────────────────────────────────────────

    /// On native (non-WASM) builds the detector always returns None.
    #[cfg(not(target_arch = "wasm32"))]
    #[test]
    fn detect_tv_platform_returns_none_on_native() {
        assert!(detect_tv_platform().is_none());
    }

    #[test]
    fn tv_platform_variants_are_distinct() {
        assert_ne!(TvPlatform::WebOs, TvPlatform::Tizen);
    }
}
