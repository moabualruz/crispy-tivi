//! Apple TV parallax / cover flow example.
//!
//! Demonstrates:
//! - `CoverFlowProvider` for horizontal carousel Z-depth
//! - `ZTransformProvider` trait usage — compute transforms per item
//! - Simulated D-pad navigation updating the focused index
//! - `ParallaxProvider` as an alternative preset
//!
//! Run with:
//! ```bash
//! cargo run --example apple_tv_parallax --features "z-cover-flow,z-parallax,input-dpad,horizontal,focus-tracking,integrity-sync,anim-hybrid"
//! ```
//!
//! Or with the `full` bundle:
//! ```bash
//! cargo run --example apple_tv_parallax --features full
//! ```

use slint_crispy_vscroll::core::config::ZTransformParams;

#[cfg(feature = "z-cover-flow")]
use slint_crispy_vscroll::z_depth::cover_flow::CoverFlowProvider;

#[cfg(feature = "z-parallax")]
use slint_crispy_vscroll::z_depth::parallax::ParallaxProvider;

use slint_crispy_vscroll::core::config::ZTransformProvider;

fn make_params(index: i32, focused: i32) -> ZTransformParams {
    let dist = (index - focused) as f32;
    ZTransformParams {
        index,
        focused_index: focused,
        distance_from_focus: dist,
        normalized_distance: dist.abs(),
        scroll_progress: 0.0,
        viewport_position: 0.0,
        is_focused: index == focused,
        pointer_position: None,
        velocity: 0.0,
    }
}

fn main() {
    const TOTAL: i32 = 9;
    let mut focused: i32 = 4;

    #[cfg(feature = "z-cover-flow")]
    let cover_flow = CoverFlowProvider::default();

    #[cfg(feature = "z-parallax")]
    let parallax = ParallaxProvider::default();

    println!("--- Cover flow transforms (focused={focused}) ---");
    for i in 0..TOTAL {
        #[cfg(feature = "z-cover-flow")]
        {
            let t = cover_flow.compute(make_params(i, focused));
            println!(
                "  Item {i:2}: scale={:.3}  opacity={:.3}  rot_y={:+.1}°  z={:.1}",
                t.scale, t.opacity, t.rotation_y, t.z_offset
            );
        }
        #[cfg(not(feature = "z-cover-flow"))]
        let _ = make_params(i, focused);
    }

    // Simulate D-pad Right: focus moves +1
    focused += 1;
    println!("\n--- After D-pad Right (focused={focused}) ---");
    for i in 0..TOTAL {
        #[cfg(feature = "z-cover-flow")]
        {
            let t = cover_flow.compute(make_params(i, focused));
            println!(
                "  Item {i:2}: scale={:.3}  opacity={:.3}  rot_y={:+.1}°",
                t.scale, t.opacity, t.rotation_y
            );
        }
        #[cfg(not(feature = "z-cover-flow"))]
        let _ = make_params(i, focused);
    }

    println!("\n--- Parallax offsets (focused={focused}) ---");
    for i in 0..TOTAL {
        #[cfg(feature = "z-parallax")]
        {
            let t = parallax.compute(make_params(i, focused));
            println!("  Item {i:2}: translate_x={:.2}", t.translate_x);
        }
        #[cfg(not(feature = "z-parallax"))]
        let _ = make_params(i, focused);
    }

    println!("\nApple TV parallax example completed.");
}
