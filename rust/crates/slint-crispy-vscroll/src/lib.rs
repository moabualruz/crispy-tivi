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
