//! Google Cast integration service (Epoch 10.3).
//!
//! Implements the control flow for Google Cast sessions:
//! connect, load media URL, transport controls (play/pause/stop/seek),
//! and volume control.
//!
//! Actual TCP/TLS socket I/O is injected via [`CastTransport`] so that
//! all state machine logic can be unit-tested without a real Chromecast.

use std::sync::{Arc, Mutex};

use thiserror::Error;

// ── Error ─────────────────────────────────────────────────────────────────────

#[derive(Debug, Error, PartialEq)]
pub enum CastError {
    #[error("not connected to any cast device")]
    NotConnected,
    #[error("no active media session")]
    NoSession,
    #[error("transport error: {0}")]
    Transport(String),
    #[error("invalid parameter: {0}")]
    InvalidParam(String),
}

// ── Domain types ──────────────────────────────────────────────────────────────

/// Connection state of the Cast session.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CastState {
    Idle,
    Connecting,
    Connected,
    Playing,
    Paused,
    Buffering,
    Disconnected,
}

/// Outgoing Cast command.
#[derive(Debug, Clone, PartialEq)]
pub enum CastCommand {
    Connect { host: String, port: u16 },
    Disconnect,
    Load { url: String, title: String },
    Play,
    Pause,
    Stop,
    Seek { position_secs: f64 },
    SetVolume { level: f32 },
    SetMute { muted: bool },
}

/// Status reported back from the Cast receiver.
#[derive(Debug, Clone, PartialEq)]
pub struct CastStatus {
    pub state: CastState,
    pub position_secs: Option<f64>,
    pub duration_secs: Option<f64>,
    pub volume: Option<f32>,
    pub muted: Option<bool>,
}

// ── Transport trait ───────────────────────────────────────────────────────────

/// Abstraction over Cast channel I/O (TLS/protobuf in production).
pub trait CastTransport: Send + Sync {
    /// Send a command. Returns the receiver's status response.
    fn send(&self, cmd: CastCommand) -> Result<CastStatus, CastError>;
}

// ── Noop transport ────────────────────────────────────────────────────────────

/// No-op transport that simulates a successful connection for testing.
#[derive(Debug, Default)]
pub struct NoopCastTransport;

impl CastTransport for NoopCastTransport {
    fn send(&self, cmd: CastCommand) -> Result<CastStatus, CastError> {
        let state = match &cmd {
            CastCommand::Connect { .. } => CastState::Connected,
            CastCommand::Disconnect => CastState::Disconnected,
            CastCommand::Load { .. } => CastState::Playing,
            CastCommand::Play => CastState::Playing,
            CastCommand::Pause => CastState::Paused,
            CastCommand::Stop => CastState::Idle,
            CastCommand::Seek { .. } => CastState::Playing,
            CastCommand::SetVolume { .. } | CastCommand::SetMute { .. } => CastState::Playing,
        };
        Ok(CastStatus {
            state,
            position_secs: None,
            duration_secs: None,
            volume: None,
            muted: None,
        })
    }
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Google Cast session manager.
pub struct CastService {
    transport: Arc<dyn CastTransport>,
    state: Arc<Mutex<CastState>>,
}

impl CastService {
    pub fn new(transport: Arc<dyn CastTransport>) -> Self {
        Self {
            transport,
            state: Arc::new(Mutex::new(CastState::Idle)),
        }
    }

    /// Create a service backed by the no-op transport.
    pub fn noop() -> Self {
        Self::new(Arc::new(NoopCastTransport))
    }

    fn set_state(&self, s: CastState) {
        *self.state.lock().unwrap_or_else(|e| e.into_inner()) = s;
    }

    pub fn state(&self) -> CastState {
        *self.state.lock().unwrap_or_else(|e| e.into_inner())
    }

    /// Connect to a Cast receiver.
    pub fn connect(&self, host: &str, port: u16) -> Result<(), CastError> {
        if host.is_empty() {
            return Err(CastError::InvalidParam("host must not be empty".into()));
        }
        self.set_state(CastState::Connecting);
        let status = self.transport.send(CastCommand::Connect {
            host: host.to_string(),
            port,
        })?;
        self.set_state(status.state);
        Ok(())
    }

    /// Disconnect from the current receiver.
    pub fn disconnect(&self) -> Result<(), CastError> {
        let status = self.transport.send(CastCommand::Disconnect)?;
        self.set_state(status.state);
        Ok(())
    }

    /// Load and play a media URL on the receiver.
    pub fn load_media(&self, url: &str, title: &str) -> Result<(), CastError> {
        if !matches!(
            self.state(),
            CastState::Connected | CastState::Playing | CastState::Paused | CastState::Idle
        ) {
            return Err(CastError::NotConnected);
        }
        if url.is_empty() {
            return Err(CastError::InvalidParam("url must not be empty".into()));
        }
        let status = self.transport.send(CastCommand::Load {
            url: url.to_string(),
            title: title.to_string(),
        })?;
        self.set_state(status.state);
        Ok(())
    }

    /// Resume playback.
    pub fn play(&self) -> Result<(), CastError> {
        self.require_session()?;
        let status = self.transport.send(CastCommand::Play)?;
        self.set_state(status.state);
        Ok(())
    }

    /// Pause playback.
    pub fn pause(&self) -> Result<(), CastError> {
        self.require_session()?;
        let status = self.transport.send(CastCommand::Pause)?;
        self.set_state(status.state);
        Ok(())
    }

    /// Stop playback and end the media session.
    pub fn stop(&self) -> Result<(), CastError> {
        self.require_session()?;
        let status = self.transport.send(CastCommand::Stop)?;
        self.set_state(status.state);
        Ok(())
    }

    /// Seek to an absolute position in seconds.
    pub fn seek(&self, position_secs: f64) -> Result<(), CastError> {
        self.require_session()?;
        if position_secs < 0.0 {
            return Err(CastError::InvalidParam("position must be >= 0".into()));
        }
        let status = self.transport.send(CastCommand::Seek { position_secs })?;
        self.set_state(status.state);
        Ok(())
    }

    /// Set receiver volume (0.0–1.0).
    pub fn set_volume(&self, level: f32) -> Result<(), CastError> {
        if !(0.0..=1.0).contains(&level) {
            return Err(CastError::InvalidParam(
                "volume must be between 0.0 and 1.0".into(),
            ));
        }
        let status = self.transport.send(CastCommand::SetVolume { level })?;
        self.set_state(status.state);
        Ok(())
    }

    /// Mute or unmute the receiver.
    pub fn set_mute(&self, muted: bool) -> Result<(), CastError> {
        let status = self.transport.send(CastCommand::SetMute { muted })?;
        self.set_state(status.state);
        Ok(())
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    fn require_session(&self) -> Result<(), CastError> {
        match self.state() {
            CastState::Playing | CastState::Paused | CastState::Buffering => Ok(()),
            CastState::Connected => Ok(()),
            _ => Err(CastError::NotConnected),
        }
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn connected_service() -> CastService {
        let svc = CastService::noop();
        svc.connect("192.168.1.100", 8009).unwrap();
        // After noop connect, state = Connected; manually ensure session state.
        svc.set_state(CastState::Connected);
        svc
    }

    fn playing_service() -> CastService {
        let svc = connected_service();
        svc.load_media("http://example.com/stream.m3u8", "Test Channel")
            .unwrap();
        svc
    }

    // ── CastState ─────────────────────────────────────────────────────────────

    #[test]
    fn test_initial_state_is_idle() {
        let svc = CastService::noop();
        assert_eq!(svc.state(), CastState::Idle);
    }

    // ── connect ───────────────────────────────────────────────────────────────

    #[test]
    fn test_connect_transitions_to_connected() {
        let svc = CastService::noop();
        svc.connect("192.168.1.100", 8009).unwrap();
        assert_eq!(svc.state(), CastState::Connected);
    }

    #[test]
    fn test_connect_rejects_empty_host() {
        let svc = CastService::noop();
        assert_eq!(
            svc.connect("", 8009),
            Err(CastError::InvalidParam("host must not be empty".into()))
        );
    }

    // ── disconnect ────────────────────────────────────────────────────────────

    #[test]
    fn test_disconnect_transitions_to_disconnected() {
        let svc = connected_service();
        svc.disconnect().unwrap();
        assert_eq!(svc.state(), CastState::Disconnected);
    }

    // ── load_media ────────────────────────────────────────────────────────────

    #[test]
    fn test_load_media_transitions_to_playing() {
        let svc = connected_service();
        svc.load_media("http://example.com/stream.m3u8", "Channel A")
            .unwrap();
        assert_eq!(svc.state(), CastState::Playing);
    }

    #[test]
    fn test_load_media_rejects_empty_url() {
        let svc = connected_service();
        assert!(matches!(
            svc.load_media("", "Title"),
            Err(CastError::InvalidParam(_))
        ));
    }

    #[test]
    fn test_load_media_fails_when_disconnected() {
        let svc = CastService::noop();
        // State is Idle (disconnected variant).
        svc.set_state(CastState::Disconnected);
        assert_eq!(
            svc.load_media("http://example.com/x.m3u8", "Test"),
            Err(CastError::NotConnected)
        );
    }

    // ── play / pause ──────────────────────────────────────────────────────────

    #[test]
    fn test_play_transitions_to_playing() {
        let svc = playing_service();
        svc.pause().unwrap();
        svc.play().unwrap();
        assert_eq!(svc.state(), CastState::Playing);
    }

    #[test]
    fn test_pause_transitions_to_paused() {
        let svc = playing_service();
        svc.pause().unwrap();
        assert_eq!(svc.state(), CastState::Paused);
    }

    #[test]
    fn test_play_fails_when_idle() {
        let svc = CastService::noop();
        assert_eq!(svc.play(), Err(CastError::NotConnected));
    }

    // ── stop ──────────────────────────────────────────────────────────────────

    #[test]
    fn test_stop_transitions_to_idle() {
        let svc = playing_service();
        svc.stop().unwrap();
        assert_eq!(svc.state(), CastState::Idle);
    }

    // ── seek ──────────────────────────────────────────────────────────────────

    #[test]
    fn test_seek_valid_position_succeeds() {
        let svc = playing_service();
        svc.seek(120.0).unwrap();
    }

    #[test]
    fn test_seek_negative_position_rejected() {
        let svc = playing_service();
        assert!(matches!(svc.seek(-1.0), Err(CastError::InvalidParam(_))));
    }

    // ── volume ────────────────────────────────────────────────────────────────

    #[test]
    fn test_set_volume_valid_range_succeeds() {
        let svc = playing_service();
        svc.set_volume(0.5).unwrap();
    }

    #[test]
    fn test_set_volume_zero_succeeds() {
        let svc = playing_service();
        svc.set_volume(0.0).unwrap();
    }

    #[test]
    fn test_set_volume_one_succeeds() {
        let svc = playing_service();
        svc.set_volume(1.0).unwrap();
    }

    #[test]
    fn test_set_volume_above_one_rejected() {
        let svc = CastService::noop();
        assert!(matches!(
            svc.set_volume(1.1),
            Err(CastError::InvalidParam(_))
        ));
    }

    #[test]
    fn test_set_volume_negative_rejected() {
        let svc = CastService::noop();
        assert!(matches!(
            svc.set_volume(-0.1),
            Err(CastError::InvalidParam(_))
        ));
    }

    // ── mute ─────────────────────────────────────────────────────────────────

    #[test]
    fn test_set_mute_true_does_not_error() {
        let svc = playing_service();
        svc.set_mute(true).unwrap();
    }

    #[test]
    fn test_set_mute_false_does_not_error() {
        let svc = playing_service();
        svc.set_mute(false).unwrap();
    }

    // ── transport error propagation ───────────────────────────────────────────

    struct FailTransport;

    impl CastTransport for FailTransport {
        fn send(&self, _: CastCommand) -> Result<CastStatus, CastError> {
            Err(CastError::Transport("network failure".into()))
        }
    }

    #[test]
    fn test_transport_error_propagates_on_connect() {
        let svc = CastService::new(Arc::new(FailTransport));
        assert!(matches!(
            svc.connect("host", 8009),
            Err(CastError::Transport(_))
        ));
    }
}
