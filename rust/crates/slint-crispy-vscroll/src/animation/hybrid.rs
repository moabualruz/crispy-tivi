//! Hybrid animation coordinator (Task 8).
//!
//! Decides whether to use Slint transitions or Rust tick-based animation
//! based on the animation target and current system state.

use crate::core::config::{AnimationConfig, AnimationTarget, EasingCurve};

use super::rust_tick::{AnimationDriver, RustTickDriver};
use super::slint_transitions::{SlintTransitionSet, TransitionSpec};

// ---------------------------------------------------------------------------
// AnimationMode
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AnimationMode {
    /// Slint handles transitions via `animate {}` declarations.
    SlintTransition,
    /// Rust tick loop drives per-frame property updates.
    RustTick,
    /// Reduced motion — instant snap, no animation.
    Instant,
}

// ---------------------------------------------------------------------------
// HybridCoordinator (Task 8)
// ---------------------------------------------------------------------------

pub struct HybridCoordinator {
    config: AnimationConfig,
    mode: AnimationMode,
    scroll_driver: RustTickDriver,
    focus_driver: RustTickDriver,
}

impl HybridCoordinator {
    pub fn new(config: AnimationConfig) -> Self {
        let mode = Self::resolve_mode(&config);
        let scroll_easing = config.dpad_easing;
        let focus_easing = EasingCurve::EaseOut;
        let scroll_driver = RustTickDriver::new(0.0, config.slot_fade_in_ms as f32, scroll_easing);
        let focus_driver = RustTickDriver::new(1.0, config.focus_scale_ms as f32, focus_easing);
        Self {
            config,
            mode,
            scroll_driver,
            focus_driver,
        }
    }

    pub fn mode(&self) -> AnimationMode {
        self.mode
    }

    /// Returns the recommended `AnimationTarget` for the current mode.
    pub fn preferred_target(&self) -> AnimationTarget {
        match self.mode {
            AnimationMode::RustTick | AnimationMode::Instant | AnimationMode::SlintTransition => {
                AnimationTarget::RustTick
            }
        }
    }

    /// Tick all Rust-driven animations. Returns true if any are still running.
    pub fn tick(&mut self, dt_ms: f32) -> bool {
        if matches!(self.mode, AnimationMode::Instant) {
            return false;
        }
        let a = self.scroll_driver.tick(dt_ms);
        let b = self.focus_driver.tick(dt_ms);
        a || b
    }

    /// Set scroll target position.
    pub fn set_scroll_target(&mut self, target: f32) {
        match self.mode {
            AnimationMode::Instant => self.scroll_driver.snap_to(target),
            _ => self.scroll_driver.set_target(target),
        }
    }

    /// Set focus scale target.
    pub fn set_focus_scale_target(&mut self, target: f32) {
        match self.mode {
            AnimationMode::Instant => self.focus_driver.snap_to(target),
            _ => self.focus_driver.set_target(target),
        }
    }

    pub fn scroll_position(&self) -> f32 {
        self.scroll_driver.current()
    }

    pub fn focus_scale(&self) -> f32 {
        self.focus_driver.current()
    }

    /// Returns the appropriate `SlintTransitionSet` for the current mode.
    pub fn transition_set(&self) -> SlintTransitionSet {
        if self.config.reduced_motion {
            SlintTransitionSet::reduced_motion()
        } else {
            SlintTransitionSet::default_slot()
        }
    }

    /// Returns a per-property transition spec for focus change animations.
    pub fn focus_transition(&self) -> TransitionSpec {
        if self.config.reduced_motion {
            TransitionSpec::new("scale", 0, EasingCurve::Linear)
        } else {
            TransitionSpec::new("scale", self.config.focus_scale_ms, EasingCurve::EaseOut)
        }
    }

    // -----------------------------------------------------------------------
    // Private
    // -----------------------------------------------------------------------

    fn resolve_mode(config: &AnimationConfig) -> AnimationMode {
        if config.reduced_motion {
            AnimationMode::Instant
        } else {
            AnimationMode::RustTick
        }
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::config::AnimationConfig;

    fn default_coordinator() -> HybridCoordinator {
        HybridCoordinator::new(AnimationConfig::default())
    }

    #[test]
    fn test_default_mode_is_rust_tick() {
        let c = default_coordinator();
        assert_eq!(c.mode(), AnimationMode::RustTick);
    }

    #[test]
    fn test_reduced_motion_mode_is_instant() {
        let config = AnimationConfig {
            reduced_motion: true,
            ..AnimationConfig::default()
        };
        let c = HybridCoordinator::new(config);
        assert_eq!(c.mode(), AnimationMode::Instant);
    }

    #[test]
    fn test_set_scroll_target_advances_on_tick() {
        let mut c = default_coordinator();
        c.set_scroll_target(500.0);
        let before = c.scroll_position();
        c.tick(100.0);
        let after = c.scroll_position();
        assert!(after > before || after == 500.0);
    }

    #[test]
    fn test_reduced_motion_snaps_immediately() {
        let config = AnimationConfig {
            reduced_motion: true,
            ..AnimationConfig::default()
        };
        let mut c = HybridCoordinator::new(config);
        c.set_scroll_target(300.0);
        assert!((c.scroll_position() - 300.0).abs() < 0.001);
    }

    #[test]
    fn test_tick_returns_false_when_instant() {
        let config = AnimationConfig {
            reduced_motion: true,
            ..AnimationConfig::default()
        };
        let mut c = HybridCoordinator::new(config);
        assert!(!c.tick(16.0));
    }

    #[test]
    fn test_reduced_motion_transition_is_instant() {
        let config = AnimationConfig {
            reduced_motion: true,
            ..AnimationConfig::default()
        };
        let c = HybridCoordinator::new(config);
        let t = c.focus_transition();
        assert_eq!(t.duration_ms, 0);
    }

    #[test]
    fn test_set_focus_scale_target_instant_snaps_immediately() {
        // Covers AnimationMode::Instant branch in set_focus_scale_target (line ~84)
        let config = AnimationConfig {
            reduced_motion: true,
            ..AnimationConfig::default()
        };
        let mut c = HybridCoordinator::new(config);
        c.set_focus_scale_target(1.5);
        assert!((c.focus_scale() - 1.5).abs() < 0.001);
    }

    #[test]
    fn test_set_focus_scale_target_rust_tick_animates() {
        // Covers the `_` (RustTick) branch in set_focus_scale_target
        let mut c = default_coordinator();
        let before = c.focus_scale();
        c.set_focus_scale_target(2.0);
        c.tick(100.0);
        let after = c.focus_scale();
        assert!(after > before || after == 2.0);
    }

    #[test]
    fn test_preferred_target_rust_tick_returns_rust_tick() {
        // Covers AnimationMode::RustTick arm in preferred_target (line ~59)
        let c = default_coordinator();
        assert_eq!(
            c.preferred_target(),
            crate::core::config::AnimationTarget::RustTick
        );
    }

    #[test]
    fn test_preferred_target_instant_returns_rust_tick() {
        // Covers AnimationMode::Instant arm in preferred_target (line ~59)
        let config = AnimationConfig {
            reduced_motion: true,
            ..AnimationConfig::default()
        };
        let c = HybridCoordinator::new(config);
        assert_eq!(
            c.preferred_target(),
            crate::core::config::AnimationTarget::RustTick
        );
    }

    #[test]
    fn test_transition_set_default_not_reduced() {
        // Covers transition_set non-reduced path (line ~102)
        let c = default_coordinator();
        let _ts = c.transition_set();
        // Just verify it doesn't panic
    }

    #[test]
    fn test_focus_transition_duration_matches_config() {
        let config = AnimationConfig {
            focus_scale_ms: 250,
            ..AnimationConfig::default()
        };
        let c = HybridCoordinator::new(config);
        let t = c.focus_transition();
        assert_eq!(t.duration_ms, 250);
    }

    #[test]
    fn test_transition_set_reduced_motion_returns_reduced() {
        // Covers hybrid.rs: SlintTransitionSet::reduced_motion() path
        let config = AnimationConfig {
            reduced_motion: true,
            ..AnimationConfig::default()
        };
        let c = HybridCoordinator::new(config);
        let ts = c.transition_set();
        // reduced_motion → all durations 0
        assert_eq!(ts.scale.duration_ms, 0);
        assert_eq!(ts.opacity.duration_ms, 0);
        assert_eq!(ts.translate_x.duration_ms, 0);
        assert_eq!(ts.translate_y.duration_ms, 0);
    }
}
