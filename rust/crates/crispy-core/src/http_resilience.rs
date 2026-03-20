//! Resilient HTTP fetching with JSON recovery for IPTV sources.
//!
//! Ports the Dart `HttpService.getJsonList()` resilience logic to Rust:
//! - Fetches as bytes (reqwest auto-decompresses gzip)
//! - UTF-8 decode with replacement chars (`String::from_utf8_lossy`)
//! - Fast-path JSON parse; on failure, applies recovery:
//!   - Invalid escape sequences (`\0`, `\x`, `\a`, etc.)
//!   - Truncated unicode escapes (`\uXXX` → `\u0XXX`)
//!   - Lone surrogates → `\uFFFD` replacement character
//!   - Missing opening quotes on values (Xtream bug)
//!   - Truncated JSON arrays (find last `}`, close with `]`)

use anyhow::{Context, Result};
use regex::Regex;
use std::sync::LazyLock;

use crate::http_client::fetch_with_retry;

// ── Compiled regexes (allocated once) ──────────────────────────────
//
// The `regex` crate does NOT support lookaround assertions (`(?!...)`,
// `(?<!...)`). Where the Dart original used them we use simple patterns
// paired with manual position checks in helper functions.

/// Any `\X` escape sequence (backslash + one char). Used by
/// `sanitize_json` with a closure to keep valid escapes and strip
/// the backslash from invalid ones.
static RE_ANY_ESCAPE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\\(.)").unwrap());

/// Any `\uXXX` sequence (exactly 3 hex digits). Used by
/// `fix_truncated_unicode` which manually checks for a 4th digit.
static RE_UNICODE_3HEX: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\\u([0-9a-fA-F]{3})").unwrap());

/// Any high surrogate: `\uD800`–`\uDBFF`.
static RE_HIGH_SURROGATE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\\u[dD][89aAbB][0-9a-fA-F]{2}").unwrap());

/// Any low surrogate: `\uDC00`–`\uDFFF`.
static RE_LOW_SURROGATE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\\u[dD][cCdDeEfF][0-9a-fA-F]{2}").unwrap());

/// Missing opening quote: `"key":value"` → `"key":"value"`.
/// Includes the trailing `"` so the replacement doesn't double it.
static RE_MISSING_OPEN_QUOTE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new("\":\\s*([a-zA-Z_][a-zA-Z0-9_.]*)\"").unwrap());

// ── Public API ─────────────────────────────────────────────────────

/// Fetches a URL and returns the response body as a string.
///
/// Uses [`fetch_with_retry`] for automatic retry on transient failures.
/// When `accept_invalid_certs` is `true`, TLS certificate verification
/// is skipped to support self-signed server certificates.
pub async fn fetch_string(url: &str, accept_invalid_certs: bool) -> Result<String> {
    let resp = fetch_with_retry(url, accept_invalid_certs)
        .await
        .with_context(|| format!("Failed to fetch {url}"))?;

    let bytes = resp
        .bytes()
        .await
        .with_context(|| format!("Failed to read response from {url}"))?;

    Ok(String::from_utf8_lossy(&bytes).into_owned())
}

/// Fetches a URL and returns a resilient JSON list.
///
/// Handles common IPTV server issues:
/// - Gzip responses (auto-decompressed by reqwest)
/// - Malformed UTF-8 (replaced with U+FFFD)
/// - Invalid JSON escape sequences
/// - Lone surrogates from PHP servers
/// - Truncated JSON arrays (missing closing `]`)
/// - Missing opening quotes on values
///
/// When `accept_invalid_certs` is `true`, TLS certificate verification
/// is skipped to support self-signed server certificates.
pub async fn fetch_json_list(
    url: &str,
    accept_invalid_certs: bool,
) -> Result<Vec<serde_json::Value>> {
    let resp = fetch_with_retry(url, accept_invalid_certs)
        .await
        .with_context(|| format!("Failed to fetch {url}"))?;

    let bytes = resp
        .bytes()
        .await
        .with_context(|| format!("Failed to read response from {url}"))?;

    if bytes.is_empty() {
        return Ok(vec![]);
    }

    let text = String::from_utf8_lossy(&bytes);
    parse_json_list_resilient(&text)
}

/// Fetches a URL and returns the response body as a single JSON object.
///
/// Used for Xtream endpoints that return a single object (e.g. `get_series_info`).
/// Applies the same resilience logic as [`fetch_json_list`] for sanitization,
/// but expects (and returns) a `serde_json::Value` instead of an array.
///
/// Returns `Ok(Value::Null)` on empty response rather than an error, so
/// callers can treat an empty/missing body as non-fatal.
///
/// When `accept_invalid_certs` is `true`, TLS certificate verification
/// is skipped to support self-signed server certificates.
pub async fn fetch_json_object(url: &str, accept_invalid_certs: bool) -> Result<serde_json::Value> {
    let resp = fetch_with_retry(url, accept_invalid_certs)
        .await
        .with_context(|| format!("Failed to fetch {url}"))?;

    let bytes = resp
        .bytes()
        .await
        .with_context(|| format!("Failed to read response from {url}"))?;

    if bytes.is_empty() {
        return Ok(serde_json::Value::Null);
    }

    let text = String::from_utf8_lossy(&bytes);
    let sanitized = sanitize_json(&text);

    match serde_json::from_str::<serde_json::Value>(&sanitized) {
        Ok(v) => Ok(v),
        Err(_) => {
            // Fast-path failed; attempt array recovery then take first element.
            match serde_json::from_str::<serde_json::Value>(&text) {
                Ok(v) => Ok(v),
                Err(e) => {
                    eprintln!(
                        "fetch_json_object: JSON parse failed for {} bytes: {e}",
                        text.len()
                    );
                    Ok(serde_json::Value::Null)
                }
            }
        }
    }
}

/// Parses a JSON string into a list with resilient recovery.
///
/// Separated from `fetch_json_list` for direct testing without HTTP.
pub fn parse_json_list_resilient(text: &str) -> Result<Vec<serde_json::Value>> {
    if text.is_empty() {
        return Ok(vec![]);
    }

    // Fast path: try standard parse.
    if let Ok(serde_json::Value::Array(arr)) = serde_json::from_str(text) {
        return Ok(arr);
    }

    // Recovery path: sanitize + fix truncation.
    let mut s = sanitize_json(text);
    s = fix_truncated_array(&s);

    match serde_json::from_str::<serde_json::Value>(&s) {
        Ok(serde_json::Value::Array(arr)) => Ok(arr),
        Ok(other) => Ok(vec![other]),
        Err(e) => {
            // Last resort: return empty rather than failing sync entirely.
            eprintln!("JSON recovery failed for {} bytes: {e}", text.len());
            Ok(vec![])
        }
    }
}

// ── JSON sanitization (ports Dart `_sanitizeJson`) ─────────────────

/// Sanitizes common IPTV server JSON malformations.
pub fn sanitize_json(s: &str) -> String {
    // Fix invalid escape sequences: keep valid escapes intact,
    // drop the backslash on invalid ones. Using `\\(.)` ensures
    // `\\s` is not misinterpreted (the first `\` pairs with the
    // second, leaving `s` as a regular character).
    let mut result = RE_ANY_ESCAPE
        .replace_all(s, |caps: &regex::Captures| {
            let ch = caps[1].chars().next().unwrap();
            if "\"\\/bfnrtu".contains(ch) {
                caps[0].to_owned()
            } else {
                caps[1].to_owned()
            }
        })
        .into_owned();

    // Fix truncated unicode escapes: \uXXX → \u0XXX.
    result = fix_truncated_unicode(&result);

    // Fix lone surrogates → replacement character.
    result = fix_lone_high_surrogates(&result);
    result = fix_lone_low_surrogates(&result);

    // Fix missing opening quotes on values (Xtream bug).
    result = RE_MISSING_OPEN_QUOTE
        .replace_all(&result, |caps: &regex::Captures| {
            format!("\":\"{}\"", &caps[1])
        })
        .into_owned();

    result
}

/// Fixes truncated JSON arrays by finding the last complete object
/// and closing the array bracket.
pub fn fix_truncated_array(s: &str) -> String {
    let trimmed = s.trim_start();
    if !trimmed.starts_with('[') {
        return s.to_owned();
    }

    // Already valid array ending.
    if trimmed.trim_end().ends_with(']') {
        return s.to_owned();
    }

    if let Some(last_brace) = s.rfind('}') {
        let tail = s[last_brace + 1..].trim();
        if tail.is_empty() || tail == "," || !tail.ends_with(']') {
            return format!("{}]", &s[..last_brace + 1]);
        }
    }

    s.to_owned()
}

/// Pads truncated unicode escapes: `\uXXX` → `\u0XXX`, but only
/// when NOT followed by a 4th hex digit (which would make it valid).
fn fix_truncated_unicode(s: &str) -> String {
    let mut result = s.to_owned();
    let positions: Vec<_> = RE_UNICODE_3HEX
        .captures_iter(s)
        .map(|c| {
            let m = c.get(0).unwrap();
            (m.start(), m.end(), c[1].to_owned())
        })
        .collect();

    for (start, end, hex3) in positions.into_iter().rev() {
        // If followed by another hex digit, this is a valid 4-digit escape.
        if end < s.len() && s.as_bytes()[end].is_ascii_hexdigit() {
            continue;
        }
        let replacement = format!("\\u0{hex3}");
        result.replace_range(start..end, &replacement);
    }
    result
}

/// Replaces lone high surrogates (`\uD800`–`\uDBFF`) that are NOT
/// followed by a low surrogate with `\uFFFD`. Manual lookahead
/// because the `regex` crate does not support `(?!...)`.
fn fix_lone_high_surrogates(s: &str) -> String {
    let mut result = s.to_owned();
    let positions: Vec<(usize, usize)> = RE_HIGH_SURROGATE
        .find_iter(s)
        .map(|m| (m.start(), m.end()))
        .collect();

    for (start, end) in positions.into_iter().rev() {
        // A valid low surrogate escape is exactly 6 bytes (`\uXXXX`).
        let followed_by_low = end + 6 <= s.len() && RE_LOW_SURROGATE.is_match(&s[end..end + 6]);
        if !followed_by_low {
            result.replace_range(start..end, r"\uFFFD");
        }
    }
    result
}

/// Replaces lone low surrogates (`\uDC00`–`\uDFFF`) that are NOT
/// preceded by a high surrogate with `\uFFFD`. Manual lookbehind
/// because the `regex` crate does not support `(?<!...)`.
fn fix_lone_low_surrogates(s: &str) -> String {
    let mut result = s.to_owned();
    // Collect low surrogate positions first, then check each.
    let positions: Vec<(usize, usize)> = RE_LOW_SURROGATE
        .find_iter(s)
        .map(|m| (m.start(), m.end()))
        .collect();

    // Process in reverse so byte offsets stay valid after replacements.
    for (start, end) in positions.into_iter().rev() {
        // A valid high surrogate escape is exactly 6 bytes (`\uXXXX`).
        let preceded_by_high = start >= 6 && RE_HIGH_SURROGATE.is_match(&s[start - 6..start]);
        if !preceded_by_high {
            result.replace_range(start..end, r"\uFFFD");
        }
    }
    result
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── sanitize_json tests ────────────────────────────────────────

    #[test]
    fn sanitize_removes_invalid_escapes() {
        assert_eq!(sanitize_json(r#"{"k": "v\alue"}"#), r#"{"k": "value"}"#);
        assert_eq!(sanitize_json(r#"{"k": "v\0"}"#), r#"{"k": "v0"}"#);
    }

    #[test]
    fn sanitize_preserves_valid_escapes() {
        let input = r#"{"k": "line\nbreak\ttab\\slash\"quote"}"#;
        assert_eq!(sanitize_json(input), input);
    }

    #[test]
    fn sanitize_fixes_truncated_unicode() {
        assert_eq!(sanitize_json(r"\u00A"), r"\u000A");
        assert_eq!(sanitize_json(r"\uFFF"), r"\u0FFF");
    }

    #[test]
    fn sanitize_preserves_full_unicode() {
        let input = r"\u00A0";
        assert_eq!(sanitize_json(input), input);
    }

    #[test]
    fn sanitize_fixes_lone_high_surrogate() {
        // \uD800 without following low surrogate.
        assert_eq!(sanitize_json(r"\uD800 rest"), r"\uFFFD rest");
        assert_eq!(sanitize_json(r"\uDB99"), r"\uFFFD");
    }

    #[test]
    fn sanitize_preserves_valid_surrogate_pair() {
        let input = r"\uD83D\uDE00"; // 😀
        assert_eq!(sanitize_json(input), input);
    }

    #[test]
    fn sanitize_fixes_lone_low_surrogate() {
        assert_eq!(sanitize_json(r"prefix \uDC00"), r"prefix \uFFFD");
    }

    #[test]
    fn sanitize_fixes_missing_open_quote() {
        assert_eq!(sanitize_json(r#"{"key":value"}"#), r#"{"key":"value"}"#);
    }

    #[test]
    fn sanitize_preserves_properly_quoted_values() {
        let input = r#"{"key":"value"}"#;
        assert_eq!(sanitize_json(input), input);
    }

    #[test]
    fn sanitize_handles_multiple_issues() {
        let input = r#"[{"name": "t\est\u00A", "id": "\uD800"}]"#;
        let result = sanitize_json(input);
        assert!(result.contains("test"));
        assert!(result.contains(r"\u000A"));
        assert!(result.contains(r"\uFFFD"));
    }

    // ── fix_truncated_array tests ──────────────────────────────────

    #[test]
    fn truncated_array_fixes_missing_bracket() {
        let input = r#"[{"id":1},{"id":2}"#;
        assert_eq!(fix_truncated_array(input), r#"[{"id":1},{"id":2}]"#);
    }

    #[test]
    fn truncated_array_fixes_trailing_comma() {
        let input = r#"[{"id":1},{"id":2},"#;
        assert_eq!(fix_truncated_array(input), r#"[{"id":1},{"id":2}]"#);
    }

    #[test]
    fn truncated_array_fixes_partial_object() {
        // rfind('}') finds the closing brace of {"id":2}, dropping the partial.
        let input = r#"[{"id":1},{"id":2},{"id":3,"na"#;
        assert_eq!(fix_truncated_array(input), r#"[{"id":1},{"id":2}]"#);
    }

    #[test]
    fn truncated_array_preserves_valid() {
        let input = r#"[{"id":1},{"id":2}]"#;
        assert_eq!(fix_truncated_array(input), input);
    }

    #[test]
    fn truncated_array_ignores_non_array() {
        let input = r#"{"id":1}"#;
        assert_eq!(fix_truncated_array(input), input);
    }

    #[test]
    fn truncated_array_handles_empty() {
        assert_eq!(fix_truncated_array(""), "");
        assert_eq!(fix_truncated_array("[]"), "[]");
    }

    #[test]
    fn truncated_array_handles_whitespace_prefix() {
        let input = "  \n[{\"id\":1}";
        assert_eq!(fix_truncated_array(input), "  \n[{\"id\":1}]");
    }

    // ── parse_json_list_resilient tests ────────────────────────────

    #[test]
    fn resilient_parse_valid_array() {
        let input = r#"[{"id":1},{"id":2}]"#;
        let result = parse_json_list_resilient(input).unwrap();
        assert_eq!(result.len(), 2);
    }

    #[test]
    fn resilient_parse_empty() {
        assert!(parse_json_list_resilient("").unwrap().is_empty());
        assert!(parse_json_list_resilient("[]").unwrap().is_empty());
    }

    #[test]
    fn resilient_parse_truncated() {
        let input = r#"[{"id":1},{"id":2}"#;
        let result = parse_json_list_resilient(input).unwrap();
        assert_eq!(result.len(), 2);
    }

    #[test]
    fn resilient_parse_with_invalid_escapes() {
        let input = r#"[{"name":"te\st"}]"#;
        let result = parse_json_list_resilient(input).unwrap();
        assert_eq!(result.len(), 1);
        assert_eq!(result[0]["name"].as_str().unwrap(), "test");
    }

    #[test]
    fn resilient_parse_with_lone_surrogate() {
        let input = r#"[{"name":"\uD800test"}]"#;
        let result = parse_json_list_resilient(input).unwrap();
        assert_eq!(result.len(), 1);
    }

    #[test]
    fn resilient_parse_single_object() {
        let input = r#"{"id":1}"#;
        let result = parse_json_list_resilient(input).unwrap();
        assert_eq!(result.len(), 1);
        assert_eq!(result[0]["id"].as_i64().unwrap(), 1);
    }

    #[test]
    fn resilient_parse_truncated_with_trailing_comma() {
        let input = r#"[{"id":1},{"id":2},"#;
        let result = parse_json_list_resilient(input).unwrap();
        assert_eq!(result.len(), 2);
    }

    #[test]
    fn resilient_parse_large_truncated() {
        // Simulate a large response with many items, truncated mid-object.
        let mut items: Vec<String> = (1..=100)
            .map(|i| format!(r#"{{"id":{i},"name":"item_{i}"}}"#))
            .collect();
        let partial = r#"{"id":101,"na"#;
        items.push(partial.to_string());
        let input = format!("[{}]", items.join(","));
        // Remove the closing `]` and partial object's closing.
        let truncated = &input[..input.rfind(']').unwrap()];

        let result = parse_json_list_resilient(truncated).unwrap();
        assert_eq!(result.len(), 100); // 100 complete items, partial dropped
    }

    #[test]
    fn resilient_parse_completely_broken() {
        let input = "this is not json at all {{{";
        let result = parse_json_list_resilient(input).unwrap();
        assert!(result.is_empty());
    }
}
