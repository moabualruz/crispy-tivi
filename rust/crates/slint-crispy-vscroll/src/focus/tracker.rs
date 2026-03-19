//! FocusTracker — linear and grid navigation with edge overflow callbacks (Tasks 9, 10, 14).

use crate::core::types::{Direction, NavDirection};

// ---------------------------------------------------------------------------
// NavResult
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NavResult {
    Moved(usize),
    EdgeReached(NavDirection),
}

// ---------------------------------------------------------------------------
// FocusEdge (Task 14)
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FocusEdge {
    First,
    Last,
}

// ---------------------------------------------------------------------------
// FocusTracker
// ---------------------------------------------------------------------------

pub struct FocusTracker {
    item_count: usize,
    columns: usize,
    #[allow(dead_code)]
    direction: Direction,
    focused: usize,
    overflow_cb: Option<Box<dyn FnMut(FocusEdge) + Send>>,
}

impl FocusTracker {
    /// Linear list (columns = 1).
    pub fn new(item_count: usize, direction: Direction) -> Self {
        Self {
            item_count,
            columns: 1,
            direction,
            focused: 0,
            overflow_cb: None,
        }
    }

    /// Grid layout with the given column count (Task 10).
    pub fn new_grid(item_count: usize, columns: usize) -> Self {
        assert!(columns > 0, "columns must be > 0");
        Self {
            item_count,
            columns,
            direction: Direction::Vertical,
            focused: 0,
            overflow_cb: None,
        }
    }

    pub fn focused_index(&self) -> usize {
        self.focused
    }

    pub fn set_focus(&mut self, index: usize) {
        self.focused = index.min(self.item_count.saturating_sub(1));
    }

    /// Register a callback that fires when navigation hits an edge (Task 14).
    pub fn on_overflow(&mut self, cb: impl FnMut(FocusEdge) + Send + 'static) {
        self.overflow_cb = Some(Box::new(cb));
    }

    /// Navigate in the given direction. Returns `Moved(new_index)` or `EdgeReached`.
    pub fn navigate(&mut self, dir: NavDirection) -> NavResult {
        if self.item_count == 0 {
            return NavResult::EdgeReached(dir);
        }

        let step = self.step_for(dir);

        match step {
            Step::Forward(delta) => {
                let new_idx = self.focused + delta;
                if new_idx >= self.item_count {
                    self.fire_overflow(FocusEdge::Last);
                    NavResult::EdgeReached(dir)
                } else {
                    self.focused = new_idx;
                    NavResult::Moved(self.focused)
                }
            }
            Step::Backward(delta) => {
                if delta > self.focused {
                    self.fire_overflow(FocusEdge::First);
                    NavResult::EdgeReached(dir)
                } else {
                    self.focused -= delta;
                    NavResult::Moved(self.focused)
                }
            }
        }
    }

    // -----------------------------------------------------------------------
    // Private
    // -----------------------------------------------------------------------

    fn step_for(&self, dir: NavDirection) -> Step {
        match dir {
            NavDirection::Down => Step::Forward(self.columns),
            NavDirection::Right => Step::Forward(1),
            NavDirection::Up => Step::Backward(self.columns),
            NavDirection::Left => Step::Backward(1),
        }
    }

    fn fire_overflow(&mut self, edge: FocusEdge) {
        if let Some(cb) = self.overflow_cb.as_mut() {
            cb(edge);
        }
    }
}

// ---------------------------------------------------------------------------
// Internal helper
// ---------------------------------------------------------------------------

enum Step {
    Forward(usize),
    Backward(usize),
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    // --- Task 9: Linear navigation ---

    #[test]
    fn test_linear_down_increments() {
        let mut t = FocusTracker::new(10, Direction::Vertical);
        let r = t.navigate(NavDirection::Down);
        assert_eq!(r, NavResult::Moved(1));
        assert_eq!(t.focused_index(), 1);
    }

    #[test]
    fn test_linear_up_decrements() {
        let mut t = FocusTracker::new(10, Direction::Vertical);
        t.set_focus(5);
        let r = t.navigate(NavDirection::Up);
        assert_eq!(r, NavResult::Moved(4));
    }

    #[test]
    fn test_linear_clamp_at_zero() {
        let mut t = FocusTracker::new(10, Direction::Vertical);
        t.set_focus(0);
        let r = t.navigate(NavDirection::Up);
        assert_eq!(r, NavResult::EdgeReached(NavDirection::Up));
        assert_eq!(t.focused_index(), 0);
    }

    #[test]
    fn test_linear_clamp_at_max() {
        let mut t = FocusTracker::new(5, Direction::Vertical);
        t.set_focus(4);
        let r = t.navigate(NavDirection::Down);
        assert_eq!(r, NavResult::EdgeReached(NavDirection::Down));
        assert_eq!(t.focused_index(), 4);
    }

    // --- Task 10: Grid navigation ---

    #[test]
    fn test_grid_down_same_column() {
        let mut t = FocusTracker::new_grid(9, 3);
        t.set_focus(1); // row 0, col 1
        let r = t.navigate(NavDirection::Down);
        assert_eq!(r, NavResult::Moved(4)); // row 1, col 1
    }

    #[test]
    fn test_grid_right_within_row() {
        let mut t = FocusTracker::new_grid(9, 3);
        t.set_focus(3); // row 1, col 0
        let r = t.navigate(NavDirection::Right);
        assert_eq!(r, NavResult::Moved(4));
    }

    #[test]
    fn test_grid_partial_last_row_clamp() {
        // 7 items, 3 cols → last row has 1 item at index 6
        let mut t = FocusTracker::new_grid(7, 3);
        t.set_focus(3); // row 1, col 0
        let r = t.navigate(NavDirection::Down); // would be 6 (valid)
        assert_eq!(r, NavResult::Moved(6));
        let r2 = t.navigate(NavDirection::Down); // 6+3=9 >= 7 → edge
        assert_eq!(r2, NavResult::EdgeReached(NavDirection::Down));
    }

    // --- Task 14: Edge overflow callback ---

    #[test]
    fn test_overflow_fires_at_last() {
        let mut t = FocusTracker::new(3, Direction::Vertical);
        t.set_focus(2);
        let fired = std::sync::Arc::new(std::sync::Mutex::new(None::<FocusEdge>));
        let fired_clone = fired.clone();
        t.on_overflow(move |e| {
            *fired_clone.lock().unwrap() = Some(e);
        });
        t.navigate(NavDirection::Down);
        assert_eq!(*fired.lock().unwrap(), Some(FocusEdge::Last));
    }

    #[test]
    fn test_overflow_fires_at_first() {
        let mut t = FocusTracker::new(3, Direction::Vertical);
        t.set_focus(0);
        let fired = std::sync::Arc::new(std::sync::Mutex::new(None::<FocusEdge>));
        let fired_clone = fired.clone();
        t.on_overflow(move |e| {
            *fired_clone.lock().unwrap() = Some(e);
        });
        t.navigate(NavDirection::Up);
        assert_eq!(*fired.lock().unwrap(), Some(FocusEdge::First));
    }

    #[test]
    fn test_overflow_does_not_fire_mid_list() {
        let mut t = FocusTracker::new(5, Direction::Vertical);
        t.set_focus(2);
        let fired = std::sync::Arc::new(std::sync::Mutex::new(false));
        let fired_clone = fired.clone();
        t.on_overflow(move |_| {
            *fired_clone.lock().unwrap() = true;
        });
        t.navigate(NavDirection::Down);
        t.navigate(NavDirection::Up);
        assert!(!*fired.lock().unwrap());
    }
}
