//! URL and title normalization utilities.
//!
//! Provides URL normalization (lowercase scheme/host, remove trailing
//! slashes, sort query params) and title normalization (Unicode NFC,
//! trim, collapse whitespace, remove control characters).

use std::sync::LazyLock;

use regex::Regex;
use unicode_normalization::UnicodeNormalization;
use url::Url;

use crate::error::ToolsError;

/// Matches control characters (Unicode category Cc), excluding
/// common whitespace (\n, \r, \t).
static CONTROL_CHARS: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]").unwrap());

/// Matches two or more consecutive whitespace characters.
static MULTI_WHITESPACE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\s{2,}").unwrap());

/// Normalize a URL: lowercase scheme/host, remove trailing slashes,
/// sort query params.
///
/// Preserves the path and percent-encoding. Returns an error if the
/// URL is not parseable.
pub fn normalize_url(raw: &str) -> Result<String, ToolsError> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return Err(ToolsError::InvalidUrl("empty URL".into()));
    }

    let mut parsed =
        Url::parse(trimmed).map_err(|e| ToolsError::InvalidUrl(format!("{trimmed}: {e}")))?;

    // Lowercase scheme and host (Url crate does scheme automatically,
    // but host may preserve case in some edge cases).
    if let Some(host) = parsed.host_str() {
        let lower_host = host.to_lowercase();
        if lower_host != host {
            parsed
                .set_host(Some(&lower_host))
                .map_err(|e| ToolsError::InvalidUrl(format!("host normalization: {e}")))?;
        }
    }

    // Sort query parameters for canonical form.
    if parsed.query().is_some() {
        let mut pairs: Vec<(String, String)> = parsed.query_pairs().into_owned().collect();
        pairs.sort_by(|a, b| a.0.cmp(&b.0).then(a.1.cmp(&b.1)));
        let mut query = parsed.query_pairs_mut();
        query.clear();
        for (key, value) in &pairs {
            query.append_pair(key, value);
        }
        // Drop the mutable borrow.
        drop(query);
    }

    let mut result = parsed.to_string();

    // Remove trailing slash only if path is just "/".
    if result.ends_with('/') && parsed.path() == "/" && parsed.query().is_none() {
        result.pop();
    }

    Ok(result)
}

/// Normalize a title: Unicode NFC, trim whitespace, collapse
/// multiple spaces, remove control characters.
pub fn normalize_title(title: &str) -> String {
    // Apply Unicode NFC normalization.
    let nfc: String = title.nfc().collect();

    // Remove control characters.
    let no_controls = CONTROL_CHARS.replace_all(&nfc, "");

    // Collapse multiple whitespace into single space.
    let collapsed = MULTI_WHITESPACE.replace_all(&no_controls, " ");

    collapsed.trim().to_string()
}

/// Extract base URL (scheme://host[:port]) from a full URL.
///
/// Returns `None` if the URL is not parseable or has no host.
pub fn extract_base_url(url: &str) -> Option<String> {
    let parsed = Url::parse(url.trim()).ok()?;
    let scheme = parsed.scheme();
    let host = parsed.host_str()?;

    match parsed.port() {
        Some(port) => Some(format!("{scheme}://{host}:{port}")),
        None => Some(format!("{scheme}://{host}")),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── normalize_url ──────────────────────────────────

    #[test]
    fn lowercases_scheme_and_host() {
        let result = normalize_url("HTTP://Example.COM/path").unwrap();
        assert!(result.starts_with("http://example.com/"));
    }

    #[test]
    fn removes_trailing_slash_on_root() {
        let result = normalize_url("http://example.com/").unwrap();
        assert_eq!(result, "http://example.com");
    }

    #[test]
    fn preserves_path_trailing_slash() {
        // Non-root path trailing slash is preserved (it's semantically distinct).
        let result = normalize_url("http://example.com/path/").unwrap();
        assert!(result.contains("/path/"));
    }

    #[test]
    fn sorts_query_params() {
        let result = normalize_url("http://example.com/path?z=1&a=2").unwrap();
        assert!(result.contains("a=2&z=1"));
    }

    #[test]
    fn empty_url_errors() {
        assert!(normalize_url("").is_err());
        assert!(normalize_url("   ").is_err());
    }

    #[test]
    fn invalid_url_errors() {
        assert!(normalize_url("not a url").is_err());
    }

    #[test]
    fn preserves_port() {
        let result = normalize_url("http://example.com:8080/path").unwrap();
        assert!(result.contains(":8080"));
    }

    // ── normalize_title ────────────────────────────────

    #[test]
    fn trims_and_collapses_whitespace() {
        assert_eq!(normalize_title("  BBC   One  "), "BBC One");
    }

    #[test]
    fn removes_control_characters() {
        assert_eq!(normalize_title("BBC\x00One\x07Two"), "BBCOneTwo");
    }

    #[test]
    fn applies_nfc_normalization() {
        // e + combining acute accent → single precomposed character.
        let input = "caf\u{0065}\u{0301}";
        let result = normalize_title(input);
        assert_eq!(result, "caf\u{00E9}");
    }

    #[test]
    fn empty_input_returns_empty() {
        assert_eq!(normalize_title(""), "");
        assert_eq!(normalize_title("   "), "");
    }

    #[test]
    fn preserves_normal_text() {
        assert_eq!(normalize_title("Sky Sports 1"), "Sky Sports 1");
    }

    // ── extract_base_url ───────────────────────────────

    #[test]
    fn extracts_scheme_host_port() {
        assert_eq!(
            extract_base_url("http://host:8080/path/to/thing?q=1"),
            Some("http://host:8080".into()),
        );
    }

    #[test]
    fn extracts_without_port() {
        assert_eq!(
            extract_base_url("https://example.com/path"),
            Some("https://example.com".into()),
        );
    }

    #[test]
    fn returns_none_for_invalid() {
        assert_eq!(extract_base_url("not a url"), None);
    }

    #[test]
    fn returns_none_for_empty() {
        assert_eq!(extract_base_url(""), None);
    }
}
