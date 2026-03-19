//! D-pad input handler with repeat and acceleration (Task 5).

use crate::core::events::{KeyCode, RawInputEvent};
use crate::core::types::NavDirection;

use super::{EventOutcome, KeyAction};

// ---------------------------------------------------------------------------
// DpadConfig
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct DpadConfig {
    /// How long to hold before repeat starts (ms).
    pub repeat_delay_ms: u32,
    /// Rate of repeated events once repeating (ms between events).
    pub repeat_rate_ms: u32,
    /// Enable acceleration: repeated presses increase step size.
    pub acceleration: bool,
    /// Acceleration curve exponent (0.0–1.0 — lower = faster ramp).
    pub acceleration_curve: f32,
}

impl Default for DpadConfig {
    fn default() -> Self {
        Self {
            repeat_delay_ms: 400,
            repeat_rate_ms: 100,
            acceleration: true,
            acceleration_curve: 0.85,
        }
    }
}

// ---------------------------------------------------------------------------
// DpadAction
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct DpadAction {
    pub direction: NavDirection,
    /// Multiplier from acceleration (1.0 = no acceleration).
    pub step_multiplier: f32,
}

// ---------------------------------------------------------------------------
// DpadHandler (Task 5)
// ---------------------------------------------------------------------------

pub struct DpadHandler {
    config: DpadConfig,
    held_dir: Option<NavDirection>,
    held_ms: u32,
    repeat_step: u32,
}

impl DpadHandler {
    pub fn new(config: DpadConfig) -> Self {
        Self {
            config,
            held_dir: None,
            held_ms: 0,
            repeat_step: 0,
        }
    }

    /// Call on each frame with elapsed_ms since last frame.
    /// Returns a `DpadAction` if a repeat fire should occur.
    pub fn tick(&mut self, elapsed_ms: u32) -> Option<DpadAction> {
        let dir = self.held_dir?;
        self.held_ms += elapsed_ms;

        if self.held_ms >= self.config.repeat_delay_ms {
            let since_delay = self.held_ms - self.config.repeat_delay_ms;
            let new_step = since_delay / self.config.repeat_rate_ms;
            if new_step > self.repeat_step {
                self.repeat_step = new_step;
                let multiplier = self.compute_multiplier(new_step);
                return Some(DpadAction {
                    direction: dir,
                    step_multiplier: multiplier,
                });
            }
        }
        None
    }

    /// Handle a key-down event. Returns the initial `DpadAction` if it's a nav key.
    pub fn on_key_down(&mut self, event: &RawInputEvent) -> Option<DpadAction> {
        let key_code = extract_key_code(event)?;
        let dir = key_code.to_nav_direction()?;
        self.held_dir = Some(dir);
        self.held_ms = 0;
        self.repeat_step = 0;
        Some(DpadAction {
            direction: dir,
            step_multiplier: 1.0,
        })
    }

    /// Handle a key-up event. Clears the held state.
    pub fn on_key_up(&mut self, event: &RawInputEvent) {
        if let Some(key_code) = extract_key_code(event) {
            if key_code.to_nav_direction().is_some() {
                self.held_dir = None;
                self.held_ms = 0;
                self.repeat_step = 0;
            }
        }
    }

    /// Returns the current held direction, if any.
    pub fn held_direction(&self) -> Option<NavDirection> {
        self.held_dir
    }

    // -----------------------------------------------------------------------
    // Private
    // -----------------------------------------------------------------------

    fn compute_multiplier(&self, step: u32) -> f32 {
        if !self.config.acceleration || step == 0 {
            return 1.0;
        }
        // Exponential ramp: multiplier = step^(1 - curve)
        // curve=0.85 → gentle acceleration
        let exponent = 1.0 - self.config.acceleration_curve;
        (step as f32).powf(exponent).max(1.0)
    }
}

/// Wraps `handle` for compatibility with InputRouter trait pattern.
pub fn handle_dpad(handler: &mut DpadHandler, event: &RawInputEvent) -> EventOutcome {
    if let Some(action) = handler.on_key_down(event) {
        EventOutcome::Consumed(KeyAction::Navigate(action.direction))
    } else {
        EventOutcome::Unconsumed
    }
}

fn extract_key_code(event: &RawInputEvent) -> Option<KeyCode> {
    match event {
        RawInputEvent::Key(k) => Some(k.key_code),
        _ => None,
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::events::{KeyData, Modifiers};

    fn nav_key_event(code: KeyCode) -> RawInputEvent {
        RawInputEvent::Key(KeyData {
            key_code: code,
            modifiers: Modifiers::default(),
            repeat_count: 0,
            is_repeat: false,
        })
    }

    #[test]
    fn test_dpad_down_key_returns_action() {
        let mut h = DpadHandler::new(DpadConfig::default());
        let ev = nav_key_event(KeyCode::ARROW_DOWN);
        let action = h.on_key_down(&ev).unwrap();
        assert_eq!(action.direction, NavDirection::Down);
        assert!((action.step_multiplier - 1.0).abs() < 0.001);
    }

    #[test]
    fn test_dpad_up_key_returns_action() {
        let mut h = DpadHandler::new(DpadConfig::default());
        let ev = nav_key_event(KeyCode::ARROW_UP);
        let action = h.on_key_down(&ev).unwrap();
        assert_eq!(action.direction, NavDirection::Up);
    }

    #[test]
    fn test_dpad_non_nav_key_returns_none() {
        let mut h = DpadHandler::new(DpadConfig::default());
        let ev = nav_key_event(KeyCode::ENTER);
        assert!(h.on_key_down(&ev).is_none());
    }

    #[test]
    fn test_dpad_no_repeat_before_delay() {
        let mut h = DpadHandler::new(DpadConfig::default());
        let ev = nav_key_event(KeyCode::ARROW_DOWN);
        h.on_key_down(&ev);
        // Tick 300ms — below delay of 400ms
        let result = h.tick(300);
        assert!(result.is_none());
    }

    #[test]
    fn test_dpad_repeat_fires_after_delay() {
        let mut h = DpadHandler::new(DpadConfig::default());
        let ev = nav_key_event(KeyCode::ARROW_DOWN);
        h.on_key_down(&ev);
        // Tick past delay + one repeat period
        h.tick(400); // hits delay
        let result = h.tick(100); // one repeat period
        assert!(result.is_some());
    }

    #[test]
    fn test_dpad_key_up_clears_held_dir() {
        let mut h = DpadHandler::new(DpadConfig::default());
        let down_ev = nav_key_event(KeyCode::ARROW_DOWN);
        h.on_key_down(&down_ev);
        assert!(h.held_direction().is_some());
        h.on_key_up(&down_ev);
        assert!(h.held_direction().is_none());
    }

    #[test]
    fn test_dpad_acceleration_increases_multiplier() {
        let config = DpadConfig {
            repeat_delay_ms: 0,
            repeat_rate_ms: 100,
            acceleration: true,
            acceleration_curve: 0.5,
        };
        let mut h = DpadHandler::new(config);
        let ev = nav_key_event(KeyCode::ARROW_DOWN);
        h.on_key_down(&ev);
        // After many repeat steps, multiplier should grow
        h.tick(500); // step 5
        let action = h.tick(100); // step 6
        if let Some(a) = action {
            assert!(a.step_multiplier >= 1.0);
        }
    }

    #[test]
    fn test_dpad_acceleration_disabled_multiplier_stays_one() {
        let config = DpadConfig {
            acceleration: false,
            repeat_delay_ms: 0,
            repeat_rate_ms: 100,
            ..DpadConfig::default()
        };
        let mut h = DpadHandler::new(config);
        let ev = nav_key_event(KeyCode::ARROW_DOWN);
        h.on_key_down(&ev);
        h.tick(200);
        let action = h.tick(100);
        if let Some(a) = action {
            assert!((a.step_multiplier - 1.0).abs() < 0.001);
        }
    }

    #[test]
    fn test_handle_dpad_consumed_for_nav_key() {
        use super::super::keyboard::EventOutcome;
        let mut h = DpadHandler::new(DpadConfig::default());
        let ev = nav_key_event(KeyCode::ARROW_DOWN);
        let outcome = handle_dpad(&mut h, &ev);
        assert!(matches!(outcome, EventOutcome::Consumed(_)));
    }

    #[test]
    fn test_handle_dpad_unconsumed_for_non_nav_key() {
        use super::super::keyboard::EventOutcome;
        let mut h = DpadHandler::new(DpadConfig::default());
        let ev = nav_key_event(KeyCode::ENTER);
        let outcome = handle_dpad(&mut h, &ev);
        assert!(matches!(outcome, EventOutcome::Unconsumed));
    }

    #[test]
    fn test_handle_dpad_non_key_event_unconsumed() {
        use super::super::keyboard::EventOutcome;
        use crate::core::events::{WheelData, WheelMode};
        use crate::core::types::Vec3;
        let mut h = DpadHandler::new(DpadConfig::default());
        let ev = RawInputEvent::Wheel(WheelData {
            delta: Vec3 {
                x: 0.0,
                y: 10.0,
                z: 0.0,
            },
            delta_mode: WheelMode::Pixel,
            is_inverted: false,
        });
        let outcome = handle_dpad(&mut h, &ev);
        assert!(matches!(outcome, EventOutcome::Unconsumed));
    }
}
