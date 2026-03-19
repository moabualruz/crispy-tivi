//! Scroll integration bridge — wraps `slint-crispy-vscroll`'s `VirtualScroller`
//! as a drop-in replacement for the hand-rolled `WindowedModel` + `ScrollController`
//! pair used in `event_bridge.rs`.
//!
//! # Design
//!
//! `ScrollBridge` holds a `VirtualScroller` and exposes the same surface that
//! `on_scroll_channels / on_scroll_movies / on_scroll_series` previously computed
//! inline: given a `delta` (positive = forward, negative = backward, 0 = reset),
//! return the new `window_start` so the caller can repopulate its `VecModel`.
//!
//! The bridge does NOT touch `slint::VecModel` directly — that remains the
//! responsibility of `event_bridge.rs` so the UI-thread ownership rules are
//! respected.
//!
//! # Migration path
//!
//! Phase 8 replaces the three copies of the window-shift arithmetic in
//! `event_bridge.rs` with a `ScrollBridge` per list.  The `.slint` screens are
//! not modified in this phase; the Slint `ScrollView.scrolled()` callback still
//! fires `scroll-channels(delta)` → Rust `on_scroll_channels(delta)`.

use slint_crispy_vscroll::{
    core::{NavDirection, QuickPreset},
    facade::{quick::from_quick_preset, scroller::VirtualScroller},
};

// ── Window sizes (replaces the constants in event_bridge.rs) ─────────────
/// Number of items rendered in the channel list viewport window.
pub(crate) const CHANNEL_WINDOW: usize = 15;
/// Number of items rendered in the VOD (movies/series) viewport window.
pub(crate) const VOD_WINDOW: usize = 45;

/// Multiplier: the VecModel holds `WINDOW * BUFFER_MULTIPLIER` items so Slint
/// never stalls waiting for data on fast flicks.
const BUFFER_MULTIPLIER: usize = 3;

// ── ScrollBridge ─────────────────────────────────────────────────────────

/// Result returned by [`ScrollBridge::apply_delta`].
pub(crate) struct ScrollShift {
    /// The new `window_start` index into the full dataset.
    pub new_start: usize,
    /// Whether the window actually moved (false → caller can skip repopulation).
    pub shifted: bool,
}

/// One per scrollable list (channels, movies, series).
///
/// Wraps a `VirtualScroller` and translates Slint's scroll-delta events into
/// window-start positions for VecModel management.
pub(crate) struct ScrollBridge {
    scroller: VirtualScroller,
    window_size: usize,
    total: usize,
}

impl ScrollBridge {
    /// Create a bridge with the given viewport window size.
    ///
    /// `window_size` should be one of [`CHANNEL_WINDOW`] or [`VOD_WINDOW`].
    pub(crate) fn new(window_size: usize) -> Self {
        let scroller = from_quick_preset(QuickPreset::TvVertical, 0);
        Self {
            scroller,
            window_size,
            total: 0,
        }
    }

    /// Update the total item count (called when new data arrives).
    pub(crate) fn set_total(&mut self, total: usize) {
        self.total = total;
        // Rebuild the scroller with the new item count (resets focus to 0).
        self.scroller = from_quick_preset(QuickPreset::TvVertical, total as i32);
    }

    /// Process a scroll delta and return the new window start.
    ///
    /// `delta > 0`  → scroll forward (down)
    /// `delta < 0`  → scroll backward (up)
    /// `delta == 0` → full reset (re-populate from current `window_start`)
    ///
    /// The returned `new_start` can be used directly as the slice start into
    /// `SharedData.channels / .movies / .series`.
    pub(crate) fn apply_delta(&mut self, delta: i32, current_start: usize) -> ScrollShift {
        if self.total == 0 {
            return ScrollShift {
                new_start: 0,
                shifted: false,
            };
        }

        if delta == 0 {
            // Reset: re-use the current window start unchanged; caller resets model.
            return ScrollShift {
                new_start: current_start,
                shifted: true, // always repopulate on reset
            };
        }

        // Advance the scroller's focus by |delta| steps in the appropriate direction.
        let steps = delta.unsigned_abs() as usize;
        let dir = if delta > 0 {
            NavDirection::Down
        } else {
            NavDirection::Up
        };
        for _ in 0..steps {
            self.scroller.navigate(dir);
        }

        let focused = self.scroller.focused_index();
        let new_start = self.window_start_for(focused);
        let shifted = new_start != current_start;

        ScrollShift { new_start, shifted }
    }

    /// Compute window start such that `focused` stays within the buffered window,
    /// centred where possible, clamped to valid dataset bounds.
    fn window_start_for(&self, focused: usize) -> usize {
        let buf = self.window_size * BUFFER_MULTIPLIER;
        // Keep focused at least `window_size / 2` from the start of the buffer.
        let half = self.window_size / 2;
        let ideal = focused.saturating_sub(half);
        let max_start = self.total.saturating_sub(buf);
        ideal.min(max_start)
    }

    /// The size of the VecModel window (items to show at once).
    pub(crate) fn buffer_size(&self) -> usize {
        self.window_size * BUFFER_MULTIPLIER
    }

    /// Currently focused item index within the full dataset.
    pub(crate) fn focused_index(&self) -> usize {
        self.scroller.focused_index()
    }

    /// Reset focus to zero (e.g. when navigating back to a screen).
    pub(crate) fn reset(&mut self) {
        self.scroller = from_quick_preset(QuickPreset::TvVertical, self.total as i32);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_bridge(window: usize, total: usize) -> ScrollBridge {
        let mut b = ScrollBridge::new(window);
        b.set_total(total);
        b
    }

    #[test]
    fn test_apply_delta_zero_returns_current_start_as_reset() {
        let mut b = make_bridge(CHANNEL_WINDOW, 100);
        let result = b.apply_delta(0, 5);
        assert_eq!(result.new_start, 5, "reset preserves current start");
        assert!(result.shifted, "reset always triggers repopulation");
    }

    #[test]
    fn test_apply_delta_forward_advances_window() {
        let mut b = make_bridge(CHANNEL_WINDOW, 200);
        // Scroll forward 20 items
        let result = b.apply_delta(20, 0);
        assert!(result.new_start > 0, "window should have moved forward");
    }

    #[test]
    fn test_apply_delta_backward_from_zero_stays_zero() {
        let mut b = make_bridge(CHANNEL_WINDOW, 100);
        let result = b.apply_delta(-5, 0);
        assert_eq!(result.new_start, 0, "cannot scroll before start");
    }

    #[test]
    fn test_apply_delta_empty_dataset_no_panic() {
        let mut b = make_bridge(CHANNEL_WINDOW, 0);
        let result = b.apply_delta(5, 0);
        assert_eq!(result.new_start, 0);
        assert!(!result.shifted);
    }

    #[test]
    fn test_set_total_resets_focus() {
        let mut b = make_bridge(CHANNEL_WINDOW, 100);
        b.apply_delta(50, 0);
        b.set_total(200);
        // After set_total, the scroller is rebuilt — focus is back at 0
        assert_eq!(b.focused_index(), 0);
    }

    #[test]
    fn test_buffer_size_is_window_times_multiplier() {
        let b = make_bridge(VOD_WINDOW, 500);
        assert_eq!(b.buffer_size(), VOD_WINDOW * 3);
    }

    #[test]
    fn test_window_start_clamped_to_max() {
        let mut b = make_bridge(CHANNEL_WINDOW, 20);
        // Try to scroll way past the end
        let result = b.apply_delta(1000, 0);
        // new_start must never exceed total - buffer (clamped to 0 when total < buffer)
        assert!(result.new_start < 20);
    }

    #[test]
    fn test_reset_brings_focus_back_to_zero() {
        let mut b = make_bridge(CHANNEL_WINDOW, 100);
        b.apply_delta(30, 0);
        b.reset();
        assert_eq!(b.focused_index(), 0);
    }
}
