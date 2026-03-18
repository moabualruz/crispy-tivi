//! Radio channel detection and sleep-timer service.
//!
//! Detection uses three heuristics (in priority order):
//!  1. `channel_group` contains "radio", "music", or "audio" (case-insensitive).
//!  2. The stream URL uses an audio-only MIME extension (`.mp3`, `.aac`, …).
//!  3. The channel name itself contains "radio" (case-insensitive).
//!
//! The sleep timer is in-process state only — it is not persisted to the DB.

use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use crate::models::Channel;

// ── Radio detection ───────────────────────────────────────────────────────────

/// Audio-only file extensions that indicate a radio/audio stream.
const AUDIO_EXTENSIONS: &[&str] = &[".mp3", ".aac", ".flac", ".ogg", ".m4a", ".opus", ".wav"];

/// Group-title keywords that indicate a radio category.
const RADIO_GROUP_KEYWORDS: &[&str] = &["radio", "music", "audio"];

/// Return `true` when the channel is likely a radio / audio-only stream.
pub fn is_radio_channel(channel: &Channel) -> bool {
    // 1. Group title keyword match.
    if let Some(group) = &channel.channel_group {
        let lower = group.to_lowercase();
        if RADIO_GROUP_KEYWORDS.iter().any(|kw| lower.contains(kw)) {
            return true;
        }
    }

    // 2. Stream URL uses an audio-only extension.
    let url_lower = channel.stream_url.to_lowercase();
    if AUDIO_EXTENSIONS.iter().any(|ext| url_lower.ends_with(ext)) {
        return true;
    }

    // 3. Channel name contains "radio".
    channel.name.to_lowercase().contains("radio")
}

/// Filter `channels` returning only those identified as radio/audio streams.
pub fn get_radio_channels<'a>(channels: &'a [Channel]) -> Vec<&'a Channel> {
    channels.iter().filter(|c| is_radio_channel(c)).collect()
}

// ── Sleep timer ───────────────────────────────────────────────────────────────

/// Shared sleep-timer state — cheaply cloneable via `Arc`.
#[derive(Clone, Default)]
pub struct SleepTimer {
    inner: Arc<Mutex<SleepTimerInner>>,
}

#[derive(Default)]
struct SleepTimerInner {
    /// None means the timer is inactive.
    deadline: Option<Instant>,
    duration: Duration,
}

impl SleepTimer {
    pub fn new() -> Self {
        Self::default()
    }

    /// Start (or restart) the timer for `duration`.
    pub fn start(&self, duration: Duration) {
        let mut guard = self.inner.lock().unwrap();
        guard.deadline = Some(Instant::now() + duration);
        guard.duration = duration;
    }

    /// Cancel an active timer.
    pub fn cancel(&self) {
        let mut guard = self.inner.lock().unwrap();
        guard.deadline = None;
    }

    /// Return the remaining duration, or `None` if the timer is inactive or
    /// has already expired.
    pub fn get_remaining(&self) -> Option<Duration> {
        let guard = self.inner.lock().unwrap();
        let deadline = guard.deadline?;
        let now = Instant::now();
        if now >= deadline {
            None
        } else {
            Some(deadline - now)
        }
    }

    /// Return `true` when the timer is active and has not yet expired.
    pub fn is_active(&self) -> bool {
        self.get_remaining().is_some()
    }

    /// Return `true` when the timer was started and has now fired (elapsed).
    ///
    /// The timer remains in "expired" state until `cancel()` or a new
    /// `start()` call resets it.
    pub fn has_fired(&self) -> bool {
        let guard = self.inner.lock().unwrap();
        match guard.deadline {
            Some(d) => Instant::now() >= d,
            None => false,
        }
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use std::thread;

    use super::*;
    use crate::services::test_helpers::make_channel;

    fn ch(name: &str, group: Option<&str>, url: &str) -> Channel {
        let mut c = make_channel("id", name);
        c.channel_group = group.map(|s| s.to_string());
        c.stream_url = url.to_string();
        c
    }

    // ── Detection ──────────────────────────────────

    #[test]
    fn test_group_radio_detected() {
        assert!(is_radio_channel(&ch(
            "BBC News",
            Some("Radio UK"),
            "http://stream"
        )));
    }

    #[test]
    fn test_group_music_detected() {
        assert!(is_radio_channel(&ch(
            "Pop Hits",
            Some("Music"),
            "http://stream"
        )));
    }

    #[test]
    fn test_group_audio_detected() {
        assert!(is_radio_channel(&ch(
            "Podcast",
            Some("Audio"),
            "http://feed"
        )));
    }

    #[test]
    fn test_mp3_url_detected() {
        assert!(is_radio_channel(&ch(
            "Station",
            None,
            "http://stream.example.com/live.mp3"
        )));
    }

    #[test]
    fn test_aac_url_detected() {
        assert!(is_radio_channel(&ch(
            "Station",
            None,
            "http://stream.example.com/live.aac"
        )));
    }

    #[test]
    fn test_channel_name_radio_detected() {
        assert!(is_radio_channel(&ch("Radio 4", None, "http://live.ts")));
    }

    #[test]
    fn test_normal_tv_channel_not_detected() {
        assert!(!is_radio_channel(&ch(
            "CNN",
            Some("News"),
            "http://live.ts"
        )));
    }

    #[test]
    fn test_get_radio_channels_filters_correctly() {
        let channels = vec![
            ch("BBC Radio 1", Some("Radio"), "http://stream"),
            ch("CNN", Some("News"), "http://stream"),
            ch("Jazz FM", None, "http://jazz.mp3"),
        ];
        let radio = get_radio_channels(&channels);
        assert_eq!(radio.len(), 2);
        assert_eq!(radio[0].name, "BBC Radio 1");
        assert_eq!(radio[1].name, "Jazz FM");
    }

    // ── Sleep timer ────────────────────────────────

    #[test]
    fn test_timer_inactive_by_default() {
        let t = SleepTimer::new();
        assert!(!t.is_active());
        assert!(t.get_remaining().is_none());
    }

    #[test]
    fn test_timer_starts_and_is_active() {
        let t = SleepTimer::new();
        t.start(Duration::from_secs(60));
        assert!(t.is_active());
        let rem = t.get_remaining().unwrap();
        // Allow ±1 s of test jitter.
        assert!(rem <= Duration::from_secs(60));
        assert!(rem > Duration::from_secs(58));
    }

    #[test]
    fn test_timer_cancel() {
        let t = SleepTimer::new();
        t.start(Duration::from_secs(60));
        t.cancel();
        assert!(!t.is_active());
    }

    #[test]
    fn test_timer_fires_after_duration() {
        let t = SleepTimer::new();
        t.start(Duration::from_millis(10));
        thread::sleep(Duration::from_millis(20));
        assert!(t.has_fired());
        assert!(!t.is_active());
    }

    #[test]
    fn test_timer_restart() {
        let t = SleepTimer::new();
        t.start(Duration::from_millis(10));
        thread::sleep(Duration::from_millis(20));
        // Restart with a long duration.
        t.start(Duration::from_secs(60));
        assert!(t.is_active());
        assert!(!t.has_fired());
    }
}
