//! Rust-side tick-based animation driver (Task 6).
//!
//! Interpolates a scalar value toward a target at a configurable rate.
//! Designed to be called once per frame by a Slint Timer callback.

use crate::core::config::EasingCurve;

// ---------------------------------------------------------------------------
// AnimationDriver trait (Task 6)
// ---------------------------------------------------------------------------

/// Drives per-frame property interpolation entirely in Rust.
///
/// Implementors call `tick(dt_ms)` each frame and read back `current()`.
pub trait AnimationDriver: Send + Sync {
    /// Advance the animation by `dt_ms` milliseconds.
    /// Returns true if the animation is still running (not yet settled).
    fn tick(&mut self, dt_ms: f32) -> bool;

    /// Current interpolated value.
    fn current(&self) -> f32;

    /// Returns true if the animation has fully settled (no longer changing).
    fn is_settled(&self) -> bool;

    /// Set a new target value.
    fn set_target(&mut self, target: f32);

    /// Snap to value immediately (no animation).
    fn snap_to(&mut self, value: f32);
}

// ---------------------------------------------------------------------------
// Easing functions
// ---------------------------------------------------------------------------

fn apply_easing(t: f32, curve: EasingCurve) -> f32 {
    let t = t.clamp(0.0, 1.0);
    match curve {
        EasingCurve::Linear => t,
        EasingCurve::EaseIn => t * t,
        EasingCurve::EaseOut => t * (2.0 - t),
        EasingCurve::EaseInOut => {
            if t < 0.5 {
                2.0 * t * t
            } else {
                -1.0 + (4.0 - 2.0 * t) * t
            }
        }
        EasingCurve::CubicBezier => {
            // Approximate cubic ease-in-out
            t * t * (3.0 - 2.0 * t)
        }
    }
}

// ---------------------------------------------------------------------------
// RustTickDriver
// ---------------------------------------------------------------------------

pub struct RustTickDriver {
    current: f32,
    start: f32,
    target: f32,
    duration_ms: f32,
    elapsed_ms: f32,
    easing: EasingCurve,
    settle_threshold: f32,
}

impl RustTickDriver {
    pub fn new(initial: f32, duration_ms: f32, easing: EasingCurve) -> Self {
        Self {
            current: initial,
            start: initial,
            target: initial,
            duration_ms,
            elapsed_ms: 0.0,
            easing,
            settle_threshold: 0.001,
        }
    }

    pub fn with_settle_threshold(mut self, threshold: f32) -> Self {
        self.settle_threshold = threshold;
        self
    }

    /// Advance elapsed time and interpolate current value toward target.
    fn advance(&mut self, dt_ms: f32) {
        self.elapsed_ms = (self.elapsed_ms + dt_ms).min(self.duration_ms);
        let t = if self.duration_ms > 0.0 {
            self.elapsed_ms / self.duration_ms
        } else {
            1.0
        };
        let eased = apply_easing(t, self.easing);
        self.current = self.start + (self.target - self.start) * eased;
    }
}

impl AnimationDriver for RustTickDriver {
    fn tick(&mut self, dt_ms: f32) -> bool {
        if self.is_settled() {
            return false;
        }
        self.advance(dt_ms);
        !self.is_settled()
    }

    fn current(&self) -> f32 {
        self.current
    }

    fn is_settled(&self) -> bool {
        (self.current - self.target).abs() < self.settle_threshold
            && ((self.start - self.target).abs() < self.settle_threshold
                || self.elapsed_ms >= self.duration_ms)
    }

    fn set_target(&mut self, target: f32) {
        if (target - self.target).abs() < f32::EPSILON {
            return;
        }
        self.start = self.current;
        self.target = target;
        self.elapsed_ms = 0.0;
    }

    fn snap_to(&mut self, value: f32) {
        self.current = value;
        self.start = value;
        self.target = value;
        self.elapsed_ms = self.duration_ms;
    }
}

// ---------------------------------------------------------------------------
// FrameBudgetGuard
// ---------------------------------------------------------------------------

/// Tracks frame budget usage. Returns true if within budget.
pub struct FrameBudgetGuard {
    budget_ms: f32,
    used_ms: f32,
}

impl FrameBudgetGuard {
    pub fn new(budget_ms: f32) -> Self {
        Self {
            budget_ms,
            used_ms: 0.0,
        }
    }

    pub fn record(&mut self, work_ms: f32) {
        self.used_ms += work_ms;
    }

    pub fn within_budget(&self) -> bool {
        self.used_ms <= self.budget_ms
    }

    pub fn reset(&mut self) {
        self.used_ms = 0.0;
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_driver_starts_settled_at_initial() {
        let driver = RustTickDriver::new(0.0, 200.0, EasingCurve::Linear);
        assert!(driver.is_settled());
        assert!((driver.current() - 0.0).abs() < 0.001);
    }

    #[test]
    fn test_set_target_starts_animation() {
        let mut driver = RustTickDriver::new(0.0, 200.0, EasingCurve::Linear);
        driver.set_target(100.0);
        assert!(!driver.is_settled());
    }

    #[test]
    fn test_tick_advances_toward_target() {
        let mut driver = RustTickDriver::new(0.0, 200.0, EasingCurve::Linear);
        driver.set_target(100.0);
        driver.tick(100.0); // halfway
        let v = driver.current();
        assert!(v > 0.0 && v < 100.0);
    }

    #[test]
    fn test_tick_full_duration_reaches_target() {
        let mut driver = RustTickDriver::new(0.0, 200.0, EasingCurve::Linear);
        driver.set_target(100.0);
        driver.tick(200.0);
        assert!(driver.is_settled());
        assert!((driver.current() - 100.0).abs() < 0.001);
    }

    #[test]
    fn test_snap_to_sets_immediately() {
        let mut driver = RustTickDriver::new(0.0, 200.0, EasingCurve::EaseOut);
        driver.snap_to(500.0);
        assert!(driver.is_settled());
        assert!((driver.current() - 500.0).abs() < 0.001);
    }

    #[test]
    fn test_tick_returns_false_when_settled() {
        let mut driver = RustTickDriver::new(0.0, 200.0, EasingCurve::Linear);
        driver.set_target(100.0);
        driver.tick(200.0); // settle
        let still_running = driver.tick(16.0);
        assert!(!still_running);
    }

    #[test]
    fn test_ease_in_out_midpoint() {
        let t = apply_easing(0.5, EasingCurve::EaseInOut);
        assert!((t - 0.5).abs() < 0.001);
    }

    #[test]
    fn test_ease_out_reaches_one() {
        let t = apply_easing(1.0, EasingCurve::EaseOut);
        assert!((t - 1.0).abs() < 0.001);
    }

    #[test]
    fn test_linear_easing_proportional() {
        let t = apply_easing(0.3, EasingCurve::Linear);
        assert!((t - 0.3).abs() < 0.001);
    }

    #[test]
    fn test_frame_budget_guard() {
        let mut guard = FrameBudgetGuard::new(8.0);
        guard.record(3.0);
        assert!(guard.within_budget());
        guard.record(6.0);
        assert!(!guard.within_budget());
        guard.reset();
        assert!(guard.within_budget());
    }

    #[test]
    fn test_ease_in_increases_quadratically() {
        // Covers EasingCurve::EaseIn branch (line ~41 in apply_easing)
        let t = apply_easing(0.5, EasingCurve::EaseIn);
        // EaseIn = t*t => 0.25
        assert!((t - 0.25).abs() < 0.001);
    }

    #[test]
    fn test_cubic_bezier_smooth_step() {
        // Covers EasingCurve::CubicBezier branch
        let t = apply_easing(0.5, EasingCurve::CubicBezier);
        // smoothstep: 0.5*0.5*(3 - 2*0.5) = 0.25 * 2.0 = 0.5
        assert!((t - 0.5).abs() < 0.001);
        // at 0.0 should be 0.0
        assert!((apply_easing(0.0, EasingCurve::CubicBezier) - 0.0).abs() < 0.001);
        // at 1.0 should be 1.0
        assert!((apply_easing(1.0, EasingCurve::CubicBezier) - 1.0).abs() < 0.001);
    }

    #[test]
    fn test_with_settle_threshold_builder() {
        // Covers with_settle_threshold (lines 84-86)
        let driver =
            RustTickDriver::new(0.0, 200.0, EasingCurve::Linear).with_settle_threshold(0.5);
        // With larger threshold, driver should still start settled (current==target==0)
        assert!(driver.is_settled());
    }

    #[test]
    fn test_with_settle_threshold_affects_settle_detection() {
        // Large threshold: once elapsed >= duration AND |current-target| < threshold → settled
        let mut driver =
            RustTickDriver::new(0.0, 200.0, EasingCurve::Linear).with_settle_threshold(10.0);
        driver.set_target(100.0);
        // Tick past full duration → elapsed >= duration AND current == target → settled
        driver.tick(200.0);
        assert!(driver.is_settled());
    }

    #[test]
    fn test_ease_in_full_duration_reaches_target() {
        // Covers EaseIn path through tick
        let mut driver = RustTickDriver::new(0.0, 200.0, EasingCurve::EaseIn);
        driver.set_target(100.0);
        driver.tick(200.0);
        assert!(driver.is_settled());
        assert!((driver.current() - 100.0).abs() < 0.001);
    }

    #[test]
    fn test_cubic_bezier_driver_settles() {
        // Covers CubicBezier path through tick
        let mut driver = RustTickDriver::new(0.0, 100.0, EasingCurve::CubicBezier);
        driver.set_target(50.0);
        driver.tick(100.0);
        assert!(driver.is_settled());
        assert!((driver.current() - 50.0).abs() < 0.001);
    }

    #[test]
    fn test_convergence_over_many_frames() {
        let mut driver = RustTickDriver::new(0.0, 300.0, EasingCurve::EaseInOut);
        driver.set_target(1000.0);
        for _ in 0..20 {
            driver.tick(16.0); // ~60fps
        }
        // After 320ms > 300ms duration, should be settled
        assert!(driver.is_settled());
    }

    #[test]
    fn test_zero_duration_driver_snaps_on_first_tick() {
        // Covers lines 96-103: tick() body when duration_ms == 0 → t = 1.0 branch (line 100)
        let mut driver = RustTickDriver::new(0.0, 0.0, EasingCurve::Linear);
        driver.set_target(200.0);
        // With duration=0, is_settled() is false until we tick (elapsed < duration is 0==0, but
        // current != target). Tick should jump to target immediately.
        let running = driver.tick(0.0);
        // After tick with zero duration, current should equal target
        assert!((driver.current() - 200.0).abs() < 0.001);
        // settled now
        assert!(!running);
    }

    #[test]
    fn test_ease_in_out_second_half() {
        // Covers EaseInOut else branch (t >= 0.5): -1 + (4 - 2t)*t
        let t = apply_easing(0.75, EasingCurve::EaseInOut);
        // -1 + (4 - 1.5)*0.75 = -1 + 2.5*0.75 = -1 + 1.875 = 0.875
        assert!((t - 0.875).abs() < 0.001);
    }
}
