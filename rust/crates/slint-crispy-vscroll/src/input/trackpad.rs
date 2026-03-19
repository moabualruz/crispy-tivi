//! Trackpad (precision scroll) input handler (Task 2 extension).

use crate::core::events::{RawInputEvent, WheelMode};
use crate::core::types::Vec2;

// ---------------------------------------------------------------------------
// TrackpadConfig
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct TrackpadConfig {
    /// Scale factor for pixel-mode trackpad events.
    pub pixel_scale: f32,
    /// Whether to apply momentum when the user lifts fingers.
    pub momentum_enabled: bool,
}

impl Default for TrackpadConfig {
    fn default() -> Self {
        Self {
            pixel_scale: 1.0,
            momentum_enabled: true,
        }
    }
}

// ---------------------------------------------------------------------------
// TrackpadHandler
// ---------------------------------------------------------------------------

pub struct TrackpadHandler {
    config: TrackpadConfig,
}

impl TrackpadHandler {
    pub fn new(config: TrackpadConfig) -> Self {
        Self { config }
    }

    /// Compute the pixel delta from a wheel event (trackpad precision scroll).
    pub fn compute_delta(&self, event: &RawInputEvent) -> Option<Vec2> {
        let wheel = match event {
            RawInputEvent::Wheel(w) => w,
            _ => return None,
        };

        // Trackpad events are always pixel mode
        if !matches!(wheel.delta_mode, WheelMode::Pixel) {
            return None;
        }

        let invert = if wheel.is_inverted { -1.0_f32 } else { 1.0_f32 };

        Some(Vec2::new(
            wheel.delta.x * self.config.pixel_scale * invert,
            wheel.delta.y * self.config.pixel_scale * invert,
        ))
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::events::{WheelData, WheelMode};
    use crate::core::types::Vec3;

    fn pixel_wheel(x: f32, y: f32) -> RawInputEvent {
        RawInputEvent::Wheel(WheelData {
            delta: Vec3 { x, y, z: 0.0 },
            delta_mode: WheelMode::Pixel,
            is_inverted: false,
        })
    }

    #[test]
    fn test_trackpad_pixel_delta_passthrough() {
        let h = TrackpadHandler::new(TrackpadConfig::default());
        let d = h.compute_delta(&pixel_wheel(10.0, 20.0)).unwrap();
        assert!((d.x - 10.0).abs() < 0.001);
        assert!((d.y - 20.0).abs() < 0.001);
    }

    #[test]
    fn test_trackpad_line_mode_returns_none() {
        let h = TrackpadHandler::new(TrackpadConfig::default());
        let ev = RawInputEvent::Wheel(WheelData {
            delta: Vec3 {
                x: 0.0,
                y: 3.0,
                z: 0.0,
            },
            delta_mode: WheelMode::Line,
            is_inverted: false,
        });
        assert!(h.compute_delta(&ev).is_none());
    }

    #[test]
    fn test_trackpad_scale_applied() {
        let config = TrackpadConfig {
            pixel_scale: 1.5,
            ..TrackpadConfig::default()
        };
        let h = TrackpadHandler::new(config);
        let d = h.compute_delta(&pixel_wheel(10.0, 20.0)).unwrap();
        assert!((d.y - 30.0).abs() < 0.001);
    }

    #[test]
    fn test_trackpad_inverted_event_negates_delta() {
        let h = TrackpadHandler::new(TrackpadConfig::default());
        let ev = RawInputEvent::Wheel(WheelData {
            delta: Vec3 {
                x: 0.0,
                y: 20.0,
                z: 0.0,
            },
            delta_mode: WheelMode::Pixel,
            is_inverted: true,
        });
        let d = h.compute_delta(&ev).unwrap();
        assert!((d.y - (-20.0)).abs() < 0.001);
    }

    #[test]
    fn test_trackpad_non_wheel_event_returns_none() {
        use crate::core::events::{KeyCode, KeyData, Modifiers};
        let h = TrackpadHandler::new(TrackpadConfig::default());
        let ev = RawInputEvent::Key(KeyData {
            key_code: KeyCode::ARROW_DOWN,
            modifiers: Modifiers::default(),
            repeat_count: 0,
            is_repeat: false,
        });
        assert!(h.compute_delta(&ev).is_none());
    }

    #[test]
    fn test_trackpad_page_mode_returns_none() {
        let h = TrackpadHandler::new(TrackpadConfig::default());
        let ev = RawInputEvent::Wheel(WheelData {
            delta: Vec3 {
                x: 0.0,
                y: 1.0,
                z: 0.0,
            },
            delta_mode: WheelMode::Page,
            is_inverted: false,
        });
        assert!(h.compute_delta(&ev).is_none());
    }
}
