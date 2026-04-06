//! Playback checkpoint and recovery for CrispyTivi.
//!
//! Persists resume positions for VOD and Live TV. After a
//! reconnect, callers retrieve the last checkpoint to resume
//! from the correct position.
//!
//! Checkpoints are stored in the existing `db_watch_history`
//! table using `position_ms`. A dedicated outbox table
//! `db_playback_checkpoints` is created for fast key-value
//! lookup without scanning history.

use chrono::{DateTime, Utc};
use rusqlite::params;
use serde::{Deserialize, Serialize};

use crate::upsert;

use crate::database::{optional, Database, DbError};

// ── DDL ──────────────────────────────────────────────────

const CREATE_CHECKPOINTS: &str = "\
CREATE TABLE IF NOT EXISTS db_playback_checkpoints (
    content_id      TEXT PRIMARY KEY NOT NULL,
    position_secs   REAL NOT NULL,
    timestamp       INTEGER NOT NULL,
    content_type    TEXT NOT NULL
);
";

// ── ContentType ──────────────────────────────────────────

/// Classification of playable content.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ContentType {
    /// Live television channel.
    Live,
    /// VOD movie.
    Movie,
    /// TV series episode.
    Episode,
}

impl ContentType {
    fn as_str(self) -> &'static str {
        match self {
            Self::Live => "live",
            Self::Movie => "movie",
            Self::Episode => "episode",
        }
    }

    fn from_str(s: &str) -> Self {
        match s {
            "live" => Self::Live,
            "movie" => Self::Movie,
            _ => Self::Episode,
        }
    }
}

// ── PlaybackCheckpoint ───────────────────────────────────

/// A persisted playback position.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlaybackCheckpoint {
    /// Unique content identifier (stream URL or VOD id).
    pub content_id: String,
    /// Resume position in seconds. For live TV this is ignored
    /// (always resume at live edge).
    pub position_secs: f64,
    /// Wall-clock time when the checkpoint was written.
    pub timestamp: DateTime<Utc>,
    /// Whether this is live, movie, or episode content.
    pub content_type: ContentType,
}

// ── PlaybackRecovery ─────────────────────────────────────

/// Manages playback checkpoints for resume-on-reconnect.
pub struct PlaybackRecovery;

impl PlaybackRecovery {
    /// Ensure the checkpoints table exists.
    pub fn ensure_table(db: &Database) -> Result<(), DbError> {
        db.get()?.execute_batch(CREATE_CHECKPOINTS)?;
        Ok(())
    }

    /// Write (upsert) a checkpoint. Called at pause, stop,
    /// every 30 s during playback, and on app background.
    pub fn save_checkpoint(db: &Database, checkpoint: &PlaybackCheckpoint) -> Result<(), DbError> {
        let conn = db.get()?;
        upsert!(
            conn,
            "db_playback_checkpoints",
            ["content_id", "position_secs", "timestamp", "content_type"],
            "content_id",
            params![
                checkpoint.content_id,
                checkpoint.position_secs,
                checkpoint.timestamp.timestamp(),
                checkpoint.content_type.as_str(),
            ],
        )?;
        Ok(())
    }

    /// Retrieve the resume position for `content_id`.
    ///
    /// - **VOD (Movie / Episode):** returns the checkpointed
    ///   `position_secs`.
    /// - **Live TV:** always returns `None` — live streams
    ///   resume at the live edge (caller tunes to "now").
    pub fn get_resume_position(db: &Database, content_id: &str) -> Result<Option<f64>, DbError> {
        let conn = db.get()?;
        let result: rusqlite::Result<(f64, String)> = conn.query_row(
            "SELECT position_secs, content_type \
             FROM db_playback_checkpoints \
             WHERE content_id = ?1",
            params![content_id],
            |row| Ok((row.get::<_, f64>(0)?, row.get::<_, String>(1)?)),
        );

        match optional(result)? {
            Some((pos, content_type_str)) => {
                if ContentType::from_str(&content_type_str) == ContentType::Live {
                    Ok(None) // live TV always resumes at live edge
                } else {
                    Ok(Some(pos))
                }
            }
            None => Ok(None),
        }
    }

    /// Load the full checkpoint record for `content_id`.
    pub fn get_checkpoint(
        db: &Database,
        content_id: &str,
    ) -> Result<Option<PlaybackCheckpoint>, DbError> {
        let conn = db.get()?;
        let result: rusqlite::Result<(f64, i64, String)> = conn.query_row(
            "SELECT position_secs, timestamp, content_type \
             FROM db_playback_checkpoints \
             WHERE content_id = ?1",
            params![content_id],
            |row| {
                Ok((
                    row.get::<_, f64>(0)?,
                    row.get::<_, i64>(1)?,
                    row.get::<_, String>(2)?,
                ))
            },
        );

        Ok(optional(result)?.map(|(position_secs, ts, ct_str)| {
            let timestamp = DateTime::from_timestamp(ts, 0).unwrap_or_default();
            PlaybackCheckpoint {
                content_id: content_id.to_string(),
                position_secs,
                timestamp,
                content_type: ContentType::from_str(&ct_str),
            }
        }))
    }

    /// Delete the checkpoint for `content_id` (e.g. when a VOD
    /// reaches the end and should restart from beginning).
    pub fn clear_checkpoint(db: &Database, content_id: &str) -> Result<(), DbError> {
        db.get()?.execute(
            "DELETE FROM db_playback_checkpoints WHERE content_id = ?1",
            params![content_id],
        )?;
        Ok(())
    }
}

// ── Tests ─────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::database::Database;

    fn setup() -> Database {
        let db = Database::open_in_memory().expect("open_in_memory");
        PlaybackRecovery::ensure_table(&db).expect("ensure_table");
        db
    }

    fn make_checkpoint(id: &str, pos: f64, ct: ContentType) -> PlaybackCheckpoint {
        PlaybackCheckpoint {
            content_id: id.to_string(),
            position_secs: pos,
            timestamp: Utc::now(),
            content_type: ct,
        }
    }

    #[test]
    fn test_save_and_get_checkpoint_movie() {
        let db = setup();
        let cp = make_checkpoint("movie-1", 125.5, ContentType::Movie);
        PlaybackRecovery::save_checkpoint(&db, &cp).unwrap();

        let pos = PlaybackRecovery::get_resume_position(&db, "movie-1")
            .unwrap()
            .expect("should have position");
        assert!((pos - 125.5).abs() < 0.01);
    }

    #[test]
    fn test_save_and_get_checkpoint_episode() {
        let db = setup();
        let cp = make_checkpoint("ep-s01e01", 300.0, ContentType::Episode);
        PlaybackRecovery::save_checkpoint(&db, &cp).unwrap();

        let pos = PlaybackRecovery::get_resume_position(&db, "ep-s01e01")
            .unwrap()
            .expect("should have position");
        assert!((pos - 300.0).abs() < 0.01);
    }

    #[test]
    fn test_live_tv_resume_position_is_none() {
        let db = setup();
        let cp = make_checkpoint("channel-news", 99999.0, ContentType::Live);
        PlaybackRecovery::save_checkpoint(&db, &cp).unwrap();

        // Live TV must always return None (resume at live edge).
        let pos = PlaybackRecovery::get_resume_position(&db, "channel-news").unwrap();
        assert!(pos.is_none());
    }

    #[test]
    fn test_get_resume_position_missing_returns_none() {
        let db = setup();
        let pos = PlaybackRecovery::get_resume_position(&db, "nonexistent").unwrap();
        assert!(pos.is_none());
    }

    #[test]
    fn test_upsert_updates_position() {
        let db = setup();
        let cp1 = make_checkpoint("movie-2", 50.0, ContentType::Movie);
        PlaybackRecovery::save_checkpoint(&db, &cp1).unwrap();

        let cp2 = make_checkpoint("movie-2", 180.0, ContentType::Movie);
        PlaybackRecovery::save_checkpoint(&db, &cp2).unwrap();

        let pos = PlaybackRecovery::get_resume_position(&db, "movie-2")
            .unwrap()
            .unwrap();
        assert!((pos - 180.0).abs() < 0.01);
    }

    #[test]
    fn test_clear_checkpoint() {
        let db = setup();
        let cp = make_checkpoint("movie-3", 60.0, ContentType::Movie);
        PlaybackRecovery::save_checkpoint(&db, &cp).unwrap();

        PlaybackRecovery::clear_checkpoint(&db, "movie-3").unwrap();
        let pos = PlaybackRecovery::get_resume_position(&db, "movie-3").unwrap();
        assert!(pos.is_none());
    }

    #[test]
    fn test_get_full_checkpoint_fields() {
        let db = setup();
        let cp = make_checkpoint("ep-s02e03", 240.0, ContentType::Episode);
        PlaybackRecovery::save_checkpoint(&db, &cp).unwrap();

        let loaded = PlaybackRecovery::get_checkpoint(&db, "ep-s02e03")
            .unwrap()
            .expect("checkpoint exists");
        assert_eq!(loaded.content_id, "ep-s02e03");
        assert!((loaded.position_secs - 240.0).abs() < 0.01);
        assert_eq!(loaded.content_type, ContentType::Episode);
    }

    #[test]
    fn test_content_type_roundtrip() {
        for ct in [ContentType::Live, ContentType::Movie, ContentType::Episode] {
            assert_eq!(ContentType::from_str(ct.as_str()), ct);
        }
    }
}
