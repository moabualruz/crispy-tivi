//! Keyboard and D-pad input handler (Task 1).

use crate::core::events::{KeyCode, KeyData, Modifiers, RawInputEvent};
use crate::core::types::{Direction, NavDirection};

// ---------------------------------------------------------------------------
// InputConfig
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct InputConfig {
    /// Which layout direction this scroller scrolls in.
    pub direction: Direction,
    /// If true, Page Up/Down scroll by a full page; else by step.
    pub page_keys_enabled: bool,
    /// Step size for a single D-pad/arrow press (pixels).
    pub step_px: f32,
    /// Page size override (0 = use viewport height).
    pub page_px: f32,
}

impl Default for InputConfig {
    fn default() -> Self {
        Self {
            direction: Direction::Vertical,
            page_keys_enabled: true,
            step_px: 60.0,
            page_px: 0.0,
        }
    }
}

// ---------------------------------------------------------------------------
// KeyAction
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum KeyAction {
    Navigate(NavDirection),
    ScrollDelta(f32),
    PageDelta(f32),
    JumpToStart,
    JumpToEnd,
    Activate,
    Dismiss,
}

// ---------------------------------------------------------------------------
// EventOutcome
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum EventOutcome {
    Consumed(KeyAction),
    Unconsumed,
}

// ---------------------------------------------------------------------------
// KeyboardHandler (Tasks 1, 5)
// ---------------------------------------------------------------------------

pub struct KeyboardHandler {
    config: InputConfig,
}

impl KeyboardHandler {
    pub fn new(config: InputConfig) -> Self {
        Self { config }
    }

    /// Classify a `RawInputEvent::Key` and return an `EventOutcome`.
    /// `viewport_size` is used for page-scroll computation.
    pub fn handle(&self, event: &RawInputEvent, viewport_size: f32) -> EventOutcome {
        let key_data = match event {
            RawInputEvent::Key(k) => k,
            _ => return EventOutcome::Unconsumed,
        };

        if let Some(action) = self.classify(key_data, viewport_size) {
            EventOutcome::Consumed(action)
        } else {
            EventOutcome::Unconsumed
        }
    }

    fn classify(&self, kd: &KeyData, viewport_size: f32) -> Option<KeyAction> {
        let page = if self.config.page_px > 0.0 {
            self.config.page_px
        } else {
            viewport_size
        };

        match kd.key_code {
            KeyCode::ARROW_UP => Some(KeyAction::Navigate(NavDirection::Up)),
            KeyCode::ARROW_DOWN => Some(KeyAction::Navigate(NavDirection::Down)),
            KeyCode::ARROW_LEFT => Some(KeyAction::Navigate(NavDirection::Left)),
            KeyCode::ARROW_RIGHT => Some(KeyAction::Navigate(NavDirection::Right)),
            KeyCode::PAGE_UP if self.config.page_keys_enabled => Some(KeyAction::PageDelta(-page)),
            KeyCode::PAGE_DOWN if self.config.page_keys_enabled => Some(KeyAction::PageDelta(page)),
            KeyCode::HOME => Some(KeyAction::JumpToStart),
            KeyCode::END => Some(KeyAction::JumpToEnd),
            KeyCode::ENTER => Some(KeyAction::Activate),
            KeyCode::ESCAPE => Some(KeyAction::Dismiss),
            _ => None,
        }
    }
}

// ---------------------------------------------------------------------------
// Helper: build a RawInputEvent::Key from a KeyCode
// ---------------------------------------------------------------------------

pub fn make_key_event(key_code: KeyCode) -> RawInputEvent {
    RawInputEvent::Key(KeyData {
        key_code,
        modifiers: Modifiers::default(),
        repeat_count: 0,
        is_repeat: false,
    })
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_key_down_maps_to_navigate_down() {
        let handler = KeyboardHandler::new(InputConfig::default());
        let ev = make_key_event(KeyCode::ARROW_DOWN);
        let outcome = handler.handle(&ev, 600.0);
        assert_eq!(
            outcome,
            EventOutcome::Consumed(KeyAction::Navigate(NavDirection::Down))
        );
    }

    #[test]
    fn test_key_up_maps_to_navigate_up() {
        let handler = KeyboardHandler::new(InputConfig::default());
        let ev = make_key_event(KeyCode::ARROW_UP);
        let outcome = handler.handle(&ev, 600.0);
        assert_eq!(
            outcome,
            EventOutcome::Consumed(KeyAction::Navigate(NavDirection::Up))
        );
    }

    #[test]
    fn test_key_left_maps_to_navigate_left() {
        let handler = KeyboardHandler::new(InputConfig::default());
        let ev = make_key_event(KeyCode::ARROW_LEFT);
        let outcome = handler.handle(&ev, 600.0);
        assert_eq!(
            outcome,
            EventOutcome::Consumed(KeyAction::Navigate(NavDirection::Left))
        );
    }

    #[test]
    fn test_key_right_maps_to_navigate_right() {
        let handler = KeyboardHandler::new(InputConfig::default());
        let ev = make_key_event(KeyCode::ARROW_RIGHT);
        let outcome = handler.handle(&ev, 600.0);
        assert_eq!(
            outcome,
            EventOutcome::Consumed(KeyAction::Navigate(NavDirection::Right))
        );
    }

    #[test]
    fn test_page_down_produces_page_delta_positive() {
        let handler = KeyboardHandler::new(InputConfig::default());
        let ev = make_key_event(KeyCode::PAGE_DOWN);
        let outcome = handler.handle(&ev, 600.0);
        assert_eq!(outcome, EventOutcome::Consumed(KeyAction::PageDelta(600.0)));
    }

    #[test]
    fn test_page_up_produces_page_delta_negative() {
        let handler = KeyboardHandler::new(InputConfig::default());
        let ev = make_key_event(KeyCode::PAGE_UP);
        let outcome = handler.handle(&ev, 600.0);
        assert_eq!(
            outcome,
            EventOutcome::Consumed(KeyAction::PageDelta(-600.0))
        );
    }

    #[test]
    fn test_home_maps_to_jump_start() {
        let handler = KeyboardHandler::new(InputConfig::default());
        let ev = make_key_event(KeyCode::HOME);
        let outcome = handler.handle(&ev, 600.0);
        assert_eq!(outcome, EventOutcome::Consumed(KeyAction::JumpToStart));
    }

    #[test]
    fn test_end_maps_to_jump_end() {
        let handler = KeyboardHandler::new(InputConfig::default());
        let ev = make_key_event(KeyCode::END);
        let outcome = handler.handle(&ev, 600.0);
        assert_eq!(outcome, EventOutcome::Consumed(KeyAction::JumpToEnd));
    }

    #[test]
    fn test_enter_maps_to_activate() {
        let handler = KeyboardHandler::new(InputConfig::default());
        let ev = make_key_event(KeyCode::ENTER);
        let outcome = handler.handle(&ev, 0.0);
        assert_eq!(outcome, EventOutcome::Consumed(KeyAction::Activate));
    }

    #[test]
    fn test_escape_maps_to_dismiss() {
        let handler = KeyboardHandler::new(InputConfig::default());
        let ev = make_key_event(KeyCode::ESCAPE);
        let outcome = handler.handle(&ev, 0.0);
        assert_eq!(outcome, EventOutcome::Consumed(KeyAction::Dismiss));
    }

    #[test]
    fn test_space_is_unconsumed() {
        let handler = KeyboardHandler::new(InputConfig::default());
        let ev = make_key_event(KeyCode::SPACE);
        let outcome = handler.handle(&ev, 0.0);
        assert_eq!(outcome, EventOutcome::Unconsumed);
    }

    #[test]
    fn test_non_key_event_is_unconsumed() {
        use crate::core::events::{WheelData, WheelMode};
        use crate::core::types::Vec3;
        let handler = KeyboardHandler::new(InputConfig::default());
        let ev = RawInputEvent::Wheel(WheelData {
            delta: Vec3::default(),
            delta_mode: WheelMode::Pixel,
            is_inverted: false,
        });
        assert_eq!(handler.handle(&ev, 600.0), EventOutcome::Unconsumed);
    }

    #[test]
    fn test_page_keys_disabled_returns_unconsumed() {
        let config = InputConfig {
            page_keys_enabled: false,
            ..InputConfig::default()
        };
        let handler = KeyboardHandler::new(config);
        let ev = make_key_event(KeyCode::PAGE_DOWN);
        assert_eq!(handler.handle(&ev, 600.0), EventOutcome::Unconsumed);
    }

    #[test]
    fn test_custom_page_px_overrides_viewport() {
        let config = InputConfig {
            page_px: 400.0,
            ..InputConfig::default()
        };
        let handler = KeyboardHandler::new(config);
        let ev = make_key_event(KeyCode::PAGE_DOWN);
        assert_eq!(
            handler.handle(&ev, 600.0),
            EventOutcome::Consumed(KeyAction::PageDelta(400.0))
        );
    }
}
