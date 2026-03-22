//! Error types for M3U parsing and writing.

use thiserror::Error;

/// Errors that can occur during M3U parsing or writing.
#[derive(Debug, Error)]
pub enum M3uError {
    /// The input is not a valid M3U playlist (missing `#EXTM3U` header).
    #[error("invalid M3U: missing #EXTM3U header")]
    MissingHeader,

    /// A parse error at a specific line.
    #[error("parse error at line {line}: {message}")]
    Parse {
        /// 1-based line number where the error occurred.
        line: usize,
        /// Human-readable description of the error.
        message: String,
    },

    /// An I/O error (e.g. reading from a file).
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
}
