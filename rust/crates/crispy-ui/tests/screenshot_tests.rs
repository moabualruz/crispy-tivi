//! Screenshot testing pipeline entry point.
//!
//! This file is the Cargo integration test root. It pulls in the
//! `harness` and `journeys` sub-modules so their `#[cfg(test)]`
//! blocks are compiled and run by `cargo test`.

// Bring all Slint-generated types (AppWindow, AppState, OnboardingState, …)
// into scope for this test binary. Required because journey modules reference
// these types and `crispy-ui` is a binary crate with no exported library.
slint::include_modules!();

mod harness;
mod journeys;
