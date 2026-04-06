//! Resolution detection from channel metadata.
//!
//! Detects resolution tier from channel name, URL, and extra attributes
//! by matching common patterns like "4K", "UHD", "FHD", "1080p", "HD",
//! "720p", "SD".

use std::collections::HashMap;
use std::sync::LazyLock;

use crispy_iptv_types::Resolution;
use regex::Regex;

/// Pattern for UHD / 4K indicators (case-insensitive).
static UHD_PATTERN: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)\b(4K|UHD|2160[pi]|Ultra\s*HD)\b").unwrap());

/// Pattern for FHD / 1080 indicators (case-insensitive).
static FHD_PATTERN: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)\b(FHD|1080[pi]|Full\s*HD)\b").unwrap());

/// Pattern for HD / 720 indicators (case-insensitive).
static HD_PATTERN: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"(?i)\b(HD|720[pi])\b").unwrap());

/// Pattern for SD indicators (case-insensitive).
static SD_PATTERN: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)\b(SD|480[pi]|576[pi]|SDTV)\b").unwrap());

/// Detect resolution from channel name, URL, and attributes.
///
/// Checks for patterns like "4K", "UHD", "FHD", "1080p", "HD", "720p", "SD".
/// Searches in order: UHD > FHD > HD > SD, returning the first match.
/// Falls back to `Resolution::Unknown` if no pattern matches.
pub fn detect_resolution(
    name: &str,
    url: &str,
    attributes: &HashMap<String, String>,
) -> Resolution {
    // Combine all text sources for scanning.
    let attr_text: String = attributes
        .values()
        .map(std::string::String::as_str)
        .collect::<Vec<_>>()
        .join(" ");

    // Check each resolution tier in descending order.
    for text in [name, url, attr_text.as_str()] {
        if UHD_PATTERN.is_match(text) {
            return Resolution::UHD;
        }
    }
    for text in [name, url, attr_text.as_str()] {
        if FHD_PATTERN.is_match(text) {
            return Resolution::FHD;
        }
    }
    for text in [name, url, attr_text.as_str()] {
        if HD_PATTERN.is_match(text) {
            return Resolution::HD;
        }
    }
    for text in [name, url, attr_text.as_str()] {
        if SD_PATTERN.is_match(text) {
            return Resolution::SD;
        }
    }

    Resolution::Unknown
}

#[cfg(test)]
mod tests {
    use super::*;

    fn empty_attrs() -> HashMap<String, String> {
        HashMap::new()
    }

    #[test]
    fn detects_4k_from_name() {
        assert_eq!(
            detect_resolution("BBC One 4K", "", &empty_attrs()),
            Resolution::UHD
        );
    }

    #[test]
    fn detects_uhd_from_name() {
        assert_eq!(
            detect_resolution("Sports UHD", "", &empty_attrs()),
            Resolution::UHD
        );
    }

    #[test]
    fn detects_2160p_from_name() {
        assert_eq!(
            detect_resolution("Movie 2160p", "", &empty_attrs()),
            Resolution::UHD
        );
    }

    #[test]
    fn detects_fhd_from_name() {
        assert_eq!(
            detect_resolution("CNN FHD", "", &empty_attrs()),
            Resolution::FHD
        );
    }

    #[test]
    fn detects_1080p_from_name() {
        assert_eq!(
            detect_resolution("Stream 1080p", "", &empty_attrs()),
            Resolution::FHD
        );
    }

    #[test]
    fn detects_full_hd_from_name() {
        assert_eq!(
            detect_resolution("Channel Full HD", "", &empty_attrs()),
            Resolution::FHD
        );
    }

    #[test]
    fn detects_hd_from_name() {
        assert_eq!(
            detect_resolution("Sky HD", "", &empty_attrs()),
            Resolution::HD
        );
    }

    #[test]
    fn detects_720p_from_name() {
        assert_eq!(
            detect_resolution("Stream 720p", "", &empty_attrs()),
            Resolution::HD
        );
    }

    #[test]
    fn detects_sd_from_name() {
        assert_eq!(
            detect_resolution("Old Channel SD", "", &empty_attrs()),
            Resolution::SD
        );
    }

    #[test]
    fn detects_480p_from_name() {
        assert_eq!(
            detect_resolution("Low Res 480p", "", &empty_attrs()),
            Resolution::SD
        );
    }

    #[test]
    fn returns_unknown_when_no_match() {
        assert_eq!(
            detect_resolution("BBC One", "", &empty_attrs()),
            Resolution::Unknown
        );
    }

    #[test]
    fn detects_from_url() {
        // "hd" in a URL path segment matches \bHD\b.
        assert_eq!(
            detect_resolution("Channel", "http://example.com/hd/stream.ts", &empty_attrs()),
            Resolution::HD,
        );
        assert_eq!(
            detect_resolution(
                "Channel",
                "http://example.com/live/1080p/stream.ts",
                &empty_attrs()
            ),
            Resolution::FHD,
        );
    }

    #[test]
    fn detects_from_attributes() {
        let mut attrs = HashMap::new();
        attrs.insert("quality".to_string(), "FHD".to_string());
        assert_eq!(detect_resolution("Channel", "", &attrs), Resolution::FHD);
    }

    #[test]
    fn uhd_takes_priority_over_hd() {
        // Name says "HD" but also "4K" — UHD wins.
        assert_eq!(
            detect_resolution("Sports HD 4K", "", &empty_attrs()),
            Resolution::UHD
        );
    }

    #[test]
    fn fhd_takes_priority_over_hd() {
        assert_eq!(
            detect_resolution("FHD Movie HD", "", &empty_attrs()),
            Resolution::FHD
        );
    }
}
