//! Slint-side transition metadata (Task 7).
//!
//! Provides configuration structs that map to Slint `animate {}` declarations.
//! No actual Slint runtime calls happen here — this module is pure Rust config
//! so it can be unit-tested without the Slint runtime.

use crate::core::config::EasingCurve;

// ---------------------------------------------------------------------------
// TransitionSpec
// ---------------------------------------------------------------------------

/// Describes a single Slint animated property transition.
#[derive(Debug, Clone, PartialEq)]
pub struct TransitionSpec {
    /// Target property name (informational, for builders).
    pub property: &'static str,
    /// Duration in milliseconds.
    pub duration_ms: u32,
    /// Easing curve.
    pub easing: EasingCurve,
    /// Delay before starting (ms).
    pub delay_ms: u32,
}

impl TransitionSpec {
    pub fn new(property: &'static str, duration_ms: u32, easing: EasingCurve) -> Self {
        Self {
            property,
            duration_ms,
            easing,
            delay_ms: 0,
        }
    }

    pub fn with_delay(mut self, delay_ms: u32) -> Self {
        self.delay_ms = delay_ms;
        self
    }
}

// ---------------------------------------------------------------------------
// SlintTransitionSet
// ---------------------------------------------------------------------------

/// A set of transitions for a virtual scroll slot.
#[derive(Debug, Clone)]
pub struct SlintTransitionSet {
    pub scale: TransitionSpec,
    pub opacity: TransitionSpec,
    pub translate_x: TransitionSpec,
    pub translate_y: TransitionSpec,
}

impl SlintTransitionSet {
    /// Default slot transitions (200ms ease-out).
    pub fn default_slot() -> Self {
        Self {
            scale: TransitionSpec::new("scale", 200, EasingCurve::EaseOut),
            opacity: TransitionSpec::new("opacity", 150, EasingCurve::EaseOut),
            translate_x: TransitionSpec::new("translate_x", 200, EasingCurve::EaseOut),
            translate_y: TransitionSpec::new("translate_y", 200, EasingCurve::EaseOut),
        }
    }

    /// Reduced-motion transitions (instant snap).
    pub fn reduced_motion() -> Self {
        Self {
            scale: TransitionSpec::new("scale", 0, EasingCurve::Linear),
            opacity: TransitionSpec::new("opacity", 0, EasingCurve::Linear),
            translate_x: TransitionSpec::new("translate_x", 0, EasingCurve::Linear),
            translate_y: TransitionSpec::new("translate_y", 0, EasingCurve::Linear),
        }
    }

    /// Focus-change transitions (snappy scale + fade).
    pub fn focus_change() -> Self {
        Self {
            scale: TransitionSpec::new("scale", 120, EasingCurve::EaseOut),
            opacity: TransitionSpec::new("opacity", 80, EasingCurve::EaseOut),
            translate_x: TransitionSpec::new("translate_x", 120, EasingCurve::EaseInOut),
            translate_y: TransitionSpec::new("translate_y", 120, EasingCurve::EaseInOut),
        }
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_slot_transitions_are_200ms() {
        let t = SlintTransitionSet::default_slot();
        assert_eq!(t.scale.duration_ms, 200);
        assert_eq!(t.opacity.duration_ms, 150);
        assert_eq!(t.translate_y.duration_ms, 200);
    }

    #[test]
    fn test_reduced_motion_transitions_are_instant() {
        let t = SlintTransitionSet::reduced_motion();
        assert_eq!(t.scale.duration_ms, 0);
        assert_eq!(t.opacity.duration_ms, 0);
        assert_eq!(t.translate_x.easing, EasingCurve::Linear);
    }

    #[test]
    fn test_focus_change_transitions_shorter_than_default() {
        let default = SlintTransitionSet::default_slot();
        let focus = SlintTransitionSet::focus_change();
        assert!(focus.scale.duration_ms < default.scale.duration_ms);
    }

    #[test]
    fn test_transition_spec_with_delay() {
        let spec = TransitionSpec::new("opacity", 200, EasingCurve::EaseOut).with_delay(50);
        assert_eq!(spec.delay_ms, 50);
    }

    #[test]
    fn test_transition_spec_property_name_preserved() {
        let spec = TransitionSpec::new("scale", 100, EasingCurve::Linear);
        assert_eq!(spec.property, "scale");
    }
}
