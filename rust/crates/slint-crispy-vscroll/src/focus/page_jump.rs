//! page_jump — viewport-follow strategy: jump a full page at a time (Task 13).

/// Result of a page jump.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct PageJumpResult {
    pub new_scroll: f32,
    pub new_focus: usize,
}

/// Jump forward one page.
///
/// Advances scroll by `viewport_height`. Focus moves to the first fully visible
/// item in the new page. Clamps at the last item / max scroll.
pub fn page_jump_forward(
    scroll_pos: f32,
    viewport_height: f32,
    item_height: f32,
    item_count: usize,
) -> PageJumpResult {
    let total_height = item_count as f32 * item_height;
    let max_scroll = (total_height - viewport_height).max(0.0);
    let new_scroll = (scroll_pos + viewport_height).min(max_scroll);
    let new_focus = ((new_scroll / item_height) as usize).min(item_count.saturating_sub(1));
    PageJumpResult {
        new_scroll,
        new_focus,
    }
}

/// Jump backward one page.
///
/// Moves scroll back by `viewport_height`. Focus moves to the first visible item.
/// Clamps at scroll=0 / focus=0.
pub fn page_jump_backward(
    scroll_pos: f32,
    viewport_height: f32,
    item_height: f32,
    item_count: usize,
) -> PageJumpResult {
    let new_scroll = (scroll_pos - viewport_height).max(0.0);
    let new_focus = ((new_scroll / item_height) as usize).min(item_count.saturating_sub(1));
    PageJumpResult {
        new_scroll,
        new_focus,
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_page_jump_forward_advances() {
        // 20 items * 100h = 2000, viewport=400, start at 0
        let r = page_jump_forward(0.0, 400.0, 100.0, 20);
        assert!((r.new_scroll - 400.0).abs() < 0.001);
        assert_eq!(r.new_focus, 4);
    }

    #[test]
    fn test_page_jump_backward_retreats() {
        let r = page_jump_backward(800.0, 400.0, 100.0, 20);
        assert!((r.new_scroll - 400.0).abs() < 0.001);
        assert_eq!(r.new_focus, 4);
    }

    #[test]
    fn test_page_jump_forward_clamps_at_end() {
        // Already near the end: scroll=1700, max=1600
        let r = page_jump_forward(1700.0, 400.0, 100.0, 20);
        assert!((r.new_scroll - 1600.0).abs() < 0.001);
        assert_eq!(r.new_focus, 16);
    }

    #[test]
    fn test_page_jump_backward_clamps_at_zero() {
        let r = page_jump_backward(100.0, 400.0, 100.0, 20);
        assert!((r.new_scroll - 0.0).abs() < 0.001);
        assert_eq!(r.new_focus, 0);
    }
}
