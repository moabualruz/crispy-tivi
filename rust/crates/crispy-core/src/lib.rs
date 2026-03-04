//! CrispyTivi core library.
//!
//! Contains all business logic, domain models, and
//! database access. Used by both `crispy-ffi` (native
//! platforms via FFI) and `crispy-server` (web via
//! WebSocket).

pub mod algorithms;
pub mod backup;
pub mod database;
pub mod events;
pub mod gpu;
pub mod models;
pub mod parsers;
pub mod services;
pub mod utils;
