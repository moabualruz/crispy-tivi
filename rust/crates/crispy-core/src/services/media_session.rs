//! Media session abstraction.
//!
//! Provides OS-level "now playing" metadata integration (lock screen,
//! notification shade, MPRIS on Linux, SMTC on Windows, etc.).
//! The `NoopMediaSession` impl is used on unsupported platforms.

/// Metadata describing the currently playing item.
#[derive(Debug, Clone, Default)]
pub struct MediaSessionInfo {
    pub title: String,
    pub artist: Option<String>,
    pub album: Option<String>,
    pub artwork_url: Option<String>,
    pub duration: Option<f64>,
    pub position: Option<f64>,
}

/// Actions that the OS media session layer can request.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum MediaSessionAction {
    Play,
    Pause,
    Stop,
    SeekForward,
    SeekBackward,
    NextTrack,
    PrevTrack,
}

/// Platform media-session service.
pub trait MediaSessionService: Send + Sync {
    /// Push updated metadata to the OS.
    fn update_metadata(&self, info: &MediaSessionInfo);

    /// Notify the OS of the current playback position (seconds).
    fn update_position(&self, secs: f64);

    /// Register a handler for a specific media action from the OS.
    fn set_action_handler(&self, action: MediaSessionAction, handler: Box<dyn Fn() + Send + Sync>);

    /// Clear all metadata and handlers (e.g. on stop).
    fn clear(&self);
}

// ── Noop impl ────────────────────────────────────────────────────────────────

/// No-op implementation used on unsupported platforms.
#[derive(Debug, Default)]
pub struct NoopMediaSession;

impl MediaSessionService for NoopMediaSession {
    fn update_metadata(&self, _info: &MediaSessionInfo) {}
    fn update_position(&self, _secs: f64) {}
    fn set_action_handler(
        &self,
        _action: MediaSessionAction,
        _handler: Box<dyn Fn() + Send + Sync>,
    ) {
    }
    fn clear(&self) {}
}

// ── Tests ────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn make_info() -> MediaSessionInfo {
        MediaSessionInfo {
            title: "Test Title".to_string(),
            artist: Some("Test Artist".to_string()),
            album: None,
            artwork_url: Some("https://example.com/art.jpg".to_string()),
            duration: Some(3600.0),
            position: Some(42.0),
        }
    }

    #[test]
    fn media_session_info_fields() {
        let info = make_info();
        assert_eq!(info.title, "Test Title");
        assert_eq!(info.artist.as_deref(), Some("Test Artist"));
        assert!(info.album.is_none());
        assert_eq!(info.duration, Some(3600.0));
    }

    #[test]
    fn media_session_action_equality() {
        assert_eq!(MediaSessionAction::Play, MediaSessionAction::Play);
        assert_ne!(MediaSessionAction::Play, MediaSessionAction::Pause);
    }

    #[test]
    fn noop_media_session_update_metadata_does_not_panic() {
        let svc = NoopMediaSession;
        svc.update_metadata(&make_info());
    }

    #[test]
    fn noop_media_session_update_position_does_not_panic() {
        let svc = NoopMediaSession;
        svc.update_position(123.4);
    }

    #[test]
    fn noop_media_session_set_action_handler_does_not_panic() {
        let svc = NoopMediaSession;
        svc.set_action_handler(MediaSessionAction::Play, Box::new(|| {}));
    }

    #[test]
    fn noop_media_session_clear_does_not_panic() {
        let svc = NoopMediaSession;
        svc.clear();
    }

    #[test]
    fn noop_media_session_all_actions_accepted() {
        let svc = NoopMediaSession;
        let actions = [
            MediaSessionAction::Play,
            MediaSessionAction::Pause,
            MediaSessionAction::Stop,
            MediaSessionAction::SeekForward,
            MediaSessionAction::SeekBackward,
            MediaSessionAction::NextTrack,
            MediaSessionAction::PrevTrack,
        ];
        for action in actions {
            svc.set_action_handler(action, Box::new(|| {}));
        }
    }

    #[test]
    fn noop_media_session_default_info() {
        let info = MediaSessionInfo::default();
        assert!(info.title.is_empty());
        assert!(info.artist.is_none());
        assert!(info.duration.is_none());
    }
}
