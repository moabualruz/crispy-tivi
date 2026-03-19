use std::ops::Range;

/// X position of item at `index` in a uniform-width horizontal list.
pub fn item_x_uniform(index: usize, item_width: f32, scroll_x: f32) -> f32 {
    index as f32 * item_width - scroll_x
}

/// Compute the range of item indices that are visible (plus buffer) for a uniform horizontal layout.
pub fn visible_range_uniform(
    scroll_pos: f32,
    item_size: f32,
    viewport_size: f32,
    item_count: usize,
    buffer: usize,
) -> Range<usize> {
    if item_size <= 0.0 || item_count == 0 {
        return 0..0;
    }
    let first_visible = (scroll_pos / item_size).floor() as isize;
    let last_visible = ((scroll_pos + viewport_size) / item_size).ceil() as isize;

    let start = (first_visible - buffer as isize).max(0) as usize;
    let end = ((last_visible + buffer as isize) as usize).min(item_count);
    start..end
}

/// Total content width for a uniform horizontal list.
pub fn content_size_uniform(item_count: usize, item_size: f32) -> f32 {
    item_count as f32 * item_size
}

/// Maximum scroll offset for a horizontal list.
pub fn max_scroll_offset(content_size: f32, viewport_size: f32) -> f32 {
    (content_size - viewport_size).max(0.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_item_x_uniform_no_scroll() {
        assert_eq!(item_x_uniform(0, 200.0, 0.0), 0.0);
        assert_eq!(item_x_uniform(1, 200.0, 0.0), 200.0);
        assert_eq!(item_x_uniform(3, 200.0, 0.0), 600.0);
    }

    #[test]
    fn test_item_x_uniform_with_scroll() {
        assert_eq!(item_x_uniform(0, 200.0, 300.0), -300.0);
        assert_eq!(item_x_uniform(2, 200.0, 300.0), 100.0);
    }

    #[test]
    fn test_visible_range_matches_vertical_axis_symmetry() {
        // Same formula as vertical — axis-swapped
        let r = visible_range_uniform(0.0, 200.0, 800.0, 20, 1);
        assert_eq!(r.start, 0);
        // last_visible = ceil(800/200)=4, end=4+1=5
        assert_eq!(r.end, 5);
    }

    #[test]
    fn test_visible_range_uniform_clamped_end() {
        let r = visible_range_uniform(1600.0, 200.0, 800.0, 10, 1);
        assert_eq!(r.end, 10);
    }

    #[test]
    fn test_visible_range_empty_on_zero_items() {
        assert_eq!(visible_range_uniform(0.0, 200.0, 800.0, 0, 1), 0..0);
    }

    #[test]
    fn test_content_size_uniform() {
        assert_eq!(content_size_uniform(5, 200.0), 1000.0);
    }

    #[test]
    fn test_max_scroll_offset_positive() {
        assert_eq!(max_scroll_offset(2000.0, 800.0), 1200.0);
    }

    #[test]
    fn test_max_scroll_offset_no_overflow() {
        assert_eq!(max_scroll_offset(500.0, 800.0), 0.0);
    }
}
