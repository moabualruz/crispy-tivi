//! Error types for media probing operations.

/// Errors that can occur during media probing.
#[derive(Debug, thiserror::Error)]
pub enum ProbeError {
    /// ffprobe binary not found in PATH.
    #[error("ffprobe not found in PATH — install ffmpeg to use media probing")]
    FfprobeNotFound,

    /// ffmpeg binary not found in PATH.
    #[error("ffmpeg not found in PATH — install ffmpeg to use media probing")]
    FfmpegNotFound,

    /// Process timed out.
    #[error("operation timed out after {timeout_secs}s for {url}")]
    Timeout {
        /// The URL being probed.
        url: String,
        /// The timeout duration in seconds.
        timeout_secs: u64,
    },

    /// Process exited with non-zero status.
    #[error("process failed (exit code {code:?}): {stderr}")]
    ProcessFailed {
        /// Exit code, if available.
        code: Option<i32>,
        /// Standard error output.
        stderr: String,
    },

    /// Failed to parse ffprobe JSON output.
    #[error("failed to parse ffprobe output: {0}")]
    JsonParse(#[from] serde_json::Error),

    /// No streams found in the probed media.
    #[error("no streams found in media at {0}")]
    NoStreams(String),

    /// I/O error during subprocess execution.
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),

    /// HLS playlist recursion depth exceeded.
    #[error("HLS playlist recursion depth exceeded (max {0})")]
    HlsMaxDepth(u32),

    /// HLS playlist loop detected.
    #[error("HLS playlist loop detected at {0}")]
    HlsLoop(String),

    /// libmpv is not available on this system.
    #[cfg(feature = "libmpv-backend")]
    #[error("libmpv not available: {0}")]
    MpvUnavailable(String),

    /// libmpv handle initialization failed.
    #[cfg(feature = "libmpv-backend")]
    #[error("libmpv initialization failed: {0}")]
    MpvInitFailed(String),

    /// An mpv command or property access failed.
    #[cfg(feature = "libmpv-backend")]
    #[error("mpv command '{command}' failed: {detail}")]
    MpvCommandFailed {
        /// The command that was attempted.
        command: String,
        /// Error details from mpv.
        detail: String,
    },
}
