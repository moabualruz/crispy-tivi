//! SlotPool — integrity-mode-aware pool of RuntimeSlots.

use std::ops::Range;

use crate::core::config::IntegrityMode;
use crate::slots::descriptor::{RuntimeSlot, SlotState};
use crate::slots::recycler::compute_recycle;

// ---------------------------------------------------------------------------
// SlotPool
// ---------------------------------------------------------------------------

pub struct SlotPool {
    slots: Vec<RuntimeSlot>,
    mode: IntegrityMode,
    /// Per-slot ack timeout accumulator (ms). Only used in AsyncAck mode.
    ack_timers: Vec<u64>,
    ack_timeout_ms: u64,
    current_range: Range<usize>,
}

impl SlotPool {
    pub fn new(capacity: usize, mode: IntegrityMode) -> Self {
        let slots = (0..capacity).map(RuntimeSlot::new).collect::<Vec<_>>();
        let ack_timers = vec![0u64; capacity];
        Self {
            slots,
            mode,
            ack_timers,
            ack_timeout_ms: 500,
            current_range: 0..0,
        }
    }

    pub fn capacity(&self) -> usize {
        self.slots.len()
    }

    pub fn slots(&self) -> &[RuntimeSlot] {
        &self.slots
    }

    /// Update visible range. `pos_fn(data_index) -> (x, y, width, height)`.
    pub fn update_visible_range(
        &mut self,
        new_range: Range<usize>,
        pos_fn: impl Fn(usize) -> (f32, f32, f32, f32),
    ) {
        let diff = compute_recycle(self.current_range.clone(), new_range.clone());

        // Free slots for indices leaving the view.
        for data_idx in &diff.to_free {
            if let Some(s) = self
                .slots
                .iter_mut()
                .find(|s| s.data_index == *data_idx as i32)
            {
                s.free();
            }
        }

        // Assign slots for newly visible indices.
        let mode = self.effective_mode();
        for data_idx in &diff.to_assign {
            let (x, y, w, h) = pos_fn(*data_idx);
            if let Some(s) = self.slots.iter_mut().find(|s| s.state == SlotState::Free) {
                match mode {
                    IntegrityMode::AsyncAck => {
                        let id = s.slot_id;
                        s.stage(*data_idx as i32, x, y, w, h);
                        self.ack_timers[id] = 0;
                    }
                    _ => {
                        s.assign(*data_idx as i32, x, y, w, h);
                    }
                }
            }
        }

        self.current_range = new_range;
    }

    // -----------------------------------------------------------------------
    // AsyncAck helpers (Task 5)
    // -----------------------------------------------------------------------

    /// Mark a Staging slot ready → Active + visible.
    pub fn mark_ready(&mut self, data_index: i32) {
        for s in self.slots.iter_mut() {
            if s.data_index == data_index && s.state == SlotState::Staging {
                s.state = SlotState::Active;
                s.visible = true;
                self.ack_timers[s.slot_id] = 0;
                return;
            }
        }
    }

    pub fn set_ack_timeout_ms(&mut self, ms: u64) {
        self.ack_timeout_ms = ms;
    }

    /// Advance staging-slot timers by `dt_ms`; force-activate those past timeout.
    pub fn tick_ack_timeouts(&mut self, dt_ms: u64) {
        let timeout = self.ack_timeout_ms;
        for s in self.slots.iter_mut() {
            if s.state == SlotState::Staging {
                let id = s.slot_id;
                self.ack_timers[id] += dt_ms;
                if self.ack_timers[id] >= timeout {
                    s.state = SlotState::Active;
                    s.visible = true;
                    self.ack_timers[id] = 0;
                }
            }
        }
    }

    // -----------------------------------------------------------------------
    // Resize (Task 8)
    // -----------------------------------------------------------------------

    /// Grow adds free slots; shrink removes free slots first.
    /// Never drops active slots — if `new_capacity` < active count, stays at active count.
    pub fn resize(&mut self, new_capacity: usize) {
        let current = self.slots.len();
        if new_capacity >= current {
            for id in current..new_capacity {
                self.slots.push(RuntimeSlot::new(id));
                self.ack_timers.push(0);
            }
        } else {
            let active_count = self
                .slots
                .iter()
                .filter(|s| s.state != SlotState::Free)
                .count();
            let target = new_capacity.max(active_count);
            // Remove free slots from the end until we reach target.
            let mut i = self.slots.len();
            while self.slots.len() > target && i > 0 {
                i -= 1;
                if self.slots[i].state == SlotState::Free {
                    self.slots.remove(i);
                    self.ack_timers.remove(i);
                }
            }
        }
    }

    // -----------------------------------------------------------------------
    // Private
    // -----------------------------------------------------------------------

    fn effective_mode(&self) -> IntegrityMode {
        match self.mode {
            IntegrityMode::Auto => IntegrityMode::Sync,
            other => other,
        }
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

    // --- Task 4: Sync mode ---

    #[test]
    fn test_sync_assigns_immediately_active() {
        let mut pool = SlotPool::new(5, IntegrityMode::Sync);
        pool.update_visible_range(0..3, pos);
        let active = pool
            .slots()
            .iter()
            .filter(|s| s.state == SlotState::Active)
            .count();
        assert_eq!(active, 3);
        assert!(pool
            .slots()
            .iter()
            .filter(|s| s.state == SlotState::Active)
            .all(|s| s.visible));
    }

    #[test]
    fn test_sync_frees_on_range_change() {
        let mut pool = SlotPool::new(5, IntegrityMode::Sync);
        pool.update_visible_range(0..3, pos);
        pool.update_visible_range(2..5, pos);
        let active = pool
            .slots()
            .iter()
            .filter(|s| s.state == SlotState::Active)
            .count();
        let free = pool
            .slots()
            .iter()
            .filter(|s| s.state == SlotState::Free)
            .count();
        assert_eq!(active, 3);
        assert_eq!(free, 2);
    }

    // --- Task 5: AsyncAck mode ---

    #[test]
    fn test_async_ack_starts_staging_not_visible() {
        let mut pool = SlotPool::new(5, IntegrityMode::AsyncAck);
        pool.update_visible_range(0..3, pos);
        let staging = pool
            .slots()
            .iter()
            .filter(|s| s.state == SlotState::Staging)
            .count();
        assert_eq!(staging, 3);
        assert!(pool
            .slots()
            .iter()
            .filter(|s| s.state == SlotState::Staging)
            .all(|s| !s.visible));
    }

    #[test]
    fn test_async_ack_mark_ready_activates() {
        let mut pool = SlotPool::new(5, IntegrityMode::AsyncAck);
        pool.update_visible_range(0..1, pos);
        pool.mark_ready(0);
        let s = pool.slots().iter().find(|s| s.data_index == 0).unwrap();
        assert_eq!(s.state, SlotState::Active);
        assert!(s.visible);
    }

    #[test]
    fn test_async_ack_unacked_not_visible() {
        let mut pool = SlotPool::new(5, IntegrityMode::AsyncAck);
        pool.update_visible_range(0..2, pos);
        pool.mark_ready(0);
        let s1 = pool.slots().iter().find(|s| s.data_index == 1).unwrap();
        assert!(!s1.visible);
        assert_eq!(s1.state, SlotState::Staging);
    }

    #[test]
    fn test_async_ack_timeout_forces_active() {
        let mut pool = SlotPool::new(5, IntegrityMode::AsyncAck);
        pool.set_ack_timeout_ms(100);
        pool.update_visible_range(0..1, pos);
        pool.tick_ack_timeouts(101);
        let s = pool.slots().iter().find(|s| s.data_index == 0).unwrap();
        assert_eq!(s.state, SlotState::Active);
        assert!(s.visible);
    }

    // --- Task 8: Resize ---

    #[test]
    fn test_resize_grow_adds_free_slots() {
        let mut pool = SlotPool::new(3, IntegrityMode::Sync);
        pool.resize(6);
        assert_eq!(pool.capacity(), 6);
        let free = pool
            .slots()
            .iter()
            .filter(|s| s.state == SlotState::Free)
            .count();
        assert_eq!(free, 6);
    }

    #[test]
    fn test_resize_shrink_removes_free() {
        let mut pool = SlotPool::new(6, IntegrityMode::Sync);
        pool.resize(3);
        assert_eq!(pool.capacity(), 3);
    }

    #[test]
    fn test_double_buffer_mode_assigns_immediately() {
        // Covers effective_mode line 157: `other => other` for DoubleBuffer mode
        let mut pool = SlotPool::new(5, IntegrityMode::DoubleBuffer);
        pool.update_visible_range(0..2, pos);
        // DoubleBuffer maps to itself (non-Auto) → treated as Sync (active)
        let active = pool
            .slots()
            .iter()
            .filter(|s| s.state == SlotState::Active)
            .count();
        assert_eq!(active, 2);
    }

    #[test]
    fn test_auto_mode_assigns_immediately_like_sync() {
        // Covers pool.rs line 157: IntegrityMode::Auto => IntegrityMode::Sync in effective_mode()
        let mut pool = SlotPool::new(5, IntegrityMode::Auto);
        pool.update_visible_range(0..3, pos);
        // Auto maps to Sync → slots should be Active immediately
        let active = pool
            .slots()
            .iter()
            .filter(|s| s.state == SlotState::Active)
            .count();
        assert_eq!(active, 3);
    }

    #[test]
    fn test_resize_shrink_below_active_is_noop() {
        let mut pool = SlotPool::new(5, IntegrityMode::Sync);
        pool.update_visible_range(0..4, pos);
        pool.resize(2); // 4 active — can't shrink below 4
        assert!(pool.capacity() >= 4);
        let active = pool
            .slots()
            .iter()
            .filter(|s| s.state == SlotState::Active)
            .count();
        assert_eq!(active, 4);
    }
}
