//! Core player abstraction.

use thiserror::Error;

/// Errors that can occur during player operations.
#[derive(Debug, Error)]
pub enum PlayerError {
    #[error("playback failed: {0}")]
    Playback(String),

    #[error("backend not initialized")]
    NotInitialized,

    #[error("unsupported operation: {0}")]
    Unsupported(String),
}

/// Current state of the player.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PlayerState {
    /// No media loaded.
    Idle,
    /// Media is buffering.
    Buffering,
    /// Media is playing.
    Playing,
    /// Media is paused.
    Paused,
    /// Playback has stopped (end of stream or explicit stop).
    Stopped,
    /// An error occurred during playback.
    Error,
}

/// Trait that all video backends must implement.
///
/// Implementations exist for libmpv (default) and GStreamer
/// (feature-gated via `gstreamer-backend`).
pub trait PlayerBackend: Send + Sync {
    /// Start playback of the given URL or file path.
    fn play(&self, url: &str) -> Result<(), PlayerError>;

    /// Pause playback.
    fn pause(&self) -> Result<(), PlayerError>;

    /// Seek to the given position in seconds.
    fn seek(&self, position_secs: f64) -> Result<(), PlayerError>;

    /// Set volume (0.0 = mute, 1.0 = 100%).
    fn set_volume(&self, volume: f32) -> Result<(), PlayerError>;

    /// Stop playback and release the current media.
    fn stop(&self) -> Result<(), PlayerError>;

    /// Query the current player state.
    fn state(&self) -> PlayerState;
}
