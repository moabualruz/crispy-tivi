//! Catchup/timeshift URL template system for IPTV channels.
//!
//! Translated from Kodi pvr.iptvsimple's `CatchupController` and `Channel`
//! catchup logic. Provides:
//!
//! - **Mode configuration** — 8 catchup modes with automatic source generation
//! - **Template engine** — variable substitution for time-based URL placeholders
//! - **Provider parsing** — Flussonic and Xtream Codes URL regex extraction
//! - **Window validation** — catchup availability checking
//! - **EPG-tag processors** — convenience wrappers for programme/channel playback

pub mod error;
pub mod mode;
pub mod provider;
pub mod template;

pub use error::CatchupError;
pub use mode::{CatchupConfig, CatchupMode, IGNORE_CATCHUP_DAYS, configure_catchup};
pub use template::{
    format_catchup_url, format_catchup_url_with_granularity, format_now_only,
    is_within_catchup_window,
};

use chrono::Utc;

/// Build a catchup URL for time-shifted playback of a specific EPG programme.
///
/// Translated from the logic in `CatchupController::ProcessEPGTagForTimeshiftedPlayback()`
/// and `CatchupController::GetCatchupUrl()`. Takes programme start/end times and
/// produces the fully-substituted URL using the channel's catchup source template.
///
/// # Arguments
/// * `config` - The channel's resolved catchup configuration.
/// * `programme_start` - Programme start time (UTC epoch seconds).
/// * `programme_end` - Programme end time (UTC epoch seconds).
/// * `programme_catchup_id` - Optional catchup-id from the EPG entry.
/// * `timezone_shift_secs` - Combined tvg-shift + catchup correction in seconds.
pub fn process_programme_for_timeshift(
    config: &CatchupConfig,
    programme_start: i64,
    programme_end: i64,
    programme_catchup_id: Option<&str>,
    timezone_shift_secs: i32,
) -> String {
    let mut duration = programme_end - programme_start;

    // Cap duration to now (can't timeshift into the future)
    let now = Utc::now().timestamp();
    if programme_start + duration > now {
        duration = now - programme_start;
    }
    if duration < 0 {
        duration = 0;
    }

    format_catchup_url_with_granularity(
        &config.source,
        programme_start,
        duration,
        programme_catchup_id,
        timezone_shift_secs,
        config.granularity_seconds,
    )
}

/// Build a catchup URL for VOD playback of an EPG programme.
///
/// Translated from `CatchupController::ProcessEPGTagForVideoPlayback()`.
/// For VOD mode, the catchup source is typically just `{catchup-id}` or a
/// URL template containing `{catchup-id}`. This function substitutes the
/// catchup-id and processes any remaining time placeholders.
///
/// # Arguments
/// * `config` - The channel's resolved catchup configuration.
/// * `programme_catchup_id` - The catchup-id from the EPG entry.
pub fn process_programme_for_vod(config: &CatchupConfig, programme_catchup_id: &str) -> String {
    // VOD sources are typically just {catchup-id} or a URL with {catchup-id}.
    // We substitute it directly, using a minimal time context (now-based).
    let now = Utc::now().timestamp();
    format_catchup_url_with_granularity(
        &config.source,
        now,
        0,
        Some(programme_catchup_id),
        0,
        config.granularity_seconds,
    )
}

/// Build a live-stream URL with catchup "now" placeholders substituted.
///
/// Translated from `CatchupController::ProcessStreamUrl()` and
/// `CatchupController::ProcessChannelForPlayback()`. Used when a channel
/// supports catchup but is currently playing live — processes `{lutc}`,
/// `${now}`, `${timestamp}` and similar now-only placeholders.
///
/// # Arguments
/// * `config` - The channel's resolved catchup configuration.
pub fn process_channel_for_live(config: &CatchupConfig) -> String {
    format_now_only(&config.source, 0, 0, 0)
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::TimeZone;

    fn fixed_start() -> i64 {
        Utc.with_ymd_and_hms(2024, 3, 15, 14, 30, 45)
            .unwrap()
            .timestamp()
    }

    fn make_config(source: &str, granularity: i32) -> CatchupConfig {
        CatchupConfig {
            mode: CatchupMode::Default,
            source: source.to_string(),
            catchup_days: 7,
            supports_timeshifting: true,
            terminates: true,
            granularity_seconds: granularity,
            is_ts_stream: false,
        }
    }

    #[test]
    fn process_programme_for_timeshift_produces_correct_url() {
        let start = fixed_start();
        let end = start + 3600;
        let config = make_config(
            "http://example.com/catchup?start={utc}&end={utcend}&id={catchup-id}",
            1,
        );

        let result = process_programme_for_timeshift(&config, start, end, Some("prog_123"), 0);

        assert!(result.contains(&format!("start={start}")));
        assert!(result.contains("id=prog_123"));
        // end depends on now-capping, but should not contain raw placeholder
        assert!(!result.contains("{utc}"));
        assert!(!result.contains("{utcend}"));
        assert!(!result.contains("{catchup-id}"));
    }

    #[test]
    fn process_programme_for_vod_substitutes_catchup_id() {
        let config = make_config("http://example.com/vod/{catchup-id}", 1);

        let result = process_programme_for_vod(&config, "movie_456");

        assert_eq!(result, "http://example.com/vod/movie_456");
    }

    #[test]
    fn process_channel_for_live_uses_current_time() {
        let config = make_config("http://example.com/live?now=${now}", 1);

        let before = Utc::now().timestamp();
        let result = process_channel_for_live(&config);
        let after = Utc::now().timestamp();

        // Extract the now value and verify it's approximately current time
        let now_str = result.split("now=").nth(1).unwrap();
        let now_val: i64 = now_str.parse().expect("should be a timestamp");
        assert!(now_val >= before && now_val <= after);
    }
}
