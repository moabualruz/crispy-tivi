//! URL construction helpers for Xtream Codes streams.
//!
//! These are synchronous, pure functions — no network calls.

use crate::types::{StreamFormat, StreamType};

/// Build a stream URL.
///
/// Format: `{base}/{type_segment}/{username}/{password}/{stream_id}.{ext}`
///
/// For RTMP channels, the extension is always `ts` per the upstream TS library.
pub fn build_stream_url(
    base_url: &str,
    username: &str,
    password: &str,
    stream_type: StreamType,
    stream_id: i64,
    extension: &str,
) -> String {
    let base = base_url.trim_end_matches('/');
    let segment = stream_type.path_segment();
    format!("{base}/{segment}/{username}/{password}/{stream_id}.{extension}")
}

/// Build a timeshift / catchup URL for a live channel.
///
/// Format: `{base}/timeshift/{username}/{password}/{duration}/{start}/{stream_id}.ts`
///
/// `start` should be formatted as `YYYY-MM-DD:HH-MM` (the Xtream convention).
pub fn build_timeshift_url(
    base_url: &str,
    username: &str,
    password: &str,
    stream_id: i64,
    duration_minutes: u32,
    start: &str,
) -> String {
    let base = base_url.trim_end_matches('/');
    format!("{base}/timeshift/{username}/{password}/{duration_minutes}/{start}/{stream_id}.ts")
}

/// Build the XMLTV EPG URL.
///
/// Format: `{base}/xmltv.php?username={user}&password={pass}`
pub fn build_xmltv_url(base_url: &str, username: &str, password: &str) -> String {
    let base = base_url.trim_end_matches('/');
    format!("{base}/xmltv.php?username={username}&password={password}")
}

/// Build the player API URL for a given action.
///
/// Format: `{base}/player_api.php?username={user}&password={pass}&action={action}`
pub fn build_api_url(base_url: &str, username: &str, password: &str, action: &str) -> String {
    let base = base_url.trim_end_matches('/');
    format!("{base}/player_api.php?username={username}&password={password}&action={action}")
}

/// Determine the effective format extension for a channel stream.
///
/// If the user's preferred format is in `allowed_formats`, use it.
/// Otherwise fall back to the first allowed format, or the preferred format
/// if the allowed list is empty (some servers return an empty array).
pub fn effective_channel_extension(preferred: StreamFormat, allowed_formats: &[String]) -> String {
    let pref_ext = preferred.extension();

    if allowed_formats.is_empty() {
        return pref_ext.to_string();
    }

    if allowed_formats.iter().any(|f| f == pref_ext) {
        return pref_ext.to_string();
    }

    // Fall back to first allowed format.
    allowed_formats
        .first()
        .map(std::string::String::as_str)
        .unwrap_or(pref_ext)
        .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn stream_url_live_channel() {
        let url = build_stream_url(
            "http://example.com",
            "user",
            "pass",
            StreamType::Channel,
            42,
            "ts",
        );
        assert_eq!(url, "http://example.com/live/user/pass/42.ts");
    }

    #[test]
    fn stream_url_movie() {
        let url = build_stream_url(
            "http://example.com/",
            "user",
            "pass",
            StreamType::Movie,
            99,
            "mp4",
        );
        assert_eq!(url, "http://example.com/movie/user/pass/99.mp4");
    }

    #[test]
    fn stream_url_episode() {
        let url = build_stream_url(
            "http://example.com",
            "user",
            "pass",
            StreamType::Episode,
            7,
            "mkv",
        );
        assert_eq!(url, "http://example.com/series/user/pass/7.mkv");
    }

    #[test]
    fn timeshift_url() {
        let url = build_timeshift_url(
            "http://example.com",
            "user",
            "pass",
            42,
            120,
            "2024-01-01:10-00",
        );
        assert_eq!(
            url,
            "http://example.com/timeshift/user/pass/120/2024-01-01:10-00/42.ts"
        );
    }

    #[test]
    fn xmltv_url() {
        let url = build_xmltv_url("http://example.com", "user", "pass");
        assert_eq!(
            url,
            "http://example.com/xmltv.php?username=user&password=pass"
        );
    }

    #[test]
    fn api_url() {
        let url = build_api_url("http://example.com", "user", "pass", "get_live_streams");
        assert_eq!(
            url,
            "http://example.com/player_api.php?username=user&password=pass&action=get_live_streams"
        );
    }

    #[test]
    fn effective_extension_preferred_in_list() {
        let allowed = vec!["ts".to_string(), "m3u8".to_string()];
        assert_eq!(
            effective_channel_extension(StreamFormat::M3u8, &allowed),
            "m3u8"
        );
    }

    #[test]
    fn effective_extension_fallback_to_first() {
        let allowed = vec!["m3u8".to_string()];
        assert_eq!(
            effective_channel_extension(StreamFormat::Ts, &allowed),
            "m3u8"
        );
    }

    #[test]
    fn effective_extension_empty_allowed() {
        let allowed: Vec<String> = vec![];
        assert_eq!(
            effective_channel_extension(StreamFormat::Ts, &allowed),
            "ts"
        );
    }

    #[test]
    fn trailing_slash_stripped() {
        let url = build_xmltv_url("http://example.com/", "u", "p");
        assert!(url.starts_with("http://example.com/xmltv"));
        assert!(!url.contains("//xmltv"));
    }
}
