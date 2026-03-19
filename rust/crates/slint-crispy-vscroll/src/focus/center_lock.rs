//! center_lock — viewport-follow strategy: keep focus centered (Task 12).

/// Compute scroll position to center the focused item in the viewport.
///
/// Result is clamped to `[0, max_scroll]` where
/// `max_scroll = item_count * item_height - viewport_height`.
pub fn center_lock(
    focus_index: usize,
    item_height: f32,
    viewport_height: f32,
    item_count: usize,
) -> f32 {
    let item_center = focus_index as f32 * item_height + item_height * 0.5;
    let ideal = item_center - viewport_height * 0.5;
    let total_height = item_count as f32 * item_height;
    let max_scroll = (total_height - viewport_height).max(0.0);
    ideal.clamp(0.0, max_scroll)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_centers_item_in_viewport() {
        // item_height=100, viewport=400, item at index 5 → center=550, ideal=550-200=350
        let pos = center_lock(5, 100.0, 400.0, 20);
        assert!((pos - 350.0).abs() < 0.001);
    }

    #[test]
    fn test_clamps_at_zero() {
        // item at index 0 — ideal would be negative
        let pos = center_lock(0, 100.0, 400.0, 20);
        assert!((pos - 0.0).abs() < 0.001);
    }

    #[test]
    fn test_clamps_at_max() {
        // item at last index — ideal may exceed max_scroll
        // 20 items * 100h = 2000, max_scroll = 2000-400=1600
        let pos = center_lock(19, 100.0, 400.0, 20);
        assert!((pos - 1600.0).abs() < 0.001);
    }
}
