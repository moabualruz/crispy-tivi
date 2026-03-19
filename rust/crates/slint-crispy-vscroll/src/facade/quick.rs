//! Quick preset factory (Tasks 19–21).
//!
//! One-call setup for common scroller configurations.

use crate::core::config::{
    AnimationConfig, IntegrityMode, ItemSizing, PhysicsConfig, QuickPreset, ResizeStrategy,
    ScrollerConfig, ViewportFollow, ZPreset,
};
use crate::core::types::{Direction, SnapMode};

use super::scroller::{VirtualScroller, VirtualScrollerBuilder};

// ---------------------------------------------------------------------------
// Quick preset factory (Task 19)
// ---------------------------------------------------------------------------

/// Build a `VirtualScroller` from a `QuickPreset`.
pub fn from_quick_preset(preset: QuickPreset, item_count: i32) -> VirtualScroller {
    let config = config_for_preset(preset, item_count);
    VirtualScrollerBuilder::new(config).build()
}

fn config_for_preset(preset: QuickPreset, item_count: i32) -> ScrollerConfig {
    match preset {
        QuickPreset::TvVertical => tv_vertical_config(item_count),
        QuickPreset::TvHorizontal => tv_horizontal_config(item_count),
        QuickPreset::TvGrid => tv_grid_config(item_count),
        QuickPreset::MobileVertical => mobile_vertical_config(item_count),
        QuickPreset::MobileHorizontal => mobile_horizontal_config(item_count),
        QuickPreset::DesktopVertical => desktop_vertical_config(item_count),
        QuickPreset::DesktopGrid => desktop_grid_config(item_count),
    }
}

// ---------------------------------------------------------------------------
// TV presets (Task 20)
// ---------------------------------------------------------------------------

fn tv_vertical_config(item_count: i32) -> ScrollerConfig {
    ScrollerConfig {
        direction: Direction::Vertical,
        item_count,
        item_sizing: ItemSizing::Uniform {
            width: 320.0,
            height: 180.0,
        },
        snap_mode: SnapMode::StartAligned,
        resize_strategy: ResizeStrategy::Reflow,
        breakpoints: vec![],
        viewport_follow: ViewportFollow::ScrollAhead,
        integrity_mode: IntegrityMode::Sync,
        physics: tv_physics(),
        z_preset: Some(ZPreset::GoogleTv),
        z_custom: None,
        animation: AnimationConfig::default(),
        pool_buffer_ratio: 1.5,
        async_ack_timeout_ms: 500,
        scrollbar_visible: false,
        scrollbar_fade_ms: 1000,
    }
}

fn tv_horizontal_config(item_count: i32) -> ScrollerConfig {
    ScrollerConfig {
        direction: Direction::Horizontal,
        item_count,
        item_sizing: ItemSizing::Uniform {
            width: 240.0,
            height: 160.0,
        },
        snap_mode: SnapMode::StartAligned,
        resize_strategy: ResizeStrategy::Reflow,
        breakpoints: vec![],
        viewport_follow: ViewportFollow::ScrollAhead,
        integrity_mode: IntegrityMode::Sync,
        physics: tv_physics(),
        z_preset: Some(ZPreset::AppleTv),
        z_custom: None,
        animation: AnimationConfig::default(),
        pool_buffer_ratio: 1.5,
        async_ack_timeout_ms: 500,
        scrollbar_visible: false,
        scrollbar_fade_ms: 1000,
    }
}

fn tv_grid_config(item_count: i32) -> ScrollerConfig {
    ScrollerConfig {
        direction: Direction::Vertical,
        item_count,
        item_sizing: ItemSizing::FillWithRatio {
            columns: 4,
            aspect_ratio: 16.0 / 9.0,
            gap: 12.0,
        },
        snap_mode: SnapMode::None,
        resize_strategy: ResizeStrategy::Breakpoints,
        breakpoints: vec![],
        viewport_follow: ViewportFollow::ScrollAhead,
        integrity_mode: IntegrityMode::Sync,
        physics: tv_physics(),
        z_preset: Some(ZPreset::Flat),
        z_custom: None,
        animation: AnimationConfig::default(),
        pool_buffer_ratio: 2.0,
        async_ack_timeout_ms: 500,
        scrollbar_visible: false,
        scrollbar_fade_ms: 1000,
    }
}

// ---------------------------------------------------------------------------
// Mobile presets (Task 20)
// ---------------------------------------------------------------------------

fn mobile_vertical_config(item_count: i32) -> ScrollerConfig {
    ScrollerConfig {
        direction: Direction::Vertical,
        item_count,
        item_sizing: ItemSizing::Uniform {
            width: 360.0,
            height: 80.0,
        },
        snap_mode: SnapMode::None,
        resize_strategy: ResizeStrategy::Reflow,
        breakpoints: vec![],
        viewport_follow: ViewportFollow::ScrollAhead,
        integrity_mode: IntegrityMode::Sync,
        physics: mobile_physics(),
        z_preset: Some(ZPreset::Flat),
        z_custom: None,
        animation: AnimationConfig::default(),
        pool_buffer_ratio: 2.0,
        async_ack_timeout_ms: 500,
        scrollbar_visible: true,
        scrollbar_fade_ms: 800,
    }
}

fn mobile_horizontal_config(item_count: i32) -> ScrollerConfig {
    ScrollerConfig {
        direction: Direction::Horizontal,
        item_count,
        item_sizing: ItemSizing::Uniform {
            width: 160.0,
            height: 200.0,
        },
        snap_mode: SnapMode::Nearest,
        resize_strategy: ResizeStrategy::Reflow,
        breakpoints: vec![],
        viewport_follow: ViewportFollow::ScrollAhead,
        integrity_mode: IntegrityMode::Sync,
        physics: mobile_physics(),
        z_preset: Some(ZPreset::Flat),
        z_custom: None,
        animation: AnimationConfig::default(),
        pool_buffer_ratio: 1.5,
        async_ack_timeout_ms: 500,
        scrollbar_visible: false,
        scrollbar_fade_ms: 500,
    }
}

// ---------------------------------------------------------------------------
// Desktop presets (Task 21)
// ---------------------------------------------------------------------------

fn desktop_vertical_config(item_count: i32) -> ScrollerConfig {
    ScrollerConfig {
        direction: Direction::Vertical,
        item_count,
        item_sizing: ItemSizing::Uniform {
            width: 400.0,
            height: 60.0,
        },
        snap_mode: SnapMode::None,
        resize_strategy: ResizeStrategy::Reflow,
        breakpoints: vec![],
        viewport_follow: ViewportFollow::ScrollAhead,
        integrity_mode: IntegrityMode::Sync,
        physics: desktop_physics(),
        z_preset: Some(ZPreset::Flat),
        z_custom: None,
        animation: AnimationConfig::default(),
        pool_buffer_ratio: 2.0,
        async_ack_timeout_ms: 500,
        scrollbar_visible: true,
        scrollbar_fade_ms: 1200,
    }
}

fn desktop_grid_config(item_count: i32) -> ScrollerConfig {
    ScrollerConfig {
        direction: Direction::Vertical,
        item_count,
        item_sizing: ItemSizing::FillWithRatio {
            columns: 5,
            aspect_ratio: 2.0 / 3.0,
            gap: 16.0,
        },
        snap_mode: SnapMode::None,
        resize_strategy: ResizeStrategy::Breakpoints,
        breakpoints: vec![],
        viewport_follow: ViewportFollow::ScrollAhead,
        integrity_mode: IntegrityMode::Sync,
        physics: desktop_physics(),
        z_preset: Some(ZPreset::Flat),
        z_custom: None,
        animation: AnimationConfig::default(),
        pool_buffer_ratio: 2.0,
        async_ack_timeout_ms: 500,
        scrollbar_visible: true,
        scrollbar_fade_ms: 1200,
    }
}

// ---------------------------------------------------------------------------
// Physics helpers
// ---------------------------------------------------------------------------

fn tv_physics() -> PhysicsConfig {
    PhysicsConfig {
        friction: 0.97,
        dpad_scroll_duration_ms: 200,
        dpad_acceleration: true,
        ..PhysicsConfig::default()
    }
}

fn mobile_physics() -> PhysicsConfig {
    PhysicsConfig {
        friction: 0.95,
        velocity_cap: 4000.0,
        ..PhysicsConfig::default()
    }
}

fn desktop_physics() -> PhysicsConfig {
    PhysicsConfig {
        friction: 0.92,
        velocity_cap: 2000.0,
        dpad_acceleration: false,
        ..PhysicsConfig::default()
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tv_vertical_preset_builds() {
        let s = from_quick_preset(QuickPreset::TvVertical, 100);
        assert_eq!(s.focused_index(), 0);
        assert_eq!(s.scroll_position(), 0.0);
    }

    #[test]
    fn test_tv_horizontal_preset_builds() {
        let _ = from_quick_preset(QuickPreset::TvHorizontal, 50);
    }

    #[test]
    fn test_tv_grid_preset_builds() {
        let _ = from_quick_preset(QuickPreset::TvGrid, 200);
    }

    #[test]
    fn test_mobile_vertical_preset_builds() {
        let _ = from_quick_preset(QuickPreset::MobileVertical, 500);
    }

    #[test]
    fn test_mobile_horizontal_preset_builds() {
        let _ = from_quick_preset(QuickPreset::MobileHorizontal, 30);
    }

    #[test]
    fn test_desktop_vertical_preset_builds() {
        let _ = from_quick_preset(QuickPreset::DesktopVertical, 1000);
    }

    #[test]
    fn test_desktop_grid_preset_builds() {
        let _ = from_quick_preset(QuickPreset::DesktopGrid, 300);
    }

    #[test]
    fn test_tv_vertical_config_has_google_tv_preset() {
        let cfg = config_for_preset(QuickPreset::TvVertical, 10);
        assert_eq!(cfg.z_preset, Some(ZPreset::GoogleTv));
    }

    #[test]
    fn test_tv_horizontal_config_has_apple_tv_preset() {
        let cfg = config_for_preset(QuickPreset::TvHorizontal, 10);
        assert_eq!(cfg.z_preset, Some(ZPreset::AppleTv));
    }

    #[test]
    fn test_mobile_has_flat_preset() {
        let cfg = config_for_preset(QuickPreset::MobileVertical, 10);
        assert_eq!(cfg.z_preset, Some(ZPreset::Flat));
    }

    #[test]
    fn test_preset_scroller_ticks_without_panic() {
        let mut s = from_quick_preset(QuickPreset::TvVertical, 50);
        s.scroll_to(300.0);
        for _ in 0..5 {
            s.tick(16.0);
        }
        assert!(s.scroll_position() >= 0.0);
    }
}
