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
}
