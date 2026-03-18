//! CrispyTivi error taxonomy.
//!
//! All public-facing error types live here. Service code converts
//! lower-level errors (`DbError`, `reqwest::Error`, etc.) into
//! `CrispyError` variants at the service boundary so callers have
//! a single type to match against.

use thiserror::Error;

use crate::database::DbError;

/// Top-level error type for the CrispyTivi domain.
#[derive(Error, Debug)]
pub enum CrispyError {
    /// A network request failed (DNS, TCP, TLS, timeout).
    #[error("Network error: {message}")]
    Network {
        message: String,
        #[source]
        source: Option<Box<dyn std::error::Error + Send + Sync>>,
    },

    /// A source provider returned an unexpected response or rejected auth.
    #[error("Source provider error: {message}")]
    SourceProvider {
        message: String,
        source_id: Option<i64>,
    },

    /// Stream playback could not be started or was interrupted.
    #[error("Stream playback error: {message}")]
    StreamPlayback { message: String },

    /// A storage / file-system operation failed.
    #[error("Storage error: {message}")]
    Storage { message: String },

    /// Authentication or profile operation failed.
    #[error("Authentication error: {message}")]
    AuthProfile { message: String },

    /// A player backend operation failed.
    #[error("Player error: {message}")]
    Player { message: String },

    /// An unexpected system-level error occurred.
    #[error("System error: {message}")]
    System { message: String },

    /// A database operation failed.
    #[error("Database error: {0}")]
    Database(#[from] rusqlite::Error),

    /// An HTTP request or response error.
    #[error("HTTP error: {0}")]
    Http(#[from] reqwest::Error),

    /// A JSON serialisation / deserialisation error.
    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),

    /// An I/O error (file read/write).
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),

    /// A security policy violation (blocked URL scheme, crypto failure, etc.).
    #[error("Security error: {message}")]
    Security { message: String },
}

impl From<url::ParseError> for CrispyError {
    fn from(e: url::ParseError) -> Self {
        CrispyError::Security {
            message: format!("Invalid URL: {e}"),
        }
    }
}

// ── From conversions ──────────────────────────────────────────────────────────

impl From<DbError> for CrispyError {
    fn from(e: DbError) -> Self {
        match e {
            DbError::Sqlite(inner) => CrispyError::Database(inner),
            DbError::Migration(msg) => CrispyError::Storage { message: msg },
            DbError::NotFound => CrispyError::Storage {
                message: "Entity not found".to_string(),
            },
        }
    }
}

impl From<anyhow::Error> for CrispyError {
    fn from(e: anyhow::Error) -> Self {
        CrispyError::System {
            message: e.to_string(),
        }
    }
}

// ── Convenience constructors ──────────────────────────────────────────────────

impl CrispyError {
    /// Construct a `Network` variant with an optional boxed source.
    pub fn network(message: impl Into<String>) -> Self {
        CrispyError::Network {
            message: message.into(),
            source: None,
        }
    }

    /// Construct a `Network` variant wrapping a concrete error.
    pub fn network_from<E>(message: impl Into<String>, err: E) -> Self
    where
        E: std::error::Error + Send + Sync + 'static,
    {
        CrispyError::Network {
            message: message.into(),
            source: Some(Box::new(err)),
        }
    }

    /// Construct a `SourceProvider` variant.
    pub fn source_provider(message: impl Into<String>, source_id: Option<i64>) -> Self {
        CrispyError::SourceProvider {
            message: message.into(),
            source_id,
        }
    }

    /// Construct a `Player` variant.
    pub fn player(message: impl Into<String>) -> Self {
        CrispyError::Player {
            message: message.into(),
        }
    }

    /// Construct a `Storage` variant.
    pub fn storage(message: impl Into<String>) -> Self {
        CrispyError::Storage {
            message: message.into(),
        }
    }

    /// Construct an `AuthProfile` variant.
    pub fn auth(message: impl Into<String>) -> Self {
        CrispyError::AuthProfile {
            message: message.into(),
        }
    }

    /// Construct a `Security` variant.
    pub fn security(message: impl Into<String>) -> Self {
        CrispyError::Security {
            message: message.into(),
        }
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn network_variant_display() {
        let e = CrispyError::network("connection refused");
        assert_eq!(e.to_string(), "Network error: connection refused");
    }

    #[test]
    fn source_provider_variant_display() {
        let e = CrispyError::source_provider("401 Unauthorized", Some(42));
        assert_eq!(e.to_string(), "Source provider error: 401 Unauthorized");
    }

    #[test]
    fn stream_playback_variant_display() {
        let e = CrispyError::StreamPlayback {
            message: "codec unsupported".to_string(),
        };
        assert_eq!(e.to_string(), "Stream playback error: codec unsupported");
    }

    #[test]
    fn storage_variant_display() {
        let e = CrispyError::storage("disk full");
        assert_eq!(e.to_string(), "Storage error: disk full");
    }

    #[test]
    fn auth_variant_display() {
        let e = CrispyError::auth("wrong PIN");
        assert_eq!(e.to_string(), "Authentication error: wrong PIN");
    }

    #[test]
    fn player_variant_display() {
        let e = CrispyError::player("mpv initialisation failed");
        assert_eq!(e.to_string(), "Player error: mpv initialisation failed");
    }

    #[test]
    fn system_variant_display() {
        let e = CrispyError::System {
            message: "OOM".to_string(),
        };
        assert_eq!(e.to_string(), "System error: OOM");
    }

    #[test]
    fn from_rusqlite_error() {
        let sqlite_err = rusqlite::Error::QueryReturnedNoRows;
        let e: CrispyError = CrispyError::Database(sqlite_err);
        assert!(e.to_string().starts_with("Database error:"));
    }

    #[test]
    fn from_serde_json_error() {
        let json_err = serde_json::from_str::<serde_json::Value>("invalid json {").unwrap_err();
        let e: CrispyError = json_err.into();
        assert!(e.to_string().starts_with("JSON error:"));
    }

    #[test]
    fn from_db_error_not_found() {
        let db_err = DbError::NotFound;
        let e: CrispyError = db_err.into();
        assert!(matches!(e, CrispyError::Storage { .. }));
        assert!(e.to_string().contains("not found"));
    }

    #[test]
    fn from_db_error_migration() {
        let db_err = DbError::Migration("schema version mismatch".to_string());
        let e: CrispyError = db_err.into();
        assert!(matches!(e, CrispyError::Storage { .. }));
        assert!(e.to_string().contains("schema version mismatch"));
    }

    #[test]
    fn network_from_wraps_source() {
        let io_err = std::io::Error::new(std::io::ErrorKind::ConnectionRefused, "refused");
        let e = CrispyError::network_from("could not connect", io_err);
        assert!(e.to_string().contains("could not connect"));
        // source() is available via std::error::Error trait
        use std::error::Error;
        assert!(e.source().is_some());
    }
}
