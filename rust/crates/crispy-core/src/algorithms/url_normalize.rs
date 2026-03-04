//! API base URL normalization.
//!
//! Extracts `scheme://host[:port]` from a full URL,
//! stripping paths, query params, and fragments. Used by
//! Xtream and Stalker portal clients to canonicalize
//! provider URLs.

/// Normalize an API base URL to `scheme://host[:port]`.
///
/// Strips path, query string, and fragment. Returns an
/// error if the URL is empty, has no host, or is
/// unparseable.
///
/// Default ports (80 for http, 443 for https) are omitted.
///
/// # Examples
///
/// ```
/// use crispy_core::algorithms::url_normalize::*;
///
/// assert_eq!(
///     normalize_api_base_url(
///         "http://provider.com:8080/player_api.php?u=x",
///     )
///     .unwrap(),
///     "http://provider.com:8080",
/// );
/// ```
pub fn normalize_api_base_url(url: &str) -> Result<String, String> {
    let trimmed = url.trim();
    if trimmed.is_empty() {
        return Err("URL must not be empty".into());
    }

    // Ensure a scheme exists so the parser can find
    // the host.
    let with_scheme = if !trimmed.contains("://") {
        format!("http://{trimmed}")
    } else {
        trimmed.to_string()
    };

    // Split on "://" to extract scheme and the rest.
    let (scheme, remainder) = match with_scheme.split_once("://") {
        Some((s, r)) if !s.is_empty() && !r.is_empty() => (s, r),
        _ => {
            return Err(format!("Invalid URL format: {trimmed}"));
        }
    };

    // remainder = "host:port/path?query#frag"
    // Strip fragment.
    let no_frag = remainder.split('#').next().unwrap_or(remainder);
    // Strip query.
    let no_query = no_frag.split('?').next().unwrap_or(no_frag);
    // Strip path — take up to first '/'.
    let authority = no_query.split('/').next().unwrap_or(no_query);

    if authority.is_empty() {
        return Err(format!("No host in URL: {trimmed}"));
    }

    // Split authority into host and optional port.
    // Handle IPv6 addresses: [::1]:8080
    let (host, port) = if authority.starts_with('[') {
        // IPv6: [host]:port or [host]
        match authority.find(']') {
            Some(end) => {
                let h = &authority[..=end];
                let rest = &authority[end + 1..];
                let p = rest
                    .strip_prefix(':')
                    .and_then(|s| if s.is_empty() { None } else { Some(s) });
                (h, p)
            }
            None => {
                return Err(format!("Invalid IPv6 URL: {trimmed}"));
            }
        }
    } else {
        // IPv4 / hostname — last ':' is port separator.
        match authority.rfind(':') {
            Some(pos) => {
                let candidate = &authority[pos + 1..];
                // Only treat as port if it's all digits.
                if candidate.chars().all(|c| c.is_ascii_digit()) && !candidate.is_empty() {
                    (&authority[..pos], Some(candidate))
                } else {
                    (authority, None)
                }
            }
            None => (authority, None),
        }
    };

    if host.is_empty() {
        return Err(format!("No host in URL: {trimmed}"));
    }

    // Determine if port should be included.
    let include_port = match port {
        Some(p) => {
            let port_num: u16 = p.parse().map_err(|_| format!("Invalid port: {p}"))?;
            !is_default_port(scheme, port_num)
        }
        None => false,
    };

    if include_port {
        Ok(format!("{scheme}://{host}:{port}", port = port.unwrap()))
    } else {
        Ok(format!("{scheme}://{host}"))
    }
}

/// Returns true if the port is the default for the
/// scheme.
fn is_default_port(scheme: &str, port: u16) -> bool {
    matches!((scheme, port), ("http", 80) | ("https", 443))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn strips_path() {
        assert_eq!(
            normalize_api_base_url("http://provider.com:8080/player_api.php",).unwrap(),
            "http://provider.com:8080",
        );
    }

    #[test]
    fn preserves_non_default_port() {
        assert_eq!(
            normalize_api_base_url("http://example.com:25461/live",).unwrap(),
            "http://example.com:25461",
        );
    }

    #[test]
    fn strips_trailing_slash() {
        assert_eq!(
            normalize_api_base_url("http://example.com:8080/",).unwrap(),
            "http://example.com:8080",
        );
    }

    #[test]
    fn no_scheme_defaults_to_http() {
        assert_eq!(
            normalize_api_base_url("example.com:9090").unwrap(),
            "http://example.com:9090",
        );
    }

    #[test]
    fn empty_url_errors() {
        assert!(normalize_api_base_url("").is_err());
        assert!(normalize_api_base_url("   ").is_err());
    }

    #[test]
    fn strips_query_params() {
        assert_eq!(
            normalize_api_base_url("http://tv.example.com/api?user=x&pass=y",).unwrap(),
            "http://tv.example.com",
        );
    }

    #[test]
    fn already_clean_url_is_noop() {
        assert_eq!(
            normalize_api_base_url("http://provider.com:8080",).unwrap(),
            "http://provider.com:8080",
        );
    }

    #[test]
    fn strips_auth_path_components() {
        assert_eq!(
            normalize_api_base_url("https://iptv.example.com/stalker_portal/server/load.php",)
                .unwrap(),
            "https://iptv.example.com",
        );
    }

    #[test]
    fn omits_default_http_port() {
        assert_eq!(
            normalize_api_base_url("http://example.com:80/path",).unwrap(),
            "http://example.com",
        );
    }

    #[test]
    fn omits_default_https_port() {
        assert_eq!(
            normalize_api_base_url("https://example.com:443/path",).unwrap(),
            "https://example.com",
        );
    }

    #[test]
    fn preserves_https_non_default_port() {
        assert_eq!(
            normalize_api_base_url("https://example.com:8443/api",).unwrap(),
            "https://example.com:8443",
        );
    }

    #[test]
    fn strips_fragment() {
        assert_eq!(
            normalize_api_base_url("http://example.com/path#section",).unwrap(),
            "http://example.com",
        );
    }
}
