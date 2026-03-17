//! CrispyTivi server library.
//!
//! Provides the WebSocket/HTTP service layer that wraps
//! `crispy-core`. Used by the standalone server binary
//! and by `crispy-ui` in server mode.

pub mod handlers;

// Re-export crispy-core types so crispy-ui depends only on crispy-server
pub use crispy_core::services::CrispyService;
