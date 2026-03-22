//! Structured error types for IPTV operations.

use thiserror::Error;

/// Top-level error enum for all IPTV crate operations.
#[derive(Debug, Error)]
pub enum IptvError {
    /// M3U/playlist parsing failure.
    #[error("parse error at line {line}: {message}")]
    Parse { line: usize, message: String },

    /// XMLTV/EPG parsing failure.
    #[error("XML error: {0}")]
    Xml(String),

    /// HTTP / network error.
    #[error("network error: {0}")]
    Network(String),

    /// Authentication failure (Xtream, Stalker).
    #[error("auth error: {0}")]
    Auth(String),

    /// Session expired (Stalker token, Xtream account).
    #[error("session expired: {0}")]
    SessionExpired(String),

    /// Rate limited by server.
    #[error("rate limited: retry after {retry_after_secs}s")]
    RateLimited { retry_after_secs: u64 },

    /// Invalid URL or endpoint.
    #[error("invalid URL: {0}")]
    InvalidUrl(String),

    /// Server returned unexpected data format.
    #[error("unexpected response: {0}")]
    UnexpectedResponse(String),

    /// Timeout waiting for server response.
    #[error("timeout after {0}ms")]
    Timeout(u64),

    /// Stream unavailable or dead.
    #[error("stream unavailable: {0}")]
    StreamUnavailable(String),

    /// Generic I/O error.
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
}
