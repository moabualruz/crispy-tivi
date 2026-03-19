//! GridFocusNavigator — column-preserving D-pad navigation for grid layouts.
//!
//! Computes the next focused item index given the current index, grid dimensions,
//! and a navigation direction.  Partial last rows are handled by clamping to the
//! last valid item rather than wrapping or panicking.

use crate::core::types::NavDirection;

// ---------------------------------------------------------------------------
// GridFocusNavigator
// ---------------------------------------------------------------------------

/// Stateless helper that maps (current_index, direction) → next_index in a
/// grid whose items fill row-by-row (left → right, top → bottom).
pub struct GridFocusNavigator {
    columns: usize,
    total: usize,
}

impl GridFocusNavigator {
    /// Create a navigator for a grid with the given column count and total items.
    ///
    /// # Panics
    /// Panics if `columns == 0`.
    pub fn new(columns: usize, total: usize) -> Self {
        assert!(columns > 0, "columns must be > 0");
        Self { columns, total }
    }

    /// Return the index the focus should move to from `current` in direction `dir`.
    ///
    /// - Moving **Right** from the last column in a row stays at that column.
    /// - Moving **Left** from column 0 stays at column 0.
    /// - Moving **Down** from the last row (or partial last row) stays at `current`.
    ///   If the target column does not exist in the next row (partial row), the
    ///   result is clamped to the last valid item.
    /// - Moving **Up** from row 0 stays at `current`.
    pub fn next_focus(&self, current: usize, dir: NavDirection) -> usize {
        if self.total == 0 {
            return 0;
        }
        let last = self.total.saturating_sub(1);
        let col = current % self.columns;
        let row = current / self.columns;

        let candidate = match dir {
            NavDirection::Right => {
                if col + 1 < self.columns {
                    current + 1
                } else {
                    current
                }
            }
            NavDirection::Left => {
                if col > 0 {
                    current - 1
                } else {
                    current
                }
            }
            NavDirection::Down => {
                let target = (row + 1) * self.columns + col;
                if target < self.total {
                    target
                } else if (row + 1) * self.columns < self.total {
                    // Next row exists but doesn't reach this column — clamp to last item
                    last
                } else {
                    // Already on the last row
                    current
                }
            }
            NavDirection::Up => {
                if row > 0 {
                    (row - 1) * self.columns + col
                } else {
                    current
                }
            }
        };
        candidate.min(last)
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    fn nav(cols: usize, total: usize, from: usize, dir: NavDirection) -> usize {
        GridFocusNavigator::new(cols, total).next_focus(from, dir)
    }

    #[test]
    fn test_right_moves_to_next_col() {
        assert_eq!(nav(3, 9, 0, NavDirection::Right), 1);
    }

    #[test]
    fn test_left_moves_to_prev_col() {
        assert_eq!(nav(3, 9, 1, NavDirection::Left), 0);
    }

    #[test]
    fn test_down_moves_to_same_col_next_row() {
        // col=1, row=0 → col=1, row=1 = index 4
        assert_eq!(nav(3, 9, 1, NavDirection::Down), 4);
    }

    #[test]
    fn test_up_moves_to_same_col_prev_row() {
        // col=1, row=1 = index 4 → col=1, row=0 = index 1
        assert_eq!(nav(3, 9, 4, NavDirection::Up), 1);
    }

    #[test]
    fn test_right_at_last_col_stays() {
        assert_eq!(nav(3, 9, 2, NavDirection::Right), 2);
    }

    #[test]
    fn test_left_at_first_col_stays() {
        assert_eq!(nav(3, 9, 0, NavDirection::Left), 0);
    }

    #[test]
    fn test_up_at_first_row_stays() {
        assert_eq!(nav(3, 9, 1, NavDirection::Up), 1);
    }

    #[test]
    fn test_down_at_last_full_row_stays() {
        // 9 items, 3 cols → last row is row 2 (indices 6,7,8)
        assert_eq!(nav(3, 9, 7, NavDirection::Down), 7);
    }

    #[test]
    fn test_down_into_partial_last_row_clamps_to_last_item() {
        // 5 items, 3 cols: row 0 = [0,1,2], row 1 = [3,4]
        // From index 2 (col=2, row=0) → col=2, row=1 = index 5 (doesn't exist) → clamp to 4
        assert_eq!(nav(3, 5, 2, NavDirection::Down), 4);
        // From index 1 (col=1, row=0) → col=1, row=1 = index 4 (exists) → 4
        assert_eq!(nav(3, 5, 1, NavDirection::Down), 4);
    }

    #[test]
    fn test_column_preserved_across_rows() {
        // 12 items, 4 cols
        // index 2 = row 0, col 2 → down → row 1, col 2 = index 6 → down → row 2, col 2 = index 10
        assert_eq!(nav(4, 12, 2, NavDirection::Down), 6);
        assert_eq!(nav(4, 12, 6, NavDirection::Down), 10);
    }

    #[test]
    fn test_zero_total_returns_zero() {
        let nav_obj = GridFocusNavigator::new(3, 0);
        assert_eq!(nav_obj.next_focus(0, NavDirection::Down), 0);
    }
}
