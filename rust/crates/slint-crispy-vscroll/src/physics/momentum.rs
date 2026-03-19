/// Clamp velocity to ±max_velocity.
pub fn apply_velocity_cap(velocity: f32, max_velocity: f32) -> f32 {
    velocity.clamp(-max_velocity, max_velocity)
}

/// Frame-rate-independent friction decay.
/// Uses `friction` as the per-frame coefficient at 60fps.
/// Formula: `v * friction.powf(dt * 60.0)`
pub fn apply_friction_decay(velocity: f32, friction: f32, dt: f32) -> f32 {
    velocity * friction.powf(dt * 60.0)
}

/// True when velocity magnitude is below the stop threshold.
pub fn should_stop_momentum(velocity: f32, threshold: f32) -> bool {
    velocity.abs() < threshold
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_velocity_cap_clamps_positive() {
        assert_eq!(apply_velocity_cap(5000.0, 3000.0), 3000.0);
    }

    #[test]
    fn test_velocity_cap_clamps_negative() {
        assert_eq!(apply_velocity_cap(-5000.0, 3000.0), -3000.0);
    }

    #[test]
    fn test_velocity_cap_passthrough_within_range() {
        assert_eq!(apply_velocity_cap(1000.0, 3000.0), 1000.0);
        assert_eq!(apply_velocity_cap(-1000.0, 3000.0), -1000.0);
    }

    #[test]
    fn test_friction_decay_reduces_velocity() {
        let v = apply_friction_decay(1000.0, 0.97, 1.0 / 60.0);
        // One frame at 60fps: v * 0.97^1 = 970.0
        assert!((v - 970.0).abs() < 0.5, "v={v}");
    }

    #[test]
    fn test_friction_half_life_frame_rate_independent() {
        // At friction=0.97, 60fps, after 1 second: v * 0.97^60
        let expected = 1000.0_f32 * 0.97_f32.powf(60.0);
        // Simulate as 60 individual 1/60s ticks
        let mut v = 1000.0_f32;
        for _ in 0..60 {
            v = apply_friction_decay(v, 0.97, 1.0 / 60.0);
        }
        assert!((v - expected).abs() < 1.0, "v={v} expected={expected}");
    }

    #[test]
    fn test_friction_decay_same_result_regardless_of_step_size() {
        // One 1s step vs sixty 1/60s steps should give same result
        let v_one = apply_friction_decay(1000.0, 0.97, 1.0);
        let mut v_many = 1000.0_f32;
        for _ in 0..60 {
            v_many = apply_friction_decay(v_many, 0.97, 1.0 / 60.0);
        }
        assert!(
            (v_one - v_many).abs() < 1.0,
            "v_one={v_one} v_many={v_many}"
        );
    }

    #[test]
    fn test_should_stop_momentum_below_threshold() {
        assert!(should_stop_momentum(4.9, 5.0));
        assert!(should_stop_momentum(-4.9, 5.0));
    }

    #[test]
    fn test_should_stop_momentum_above_threshold() {
        assert!(!should_stop_momentum(5.1, 5.0));
        assert!(!should_stop_momentum(-5.1, 5.0));
    }

    #[test]
    fn test_should_stop_momentum_at_exact_threshold() {
        // exactly equal is not below threshold
        assert!(!should_stop_momentum(5.0, 5.0));
    }
}
