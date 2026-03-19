//! Runtime slot state — lifecycle management for individual slots in the pool.

// ---------------------------------------------------------------------------
// SlotState
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Default)]
pub enum SlotState {
    #[default]
    Free,
    Active,
    Staging,
}

impl SlotState {
    #[inline]
    pub fn is_active(self) -> bool {
        self == SlotState::Active
    }
}

// ---------------------------------------------------------------------------
// RuntimeSlot
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct RuntimeSlot {
    pub slot_id: usize,
    pub state: SlotState,
    pub data_index: i32,
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
    pub visible: bool,
}

impl RuntimeSlot {
    pub fn new(slot_id: usize) -> Self {
        Self {
            slot_id,
            state: SlotState::Free,
            data_index: -1,
            x: 0.0,
            y: 0.0,
            width: 0.0,
            height: 0.0,
            visible: false,
        }
    }

    pub fn assign(&mut self, index: i32, x: f32, y: f32, w: f32, h: f32) {
        self.data_index = index;
        self.x = x;
        self.y = y;
        self.width = w;
        self.height = h;
        self.state = SlotState::Active;
        self.visible = true;
    }

    pub fn free(&mut self) {
        self.state = SlotState::Free;
        self.visible = false;
        self.data_index = -1;
    }

    pub fn stage(&mut self, index: i32, x: f32, y: f32, w: f32, h: f32) {
        self.data_index = index;
        self.x = x;
        self.y = y;
        self.width = w;
        self.height = h;
        self.state = SlotState::Staging;
        self.visible = false;
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_slot_default_state_is_free() {
        let s = RuntimeSlot::new(0);
        assert_eq!(s.state, SlotState::Free);
        assert!(!s.visible);
        assert_eq!(s.data_index, -1);
    }

    #[test]
    fn test_slot_state_is_active_only_for_active() {
        assert!(SlotState::Active.is_active());
        assert!(!SlotState::Free.is_active());
        assert!(!SlotState::Staging.is_active());
    }

    #[test]
    fn test_assign_sets_active_and_visible() {
        let mut s = RuntimeSlot::new(3);
        s.assign(10, 0.0, 100.0, 320.0, 180.0);
        assert_eq!(s.state, SlotState::Active);
        assert!(s.visible);
        assert_eq!(s.data_index, 10);
        assert!((s.y - 100.0).abs() < 0.001);
        assert!((s.width - 320.0).abs() < 0.001);
    }

    #[test]
    fn test_free_resets_slot() {
        let mut s = RuntimeSlot::new(1);
        s.assign(5, 10.0, 20.0, 100.0, 50.0);
        s.free();
        assert_eq!(s.state, SlotState::Free);
        assert!(!s.visible);
        assert_eq!(s.data_index, -1);
    }

    #[test]
    fn test_stage_sets_staging_not_visible() {
        let mut s = RuntimeSlot::new(2);
        s.stage(7, 0.0, 200.0, 320.0, 180.0);
        assert_eq!(s.state, SlotState::Staging);
        assert!(!s.visible);
        assert_eq!(s.data_index, 7);
    }

    #[test]
    fn test_slot_id_preserved() {
        let mut s = RuntimeSlot::new(42);
        s.assign(0, 0.0, 0.0, 1.0, 1.0);
        assert_eq!(s.slot_id, 42);
        s.free();
        assert_eq!(s.slot_id, 42);
    }
}
