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

/// Metadata for an audio or subtitle track reported by mpv.
#[derive(Debug, Clone, PartialEq)]
pub struct TrackInfo {
    /// mpv track id (used for aid / sid property values).
    pub id: i64,
    /// Human-readable title, if present in the stream.
    pub title: Option<String>,
    /// BCP-47 / ISO 639 language tag, if present.
    pub language: Option<String>,
    /// Codec identifier string (e.g. "aac", "h264", "subrip").
    pub codec: Option<String>,
    /// Whether this track is the default for its type.
    pub is_default: bool,
}

/// Demuxer buffer statistics for timeshift monitoring.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BufferStats {
    /// Seconds of content currently buffered ahead of playback position.
    pub cache_duration: f64,
    /// Approximate bytes currently held in the demuxer cache.
    pub cache_used_bytes: u64,
}

/// Video stream / decoder information.
#[derive(Debug, Clone, PartialEq)]
pub struct VideoInfo {
    /// Decoded frame width in pixels.
    pub width: u32,
    /// Decoded frame height in pixels.
    pub height: u32,
    /// Video codec identifier (e.g. "h264", "hevc").
    pub codec: String,
    /// Active hardware-decode method (e.g. "d3d11va", "vaapi", "none").
    pub hwdec_active: String,
    /// Container/stream frame rate (frames per second).
    pub fps: f64,
}

/// Trait that all video backends must implement.
///
/// Single implementation: libmpv for all platforms.
pub trait PlayerBackend: Send + Sync {
    // ── Playback control ──────────────────────────────────────────────────

    /// Start playback of the given URL or file path.
    fn play(&self, url: &str) -> Result<(), PlayerError>;

    /// Pause or resume playback (toggles between Playing ↔ Paused).
    fn pause(&self) -> Result<(), PlayerError>;

    /// Seek to an absolute position in seconds.
    fn seek(&self, position_secs: f64) -> Result<(), PlayerError>;

    /// Seek relative to the current position (negative = rewind).
    fn seek_relative(&self, offset_secs: f64) -> Result<(), PlayerError>;

    /// Set volume (0.0 = mute, 1.0 = 100%).
    fn set_volume(&self, volume: f32) -> Result<(), PlayerError>;

    /// Stop playback and release the current media.
    fn stop(&self) -> Result<(), PlayerError>;

    /// Query the current player state.
    fn state(&self) -> PlayerState;

    // ── Speed ─────────────────────────────────────────────────────────────

    /// Set playback speed multiplier (1.0 = normal, 2.0 = double speed).
    /// Valid range is [0.01, 100.0]; values outside this range return `PlayerError::Playback`.
    fn set_speed(&self, speed: f64) -> Result<(), PlayerError>;

    /// Return the current playback speed multiplier.
    fn get_speed(&self) -> f64;

    // ── Position / duration ───────────────────────────────────────────────

    /// Return current playback position in seconds (0.0 when no media loaded).
    fn get_position(&self) -> f64;

    /// Return total duration in seconds (0.0 for live streams or when unknown).
    fn get_duration(&self) -> f64;

    // ── Tracks ────────────────────────────────────────────────────────────

    /// Enumerate all audio tracks reported by mpv.
    fn get_audio_tracks(&self) -> Vec<TrackInfo>;

    /// Enumerate all subtitle tracks reported by mpv.
    fn get_subtitle_tracks(&self) -> Vec<TrackInfo>;

    /// Activate an audio track by its mpv track id.
    fn set_audio_track(&self, id: i64) -> Result<(), PlayerError>;

    /// Activate a subtitle track by its mpv track id, or disable subtitles (`None`).
    fn set_subtitle_track(&self, id: Option<i64>) -> Result<(), PlayerError>;

    // ── Timeshift buffer ──────────────────────────────────────────────────

    /// Configure demuxer buffer limits for timeshift operation.
    ///
    /// `max_bytes` controls how far ahead mpv buffers (forward window).
    /// `max_back_bytes` controls how far back the user can seek (back window).
    fn set_timeshift_buffer(&self, max_bytes: u64, max_back_bytes: u64);

    /// Return current demuxer buffer statistics.
    fn get_buffer_stats(&self) -> BufferStats;

    // ── Video / decoder info ──────────────────────────────────────────────

    /// Return current video stream and decoder metadata.
    fn get_video_info(&self) -> VideoInfo;

    /// Return the currently active hardware-decode method string
    /// (reads mpv `hwdec-current` property; "none" when software decoding).
    fn get_hwdec_status(&self) -> String;

    // ── Property observation ──────────────────────────────────────────────

    /// Register a callback that fires whenever the playback position changes.
    /// The callback receives the new position in seconds.
    fn on_position_change(&self, callback: Box<dyn Fn(f64) + Send + Sync + 'static>);

    /// Register a callback that fires whenever the player state changes.
    fn on_state_change(&self, callback: Box<dyn Fn(PlayerState) + Send + Sync + 'static>);

    /// Register a callback that fires whenever the active track changes
    /// (e.g. audio or subtitle track switch, or new tracks detected).
    fn on_track_change(&self, callback: Box<dyn Fn() + Send + Sync + 'static>);
}

// ── Tests ────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use mockall::mock;

    use super::*;

    mock! {
        /// Mock implementation of PlayerBackend for testing.
        pub TestBackend {}

        impl PlayerBackend for TestBackend {
            fn play(&self, url: &str) -> Result<(), PlayerError>;
            fn pause(&self) -> Result<(), PlayerError>;
            fn seek(&self, position_secs: f64) -> Result<(), PlayerError>;
            fn seek_relative(&self, offset_secs: f64) -> Result<(), PlayerError>;
            fn set_volume(&self, volume: f32) -> Result<(), PlayerError>;
            fn stop(&self) -> Result<(), PlayerError>;
            fn state(&self) -> PlayerState;
            fn set_speed(&self, speed: f64) -> Result<(), PlayerError>;
            fn get_speed(&self) -> f64;
            fn get_position(&self) -> f64;
            fn get_duration(&self) -> f64;
            fn get_audio_tracks(&self) -> Vec<TrackInfo>;
            fn get_subtitle_tracks(&self) -> Vec<TrackInfo>;
            fn set_audio_track(&self, id: i64) -> Result<(), PlayerError>;
            fn set_subtitle_track(&self, id: Option<i64>) -> Result<(), PlayerError>;
            fn set_timeshift_buffer(&self, max_bytes: u64, max_back_bytes: u64);
            fn get_buffer_stats(&self) -> BufferStats;
            fn get_video_info(&self) -> VideoInfo;
            fn get_hwdec_status(&self) -> String;
            fn on_position_change(&self, callback: Box<dyn Fn(f64) + Send + Sync + 'static>);
            fn on_state_change(&self, callback: Box<dyn Fn(PlayerState) + Send + Sync + 'static>);
            fn on_track_change(&self, callback: Box<dyn Fn() + Send + Sync + 'static>);
        }
    }

    // ── State transition tests ────────────────────────────────────────────

    #[test]
    fn test_mock_backend_play_returns_ok() {
        let mut mock = MockTestBackend::new();
        mock.expect_play()
            .withf(|url| url.starts_with("http"))
            .returning(|_| Ok(()));
        mock.expect_state().returning(|| PlayerState::Playing);

        let result = mock.play("http://example.com/stream.ts");
        assert!(result.is_ok());
        assert_eq!(mock.state(), PlayerState::Playing);
    }

    #[test]
    fn test_mock_backend_idle_to_playing_to_paused_to_playing_to_stopped() {
        let mut mock = MockTestBackend::new();
        let mut seq = mockall::Sequence::new();

        mock.expect_state()
            .times(1)
            .in_sequence(&mut seq)
            .returning(|| PlayerState::Idle);
        mock.expect_play()
            .times(1)
            .in_sequence(&mut seq)
            .returning(|_| Ok(()));
        mock.expect_state()
            .times(1)
            .in_sequence(&mut seq)
            .returning(|| PlayerState::Playing);
        mock.expect_pause()
            .times(1)
            .in_sequence(&mut seq)
            .returning(|| Ok(()));
        mock.expect_state()
            .times(1)
            .in_sequence(&mut seq)
            .returning(|| PlayerState::Paused);
        mock.expect_pause()
            .times(1)
            .in_sequence(&mut seq)
            .returning(|| Ok(()));
        mock.expect_state()
            .times(1)
            .in_sequence(&mut seq)
            .returning(|| PlayerState::Playing);
        mock.expect_stop()
            .times(1)
            .in_sequence(&mut seq)
            .returning(|| Ok(()));
        mock.expect_state()
            .times(1)
            .in_sequence(&mut seq)
            .returning(|| PlayerState::Stopped);

        assert_eq!(mock.state(), PlayerState::Idle);
        assert!(mock.play("http://example.com/live.ts").is_ok());
        assert_eq!(mock.state(), PlayerState::Playing);
        assert!(mock.pause().is_ok());
        assert_eq!(mock.state(), PlayerState::Paused);
        assert!(mock.pause().is_ok()); // resume
        assert_eq!(mock.state(), PlayerState::Playing);
        assert!(mock.stop().is_ok());
        assert_eq!(mock.state(), PlayerState::Stopped);
    }

    #[test]
    fn test_mock_backend_stop_transitions_to_stopped() {
        let mut mock = MockTestBackend::new();
        mock.expect_stop().returning(|| Ok(()));
        mock.expect_state().returning(|| PlayerState::Stopped);

        assert!(mock.stop().is_ok());
        assert_eq!(mock.state(), PlayerState::Stopped);
    }

    // ── Seek tests ────────────────────────────────────────────────────────

    #[test]
    fn test_mock_backend_seek_absolute() {
        let mut mock = MockTestBackend::new();
        mock.expect_seek()
            .withf(|&pos| pos == 120.0)
            .returning(|_| Ok(()));

        assert!(mock.seek(120.0).is_ok());
    }

    #[test]
    fn test_mock_backend_seek_relative_forward() {
        let mut mock = MockTestBackend::new();
        mock.expect_seek_relative()
            .withf(|&offset| offset == 10.0)
            .returning(|_| Ok(()));

        assert!(mock.seek_relative(10.0).is_ok());
    }

    #[test]
    fn test_mock_backend_seek_relative_backward() {
        let mut mock = MockTestBackend::new();
        mock.expect_seek_relative()
            .withf(|&offset| offset == -10.0)
            .returning(|_| Ok(()));

        assert!(mock.seek_relative(-10.0).is_ok());
    }

    // ── Speed tests ───────────────────────────────────────────────────────

    #[test]
    fn test_mock_backend_set_speed_normal() {
        let mut mock = MockTestBackend::new();
        mock.expect_set_speed()
            .withf(|&s| s == 1.0)
            .returning(|_| Ok(()));
        mock.expect_get_speed().returning(|| 1.0);

        assert!(mock.set_speed(1.0).is_ok());
        assert!((mock.get_speed() - 1.0).abs() < f64::EPSILON);
    }

    #[test]
    fn test_mock_backend_set_speed_double() {
        let mut mock = MockTestBackend::new();
        mock.expect_set_speed()
            .withf(|&s| s == 2.0)
            .returning(|_| Ok(()));
        mock.expect_get_speed().returning(|| 2.0);

        assert!(mock.set_speed(2.0).is_ok());
        assert!((mock.get_speed() - 2.0).abs() < f64::EPSILON);
    }

    #[test]
    fn test_mock_backend_set_speed_invalid_too_low() {
        let mut mock = MockTestBackend::new();
        mock.expect_set_speed()
            .withf(|&s| s < 0.01)
            .returning(|_| Err(PlayerError::Playback("speed out of range".into())));

        assert!(mock.set_speed(0.0).is_err());
    }

    #[test]
    fn test_mock_backend_set_speed_invalid_too_high() {
        let mut mock = MockTestBackend::new();
        mock.expect_set_speed()
            .withf(|&s| s > 100.0)
            .returning(|_| Err(PlayerError::Playback("speed out of range".into())));

        assert!(mock.set_speed(200.0).is_err());
    }

    // ── Track enumeration and selection ──────────────────────────────────

    #[test]
    fn test_mock_backend_get_audio_tracks_returns_list() {
        let mut mock = MockTestBackend::new();
        mock.expect_get_audio_tracks().returning(|| {
            vec![
                TrackInfo {
                    id: 1,
                    title: Some("English".into()),
                    language: Some("eng".into()),
                    codec: Some("aac".into()),
                    is_default: true,
                },
                TrackInfo {
                    id: 2,
                    title: Some("Arabic".into()),
                    language: Some("ara".into()),
                    codec: Some("aac".into()),
                    is_default: false,
                },
            ]
        });

        let tracks = mock.get_audio_tracks();
        assert_eq!(tracks.len(), 2);
        assert_eq!(tracks[0].id, 1);
        assert_eq!(tracks[0].language.as_deref(), Some("eng"));
        assert!(tracks[0].is_default);
        assert_eq!(tracks[1].id, 2);
        assert!(!tracks[1].is_default);
    }

    #[test]
    fn test_mock_backend_get_subtitle_tracks_empty_when_none() {
        let mut mock = MockTestBackend::new();
        mock.expect_get_subtitle_tracks().returning(Vec::new);

        assert!(mock.get_subtitle_tracks().is_empty());
    }

    #[test]
    fn test_mock_backend_set_audio_track_ok() {
        let mut mock = MockTestBackend::new();
        mock.expect_set_audio_track()
            .withf(|&id| id == 2)
            .returning(|_| Ok(()));

        assert!(mock.set_audio_track(2).is_ok());
    }

    #[test]
    fn test_mock_backend_set_subtitle_track_some() {
        let mut mock = MockTestBackend::new();
        mock.expect_set_subtitle_track()
            .withf(|id| *id == Some(3))
            .returning(|_| Ok(()));

        assert!(mock.set_subtitle_track(Some(3)).is_ok());
    }

    #[test]
    fn test_mock_backend_set_subtitle_track_none_disables() {
        let mut mock = MockTestBackend::new();
        mock.expect_set_subtitle_track()
            .withf(|id| id.is_none())
            .returning(|_| Ok(()));

        assert!(mock.set_subtitle_track(None).is_ok());
    }

    // ── Misc ──────────────────────────────────────────────────────────────

    #[test]
    fn test_player_state_equality() {
        assert_eq!(PlayerState::Idle, PlayerState::Idle);
        assert_ne!(PlayerState::Playing, PlayerState::Paused);
    }

    #[test]
    fn test_player_error_display() {
        let err = PlayerError::Playback("codec error".to_string());
        assert!(err.to_string().contains("codec error"));

        let err2 = PlayerError::NotInitialized;
        assert!(err2.to_string().contains("not initialized"));
    }

    #[test]
    fn test_track_info_fields() {
        let t = TrackInfo {
            id: 5,
            title: None,
            language: Some("fra".into()),
            codec: Some("eac3".into()),
            is_default: false,
        };
        assert_eq!(t.id, 5);
        assert!(t.title.is_none());
        assert_eq!(t.language.as_deref(), Some("fra"));
    }
}
