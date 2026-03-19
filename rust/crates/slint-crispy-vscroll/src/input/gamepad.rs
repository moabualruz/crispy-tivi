//! Gamepad axis and trigger input handler.

use crate::core::events::{GamepadAxisData, GamepadStick, RawInputEvent};
use crate::core::types::{NavDirection, Vec2};

// ---------------------------------------------------------------------------
// GamepadConfig
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct GamepadConfig {
    /// Deadzone radius — axis values within this are treated as zero.
    pub deadzone: f32,
    /// Speed multiplier for scroll from analog stick.
    pub scroll_speed: f32,
    /// Which stick drives scrolling.
    pub scroll_stick: GamepadStick,
}

impl Default for GamepadConfig {
    fn default() -> Self {
        Self {
            deadzone: 0.15,
            scroll_speed: 200.0,
            scroll_stick: GamepadStick::Left,
        }
    }
}

// ---------------------------------------------------------------------------
// GamepadAction
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum GamepadAction {
    /// Continuous scroll from analog stick (pixels/s).
    ScrollVelocity(Vec2),
    /// Discrete navigation from fully pressed direction.
    Navigate(NavDirection),
}

// ---------------------------------------------------------------------------
// GamepadHandler
// ---------------------------------------------------------------------------

pub struct GamepadHandler {
    config: GamepadConfig,
}

impl GamepadHandler {
    pub fn new(config: GamepadConfig) -> Self {
        Self { config }
    }

    /// Handle a `RawInputEvent::GamepadAxis` event.
    pub fn handle_axis(&self, event: &RawInputEvent) -> Option<GamepadAction> {
        let axis_data = match event {
            RawInputEvent::GamepadAxis(d) => d,
            _ => return None,
        };

        if axis_data.stick != self.config.scroll_stick {
            return None;
        }

        let ax = self.apply_deadzone(axis_data);
        if ax.magnitude() < f32::EPSILON {
            return None;
        }

        Some(GamepadAction::ScrollVelocity(ax * self.config.scroll_speed))
    }

    /// Handle a `RawInputEvent::GamepadTrigger` — map to discrete nav.
    pub fn handle_trigger(&self, event: &RawInputEvent) -> Option<GamepadAction> {
        let trigger_data = match event {
            RawInputEvent::GamepadTrigger(t) => t,
            _ => return None,
        };

        use crate::core::events::GamepadTriggerSide;
        if trigger_data.value > 0.5 {
            let dir = match trigger_data.trigger {
                GamepadTriggerSide::L2 => NavDirection::Up,
                GamepadTriggerSide::R2 => NavDirection::Down,
            };
            Some(GamepadAction::Navigate(dir))
        } else {
            None
        }
    }

    fn apply_deadzone(&self, data: &GamepadAxisData) -> Vec2 {
        let ax = data.axis;
        if ax.magnitude() < self.config.deadzone {
            Vec2::ZERO
        } else {
            ax
        }
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::events::{GamepadAxisData, GamepadTriggerData, GamepadTriggerSide};

    #[test]
    fn test_axis_within_deadzone_returns_none() {
        let h = GamepadHandler::new(GamepadConfig::default());
        let ev = RawInputEvent::GamepadAxis(GamepadAxisData {
            stick: GamepadStick::Left,
            axis: Vec2::new(0.1, 0.0),
            deadzone_applied: false,
        });
        assert!(h.handle_axis(&ev).is_none());
    }

    #[test]
    fn test_axis_beyond_deadzone_returns_velocity() {
        let h = GamepadHandler::new(GamepadConfig::default());
        let ev = RawInputEvent::GamepadAxis(GamepadAxisData {
            stick: GamepadStick::Left,
            axis: Vec2::new(0.0, 0.8),
            deadzone_applied: false,
        });
        match h.handle_axis(&ev) {
            Some(GamepadAction::ScrollVelocity(v)) => {
                assert!(v.y.abs() > 0.0);
            }
            _ => panic!("Expected ScrollVelocity"),
        }
    }

    #[test]
    fn test_wrong_stick_returns_none() {
        let h = GamepadHandler::new(GamepadConfig::default()); // scroll_stick = Left
        let ev = RawInputEvent::GamepadAxis(GamepadAxisData {
            stick: GamepadStick::Right,
            axis: Vec2::new(0.0, 1.0),
            deadzone_applied: false,
        });
        assert!(h.handle_axis(&ev).is_none());
    }

    #[test]
    fn test_trigger_r2_maps_to_down() {
        let h = GamepadHandler::new(GamepadConfig::default());
        let ev = RawInputEvent::GamepadTrigger(GamepadTriggerData {
            trigger: GamepadTriggerSide::R2,
            value: 0.9,
        });
        assert_eq!(
            h.handle_trigger(&ev),
            Some(GamepadAction::Navigate(NavDirection::Down))
        );
    }

    #[test]
    fn test_trigger_l2_maps_to_up() {
        let h = GamepadHandler::new(GamepadConfig::default());
        let ev = RawInputEvent::GamepadTrigger(GamepadTriggerData {
            trigger: GamepadTriggerSide::L2,
            value: 0.9,
        });
        assert_eq!(
            h.handle_trigger(&ev),
            Some(GamepadAction::Navigate(NavDirection::Up))
        );
    }

    #[test]
    fn test_trigger_below_threshold_returns_none() {
        let h = GamepadHandler::new(GamepadConfig::default());
        let ev = RawInputEvent::GamepadTrigger(GamepadTriggerData {
            trigger: GamepadTriggerSide::R2,
            value: 0.3,
        });
        assert!(h.handle_trigger(&ev).is_none());
    }

    #[test]
    fn test_handle_axis_non_gamepad_event_returns_none() {
        use crate::core::events::{KeyCode, KeyData, Modifiers};
        let h = GamepadHandler::new(GamepadConfig::default());
        let ev = RawInputEvent::Key(KeyData {
            key_code: KeyCode::ARROW_DOWN,
            modifiers: Modifiers::default(),
            repeat_count: 0,
            is_repeat: false,
        });
        assert!(h.handle_axis(&ev).is_none());
    }

    #[test]
    fn test_handle_trigger_non_trigger_event_returns_none() {
        use crate::core::events::{KeyCode, KeyData, Modifiers};
        let h = GamepadHandler::new(GamepadConfig::default());
        let ev = RawInputEvent::Key(KeyData {
            key_code: KeyCode::ARROW_DOWN,
            modifiers: Modifiers::default(),
            repeat_count: 0,
            is_repeat: false,
        });
        assert!(h.handle_trigger(&ev).is_none());
    }
}
