//! Input classification and routing.

#[cfg(feature = "input-dpad")]
pub mod dpad;
#[cfg(feature = "input-gamepad")]
pub mod gamepad;
#[cfg(feature = "input-inject")]
pub mod inject;
#[cfg(feature = "input-keyboard")]
pub mod keyboard;
#[cfg(feature = "input-mouse")]
pub mod mouse;
#[cfg(feature = "input-touch")]
pub mod touch;
#[cfg(feature = "input-trackpad")]
pub mod trackpad;
