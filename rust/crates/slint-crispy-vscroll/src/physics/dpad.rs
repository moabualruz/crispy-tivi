/// Ease-out cubic: fast start, slow end.
/// `t` must be in [0.0, 1.0].
pub fn ease_out_cubic(t: f32) -> f32 {
    let t = t.clamp(0.0, 1.0);
    1.0 - (1.0 - t).powi(3)
}

/// Interpolate from `start` to `target` using ease-out-cubic at progress `t`.
pub fn dpad_interpolate(start: f32, target: f32, t: f32) -> f32 {
    let ease = ease_out_cubic(t);
    start + (target - start) * ease
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ease_out_cubic_at_zero() {
        assert_eq!(ease_out_cubic(0.0), 0.0);
    }

    #[test]
    fn test_ease_out_cubic_at_one() {
        assert_eq!(ease_out_cubic(1.0), 1.0);
    }

    #[test]
    fn test_ease_out_cubic_starts_fast() {
        // Derivative at t=0 is 3 (slope ~3x faster than linear)
        let t0 = ease_out_cubic(0.0);
        let t01 = ease_out_cubic(0.01);
        let slope = (t01 - t0) / 0.01;
        assert!(slope > 2.5, "slope={slope}");
    }

    #[test]
    fn test_ease_out_cubic_monotone_increasing() {
        let mut prev = ease_out_cubic(0.0);
        for i in 1..=100 {
            let t = i as f32 / 100.0;
            let cur = ease_out_cubic(t);
            assert!(cur >= prev, "t={t} cur={cur} prev={prev}");
            prev = cur;
        }
    }

    #[test]
    fn test_ease_out_cubic_midpoint_is_past_linear() {
        // ease-out is above linear for t in (0, 1)
        assert!(ease_out_cubic(0.5) > 0.5);
    }

    #[test]
    fn test_ease_out_cubic_clamps_out_of_range() {
        assert_eq!(ease_out_cubic(-1.0), 0.0);
        assert_eq!(ease_out_cubic(2.0), 1.0);
    }

    #[test]
    fn test_dpad_interpolate_at_zero_returns_start() {
        assert_eq!(dpad_interpolate(0.0, 200.0, 0.0), 0.0);
    }

    #[test]
    fn test_dpad_interpolate_at_one_returns_target() {
        assert_eq!(dpad_interpolate(0.0, 200.0, 1.0), 200.0);
    }

    #[test]
    fn test_dpad_interpolate_moves_toward_target() {
        let v = dpad_interpolate(0.0, 200.0, 0.5);
        assert!(v > 0.0 && v < 200.0, "v={v}");
    }

    #[test]
    fn test_dpad_interpolate_monotone() {
        let mut prev = dpad_interpolate(0.0, 100.0, 0.0);
        for i in 1..=100 {
            let t = i as f32 / 100.0;
            let cur = dpad_interpolate(0.0, 100.0, t);
            assert!(cur >= prev, "t={t} cur={cur} prev={prev}");
            prev = cur;
        }
    }
}
