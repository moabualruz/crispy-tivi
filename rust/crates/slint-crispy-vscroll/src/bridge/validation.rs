//! Runtime validation for the Slint bridge.
//!
//! These checks fire on the first tick to catch misconfiguration early —
//! the engine panics with a descriptive message rather than silently
//! rendering nothing.

// ---------------------------------------------------------------------------
// ValidationContext
// ---------------------------------------------------------------------------

/// Snapshot of bridge properties read from the Slint component on first tick.
#[derive(Debug, Clone)]
pub struct ValidationContext {
    /// Value of the `item-count` property. `-1` means unset (sentinel).
    pub item_count: i32,
    /// Value of the `direction` property. `-1` means unset (sentinel).
    pub direction: i32,
    /// Current length of the `slot-model` VecModel.
    pub slot_model_len: usize,
}

// ---------------------------------------------------------------------------
// Validators
// ---------------------------------------------------------------------------

/// Validate required properties on the first render tick.
///
/// # Panics
/// - `item-count` is still `-1` (never set from Rust)
/// - `direction` is still `-1` (never set from Rust)
/// - `slot-model` is empty while `item-count > 0` (VecModel not wired)
pub fn validate_on_first_tick(ctx: &ValidationContext) {
    if ctx.item_count == -1 {
        panic!(
            "slint-crispy-vscroll: 'item-count' is still -1 on first tick. \
             Set VirtualScrollBase.item-count from Rust before the first render."
        );
    }

    if ctx.direction == -1 {
        panic!(
            "slint-crispy-vscroll: 'direction' is unset on first tick. \
             Set VirtualScrollBase.direction to 0 (Vertical) or 1 (Horizontal)."
        );
    }

    if ctx.item_count > 0 && ctx.slot_model_len == 0 {
        panic!(
            "slint-crispy-vscroll: slot-model is empty but item-count is {}. \
             Wire the VecModel to VirtualScrollBase.slot-model before the first render.",
            ctx.item_count
        );
    }
}

/// Validate that the pool has enough slots to cover the viewport.
///
/// # Parameters
/// - `pool_capacity`: total number of slots allocated in the pool
/// - `minimum_slots`: minimum slots required to fill the viewport (typically
///   `ceil(viewport_size / item_size) + buffer`)
///
/// # Panics
/// - `pool_capacity < minimum_slots`
pub fn validate_pool_size(pool_capacity: usize, minimum_slots: usize) {
    if pool_capacity < minimum_slots {
        panic!(
            "slint-crispy-vscroll: pool capacity {} is too small for viewport — \
             need at least {} slots. Increase pool_buffer_ratio in ScrollerConfig.",
            pool_capacity, minimum_slots
        );
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    // ── validate_on_first_tick ──────────────────────────────────────────────

    #[test]
    #[should_panic(expected = "slint-crispy-vscroll: 'item-count' is still -1")]
    fn test_validate_panics_when_item_count_unset() {
        validate_on_first_tick(&ValidationContext {
            item_count: -1,
            direction: 0,
            slot_model_len: 5,
        });
    }

    #[test]
    #[should_panic(expected = "slint-crispy-vscroll: 'direction' is unset")]
    fn test_validate_panics_when_direction_unset() {
        validate_on_first_tick(&ValidationContext {
            item_count: 10,
            direction: -1,
            slot_model_len: 5,
        });
    }

    #[test]
    #[should_panic(expected = "slint-crispy-vscroll: slot-model is empty but item-count")]
    fn test_validate_panics_when_slot_model_empty_with_items() {
        validate_on_first_tick(&ValidationContext {
            item_count: 10,
            direction: 0,
            slot_model_len: 0,
        });
    }

    #[test]
    fn test_validate_passes_when_all_set_correctly() {
        // Must NOT panic
        validate_on_first_tick(&ValidationContext {
            item_count: 10,
            direction: 0,
            slot_model_len: 5,
        });
    }

    #[test]
    fn test_validate_passes_when_item_count_zero_and_slot_model_empty() {
        // Zero items is valid — nothing to display
        validate_on_first_tick(&ValidationContext {
            item_count: 0,
            direction: 1,
            slot_model_len: 0,
        });
    }

    // ── validate_pool_size ─────────────────────────────────────────────────

    #[test]
    #[should_panic(expected = "slint-crispy-vscroll: pool capacity")]
    fn test_validate_panics_when_pool_too_small_for_viewport() {
        validate_pool_size(3, 8);
    }

    #[test]
    fn test_validate_pool_passes_when_exactly_minimum() {
        // Must NOT panic
        validate_pool_size(8, 8);
    }

    #[test]
    fn test_validate_pool_passes_when_larger_than_minimum() {
        // Must NOT panic
        validate_pool_size(12, 8);
    }

    #[test]
    #[should_panic(expected = "slint-crispy-vscroll: pool capacity")]
    fn test_validate_pool_panics_when_zero_capacity() {
        validate_pool_size(0, 1);
    }
}
