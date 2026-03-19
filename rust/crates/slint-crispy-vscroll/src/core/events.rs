//! Scroll and raw input event types for slint-crispy-vscroll.

use super::types::{Edge, NavDirection, ScrollPhase, ScrollSource, Vec2, Vec3};

// ---------------------------------------------------------------------------
// ScrollEvent
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct ScrollEvent {
    pub original_delta: Vec2,
    pub consumed_delta: Vec2,
    pub remaining_delta: Vec2,
    pub velocity: Vec2,
    pub acceleration: Vec2,
    pub phase: ScrollPhase,
    pub source: ScrollSource,
    pub timestamp_ms: u64,
    pub frame_number: u64,
    pub child_edge: Edge,
    pub scroll_position: Vec2,
    pub content_bounds: Vec2,
    pub viewport_size: Vec2,
    pub focused_index: i32,
    pub total_items: i32,
    pub raw_event: Option<RawInputEvent>,
}

impl Default for ScrollEvent {
    fn default() -> Self {
        Self {
            original_delta: Vec2::ZERO,
            consumed_delta: Vec2::ZERO,
            remaining_delta: Vec2::ZERO,
            velocity: Vec2::ZERO,
            acceleration: Vec2::ZERO,
            phase: ScrollPhase::Started,
            source: ScrollSource::Programmatic,
            timestamp_ms: 0,
            frame_number: 0,
            child_edge: Edge::None,
            scroll_position: Vec2::ZERO,
            content_bounds: Vec2::ZERO,
            viewport_size: Vec2::ZERO,
            focused_index: -1,
            total_items: 0,
            raw_event: None,
        }
    }
}

// ---------------------------------------------------------------------------
// RawInputEvent
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub enum RawInputEvent {
    Pointer(PointerData),
    Wheel(WheelData),
    Key(KeyData),
    GamepadAxis(GamepadAxisData),
    GamepadTrigger(GamepadTriggerData),
}

// ---------------------------------------------------------------------------
// PointerData
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct PointerData {
    pub pointer_id: u32,
    pub position: Vec2,
    pub screen_position: Vec2,
    pub pressure: f32,
    pub tilt: Vec2,
    pub contact_size: Vec2,
    pub pointer_type: PointerType,
    pub button: PointerButton,
    pub coalesced_count: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum PointerType {
    Touch,
    Pen,
    Mouse,
    Trackpad,
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum PointerButton {
    None,
    Primary,
    Secondary,
    Middle,
    Back,
    Forward,
}

// ---------------------------------------------------------------------------
// WheelData
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct WheelData {
    pub delta: Vec3,
    pub delta_mode: WheelMode,
    pub is_inverted: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum WheelMode {
    Pixel,
    Line,
    Page,
}

// ---------------------------------------------------------------------------
// KeyData
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct KeyData {
    pub key_code: KeyCode,
    pub modifiers: Modifiers,
    pub repeat_count: u32,
    pub is_repeat: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct KeyCode(pub u32);

impl KeyCode {
    pub const ARROW_UP: Self = Self(0x0001);
    pub const ARROW_DOWN: Self = Self(0x0002);
    pub const ARROW_LEFT: Self = Self(0x0003);
    pub const ARROW_RIGHT: Self = Self(0x0004);
    pub const PAGE_UP: Self = Self(0x0005);
    pub const PAGE_DOWN: Self = Self(0x0006);
    pub const HOME: Self = Self(0x0007);
    pub const END: Self = Self(0x0008);
    pub const ENTER: Self = Self(0x0009);
    pub const ESCAPE: Self = Self(0x000A);
    pub const TAB: Self = Self(0x000B);
    pub const SPACE: Self = Self(0x000C);

    pub fn is_nav(&self) -> bool {
        matches!(self.0, 0x0001..=0x0004)
    }

    pub fn to_nav_direction(&self) -> Option<NavDirection> {
        match *self {
            Self::ARROW_UP => Some(NavDirection::Up),
            Self::ARROW_DOWN => Some(NavDirection::Down),
            Self::ARROW_LEFT => Some(NavDirection::Left),
            Self::ARROW_RIGHT => Some(NavDirection::Right),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, Copy, Default)]
pub struct Modifiers {
    pub shift: bool,
    pub ctrl: bool,
    pub alt: bool,
    pub meta: bool,
}

// ---------------------------------------------------------------------------
// GamepadAxisData
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct GamepadAxisData {
    pub stick: GamepadStick,
    pub axis: Vec2,
    pub deadzone_applied: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum GamepadStick {
    Left,
    Right,
}

// ---------------------------------------------------------------------------
// GamepadTriggerData
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct GamepadTriggerData {
    pub trigger: GamepadTriggerSide,
    pub value: f32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum GamepadTriggerSide {
    L2,
    R2,
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_scroll_event_default_has_zero_deltas() {
        let e = ScrollEvent::default();
        assert_eq!(e.original_delta, Vec2::ZERO);
        assert_eq!(e.consumed_delta, Vec2::ZERO);
        assert_eq!(e.remaining_delta, Vec2::ZERO);
    }

    #[test]
    fn test_scroll_event_default_focused_index_is_negative_one() {
        let e = ScrollEvent::default();
        assert_eq!(e.focused_index, -1);
    }

    #[test]
    fn test_scroll_event_remaining_equals_original_minus_consumed() {
        let e = ScrollEvent {
            original_delta: Vec2::new(30.0, 15.0),
            consumed_delta: Vec2::new(30.0, 0.0),
            remaining_delta: Vec2::new(0.0, 15.0),
            ..ScrollEvent::default()
        };
        let expected = e.original_delta - e.consumed_delta;
        assert_eq!(e.remaining_delta.x, expected.x);
        assert_eq!(e.remaining_delta.y, expected.y);
    }

    #[test]
    fn test_key_code_is_nav() {
        assert!(KeyCode::ARROW_UP.is_nav());
        assert!(KeyCode::ARROW_DOWN.is_nav());
        assert!(KeyCode::ARROW_LEFT.is_nav());
        assert!(KeyCode::ARROW_RIGHT.is_nav());
        assert!(!KeyCode::ENTER.is_nav());
        assert!(!KeyCode::SPACE.is_nav());
    }

    #[test]
    fn test_key_code_to_nav_direction() {
        assert_eq!(KeyCode::ARROW_UP.to_nav_direction(), Some(NavDirection::Up));
        assert_eq!(
            KeyCode::ARROW_DOWN.to_nav_direction(),
            Some(NavDirection::Down)
        );
        assert_eq!(KeyCode::ENTER.to_nav_direction(), None);
    }

    #[test]
    fn test_modifiers_default_all_false() {
        let m = Modifiers::default();
        assert!(!m.shift);
        assert!(!m.ctrl);
        assert!(!m.alt);
        assert!(!m.meta);
    }

    #[test]
    fn test_raw_input_event_variants() {
        let _ = RawInputEvent::Pointer(PointerData {
            pointer_id: 0,
            position: Vec2::ZERO,
            screen_position: Vec2::ZERO,
            pressure: 1.0,
            tilt: Vec2::ZERO,
            contact_size: Vec2::ZERO,
            pointer_type: PointerType::Mouse,
            button: PointerButton::Primary,
            coalesced_count: 0,
        });
        let _ = RawInputEvent::Wheel(WheelData {
            delta: Vec3::default(),
            delta_mode: WheelMode::Pixel,
            is_inverted: false,
        });
        let _ = RawInputEvent::Key(KeyData {
            key_code: KeyCode::ENTER,
            modifiers: Modifiers::default(),
            repeat_count: 0,
            is_repeat: false,
        });
    }

    #[test]
    fn test_scroll_event_default_phase_is_started() {
        let e = ScrollEvent::default();
        assert!(matches!(e.phase, ScrollPhase::Started));
    }

    #[test]
    fn test_scroll_event_default_source_is_programmatic() {
        let e = ScrollEvent::default();
        assert!(matches!(e.source, ScrollSource::Programmatic));
    }

    #[test]
    fn test_scroll_event_default_child_edge_is_none() {
        let e = ScrollEvent::default();
        assert!(matches!(e.child_edge, Edge::None));
    }

    #[test]
    fn test_scroll_event_default_raw_event_is_none() {
        let e = ScrollEvent::default();
        assert!(e.raw_event.is_none());
    }

    #[test]
    fn test_key_code_page_keys_not_nav() {
        assert!(!KeyCode::PAGE_UP.is_nav());
        assert!(!KeyCode::PAGE_DOWN.is_nav());
        assert!(!KeyCode::HOME.is_nav());
        assert!(!KeyCode::END.is_nav());
    }

    #[test]
    fn test_key_code_nav_direction_all_arrows() {
        assert_eq!(
            KeyCode::ARROW_LEFT.to_nav_direction(),
            Some(NavDirection::Left)
        );
        assert_eq!(
            KeyCode::ARROW_RIGHT.to_nav_direction(),
            Some(NavDirection::Right)
        );
        assert_eq!(KeyCode::PAGE_UP.to_nav_direction(), None);
    }

    #[test]
    fn test_gamepad_axis_data_construction() {
        let d = GamepadAxisData {
            stick: GamepadStick::Left,
            axis: Vec2::new(0.5, -0.3),
            deadzone_applied: true,
        };
        assert_eq!(d.stick, GamepadStick::Left);
        assert!(d.deadzone_applied);
    }

    #[test]
    fn test_gamepad_trigger_data_construction() {
        let d = GamepadTriggerData {
            trigger: GamepadTriggerSide::R2,
            value: 0.75,
        };
        assert_eq!(d.trigger, GamepadTriggerSide::R2);
        assert!((d.value - 0.75).abs() < f32::EPSILON);
    }
}
