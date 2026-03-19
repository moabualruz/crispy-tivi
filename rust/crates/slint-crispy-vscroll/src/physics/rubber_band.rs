/// Apple-formula rubber-band displacement.
/// `overscroll` — how far past the boundary (pixels, positive).
/// `dimension`  — viewport size in the scroll axis.
/// `coefficient` — resistance factor (higher = stiffer, less displacement).
///
/// Formula: `(1 - 1 / (overscroll * coefficient / dimension + 1)) * dimension`
pub fn rubber_band_displacement(overscroll: f32, dimension: f32, coefficient: f32) -> f32 {
    if dimension <= 0.0 || overscroll <= 0.0 {
        return 0.0;
    }
    (1.0 - 1.0 / (overscroll * coefficient / dimension + 1.0)) * dimension
}

/// Spring-back force: returns the position one step closer to `boundary`.
/// Uses an exponential decay toward the boundary position.
/// `damping` is in range (0, 1) — fraction of distance closed per call.
pub fn spring_back(current: f32, boundary: f32, damping: f32) -> f32 {
    current + (boundary - current) * damping.clamp(0.0, 1.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_rubber_band_zero_at_boundary() {
        assert_eq!(rubber_band_displacement(0.0, 600.0, 0.55), 0.0);
    }

    #[test]
    fn test_rubber_band_reduces_overscroll() {
        // Displacement should be less than raw overscroll
        let raw = 200.0;
        let displaced = rubber_band_displacement(raw, 600.0, 0.55);
        assert!(
            displaced < raw,
            "displaced={displaced} should be < raw={raw}"
        );
        assert!(displaced > 0.0, "displaced={displaced} should be > 0");
    }

    #[test]
    fn test_rubber_band_saturates_near_dimension() {
        // Very large overscroll should approach but never exceed dimension
        let displaced = rubber_band_displacement(100_000.0, 600.0, 0.55);
        assert!(displaced < 600.0, "displaced={displaced}");
        assert!(
            displaced > 500.0,
            "displaced={displaced} should be near dimension"
        );
    }

    #[test]
    fn test_rubber_band_negative_dimension_returns_zero() {
        assert_eq!(rubber_band_displacement(100.0, -600.0, 0.55), 0.0);
    }

    #[test]
    fn test_spring_back_converges_to_boundary() {
        let mut pos = 150.0_f32;
        let boundary = 0.0;
        for _ in 0..200 {
            pos = spring_back(pos, boundary, 0.15);
        }
        assert!(pos.abs() < 0.01, "pos={pos}");
    }

    #[test]
    fn test_spring_back_moves_toward_boundary() {
        let pos = spring_back(100.0, 0.0, 0.2);
        assert!(pos < 100.0 && pos > 0.0, "pos={pos}");
    }

    #[test]
    fn test_spring_back_at_boundary_stays_put() {
        assert_eq!(spring_back(0.0, 0.0, 0.3), 0.0);
    }
}
