//! Horizontal carousel example — D-pad navigation with snap-start.
//!
//! Demonstrates:
//! - Horizontal scroll axis
//! - `SnapMode::StartAligned` so items snap cleanly into view
//! - `FocusTracker` with left/right D-pad navigation
//! - `GridFocusNavigator` used in single-row mode (columns = total items)
//!
//! Run with:
//! ```bash
//! cargo run --example horizontal_carousel --features tv-app
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

fn main() {
    // --- Build a horizontal scroller (20 items, 280×180 each) ---
    let mut scroller = VirtualScrollerBuilder::new(ScrollerConfig {
        direction: Direction::Horizontal,
        item_count: 20,
        item_sizing: ItemSizing::Uniform {
            width: 280.0,
            height: 180.0,
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
    .build();

    // --- Focus tracking ---
    #[cfg(feature = "focus-tracking")]
    let mut focus = FocusTracker::new(20, Direction::Horizontal);

    // Simulate 5 D-pad Right presses
    for _ in 0..5 {
        #[cfg(feature = "focus-tracking")]
        {
            focus.navigate(NavDirection::Right);
        }
        scroller.scroll_by(280.0);
        scroller.tick(16.0); // ~60 fps frame
    }

    #[cfg(feature = "focus-tracking")]
    println!("Focused index after 5 rights: {}", focus.focused_index());
    println!("Scroll position: {:.1}", scroller.scroll_position());

    // In a real app the Slint main loop would run here.
    // This example proves the types compose and compile correctly.
}
