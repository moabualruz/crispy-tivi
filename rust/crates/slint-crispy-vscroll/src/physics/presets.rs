use crate::core::config::PhysicsConfig;
use crate::core::types::SnapMode;

/// Apple TV-style: smooth, inertial, start-aligned snap, rubber-band enabled.
pub fn apple_tv() -> PhysicsConfig {
    PhysicsConfig {
        friction: 0.97,
        velocity_cap: 3000.0,
        velocity_threshold: 5.0,
        snap_mode: SnapMode::StartAligned,
        snap_tension: 300.0,
        snap_damping: 28.0,
        snap_duration_ms: 400,
        rubber_band_stiffness: 0.35,
        rubber_band_max_distance: 120.0,
        rubber_band_return_tension: 400.0,
        rubber_band_return_damping: 30.0,
        spring_mass: 1.0,
        spring_stiffness: 300.0,
        spring_damping: 28.0,
        dpad_scroll_duration_ms: 200,
        dpad_repeat_delay_ms: 400,
        dpad_repeat_rate_ms: 100,
        dpad_acceleration: true,
        dpad_acceleration_curve: 0.85,
        reduced_motion: false,
    }
}

/// Netflix-style: faster decay, snappier response.
pub fn netflix() -> PhysicsConfig {
    PhysicsConfig {
        friction: 0.92,
        velocity_cap: 4000.0,
        velocity_threshold: 8.0,
        snap_mode: SnapMode::StartAligned,
        snap_tension: 500.0,
        snap_damping: 35.0,
        snap_duration_ms: 250,
        rubber_band_stiffness: 0.25,
        rubber_band_max_distance: 80.0,
        rubber_band_return_tension: 600.0,
        rubber_band_return_damping: 40.0,
        spring_mass: 1.0,
        spring_stiffness: 500.0,
        spring_damping: 35.0,
        dpad_scroll_duration_ms: 150,
        dpad_repeat_delay_ms: 350,
        dpad_repeat_rate_ms: 80,
        dpad_acceleration: true,
        dpad_acceleration_curve: 0.75,
        reduced_motion: false,
    }
}

/// Google TV-style: D-pad focused, precise, higher stop threshold.
pub fn google_tv() -> PhysicsConfig {
    PhysicsConfig {
        friction: 0.95,
        velocity_cap: 2500.0,
        velocity_threshold: 10.0,
        snap_mode: SnapMode::StartAligned,
        snap_tension: 400.0,
        snap_damping: 32.0,
        snap_duration_ms: 300,
        rubber_band_stiffness: 0.20,
        rubber_band_max_distance: 60.0,
        rubber_band_return_tension: 500.0,
        rubber_band_return_damping: 35.0,
        spring_mass: 1.0,
        spring_stiffness: 400.0,
        spring_damping: 32.0,
        dpad_scroll_duration_ms: 180,
        dpad_repeat_delay_ms: 300,
        dpad_repeat_rate_ms: 75,
        dpad_acceleration: true,
        dpad_acceleration_curve: 0.80,
        reduced_motion: false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn assert_valid_physics_config(cfg: &PhysicsConfig, name: &str) {
        assert!(
            cfg.friction > 0.0 && cfg.friction < 1.0,
            "{name}: friction={} must be in (0,1)",
            cfg.friction
        );
        assert!(
            cfg.velocity_cap > 0.0,
            "{name}: velocity_cap={} must be positive",
            cfg.velocity_cap
        );
        assert!(
            cfg.velocity_threshold > 0.0,
            "{name}: velocity_threshold={} must be positive",
            cfg.velocity_threshold
        );
        assert!(
            cfg.snap_tension > 0.0,
            "{name}: snap_tension must be positive"
        );
        assert!(
            cfg.snap_damping > 0.0,
            "{name}: snap_damping must be positive"
        );
        assert!(
            cfg.snap_duration_ms > 0,
            "{name}: snap_duration_ms must be > 0"
        );
        assert!(
            cfg.rubber_band_stiffness > 0.0 && cfg.rubber_band_stiffness < 1.0,
            "{name}: rubber_band_stiffness={} must be in (0,1)",
            cfg.rubber_band_stiffness
        );
        assert!(
            cfg.rubber_band_max_distance > 0.0,
            "{name}: rubber_band_max_distance must be positive"
        );
        assert!(
            cfg.spring_mass > 0.0,
            "{name}: spring_mass must be positive"
        );
        assert!(
            cfg.spring_stiffness > 0.0,
            "{name}: spring_stiffness must be positive"
        );
        assert!(
            cfg.spring_damping > 0.0,
            "{name}: spring_damping must be positive"
        );
        assert!(
            cfg.dpad_scroll_duration_ms > 0,
            "{name}: dpad_scroll_duration_ms must be > 0"
        );
        assert!(
            cfg.dpad_repeat_rate_ms > 0,
            "{name}: dpad_repeat_rate_ms must be > 0"
        );
        assert!(
            cfg.dpad_acceleration_curve > 0.0 && cfg.dpad_acceleration_curve < 1.0,
            "{name}: dpad_acceleration_curve={} must be in (0,1)",
            cfg.dpad_acceleration_curve
        );
    }

    #[test]
    fn test_apple_tv_preset_valid_ranges() {
        assert_valid_physics_config(&apple_tv(), "apple_tv");
    }

    #[test]
    fn test_netflix_preset_valid_ranges() {
        assert_valid_physics_config(&netflix(), "netflix");
    }

    #[test]
    fn test_google_tv_preset_valid_ranges() {
        assert_valid_physics_config(&google_tv(), "google_tv");
    }

    #[test]
    fn test_presets_have_distinct_characteristics() {
        let a = apple_tv();
        let n = netflix();
        let g = google_tv();
        // Netflix has lower friction (faster decay) than Apple TV
        assert!(
            n.friction < a.friction,
            "netflix friction should be < apple_tv"
        );
        // Google TV has higher velocity_threshold than Apple TV
        assert!(
            g.velocity_threshold > a.velocity_threshold,
            "google_tv threshold should be > apple_tv"
        );
        // Netflix has shorter snap duration
        assert!(
            n.snap_duration_ms < a.snap_duration_ms,
            "netflix snap_duration_ms should be < apple_tv"
        );
    }

    #[test]
    fn test_presets_have_start_aligned_snap() {
        assert_eq!(apple_tv().snap_mode, SnapMode::StartAligned);
        assert_eq!(netflix().snap_mode, SnapMode::StartAligned);
        assert_eq!(google_tv().snap_mode, SnapMode::StartAligned);
    }
}
