//! FFI API surface for Flutter.
//!
//! Thin wrapper around `CrispyService` exposed via
//! `flutter_rust_bridge`. Functions use primitive types
//! and JSON strings for struct transfer.
//!
//! # Pattern
//!
//! - Simple params/returns: typed (String, i32, bool)
//! - Complex structs: JSON `String` via serde
//! - Errors: `anyhow::Result` (FRB maps to exceptions)
//! - State: `OnceLock<CrispyService>` singleton

pub mod algorithms;
pub mod channels;
pub mod display;
pub mod dvr;
pub mod epg;
pub mod lifecycle;
pub mod parsers;
pub mod profiles;
pub mod settings;
pub mod vod;
pub mod watchlist;

pub use algorithms::*;
pub use channels::*;
pub use display::*;
pub use dvr::*;
pub use epg::*;
pub use lifecycle::*;
pub use parsers::*;
pub use profiles::*;
pub use settings::*;
pub use vod::*;
pub use watchlist::*;

use anyhow::{Result, anyhow};
use crispy_core::services::CrispyService;
use std::sync::OnceLock;

/// Global service singleton. CrispyService uses an internal r2d2 connection
/// pool, making it completely thread-safe and cheaply cloneable.
pub(super) static SERVICE: OnceLock<CrispyService> = OnceLock::new();

/// Get a clone of the service or error if not initialized.
pub(super) fn svc() -> Result<CrispyService> {
    SERVICE
        .get()
        .cloned()
        .ok_or_else(|| anyhow!("Not initialized"))
}

/// Convert millisecond epoch to `NaiveDateTime`.
pub(super) fn ms_to_naive(ms: i64) -> anyhow::Result<chrono::NaiveDateTime> {
    chrono::DateTime::from_timestamp(ms / 1000, 0)
        .ok_or_else(|| anyhow!("Invalid timestamp"))
        .map(|dt| dt.naive_utc())
}
