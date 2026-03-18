//! CrispyTivi server library.
//!
//! Provides the WebSocket/HTTP service layer that wraps
//! `crispy-core`. Used by the standalone server binary
//! and by `crispy-ui` in server mode.

pub mod config;
pub mod handlers;
pub mod ws_handler;
pub mod ws_protocol;

// Re-export crispy-core types so crispy-ui depends only on crispy-server
pub use crispy_core::models;
pub use crispy_core::services::CrispyService;
