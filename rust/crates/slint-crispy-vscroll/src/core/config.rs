//! Configuration types for slint-crispy-vscroll.
//!
//! All config structs and enums used to configure the scroller,
//! physics, layout, slots, z-depth transforms, and animation.

use super::types::{Direction, SnapMode, Vec2};

// ---------------------------------------------------------------------------
// PhysicsState
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum PhysicsState {
    Idle,
    Dragging,
    DPadStep,
    Programmatic,
    Momentum,
    Snapping,
    RubberBand,
}

impl PhysicsState {
    /// Returns true if the physics engine is actively animating (any state except Idle).
    pub fn is_animating(self) -> bool {
        !matches!(self, Self::Idle)
    }

    /// Returns true if a touch-start should cancel this state.
    pub fn can_accept_touch_start(self) -> bool {
        matches!(self, Self::Momentum | Self::DPadStep | Self::Programmatic)
    }
}

// ---------------------------------------------------------------------------
// PhysicsConfig — Default = Apple TV preset
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct PhysicsConfig {
    // Momentum
    pub friction: f32,
    pub velocity_cap: f32,
    pub velocity_threshold: f32,
    // Snap
    pub snap_mode: SnapMode,
    pub snap_tension: f32,
    pub snap_damping: f32,
    pub snap_duration_ms: u32,
    // Rubber-band
    pub rubber_band_stiffness: f32,
    pub rubber_band_max_distance: f32,
    pub rubber_band_return_tension: f32,
    pub rubber_band_return_damping: f32,
    // Spring (general purpose)
    pub spring_mass: f32,
    pub spring_stiffness: f32,
    pub spring_damping: f32,
    // D-pad
    pub dpad_scroll_duration_ms: u32,
    pub dpad_repeat_delay_ms: u32,
    pub dpad_repeat_rate_ms: u32,
    pub dpad_acceleration: bool,
    pub dpad_acceleration_curve: f32,
    // Reduced motion
    pub reduced_motion: bool,
}

impl Default for PhysicsConfig {
    fn default() -> Self {
        Self {
            friction: 0.97,
            velocity_cap: 3000.0,
            velocity_threshold: 5.0,
            snap_mode: SnapMode::StartAligned,
            snap_tension: 300.0,
            snap_damping: 28.0,
            snap_duration_ms: 400,
            rubber_band_stiffness: 0.35,
            rubber_band_max_distance: 120.0,
            rubber_band_return_tension: 400.0,
            rubber_band_return_damping: 30.0,
            spring_mass: 1.0,
            spring_stiffness: 300.0,
            spring_damping: 28.0,
            dpad_scroll_duration_ms: 200,
            dpad_repeat_delay_ms: 400,
            dpad_repeat_rate_ms: 100,
            dpad_acceleration: true,
            dpad_acceleration_curve: 0.85,
            reduced_motion: false,
        }
    }
}

// ---------------------------------------------------------------------------
// LayoutRect
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy)]
pub struct LayoutRect {
    pub index: i32,
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
    pub row: i32,
    pub column: i32,
}

impl Default for LayoutRect {
    fn default() -> Self {
        Self {
            index: 0,
            x: 0.0,
            y: 0.0,
            width: 0.0,
            height: 0.0,
            row: 0,
            column: 0,
        }
    }
}

// ---------------------------------------------------------------------------
// ResizeStrategy
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ResizeStrategy {
    Reflow,
    Scale,
    Breakpoints,
}

// ---------------------------------------------------------------------------
// Breakpoint
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy)]
pub struct Breakpoint {
    pub min_size: f32,
    pub count: i32,
}

// ---------------------------------------------------------------------------
// ViewportFollow
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ViewportFollow {
    ScrollAhead,
    CenterLock,
    PageJump,
}

// ---------------------------------------------------------------------------
// ItemSizing
// ---------------------------------------------------------------------------

pub enum ItemSizing {
    Uniform {
        width: f32,
        height: f32,
    },
    UniformWidthWithRatio {
        width: f32,
        aspect_ratio: f32,
    },
    UniformHeightWithRatio {
        height: f32,
        aspect_ratio: f32,
    },
    FillWithRatio {
        columns: i32,
        aspect_ratio: f32,
        gap: f32,
    },
    Variable {
        get_size: Box<dyn Fn(i32) -> (f32, f32) + Send + Sync>,
    },
}

impl std::fmt::Debug for ItemSizing {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Uniform { width, height } => f
                .debug_struct("Uniform")
                .field("width", width)
                .field("height", height)
                .finish(),
            Self::UniformWidthWithRatio {
                width,
                aspect_ratio,
            } => f
                .debug_struct("UniformWidthWithRatio")
                .field("width", width)
                .field("aspect_ratio", aspect_ratio)
                .finish(),
            Self::UniformHeightWithRatio {
                height,
                aspect_ratio,
            } => f
                .debug_struct("UniformHeightWithRatio")
                .field("height", height)
                .field("aspect_ratio", aspect_ratio)
                .finish(),
            Self::FillWithRatio {
                columns,
                aspect_ratio,
                gap,
            } => f
                .debug_struct("FillWithRatio")
                .field("columns", columns)
                .field("aspect_ratio", aspect_ratio)
                .field("gap", gap)
                .finish(),
            Self::Variable { .. } => f.debug_struct("Variable").finish_non_exhaustive(),
        }
    }
}

impl Clone for ItemSizing {
    fn clone(&self) -> Self {
        match self {
            Self::Uniform { width, height } => Self::Uniform {
                width: *width,
                height: *height,
            },
            Self::UniformWidthWithRatio {
                width,
                aspect_ratio,
            } => Self::UniformWidthWithRatio {
                width: *width,
                aspect_ratio: *aspect_ratio,
            },
            Self::UniformHeightWithRatio {
                height,
                aspect_ratio,
            } => Self::UniformHeightWithRatio {
                height: *height,
                aspect_ratio: *aspect_ratio,
            },
            Self::FillWithRatio {
                columns,
                aspect_ratio,
                gap,
            } => Self::FillWithRatio {
                columns: *columns,
                aspect_ratio: *aspect_ratio,
                gap: *gap,
            },
            // Variable closures are not Clone — callers must reconstruct
            Self::Variable { .. } => panic!("ItemSizing::Variable cannot be cloned"),
        }
    }
}

// ---------------------------------------------------------------------------
// SlotDescriptor
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct SlotDescriptor {
    pub slot_id: i32,
    pub index: i32,
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
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
    pub is_focused: bool,
    pub ready: bool,
}

impl Default for SlotDescriptor {
    fn default() -> Self {
        Self {
            slot_id: 0,
            index: 0,
            x: 0.0,
            y: 0.0,
            width: 0.0,
            height: 0.0,
            scale: 1.0,
            opacity: 1.0,
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
            ready: true,
        }
    }
}

// ---------------------------------------------------------------------------
// IntegrityMode
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum IntegrityMode {
    Sync,
    AsyncAck,
    DoubleBuffer,
    Auto,
}

// ---------------------------------------------------------------------------
// ZTransform
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy)]
pub struct ZTransform {
    pub scale: f32,
    pub opacity: f32,
    pub z_offset: f32,
    pub rotation_x: f32,
    pub rotation_y: f32,
    pub translate_x: f32,
    pub translate_y: f32,
    pub blur: f32,
    pub shadow_radius: f32,
    pub shadow_opacity: f32,
    pub border_width: f32,
    pub border_opacity: f32,
}

impl Default for ZTransform {
    fn default() -> Self {
        Self {
            scale: 1.0,
            opacity: 1.0,
            z_offset: 0.0,
            rotation_x: 0.0,
            rotation_y: 0.0,
            translate_x: 0.0,
            translate_y: 0.0,
            blur: 0.0,
            shadow_radius: 0.0,
            shadow_opacity: 0.0,
            border_width: 0.0,
            border_opacity: 0.0,
        }
    }
}

// ---------------------------------------------------------------------------
// ZTransformParams
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy)]
pub struct ZTransformParams {
    pub index: i32,
    pub focused_index: i32,
    pub distance_from_focus: f32,
    pub normalized_distance: f32,
    pub scroll_progress: f32,
    pub viewport_position: f32,
    pub is_focused: bool,
    pub pointer_position: Option<Vec2>,
    pub velocity: f32,
}

// ---------------------------------------------------------------------------
// ZTransformProvider trait
// ---------------------------------------------------------------------------

pub trait ZTransformProvider: Send + Sync {
    fn compute(&self, params: ZTransformParams) -> ZTransform;
}

// ---------------------------------------------------------------------------
// ZPreset
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ZPreset {
    AppleTv,
    Netflix,
    GoogleTv,
    Flat,
}

// ---------------------------------------------------------------------------
// AnimationTarget
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum AnimationTarget {
    SlintTransition,
    RustTick,
}

// ---------------------------------------------------------------------------
// EasingCurve
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum EasingCurve {
    Linear,
    EaseIn,
    EaseOut,
    EaseInOut,
    CubicBezier,
}

// ---------------------------------------------------------------------------
// AnimationConfig
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct AnimationConfig {
    pub target_fps: u32,
    pub frame_budget_ms: f32,
    pub slot_fade_in_ms: u32,
    pub focus_scale_ms: u32,
    pub dpad_easing: EasingCurve,
    pub reduced_motion: bool,
}

impl Default for AnimationConfig {
    fn default() -> Self {
        Self {
            target_fps: 60,
            frame_budget_ms: 8.0,
            slot_fade_in_ms: 150,
            focus_scale_ms: 200,
            dpad_easing: EasingCurve::EaseOut,
            reduced_motion: false,
        }
    }
}

// ---------------------------------------------------------------------------
// ScrollerConfig — no Default (direction + item_sizing are required)
// ---------------------------------------------------------------------------

pub struct ScrollerConfig {
    pub direction: Direction,
    pub item_count: i32,
    pub item_sizing: ItemSizing,
    pub snap_mode: SnapMode,
    pub resize_strategy: ResizeStrategy,
    pub breakpoints: Vec<Breakpoint>,
    pub viewport_follow: ViewportFollow,
    pub integrity_mode: IntegrityMode,
    pub physics: PhysicsConfig,
    pub z_preset: Option<ZPreset>,
    pub z_custom: Option<Box<dyn ZTransformProvider>>,
    pub animation: AnimationConfig,
    pub pool_buffer_ratio: f32,
    pub async_ack_timeout_ms: u32,
    pub scrollbar_visible: bool,
    pub scrollbar_fade_ms: u32,
}

impl std::fmt::Debug for ScrollerConfig {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ScrollerConfig")
            .field("direction", &self.direction)
            .field("item_count", &self.item_count)
            .field("item_sizing", &self.item_sizing)
            .field("snap_mode", &self.snap_mode)
            .field("resize_strategy", &self.resize_strategy)
            .field("viewport_follow", &self.viewport_follow)
            .field("integrity_mode", &self.integrity_mode)
            .field("physics", &self.physics)
            .field("z_preset", &self.z_preset)
            .field(
                "z_custom",
                &self.z_custom.as_ref().map(|_| "<ZTransformProvider>"),
            )
            .field("animation", &self.animation)
            .field("pool_buffer_ratio", &self.pool_buffer_ratio)
            .field("async_ack_timeout_ms", &self.async_ack_timeout_ms)
            .field("scrollbar_visible", &self.scrollbar_visible)
            .field("scrollbar_fade_ms", &self.scrollbar_fade_ms)
            .finish()
    }
}

// ---------------------------------------------------------------------------
// QuickPreset
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum QuickPreset {
    TvVertical,
    TvHorizontal,
    TvGrid,
    MobileVertical,
    MobileHorizontal,
    DesktopVertical,
    DesktopGrid,
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_physics_config_default_is_apple_tv_preset() {
        let cfg = PhysicsConfig::default();
        assert!((cfg.friction - 0.97).abs() < 0.001);
        assert_eq!(cfg.snap_mode, SnapMode::StartAligned);
        assert_eq!(cfg.dpad_scroll_duration_ms, 200);
        assert!(!cfg.reduced_motion);
        assert!(cfg.dpad_acceleration);
    }

    #[test]
    fn test_layout_rect_default_is_zero() {
        let r = LayoutRect::default();
        assert_eq!(r.x, 0.0);
        assert_eq!(r.y, 0.0);
        assert_eq!(r.width, 0.0);
        assert_eq!(r.height, 0.0);
        assert_eq!(r.index, 0);
    }

    #[test]
    fn test_slot_descriptor_default_ready_and_unit_scale() {
        let s = SlotDescriptor::default();
        assert!(s.ready);
        assert!((s.scale - 1.0).abs() < 0.001);
        assert!((s.opacity - 1.0).abs() < 0.001);
        assert!(!s.is_focused);
        assert_eq!(s.index, 0);
    }

    #[test]
    fn test_z_transform_default_is_identity() {
        let z = ZTransform::default();
        assert!((z.scale - 1.0).abs() < 0.001);
        assert!((z.opacity - 1.0).abs() < 0.001);
        assert_eq!(z.translate_x, 0.0);
        assert_eq!(z.rotation_x, 0.0);
        assert_eq!(z.shadow_radius, 0.0);
    }

    #[test]
    fn test_animation_config_default_60fps() {
        let cfg = AnimationConfig::default();
        assert_eq!(cfg.target_fps, 60);
        assert!((cfg.frame_budget_ms - 8.0).abs() < 0.001);
        assert!(!cfg.reduced_motion);
        assert_eq!(cfg.dpad_easing, EasingCurve::EaseOut);
    }

    #[test]
    fn test_item_sizing_variants() {
        let _ = ItemSizing::Uniform {
            width: 200.0,
            height: 300.0,
        };
        let _ = ItemSizing::UniformWidthWithRatio {
            width: 200.0,
            aspect_ratio: 16.0 / 9.0,
        };
        let _ = ItemSizing::FillWithRatio {
            columns: 4,
            aspect_ratio: 1.0,
            gap: 8.0,
        };
    }

    #[test]
    fn test_quick_preset_variants() {
        let _ = QuickPreset::TvVertical;
        let _ = QuickPreset::TvGrid;
        let _ = QuickPreset::MobileVertical;
        let _ = QuickPreset::DesktopGrid;
    }

    #[test]
    fn test_physics_state_variants() {
        let states = [
            PhysicsState::Idle,
            PhysicsState::Dragging,
            PhysicsState::DPadStep,
            PhysicsState::Programmatic,
            PhysicsState::Momentum,
            PhysicsState::Snapping,
            PhysicsState::RubberBand,
        ];
        assert_eq!(states.len(), 7);
    }

    #[test]
    fn test_integrity_mode_variants() {
        let _ = IntegrityMode::Sync;
        let _ = IntegrityMode::AsyncAck;
        let _ = IntegrityMode::DoubleBuffer;
        let _ = IntegrityMode::Auto;
    }

    #[test]
    fn test_physics_config_velocity_defaults() {
        let cfg = PhysicsConfig::default();
        assert!((cfg.velocity_cap - 3000.0).abs() < 0.001);
        assert!((cfg.velocity_threshold - 5.0).abs() < 0.001);
        assert!((cfg.rubber_band_stiffness - 0.35).abs() < 0.001);
        assert!((cfg.spring_mass - 1.0).abs() < 0.001);
        assert!((cfg.dpad_acceleration_curve - 0.85).abs() < 0.001);
    }

    #[test]
    fn test_z_transform_params_option_pointer() {
        let params = ZTransformParams {
            index: 0,
            focused_index: 0,
            distance_from_focus: 0.0,
            normalized_distance: 0.0,
            scroll_progress: 0.0,
            viewport_position: 0.0,
            is_focused: true,
            pointer_position: Some(Vec2::new(100.0, 200.0)),
            velocity: 0.0,
        };
        assert!(params.pointer_position.is_some());
        assert!(params.is_focused);
    }

    #[test]
    fn test_z_transform_provider_trait_object() {
        struct FlatProvider;
        impl ZTransformProvider for FlatProvider {
            fn compute(&self, _params: ZTransformParams) -> ZTransform {
                ZTransform::default()
            }
        }
        let provider: Box<dyn ZTransformProvider> = Box::new(FlatProvider);
        let result = provider.compute(ZTransformParams {
            index: 0,
            focused_index: 0,
            distance_from_focus: 0.0,
            normalized_distance: 0.0,
            scroll_progress: 0.0,
            viewport_position: 0.0,
            is_focused: false,
            pointer_position: None,
            velocity: 0.0,
        });
        assert!((result.scale - 1.0).abs() < 0.001);
    }

    #[test]
    fn test_resize_strategy_variants() {
        assert_ne!(ResizeStrategy::Reflow, ResizeStrategy::Scale);
        assert_ne!(ResizeStrategy::Scale, ResizeStrategy::Breakpoints);
    }

    #[test]
    fn test_viewport_follow_variants() {
        assert_ne!(ViewportFollow::ScrollAhead, ViewportFollow::CenterLock);
        assert_ne!(ViewportFollow::CenterLock, ViewportFollow::PageJump);
    }

    #[test]
    fn test_z_preset_variants() {
        let presets = [
            ZPreset::AppleTv,
            ZPreset::Netflix,
            ZPreset::GoogleTv,
            ZPreset::Flat,
        ];
        assert_eq!(presets.len(), 4);
    }

    #[test]
    fn test_easing_curve_variants() {
        let curves = [
            EasingCurve::Linear,
            EasingCurve::EaseIn,
            EasingCurve::EaseOut,
            EasingCurve::EaseInOut,
            EasingCurve::CubicBezier,
        ];
        assert_eq!(curves.len(), 5);
    }

    #[test]
    fn test_animation_target_variants() {
        assert_ne!(AnimationTarget::SlintTransition, AnimationTarget::RustTick);
    }

    #[test]
    fn test_breakpoint_fields() {
        let bp = Breakpoint {
            min_size: 768.0,
            count: 3,
        };
        assert!((bp.min_size - 768.0).abs() < 0.001);
        assert_eq!(bp.count, 3);
    }

    #[test]
    fn test_scroller_config_construction() {
        let cfg = ScrollerConfig {
            direction: Direction::Vertical,
            item_count: 100,
            item_sizing: ItemSizing::Uniform {
                width: 320.0,
                height: 180.0,
            },
            snap_mode: SnapMode::StartAligned,
            resize_strategy: ResizeStrategy::Reflow,
            breakpoints: vec![],
            viewport_follow: ViewportFollow::ScrollAhead,
            integrity_mode: IntegrityMode::Auto,
            physics: PhysicsConfig::default(),
            z_preset: None,
            z_custom: None,
            animation: AnimationConfig::default(),
            pool_buffer_ratio: 1.5,
            async_ack_timeout_ms: 500,
            scrollbar_visible: true,
            scrollbar_fade_ms: 1000,
        };
        assert_eq!(cfg.item_count, 100);
        assert!(cfg.scrollbar_visible);
        assert!((cfg.pool_buffer_ratio - 1.5).abs() < 0.001);
    }
}
