//! Bridge between Rust `RuntimeSlot` and the Slint `SlotDescriptorSlint` struct.
//!
//! # Design
//! `SlotDescriptorSlint` is a plain Rust struct — field names mirror the kebab-case
//! Slint struct exactly as the `slint::include_modules!()` macro would generate them
//! (snake_case in Rust, kebab-case in .slint).  Keeping it as a plain struct means
//! conversion logic is unit-testable without a Slint runtime.

use crate::slots::descriptor::RuntimeSlot;

// ---------------------------------------------------------------------------
// SlotDescriptorSlint
// ---------------------------------------------------------------------------

/// Rust representation of the `SlotDescriptorSlint` struct declared in
/// `ui/virtual-scroll-base.slint`.  All fields are `Copy`-friendly primitives
/// so the struct is cheap to clone into a VecModel.
#[derive(Debug, Clone, PartialEq, Default)]
pub struct SlotDescriptorSlint {
    pub slot_id: i32,
    pub index: i32, // dataset index, -1 = unassigned

    // Position
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,

    // Z-depth / visual transforms
    pub scale: f32,
    pub opacity: f32,
    pub rotation_x: f32,
    pub rotation_y: f32,
    pub translate_x: f32,
    pub translate_y: f32,
    pub z_offset: f32,
    pub shadow_radius: f32,
    pub shadow_opacity: f32,
    pub border_width: f32,
    pub border_opacity: f32,
    pub blur: f32,

    // State
    pub is_focused: bool,
    pub visible: bool,
    pub ready: bool,
}

// ---------------------------------------------------------------------------
// Conversion
// ---------------------------------------------------------------------------

/// Convert a `RuntimeSlot` to its Slint bridge representation.
///
/// The conversion is a pure field copy — no computation occurs.
/// Direction is always Rust → Slint; Slint is display-only.
pub fn to_slint_slot(slot: &RuntimeSlot) -> SlotDescriptorSlint {
    SlotDescriptorSlint {
        slot_id: slot.slot_id as i32,
        index: slot.data_index,
        x: slot.x,
        y: slot.y,
        width: slot.width,
        height: slot.height,
        // Visual transform defaults — z_depth system will override in Phase 5+
        scale: 1.0,
        opacity: if slot.visible { 1.0 } else { 0.0 },
        rotation_x: 0.0,
        rotation_y: 0.0,
        translate_x: 0.0,
        translate_y: 0.0,
        z_offset: 0.0,
        shadow_radius: 0.0,
        shadow_opacity: 0.0,
        border_width: 0.0,
        border_opacity: 0.0,
        blur: 0.0,
        is_focused: false,
        visible: slot.visible,
        ready: slot.visible, // ready when visible and assigned
    }
}

/// Convert a slice of `RuntimeSlot`s to a `Vec<SlotDescriptorSlint>` suitable
/// for pushing into a Slint `VecModel`.
pub fn to_slint_slots(slots: &[RuntimeSlot]) -> Vec<SlotDescriptorSlint> {
    slots.iter().map(to_slint_slot).collect()
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::slots::descriptor::RuntimeSlot;

    fn make_active(slot_id: usize, data_index: i32, x: f32, y: f32, w: f32, h: f32) -> RuntimeSlot {
        let mut s = RuntimeSlot::new(slot_id);
        s.assign(data_index, x, y, w, h);
        s
    }

    #[test]
    fn test_to_slint_slot_copies_position_fields() {
        let slot = make_active(3, 7, 10.0, 20.0, 300.0, 60.0);
        let s = to_slint_slot(&slot);
        assert_eq!(s.slot_id, 3);
        assert_eq!(s.index, 7);
        assert_eq!(s.x, 10.0);
        assert_eq!(s.y, 20.0);
        assert_eq!(s.width, 300.0);
        assert_eq!(s.height, 60.0);
    }

    #[test]
    fn test_to_slint_slot_active_is_visible_and_ready() {
        let slot = make_active(0, 0, 0.0, 0.0, 400.0, 80.0);
        let s = to_slint_slot(&slot);
        assert!(s.visible);
        assert!(s.ready);
        assert_eq!(s.opacity, 1.0);
        assert_eq!(s.scale, 1.0);
    }

    #[test]
    fn test_to_slint_slot_free_slot_not_visible() {
        let slot = RuntimeSlot::new(5);
        let s = to_slint_slot(&slot);
        assert!(!s.visible);
        assert!(!s.ready);
        assert_eq!(s.opacity, 0.0);
        assert_eq!(s.index, -1);
    }

    #[test]
    fn test_to_slint_slot_staged_slot_not_visible() {
        let mut slot = RuntimeSlot::new(2);
        slot.stage(4, 0.0, 160.0, 400.0, 80.0);
        let s = to_slint_slot(&slot);
        assert!(!s.visible);
        assert!(!s.ready);
    }

    #[test]
    fn test_to_slint_slots_batch_conversion() {
        let slots = vec![
            make_active(0, 0, 0.0, 0.0, 400.0, 80.0),
            make_active(1, 1, 0.0, 80.0, 400.0, 80.0),
            make_active(2, 2, 0.0, 160.0, 400.0, 80.0),
            RuntimeSlot::new(3),
            RuntimeSlot::new(4),
        ];
        let result = to_slint_slots(&slots);
        assert_eq!(result.len(), 5);
        assert_eq!(result[0].index, 0);
        assert_eq!(result[1].y, 80.0);
        assert_eq!(result[2].y, 160.0);
        assert!(!result[3].visible);
        assert!(!result[4].visible);
    }

    #[test]
    fn test_to_slint_slot_slot_id_preserved_after_reassign() {
        let mut slot = RuntimeSlot::new(42);
        slot.assign(10, 5.0, 5.0, 100.0, 50.0);
        slot.free();
        slot.assign(11, 10.0, 10.0, 100.0, 50.0);
        let s = to_slint_slot(&slot);
        assert_eq!(s.slot_id, 42);
        assert_eq!(s.index, 11);
    }

    #[test]
    fn test_visual_transform_defaults_are_identity() {
        let slot = make_active(0, 0, 0.0, 0.0, 100.0, 100.0);
        let s = to_slint_slot(&slot);
        assert_eq!(s.scale, 1.0);
        assert_eq!(s.rotation_x, 0.0);
        assert_eq!(s.rotation_y, 0.0);
        assert_eq!(s.translate_x, 0.0);
        assert_eq!(s.translate_y, 0.0);
        assert_eq!(s.z_offset, 0.0);
        assert_eq!(s.blur, 0.0);
    }
}
