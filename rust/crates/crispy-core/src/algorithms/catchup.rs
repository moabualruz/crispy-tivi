//! Catch-up / timeshift URL builder.
//!
//! Ports logic from Dart `catchup_url_builder.dart`.
//! Supports Xtream, Stalker Portal, and M3U catch-up
//! URL formats.

use chrono::{NaiveDateTime, Utc};
use serde::{Deserialize, Serialize};

use crate::models::{Channel, EpgEntry};

/// Resolved catch-up playback info.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CatchupInfo {
    /// Constructed catch-up stream URL.
    pub archive_url: String,
    /// Channel display name.
    pub channel_name: String,
    /// Programme title.
    pub program_title: String,
    /// Programme start time.
    pub start_time: NaiveDateTime,
    /// Programme end time.
    pub end_time: NaiveDateTime,
}

/// Build a catch-up URL for an Xtream-API channel.
///
/// Format:
/// `{base}/timeshift/{user}/{pass}/{dur}/{start}/{sid}.ts`
///
/// Returns `None` if the channel has no catch-up, the
/// programme is not in the past, or the stream ID cannot
/// be extracted from `channel.id`.
pub fn build_xtream_catchup(
    channel: &Channel,
    entry: &EpgEntry,
    base_url: &str,
    username: &str,
    password: &str,
) -> Option<CatchupInfo> {
    validate_catchup(channel, entry)?;

    // Extract numeric stream_id from "xc_123" format.
    let stream_id: i64 = channel.id.strip_prefix("xc_")?.parse().ok()?;

    let start_utc = entry.start_time.and_utc().timestamp();
    let duration_minutes = (entry.end_time - entry.start_time).num_minutes();

    let base = base_url.trim_end_matches('/');
    let url = format!(
        "{base}/timeshift/{username}/{password}/\
         {duration_minutes}/{start_utc}/{stream_id}.ts"
    );

    Some(CatchupInfo {
        archive_url: url,
        channel_name: channel.name.clone(),
        program_title: entry.title.clone(),
        start_time: entry.start_time,
        end_time: entry.end_time,
    })
}

/// Build a catch-up URL for a Stalker Portal channel.
///
/// Appends `?utc={start}&lutc={end}` (or `&` if the URL
/// already contains `?`).
pub fn build_stalker_catchup(
    channel: &Channel,
    entry: &EpgEntry,
    _base_url: &str,
) -> Option<CatchupInfo> {
    validate_catchup(channel, entry)?;

    let start_utc = entry.start_time.and_utc().timestamp();
    let end_utc = entry.end_time.and_utc().timestamp();

    let sep = if channel.stream_url.contains('?') {
        '&'
    } else {
        '?'
    };

    let url = format!("{}{sep}utc={start_utc}&lutc={end_utc}", channel.stream_url,);

    Some(CatchupInfo {
        archive_url: url,
        channel_name: channel.name.clone(),
        program_title: entry.title.clone(),
        start_time: entry.start_time,
        end_time: entry.end_time,
    })
}

/// Build a catch-up URL for an M3U channel.
///
/// Supports `catchup_source` templates, `flussonic` type,
/// and `shift` type.
pub fn build_m3u_catchup(channel: &Channel, entry: &EpgEntry) -> Option<CatchupInfo> {
    validate_catchup(channel, entry)?;

    let start_utc = entry.start_time.and_utc().timestamp();
    let end_utc = entry.end_time.and_utc().timestamp();
    let duration_secs = (entry.end_time - entry.start_time).num_seconds();

    let catchup_type = channel.catchup_type.as_deref().unwrap_or("");

    let url = if let Some(ref template) = channel.catchup_source {
        // Template-based: expand placeholders.
        expand_template(
            template,
            &channel.stream_url,
            start_utc,
            end_utc,
            duration_secs,
        )
    } else if catchup_type.eq_ignore_ascii_case("flussonic") {
        format!(
            "{}?start={}&duration={}",
            channel.stream_url, start_utc, duration_secs,
        )
    } else if catchup_type.eq_ignore_ascii_case("shift") {
        let sep = if channel.stream_url.contains('?') {
            '&'
        } else {
            '?'
        };
        format!("{}{}utc={}", channel.stream_url, sep, start_utc,)
    } else {
        return None;
    };

    Some(CatchupInfo {
        archive_url: url,
        channel_name: channel.name.clone(),
        program_title: entry.title.clone(),
        start_time: entry.start_time,
        end_time: entry.end_time,
    })
}

// ── helpers ────────────────────────────────────────────

/// Validate common catch-up preconditions.
///
/// Returns `None` if:
/// - Channel has no catch-up enabled.
/// - Programme is not in the past.
/// - Programme is outside the archive window.
fn validate_catchup(channel: &Channel, entry: &EpgEntry) -> Option<()> {
    if !channel.has_catchup {
        return None;
    }

    let now = Utc::now().naive_utc();

    // Programme must have already started.
    if entry.start_time >= now {
        return None;
    }

    // Check archive window.
    if channel.catchup_days > 0 {
        let archive_start = now - chrono::TimeDelta::days(channel.catchup_days as i64);
        if entry.start_time < archive_start {
            return None;
        }
    }

    Some(())
}

/// Expand a catchup_source template with time values.
fn expand_template(
    template: &str,
    stream_url: &str,
    start_utc: i64,
    end_utc: i64,
    duration_secs: i64,
) -> String {
    let start_str = start_utc.to_string();
    let end_str = end_utc.to_string();
    let dur_str = duration_secs.to_string();

    template
        .replace("{catchup_id}", stream_url)
        .replace("{utc_start}", &start_str)
        .replace("{utc}", &start_str)
        .replace("{start}", &start_str)
        .replace("{timestamp}", &start_str)
        .replace("{utc_end}", &end_str)
        .replace("{end}", &end_str)
        .replace("{duration}", &dur_str)
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::{TimeDelta, Utc};

    fn past_entry(minutes_ago: i64, duration_min: i64) -> EpgEntry {
        let now = Utc::now().naive_utc();
        let start = now - TimeDelta::minutes(minutes_ago);
        let end = start + TimeDelta::minutes(duration_min);
        EpgEntry {
            channel_id: "epg_ch1".to_string(),
            title: "Test Program".to_string(),
            start_time: start,
            end_time: end,
            ..EpgEntry::default()
        }
    }

    fn future_entry() -> EpgEntry {
        let now = Utc::now().naive_utc();
        let start = now + TimeDelta::hours(1);
        let end = start + TimeDelta::hours(1);
        EpgEntry {
            channel_id: "epg_ch1".to_string(),
            title: "Future Show".to_string(),
            start_time: start,
            end_time: end,
            ..EpgEntry::default()
        }
    }

    fn xtream_channel() -> Channel {
        Channel {
            id: "xc_42".to_string(),
            name: "Test Channel".to_string(),
            stream_url: "http://example.com/live/u/p/42.ts".to_string(),
            number: None,
            channel_group: None,
            logo_url: None,
            tvg_id: None,
            tvg_name: None,
            is_favorite: false,
            user_agent: None,
            has_catchup: true,
            catchup_days: 7,
            catchup_type: Some("xc".to_string()),
            catchup_source: None,
            resolution: None,
            source_id: None,
            added_at: None,
            updated_at: None,
            is_247: false,
            tvg_shift: None,
            tvg_language: None,
            tvg_country: None,
            parent_code: None,
            is_radio: false,
            tvg_rec: None,
            is_adult: false,
            custom_sid: None,
            direct_source: None,
            ..Default::default()
        }
    }

    fn stalker_channel() -> Channel {
        Channel {
            id: "stk_1".to_string(),
            name: "Stalker Ch".to_string(),
            stream_url: "http://portal.com/play/ch1".to_string(),
            number: None,
            channel_group: None,
            logo_url: None,
            tvg_id: None,
            tvg_name: None,
            is_favorite: false,
            user_agent: None,
            has_catchup: true,
            catchup_days: 3,
            catchup_type: Some("stalker".to_string()),
            catchup_source: None,
            resolution: None,
            source_id: None,
            added_at: None,
            updated_at: None,
            is_247: false,
            tvg_shift: None,
            tvg_language: None,
            tvg_country: None,
            parent_code: None,
            is_radio: false,
            tvg_rec: None,
            is_adult: false,
            custom_sid: None,
            direct_source: None,
            ..Default::default()
        }
    }

    fn m3u_channel(catchup_type: &str, source: Option<&str>) -> Channel {
        Channel {
            id: "m3u_1".to_string(),
            name: "M3U Channel".to_string(),
            stream_url: "http://stream.com/live/ch1".to_string(),
            number: None,
            channel_group: None,
            logo_url: None,
            tvg_id: None,
            tvg_name: None,
            is_favorite: false,
            user_agent: None,
            has_catchup: true,
            catchup_days: 5,
            catchup_type: Some(catchup_type.to_string()),
            catchup_source: source.map(String::from),
            resolution: None,
            source_id: None,
            added_at: None,
            updated_at: None,
            is_247: false,
            tvg_shift: None,
            tvg_language: None,
            tvg_country: None,
            parent_code: None,
            is_radio: false,
            tvg_rec: None,
            is_adult: false,
            custom_sid: None,
            direct_source: None,
            ..Default::default()
        }
    }

    // ── Xtream ─────────────────────────────────────────

    #[test]
    fn xtream_builds_url() {
        let ch = xtream_channel();
        let entry = past_entry(30, 60);
        let info = build_xtream_catchup(&ch, &entry, "http://example.com", "user", "pass");

        assert!(info.is_some());
        let info = info.unwrap();
        assert!(info.archive_url.contains("/timeshift/"));
        assert!(info.archive_url.contains("/user/pass/"));
        assert!(info.archive_url.contains("/42.ts"));
    }

    #[test]
    fn xtream_returns_none_for_future() {
        let ch = xtream_channel();
        let entry = future_entry();
        let info = build_xtream_catchup(&ch, &entry, "http://example.com", "user", "pass");

        assert!(info.is_none());
    }

    #[test]
    fn xtream_returns_none_without_catchup() {
        let mut ch = xtream_channel();
        ch.has_catchup = false;
        let entry = past_entry(30, 60);
        let info = build_xtream_catchup(&ch, &entry, "http://example.com", "user", "pass");

        assert!(info.is_none());
    }

    #[test]
    fn xtream_returns_none_for_bad_id() {
        let mut ch = xtream_channel();
        ch.id = "not_xtream_123".to_string();
        let entry = past_entry(30, 60);
        let info = build_xtream_catchup(&ch, &entry, "http://example.com", "user", "pass");

        assert!(info.is_none());
    }

    // ── Stalker ────────────────────────────────────────

    #[test]
    fn stalker_builds_url() {
        let ch = stalker_channel();
        let entry = past_entry(30, 60);
        let info = build_stalker_catchup(&ch, &entry, "");

        assert!(info.is_some());
        let url = &info.unwrap().archive_url;
        assert!(url.contains("?utc="));
        assert!(url.contains("&lutc="));
    }

    #[test]
    fn stalker_uses_ampersand_when_query_exists() {
        let mut ch = stalker_channel();
        ch.stream_url = "http://portal.com/play?id=1".to_string();
        let entry = past_entry(30, 60);
        let info = build_stalker_catchup(&ch, &entry, "");

        assert!(info.is_some());
        let url = &info.unwrap().archive_url;
        assert!(url.contains("&utc="));
    }

    // ── M3U ────────────────────────────────────────────

    #[test]
    fn m3u_flussonic_builds_url() {
        let ch = m3u_channel("flussonic", None);
        let entry = past_entry(30, 60);
        let info = build_m3u_catchup(&ch, &entry);

        assert!(info.is_some());
        let url = &info.unwrap().archive_url;
        assert!(url.contains("?start="));
        assert!(url.contains("&duration="));
    }

    #[test]
    fn m3u_shift_builds_url() {
        let ch = m3u_channel("shift", None);
        let entry = past_entry(30, 60);
        let info = build_m3u_catchup(&ch, &entry);

        assert!(info.is_some());
        let url = &info.unwrap().archive_url;
        assert!(url.contains("?utc="));
    }

    #[test]
    fn m3u_template_expands_placeholders() {
        let ch = m3u_channel(
            "default",
            Some(
                "{catchup_id}?utc={utc}&end={end}\
                 &dur={duration}",
            ),
        );
        let entry = past_entry(30, 60);
        let info = build_m3u_catchup(&ch, &entry);

        assert!(info.is_some());
        let url = &info.unwrap().archive_url;
        // Should have replaced {catchup_id} with
        // stream_url.
        assert!(url.starts_with("http://stream.com"));
        // Should NOT contain unreplaced placeholders.
        assert!(!url.contains('{'));
    }

    #[test]
    fn m3u_returns_none_unknown_type_no_template() {
        let ch = m3u_channel("unknown", None);
        let entry = past_entry(30, 60);
        let info = build_m3u_catchup(&ch, &entry);

        assert!(info.is_none());
    }

    // ── Template token expansion ────────────────────

    #[test]
    fn template_start_token_only() {
        let entry = past_entry(60, 30);
        let start_utc = entry.start_time.and_utc().timestamp();
        let url = expand_template(
            "http://cdn.com/play?start={start}",
            "http://stream.com/ch1",
            start_utc,
            start_utc + 1800,
            1800,
        );
        assert_eq!(url, format!("http://cdn.com/play?start={start_utc}"),);
    }

    #[test]
    fn template_end_token_only() {
        let entry = past_entry(60, 30);
        let start_utc = entry.start_time.and_utc().timestamp();
        let end_utc = start_utc + 1800;
        let url = expand_template(
            "http://cdn.com/play?end={end}",
            "http://stream.com/ch1",
            start_utc,
            end_utc,
            1800,
        );
        assert_eq!(url, format!("http://cdn.com/play?end={end_utc}"),);
    }

    #[test]
    fn template_duration_token_only() {
        let url = expand_template(
            "http://cdn.com/play?dur={duration}",
            "http://stream.com/ch1",
            1000,
            2800,
            1800,
        );
        assert_eq!(url, "http://cdn.com/play?dur=1800");
    }

    #[test]
    fn template_utc_and_utc_end_tokens() {
        let url = expand_template("http://cdn.com/{utc}/{utc_end}", "", 5000, 6000, 1000);
        assert_eq!(url, "http://cdn.com/5000/6000");
    }

    #[test]
    fn template_utc_start_token() {
        let url = expand_template("http://cdn.com/?s={utc_start}", "", 12345, 67890, 55545);
        assert_eq!(url, "http://cdn.com/?s=12345");
    }

    #[test]
    fn template_timestamp_token() {
        let url = expand_template("http://cdn.com/?ts={timestamp}", "", 99999, 100999, 1000);
        assert_eq!(url, "http://cdn.com/?ts=99999");
    }

    #[test]
    fn template_no_tokens_passthrough() {
        let url = expand_template(
            "http://cdn.com/static/video.ts",
            "http://stream.com/ch1",
            1000,
            2000,
            1000,
        );
        assert_eq!(url, "http://cdn.com/static/video.ts");
    }

    #[test]
    fn template_unknown_token_left_as_is() {
        let url = expand_template("http://cdn.com/{xyz}/{unknown}", "", 1000, 2000, 1000);
        // Unknown tokens are NOT expanded by the code.
        assert_eq!(url, "http://cdn.com/{xyz}/{unknown}");
    }

    #[test]
    fn template_catchup_id_replaces_with_stream_url() {
        let url = expand_template(
            "{catchup_id}?utc={utc}",
            "http://stream.com/live/ch42",
            5000,
            6000,
            1000,
        );
        assert_eq!(url, "http://stream.com/live/ch42?utc=5000",);
    }

    // ── Xtream edge cases ───────────────────────────

    #[test]
    fn xtream_trims_trailing_slash_from_base() {
        let ch = xtream_channel();
        let entry = past_entry(30, 60);
        let info = build_xtream_catchup(&ch, &entry, "http://example.com/", "u", "p");
        let url = &info.unwrap().archive_url;
        // Should NOT have double slash before timeshift.
        assert!(url.starts_with("http://example.com/timeshift/"));
        assert!(!url.contains("//timeshift"));
    }

    #[test]
    fn xtream_populates_metadata_fields() {
        let ch = xtream_channel();
        let entry = past_entry(30, 60);
        let info = build_xtream_catchup(&ch, &entry, "http://example.com", "user", "pass").unwrap();
        assert_eq!(info.channel_name, "Test Channel");
        assert_eq!(info.program_title, "Test Program");
        assert_eq!(info.start_time, entry.start_time);
        assert_eq!(info.end_time, entry.end_time);
    }

    // ── Catchup validation ──────────────────────────

    #[test]
    fn catchup_returns_none_when_outside_archive_window() {
        let mut ch = xtream_channel();
        ch.catchup_days = 1; // Only 1 day of archive.
        // Entry from 3 days ago — outside archive window.
        let entry = past_entry(3 * 24 * 60, 60);
        let info = build_xtream_catchup(&ch, &entry, "http://example.com", "user", "pass");
        assert!(info.is_none());
    }

    #[test]
    fn catchup_zero_days_disables_window_check() {
        let mut ch = xtream_channel();
        ch.catchup_days = 0; // No window limit.
        // Entry from 30 days ago — would fail a window
        // check but 0 means unlimited.
        let entry = past_entry(30 * 24 * 60, 60);
        let info = build_xtream_catchup(&ch, &entry, "http://example.com", "user", "pass");
        assert!(info.is_some());
    }

    // ── M3U shift with existing query ───────────────

    #[test]
    fn m3u_shift_uses_ampersand_when_query_exists() {
        let mut ch = m3u_channel("shift", None);
        ch.stream_url = "http://stream.com/live?token=abc".to_string();
        let entry = past_entry(30, 60);
        let info = build_m3u_catchup(&ch, &entry);
        let url = &info.unwrap().archive_url;
        assert!(url.contains("&utc="));
        assert!(!url.contains("?utc="));
    }
}
