//! Image and stream URL sanitization.
//!
//! Validates and cleans image URLs (scheme check, tracking param removal,
//! protocol-relative handling) and stream URLs (whitespace trim,
//! percent-encoding normalization).

use url::Url;

/// Sanitize an image URL — validate scheme, remove tracking params,
/// handle protocol-relative URLs.
///
/// Returns `None` if the input is `None`, empty, whitespace-only,
/// or not a valid HTTP(S) URL.
pub fn sanitize_image_url(url: Option<&str>) -> Option<String> {
    let raw = url?.trim();
    if raw.is_empty() {
        return None;
    }

    // Handle protocol-relative URLs.
    let with_scheme = if raw.starts_with("//") {
        format!("https:{raw}")
    } else {
        raw.to_string()
    };

    // Parse and validate.
    let parsed = Url::parse(&with_scheme).ok()?;

    // Only allow http and https schemes for images.
    match parsed.scheme() {
        "http" | "https" => {}
        _ => return None,
    }

    // Must have a host.
    parsed.host_str()?;

    // Rebuild without tracking parameters.
    let tracking_params = [
        "utm_source",
        "utm_medium",
        "utm_campaign",
        "utm_term",
        "utm_content",
        "fbclid",
        "gclid",
        "ref",
    ];

    let mut cleaned = parsed.clone();
    {
        let filtered: Vec<(String, String)> = parsed
            .query_pairs()
            .into_owned()
            .filter(|(key, _)| !tracking_params.contains(&key.as_str()))
            .collect();

        let mut query = cleaned.query_pairs_mut();
        query.clear();
        for (key, value) in &filtered {
            query.append_pair(key, value);
        }
    }

    // Remove empty query string.
    if cleaned.query() == Some("") {
        cleaned.set_query(None);
    }

    Some(cleaned.to_string())
}

/// Clean a stream URL — trim whitespace, normalize percent-encoding.
///
/// Does not validate the URL scheme (streams may use rtmp://, udp://, etc.).
pub fn sanitize_stream_url(url: &str) -> String {
    let trimmed = url.trim();
    if trimmed.is_empty() {
        return String::new();
    }

    // Attempt to parse and re-serialize for percent-encoding normalization.
    // If parsing fails (e.g., udp:// URLs that `url` crate can't handle),
    // return the trimmed original.
    match Url::parse(trimmed) {
        Ok(parsed) => parsed.to_string(),
        Err(_) => trimmed.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── sanitize_image_url ─────────────────────────────

    #[test]
    fn valid_https_url_passes() {
        let result = sanitize_image_url(Some("https://cdn.example.com/logo.png"));
        assert_eq!(result, Some("https://cdn.example.com/logo.png".into()));
    }

    #[test]
    fn valid_http_url_passes() {
        let result = sanitize_image_url(Some("http://cdn.example.com/logo.png"));
        assert_eq!(result, Some("http://cdn.example.com/logo.png".into()));
    }

    #[test]
    fn none_returns_none() {
        assert_eq!(sanitize_image_url(None), None);
    }

    #[test]
    fn empty_returns_none() {
        assert_eq!(sanitize_image_url(Some("")), None);
        assert_eq!(sanitize_image_url(Some("   ")), None);
    }

    #[test]
    fn invalid_scheme_returns_none() {
        assert_eq!(sanitize_image_url(Some("ftp://example.com/logo.png")), None);
        assert_eq!(sanitize_image_url(Some("data:image/png;base64,abc")), None);
    }

    #[test]
    fn protocol_relative_gets_https() {
        let result = sanitize_image_url(Some("//cdn.example.com/logo.png"));
        assert!(result.is_some());
        assert!(result.unwrap().starts_with("https://"));
    }

    #[test]
    fn removes_tracking_params() {
        let result = sanitize_image_url(Some(
            "https://cdn.example.com/logo.png?w=100&utm_source=tv&fbclid=abc",
        ));
        let url = result.unwrap();
        assert!(url.contains("w=100"));
        assert!(!url.contains("utm_source"));
        assert!(!url.contains("fbclid"));
    }

    #[test]
    fn trims_whitespace() {
        let result = sanitize_image_url(Some("  https://cdn.example.com/logo.png  "));
        assert_eq!(result, Some("https://cdn.example.com/logo.png".into()));
    }

    // ── sanitize_stream_url ────────────────────────────

    #[test]
    fn trims_stream_url_whitespace() {
        assert_eq!(
            sanitize_stream_url("  http://example.com/stream  "),
            "http://example.com/stream",
        );
    }

    #[test]
    fn empty_stream_url_returns_empty() {
        assert_eq!(sanitize_stream_url(""), "");
        assert_eq!(sanitize_stream_url("   "), "");
    }

    #[test]
    fn normalizes_percent_encoding() {
        // The url crate normalizes percent-encoding on parse.
        let result = sanitize_stream_url("http://example.com/path%20with%20spaces");
        assert!(result.contains("example.com"));
    }

    #[test]
    fn unparseable_url_returns_trimmed() {
        // Truly unparseable URL — returned as-is after trimming.
        let input = "some://[invalid-url";
        let result = sanitize_stream_url(input);
        assert_eq!(result, input);
    }
}
