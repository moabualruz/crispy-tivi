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
pub mod app_update;
pub mod bookmarks;
pub mod buffer;
pub mod channels;
pub mod display;
pub mod dvr;
pub mod epg;
pub mod lifecycle;
pub mod parsers;
pub mod profiles;
pub mod settings;
pub mod smart_groups;
pub mod sources;
pub mod stream_health;
pub mod sync;
pub mod vod;
pub mod watchlist;

pub use algorithms::*;
pub use app_update::*;
pub use bookmarks::*;
pub use buffer::*;
pub use channels::*;
pub use display::*;
pub use dvr::*;
pub use epg::*;
pub use lifecycle::*;
pub use parsers::*;
pub use profiles::*;
pub use settings::*;
pub use smart_groups::*;
pub use sources::*;
pub use stream_health::*;
pub use sync::*;
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

/// Serialize a value to a JSON string.
///
/// Used by FFI functions that return complex structs as `String`.
/// Centralises the `Ok(serde_json::to_string(&val)?)` boilerplate.
pub(crate) fn json_result<T: serde::Serialize>(val: T) -> anyhow::Result<String> {
    Ok(serde_json::to_string(&val)?)
}

/// Convert any `Display` error into `anyhow::Error`.
///
/// Used in async FFI wrappers that call `crispy_core` functions
/// returning non-anyhow error types (e.g. `anyhow::Error` from
/// the core crate after `.map_err(|e| anyhow!("{e}"))`).
pub(crate) fn into_anyhow<T, E: std::fmt::Display>(r: Result<T, E>) -> anyhow::Result<T> {
    r.map_err(|e| anyhow::anyhow!("{e}"))
}

/// Deserialize a JSON string into `T`.
///
/// Centralises the `serde_json::from_str(&json).context("...")`
/// boilerplate used across every FFI API file.
pub(crate) fn from_json<T: serde::de::DeserializeOwned>(json: &str) -> anyhow::Result<T> {
    serde_json::from_str(json)
        .map_err(|e| anyhow::anyhow!("Invalid {} JSON: {e}", std::any::type_name::<T>()))
}

/// Convert millisecond epoch to `NaiveDateTime`.
pub(super) fn ms_to_naive(ms: i64) -> anyhow::Result<chrono::NaiveDateTime> {
    chrono::DateTime::from_timestamp(ms / 1000, 0)
        .ok_or_else(|| anyhow!("Invalid timestamp"))
        .map(|dt| dt.naive_utc())
}
