//! Error types for stream checking operations.

/// Errors that can occur during stream validation.
#[derive(Debug, thiserror::Error)]
pub enum CheckerError {
    /// HTTP request failed.
    #[error("HTTP error: {0}")]
    Http(#[from] reqwest::Error),

    /// Invalid URL provided.
    #[error("invalid URL: {0}")]
    InvalidUrl(String),

    /// Request timed out.
    #[error("request timed out after {timeout_ms}ms")]
    Timeout { timeout_ms: u64 },

    /// Connection refused by the server.
    #[error("connection refused: {0}")]
    ConnectionRefused(String),

    /// I/O error (e.g., checkpoint file operations).
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),
}

/// Summarize an error into a human-readable category.
///
/// Translated from IPTVChecker-Python `summarize_error()`:
///
/// ```python
/// def summarize_error(exc):
///     msg = str(exc).lower()
///     if isinstance(exc, requests.Timeout):
///         return "Connection timed out"
///     if isinstance(exc, requests.ConnectionError):
///         if any(kw in msg for kw in ['dns', ...]):
///             return "DNS resolution failed"
///         if 'ssl' in msg or 'tls' in msg or 'certificate' in msg or 'handshake' in msg:
///             return "SSL/TLS error"
///         if 'connection refused' in msg:
///             return "Connection refused"
///         return "Connection error"
///     if isinstance(exc, requests.TooManyRedirects):
///         return "Redirect loop"
///     return str(exc)[:80]
/// ```
pub fn summarize_error(error: &reqwest::Error) -> String {
    if error.is_timeout() {
        return "Connection timed out".to_string();
    }

    if error.is_connect() {
        let msg = error.to_string().to_lowercase();

        if msg.contains("dns")
            || msg.contains("name or service not known")
            || msg.contains("nodename nor servname")
            || msg.contains("no such host")
            || msg.contains("getaddrinfo failed")
        {
            return "DNS resolution failed".to_string();
        }

        if msg.contains("ssl")
            || msg.contains("tls")
            || msg.contains("certificate")
            || msg.contains("handshake")
        {
            return "SSL/TLS error".to_string();
        }

        if msg.contains("connection refused") {
            return "Connection refused".to_string();
        }

        return "Connection error".to_string();
    }

    if error.is_redirect() {
        return "Redirect loop".to_string();
    }

    // Truncate to 80 chars, matching Python's `str(exc)[:80]`.
    let msg = error.to_string();
    if msg.len() > 80 {
        format!("{}...", &msg[..77])
    } else {
        msg
    }
}

/// Summarize a generic error string into a human-readable category.
///
/// Works on pre-formatted error messages (not `reqwest::Error` instances).
pub fn summarize_error_str(msg: &str) -> &'static str {
    let lower = msg.to_lowercase();

    if lower.contains("timed out") || lower.contains("timeout") {
        return "Connection timed out";
    }
    if lower.contains("dns")
        || lower.contains("name or service not known")
        || lower.contains("getaddrinfo")
    {
        return "DNS resolution failed";
    }
    if lower.contains("ssl") || lower.contains("tls") || lower.contains("certificate") {
        return "SSL/TLS error";
    }
    if lower.contains("connection refused") {
        return "Connection refused";
    }
    if lower.contains("redirect") {
        return "Redirect loop";
    }
    "Connection error"
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn summarize_timeout_string() {
        assert_eq!(
            summarize_error_str("request timed out after 10000ms"),
            "Connection timed out"
        );
    }

    #[test]
    fn summarize_dns_string() {
        assert_eq!(
            summarize_error_str("DNS resolution failed for host"),
            "DNS resolution failed"
        );
    }

    #[test]
    fn summarize_ssl_string() {
        assert_eq!(summarize_error_str("SSL handshake error"), "SSL/TLS error");
    }

    #[test]
    fn summarize_refused_string() {
        assert_eq!(
            summarize_error_str("Connection refused on port 8080"),
            "Connection refused"
        );
    }

    #[test]
    fn summarize_redirect_string() {
        assert_eq!(summarize_error_str("too many redirects"), "Redirect loop");
    }

    #[test]
    fn summarize_unknown_string() {
        assert_eq!(
            summarize_error_str("some other failure"),
            "Connection error"
        );
    }
}
