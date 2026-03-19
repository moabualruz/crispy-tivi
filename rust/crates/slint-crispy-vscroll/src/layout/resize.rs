//! Resize strategies — pure functions that recompute layout parameters when the
//! viewport size changes.
//!
//! Three strategies are provided, each behind its own feature flag:
//! - [`reflow`] (`resize-reflow`)   — recalculate column count to fill width
//! - [`scale`]  (`resize-scale`)    — keep column count, adjust item width
//! - [`breakpoints`] (`resize-breakpoints`) — step-wise column changes with hysteresis

// ---------------------------------------------------------------------------
// Shared types
// ---------------------------------------------------------------------------

/// Output produced by any resize strategy.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ResizeResult {
    /// New column count.
    pub columns: usize,
    /// New item width (pixels).
    pub item_width: f32,
    /// New item height (pixels).
    pub item_height: f32,
}

// ---------------------------------------------------------------------------
// Reflow strategy  (resize-reflow)
// ---------------------------------------------------------------------------

/// Reflow: fit as many columns as possible given `min_item_width` and `gap_x`.
///
/// `item_height` is kept fixed; item width expands to fill the available space
/// evenly across the computed column count.
#[cfg(feature = "resize-reflow")]
pub mod reflow {
    use super::ResizeResult;

    /// Recompute columns and item size for a new viewport width.
    ///
    /// # Arguments
    /// * `viewport_w` — new viewport width in pixels
    /// * `min_item_width` — minimum allowed item width
    /// * `item_height` — fixed item height (unchanged by reflow)
    /// * `gap_x` — horizontal gap between columns
    ///
    /// Returns a `ResizeResult` with the new column count and item dimensions.
    pub fn apply_resize(
        viewport_w: f32,
        min_item_width: f32,
        item_height: f32,
        gap_x: f32,
    ) -> ResizeResult {
        let min_w = min_item_width.max(1.0);
        let gap = gap_x.max(0.0);

        // Maximum columns that fit: floor((W + gap) / (min_w + gap))
        let columns = ((viewport_w + gap) / (min_w + gap)).floor().max(1.0) as usize;

        // Spread remaining space evenly among columns
        let total_gap = gap * (columns.saturating_sub(1)) as f32;
        let item_width = ((viewport_w - total_gap) / columns as f32).max(min_w);

        ResizeResult {
            columns,
            item_width,
            item_height,
        }
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        #[test]
        fn test_reflow_3_cols_at_1280px() {
            // min_item_width=400, gap=8 → (1280+8)/(400+8) = 1288/408 ≈ 3.15 → 3 cols
            let r = apply_resize(1280.0, 400.0, 225.0, 8.0);
            assert_eq!(r.columns, 3);
            // item_width = (1280 - 8*2) / 3 = 1264 / 3 ≈ 421.3
            assert!(r.item_width > 400.0);
        }

        #[test]
        fn test_reflow_minimum_one_col() {
            let r = apply_resize(100.0, 400.0, 225.0, 8.0);
            assert_eq!(r.columns, 1);
        }

        #[test]
        fn test_reflow_item_width_fills_viewport() {
            let r = apply_resize(800.0, 200.0, 180.0, 0.0);
            // (800) / 200 = 4 columns, item_width = 800/4 = 200
            assert_eq!(r.columns, 4);
            assert!((r.item_width - 200.0).abs() < 0.5);
        }

        #[test]
        fn test_reflow_item_height_unchanged() {
            let r = apply_resize(1000.0, 200.0, 150.0, 10.0);
            assert!((r.item_height - 150.0).abs() < 0.001);
        }
    }
}

// ---------------------------------------------------------------------------
// Scale strategy  (resize-scale)
// ---------------------------------------------------------------------------

/// Scale: keep the column count fixed, adjust item width (and optionally height)
/// proportionally to fill the new viewport.
#[cfg(feature = "resize-scale")]
pub mod scale {
    use super::ResizeResult;

    /// Recompute item size for a new viewport width, keeping columns fixed.
    ///
    /// # Arguments
    /// * `viewport_w` — new viewport width in pixels
    /// * `columns` — fixed column count (unchanged)
    /// * `gap_x` — horizontal gap between columns
    /// * `aspect_ratio` — width/height ratio to apply to the new item width (0 = keep original height)
    /// * `original_height` — original item height (used when `aspect_ratio == 0`)
    pub fn apply_resize(
        viewport_w: f32,
        columns: usize,
        gap_x: f32,
        aspect_ratio: f32,
        original_height: f32,
    ) -> ResizeResult {
        let cols = columns.max(1);
        let gap = gap_x.max(0.0);
        let total_gap = gap * (cols.saturating_sub(1)) as f32;
        let item_width = ((viewport_w - total_gap) / cols as f32).max(1.0);
        let item_height = if aspect_ratio > 0.0 {
            item_width / aspect_ratio
        } else {
            original_height
        };
        ResizeResult {
            columns: cols,
            item_width,
            item_height,
        }
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        #[test]
        fn test_scale_maintains_col_count() {
            let r = apply_resize(960.0, 3, 8.0, 0.0, 180.0);
            assert_eq!(r.columns, 3);
        }

        #[test]
        fn test_scale_item_width_fills_viewport() {
            // 3 cols, 8px gap each side between cols → total gap 16px
            // item_width = (960 - 16) / 3 = 944/3 ≈ 314.67
            let r = apply_resize(960.0, 3, 8.0, 0.0, 180.0);
            let expected = (960.0 - 8.0 * 2.0) / 3.0;
            assert!((r.item_width - expected).abs() < 0.5);
        }

        #[test]
        fn test_scale_aspect_ratio_applied() {
            // 16:9 → height = width / (16/9)
            let r = apply_resize(960.0, 3, 0.0, 16.0 / 9.0, 0.0);
            let expected_w = 960.0 / 3.0;
            let expected_h = expected_w / (16.0 / 9.0);
            assert!((r.item_width - expected_w).abs() < 0.5);
            assert!((r.item_height - expected_h).abs() < 0.5);
        }

        #[test]
        fn test_scale_height_unchanged_when_no_aspect() {
            let r = apply_resize(1200.0, 4, 0.0, 0.0, 200.0);
            assert!((r.item_height - 200.0).abs() < 0.001);
        }
    }
}

// ---------------------------------------------------------------------------
// Breakpoints strategy  (resize-breakpoints)
// ---------------------------------------------------------------------------

/// Breakpoints: step-wise column changes with hysteresis to prevent rapid
/// oscillation when the viewport sits near a breakpoint boundary.
///
/// `Breakpoint` entries define the **minimum** viewport width at which a given
/// column count applies.  They must be sorted ascending by `min_width`.
#[cfg(feature = "resize-breakpoints")]
pub mod breakpoints {
    use super::ResizeResult;

    /// A single breakpoint definition.
    #[derive(Debug, Clone, Copy)]
    pub struct Breakpoint {
        /// Minimum viewport width (inclusive) at which this column count applies.
        pub min_width: f32,
        /// Column count for viewports >= `min_width`.
        pub columns: usize,
    }

    /// State for hysteresis — remembers the last committed column count so
    /// transitions only fire when the viewport crosses the threshold by at
    /// least `hysteresis_px` pixels.
    #[derive(Debug, Clone)]
    pub struct BreakpointState {
        current_columns: usize,
        hysteresis_px: f32,
    }

    impl BreakpointState {
        /// Create state with an initial column count and hysteresis band.
        pub fn new(initial_columns: usize, hysteresis_px: f32) -> Self {
            Self {
                current_columns: initial_columns,
                hysteresis_px,
            }
        }

        /// Update state for a new viewport width and return the new `ResizeResult`.
        ///
        /// # Arguments
        /// * `viewport_w` — new viewport width
        /// * `breakpoints` — sorted ascending by `min_width`; must have at least one entry
        /// * `gap_x` — horizontal gap between columns
        /// * `item_height` — fixed item height
        pub fn apply_resize(
            &mut self,
            viewport_w: f32,
            breakpoints: &[Breakpoint],
            gap_x: f32,
            item_height: f32,
        ) -> ResizeResult {
            if breakpoints.is_empty() {
                return ResizeResult {
                    columns: self.current_columns.max(1),
                    item_width: viewport_w,
                    item_height,
                };
            }

            // Find the column count that would apply at `viewport_w` without hysteresis
            let target_columns = target_columns_for(viewport_w, breakpoints);

            // Apply hysteresis: only commit to new column count if we've moved
            // far enough past the boundary.
            let new_columns = if target_columns != self.current_columns {
                // Find the boundary we're crossing
                let boundary = crossing_boundary(
                    self.current_columns,
                    target_columns,
                    viewport_w,
                    breakpoints,
                );
                let committed = match boundary {
                    Some(b) => {
                        // Switching to fewer columns (shrink): require viewport < boundary - hyst
                        // Switching to more columns (grow):   require viewport > boundary + hyst
                        if target_columns < self.current_columns {
                            viewport_w < b - self.hysteresis_px
                        } else {
                            viewport_w >= b + self.hysteresis_px
                        }
                    }
                    None => true,
                };
                if committed {
                    target_columns
                } else {
                    self.current_columns
                }
            } else {
                self.current_columns
            };

            self.current_columns = new_columns;

            let cols = new_columns.max(1);
            let gap = gap_x.max(0.0);
            let total_gap = gap * (cols.saturating_sub(1)) as f32;
            let item_width = ((viewport_w - total_gap) / cols as f32).max(1.0);

            ResizeResult {
                columns: cols,
                item_width,
                item_height,
            }
        }

        /// Current committed column count.
        pub fn current_columns(&self) -> usize {
            self.current_columns
        }
    }

    /// Determine the column count for `viewport_w` given sorted breakpoints.
    fn target_columns_for(viewport_w: f32, breakpoints: &[Breakpoint]) -> usize {
        let mut result = breakpoints[0].columns;
        for bp in breakpoints {
            if viewport_w >= bp.min_width {
                result = bp.columns;
            }
        }
        result
    }

    /// Find the exact `min_width` boundary between the two column counts.
    fn crossing_boundary(
        from_cols: usize,
        to_cols: usize,
        _viewport_w: f32,
        breakpoints: &[Breakpoint],
    ) -> Option<f32> {
        // When shrinking (to < from): boundary is the min_width of the from_cols
        // breakpoint — the threshold we're dropping below.
        // When growing (to > from): boundary is the min_width of the to_cols
        // breakpoint — the threshold we're rising above.
        let match_cols = if to_cols < from_cols {
            from_cols
        } else {
            to_cols
        };
        for bp in breakpoints {
            if bp.columns == match_cols {
                return Some(bp.min_width);
            }
        }
        None
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        fn make_breakpoints() -> Vec<Breakpoint> {
            vec![
                Breakpoint {
                    min_width: 0.0,
                    columns: 1,
                },
                Breakpoint {
                    min_width: 600.0,
                    columns: 2,
                },
                Breakpoint {
                    min_width: 900.0,
                    columns: 3,
                },
                Breakpoint {
                    min_width: 1200.0,
                    columns: 4,
                },
            ]
        }

        #[test]
        fn test_breakpoints_selects_correct_col_count() {
            let bps = make_breakpoints();
            let mut state = BreakpointState::new(1, 0.0);
            let r = state.apply_resize(1000.0, &bps, 8.0, 180.0);
            assert_eq!(r.columns, 3);
        }

        #[test]
        fn test_breakpoints_below_first_boundary() {
            let bps = make_breakpoints();
            let mut state = BreakpointState::new(1, 0.0);
            let r = state.apply_resize(400.0, &bps, 0.0, 180.0);
            assert_eq!(r.columns, 1);
        }

        #[test]
        fn test_breakpoints_hysteresis_prevents_early_switch() {
            let bps = make_breakpoints();
            // Start at 3 cols (viewport = 1000).  Shrink to 850 which is < 900
            // boundary but within hysteresis band of 60px → should stay at 3.
            let mut state = BreakpointState::new(3, 60.0);
            let r = state.apply_resize(850.0, &bps, 8.0, 180.0);
            assert_eq!(r.columns, 3, "hysteresis should hold at 3 cols");
        }

        #[test]
        fn test_breakpoints_hysteresis_commits_when_far_enough() {
            let bps = make_breakpoints();
            // Start at 3 cols. Shrink to 820 which is < 900 - 60 = 840 → commit to 2.
            let mut state = BreakpointState::new(3, 60.0);
            let r = state.apply_resize(820.0, &bps, 8.0, 180.0);
            assert_eq!(
                r.columns, 2,
                "should commit to 2 cols below hysteresis band"
            );
        }

        #[test]
        fn test_breakpoints_empty_returns_current_columns() {
            // Covers lines 236-239: early return when breakpoints is empty
            let mut state = BreakpointState::new(3, 0.0);
            let r = state.apply_resize(500.0, &[], 0.0, 180.0);
            assert_eq!(r.columns, 3);
            assert!((r.item_width - 500.0).abs() < 0.1);
        }

        #[test]
        fn test_breakpoints_current_columns_accessor() {
            // Covers current_columns() lines 292-293
            let mut state = BreakpointState::new(2, 0.0);
            assert_eq!(state.current_columns(), 2);
            let bps = make_breakpoints();
            state.apply_resize(1000.0, &bps, 0.0, 180.0);
            assert_eq!(state.current_columns(), 3);
        }

        #[test]
        fn test_breakpoints_grow_commits_past_hysteresis() {
            // Covers: growing path (to > from) → viewport >= b + hyst
            // Also exercises crossing_boundary None path via no-match column
            let bps = make_breakpoints();
            // Start at 2 cols. Grow past 900 + 30 = 930 → should commit to 3
            let mut state = BreakpointState::new(2, 30.0);
            let r = state.apply_resize(940.0, &bps, 0.0, 180.0);
            assert_eq!(
                r.columns, 3,
                "should commit to 3 cols above hysteresis band"
            );
        }

        #[test]
        fn test_breakpoints_crossing_boundary_none_commits_unconditionally() {
            // Covers None => true arm: when current_columns is 5 (not in breakpoints),
            // crossing_boundary returns None → commit unconditionally
            let bps = make_breakpoints(); // columns: 1, 2, 3, 4
                                          // Start at 5 cols (not a breakpoint). Any change → crossing_boundary None → commit
            let mut state = BreakpointState::new(5, 100.0);
            let r = state.apply_resize(1000.0, &bps, 0.0, 180.0);
            // target is 3 cols, boundary is None → committed to 3 unconditionally
            assert_eq!(r.columns, 3);
        }

        #[test]
        fn test_breakpoints_grow_prevented_within_hysteresis() {
            // Covers: growing path, viewport < boundary + hyst → stay at current
            let bps = make_breakpoints();
            // Start at 2 cols. Grow to 910 which is < 900 + 30 → stay at 2
            let mut state = BreakpointState::new(2, 30.0);
            let r = state.apply_resize(910.0, &bps, 0.0, 180.0);
            assert_eq!(r.columns, 2, "should stay at 2 cols within hysteresis band");
        }

        #[test]
        fn test_breakpoints_item_width_fills_viewport() {
            let bps = make_breakpoints();
            let mut state = BreakpointState::new(1, 0.0);
            let r = state.apply_resize(900.0, &bps, 0.0, 180.0);
            assert_eq!(r.columns, 3);
            assert!((r.item_width - 300.0).abs() < 0.5);
        }
    }
}
