/// Find the nearest snap target in `targets` to `position`.
/// Returns 0.0 if targets is empty.
pub fn snap_nearest(targets: &[f32], position: f32) -> f32 {
    targets
        .iter()
        .copied()
        .min_by(|a, b| {
            let da = (a - position).abs();
            let db = (b - position).abs();
            da.partial_cmp(&db).unwrap_or(std::cmp::Ordering::Equal)
        })
        .unwrap_or(0.0)
}

/// Snap to nearest item-start boundary (start-aligned).
/// Formula: round(scroll / item_size) * item_size
pub fn snap_start_aligned(scroll_pos: f32, item_size: f32) -> f32 {
    if item_size <= 0.0 {
        return 0.0;
    }
    (scroll_pos / item_size).round() * item_size
}

/// Snap so that an item is centered in the viewport.
/// Formula: round((scroll + viewport/2) / item_size) * item_size - viewport/2
pub fn snap_center_aligned(scroll_pos: f32, item_size: f32, viewport_size: f32) -> f32 {
    if item_size <= 0.0 {
        return 0.0;
    }
    let center = scroll_pos + viewport_size / 2.0;
    (center / item_size).round() * item_size - viewport_size / 2.0
}

/// Exponential ease toward target. Returns a position closer to `target` than `current`.
/// `stiffness` is in range (0, 1) exclusive — fraction of remaining distance closed per call.
pub fn spring_approach(current: f32, target: f32, stiffness: f32) -> f32 {
    current + (target - current) * stiffness.clamp(0.0, 1.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_snap_nearest_finds_closest() {
        let targets = [0.0, 100.0, 200.0, 300.0];
        assert_eq!(snap_nearest(&targets, 60.0), 100.0);
        assert_eq!(snap_nearest(&targets, 40.0), 0.0);
        assert_eq!(snap_nearest(&targets, 250.0), 200.0);
    }

    #[test]
    fn test_snap_nearest_empty_returns_zero() {
        assert_eq!(snap_nearest(&[], 100.0), 0.0);
    }

    #[test]
    fn test_snap_nearest_midpoint_tie_breaking() {
        // At exactly the midpoint (50.0 between 0 and 100), min_by picks first equivalent
        let targets = [0.0, 100.0];
        let result = snap_nearest(&targets, 50.0);
        // Either target is acceptable at exact midpoint
        assert!(result == 0.0 || result == 100.0, "result={result}");
    }

    #[test]
    fn test_snap_start_aligned_rounds_to_nearest_item() {
        assert_eq!(snap_start_aligned(60.0, 100.0), 100.0);
        assert_eq!(snap_start_aligned(40.0, 100.0), 0.0);
        assert_eq!(snap_start_aligned(150.0, 100.0), 200.0);
        assert_eq!(snap_start_aligned(0.0, 100.0), 0.0);
    }

    #[test]
    fn test_snap_start_aligned_zero_item_size_returns_zero() {
        assert_eq!(snap_start_aligned(500.0, 0.0), 0.0);
    }

    #[test]
    fn test_snap_center_aligned_zero_item_size_returns_zero() {
        // Covers line 28: early return when item_size <= 0
        assert_eq!(snap_center_aligned(500.0, 0.0, 400.0), 0.0);
        assert_eq!(snap_center_aligned(100.0, -1.0, 200.0), 0.0);
    }

    #[test]
    fn test_snap_center_aligned_centers_item_in_viewport() {
        // viewport=400, item_size=100 => center snap at index 2: target=150 (200 - 400/2)
        // scroll=140 => center=340 => nearest item center at 300 => snap=300-200=100
        let result = snap_center_aligned(140.0, 100.0, 400.0);
        assert_eq!(result, 100.0);
    }

    #[test]
    fn test_spring_approach_converges_to_target() {
        let mut pos = 0.0_f32;
        let target = 100.0;
        for _ in 0..100 {
            pos = spring_approach(pos, target, 0.1);
        }
        assert!((pos - target).abs() < 1.0, "pos={pos}");
    }

    #[test]
    fn test_spring_approach_moves_toward_target() {
        let pos = spring_approach(0.0, 100.0, 0.2);
        assert!(pos > 0.0 && pos < 100.0, "pos={pos}");
    }

    #[test]
    fn test_spring_approach_at_target_stays_put() {
        assert_eq!(spring_approach(100.0, 100.0, 0.5), 100.0);
    }
}
