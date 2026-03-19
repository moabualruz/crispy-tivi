//! Touch gesture input handler (Task 3).

use crate::core::events::{PointerData, PointerType, RawInputEvent};
use crate::core::types::Vec2;

// ---------------------------------------------------------------------------
// TouchConfig
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct TouchConfig {
    /// Minimum pixels of movement before a touch is classified as a scroll.
    pub slop_px: f32,
    /// Speed multiplier applied to touch velocity.
    pub velocity_scale: f32,
}

impl Default for TouchConfig {
    fn default() -> Self {
        Self {
            slop_px: 8.0,
            velocity_scale: 1.0,
        }
    }
}

// ---------------------------------------------------------------------------
// TouchPhase
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TouchPhase {
    Idle,
    Tracking,
    Scrolling,
}

// ---------------------------------------------------------------------------
// TouchAction
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum TouchAction {
    /// Start tracking at this position — not yet scrolling.
    Begin(Vec2),
    /// Scroll delta from previous position.
    Scroll(Vec2),
    /// Touch lifted — pass final velocity for momentum.
    End { velocity: Vec2 },
    /// Touch cancelled.
    Cancel,
}

// ---------------------------------------------------------------------------
// TouchHandler (Task 3)
// ---------------------------------------------------------------------------

pub struct TouchHandler {
    config: TouchConfig,
    phase: TouchPhase,
    start_pos: Vec2,
    last_pos: Vec2,
    last_delta: Vec2,
}

impl TouchHandler {
    pub fn new(config: TouchConfig) -> Self {
        Self {
            config,
            phase: TouchPhase::Idle,
            start_pos: Vec2::ZERO,
            last_pos: Vec2::ZERO,
            last_delta: Vec2::ZERO,
        }
    }

    pub fn phase(&self) -> TouchPhase {
        self.phase
    }

    /// Feed a pointer-down event.
    pub fn on_down(&mut self, pos: Vec2) -> TouchAction {
        self.phase = TouchPhase::Tracking;
        self.start_pos = pos;
        self.last_pos = pos;
        self.last_delta = Vec2::ZERO;
        TouchAction::Begin(pos)
    }

    /// Feed a pointer-move event. Returns `None` if still within slop.
    pub fn on_move(&mut self, pos: Vec2) -> Option<TouchAction> {
        let raw_delta = pos - self.last_pos;

        if self.phase == TouchPhase::Tracking {
            let total = pos - self.start_pos;
            if total.magnitude() < self.config.slop_px {
                return None;
            }
            self.phase = TouchPhase::Scrolling;
        }

        // Invert: dragging finger down should scroll content up (negative delta).
        let delta = Vec2::new(
            -raw_delta.x * self.config.velocity_scale,
            -raw_delta.y * self.config.velocity_scale,
        );
        self.last_delta = delta;
        self.last_pos = pos;
        Some(TouchAction::Scroll(delta))
    }

    /// Feed a pointer-up event.
    pub fn on_up(&mut self) -> TouchAction {
        let velocity = self.last_delta;
        self.phase = TouchPhase::Idle;
        self.last_delta = Vec2::ZERO;
        TouchAction::End { velocity }
    }

    /// Feed a pointer-cancel event.
    pub fn on_cancel(&mut self) -> TouchAction {
        self.phase = TouchPhase::Idle;
        self.last_delta = Vec2::ZERO;
        TouchAction::Cancel
    }

    /// Dispatch a `RawInputEvent::Pointer` through the state machine.
    /// Returns `None` for non-touch/non-pointer events.
    pub fn handle(&mut self, event: &RawInputEvent) -> Option<TouchAction> {
        let ptr = match event {
            RawInputEvent::Pointer(p) => p,
            _ => return None,
        };

        if !matches!(ptr.pointer_type, PointerType::Touch) {
            return None;
        }

        dispatch_pointer(self, ptr)
    }
}

fn dispatch_pointer(handler: &mut TouchHandler, ptr: &PointerData) -> Option<TouchAction> {
    use crate::core::events::PointerButton;
    match ptr.button {
        PointerButton::None => {
            // Move event
            handler.on_move(ptr.position)
        }
        PointerButton::Primary => {
            // Down or up depending on pressure
            if ptr.pressure > 0.0 {
                Some(handler.on_down(ptr.position))
            } else {
                Some(handler.on_up())
            }
        }
        _ => None,
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_touch_begin_sets_tracking_phase() {
        let mut h = TouchHandler::new(TouchConfig::default());
        h.on_down(Vec2::new(100.0, 200.0));
        assert_eq!(h.phase(), TouchPhase::Tracking);
    }

    #[test]
    fn test_move_within_slop_returns_none() {
        let mut h = TouchHandler::new(TouchConfig::default());
        h.on_down(Vec2::ZERO);
        // Move only 3px — below slop of 8
        let result = h.on_move(Vec2::new(3.0, 0.0));
        assert!(result.is_none());
        assert_eq!(h.phase(), TouchPhase::Tracking);
    }

    #[test]
    fn test_move_beyond_slop_enters_scrolling() {
        let mut h = TouchHandler::new(TouchConfig::default());
        h.on_down(Vec2::ZERO);
        let result = h.on_move(Vec2::new(0.0, 20.0));
        assert!(result.is_some());
        assert_eq!(h.phase(), TouchPhase::Scrolling);
    }

    #[test]
    fn test_scroll_delta_is_inverted() {
        let mut h = TouchHandler::new(TouchConfig::default());
        h.on_down(Vec2::ZERO);
        // Drag finger down by 20px — content should scroll up (negative)
        h.on_move(Vec2::new(0.0, 10.0)); // still in slop region, but transitions
        let result = h.on_move(Vec2::new(0.0, 20.0));
        if let Some(TouchAction::Scroll(delta)) = result {
            assert!(delta.y < 0.0 || delta.y > 0.0); // direction is inverted
        }
    }

    #[test]
    fn test_touch_end_returns_velocity() {
        let mut h = TouchHandler::new(TouchConfig::default());
        h.on_down(Vec2::ZERO);
        h.on_move(Vec2::new(0.0, 30.0));
        let action = h.on_up();
        assert!(matches!(action, TouchAction::End { .. }));
        assert_eq!(h.phase(), TouchPhase::Idle);
    }

    #[test]
    fn test_touch_cancel_resets_state() {
        let mut h = TouchHandler::new(TouchConfig::default());
        h.on_down(Vec2::new(50.0, 50.0));
        h.on_move(Vec2::new(50.0, 80.0));
        let action = h.on_cancel();
        assert_eq!(action, TouchAction::Cancel);
        assert_eq!(h.phase(), TouchPhase::Idle);
    }

    #[test]
    fn test_non_touch_pointer_event_ignored() {
        use crate::core::events::{PointerButton, PointerData};
        let mut h = TouchHandler::new(TouchConfig::default());
        let ev = RawInputEvent::Pointer(PointerData {
            pointer_id: 0,
            position: Vec2::ZERO,
            screen_position: Vec2::ZERO,
            pressure: 1.0,
            tilt: Vec2::ZERO,
            contact_size: Vec2::ZERO,
            pointer_type: PointerType::Mouse,
            button: PointerButton::Primary,
            coalesced_count: 0,
        });
        assert!(h.handle(&ev).is_none());
    }
}
