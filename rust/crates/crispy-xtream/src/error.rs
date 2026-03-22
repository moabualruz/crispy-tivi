//! Error types for the Xtream API client.

use thiserror::Error;

/// Errors that can occur when interacting with an Xtream Codes API server.
#[derive(Debug, Error)]
pub enum XtreamError {
    /// Authentication failed (invalid credentials, disabled account).
    #[error("auth error: {0}")]
    Auth(String),

    /// Account expired or session invalid.
    #[error("session expired: {0}")]
    SessionExpired(String),

    /// Server returned 429 Too Many Requests.
    #[error("rate limited: retry after {retry_after_secs}s")]
    RateLimited {
        /// Suggested retry delay in seconds (from `Retry-After` header or default).
        retry_after_secs: u64,
    },

    /// HTTP or network-level failure.
    #[error("network error: {0}")]
    Network(String),

    /// Request timed out.
    #[error("timeout: {0}")]
    Timeout(String),

    /// Server returned JSON we could not deserialize.
    #[error("unexpected response: {0}")]
    UnexpectedResponse(String),

    /// The requested resource was not found (empty info array, null name, etc.).
    #[error("not found: {0}")]
    NotFound(String),

    /// Invalid URL or configuration.
    #[error("invalid url: {0}")]
    InvalidUrl(String),
}

impl From<reqwest::Error> for XtreamError {
    fn from(err: reqwest::Error) -> Self {
        if err.is_timeout() {
            return Self::Timeout(err.to_string());
        }
        if err.is_connect() {
            return Self::Network(format!("connection failed: {err}"));
        }
        if err.is_decode() {
            return Self::UnexpectedResponse(format!("decode error: {err}"));
        }
        Self::Network(err.to_string())
    }
}

impl From<serde_json::Error> for XtreamError {
    fn from(err: serde_json::Error) -> Self {
        Self::UnexpectedResponse(format!("json parse error: {err}"))
    }
}

impl From<url::ParseError> for XtreamError {
    fn from(err: url::ParseError) -> Self {
        Self::InvalidUrl(err.to_string())
    }
}

impl From<XtreamError> for crispy_iptv_types::IptvError {
    fn from(err: XtreamError) -> Self {
        match err {
            XtreamError::Auth(msg) => Self::Auth(msg),
            XtreamError::SessionExpired(msg) => Self::SessionExpired(msg),
            XtreamError::RateLimited { retry_after_secs } => Self::RateLimited { retry_after_secs },
            XtreamError::Network(msg) => Self::Network(msg),
            XtreamError::Timeout(msg) => Self::Timeout(0).into_network(msg),
            XtreamError::UnexpectedResponse(msg) => Self::UnexpectedResponse(msg),
            XtreamError::NotFound(msg) => Self::UnexpectedResponse(msg),
            XtreamError::InvalidUrl(msg) => Self::InvalidUrl(msg),
        }
    }
}

/// Helper trait — not part of the public API.
trait IntoNetwork {
    fn into_network(self, msg: String) -> crispy_iptv_types::IptvError;
}

impl IntoNetwork for crispy_iptv_types::IptvError {
    fn into_network(self, msg: String) -> crispy_iptv_types::IptvError {
        crispy_iptv_types::IptvError::Network(msg)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn display_auth_error() {
        let err = XtreamError::Auth("bad credentials".into());
        assert_eq!(err.to_string(), "auth error: bad credentials");
    }

    #[test]
    fn display_rate_limited() {
        let err = XtreamError::RateLimited {
            retry_after_secs: 30,
        };
        assert_eq!(err.to_string(), "rate limited: retry after 30s");
    }

    #[test]
    fn from_serde_json_error() {
        let raw = serde_json::from_str::<serde_json::Value>("not json").unwrap_err();
        let err = XtreamError::from(raw);
        assert!(matches!(err, XtreamError::UnexpectedResponse(_)));
    }

    #[test]
    fn from_url_parse_error() {
        let raw = url::Url::parse("://bad").unwrap_err();
        let err = XtreamError::from(raw);
        assert!(matches!(err, XtreamError::InvalidUrl(_)));
    }

    #[test]
    fn converts_to_iptv_error() {
        let err = XtreamError::Auth("test".into());
        let iptv: crispy_iptv_types::IptvError = err.into();
        assert!(matches!(iptv, crispy_iptv_types::IptvError::Auth(_)));
    }
}
