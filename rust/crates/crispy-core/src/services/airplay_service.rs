//! AirPlay v1 integration service (Epoch 10.4).
//!
//! Implements discovery via mDNS (`_airplay._tcp`) and media push via HTTP.
//! AirPlay v1 uses a simple HTTP reverse-proxy protocol: POST `/play` with
//! the stream URL, GET `/scrub` to query position, POST `/scrub` to seek,
//! POST `/rate` to play/pause, POST `/stop` to stop.
//!
//! Actual HTTP calls are injected via [`AirPlayTransport`] so that all
//! state machine logic can be unit-tested without a real AirPlay device.

use std::sync::{Arc, Mutex};

use thiserror::Error;

// ── Error ─────────────────────────────────────────────────────────────────────

#[derive(Debug, Error, PartialEq)]
pub enum AirPlayError {
    #[error("not connected to any AirPlay device")]
    NotConnected,
    #[error("transport error: {0}")]
    Transport(String),
    #[error("invalid parameter: {0}")]
    InvalidParam(String),
}

// ── Domain types ──────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AirPlayState {
    Idle,
    Playing,
    Paused,
    Stopped,
}

/// A discovered AirPlay v1 endpoint.
#[derive(Debug, Clone, PartialEq)]
pub struct AirPlayDevice {
    pub id: String,
    pub name: String,
    pub host: String,
    pub port: u16,
}

/// Outgoing AirPlay HTTP request.
#[derive(Debug, Clone, PartialEq)]
pub enum AirPlayRequest {
    /// POST /play with Content-Location header set to `url`.
    Play { url: String, start_position: f64 },
    /// POST /rate?value=1.0 (play) or ?value=0.0 (pause).
    Rate { value: f32 },
    /// POST /scrub?position={secs}
    Seek { position_secs: f64 },
    /// POST /stop
    Stop,
    /// GET /scrub — returns current playback position.
    GetScrub,
}

/// Response from the AirPlay device.
#[derive(Debug, Clone, PartialEq)]
pub struct AirPlayResponse {
    /// HTTP status code.
    pub status: u16,
    /// Playback position if the response carries one (e.g. from GET /scrub).
    pub position_secs: Option<f64>,
    /// Total duration if available.
    pub duration_secs: Option<f64>,
}

// ── Transport trait ───────────────────────────────────────────────────────────

/// Abstraction over AirPlay HTTP calls.
pub trait AirPlayTransport: Send + Sync {
    fn send(
        &self,
        host: &str,
        port: u16,
        request: AirPlayRequest,
    ) -> Result<AirPlayResponse, AirPlayError>;
}

// ── Noop transport ────────────────────────────────────────────────────────────

#[derive(Debug, Default)]
pub struct NoopAirPlayTransport;

impl AirPlayTransport for NoopAirPlayTransport {
    fn send(
        &self,
        _host: &str,
        _port: u16,
        request: AirPlayRequest,
    ) -> Result<AirPlayResponse, AirPlayError> {
        let position_secs = match &request {
            AirPlayRequest::GetScrub => Some(0.0),
            _ => None,
        };
        Ok(AirPlayResponse {
            status: 200,
            position_secs,
            duration_secs: None,
        })
    }
}

// ── Service ───────────────────────────────────────────────────────────────────

/// AirPlay v1 session manager.
pub struct AirPlayService {
    transport: Arc<dyn AirPlayTransport>,
    device: Arc<Mutex<Option<AirPlayDevice>>>,
    state: Arc<Mutex<AirPlayState>>,
}

impl AirPlayService {
    pub fn new(transport: Arc<dyn AirPlayTransport>) -> Self {
        Self {
            transport,
            device: Arc::new(Mutex::new(None)),
            state: Arc::new(Mutex::new(AirPlayState::Idle)),
        }
    }

    /// Create a service backed by the no-op transport.
    pub fn noop() -> Self {
        Self::new(Arc::new(NoopAirPlayTransport))
    }

    pub fn state(&self) -> AirPlayState {
        *self.state.lock().unwrap_or_else(|e| e.into_inner())
    }

    pub fn current_device(&self) -> Option<AirPlayDevice> {
        self.device
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .clone()
    }

    fn set_state(&self, s: AirPlayState) {
        *self.state.lock().unwrap_or_else(|e| e.into_inner()) = s;
    }

    fn set_device(&self, dev: Option<AirPlayDevice>) {
        *self.device.lock().unwrap_or_else(|e| e.into_inner()) = dev;
    }

    /// Associate this service with an AirPlay device (discovered via mDNS).
    pub fn select_device(&self, device: AirPlayDevice) {
        self.set_device(Some(device));
    }

    /// Push an HLS or HTTP URL to the selected device.
    ///
    /// `start_position` is in seconds (0.0 = beginning).
    pub fn push_url(&self, url: &str, start_position: f64) -> Result<(), AirPlayError> {
        if url.is_empty() {
            return Err(AirPlayError::InvalidParam("url must not be empty".into()));
        }
        let dev = self.require_device()?;
        let resp = self.transport.send(
            &dev.host,
            dev.port,
            AirPlayRequest::Play {
                url: url.to_string(),
                start_position,
            },
        )?;
        if resp.status == 200 {
            self.set_state(AirPlayState::Playing);
        }
        Ok(())
    }

    /// Pause playback (POST /rate?value=0.0).
    pub fn pause(&self) -> Result<(), AirPlayError> {
        let dev = self.require_device()?;
        self.transport
            .send(&dev.host, dev.port, AirPlayRequest::Rate { value: 0.0 })?;
        self.set_state(AirPlayState::Paused);
        Ok(())
    }

    /// Resume playback (POST /rate?value=1.0).
    pub fn play(&self) -> Result<(), AirPlayError> {
        let dev = self.require_device()?;
        self.transport
            .send(&dev.host, dev.port, AirPlayRequest::Rate { value: 1.0 })?;
        self.set_state(AirPlayState::Playing);
        Ok(())
    }

    /// Seek to an absolute position in seconds.
    pub fn seek(&self, position_secs: f64) -> Result<(), AirPlayError> {
        if position_secs < 0.0 {
            return Err(AirPlayError::InvalidParam("position must be >= 0".into()));
        }
        let dev = self.require_device()?;
        self.transport
            .send(&dev.host, dev.port, AirPlayRequest::Seek { position_secs })?;
        Ok(())
    }

    /// Stop playback.
    pub fn stop(&self) -> Result<(), AirPlayError> {
        let dev = self.require_device()?;
        self.transport
            .send(&dev.host, dev.port, AirPlayRequest::Stop)?;
        self.set_state(AirPlayState::Stopped);
        Ok(())
    }

    /// Query current playback position from the device.
    pub fn get_position(&self) -> Result<Option<f64>, AirPlayError> {
        let dev = self.require_device()?;
        let resp = self
            .transport
            .send(&dev.host, dev.port, AirPlayRequest::GetScrub)?;
        Ok(resp.position_secs)
    }

    fn require_device(&self) -> Result<AirPlayDevice, AirPlayError> {
        self.device
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .clone()
            .ok_or(AirPlayError::NotConnected)
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn test_device() -> AirPlayDevice {
        AirPlayDevice {
            id: "ap-001".to_string(),
            name: "Apple TV".to_string(),
            host: "192.168.1.50".to_string(),
            port: 7000,
        }
    }

    fn service_with_device() -> AirPlayService {
        let svc = AirPlayService::noop();
        svc.select_device(test_device());
        svc
    }

    // ── initial state ──────────────────────────────────────────────────────────

    #[test]
    fn test_initial_state_is_idle() {
        let svc = AirPlayService::noop();
        assert_eq!(svc.state(), AirPlayState::Idle);
    }

    #[test]
    fn test_initial_device_is_none() {
        let svc = AirPlayService::noop();
        assert!(svc.current_device().is_none());
    }

    // ── select_device ──────────────────────────────────────────────────────────

    #[test]
    fn test_select_device_stores_device() {
        let svc = AirPlayService::noop();
        svc.select_device(test_device());
        assert_eq!(svc.current_device().unwrap().id, "ap-001");
    }

    // ── push_url ──────────────────────────────────────────────────────────────

    #[test]
    fn test_push_url_transitions_to_playing() {
        let svc = service_with_device();
        svc.push_url("http://example.com/stream.m3u8", 0.0).unwrap();
        assert_eq!(svc.state(), AirPlayState::Playing);
    }

    #[test]
    fn test_push_url_with_start_position() {
        let svc = service_with_device();
        svc.push_url("http://example.com/stream.m3u8", 30.0)
            .unwrap();
        assert_eq!(svc.state(), AirPlayState::Playing);
    }

    #[test]
    fn test_push_url_rejects_empty_url() {
        let svc = service_with_device();
        assert!(matches!(
            svc.push_url("", 0.0),
            Err(AirPlayError::InvalidParam(_))
        ));
    }

    #[test]
    fn test_push_url_fails_without_device() {
        let svc = AirPlayService::noop();
        assert_eq!(
            svc.push_url("http://example.com/stream.m3u8", 0.0),
            Err(AirPlayError::NotConnected)
        );
    }

    // ── pause / play ──────────────────────────────────────────────────────────

    #[test]
    fn test_pause_transitions_to_paused() {
        let svc = service_with_device();
        svc.push_url("http://example.com/x.m3u8", 0.0).unwrap();
        svc.pause().unwrap();
        assert_eq!(svc.state(), AirPlayState::Paused);
    }

    #[test]
    fn test_play_transitions_to_playing() {
        let svc = service_with_device();
        svc.push_url("http://example.com/x.m3u8", 0.0).unwrap();
        svc.pause().unwrap();
        svc.play().unwrap();
        assert_eq!(svc.state(), AirPlayState::Playing);
    }

    #[test]
    fn test_pause_fails_without_device() {
        let svc = AirPlayService::noop();
        assert_eq!(svc.pause(), Err(AirPlayError::NotConnected));
    }

    #[test]
    fn test_play_fails_without_device() {
        let svc = AirPlayService::noop();
        assert_eq!(svc.play(), Err(AirPlayError::NotConnected));
    }

    // ── stop ──────────────────────────────────────────────────────────────────

    #[test]
    fn test_stop_transitions_to_stopped() {
        let svc = service_with_device();
        svc.push_url("http://example.com/x.m3u8", 0.0).unwrap();
        svc.stop().unwrap();
        assert_eq!(svc.state(), AirPlayState::Stopped);
    }

    #[test]
    fn test_stop_fails_without_device() {
        let svc = AirPlayService::noop();
        assert_eq!(svc.stop(), Err(AirPlayError::NotConnected));
    }

    // ── seek ──────────────────────────────────────────────────────────────────

    #[test]
    fn test_seek_valid_position_succeeds() {
        let svc = service_with_device();
        svc.seek(60.0).unwrap();
    }

    #[test]
    fn test_seek_negative_position_rejected() {
        let svc = service_with_device();
        assert!(matches!(svc.seek(-1.0), Err(AirPlayError::InvalidParam(_))));
    }

    #[test]
    fn test_seek_zero_position_succeeds() {
        let svc = service_with_device();
        svc.seek(0.0).unwrap();
    }

    #[test]
    fn test_seek_fails_without_device() {
        let svc = AirPlayService::noop();
        assert_eq!(svc.seek(10.0), Err(AirPlayError::NotConnected));
    }

    // ── get_position ──────────────────────────────────────────────────────────

    #[test]
    fn test_get_position_returns_value() {
        let svc = service_with_device();
        let pos = svc.get_position().unwrap();
        assert_eq!(pos, Some(0.0));
    }

    #[test]
    fn test_get_position_fails_without_device() {
        let svc = AirPlayService::noop();
        assert_eq!(svc.get_position(), Err(AirPlayError::NotConnected));
    }

    // ── transport error propagation ───────────────────────────────────────────

    struct FailAirPlayTransport;

    impl AirPlayTransport for FailAirPlayTransport {
        fn send(
            &self,
            _host: &str,
            _port: u16,
            _request: AirPlayRequest,
        ) -> Result<AirPlayResponse, AirPlayError> {
            Err(AirPlayError::Transport("network failure".into()))
        }
    }

    #[test]
    fn test_transport_error_propagates() {
        let svc = AirPlayService::new(Arc::new(FailAirPlayTransport));
        svc.select_device(test_device());
        assert!(matches!(
            svc.push_url("http://example.com/x.m3u8", 0.0),
            Err(AirPlayError::Transport(_))
        ));
    }

    // ── AirPlayDevice fields ──────────────────────────────────────────────────

    #[test]
    fn test_airplay_device_fields() {
        let dev = test_device();
        assert_eq!(dev.host, "192.168.1.50");
        assert_eq!(dev.port, 7000);
        assert_eq!(dev.name, "Apple TV");
    }
}
