//! Catchup error types.

/// Errors that can occur during catchup URL generation or validation.
#[derive(Debug, thiserror::Error)]
pub enum CatchupError {
    /// The catchup mode is disabled for this channel.
    #[error("catchup is disabled for this channel")]
    Disabled,

    /// The catchup source template is empty or invalid.
    #[error("invalid catchup source: {0}")]
    InvalidSource(String),

    /// The requested time is outside the catchup window.
    #[error("requested time {requested} is outside the catchup window of {window_days} days")]
    OutsideWindow { requested: i64, window_days: i32 },

    /// Failed to parse a provider URL (Flussonic or Xtream Codes).
    #[error("failed to parse {provider} URL: {url}")]
    UrlParseFailed { provider: String, url: String },

    /// A regex compilation error.
    #[error("regex error: {0}")]
    Regex(#[from] regex::Error),
}
