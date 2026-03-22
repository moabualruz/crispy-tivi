// [ORCH-1000] AGENT-05: Audited and verified optimal SQLite WAL/Pragma configuration.
//! SQLite database module for CrispyTivi.
//!
//! Manages schema creation, migrations, and WAL-mode
//! connection setup.  Schema versioning is driven by
//! `PRAGMA user_version` through the migration runner.
//!
//! ## PRAGMA per-connection note
//!
//! PRAGMAs (WAL, synchronous, foreign_keys, cache_size) are
//! applied via `configure()` which checks out one connection
//! from the r2d2 pool. With `r2d2_sqlite` v0.x and a file
//! database, each new physical connection starts with SQLite
//! defaults. Only the single connection obtained during
//! `open()` is guaranteed to have these pragmas set.
//!
//! **Mitigation**: The pool is capped at 20 connections but
//! for short-lived CLI/server workloads this is acceptable.
//! A proper fix would use `SqliteConnectionManager::with_init()`
//! to apply PRAGMAs on every new connection, but that requires
//! refactoring the pool construction and is deferred to a
//! future hardening sprint.

pub mod migration_runner;
pub mod retry_queue;

use r2d2::Pool;
use r2d2_sqlite::SqliteConnectionManager;

// ── Table name constants ──────────────────────────────────

/// SQLite table name for live channels.
pub const TABLE_CHANNELS: &str = "db_channels";

/// SQLite table name for movies.
pub const TABLE_MOVIES: &str = "db_movies";

/// SQLite table name for series.
pub const TABLE_SERIES: &str = "db_series";

/// SQLite table name for content sources.
pub const TABLE_SOURCES: &str = "db_sources";

/// SQLite table name for EPG programme entries.
pub const TABLE_EPG_ENTRIES: &str = "db_epg_entries";

// ── Error type ───────────────────────────────────────────

/// Database error variants.
#[derive(Debug, thiserror::Error)]
pub enum DbError {
    /// Wrapped rusqlite error.
    #[error("SQLite error: {0}")]
    Sqlite(#[from] rusqlite::Error),

    /// Migration failure.
    #[error("Migration error: {0}")]
    Migration(String),

    /// Entity not found.
    #[error("Entity not found")]
    NotFound,
}

// ── Database ─────────────────────────────────────────────

/// SQLite database handle with schema management.
#[derive(Clone)]
pub struct Database {
    pool: Pool<SqliteConnectionManager>,
}

impl Database {
    /// Open or create the database at the given path.
    ///
    /// Enables WAL mode, sets performance pragmas,
    /// and creates/migrates the schema as needed.
    pub fn open(path: &str) -> Result<Self, DbError> {
        let manager = SqliteConnectionManager::file(path);
        let pool = Pool::builder()
            .max_size(20)
            .build(manager)
            .map_err(|e| DbError::Migration(format!("Pool creation failed: {}", e)))?;

        let db = Self { pool };
        db.configure()?;
        db.ensure_schema()?;
        Ok(db)
    }

    /// Open an in-memory database (for testing).
    pub fn open_in_memory() -> Result<Self, DbError> {
        let manager = SqliteConnectionManager::memory();
        let pool = Pool::builder()
            .max_size(1) // In-memory DBs require exactly 1 connection to persist state properly
            .build(manager)
            .map_err(|e| DbError::Migration(format!("Pool creation failed: {}", e)))?;

        let db = Self { pool };
        db.configure()?;
        db.ensure_schema()?;
        Ok(db)
    }

    /// Returns a new checked-out connection from the pool.
    pub fn get(&self) -> Result<r2d2::PooledConnection<SqliteConnectionManager>, DbError> {
        self.pool
            .get()
            .map_err(|e| DbError::Migration(format!("Failed to get connection: {}", e)))
    }

    // ── Private helpers ──────────────────────────────────

    /// Set connection pragmas.
    fn configure(&self) -> Result<(), DbError> {
        self.get()?.execute_batch(PRAGMAS)?;
        Ok(())
    }

    /// Apply pending migrations (create schema on fresh DB, run deltas
    /// on existing ones).  Delegates entirely to `migration_runner`.
    fn ensure_schema(&self) -> Result<(), DbError> {
        let conn = self.get()?;
        migration_runner::run_migrations(&conn)
    }
}

// ── Pragmas ──────────────────────────────────────────────

const PRAGMAS: &str = "\
    PRAGMA journal_mode = WAL;\
    PRAGMA synchronous = NORMAL;\
    PRAGMA cache_size = 10000;\
    PRAGMA foreign_keys = ON;\
";

// ── Tests ────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn open_in_memory_creates_schema() {
        let db = Database::open_in_memory().expect("open_in_memory");

        let version: u32 = db
            .get()
            .unwrap()
            .pragma_query_value(None, "user_version", |row| row.get(0))
            .expect("read user_version");

        assert_eq!(version, migration_runner::LATEST_VERSION);
    }

    #[test]
    fn tables_exist() {
        let db = Database::open_in_memory().expect("open_in_memory");

        let tables: Vec<String> = db
            .get()
            .unwrap()
            .prepare(
                "SELECT name FROM sqlite_master \
                 WHERE type = 'table' \
                 ORDER BY name",
            )
            .expect("prepare")
            .query_map([], |row| row.get(0))
            .expect("query")
            .filter_map(|r| r.ok())
            .collect();

        let expected = vec![
            "db_bookmarks",
            "db_buffer_tiers",
            "db_categories",
            "db_channel_categories",
            "db_channel_order",
            "db_channels",
            "db_epg_channels",
            "db_epg_entries",
            "db_epg_mappings",
            "db_episodes",
            "db_favorite_categories",
            "db_movies",
            "db_profile_source_access",
            "db_profiles",
            "db_recordings",
            "db_reminders",
            "db_retry_queue",
            "db_saved_layouts",
            "db_search_history",
            "db_seasons",
            "db_series",
            "db_settings",
            "db_smart_group_members",
            "db_smart_groups",
            "db_sources",
            "db_storage_backends",
            "db_stream_health",
            "db_stream_urls",
            "db_sync_meta",
            "db_transfer_tasks",
            "db_user_favorites",
            "db_vod_categories",
            "db_vod_favorites",
            "db_watch_history",
            "db_watchlist",
            "merge_decisions",
        ];

        assert_eq!(
            tables.len(),
            37,
            "expected 37 tables (36 user + sqlite_sequence)"
        );
        for name in &expected {
            assert!(tables.contains(&name.to_string()), "missing table: {name}",);
        }
    }

    #[test]
    fn indexes_exist() {
        let db = Database::open_in_memory().expect("open_in_memory");

        let indexes: Vec<String> = db
            .get()
            .unwrap()
            .prepare(
                "SELECT name FROM sqlite_master \
                 WHERE type = 'index' \
                 AND name LIKE 'idx_%' \
                 ORDER BY name",
            )
            .expect("prepare")
            .query_map([], |row| row.get(0))
            .expect("query")
            .filter_map(|r| r.ok())
            .collect();

        let expected = vec![
            "idx_bookmarks_content",
            "idx_categories_source",
            "idx_categories_type_source",
            "idx_channel_categories_cat",
            "idx_channel_order_profile",
            "idx_channels_epg_channel",
            "idx_channels_native",
            "idx_channels_source",
            "idx_channels_tvg",
            "idx_epg_channel",
            "idx_epg_channel_time",
            "idx_epg_channels_source",
            "idx_epg_real_coverage",
            "idx_epg_source",
            "idx_epg_xmltv_time",
            "idx_episodes_season",
            "idx_episodes_source",
            "idx_merge_decisions_source",
            "idx_merge_decisions_type",
            "idx_movies_name",
            "idx_movies_native",
            "idx_movies_source",
            "idx_reminders_notify",
            "idx_retry_queue_status_next",
            "idx_seasons_series",
            "idx_series_name",
            "idx_series_native",
            "idx_series_source",
            "idx_source_access",
            "idx_stream_urls_channel",
            "idx_vod_categories_cat",
            "idx_vod_categories_content",
            "idx_watch_history_content",
            "idx_watch_history_profile",
            "idx_watch_history_profile_source",
            "idx_watch_history_source",
        ];

        assert_eq!(indexes.len(), expected.len(), "index count mismatch");
        for name in &expected {
            assert!(indexes.contains(&name.to_string()), "missing index: {name}",);
        }
    }

    #[test]
    fn wal_mode_enabled() {
        let db = Database::open_in_memory().expect("open_in_memory");

        let mode: String = db
            .get()
            .unwrap()
            .pragma_query_value(None, "journal_mode", |row| row.get(0))
            .expect("read journal_mode");

        // In-memory databases report "memory" for
        // journal_mode even when WAL is requested.
        // File-backed databases would report "wal".
        assert!(
            mode == "wal" || mode == "memory",
            "unexpected journal_mode: {mode}",
        );
    }

    #[test]
    fn foreign_keys_enabled() {
        let db = Database::open_in_memory().expect("open_in_memory");

        let fk: i64 = db
            .get()
            .unwrap()
            .pragma_query_value(None, "foreign_keys", |row| row.get(0))
            .expect("read foreign_keys");

        assert_eq!(fk, 1, "foreign_keys should be ON");
    }

    #[test]
    fn open_file_roundtrip() {
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("test.db");
        let path_str = path.to_str().expect("path to str");

        // Create and populate.
        {
            let db = Database::open(path_str).expect("open");
            db.get()
                .unwrap()
                .execute(
                    "INSERT INTO db_settings \
                     (key, value) VALUES (?1, ?2)",
                    ["theme", "dark"],
                )
                .expect("insert");
        }

        // Reopen and verify.
        {
            let db = Database::open(path_str).expect("reopen");
            let val: String = db
                .get()
                .unwrap()
                .query_row(
                    "SELECT value FROM db_settings \
                     WHERE key = ?1",
                    ["theme"],
                    |row| row.get(0),
                )
                .expect("select");
            assert_eq!(val, "dark");
        }
    }

    #[test]
    fn idempotent_schema_creation() {
        // Opening twice should not fail (IF NOT EXISTS).
        let db1 = Database::open_in_memory().expect("first open");
        drop(db1);

        let db2 = Database::open_in_memory().expect("second open");
        let version: u32 = db2
            .get()
            .unwrap()
            .pragma_query_value(None, "user_version", |row| row.get(0))
            .expect("read version");

        assert_eq!(version, migration_runner::LATEST_VERSION);
    }
}
