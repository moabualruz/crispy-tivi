//! CrispyTivi video player abstraction.
//!
//! Defines the [`PlayerBackend`] trait and provides feature-gated
//! implementations for libmpv and GStreamer.

mod backend;

pub use backend::{PlayerBackend, PlayerState};

#[cfg(feature = "mpv")]
pub mod mpv_backend;

#[cfg(feature = "gstreamer-backend")]
pub mod gstreamer_backend;
