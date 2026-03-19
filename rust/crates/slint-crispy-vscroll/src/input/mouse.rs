//! Mouse wheel input handler (Task 2).

use crate::core::events::{RawInputEvent, WheelMode};
use crate::core::types::Vec2;

use super::keyboard::EventOutcome;

// ---------------------------------------------------------------------------
// WheelConfig
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct WheelConfig {
    /// Pixels per "line" unit (browser line-mode wheel events).
    pub line_height_px: f32,
    /// Pixels per "page" unit.
    pub page_height_px: f32,
    /// Invert natural scrolling direction.
    pub natural_scrolling: bool,
    /// Multiplier applied to all wheel deltas.
    pub speed_multiplier: f32,
}

impl Default for WheelConfig {
    fn default() -> Self {
        Self {
            line_height_px: 20.0,
            page_height_px: 600.0,
            natural_scrolling: false,
            speed_multiplier: 1.0,
        }
    }
}

// ---------------------------------------------------------------------------
// WheelAction
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct WheelAction {
    /// Computed pixel delta to scroll (positive = scroll down/right).
    pub delta: Vec2,
}

// ---------------------------------------------------------------------------
// MouseWheelHandler (Task 2)
// ---------------------------------------------------------------------------

pub struct MouseWheelHandler {
    config: WheelConfig,
}

impl MouseWheelHandler {
    pub fn new(config: WheelConfig) -> Self {
        Self { config }
    }

    pub fn handle(&self, event: &RawInputEvent) -> EventOutcome {
        let wheel = match event {
            RawInputEvent::Wheel(w) => w,
            _ => return EventOutcome::Unconsumed,
        };

        let scale = match wheel.delta_mode {
            WheelMode::Pixel => 1.0,
            WheelMode::Line => self.config.line_height_px,
            WheelMode::Page => self.config.page_height_px,
        };

        let invert = if wheel.is_inverted ^ self.config.natural_scrolling {
            -1.0_f32
        } else {
            1.0_f32
        };

        let delta = Vec2::new(
            wheel.delta.x * scale * invert * self.config.speed_multiplier,
            wheel.delta.y * scale * invert * self.config.speed_multiplier,
        );

        EventOutcome::Consumed(super::keyboard::KeyAction::ScrollDelta(delta.y))
    }

    /// Returns the raw computed Vec2 delta (both axes).
    pub fn compute_delta(&self, event: &RawInputEvent) -> Option<Vec2> {
        let wheel = match event {
            RawInputEvent::Wheel(w) => w,
            _ => return None,
        };

        let scale = match wheel.delta_mode {
            WheelMode::Pixel => 1.0,
            WheelMode::Line => self.config.line_height_px,
            WheelMode::Page => self.config.page_height_px,
        };

        let invert = if wheel.is_inverted ^ self.config.natural_scrolling {
            -1.0_f32
        } else {
            1.0_f32
        };

        Some(Vec2::new(
            wheel.delta.x * scale * invert * self.config.speed_multiplier,
            wheel.delta.y * scale * invert * self.config.speed_multiplier,
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

    fn wheel_event(x: f32, y: f32, mode: WheelMode) -> RawInputEvent {
        RawInputEvent::Wheel(WheelData {
            delta: Vec3 { x, y, z: 0.0 },
            delta_mode: mode,
            is_inverted: false,
        })
    }

    #[test]
    fn test_pixel_mode_delta_passes_through() {
        let handler = MouseWheelHandler::new(WheelConfig::default());
        let delta = handler
            .compute_delta(&wheel_event(0.0, 50.0, WheelMode::Pixel))
            .unwrap();
        assert!((delta.y - 50.0).abs() < 0.001);
    }

    #[test]
    fn test_line_mode_scales_by_line_height() {
        let handler = MouseWheelHandler::new(WheelConfig::default());
        let delta = handler
            .compute_delta(&wheel_event(0.0, 3.0, WheelMode::Line))
            .unwrap();
        assert!((delta.y - 60.0).abs() < 0.001); // 3 * 20
    }

    #[test]
    fn test_natural_scrolling_inverts() {
        let config = WheelConfig {
            natural_scrolling: true,
            ..WheelConfig::default()
        };
        let handler = MouseWheelHandler::new(config);
        let delta = handler
            .compute_delta(&wheel_event(0.0, 50.0, WheelMode::Pixel))
            .unwrap();
        assert!((delta.y - (-50.0)).abs() < 0.001);
    }

    #[test]
    fn test_inverted_event_inverts() {
        let handler = MouseWheelHandler::new(WheelConfig::default());
        let ev = RawInputEvent::Wheel(WheelData {
            delta: Vec3 {
                x: 0.0,
                y: 50.0,
                z: 0.0,
            },
            delta_mode: WheelMode::Pixel,
            is_inverted: true,
        });
        let delta = handler.compute_delta(&ev).unwrap();
        assert!((delta.y - (-50.0)).abs() < 0.001);
    }

    #[test]
    fn test_speed_multiplier_applied() {
        let config = WheelConfig {
            speed_multiplier: 2.0,
            ..WheelConfig::default()
        };
        let handler = MouseWheelHandler::new(config);
        let delta = handler
            .compute_delta(&wheel_event(0.0, 10.0, WheelMode::Pixel))
            .unwrap();
        assert!((delta.y - 20.0).abs() < 0.001);
    }

    #[test]
    fn test_non_wheel_event_returns_none() {
        use crate::core::events::KeyCode;
        use crate::core::events::KeyData;
        use crate::core::events::Modifiers;
        let handler = MouseWheelHandler::new(WheelConfig::default());
        let ev = RawInputEvent::Key(KeyData {
            key_code: KeyCode::ARROW_DOWN,
            modifiers: Modifiers::default(),
            repeat_count: 0,
            is_repeat: false,
        });
        assert!(handler.compute_delta(&ev).is_none());
    }

    #[test]
    fn test_page_mode_scales_by_page_height() {
        let handler = MouseWheelHandler::new(WheelConfig::default());
        let delta = handler
            .compute_delta(&wheel_event(0.0, 1.0, WheelMode::Page))
            .unwrap();
        assert!((delta.y - 600.0).abs() < 0.001);
    }

    #[test]
    fn test_handle_pixel_returns_consumed() {
        let handler = MouseWheelHandler::new(WheelConfig::default());
        let ev = wheel_event(0.0, 30.0, WheelMode::Pixel);
        assert!(matches!(handler.handle(&ev), EventOutcome::Consumed(_)));
    }

    #[test]
    fn test_handle_non_wheel_returns_unconsumed() {
        use crate::core::events::{KeyCode, KeyData, Modifiers};
        let handler = MouseWheelHandler::new(WheelConfig::default());
        let ev = RawInputEvent::Key(KeyData {
            key_code: KeyCode::ARROW_DOWN,
            modifiers: Modifiers::default(),
            repeat_count: 0,
            is_repeat: false,
        });
        assert!(matches!(handler.handle(&ev), EventOutcome::Unconsumed));
    }

    #[test]
    fn test_handle_x_axis_contributes_to_scroll_delta() {
        let handler = MouseWheelHandler::new(WheelConfig::default());
        let ev = wheel_event(20.0, 0.0, WheelMode::Pixel);
        let delta = handler.compute_delta(&ev).unwrap();
        assert!((delta.x - 20.0).abs() < 0.001);
        assert!((delta.y - 0.0).abs() < 0.001);
    }

    #[test]
    fn test_handle_line_mode_consumed_with_scaling() {
        // Covers mouse.rs lines 66-67: WheelMode::Line branch in handle()
        let handler = MouseWheelHandler::new(WheelConfig::default());
        let ev = wheel_event(0.0, 2.0, WheelMode::Line);
        let outcome = handler.handle(&ev);
        // Should be consumed with delta = 2 * 20 = 40.0
        match outcome {
            EventOutcome::Consumed(crate::input::keyboard::KeyAction::ScrollDelta(d)) => {
                assert!((d - 40.0).abs() < 0.001);
            }
            _ => panic!("expected Consumed"),
        }
    }

    #[test]
    fn test_handle_inverted_event_negates_delta() {
        // Covers mouse.rs line 71: invert = -1.0 branch in handle()
        let handler = MouseWheelHandler::new(WheelConfig::default());
        let ev = RawInputEvent::Wheel(WheelData {
            delta: Vec3 {
                x: 0.0,
                y: 30.0,
                z: 0.0,
            },
            delta_mode: WheelMode::Pixel,
            is_inverted: true, // is_inverted=true, natural_scrolling=false → XOR true → -1.0
        });
        let outcome = handler.handle(&ev);
        match outcome {
            EventOutcome::Consumed(crate::input::keyboard::KeyAction::ScrollDelta(d)) => {
                assert!((d - (-30.0)).abs() < 0.001);
            }
            _ => panic!("expected Consumed"),
        }
    }

    #[test]
    fn test_handle_page_mode_consumed() {
        // Covers mouse.rs line 67 (Page arm) in handle()
        let handler = MouseWheelHandler::new(WheelConfig::default());
        let ev = wheel_event(0.0, 1.0, WheelMode::Page);
        let outcome = handler.handle(&ev);
        match outcome {
            EventOutcome::Consumed(crate::input::keyboard::KeyAction::ScrollDelta(d)) => {
                assert!((d - 600.0).abs() < 0.001);
            }
            _ => panic!("expected Consumed"),
        }
    }

    #[test]
    fn test_natural_scrolling_and_inverted_event_cancel_out() {
        // natural_scrolling=true XOR is_inverted=true → double-invert → positive
        let config = WheelConfig {
            natural_scrolling: true,
            ..WheelConfig::default()
        };
        let handler = MouseWheelHandler::new(config);
        let ev = RawInputEvent::Wheel(crate::core::events::WheelData {
            delta: crate::core::types::Vec3 {
                x: 0.0,
                y: 50.0,
                z: 0.0,
            },
            delta_mode: WheelMode::Pixel,
            is_inverted: true,
        });
        let delta = handler.compute_delta(&ev).unwrap();
        // both inversions cancel: result should be positive
        assert!(delta.y > 0.0);
    }
}
