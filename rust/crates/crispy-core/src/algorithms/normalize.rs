//! Name and URL normalization utilities.
//!
//! Shared helpers used by other algorithm modules for
//! fuzzy matching, deduplication, and timestamp parsing.

use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use chrono::NaiveDateTime;
use regex::Regex;
use std::sync::LazyLock;

static NON_ALNUM_SPACE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"[^a-z0-9\s]").unwrap());

static MULTI_SPACE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\s+").unwrap());

static MAC_ADDR: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$").unwrap());

/// Quality suffix pattern — ordered longest-first to avoid partial matches.
/// Matches as a whole word at the end of the string (case-insensitive).
#[allow(dead_code)] // Used by channel dedup pipeline in Epoch 5.12 UI wiring
static QUALITY_SUFFIX: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)\s+(H\.265|H\.264|HEVC|H265|H264|FHD|UHD|4K|SD|HD)\s*$").unwrap()
});

/// Trailing 2–3 letter country code preceded by a space (e.g. " US", " UK", " DE").
/// Only matches at end of string.
#[allow(dead_code)] // Used by channel dedup pipeline in Epoch 5.12 UI wiring
static COUNTRY_CODE_SUFFIX: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r" [A-Z]{2,3}$").unwrap());

/// Normalize a channel/programme name for fuzzy matching.
///
/// Lowercase, strip non-alphanumeric (except spaces),
/// collapse whitespace, trim.
pub fn normalize_name(name: &str) -> String {
    let lower = name.to_lowercase();
    let stripped = NON_ALNUM_SPACE.replace_all(&lower, "");
    let collapsed = MULTI_SPACE.replace_all(&stripped, " ");
    collapsed.trim().to_string()
}

/// Normalize a stream URL for comparison.
///
/// Lowercase, strip query params and trailing slashes,
/// keep scheme+host+port+path.
pub fn normalize_url(url: &str) -> String {
    let lower = url.to_lowercase();

    // Split on '?' to strip query params.
    let base = lower.split('?').next().unwrap_or(&lower);

    // Split on '#' to strip fragment.
    let base = base.split('#').next().unwrap_or(base);

    // Remove trailing slashes.
    base.trim_end_matches('/').to_string()
}

/// Try to base64-decode a string; returns original if not
/// valid base64.
pub fn try_base64_decode(value: &str) -> String {
    // Skip values that look like XML or contain spaces.
    if value.contains(' ') || value.contains('<') || value.len() < 8 || !value.len().is_multiple_of(4) {
        return value.to_string();
    }

    match STANDARD.decode(value) {
        Ok(bytes) => String::from_utf8_lossy(&bytes).into_owned(),
        Err(_) => value.to_string(),
    }
}

/// EPG timestamp format used by Xtream providers.
pub const EPG_FORMAT: &str = "%Y-%m-%d %H:%M:%S";

/// Parse an Xtream EPG timestamp string.
///
/// Primary format: `"2024-02-16 15:00:00"` (space-separated,
/// no timezone, treated as UTC). Falls back to RFC 3339
/// (e.g. `"2024-01-15T06:00:00Z"`) for providers that use
/// ISO 8601 format.
pub fn parse_epg_timestamp(value: &str) -> Option<NaiveDateTime> {
    NaiveDateTime::parse_from_str(value.trim(), EPG_FORMAT)
        .ok()
        .or_else(|| {
            chrono::DateTime::parse_from_rfc3339(value.trim())
                .ok()
                .map(|dt| dt.naive_utc())
        })
}

/// Validate a MAC address format (XX:XX:XX:XX:XX:XX).
///
/// Each XX must be 2 hex digits. Case-insensitive.
pub fn validate_mac_address(mac: &str) -> bool {
    MAC_ADDR.is_match(mac)
}

/// Strip a trailing quality suffix from a channel name.
///
/// Removes tokens like `HD`, `FHD`, `4K`, `UHD`, `SD`, `H.265`, `HEVC`, `H.264`
/// when they appear at the end of the name (case-insensitive, preceded by whitespace).
/// Ordered longest-first internally to avoid partial matches (e.g. "FHD" before "HD").
///
#[allow(dead_code)] // Used by channel dedup pipeline in Epoch 5.12 UI wiring
pub(crate) fn strip_quality_suffix(name: &str) -> String {
    QUALITY_SUFFIX.replace(name, "").trim().to_string()
}

/// Strip a trailing 2–3 letter country code from a channel name.
///
/// Removes tokens like ` US`, ` UK`, ` DE`, ` FR` only when they appear
/// at the very end of the name, preceded by a space.  Embedded country
/// codes (e.g. "ABC USA Network") are left untouched.
///
#[allow(dead_code)] // Used by channel dedup pipeline in Epoch 5.12 UI wiring
pub(crate) fn strip_country_code(name: &str) -> String {
    COUNTRY_CODE_SUFFIX.replace(name, "").to_string()
}

/// Normalize a category string for matching.
///
/// Converts to lowercase and trims whitespace. Used for
/// genre/category comparisons in recommendation and
/// popularity algorithms.
pub fn normalize_category(s: &str) -> String {
    s.to_lowercase().trim().to_string()
}

/// Strip colons from a MAC address to get a device ID.
///
/// e.g. `"00:1A:2B:3C:4D:5E"` becomes `"001A2B3C4D5E"`.
pub fn mac_to_device_id(mac: &str) -> String {
    mac.replace(':', "")
}

/// Guess search domains for a channel logo lookup.
///
/// Given a channel name, returns a list of candidate
/// domain strings (e.g., `"bbc"`, `"bbc.com"`,
/// `"bbc.tv"`, `"bbc.org"`).
pub fn guess_logo_domains(name: &str) -> Vec<String> {
    let trimmed = name.trim().to_lowercase();
    if trimmed.is_empty() {
        return Vec::new();
    }

    let word = match trimmed.split_whitespace().next() {
        Some(w) => w,
        None => return Vec::new(),
    };

    vec![
        word.to_string(),
        format!("{word}.com"),
        format!("{word}.tv"),
        format!("{word}.org"),
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── normalize_name ─────────────────────────────────

    #[test]
    fn name_lowercases() {
        assert_eq!(normalize_name("BBC ONE"), "bbc one");
    }

    #[test]
    fn name_strips_special_chars() {
        assert_eq!(normalize_name("HBO (HD) [US]"), "hbo hd us",);
    }

    #[test]
    fn name_collapses_whitespace() {
        assert_eq!(
            normalize_name("  CNN   International  "),
            "cnn international",
        );
    }

    #[test]
    fn name_empty_input() {
        assert_eq!(normalize_name(""), "");
    }

    #[test]
    fn name_preserves_digits() {
        assert_eq!(normalize_name("Sky Sports 1"), "sky sports 1");
    }

    // ── normalize_url ──────────────────────────────────

    #[test]
    fn url_strips_query_and_trailing_slash() {
        assert_eq!(
            normalize_url("http://example.com/live/123/?token=abc"),
            "http://example.com/live/123",
        );
    }

    #[test]
    fn url_lowercases() {
        assert_eq!(
            normalize_url("HTTP://Example.COM/Stream"),
            "http://example.com/stream",
        );
    }

    #[test]
    fn url_strips_fragment() {
        assert_eq!(normalize_url("http://a.com/path#frag"), "http://a.com/path",);
    }

    #[test]
    fn url_preserves_port() {
        assert_eq!(
            normalize_url("http://a.com:8080/path/"),
            "http://a.com:8080/path",
        );
    }

    // ── try_base64_decode ──────────────────────────────

    #[test]
    fn base64_decodes_valid() {
        let encoded = STANDARD.encode("hello");
        assert_eq!(try_base64_decode(&encoded), "hello");
    }

    #[test]
    fn base64_returns_original_with_spaces() {
        assert_eq!(try_base64_decode("not base64 value"), "not base64 value",);
    }

    #[test]
    fn base64_returns_original_with_xml() {
        assert_eq!(try_base64_decode("<xml>data</xml>"), "<xml>data</xml>",);
    }

    #[test]
    fn base64_returns_original_on_invalid() {
        assert_eq!(try_base64_decode("!!!invalid!!!"), "!!!invalid!!!",);
    }

    #[test]
    fn base64_returns_original_when_too_short() {
        assert_eq!(try_base64_decode("Show"), "Show");
    }

    #[test]
    fn base64_returns_original_when_length_is_not_multiple_of_four() {
        assert_eq!(try_base64_decode("abcdefghijk"), "abcdefghijk");
    }

    // ── parse_epg_timestamp ────────────────────────────

    #[test]
    fn parses_valid_timestamp() {
        let ts = parse_epg_timestamp("2024-02-16 15:00:00");
        assert!(ts.is_some());
        let dt = ts.unwrap();
        assert_eq!(dt.and_utc().timestamp(), 1708095600);
    }

    #[test]
    fn returns_none_for_invalid() {
        assert!(parse_epg_timestamp("not a date").is_none());
    }

    #[test]
    fn handles_trimming() {
        assert!(parse_epg_timestamp("  2024-02-16 15:00:00  ").is_some());
    }

    #[test]
    fn parses_rfc3339_fallback() {
        let ts = parse_epg_timestamp("2024-01-15T06:00:00Z");
        assert!(ts.is_some());
        let dt = ts.unwrap();
        assert_eq!(dt.and_utc().timestamp(), 1705298400);
    }

    #[test]
    fn parses_rfc3339_with_offset() {
        let ts = parse_epg_timestamp("2024-01-15T06:00:00+02:00");
        assert!(ts.is_some());
        // +02:00 offset → UTC is 04:00
        let dt = ts.unwrap();
        assert_eq!(dt.and_utc().timestamp(), 1705291200);
    }

    // ── validate_mac_address ─────────────────────────────

    #[test]
    fn mac_valid_formats() {
        // Uppercase.
        assert!(validate_mac_address("00:1A:2B:3C:4D:5E"));
        // Lowercase.
        assert!(validate_mac_address("aa:bb:cc:dd:ee:ff"));
        // Mixed case.
        assert!(validate_mac_address("aA:Bb:cC:dD:eE:fF"));
    }

    #[test]
    fn mac_invalid_formats() {
        // Too short.
        assert!(!validate_mac_address("00:1A:2B"));
        // Wrong separator.
        assert!(!validate_mac_address("00-1A-2B-3C-4D-5E"));
        // Non-hex characters.
        assert!(!validate_mac_address("GG:HH:II:JJ:KK:LL"));
        // Empty.
        assert!(!validate_mac_address(""));
        // No colons.
        assert!(!validate_mac_address("001A2B3C4D5E"));
    }

    // ── mac_to_device_id ─────────────────────────────────

    #[test]
    fn mac_to_device_id_strips_colons() {
        assert_eq!(mac_to_device_id("00:1A:2B:3C:4D:5E"), "001A2B3C4D5E",);
        assert_eq!(mac_to_device_id("aa:bb:cc:dd:ee:ff"), "aabbccddeeff",);
    }

    // ── guess_logo_domains ───────────────────────────────

    #[test]
    fn logo_domains_single_word() {
        let domains = guess_logo_domains("BBC");
        assert_eq!(domains, vec!["bbc", "bbc.com", "bbc.tv", "bbc.org"],);
    }

    #[test]
    fn logo_domains_multi_word() {
        let domains = guess_logo_domains("Sky Sports News");
        assert_eq!(domains, vec!["sky", "sky.com", "sky.tv", "sky.org"],);
    }

    #[test]
    fn logo_domains_empty_input() {
        assert!(guess_logo_domains("").is_empty());
        assert!(guess_logo_domains("   ").is_empty());
    }

    // ── strip_quality_suffix ──────────────────────────────

    #[test]
    fn test_strip_quality_suffix_removes_hd() {
        assert_eq!(strip_quality_suffix("BBC One HD"), "BBC One");
        assert_eq!(strip_quality_suffix("Sky Sports SD"), "Sky Sports");
        assert_eq!(strip_quality_suffix("Movie FHD"), "Movie");
    }

    #[test]
    fn test_strip_quality_suffix_removes_4k_uhd() {
        assert_eq!(strip_quality_suffix("Channel 4K"), "Channel");
        assert_eq!(strip_quality_suffix("StreamUHD UHD"), "StreamUHD");
        assert_eq!(strip_quality_suffix("Film H.265"), "Film");
        assert_eq!(strip_quality_suffix("Film HEVC"), "Film");
        assert_eq!(strip_quality_suffix("Film H.264"), "Film");
    }

    #[test]
    fn test_strip_quality_suffix_preserves_name_without_suffix() {
        assert_eq!(strip_quality_suffix("CNN"), "CNN");
        assert_eq!(strip_quality_suffix("HBO"), "HBO");
        // "HD" embedded (not trailing) should be preserved
        assert_eq!(strip_quality_suffix("HDTV Network"), "HDTV Network");
    }

    // ── strip_country_code ────────────────────────────────

    #[test]
    fn test_strip_country_code_removes_trailing_code() {
        assert_eq!(strip_country_code("CNN US"), "CNN");
        assert_eq!(strip_country_code("BBC UK"), "BBC");
        assert_eq!(strip_country_code("ARD DE"), "ARD");
        assert_eq!(strip_country_code("TF1 FR"), "TF1");
    }

    #[test]
    fn test_strip_country_code_preserves_embedded_codes() {
        // Code in the middle — must not be stripped
        assert_eq!(strip_country_code("CNN"), "CNN");
        // Three-letter codes at the end
        assert_eq!(strip_country_code("ESPN USA"), "ESPN");
        // Lowercase — should NOT match (regex is uppercase only)
        assert_eq!(strip_country_code("CNN us"), "CNN us");
    }
}
