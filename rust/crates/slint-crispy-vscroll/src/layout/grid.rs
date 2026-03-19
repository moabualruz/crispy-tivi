use std::ops::Range;

/// Compute the (x, y) viewport position of item at `index` in a grid layout.
/// Items fill row by row (left to right).
pub fn grid_position(
    index: usize,
    columns: usize,
    item_width: f32,
    item_height: f32,
    scroll_y: f32,
) -> (f32, f32) {
    let col = index % columns.max(1);
    let row = index / columns.max(1);
    let x = col as f32 * item_width;
    let y = row as f32 * item_height - scroll_y;
    (x, y)
}

/// Compute the visible item index range (plus buffer) for a grid layout.
pub fn grid_visible_range(
    scroll_pos: f32,
    item_height: f32,
    viewport_size: f32,
    columns: usize,
    item_count: usize,
    buffer: usize,
) -> Range<usize> {
    if item_height <= 0.0 || item_count == 0 || columns == 0 {
        return 0..0;
    }
    let first_visible_row = (scroll_pos / item_height).floor() as isize;
    let last_visible_row = ((scroll_pos + viewport_size) / item_height).ceil() as isize;

    let start_row = (first_visible_row - buffer as isize).max(0) as usize;
    let end_row = (last_visible_row + buffer as isize).max(0) as usize;

    let start = start_row * columns;
    let end = (end_row * columns).min(item_count);
    start..end
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_grid_position_index_to_row_col() {
        // 3 columns: index 0=(0,0), 1=(1,0), 2=(2,0), 3=(0,1)
        assert_eq!(grid_position(0, 3, 100.0, 80.0, 0.0), (0.0, 0.0));
        assert_eq!(grid_position(1, 3, 100.0, 80.0, 0.0), (100.0, 0.0));
        assert_eq!(grid_position(2, 3, 100.0, 80.0, 0.0), (200.0, 0.0));
        assert_eq!(grid_position(3, 3, 100.0, 80.0, 0.0), (0.0, 80.0));
        assert_eq!(grid_position(4, 3, 100.0, 80.0, 0.0), (100.0, 80.0));
    }

    #[test]
    fn test_grid_position_with_scroll() {
        let (x, y) = grid_position(0, 3, 100.0, 80.0, 160.0);
        assert_eq!(x, 0.0);
        assert_eq!(y, -160.0);
    }

    #[test]
    fn test_grid_visible_range_basic() {
        // 3 cols, item_height=80, viewport=240, scroll=0, no buffer => rows 0..3 => indices 0..9
        let r = grid_visible_range(0.0, 80.0, 240.0, 3, 100, 0);
        assert_eq!(r.start, 0);
        assert_eq!(r.end, 9);
    }

    #[test]
    fn test_grid_visible_range_with_buffer() {
        let r = grid_visible_range(0.0, 80.0, 240.0, 3, 100, 1);
        // start_row clamped to 0, end_row=3+1=4 => end=12
        assert_eq!(r.start, 0);
        assert_eq!(r.end, 12);
    }

    #[test]
    fn test_grid_visible_range_clamps_to_item_count() {
        // 3 cols, 10 items, scroll at bottom
        let r = grid_visible_range(200.0, 80.0, 240.0, 3, 10, 1);
        assert_eq!(r.end, 10);
    }

    #[test]
    fn test_grid_visible_range_partial_last_row() {
        // 10 items, 3 columns => 4 rows (last row has 1 item)
        // scroll=0, viewport=320 (4 rows visible), buffer=0 => all 10 items
        let r = grid_visible_range(0.0, 80.0, 320.0, 3, 10, 0);
        assert_eq!(r.end, 10);
    }

    #[test]
    fn test_grid_visible_range_empty_on_zero_items() {
        assert_eq!(grid_visible_range(0.0, 80.0, 600.0, 3, 0, 0), 0..0);
    }

    #[test]
    fn test_grid_visible_range_empty_on_zero_columns() {
        assert_eq!(grid_visible_range(0.0, 80.0, 600.0, 0, 10, 0), 0..0);
    }
}
