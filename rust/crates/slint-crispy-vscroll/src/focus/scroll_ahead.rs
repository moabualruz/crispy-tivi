//! scroll_ahead — viewport-follow strategy: keep focus visible ahead of scroll (Task 11).

/// Compute new scroll position to keep focused item visible.
///
/// Returns the same `scroll_pos` if the item is already in view.
/// Scrolls minimally to bring the item into view otherwise.
pub fn scroll_ahead(
    focus_index: usize,
    item_height: f32,
    scroll_pos: f32,
    viewport_height: f32,
) -> f32 {
    let item_top = focus_index as f32 * item_height;
    let item_bottom = item_top + item_height;
    let view_bottom = scroll_pos + viewport_height;

    if item_top < scroll_pos {
        // Item above viewport — scroll up.
        item_top
    } else if item_bottom > view_bottom {
        // Item below viewport — scroll down.
        item_bottom - viewport_height
    } else {
        scroll_pos
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_no_scroll_when_inside_viewport() {
        let pos = scroll_ahead(2, 100.0, 100.0, 400.0);
        // item_top=200, item_bottom=300, viewport 100..500 — inside
        assert!((pos - 100.0).abs() < 0.001);
    }

    #[test]
    fn test_scrolls_down_when_item_below() {
        // viewport 0..400, item at index 5: top=500, bottom=600
        let pos = scroll_ahead(5, 100.0, 0.0, 400.0);
        assert!((pos - 200.0).abs() < 0.001); // item_bottom - viewport_height = 600-400=200
    }

    #[test]
    fn test_scrolls_up_when_item_above() {
        // scroll_pos=300, item at index 2: top=200 — above viewport top
        let pos = scroll_ahead(2, 100.0, 300.0, 400.0);
        assert!((pos - 200.0).abs() < 0.001);
    }
}
