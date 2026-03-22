//! Stalker-specific error types.
//!
//! Maps to [`crispy_iptv_types::IptvError`] variants where applicable,
//! but provides richer context for Stalker portal failures.

use thiserror::Error;

/// Errors produced by [`StalkerClient`](crate::StalkerClient) operations.
#[derive(Debug, Error)]
pub enum StalkerError {
    /// Portal URL could not be discovered at any known path.
    #[error("portal not found at any known path for base URL: {0}")]
    PortalNotFound(String),

    /// Handshake failed — server did not return a valid token.
    #[error("handshake failed: {0}")]
    HandshakeFailed(String),

    /// Authentication rejected (wrong MAC, blocked account, etc.).
    #[error("authentication failed: {0}")]
    Auth(String),

    /// Session token expired — must re-authenticate.
    #[error("session expired")]
    SessionExpired,

    /// Server returned data in an unexpected format.
    #[error("unexpected response: {0}")]
    UnexpectedResponse(String),

    /// HTTP / network transport error.
    #[error("network error: {0}")]
    Network(#[from] reqwest::Error),

    /// URL parsing failure.
    #[error("invalid URL: {0}")]
    InvalidUrl(#[from] url::ParseError),

    /// JSON deserialization failure.
    #[error("JSON parse error: {0}")]
    Json(#[from] serde_json::Error),

    /// Client has not been authenticated yet.
    #[error("not authenticated — call authenticate() first")]
    NotAuthenticated,
}

impl From<&StalkerError> for crispy_iptv_types::IptvError {
    fn from(e: &StalkerError) -> Self {
        match e {
            StalkerError::Auth(msg) => crispy_iptv_types::IptvError::Auth(msg.clone()),
            StalkerError::SessionExpired => {
                crispy_iptv_types::IptvError::SessionExpired("stalker session expired".into())
            }
            StalkerError::Network(e) => crispy_iptv_types::IptvError::Network(e.to_string()),
            StalkerError::InvalidUrl(e) => crispy_iptv_types::IptvError::InvalidUrl(e.to_string()),
            other => crispy_iptv_types::IptvError::UnexpectedResponse(other.to_string()),
        }
    }
}
