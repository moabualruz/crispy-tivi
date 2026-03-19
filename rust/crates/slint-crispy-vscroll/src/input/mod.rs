//! Input classification and routing.
//!
//! Defines the `InputRouter` trait and re-exports all input handlers.

use crate::core::types::NavDirection;

// ---------------------------------------------------------------------------
// KeyAction — shared by dpad, keyboard, gamepad (no feature gate needed)
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
// EventOutcome — shared by all input handlers
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum EventOutcome {
    Consumed(KeyAction),
    Unconsumed,
}

use crate::core::events::RawInputEvent;

#[cfg(feature = "input-keyboard")]
pub use keyboard::{InputConfig, KeyboardHandler};

#[cfg(feature = "input-dpad")]
pub mod dpad;
#[cfg(feature = "input-gamepad")]
pub mod gamepad;
#[cfg(feature = "input-inject")]
pub mod inject;
#[cfg(feature = "input-keyboard")]
pub mod keyboard;
#[cfg(feature = "input-mouse")]
pub mod mouse;
#[cfg(feature = "input-touch")]
pub mod touch;
#[cfg(feature = "input-trackpad")]
pub mod trackpad;

// ---------------------------------------------------------------------------
// InputRouter trait (Task 1)
// ---------------------------------------------------------------------------

/// Common interface for all input handler types.
///
/// Each handler classifies a `RawInputEvent` and returns an `EventOutcome`
/// indicating whether it was consumed and what action was produced.
pub trait InputRouter: Send + Sync {
    /// Process a raw input event.
    ///
    /// - Returns `EventOutcome::Consumed(action)` if the handler claims this event.
    /// - Returns `EventOutcome::Unconsumed` if the event is not relevant.
    fn route(&self, event: &RawInputEvent) -> EventOutcome;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::events::RawInputEvent;

    struct AlwaysConsumed;

    impl InputRouter for AlwaysConsumed {
        fn route(&self, _event: &RawInputEvent) -> EventOutcome {
            EventOutcome::Consumed(KeyAction::Activate)
        }
    }

    struct NeverConsumed;

    impl InputRouter for NeverConsumed {
        fn route(&self, _event: &RawInputEvent) -> EventOutcome {
            EventOutcome::Unconsumed
        }
    }

    #[test]
    fn test_input_router_trait_object_consumed() {
        use crate::core::events::KeyCode;
        use crate::input::keyboard::make_key_event;
        let router: Box<dyn InputRouter> = Box::new(AlwaysConsumed);
        let ev = make_key_event(KeyCode::ENTER);
        assert_eq!(
            router.route(&ev),
            EventOutcome::Consumed(KeyAction::Activate)
        );
    }

    #[test]
    fn test_input_router_trait_object_unconsumed() {
        use crate::core::events::KeyCode;
        use crate::input::keyboard::make_key_event;
        let router: Box<dyn InputRouter> = Box::new(NeverConsumed);
        let ev = make_key_event(KeyCode::ENTER);
        assert_eq!(router.route(&ev), EventOutcome::Unconsumed);
    }
}
