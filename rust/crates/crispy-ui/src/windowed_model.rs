//! Virtual-scroll Model adapter for Slint.
//!
//! `WindowedModel` wraps a full dataset (`Arc<Vec<S>>`) and exposes only
//! a sliding window of `window_size` items to Slint via `impl Model<Data=T>`.
//! A user-supplied closure `F: Fn(&S) -> T` converts source items to Slint types
//! on demand.

use std::sync::{Arc, Mutex};

use slint::{Model, ModelNotify, ModelTracker};

pub(crate) struct WindowedModel<T, S, F>
where
    T: Clone + 'static,
    S: 'static,
    F: Fn(&S) -> T + 'static,
{
    inner: Mutex<WindowedModelInner<S>>,
    convert: F,
    notify: ModelNotify,
    _phantom: std::marker::PhantomData<T>,
}

struct WindowedModelInner<S> {
    data: Arc<Vec<S>>,
    window_start: usize,
    window_size: usize,
}

impl<T, S, F> WindowedModel<T, S, F>
where
    T: Clone + 'static,
    S: 'static,
    F: Fn(&S) -> T + 'static,
{
    /// Create a new windowed model.
    pub(crate) fn new(data: Arc<Vec<S>>, window_size: usize, convert: F) -> Self {
        Self {
            inner: Mutex::new(WindowedModelInner {
                data,
                window_start: 0,
                window_size,
            }),
            convert,
            notify: ModelNotify::default(),
            _phantom: std::marker::PhantomData,
        }
    }

    /// Replace the entire dataset. Resets window to start.
    /// Uses `notify.reset()` since the entire visible set changes.
    pub(crate) fn set_data(&self, data: Arc<Vec<S>>) {
        {
            let mut inner = self.inner.lock().unwrap();
            inner.data = data;
            inner.window_start = 0;
        }
        self.notify.reset();
    }

    /// Shift the window to a new start position.
    /// Uses `row_added`/`row_removed` for efficient incremental updates.
    /// Clamps to valid range.
    pub(crate) fn shift_to(&self, new_start: usize) {
        let (old_start, old_count, clamped, new_count) = {
            let mut inner = self.inner.lock().unwrap();
            let old_start = inner.window_start;
            let old_count = Self::visible_count_of(&inner);

            let max_start = inner.data.len().saturating_sub(1);
            let clamped = if inner.data.is_empty() {
                0
            } else {
                new_start.min(max_start)
            };

            if clamped == old_start {
                return;
            }

            inner.window_start = clamped;
            let new_count = Self::visible_count_of(&inner);
            (old_start, old_count, clamped, new_count)
        };

        if clamped > old_start {
            // Shifted forward — remove from front, add at back
            let removed = (clamped - old_start).min(old_count);
            self.notify.row_removed(0, removed);
            let kept = old_count.saturating_sub(removed);
            let added = new_count.saturating_sub(kept);
            if added > 0 {
                self.notify.row_added(new_count - added, added);
            }
        } else {
            // Shifted backward — add at front, remove from back
            let added = (old_start - clamped).min(new_count);
            let kept = new_count.saturating_sub(added);
            let removed = old_count.saturating_sub(kept);
            if removed > 0 {
                self.notify.row_removed(old_count - removed, removed);
            }
            self.notify.row_added(0, added);
        }
    }

    /// Total items in the full dataset (not just window).
    pub(crate) fn total_count(&self) -> usize {
        self.inner.lock().unwrap().data.len()
    }

    /// Current window start position.
    pub(crate) fn window_start(&self) -> usize {
        self.inner.lock().unwrap().window_start
    }

    fn visible_count_of(inner: &WindowedModelInner<S>) -> usize {
        let available = inner.data.len().saturating_sub(inner.window_start);
        available.min(inner.window_size)
    }
}

impl<T, S, F> Model for WindowedModel<T, S, F>
where
    T: Clone + 'static,
    S: 'static,
    F: Fn(&S) -> T + 'static,
{
    type Data = T;

    fn row_count(&self) -> usize {
        let inner = self.inner.lock().unwrap();
        Self::visible_count_of(&inner)
    }

    fn row_data(&self, row: usize) -> Option<T> {
        let inner = self.inner.lock().unwrap();
        let abs_index = inner.window_start + row;
        inner.data.get(abs_index).map(|item| (self.convert)(item))
    }

    fn model_tracker(&self) -> &dyn ModelTracker {
        &self.notify
    }
}

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use slint::Model;

    use super::WindowedModel;

    fn make_model(
        data: Vec<i32>,
        window_size: usize,
    ) -> WindowedModel<String, i32, impl Fn(&i32) -> String> {
        WindowedModel::new(Arc::new(data), window_size, |x: &i32| format!("item-{x}"))
    }

    #[test]
    fn test_new_model_row_count() {
        // Empty data returns 0
        let m = make_model(vec![], 10);
        assert_eq!(m.row_count(), 0);

        // Data shorter than window returns data.len()
        let m = make_model(vec![1, 2, 3], 10);
        assert_eq!(m.row_count(), 3);

        // Data longer than window returns window_size
        let m = make_model(vec![1, 2, 3, 4, 5], 3);
        assert_eq!(m.row_count(), 3);
    }

    #[test]
    fn test_row_data_returns_converted_items() {
        let m = make_model(vec![10, 20, 30], 5);
        assert_eq!(m.row_data(0), Some("item-10".to_string()));
        assert_eq!(m.row_data(1), Some("item-20".to_string()));
        assert_eq!(m.row_data(2), Some("item-30".to_string()));
        assert_eq!(m.row_data(3), None);
    }

    #[test]
    fn test_shift_forward_clamps() {
        let m = make_model(vec![0, 1, 2, 3, 4], 3);
        // Shifting past end should clamp — last valid start is data.len()-1 = 4
        m.shift_to(100);
        assert_eq!(m.window_start(), 4);
        // row_count should be 1 (only index 4 is available)
        assert_eq!(m.row_count(), 1);
    }

    #[test]
    fn test_shift_backward_clamps() {
        let m = make_model(vec![0, 1, 2, 3, 4], 3);
        m.shift_to(3);
        assert_eq!(m.window_start(), 3);
        // Now shift backward to 0 (no underflow)
        m.shift_to(0);
        assert_eq!(m.window_start(), 0);
        assert_eq!(m.row_count(), 3);
    }

    #[test]
    fn test_set_data_resets_window() {
        let m = make_model(vec![0, 1, 2, 3, 4], 3);
        m.shift_to(3);
        assert_eq!(m.window_start(), 3);

        m.set_data(Arc::new(vec![10, 11, 12, 13]));
        assert_eq!(m.window_start(), 0);
        assert_eq!(m.row_count(), 3);
        assert_eq!(m.total_count(), 4);
    }

    #[test]
    fn test_window_size_limits_row_count() {
        let data: Vec<i32> = (0..100).collect();
        let m = make_model(data, 20);
        assert_eq!(m.row_count(), 20);

        m.shift_to(85);
        // 100 - 85 = 15 available, window_size = 20 → min = 15
        assert_eq!(m.row_count(), 15);
    }

    #[test]
    fn test_total_count_reflects_full_dataset() {
        let data: Vec<i32> = (0..50).collect();
        let m = make_model(data, 10);
        assert_eq!(m.total_count(), 50);
        // total_count doesn't change after shift
        m.shift_to(40);
        assert_eq!(m.total_count(), 50);
        // row_count is windowed
        assert_eq!(m.row_count(), 10);
    }
}
