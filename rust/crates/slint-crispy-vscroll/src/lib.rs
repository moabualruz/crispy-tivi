//! slint-crispy-vscroll — Generic virtual scroll engine for Slint UI.
#![forbid(unsafe_code)]

#[cfg(not(any(
    feature = "vertical",
    feature = "horizontal",
    feature = "grid",
    feature = "full",
    feature = "tv-app",
    feature = "mobile-app",
    feature = "desktop-app",
)))]
compile_error!(
    "slint-crispy-vscroll: no layout features enabled. \
     Use features = [\"full\"] or specify at minimum one of: \
     vertical, horizontal, grid, tv-app, mobile-app, desktop-app"
);

pub mod core;

#[cfg(any(
    feature = "input-touch",
    feature = "input-mouse",
    feature = "input-trackpad",
    feature = "input-dpad",
    feature = "input-gamepad",
    feature = "input-keyboard",
    feature = "input-inject",
))]
pub mod input;

pub mod animation;
pub mod layout;
pub mod physics;
pub mod slots;

#[cfg(feature = "focus-tracking")]
pub mod focus;

pub mod z_depth;

#[cfg(feature = "a11y-hooks")]
pub mod a11y;

pub mod bridge;
pub mod events;
pub mod facade;
