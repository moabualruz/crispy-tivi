//! FFI bridge for CrispyTivi native platforms.
//!
//! This crate exposes `crispy-core` functions to Flutter
//! via `flutter_rust_bridge`. Native platforms (Windows,
//! macOS, Linux, Android, iOS) link this as a dynamic
//! library (.dll/.so/.dylib/.a).

pub mod api;
#[cfg(windows)]
mod display_impl;

// FRB auto-generated glue — populated by codegen.
// The frb_generated module will be created by
// `flutter_rust_bridge_codegen generate`.
mod frb_generated;
