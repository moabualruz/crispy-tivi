//! Nested scroll example — vertical list of horizontal carousels.
//!
//! Demonstrates:
//! - Multiple independent `VirtualScroller` instances (one outer vertical,
//!   N inner horizontal) composing into a "shelf" layout
//! - Each inner carousel uses `FocusTracker` for horizontal D-pad navigation
//! - `VScrollWorld` (ECS) wrapping the outer scroller with a logging system
//!
//! Run with:
//! ```bash
//! cargo run --example nested_scroll --features "tv-app,ecs"
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

#[cfg(feature = "focus-tracking")]
use slint_crispy_vscroll::focus::tracker::FocusTracker;

#[cfg(feature = "ecs")]
use slint_crispy_vscroll::facade::ecs::{VScrollSystem, VScrollWorld};

// ---------------------------------------------------------------------------
// ECS system: logs vertical scroll position each tick
// ---------------------------------------------------------------------------

#[cfg(feature = "ecs")]
struct PositionLogger;

#[cfg(feature = "ecs")]
impl VScrollSystem for PositionLogger {
    fn tick(&mut self, world: &mut VScrollWorld, _dt: f32) {
        let _ = world.scroller().scroll_position();
        // In a real app: update UI labels, analytics, etc.
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn make_row_scroller(item_count: i32) -> slint_crispy_vscroll::facade::scroller::VirtualScroller {
    VirtualScrollerBuilder::new(ScrollerConfig {
        direction: Direction::Horizontal,
        item_count,
        item_sizing: ItemSizing::Uniform {
            width: 240.0,
            height: 135.0,
        },
        snap_mode: SnapMode::StartAligned,
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
        scrollbar_visible: false,
        scrollbar_fade_ms: 1000,
    })
    .build()
}

fn make_outer_scroller(row_count: i32) -> slint_crispy_vscroll::facade::scroller::VirtualScroller {
    VirtualScrollerBuilder::new(ScrollerConfig {
        direction: Direction::Vertical,
        item_count: row_count,
        item_sizing: ItemSizing::Uniform {
            width: 1280.0,
            height: 175.0,
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
    .build()
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

fn main() {
    const ROW_COUNT: i32 = 6;
    const ITEMS_PER_ROW: i32 = 20;

    // --- Build outer scroller (vertical shelf) ---
    let outer = make_outer_scroller(ROW_COUNT);

    // --- Wrap in ECS world ---
    #[cfg(feature = "ecs")]
    let mut world = {
        let mut w = VScrollWorld::new(outer);
        w.add_system(PositionLogger);
        w
    };

    // --- Build inner (horizontal) scrollers + focus trackers ---
    let mut rows: Vec<_> = (0..ROW_COUNT)
        .map(|_| make_row_scroller(ITEMS_PER_ROW))
        .collect();

    #[cfg(feature = "focus-tracking")]
    let mut row_focus: Vec<FocusTracker> = (0..ROW_COUNT)
        .map(|_| FocusTracker::new(ITEMS_PER_ROW as usize, Direction::Horizontal))
        .collect();

    // Simulate navigating right in row 2
    let active_row = 2_usize;
    for _ in 0..4 {
        #[cfg(feature = "focus-tracking")]
        {
            row_focus[active_row].navigate(NavDirection::Right);
        }
        rows[active_row].scroll_by(240.0);
        rows[active_row].tick(16.0);
    }

    // Tick the outer scroller / ECS world
    #[cfg(feature = "ecs")]
    world.tick(1.0 / 60.0);

    #[cfg(not(feature = "ecs"))]
    {
        let mut outer_plain = make_outer_scroller(ROW_COUNT);
        outer_plain.tick(16.0);
    }

    #[cfg(feature = "focus-tracking")]
    println!(
        "Row {} focused index: {}",
        active_row,
        row_focus[active_row].focused_index()
    );

    println!("Nested scroll example completed.");
}
