use std::ops::Range;

/// Y position of item at `index` in a uniform-height vertical list.
pub fn item_y_uniform(index: usize, item_height: f32, scroll_y: f32) -> f32 {
    index as f32 * item_height - scroll_y
}

/// Compute the range of item indices that are visible (plus buffer) for a uniform layout.
/// `buffer` is the number of extra items to include on each side beyond the visible range.
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

/// Total content height for a uniform vertical list.
pub fn content_size_uniform(item_count: usize, item_size: f32) -> f32 {
    item_count as f32 * item_size
}

/// Maximum scroll offset (content extends beyond viewport).
pub fn max_scroll_offset(content_size: f32, viewport_size: f32) -> f32 {
    (content_size - viewport_size).max(0.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_item_y_uniform_no_scroll() {
        assert_eq!(item_y_uniform(0, 100.0, 0.0), 0.0);
        assert_eq!(item_y_uniform(1, 100.0, 0.0), 100.0);
        assert_eq!(item_y_uniform(5, 100.0, 0.0), 500.0);
    }

    #[test]
    fn test_item_y_uniform_with_scroll() {
        assert_eq!(item_y_uniform(0, 100.0, 150.0), -150.0);
        assert_eq!(item_y_uniform(1, 100.0, 150.0), -50.0);
        assert_eq!(item_y_uniform(2, 100.0, 150.0), 50.0);
    }

    #[test]
    fn test_visible_range_uniform_basic() {
        // scroll=0, item_size=100, viewport=300, 10 items, buffer=0 => indices 0..3
        let r = visible_range_uniform(0.0, 100.0, 300.0, 10, 0);
        assert_eq!(r, 0..3);
    }

    #[test]
    fn test_visible_range_uniform_with_buffer() {
        let r = visible_range_uniform(0.0, 100.0, 300.0, 10, 1);
        // -1 clamped to 0, end 3+1=4
        assert_eq!(r, 0..4);
    }

    #[test]
    fn test_visible_range_uniform_clamped_to_item_count() {
        // Near the end: scroll near max
        let r = visible_range_uniform(700.0, 100.0, 300.0, 10, 1);
        // first=7, last=10, buffer: start=6, end=min(11,10)=10
        assert_eq!(r.start, 6);
        assert_eq!(r.end, 10);
    }

    #[test]
    fn test_visible_range_uniform_empty_on_zero_items() {
        assert_eq!(visible_range_uniform(0.0, 100.0, 600.0, 0, 1), 0..0);
    }

    #[test]
    fn test_visible_range_uniform_empty_on_zero_item_size() {
        assert_eq!(visible_range_uniform(0.0, 0.0, 600.0, 100, 1), 0..0);
    }

    #[test]
    fn test_content_size_uniform() {
        assert_eq!(content_size_uniform(10, 100.0), 1000.0);
        assert_eq!(content_size_uniform(0, 100.0), 0.0);
    }

    #[test]
    fn test_max_scroll_offset_positive() {
        assert_eq!(max_scroll_offset(1000.0, 600.0), 400.0);
    }

    #[test]
    fn test_max_scroll_offset_no_overflow() {
        // viewport larger than content => 0
        assert_eq!(max_scroll_offset(400.0, 600.0), 0.0);
    }

    #[test]
    fn test_max_scroll_offset_exact_fit() {
        assert_eq!(max_scroll_offset(600.0, 600.0), 0.0);
    }
}
