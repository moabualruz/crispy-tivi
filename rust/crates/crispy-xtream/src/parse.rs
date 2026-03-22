//! Response parsing helpers.
//!
//! Xtream servers frequently base64-encode EPG titles and descriptions.
//! This module provides transparent decoding utilities.

use base64::Engine;
use base64::engine::general_purpose::STANDARD;

/// Attempt to decode a base64-encoded string.
///
/// Returns the decoded UTF-8 string if the input is valid base64 that
/// decodes to valid UTF-8. Returns the original string unchanged otherwise.
pub fn maybe_decode_base64(input: &str) -> String {
    if input.is_empty() {
        return String::new();
    }

    // Quick heuristic: base64 strings from Xtream servers are typically
    // at least 4 chars, contain only base64 alphabet, and are padded.
    // We try to decode and fall back to the original on failure.
    match STANDARD.decode(input.trim()) {
        Ok(bytes) => match String::from_utf8(bytes) {
            Ok(decoded) => {
                // Sanity check: if the "decoded" string looks like garbage
                // (contains many control chars), the input was probably not
                // base64 after all.
                let control_count = decoded
                    .chars()
                    .filter(|c| c.is_control() && *c != '\n')
                    .count();
                if decoded.len() > 4 && control_count > decoded.len() / 4 {
                    input.to_string()
                } else {
                    decoded
                }
            }
            Err(_) => input.to_string(),
        },
        Err(_) => input.to_string(),
    }
}

/// Decode EPG title/description fields in-place.
///
/// Xtream servers may return titles and descriptions as base64 or plain text.
/// This function attempts to decode and replaces the value only when valid.
pub fn decode_epg_field(field: &Option<String>) -> Option<String> {
    field.as_ref().map(|s| maybe_decode_base64(s))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn decodes_valid_base64() {
        // "News" in base64
        assert_eq!(maybe_decode_base64("TmV3cw=="), "News");
    }

    #[test]
    fn decodes_base64_description() {
        // "Daily news" in base64
        assert_eq!(maybe_decode_base64("RGFpbHkgbmV3cw=="), "Daily news");
    }

    #[test]
    fn returns_plain_text_unchanged() {
        assert_eq!(maybe_decode_base64("Just plain text"), "Just plain text");
    }

    #[test]
    fn handles_empty_string() {
        assert_eq!(maybe_decode_base64(""), "");
    }

    #[test]
    fn handles_unicode_plain_text() {
        let text = "Programme en fran\u{00e7}ais";
        assert_eq!(maybe_decode_base64(text), text);
    }

    #[test]
    fn decode_epg_field_some() {
        let field = Some("TmV3cw==".to_string());
        assert_eq!(decode_epg_field(&field), Some("News".to_string()));
    }

    #[test]
    fn decode_epg_field_none() {
        assert_eq!(decode_epg_field(&None), None);
    }

    #[test]
    fn decodes_base64_with_whitespace() {
        assert_eq!(maybe_decode_base64("  TmV3cw==  "), "News");
    }
}
