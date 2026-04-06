//! UDPxy proxy URL conversion.
//!
//! Translates UDP/RTP multicast URLs to HTTP URLs routed through a UDPxy
//! proxy, faithfully ported from `iptvtools/utils.py::convert_url_with_udpxy`.

use url::Url;

/// Multicast schemes that UDPxy can proxy.
const MULTICAST_SCHEMES: &[&str] = &["udp", "rtp"];

/// Check if a URL uses a multicast scheme (`udp://` or `rtp://`).
pub fn is_multicast(url: &str) -> bool {
    let Ok(parsed) = Url::parse(url) else {
        // The `url` crate may reject bare `udp://` URLs. Fall back to
        // prefix-based detection for robustness.
        let lower = url.to_ascii_lowercase();
        return lower.starts_with("udp://") || lower.starts_with("rtp://");
    };
    MULTICAST_SCHEMES.contains(&parsed.scheme())
}

/// Rewrite a UDP/RTP multicast URL to HTTP via a UDPxy proxy.
///
/// Given `"udp://239.0.0.1:5001"` and `"http://proxy:8888"`, returns
/// `Some("http://proxy:8888/udp/239.0.0.1:5001")`.
///
/// Returns `None` if the URL is not a multicast address. Non-multicast
/// URLs are not rewritten (matching the Python behaviour of returning the
/// original URL, but here we use `Option` for explicitness).
///
/// Faithfully translated from `iptvtools/utils.py::convert_url_with_udpxy`.
pub fn convert_to_udpxy(url: &str, proxy_base: &str) -> Option<String> {
    // Try to parse with the `url` crate first.
    if let Ok(parsed) = Url::parse(url) {
        if MULTICAST_SCHEMES.contains(&parsed.scheme()) {
            let scheme = parsed.scheme();
            let netloc = match parsed.port() {
                Some(port) => format!("{}:{}", parsed.host_str().unwrap_or(""), port),
                None => parsed.host_str().unwrap_or("").to_string(),
            };
            let base = proxy_base.trim_end_matches('/');
            return Some(format!("{base}/{scheme}/{netloc}"));
        }
        return None;
    }

    // Fallback: manual parsing for URLs the `url` crate cannot handle.
    let lower = url.to_ascii_lowercase();
    for &scheme in MULTICAST_SCHEMES {
        let prefix = format!("{scheme}://");
        if lower.starts_with(&prefix) {
            let netloc = &url[prefix.len()..];
            // Strip any trailing path/query (the Python version only uses netloc).
            let netloc = netloc.split('/').next().unwrap_or(netloc);
            let base = proxy_base.trim_end_matches('/');
            return Some(format!("{base}/{scheme}/{netloc}"));
        }
    }

    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn convert_udp_url_to_udpxy() {
        let result = convert_to_udpxy("udp://239.0.0.1:5001", "http://proxy:8888");
        assert_eq!(result, Some("http://proxy:8888/udp/239.0.0.1:5001".into()));
    }

    #[test]
    fn convert_rtp_url_to_udpxy() {
        let result = convert_to_udpxy("rtp://239.1.2.3:1234", "http://proxy:8888");
        assert_eq!(result, Some("http://proxy:8888/rtp/239.1.2.3:1234".into()));
    }

    #[test]
    fn non_multicast_url_returns_none() {
        let result = convert_to_udpxy("http://example.com/stream", "http://proxy:8888");
        assert_eq!(result, None);
    }

    #[test]
    fn is_multicast_detects_udp() {
        assert!(is_multicast("udp://239.0.0.1:5001"));
    }

    #[test]
    fn is_multicast_detects_rtp() {
        assert!(is_multicast("rtp://239.1.2.3:1234"));
    }

    #[test]
    fn is_multicast_rejects_http() {
        assert!(!is_multicast("http://example.com/stream"));
    }

    #[test]
    fn proxy_base_trailing_slash_stripped() {
        let result = convert_to_udpxy("udp://239.0.0.1:5001", "http://proxy:8888/");
        assert_eq!(result, Some("http://proxy:8888/udp/239.0.0.1:5001".into()));
    }
}
