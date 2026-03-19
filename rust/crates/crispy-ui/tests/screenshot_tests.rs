//! Screenshot testing pipeline entry point.
//!
//! This file is the Cargo integration test root. It pulls in the
//! `harness` and `journeys` sub-modules so their `#[cfg(test)]`
//! blocks are compiled and run by `cargo test`.

mod harness;
mod journeys;
