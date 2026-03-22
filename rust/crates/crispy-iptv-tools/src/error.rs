//! Error types for IPTV tools operations.

/// Errors that can occur during IPTV tools operations.
#[derive(Debug, thiserror::Error)]
pub enum ToolsError {
    /// Invalid URL format.
    #[error("invalid URL: {0}")]
    InvalidUrl(String),

    /// Invalid regex pattern.
    #[error("invalid regex pattern: {0}")]
    InvalidPattern(#[from] regex::Error),

    /// Empty input where non-empty was expected.
    #[error("empty input: {0}")]
    EmptyInput(String),

    /// Invalid configuration (e.g., malformed JSON).
    #[error("invalid config: {0}")]
    InvalidConfig(String),
}
