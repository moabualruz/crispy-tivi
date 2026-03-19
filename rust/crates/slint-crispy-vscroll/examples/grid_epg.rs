//! Grid EPG example — breakpoint resize with 3 → 2 → 1 column reflow.
//!
//! Demonstrates:
//! - `GridLayout` (`grid_position`, `grid_visible_range`)
//! - `GridFocusNavigator` with column-preserving D-pad navigation
//! - `BreakpointState` switching columns at 900 / 600 px boundaries with hysteresis
//!
//! Run with:
//! ```bash
//! cargo run --example grid_epg --features tv-app
//! ```

use slint_crispy_vscroll::{
    core::{
        config::{
            AnimationConfig, IntegrityMode, ItemSizing, PhysicsConfig, ResizeStrategy,
            ScrollerConfig, ViewportFollow,
        },
        types::{Direction, NavDirection, SnapMode},
    },
    facade::scroller::VirtualScrollerBuilder,
};

#[cfg(feature = "grid")]
use slint_crispy_vscroll::layout::{
    grid::{grid_position, grid_visible_range},
    grid_focus::GridFocusNavigator,
};

#[cfg(feature = "resize-breakpoints")]
use slint_crispy_vscroll::layout::resize::breakpoints::{Breakpoint, BreakpointState};

fn main() {
    // --- Build scroller ---
    let mut scroller = VirtualScrollerBuilder::new(ScrollerConfig {
        direction: Direction::Vertical,
        item_count: 100,
        item_sizing: ItemSizing::Uniform {
            width: 320.0,
            height: 180.0,
        },
        snap_mode: SnapMode::None,
        resize_strategy: ResizeStrategy::Reflow,
        breakpoints: vec![],
        viewport_follow: ViewportFollow::ScrollAhead,
        integrity_mode: IntegrityMode::Sync,
        physics: PhysicsConfig::default(),
        z_preset: None,
        z_custom: None,
        animation: AnimationConfig::default(),
        pool_buffer_ratio: 1.5,
        async_ack_timeout_ms: 500,
        scrollbar_visible: true,
        scrollbar_fade_ms: 1000,
    })
    .build();

    // --- Grid layout: 3 columns at full desktop width ---
    #[cfg(feature = "grid")]
    {
        let columns = 3_usize;
        let item_w = 320.0_f32;
        let item_h = 180.0_f32;

        // Item 7 → row 2, col 1
        let (x, y) = grid_position(7, columns, item_w, item_h, 0.0);
        println!("Item 7 position: ({x:.0}, {y:.0})");

        // Visible range at scroll=0, 540px tall viewport, 1 row buffer
        let range = grid_visible_range(0.0, item_h, 540.0, columns, 100, 1);
        println!("Visible range: {range:?}");

        // D-pad Down from index 7 preserves column
        let nav = GridFocusNavigator::new(columns, 100);
        let next = nav.next_focus(7, NavDirection::Down);
        println!("Down from 7 → {next}");
    }

    // --- Breakpoint resize simulation ---
    #[cfg(feature = "resize-breakpoints")]
    {
        let bps = vec![
            Breakpoint {
                min_width: 0.0,
                columns: 1,
            },
            Breakpoint {
                min_width: 600.0,
                columns: 2,
            },
            Breakpoint {
                min_width: 900.0,
                columns: 3,
            },
        ];
        let mut state = BreakpointState::new(3, 50.0);

        let r1280 = state.apply_resize(1280.0, &bps, 8.0, 180.0);
        println!(
            "At 1280px: {} cols, item_w={:.1}",
            r1280.columns, r1280.item_width
        );

        let r700 = state.apply_resize(700.0, &bps, 8.0, 180.0);
        println!(
            "At 700px:  {} cols, item_w={:.1}",
            r700.columns, r700.item_width
        );

        let r400 = state.apply_resize(400.0, &bps, 8.0, 180.0);
        println!(
            "At 400px:  {} cols, item_w={:.1}",
            r400.columns, r400.item_width
        );
    }

    scroller.tick(16.0);
    println!("Grid EPG example completed.");
}
