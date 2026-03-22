//! URL normalization for checkpoint hashing.
//!
//! Translated from IPTVChecker-Python `normalize_url_for_hash()` and
//! `url_resume_hash()`.

use sha2::{Digest, Sha256};
use url::Url;

/// Query parameters stripped during normalization.
///
/// Faithfully translated from IPTVChecker-Python `_TRACKING_PARAMS`:
/// ```python
/// _TRACKING_PARAMS = frozenset({
///     'token', 'auth', 'key', 'sig', 'signature', 'expires', 'expire',
///     'ts', 'timestamp', 'nonce', 'hash', 'h', 'tk', 'st', 'e',
///     'utid', 'utm_source', 'utm_medium', 'utm_campaign', 'utm_content',
///     'utm_term', 'fbclid', 'gclid', '_', 'cb', 'cachebuster', 'rand',
/// })
/// ```
const TRACKING_PARAMS: &[&str] = &[
    "token",
    "auth",
    "key",
    "sig",
    "signature",
    "expires",
    "expire",
    "ts",
    "timestamp",
    "nonce",
    "hash",
    "h",
    "tk",
    "st",
    "e",
    "utid",
    "utm_source",
    "utm_medium",
    "utm_campaign",
    "utm_content",
    "utm_term",
    "fbclid",
    "gclid",
    "_",
    "cb",
    "cachebuster",
    "rand",
];

/// Normalize a URL for hashing by stripping tracking params and sorting
/// remaining query parameters.
///
/// Translation of IPTVChecker-Python `normalize_url_for_hash()`:
/// - Lowercase scheme and host
/// - Remove known tracking/session parameters
/// - Sort remaining query parameters alphabetically
/// - Strip fragment
pub fn normalize_url_for_hash(raw_url: &str) -> String {
    let Ok(mut parsed) = Url::parse(raw_url) else {
        return raw_url.to_string();
    };

    // Collect non-tracking query pairs, sorted.
    let mut filtered_pairs: Vec<(String, String)> = parsed
        .query_pairs()
        .filter(|(k, _)| {
            let lower = k.to_lowercase();
            !TRACKING_PARAMS.contains(&lower.as_str())
        })
        .map(|(k, v)| (k.into_owned(), v.into_owned()))
        .collect();

    filtered_pairs.sort();

    // Rebuild query string.
    if filtered_pairs.is_empty() {
        parsed.set_query(Option::None);
    } else {
        let query_string: String = filtered_pairs
            .iter()
            .map(|(k, v)| format!("{k}={v}"))
            .collect::<Vec<_>>()
            .join("&");
        parsed.set_query(Some(&query_string));
    }

    // Strip fragment.
    parsed.set_fragment(Option::None);

    parsed.to_string()
}

/// Compute a SHA-256 hash of the normalized URL, returning the first 16
/// hex characters.
///
/// Translation of IPTVChecker-Python `url_resume_hash()`:
/// ```python
/// def url_resume_hash(url):
///     normalized = normalize_url_for_hash(url)
///     return hashlib.sha256(normalized.encode('utf-8', errors='replace')).hexdigest()[:16]
/// ```
pub fn url_resume_hash(raw_url: &str) -> String {
    let normalized = normalize_url_for_hash(raw_url);
    let hash = Sha256::digest(normalized.as_bytes());
    let hex = format!("{hash:x}");
    hex[..16].to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn strips_utm_params() {
        let url = "http://example.com/stream?channel=1&utm_source=foo&utm_medium=bar";
        let normalized = normalize_url_for_hash(url);
        assert!(!normalized.contains("utm_source"));
        assert!(!normalized.contains("utm_medium"));
        assert!(normalized.contains("channel=1"));
    }

    #[test]
    fn strips_token_and_auth_params() {
        let url = "https://host.com/live.m3u8?token=abc123&auth=xyz&id=42";
        let normalized = normalize_url_for_hash(url);
        assert!(!normalized.contains("token="));
        assert!(!normalized.contains("auth="));
        assert!(normalized.contains("id=42"));
    }

    #[test]
    fn sorts_remaining_params() {
        let url = "http://example.com/stream?z=1&a=2&m=3";
        let normalized = normalize_url_for_hash(url);
        // Should be sorted: a=2, m=3, z=1
        let query = Url::parse(&normalized).unwrap();
        let pairs: Vec<_> = query.query_pairs().collect();
        assert_eq!(pairs[0].0, "a");
        assert_eq!(pairs[1].0, "m");
        assert_eq!(pairs[2].0, "z");
    }

    #[test]
    fn strips_fragment() {
        let url = "http://example.com/stream#section";
        let normalized = normalize_url_for_hash(url);
        assert!(!normalized.contains('#'));
    }

    #[test]
    fn resume_hash_is_16_chars() {
        let hash = url_resume_hash("http://example.com/stream.m3u8");
        assert_eq!(hash.len(), 16);
    }

    #[test]
    fn resume_hash_deterministic() {
        let h1 = url_resume_hash("http://example.com/stream.m3u8?token=a");
        let h2 = url_resume_hash("http://example.com/stream.m3u8?token=b");
        // Both should produce the same hash since "token" is stripped.
        assert_eq!(h1, h2);
    }

    #[test]
    fn resume_hash_differs_for_different_urls() {
        let h1 = url_resume_hash("http://example.com/stream1.m3u8");
        let h2 = url_resume_hash("http://example.com/stream2.m3u8");
        assert_ne!(h1, h2);
    }

    #[test]
    fn invalid_url_returns_as_is() {
        let url = "not-a-url";
        let normalized = normalize_url_for_hash(url);
        assert_eq!(normalized, url);
    }
}
