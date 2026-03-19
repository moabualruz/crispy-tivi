//! Animation driver — Slint transitions, Rust tick, hybrid.

#[cfg(feature = "anim-hybrid")]
pub mod hybrid;
#[cfg(feature = "anim-rust-tick")]
pub mod rust_tick;
#[cfg(feature = "anim-slint-transitions")]
pub mod slint_transitions;
