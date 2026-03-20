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

// ── Platform stubs ───────────────────────────────────────────────────────────

/// Android media session stub.
///
/// Production implementation will call into Android's
/// `MediaSession` / `MediaSessionCompat` via JNI.
/// This stub is a compile-time placeholder that satisfies the trait
/// on `target_os = "android"` without requiring a JNI runtime.
#[cfg(target_os = "android")]
#[derive(Debug, Default)]
pub struct AndroidMediaSession;

#[cfg(target_os = "android")]
impl MediaSessionService for AndroidMediaSession {
    /// JNI bridge placeholder — forwards metadata to Android MediaSession.
    fn update_metadata(&self, _info: &MediaSessionInfo) {
        // TODO(android): call JNI `NativeMediaSession.updateMetadata(title, artist, artworkUrl)`
    }

    /// JNI bridge placeholder — forwards playback position to Android.
    fn update_position(&self, _secs: f64) {
        // TODO(android): call JNI `NativeMediaSession.updatePosition(secs)`
    }

    /// JNI bridge placeholder — registers transport action handler.
    fn set_action_handler(
        &self,
        _action: MediaSessionAction,
        _handler: Box<dyn Fn() + Send + Sync>,
    ) {
        // TODO(android): route JNI callbacks → handler via global static registry
    }

    /// JNI bridge placeholder — clears the Android MediaSession.
    fn clear(&self) {
        // TODO(android): call JNI `NativeMediaSession.clear()`
    }
}

/// iOS media session stub.
///
/// Production implementation will use `MPNowPlayingInfoCenter` and
/// `MPRemoteCommandCenter` via ObjC bridge.
/// This stub is a compile-time placeholder for `target_os = "ios"`.
#[cfg(target_os = "ios")]
#[derive(Debug, Default)]
pub struct IosMediaSession;

#[cfg(target_os = "ios")]
impl MediaSessionService for IosMediaSession {
    /// ObjC bridge placeholder — updates `MPNowPlayingInfoCenter`.
    fn update_metadata(&self, _info: &MediaSessionInfo) {
        // TODO(ios): set MPNowPlayingInfoCenter.default().nowPlayingInfo
    }

    /// ObjC bridge placeholder — updates `MPNowPlayingInfoPropertyElapsedPlaybackTime`.
    fn update_position(&self, _secs: f64) {
        // TODO(ios): update elapsed playback time in nowPlayingInfo dict
    }

    /// ObjC bridge placeholder — registers `MPRemoteCommandCenter` handler.
    fn set_action_handler(
        &self,
        _action: MediaSessionAction,
        _handler: Box<dyn Fn() + Send + Sync>,
    ) {
        // TODO(ios): addTarget on the appropriate MPRemoteCommand
    }

    /// ObjC bridge placeholder — clears `MPNowPlayingInfoCenter`.
    fn clear(&self) {
        // TODO(ios): set nowPlayingInfo to nil
    }
}

/// Samsung DeX / iPad Stage Manager resizable-window media session stub.
///
/// On DeX the app can run in a resizable window; session integration
/// is identical to the base Android session but we track window mode
/// separately. Gated behind `cfg(target_os = "android")` because DeX
/// is an Android feature.
#[cfg(target_os = "android")]
#[derive(Debug, Default)]
pub struct DexMediaSession {
    /// Inner Android session delegate.
    inner: AndroidMediaSession,
}

#[cfg(target_os = "android")]
impl MediaSessionService for DexMediaSession {
    fn update_metadata(&self, info: &MediaSessionInfo) {
        self.inner.update_metadata(info);
    }
    fn update_position(&self, secs: f64) {
        self.inner.update_position(secs);
    }
    fn set_action_handler(&self, action: MediaSessionAction, handler: Box<dyn Fn() + Send + Sync>) {
        self.inner.set_action_handler(action, handler);
    }
    fn clear(&self) {
        self.inner.clear();
    }
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

    // ── Platform stub compilation tests ──────────────────────────────────────

    /// Verify the Android stub satisfies the trait on Android targets.
    #[cfg(target_os = "android")]
    #[test]
    fn android_media_session_implements_trait() {
        let svc: &dyn MediaSessionService = &AndroidMediaSession;
        svc.update_metadata(&make_info());
        svc.update_position(0.0);
        svc.set_action_handler(MediaSessionAction::Play, Box::new(|| {}));
        svc.clear();
    }

    /// Verify the DeX session delegates to the inner Android session.
    #[cfg(target_os = "android")]
    #[test]
    fn dex_media_session_delegates_without_panic() {
        let svc = DexMediaSession::default();
        svc.update_metadata(&make_info());
        svc.update_position(10.0);
        svc.set_action_handler(MediaSessionAction::Stop, Box::new(|| {}));
        svc.clear();
    }

    /// Verify the iOS stub satisfies the trait on iOS targets.
    #[cfg(target_os = "ios")]
    #[test]
    fn ios_media_session_implements_trait() {
        let svc: &dyn MediaSessionService = &IosMediaSession;
        svc.update_metadata(&make_info());
        svc.update_position(0.0);
        svc.set_action_handler(MediaSessionAction::Pause, Box::new(|| {}));
        svc.clear();
    }

    /// Confirm that on non-Android/iOS platforms only NoopMediaSession compiles.
    /// This test always runs — it guards the noop path on the dev platform.
    #[test]
    fn noop_is_default_platform_impl() {
        // NoopMediaSession must always be constructible regardless of target.
        let _svc = NoopMediaSession;
    }
}
