//! Crash recovery — persists app state across unclean shutdowns.
//!
//! On clean exit call `mark_clean_exit`. On startup call
//! `was_unclean_shutdown` to detect a crash, then
//! `get_recovery_state` to restore the last known screen / content.
//!
//! After an unclean shutdown the DB is integrity-checked. A corrupt
//! DB triggers notification via the callback passed to
//! `check_db_integrity`.

use crate::database::{Database, DbError, optional_or};
use rusqlite::params;

// ── RecoveryState ─────────────────────────────────────────────────────────────

/// Last-known app state for crash recovery.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RecoveryState {
    /// Screen name the user was on (e.g. `"live"`, `"vod"`, `"epg"`).
    pub screen: String,
    /// Content being played or browsed, if applicable.
    pub content_id: Option<String>,
    /// Whether playback was active at the time of save.
    pub playback_active: bool,
}

// ── Table DDL ─────────────────────────────────────────────────────────────────

const CREATE_TABLE: &str = "
CREATE TABLE IF NOT EXISTS db_crash_recovery (
    id              INTEGER PRIMARY KEY CHECK (id = 1),
    screen          TEXT    NOT NULL DEFAULT '',
    content_id      TEXT,
    playback_active INTEGER NOT NULL DEFAULT 0,
    clean_exit      INTEGER NOT NULL DEFAULT 0
)";

const ENSURE_ROW: &str = "INSERT OR IGNORE INTO db_crash_recovery (id) VALUES (1)";

// ── CrashRecovery ─────────────────────────────────────────────────────────────

/// Manages unclean-shutdown detection and app-state persistence.
pub struct CrashRecovery;

impl CrashRecovery {
    /// Ensure the recovery table and singleton row exist.
    pub fn ensure_table(db: &Database) -> Result<(), DbError> {
        let conn = db.get()?;
        conn.execute_batch(CREATE_TABLE)?;
        conn.execute(ENSURE_ROW, [])?;
        Ok(())
    }

    // ── State persistence ────────────────────────────────────────────────────

    /// Persist the current app state.
    ///
    /// Also clears `clean_exit` (marks session as dirty until
    /// `mark_clean_exit` is called).
    pub fn save_app_state(
        db: &Database,
        screen: &str,
        content_id: Option<&str>,
        playback_active: bool,
    ) -> Result<(), DbError> {
        let conn = db.get()?;
        conn.execute(
            "UPDATE db_crash_recovery
             SET screen = ?1, content_id = ?2, playback_active = ?3, clean_exit = 0
             WHERE id = 1",
            params![screen, content_id, playback_active as i32],
        )?;
        Ok(())
    }

    /// Return the persisted recovery state, if any meaningful state was saved.
    ///
    /// Returns `None` if no state was ever written.
    pub fn get_recovery_state(db: &Database) -> Result<Option<RecoveryState>, DbError> {
        let conn = db.get()?;
        let result: rusqlite::Result<(String, Option<String>, i32)> = conn.query_row(
            "SELECT screen, content_id, playback_active FROM db_crash_recovery WHERE id = 1",
            [],
            |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?)),
        );
        match result {
            Ok((screen, content_id, playback_active)) => {
                if screen.is_empty() {
                    Ok(None)
                } else {
                    Ok(Some(RecoveryState {
                        screen,
                        content_id,
                        playback_active: playback_active != 0,
                    }))
                }
            }
            Err(e) => Err(DbError::Sqlite(e)),
        }
    }

    /// Clear the persisted recovery state (e.g. after successful restore).
    pub fn clear_recovery_state(db: &Database) -> Result<(), DbError> {
        let conn = db.get()?;
        conn.execute(
            "UPDATE db_crash_recovery
             SET screen = '', content_id = NULL, playback_active = 0
             WHERE id = 1",
            [],
        )?;
        Ok(())
    }

    // ── Clean exit marker ────────────────────────────────────────────────────

    /// Mark the current session as clean (called on normal exit).
    pub fn mark_clean_exit(db: &Database) -> Result<(), DbError> {
        let conn = db.get()?;
        conn.execute(
            "UPDATE db_crash_recovery SET clean_exit = 1 WHERE id = 1",
            [],
        )?;
        Ok(())
    }

    /// Returns `true` if the previous session ended without a clean-exit mark.
    pub fn was_unclean_shutdown(db: &Database) -> Result<bool, DbError> {
        let conn = db.get()?;
        let result: rusqlite::Result<i32> = conn.query_row(
            "SELECT clean_exit FROM db_crash_recovery WHERE id = 1",
            [],
            |row| row.get(0),
        );
        Ok(optional_or(result, 1)? == 0)
    }

    // ── DB integrity ─────────────────────────────────────────────────────────

    /// Run SQLite `PRAGMA integrity_check` and return the result lines.
    ///
    /// An `["ok"]` response means the DB is healthy. Any other content
    /// indicates corruption. On failure the caller is responsible for
    /// triggering a backup-preserve + rebuild flow.
    pub fn check_db_integrity(db: &Database) -> Result<Vec<String>, DbError> {
        let conn = db.get()?;
        let mut stmt = conn
            .prepare("PRAGMA integrity_check")
            .map_err(DbError::Sqlite)?;
        let rows = stmt
            .query_map([], |row| row.get::<_, String>(0))
            .map_err(DbError::Sqlite)?;
        let mut results = Vec::new();
        for row in rows {
            results.push(row.map_err(DbError::Sqlite)?);
        }
        Ok(results)
    }

    /// Returns `true` if `integrity_check` reports clean.
    pub fn is_db_healthy(db: &Database) -> Result<bool, DbError> {
        let lines = Self::check_db_integrity(db)?;
        Ok(lines == vec!["ok".to_string()])
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::database::Database;

    fn setup() -> Database {
        let db = Database::open_in_memory().expect("in-memory DB");
        CrashRecovery::ensure_table(&db).expect("ensure_table");
        db
    }

    #[test]
    fn test_save_and_get_recovery_state() {
        let db = setup();
        CrashRecovery::save_app_state(&db, "live", Some("ch-001"), true).unwrap();
        let state = CrashRecovery::get_recovery_state(&db).unwrap().unwrap();
        assert_eq!(state.screen, "live");
        assert_eq!(state.content_id, Some("ch-001".to_string()));
        assert!(state.playback_active);
    }

    #[test]
    fn test_get_recovery_state_no_state() {
        let db = setup();
        assert!(CrashRecovery::get_recovery_state(&db).unwrap().is_none());
    }

    #[test]
    fn test_clear_recovery_state() {
        let db = setup();
        CrashRecovery::save_app_state(&db, "vod", Some("movie-42"), false).unwrap();
        CrashRecovery::clear_recovery_state(&db).unwrap();
        assert!(CrashRecovery::get_recovery_state(&db).unwrap().is_none());
    }

    #[test]
    fn test_mark_clean_exit_and_detect() {
        let db = setup();
        // Initially row exists with clean_exit=0 → unclean.
        assert!(CrashRecovery::was_unclean_shutdown(&db).unwrap());
        CrashRecovery::mark_clean_exit(&db).unwrap();
        assert!(!CrashRecovery::was_unclean_shutdown(&db).unwrap());
    }

    #[test]
    fn test_save_clears_clean_exit_flag() {
        let db = setup();
        CrashRecovery::mark_clean_exit(&db).unwrap();
        assert!(!CrashRecovery::was_unclean_shutdown(&db).unwrap());
        // Saving state marks session as dirty again.
        CrashRecovery::save_app_state(&db, "epg", None, false).unwrap();
        assert!(CrashRecovery::was_unclean_shutdown(&db).unwrap());
    }

    #[test]
    fn test_db_integrity_check_healthy() {
        let db = setup();
        assert!(CrashRecovery::is_db_healthy(&db).unwrap());
    }

    #[test]
    fn test_playback_active_false_roundtrip() {
        let db = setup();
        CrashRecovery::save_app_state(&db, "home", None, false).unwrap();
        let s = CrashRecovery::get_recovery_state(&db).unwrap().unwrap();
        assert!(!s.playback_active);
        assert!(s.content_id.is_none());
    }

    #[test]
    fn test_overwrite_state() {
        let db = setup();
        CrashRecovery::save_app_state(&db, "live", Some("ch-1"), true).unwrap();
        CrashRecovery::save_app_state(&db, "home", None, false).unwrap();
        let s = CrashRecovery::get_recovery_state(&db).unwrap().unwrap();
        assert_eq!(s.screen, "home");
        assert!(s.content_id.is_none());
    }
}
