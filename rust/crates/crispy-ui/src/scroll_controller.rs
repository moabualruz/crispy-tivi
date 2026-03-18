//! D-pad scroll controller with momentum acceleration.
//!
//! Tracks logical focus position, detects buffer zone entry,
//! and computes window shift targets for WindowedModel.

#![allow(dead_code)]

pub(crate) struct ScrollController {
    /// Absolute position in the full dataset
    logical_focus: usize,
    /// Total items in dataset
    total_count: usize,
    /// Number of visible items in the window
    visible_count: usize,
    /// Items from edge that trigger prefetch/shift
    buffer_zone: usize,
    /// Current window start position
    window_start: usize,
}

pub(crate) enum ScrollResult {
    /// Focus moved within current window — no shift needed
    FocusOnly { visual_index: usize },
    /// Window must shift — call WindowedModel.shift_to(new_start)
    Shift {
        new_start: usize,
        visual_index: usize,
    },
}

impl ScrollController {
    pub(crate) fn new(total_count: usize, visible_count: usize, buffer_zone: usize) -> Self {
        Self {
            logical_focus: 0,
            total_count,
            visible_count,
            buffer_zone,
            window_start: 0,
        }
    }

    /// Move focus by delta (+1 = down, -1 = up). Returns what action to take.
    pub(crate) fn move_focus(&mut self, delta: isize) -> ScrollResult {
        // 1. Compute new logical focus (clamp to 0..total_count-1)
        let new_focus = if delta >= 0 {
            (self.logical_focus + delta as usize).min(self.total_count.saturating_sub(1))
        } else {
            self.logical_focus.saturating_sub((-delta) as usize)
        };
        self.logical_focus = new_focus;

        // 2. Compute visual index within current window
        let visual = new_focus.saturating_sub(self.window_start);

        // 3. Check if we're in the buffer zone
        let near_bottom = visual + self.buffer_zone >= self.visible_count;
        let near_top = visual < self.buffer_zone;

        if near_bottom && self.window_start + self.visible_count < self.total_count {
            // Shift window forward — center focus in window
            let ideal_start = new_focus.saturating_sub(self.visible_count / 2);
            let max_start = self.total_count.saturating_sub(self.visible_count);
            let new_start = ideal_start.min(max_start);
            self.window_start = new_start;
            ScrollResult::Shift {
                new_start,
                visual_index: new_focus - new_start,
            }
        } else if near_top && self.window_start > 0 {
            // Shift window backward — center focus in window
            let ideal_start = new_focus.saturating_sub(self.visible_count / 2);
            let new_start = ideal_start; // can be 0
            self.window_start = new_start;
            ScrollResult::Shift {
                new_start,
                visual_index: new_focus - new_start,
            }
        } else {
            ScrollResult::FocusOnly {
                visual_index: visual,
            }
        }
    }

    /// Update total count (e.g., when new data arrives).
    pub(crate) fn set_total_count(&mut self, total: usize) {
        self.total_count = total;
        // Clamp focus if dataset shrunk
        if self.logical_focus >= total {
            self.logical_focus = total.saturating_sub(1);
        }
        if self.window_start + self.visible_count > total {
            self.window_start = total.saturating_sub(self.visible_count);
        }
    }

    /// Reset to beginning (e.g., on filter change).
    pub(crate) fn reset(&mut self) {
        self.logical_focus = 0;
        self.window_start = 0;
    }

    /// Current logical focus position.
    pub(crate) fn logical_focus(&self) -> usize {
        self.logical_focus
    }

    /// Current window start.
    pub(crate) fn window_start(&self) -> usize {
        self.window_start
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // Helper: total=100, visible=30, buffer=5
    fn make_controller() -> ScrollController {
        ScrollController::new(100, 30, 5)
    }

    #[test]
    fn test_move_focus_within_window() {
        let mut sc = make_controller();
        // Start at 0, move to position 10 — deep in window, no buffer zone
        for _ in 0..10 {
            sc.move_focus(1);
        }
        let result = sc.move_focus(1);
        match result {
            ScrollResult::FocusOnly { visual_index } => {
                assert_eq!(visual_index, 11);
                assert_eq!(sc.logical_focus(), 11);
                assert_eq!(sc.window_start(), 0);
            }
            ScrollResult::Shift { .. } => panic!("expected FocusOnly at pos 11"),
        }
    }

    #[test]
    fn test_move_focus_triggers_shift_at_buffer_zone() {
        let mut sc = make_controller();
        // Move to position 24: visual=24, buffer=5 → 24+5=29 >= 30 → triggers shift
        for _ in 0..24 {
            sc.move_focus(1);
        }
        let result = sc.move_focus(1); // pos 25: 25+5=30 >= 30 → shift
        match result {
            ScrollResult::Shift {
                new_start,
                visual_index,
            } => {
                assert!(new_start > 0, "window should have shifted forward");
                assert_eq!(sc.logical_focus(), 25);
                assert_eq!(sc.window_start(), new_start);
                assert_eq!(visual_index, 25 - new_start);
            }
            ScrollResult::FocusOnly { .. } => panic!("expected Shift near bottom buffer zone"),
        }
    }

    #[test]
    fn test_move_focus_backward_triggers_shift() {
        let mut sc = make_controller();
        // Jump window forward by setting state directly
        sc.window_start = 40;
        sc.logical_focus = 45;
        // Move up: visual = 45-40 = 5; 5 < buffer_zone(5) → near_top, window > 0 → shift
        let result = sc.move_focus(-1); // focus → 44, visual = 44-40 = 4 < 5 → shift
        match result {
            ScrollResult::Shift {
                new_start,
                visual_index,
            } => {
                assert!(new_start < 40, "window should have shifted backward");
                assert_eq!(sc.logical_focus(), 44);
                assert_eq!(sc.window_start(), new_start);
                assert_eq!(visual_index, 44 - new_start);
            }
            ScrollResult::FocusOnly { .. } => panic!("expected Shift near top buffer zone"),
        }
    }

    #[test]
    fn test_clamp_at_start() {
        let mut sc = make_controller();
        assert_eq!(sc.logical_focus(), 0);
        let result = sc.move_focus(-1);
        match result {
            ScrollResult::FocusOnly { visual_index } => {
                assert_eq!(visual_index, 0);
                assert_eq!(sc.logical_focus(), 0);
            }
            ScrollResult::Shift { .. } => panic!("expected FocusOnly at start clamp"),
        }
    }

    #[test]
    fn test_clamp_at_end() {
        let mut sc = make_controller();
        // Move to near the end first to get window shifted
        sc.logical_focus = 99;
        sc.window_start = 70;
        let result = sc.move_focus(1); // should stay at 99
        match result {
            ScrollResult::FocusOnly { visual_index } => {
                assert_eq!(sc.logical_focus(), 99);
                assert_eq!(visual_index, 99 - sc.window_start());
            }
            ScrollResult::Shift { .. } => {
                // Shift is also acceptable if in buffer zone — just check focus clamped
                assert_eq!(sc.logical_focus(), 99);
            }
        }
        // A second +1 must also stay at 99
        sc.move_focus(1);
        assert_eq!(sc.logical_focus(), 99);
    }

    #[test]
    fn test_reset_returns_to_zero() {
        let mut sc = make_controller();
        sc.logical_focus = 50;
        sc.window_start = 30;
        sc.reset();
        assert_eq!(sc.logical_focus(), 0);
        assert_eq!(sc.window_start(), 0);
    }

    #[test]
    fn test_set_total_count_shrinks() {
        let mut sc = make_controller();
        sc.logical_focus = 80;
        sc.window_start = 70;
        sc.set_total_count(50);
        assert_eq!(sc.total_count, 50);
        assert!(sc.logical_focus() < 50, "focus must be clamped");
        assert!(
            sc.window_start() + sc.visible_count <= 50,
            "window must not exceed new total"
        );
    }

    #[test]
    fn test_empty_dataset() {
        let mut sc = ScrollController::new(0, 30, 5);
        // Must not panic
        let result = sc.move_focus(1);
        match result {
            ScrollResult::FocusOnly { visual_index } => assert_eq!(visual_index, 0),
            ScrollResult::Shift { .. } => {} // acceptable
        }
        assert_eq!(sc.logical_focus(), 0);
        sc.set_total_count(0);
        sc.reset();
    }

    #[test]
    fn test_dataset_smaller_than_window() {
        // total=10, visible=30, buffer=5 — dataset fits entirely in window
        let mut sc = ScrollController::new(10, 30, 5);
        // Walk all 10 items forward — should never shift (total < visible)
        for i in 0..9usize {
            let result = sc.move_focus(1);
            match result {
                ScrollResult::FocusOnly { visual_index } => {
                    assert_eq!(visual_index, i + 1);
                }
                ScrollResult::Shift { .. } => {
                    // near_bottom check: window_start(0) + visible_count(30) >= total(10)
                    // so the shift branch condition `window_start + visible_count < total` is false
                    // This path should not occur
                    panic!("unexpected Shift when total < visible_count at step {i}");
                }
            }
        }
        assert_eq!(sc.logical_focus(), 9);
        // Move beyond end — clamp
        sc.move_focus(1);
        assert_eq!(sc.logical_focus(), 9);
    }
}
