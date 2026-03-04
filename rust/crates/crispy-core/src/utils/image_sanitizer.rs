//! Centralized Image URL Sanitization
//!
//! Upstream IPTV providers frequently inject corrupted or malformed
//! data into `logo_url` or `stream_icon` fields. This module provides
//! robust sanitization to ensure the Flutter frontend `SmartImage`
//! receives strictly valid strings or predictable fallbacks.

use serde_json::Value;

/// Sanitizes a raw image URL string extracted from an M3U or Xtream payload.
///
/// Handles the following edge cases:
/// 1. Empty or whitespace-only strings.
/// 2. CSV lists (e.g. `http://img1.png, http://img2.png`) -> Extracts the first valid segment.
/// 3. JSON Arrays masquerading as strings -> Extracts the first valid element.
pub fn sanitize_image_url(raw_url: Option<String>) -> Option<String> {
    let mut url = raw_url?.trim().to_string();

    if url.is_empty() {
        return None;
    }

    // Edge Case 1: JSON Array String (e.g. `["http://logo.png"]`)
    if url.starts_with('[')
        && url.ends_with(']')
        && let Ok(Value::Array(arr)) = serde_json::from_str(&url)
        && let Some(first) = arr.first()
        && let Some(s) = first.as_str()
    {
        url = s.trim().to_string();
    }

    // Edge Case 2: CSV List of URLs (e.g. `http://a.png, http://b.png`)
    if url.contains(',')
        && let Some(first_split) = url.split(',').next()
    {
        url = first_split.trim().to_string();
    }

    // Final basic protocol check to drop entirely garbage payloads early
    // (Flutter SmartImage will also verify, but this prevents DB bloat)
    if !url.is_empty()
        && (url.starts_with("http://")
            || url.starts_with("https://")
            || url.starts_with("data:image/")
            || url.starts_with("s:1:/images/"))
    {
        Some(url)
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_valid_http() {
        let res = sanitize_image_url(Some("https://example.com/logo.png".to_string()));
        assert_eq!(res.unwrap(), "https://example.com/logo.png");
    }

    #[test]
    fn test_csv_list() {
        let res = sanitize_image_url(Some(
            "https://img.com/1.png , https://img.com/2.png".to_string(),
        ));
        assert_eq!(res.unwrap(), "https://img.com/1.png");
    }

    #[test]
    fn test_json_array() {
        let res = sanitize_image_url(Some(
            r#"["https://img.com/1.png", "https://img.com/2.png"]"#.to_string(),
        ));
        assert_eq!(res.unwrap(), "https://img.com/1.png");
    }

    #[test]
    fn test_invalid_protocol_dropped() {
        let res = sanitize_image_url(Some("sftp://root:pass@server/video.mp4".to_string()));
        assert!(res.is_none());
    }

    #[test]
    fn test_empty_string_dropped() {
        let res = sanitize_image_url(Some("   ".to_string()));
        assert!(res.is_none());
    }
}
