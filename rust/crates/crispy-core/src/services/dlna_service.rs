//! DLNA/UPnP push-to-renderer service (Epoch 10.5).
//!
//! Supports:
//! - Browsing ContentDirectory services on discovered DLNA renderers.
//! - Pushing a local or remote media URL to an AVTransport renderer.
//!
//! DRM-protected content is explicitly rejected.
//!
//! Actual UPnP/SOAP calls are injected via [`DlnaTransport`] so that all
//! state machine logic can be unit-tested without a real DLNA device.

use std::sync::{Arc, Mutex};

use thiserror::Error;

// ── Error ─────────────────────────────────────────────────────────────────────

#[derive(Debug, Error, PartialEq)]
pub enum DlnaError {
    #[error("no renderer selected")]
    NoRenderer,
    #[error("DRM-protected content cannot be pushed via DLNA")]
    DrmProtected,
    #[error("transport error: {0}")]
    Transport(String),
    #[error("invalid parameter: {0}")]
    InvalidParam(String),
    #[error("SOAP fault: action={action}, description={description}")]
    SoapFault { action: String, description: String },
}

// ── Domain types ──────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DlnaTransportState {
    Stopped,
    Playing,
    PausedPlayback,
    Transitioning,
    NoMediaPresent,
}

/// A DLNA/UPnP renderer device (discovered via SSDP/mDNS).
#[derive(Debug, Clone, PartialEq)]
pub struct DlnaRenderer {
    /// UDN (Unique Device Name) from the device description.
    pub udn: String,
    /// Human-readable name.
    pub name: String,
    /// Base URL for the device description XML.
    pub location: String,
    /// AVTransport control URL (parsed from device XML).
    pub av_transport_url: String,
}

/// A media item browsed from a ContentDirectory.
#[derive(Debug, Clone, PartialEq)]
pub struct DlnaMediaItem {
    pub id: String,
    pub title: String,
    pub url: String,
    pub mime_type: String,
    pub duration_secs: Option<u64>,
    pub is_drm: bool,
}

/// UPnP/SOAP action request.
#[derive(Debug, Clone, PartialEq)]
pub enum DlnaAction {
    /// AVTransport: SetAVTransportURI
    SetUri { uri: String, metadata: String },
    /// AVTransport: Play (speed = "1")
    Play,
    /// AVTransport: Pause
    Pause,
    /// AVTransport: Stop
    Stop,
    /// AVTransport: Seek (unit = "REL_TIME", target = "HH:MM:SS")
    Seek { position_secs: u64 },
    /// AVTransport: GetTransportInfo
    GetTransportInfo,
    /// ContentDirectory: Browse (ObjectID, BrowseFlag, Filter, etc.)
    Browse {
        object_id: String,
        start: u32,
        count: u32,
    },
}

/// SOAP response from the renderer.
#[derive(Debug, Clone, PartialEq)]
pub struct DlnaResponse {
    pub transport_state: Option<DlnaTransportState>,
    pub items: Vec<DlnaMediaItem>,
}

// ── Transport trait ───────────────────────────────────────────────────────────

pub trait DlnaTransport: Send + Sync {
    fn send(&self, av_transport_url: &str, action: DlnaAction) -> Result<DlnaResponse, DlnaError>;
}

// ── Noop transport ────────────────────────────────────────────────────────────

#[derive(Debug, Default)]
pub struct NoopDlnaTransport;

impl DlnaTransport for NoopDlnaTransport {
    fn send(&self, _av_transport_url: &str, action: DlnaAction) -> Result<DlnaResponse, DlnaError> {
        let transport_state = match &action {
            DlnaAction::Play => Some(DlnaTransportState::Playing),
            DlnaAction::Pause => Some(DlnaTransportState::PausedPlayback),
            DlnaAction::Stop => Some(DlnaTransportState::Stopped),
            DlnaAction::SetUri { .. } => Some(DlnaTransportState::Stopped),
            DlnaAction::GetTransportInfo => Some(DlnaTransportState::Playing),
            DlnaAction::Seek { .. } => Some(DlnaTransportState::Playing),
            DlnaAction::Browse { .. } => None,
        };
        Ok(DlnaResponse {
            transport_state,
            items: vec![],
        })
    }
}

// ── Service ───────────────────────────────────────────────────────────────────

/// DLNA push-to-renderer service.
pub struct DlnaService {
    transport: Arc<dyn DlnaTransport>,
    renderer: Arc<Mutex<Option<DlnaRenderer>>>,
    state: Arc<Mutex<DlnaTransportState>>,
}

impl DlnaService {
    pub fn new(transport: Arc<dyn DlnaTransport>) -> Self {
        Self {
            transport,
            renderer: Arc::new(Mutex::new(None)),
            state: Arc::new(Mutex::new(DlnaTransportState::NoMediaPresent)),
        }
    }

    pub fn noop() -> Self {
        Self::new(Arc::new(NoopDlnaTransport))
    }

    pub fn state(&self) -> DlnaTransportState {
        *self.state.lock().unwrap_or_else(|e| e.into_inner())
    }

    pub fn current_renderer(&self) -> Option<DlnaRenderer> {
        self.renderer
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .clone()
    }

    fn set_state(&self, s: DlnaTransportState) {
        *self.state.lock().unwrap_or_else(|e| e.into_inner()) = s;
    }

    fn require_renderer(&self) -> Result<DlnaRenderer, DlnaError> {
        self.renderer
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .clone()
            .ok_or(DlnaError::NoRenderer)
    }

    /// Select the target renderer.
    pub fn select_renderer(&self, renderer: DlnaRenderer) {
        *self.renderer.lock().unwrap_or_else(|e| e.into_inner()) = Some(renderer);
    }

    /// Push a media URL to the renderer (SetAVTransportURI + Play).
    ///
    /// DRM-protected items are rejected before any network call.
    pub fn push_url(&self, url: &str, metadata_xml: &str, is_drm: bool) -> Result<(), DlnaError> {
        if is_drm {
            return Err(DlnaError::DrmProtected);
        }
        if url.is_empty() {
            return Err(DlnaError::InvalidParam("url must not be empty".into()));
        }
        let renderer = self.require_renderer()?;
        // SetAVTransportURI
        self.transport.send(
            &renderer.av_transport_url,
            DlnaAction::SetUri {
                uri: url.to_string(),
                metadata: metadata_xml.to_string(),
            },
        )?;
        // Play
        let resp = self
            .transport
            .send(&renderer.av_transport_url, DlnaAction::Play)?;
        if let Some(s) = resp.transport_state {
            self.set_state(s);
        }
        Ok(())
    }

    /// Pause the renderer.
    pub fn pause(&self) -> Result<(), DlnaError> {
        let renderer = self.require_renderer()?;
        let resp = self
            .transport
            .send(&renderer.av_transport_url, DlnaAction::Pause)?;
        if let Some(s) = resp.transport_state {
            self.set_state(s);
        }
        Ok(())
    }

    /// Resume playback.
    pub fn play(&self) -> Result<(), DlnaError> {
        let renderer = self.require_renderer()?;
        let resp = self
            .transport
            .send(&renderer.av_transport_url, DlnaAction::Play)?;
        if let Some(s) = resp.transport_state {
            self.set_state(s);
        }
        Ok(())
    }

    /// Stop playback.
    pub fn stop(&self) -> Result<(), DlnaError> {
        let renderer = self.require_renderer()?;
        let resp = self
            .transport
            .send(&renderer.av_transport_url, DlnaAction::Stop)?;
        if let Some(s) = resp.transport_state {
            self.set_state(s);
        }
        Ok(())
    }

    /// Seek to `position_secs` (absolute).
    pub fn seek(&self, position_secs: u64) -> Result<(), DlnaError> {
        let renderer = self.require_renderer()?;
        self.transport.send(
            &renderer.av_transport_url,
            DlnaAction::Seek { position_secs },
        )?;
        Ok(())
    }

    /// Query the current transport state from the renderer.
    pub fn get_transport_state(&self) -> Result<DlnaTransportState, DlnaError> {
        let renderer = self.require_renderer()?;
        let resp = self
            .transport
            .send(&renderer.av_transport_url, DlnaAction::GetTransportInfo)?;
        if let Some(s) = resp.transport_state {
            self.set_state(s);
            Ok(s)
        } else {
            Ok(self.state())
        }
    }

    /// Browse a ContentDirectory on the renderer.
    pub fn browse(
        &self,
        object_id: &str,
        start: u32,
        count: u32,
    ) -> Result<Vec<DlnaMediaItem>, DlnaError> {
        if object_id.is_empty() {
            return Err(DlnaError::InvalidParam(
                "object_id must not be empty".into(),
            ));
        }
        let renderer = self.require_renderer()?;
        let resp = self.transport.send(
            &renderer.av_transport_url,
            DlnaAction::Browse {
                object_id: object_id.to_string(),
                start,
                count,
            },
        )?;
        Ok(resp.items)
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn test_renderer() -> DlnaRenderer {
        DlnaRenderer {
            udn: "uuid:test-0001".to_string(),
            name: "Living Room TV".to_string(),
            location: "http://192.168.1.10:49152/description.xml".to_string(),
            av_transport_url: "http://192.168.1.10:49152/AVTransport/control".to_string(),
        }
    }

    fn service_with_renderer() -> DlnaService {
        let svc = DlnaService::noop();
        svc.select_renderer(test_renderer());
        svc
    }

    // ── initial state ──────────────────────────────────────────────────────────

    #[test]
    fn test_initial_state_is_no_media_present() {
        let svc = DlnaService::noop();
        assert_eq!(svc.state(), DlnaTransportState::NoMediaPresent);
    }

    #[test]
    fn test_initial_renderer_is_none() {
        let svc = DlnaService::noop();
        assert!(svc.current_renderer().is_none());
    }

    // ── select_renderer ────────────────────────────────────────────────────────

    #[test]
    fn test_select_renderer_stores_renderer() {
        let svc = DlnaService::noop();
        svc.select_renderer(test_renderer());
        assert_eq!(svc.current_renderer().unwrap().udn, "uuid:test-0001");
    }

    // ── push_url ──────────────────────────────────────────────────────────────

    #[test]
    fn test_push_url_transitions_to_playing() {
        let svc = service_with_renderer();
        svc.push_url("http://example.com/video.mp4", "", false)
            .unwrap();
        assert_eq!(svc.state(), DlnaTransportState::Playing);
    }

    #[test]
    fn test_push_url_rejects_drm() {
        let svc = service_with_renderer();
        assert_eq!(
            svc.push_url("http://example.com/drm.mp4", "", true),
            Err(DlnaError::DrmProtected)
        );
    }

    #[test]
    fn test_push_url_rejects_empty_url() {
        let svc = service_with_renderer();
        assert!(matches!(
            svc.push_url("", "", false),
            Err(DlnaError::InvalidParam(_))
        ));
    }

    #[test]
    fn test_push_url_fails_without_renderer() {
        let svc = DlnaService::noop();
        assert_eq!(
            svc.push_url("http://example.com/video.mp4", "", false),
            Err(DlnaError::NoRenderer)
        );
    }

    // ── pause / play ──────────────────────────────────────────────────────────

    #[test]
    fn test_pause_transitions_to_paused() {
        let svc = service_with_renderer();
        svc.push_url("http://example.com/video.mp4", "", false)
            .unwrap();
        svc.pause().unwrap();
        assert_eq!(svc.state(), DlnaTransportState::PausedPlayback);
    }

    #[test]
    fn test_play_transitions_to_playing() {
        let svc = service_with_renderer();
        svc.pause().unwrap();
        svc.play().unwrap();
        assert_eq!(svc.state(), DlnaTransportState::Playing);
    }

    #[test]
    fn test_pause_fails_without_renderer() {
        let svc = DlnaService::noop();
        assert_eq!(svc.pause(), Err(DlnaError::NoRenderer));
    }

    #[test]
    fn test_play_fails_without_renderer() {
        let svc = DlnaService::noop();
        assert_eq!(svc.play(), Err(DlnaError::NoRenderer));
    }

    // ── stop ──────────────────────────────────────────────────────────────────

    #[test]
    fn test_stop_transitions_to_stopped() {
        let svc = service_with_renderer();
        svc.push_url("http://example.com/video.mp4", "", false)
            .unwrap();
        svc.stop().unwrap();
        assert_eq!(svc.state(), DlnaTransportState::Stopped);
    }

    #[test]
    fn test_stop_fails_without_renderer() {
        let svc = DlnaService::noop();
        assert_eq!(svc.stop(), Err(DlnaError::NoRenderer));
    }

    // ── seek ──────────────────────────────────────────────────────────────────

    #[test]
    fn test_seek_valid_position_succeeds() {
        let svc = service_with_renderer();
        svc.seek(120).unwrap();
    }

    #[test]
    fn test_seek_fails_without_renderer() {
        let svc = DlnaService::noop();
        assert_eq!(svc.seek(60), Err(DlnaError::NoRenderer));
    }

    // ── get_transport_state ───────────────────────────────────────────────────

    #[test]
    fn test_get_transport_state_returns_playing() {
        let svc = service_with_renderer();
        let state = svc.get_transport_state().unwrap();
        assert_eq!(state, DlnaTransportState::Playing);
    }

    #[test]
    fn test_get_transport_state_fails_without_renderer() {
        let svc = DlnaService::noop();
        assert_eq!(svc.get_transport_state(), Err(DlnaError::NoRenderer));
    }

    // ── browse ────────────────────────────────────────────────────────────────

    #[test]
    fn test_browse_returns_items() {
        let svc = service_with_renderer();
        let items = svc.browse("0", 0, 10).unwrap();
        // Noop transport returns empty vec.
        assert!(items.is_empty());
    }

    #[test]
    fn test_browse_rejects_empty_object_id() {
        let svc = service_with_renderer();
        assert!(matches!(
            svc.browse("", 0, 10),
            Err(DlnaError::InvalidParam(_))
        ));
    }

    #[test]
    fn test_browse_fails_without_renderer() {
        let svc = DlnaService::noop();
        assert_eq!(svc.browse("0", 0, 10), Err(DlnaError::NoRenderer));
    }

    // ── transport error propagation ───────────────────────────────────────────

    struct FailDlnaTransport;

    impl DlnaTransport for FailDlnaTransport {
        fn send(
            &self,
            _av_transport_url: &str,
            _action: DlnaAction,
        ) -> Result<DlnaResponse, DlnaError> {
            Err(DlnaError::Transport("SOAP timeout".into()))
        }
    }

    #[test]
    fn test_transport_error_propagates_on_push() {
        let svc = DlnaService::new(Arc::new(FailDlnaTransport));
        svc.select_renderer(test_renderer());
        assert!(matches!(
            svc.push_url("http://example.com/video.mp4", "", false),
            Err(DlnaError::Transport(_))
        ));
    }

    // ── DlnaMediaItem ─────────────────────────────────────────────────────────

    #[test]
    fn test_dlna_media_item_fields() {
        let item = DlnaMediaItem {
            id: "1".to_string(),
            title: "Movie".to_string(),
            url: "http://192.168.1.1/movie.mp4".to_string(),
            mime_type: "video/mp4".to_string(),
            duration_secs: Some(7200),
            is_drm: false,
        };
        assert_eq!(item.mime_type, "video/mp4");
        assert_eq!(item.duration_secs, Some(7200));
        assert!(!item.is_drm);
    }

    // ── DlnaError variants ────────────────────────────────────────────────────

    #[test]
    fn test_dlna_error_soap_fault_message() {
        let err = DlnaError::SoapFault {
            action: "Play".to_string(),
            description: "Invalid state".to_string(),
        };
        let msg = err.to_string();
        assert!(msg.contains("Play"));
        assert!(msg.contains("Invalid state"));
    }
}
