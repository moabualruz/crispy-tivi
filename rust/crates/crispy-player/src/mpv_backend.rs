//! libmpv video backend.
//!
//! This module will integrate with libmpv via the `libmpv2` crate
//! to provide hardware-accelerated video playback with OpenGL underlay
//! rendering. Implementation deferred to Phase 3.
//!
//! ABSOLUTE RULE: Hardware decode is mandatory (`hwdec=auto`).
//! Never set `hwdec=no` or fall back to software decode.

use crate::backend::{PlayerBackend, PlayerError, PlayerState};

/// libmpv-based video player backend.
///
/// Renders via OpenGL underlay behind the Slint UI canvas.
/// Hardware decoding is always enabled.
pub struct MpvBackend {
    state: PlayerState,
}

impl MpvBackend {
    /// Create a new mpv backend instance.
    ///
    /// In Phase 3 this will initialize the mpv context with
    /// `hwdec=auto` and set up the OpenGL render context.
    pub fn new() -> Result<Self, PlayerError> {
        tracing::info!("MpvBackend created (skeleton — Phase 3 implementation pending)");
        Ok(Self {
            state: PlayerState::Idle,
        })
    }
}

impl PlayerBackend for MpvBackend {
    fn play(&self, _url: &str) -> Result<(), PlayerError> {
        Err(PlayerError::Unsupported(
            "MpvBackend not yet implemented (Phase 3)".into(),
        ))
    }

    fn pause(&self) -> Result<(), PlayerError> {
        Err(PlayerError::Unsupported(
            "MpvBackend not yet implemented (Phase 3)".into(),
        ))
    }

    fn seek(&self, _position_secs: f64) -> Result<(), PlayerError> {
        Err(PlayerError::Unsupported(
            "MpvBackend not yet implemented (Phase 3)".into(),
        ))
    }

    fn set_volume(&self, _volume: f32) -> Result<(), PlayerError> {
        Err(PlayerError::Unsupported(
            "MpvBackend not yet implemented (Phase 3)".into(),
        ))
    }

    fn stop(&self) -> Result<(), PlayerError> {
        Err(PlayerError::Unsupported(
            "MpvBackend not yet implemented (Phase 3)".into(),
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
    fn test_mpv_backend_new_returns_idle_state() {
        let backend = MpvBackend::new().unwrap();
        assert_eq!(backend.state(), PlayerState::Idle);
    }

    #[test]
    fn test_mpv_backend_play_returns_unsupported() {
        let backend = MpvBackend::new().unwrap();
        let result = backend.play("http://example.com/stream.m3u8");
        assert!(result.is_err());
    }
}
