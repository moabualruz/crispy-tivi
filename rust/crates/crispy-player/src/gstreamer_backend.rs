//! GStreamer video backend.
//!
//! Alternative backend using GStreamer for platforms where libmpv
//! is unavailable or impractical. Feature-gated via `gstreamer-backend`.
//! Implementation deferred to Phase 3.

use crate::backend::{PlayerBackend, PlayerError, PlayerState};

/// GStreamer-based video player backend.
pub struct GStreamerBackend {
    state: PlayerState,
}

impl GStreamerBackend {
    /// Create a new GStreamer backend instance.
    pub fn new() -> Result<Self, PlayerError> {
        tracing::info!("GStreamerBackend created (skeleton — Phase 3 implementation pending)");
        Ok(Self {
            state: PlayerState::Idle,
        })
    }
}

impl PlayerBackend for GStreamerBackend {
    fn play(&self, _url: &str) -> Result<(), PlayerError> {
        Err(PlayerError::Unsupported(
            "GStreamerBackend not yet implemented (Phase 3)".into(),
        ))
    }

    fn pause(&self) -> Result<(), PlayerError> {
        Err(PlayerError::Unsupported(
            "GStreamerBackend not yet implemented (Phase 3)".into(),
        ))
    }

    fn seek(&self, _position_secs: f64) -> Result<(), PlayerError> {
        Err(PlayerError::Unsupported(
            "GStreamerBackend not yet implemented (Phase 3)".into(),
        ))
    }

    fn set_volume(&self, _volume: f32) -> Result<(), PlayerError> {
        Err(PlayerError::Unsupported(
            "GStreamerBackend not yet implemented (Phase 3)".into(),
        ))
    }

    fn stop(&self) -> Result<(), PlayerError> {
        Err(PlayerError::Unsupported(
            "GStreamerBackend not yet implemented (Phase 3)".into(),
        ))
    }

    fn state(&self) -> PlayerState {
        self.state
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_gstreamer_backend_new_returns_idle_state() {
        let backend = GStreamerBackend::new().unwrap();
        assert_eq!(backend.state(), PlayerState::Idle);
    }
}
