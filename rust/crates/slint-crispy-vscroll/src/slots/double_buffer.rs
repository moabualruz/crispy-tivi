//! DoubleBufferPool — two half-pools, swap atomically (Task 6).

use std::ops::Range;

use crate::slots::descriptor::{RuntimeSlot, SlotState};
use crate::slots::recycler::compute_recycle;

// ---------------------------------------------------------------------------
// DoubleBufferPool
// ---------------------------------------------------------------------------

pub struct DoubleBufferPool {
    /// Two halves. active_idx selects which half is "live".
    halves: [Vec<RuntimeSlot>; 2],
    active_idx: usize,
    half_capacity: usize,
    staging_range: Range<usize>,
    active_range: Range<usize>,
}

impl DoubleBufferPool {
    pub fn new(half_capacity: usize) -> Self {
        let make_half = |offset: usize| {
            (0..half_capacity)
                .map(|i| RuntimeSlot::new(offset + i))
                .collect::<Vec<_>>()
        };
        Self {
            halves: [make_half(0), make_half(half_capacity)],
            active_idx: 0,
            half_capacity,
            staging_range: 0..0,
            active_range: 0..0,
        }
    }

    /// Returns the currently active (visible) slots.
    pub fn active_slots(&self) -> &[RuntimeSlot] {
        &self.halves[self.active_idx]
    }

    /// Returns the staging (back-buffer) slots.
    pub fn staging_slots(&self) -> &[RuntimeSlot] {
        &self.halves[1 - self.active_idx]
    }

    /// Prepare the back-buffer for a new range without disturbing active.
    pub fn prepare_staging(
        &mut self,
        range: Range<usize>,
        pos_fn: impl Fn(usize) -> (f32, f32, f32, f32),
    ) {
        let staging_idx = 1 - self.active_idx;
        // Free all staging slots.
        for s in self.halves[staging_idx].iter_mut() {
            s.free();
        }

        let diff = compute_recycle(self.staging_range.clone(), range.clone());
        // Assign newly needed slots in staging.
        for data_idx in &diff.to_assign {
            let (x, y, w, h) = pos_fn(*data_idx);
            if let Some(s) = self.halves[staging_idx]
                .iter_mut()
                .find(|s| s.state == SlotState::Free)
            {
                s.stage(*data_idx as i32, x, y, w, h);
            }
        }
        self.staging_range = range;
    }

    /// Mark all staging slots ready (visible) without swapping.
    pub fn commit_staging(&mut self) {
        let staging_idx = 1 - self.active_idx;
        for s in self.halves[staging_idx].iter_mut() {
            if s.state == SlotState::Staging {
                s.state = SlotState::Active;
                s.visible = true;
            }
        }
    }

    /// Swap active and staging halves.
    pub fn swap_buffers(&mut self) {
        self.active_idx = 1 - self.active_idx;
        self.active_range = self.staging_range.clone();
    }

    pub fn half_capacity(&self) -> usize {
        self.half_capacity
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    fn pos(i: usize) -> (f32, f32, f32, f32) {
        (0.0, i as f32 * 100.0, 320.0, 100.0)
    }

    #[test]
    fn test_active_unchanged_during_staging() {
        let mut pool = DoubleBufferPool::new(5);
        // Populate active half manually.
        for s in pool.halves[0].iter_mut().take(3) {
            s.assign(0, 0.0, 0.0, 100.0, 100.0);
        }
        pool.prepare_staging(0..3, pos);
        // Active half untouched.
        let active_count = pool
            .active_slots()
            .iter()
            .filter(|s| s.state == SlotState::Active)
            .count();
        assert_eq!(active_count, 3);
    }

    #[test]
    fn test_swap_reveals_staging() {
        let mut pool = DoubleBufferPool::new(5);
        pool.prepare_staging(0..3, pos);
        pool.commit_staging();
        pool.swap_buffers();
        let active_count = pool
            .active_slots()
            .iter()
            .filter(|s| s.state == SlotState::Active)
            .count();
        assert_eq!(active_count, 3);
        assert!(pool
            .active_slots()
            .iter()
            .filter(|s| s.state == SlotState::Active)
            .all(|s| s.visible));
    }

    #[test]
    fn test_half_capacity_returns_constructor_value() {
        // Covers half_capacity() lines 90-91
        let pool = DoubleBufferPool::new(7);
        assert_eq!(pool.half_capacity(), 7);
    }

    #[test]
    fn test_staging_slots_invisible_before_commit() {
        let mut pool = DoubleBufferPool::new(5);
        pool.prepare_staging(0..2, pos);
        let staging_visible = pool
            .staging_slots()
            .iter()
            .filter(|s| s.state == SlotState::Staging)
            .any(|s| s.visible);
        assert!(!staging_visible);
    }
}
