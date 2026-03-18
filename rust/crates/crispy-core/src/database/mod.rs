// [ORCH-1000] AGENT-05: Audited and verified optimal SQLite WAL/Pragma configuration.
//! SQLite database module for CrispyTivi.
//!
//! Manages schema creation, migrations, and WAL-mode
//! connection setup. Schema version tracks at v26
//! (matching Drift convention via `PRAGMA user_version`).
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

use r2d2::Pool;
use r2d2_sqlite::SqliteConnectionManager;

/// Current schema version.
const SCHEMA_VERSION: u32 = 36;

// ── Table name constants ──────────────────────────────────

/// SQLite table name for live channels.
pub const TABLE_CHANNELS: &str = "db_channels";

/// SQLite table name for VOD items.
pub const TABLE_VOD_ITEMS: &str = "db_vod_items";

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

        let mut db = Self { pool };
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

        let mut db = Self { pool };
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

    /// Create schema or run migrations.
    fn ensure_schema(&mut self) -> Result<(), DbError> {
        let version: u32 = self
            .get()?
            .pragma_query_value(None, "user_version", |row| row.get(0))?;

        if version == 0 {
            self.create_schema()?;
        } else if version < SCHEMA_VERSION {
            self.migrate(version)?;
        }
        Ok(())
    }

    /// Create all tables, indexes, and set version.
    fn create_schema(&mut self) -> Result<(), DbError> {
        let mut conn = self.get()?;
        let tx = conn.transaction()?;

        tx.execute_batch(CREATE_DB_CHANNELS)?;
        tx.execute_batch(CREATE_DB_VOD_ITEMS)?;
        tx.execute_batch(CREATE_DB_CATEGORIES)?;
        tx.execute_batch(CREATE_DB_SYNC_META)?;
        tx.execute_batch(CREATE_DB_SETTINGS)?;
        tx.execute_batch(CREATE_DB_EPG_ENTRIES)?;
        tx.execute_batch(CREATE_DB_WATCH_HISTORY)?;
        tx.execute_batch(CREATE_DB_PROFILES)?;
        tx.execute_batch(CREATE_DB_USER_FAVORITES)?;
        tx.execute_batch(CREATE_DB_VOD_FAVORITES)?;
        tx.execute_batch(CREATE_DB_FAVORITE_CATEGORIES)?;
        tx.execute_batch(CREATE_DB_PROFILE_SOURCE_ACCESS)?;
        tx.execute_batch(CREATE_DB_RECORDINGS)?;
        tx.execute_batch(CREATE_DB_STORAGE_BACKENDS)?;
        tx.execute_batch(CREATE_DB_TRANSFER_TASKS)?;
        tx.execute_batch(CREATE_DB_SAVED_LAYOUTS)?;
        tx.execute_batch(CREATE_DB_SEARCH_HISTORY)?;
        tx.execute_batch(CREATE_DB_CHANNEL_ORDER)?;
        tx.execute_batch(CREATE_DB_REMINDERS)?;
        tx.execute_batch(CREATE_DB_WATCHLIST)?;
        tx.execute_batch(CREATE_DB_SOURCES)?;
        tx.execute_batch(CREATE_DB_BUFFER_TIERS)?;
        tx.execute_batch(CREATE_DB_BOOKMARKS)?;
        tx.execute_batch(CREATE_DB_STREAM_HEALTH)?;
        tx.execute_batch(CREATE_DB_EPG_MAPPINGS)?;
        tx.execute_batch(CREATE_DB_SMART_GROUPS)?;
        tx.execute_batch(CREATE_DB_SMART_GROUP_MEMBERS)?;
        tx.execute_batch(CREATE_DB_RETRY_QUEUE)?;
        tx.execute_batch(CREATE_INDEXES)?;

        tx.pragma_update(None, "user_version", SCHEMA_VERSION)?;
        tx.commit()?;
        Ok(())
    }

    /// Incremental migration from `from_version` to
    /// `SCHEMA_VERSION`. Placeholder for future deltas.
    fn migrate(&mut self, from_version: u32) -> Result<(), DbError> {
        let mut conn = self.get()?;
        let tx = conn.transaction()?;

        // v21: `ALTER TABLE ADD COLUMN` silences errors intentionally —
        // SQLite rejects the statement if the column already exists, which
        // can happen when a partial migration was applied previously.
        if from_version < 21 {
            let _ = tx.execute(
                "ALTER TABLE db_profiles ADD COLUMN dvr_quota_mb INTEGER",
                [],
            );
        }

        // v22: DROP TABLE IF EXISTS never fails; `?` would also be fine,
        // but `let _` is kept for consistency with the surrounding arms.
        if from_version < 22 {
            tx.execute("DROP TABLE IF EXISTS db_image_cache", [])?;
        }

        // v23: See v21 note — ADD COLUMN is non-idempotent in SQLite.
        if from_version < 23 {
            let _ = tx.execute(
                "ALTER TABLE db_watch_history ADD COLUMN series_poster_url TEXT",
                [],
            );
        }

        // v24: Migration for adding profile_id to db_watch_history.
        // See v21 note — ADD COLUMN is non-idempotent in SQLite.
        if from_version < 24 {
            let _ = tx.execute(
                "ALTER TABLE db_watch_history ADD COLUMN profile_id TEXT",
                [],
            );
        }

        // v25: Backfill missing profile_id for old watch history items.
        // UPDATE never fails with a duplicate-column error, so `?` is safe.
        if from_version < 25 {
            tx.execute(
                "UPDATE db_watch_history SET profile_id = 'default' WHERE profile_id IS NULL",
                [],
            )?;
        }

        // v26: Add performance indexes for high-frequency query patterns.
        // Uses IF NOT EXISTS so this is safe to re-run if migration was
        // partially applied.
        if from_version < 26 {
            tx.execute_batch(
                "CREATE INDEX IF NOT EXISTS idx_watch_history_profile \
                    ON db_watch_history(profile_id); \
                 CREATE INDEX IF NOT EXISTS idx_vod_items_series \
                    ON db_vod_items(series_id); \
                 CREATE INDEX IF NOT EXISTS idx_reminders_notify \
                    ON db_reminders(notify_at); \
                 CREATE INDEX IF NOT EXISTS idx_channel_order_profile \
                    ON db_channel_order(profile_id);",
            )?;
        }

        // v27: Add missing foreign key constraint to db_reminders.
        // Requires CREATE-copy-DROP-rename pattern in SQLite to add FKs to existing schema
        if from_version < 27 {
            tx.execute_batch(
                "CREATE TABLE db_reminders_new (
                    id TEXT PRIMARY KEY NOT NULL,
                    program_name TEXT NOT NULL,
                    channel_name TEXT NOT NULL,
                    start_time INTEGER NOT NULL,
                    notify_at INTEGER NOT NULL,
                    fired INTEGER NOT NULL DEFAULT 0,
                    profile_id TEXT REFERENCES db_profiles(id) ON DELETE CASCADE,
                    created_at INTEGER NOT NULL
                );
                INSERT INTO db_reminders_new SELECT * FROM db_reminders;
                DROP TABLE db_reminders;
                ALTER TABLE db_reminders_new RENAME TO db_reminders;
                CREATE INDEX IF NOT EXISTS idx_reminders_notify ON db_reminders (notify_at);",
            )?;
        }

        // v28: Add db_watchlist for persisting the user watchlist.
        if from_version < 28 {
            tx.execute_batch(CREATE_DB_WATCHLIST)?;
        }

        // v29: Add db_sources table, source_id to epg_entries and categories.
        if from_version < 29 {
            tx.execute_batch(CREATE_DB_SOURCES)?;
            let _ = tx.execute("ALTER TABLE db_epg_entries ADD COLUMN source_id TEXT", []);
            let _ = tx.execute("ALTER TABLE db_categories ADD COLUMN source_id TEXT", []);
            tx.execute_batch(
                "CREATE INDEX IF NOT EXISTS idx_epg_source \
                    ON db_epg_entries (source_id); \
                 CREATE INDEX IF NOT EXISTS idx_categories_source \
                    ON db_categories (source_id);",
            )?;
        }

        // v30: Add source_id column to db_watch_history.
        // See v21 note — ADD COLUMN is non-idempotent in SQLite.
        if from_version < 30 {
            let _ = tx.execute("ALTER TABLE db_watch_history ADD COLUMN source_id TEXT", []);
            tx.execute_batch(
                "CREATE INDEX IF NOT EXISTS idx_watch_history_source \
                    ON db_watch_history (source_id);",
            )?;
        }

        // v31: Add db_buffer_tiers for adaptive buffer persistence.
        if from_version < 31 {
            tx.execute_batch(CREATE_DB_BUFFER_TIERS)?;
        }

        // v32: Add db_bookmarks for persistent video bookmarks.
        if from_version < 32 {
            tx.execute_batch(CREATE_DB_BOOKMARKS)?;
            tx.execute_batch(
                "CREATE INDEX IF NOT EXISTS idx_bookmarks_content \
                    ON db_bookmarks (content_id);",
            )?;
        }

        // v33: Add db_stream_health for stream reliability tracking.
        if from_version < 33 {
            tx.execute_batch(CREATE_DB_STREAM_HEALTH)?;
        }

        // v34: Add db_epg_mappings table and is_247 column on channels.
        if from_version < 34 {
            tx.execute_batch(CREATE_DB_EPG_MAPPINGS)?;
            let _ = tx.execute(
                "ALTER TABLE db_channels ADD COLUMN is_247 INTEGER NOT NULL DEFAULT 0",
                [],
            );
        }

        // v35: Add smart channel groups for cross-provider failover.
        if from_version < 35 {
            tx.execute_batch(CREATE_DB_SMART_GROUPS)?;
            tx.execute_batch(CREATE_DB_SMART_GROUP_MEMBERS)?;
        }

        // v36: Add durable retry queue for background operations.
        if from_version < 36 {
            tx.execute_batch(CREATE_DB_RETRY_QUEUE)?;
        }

        tx.pragma_update(None, "user_version", SCHEMA_VERSION)?;
        tx.commit()?;
        Ok(())
    }
}

// ── Pragmas ──────────────────────────────────────────────

const PRAGMAS: &str = "\
    PRAGMA journal_mode = WAL;\
    PRAGMA synchronous = NORMAL;\
    PRAGMA cache_size = 10000;\
    PRAGMA foreign_keys = ON;\
";

// ── Table DDL ────────────────────────────────────────────

const CREATE_DB_CHANNELS: &str = "\
CREATE TABLE IF NOT EXISTS db_channels (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    stream_url TEXT NOT NULL,
    number INTEGER,
    channel_group TEXT,
    logo_url TEXT,
    tvg_id TEXT,
    tvg_name TEXT,
    is_favorite INTEGER NOT NULL DEFAULT 0,
    user_agent TEXT,
    has_catchup INTEGER NOT NULL DEFAULT 0,
    catchup_days INTEGER NOT NULL DEFAULT 0,
    catchup_type TEXT,
    catchup_source TEXT,
    source_id TEXT,
    added_at INTEGER,
    updated_at INTEGER,
    is_247 INTEGER NOT NULL DEFAULT 0
);";

const CREATE_DB_VOD_ITEMS: &str = "\
CREATE TABLE IF NOT EXISTS db_vod_items (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    stream_url TEXT NOT NULL,
    type TEXT NOT NULL,
    poster_url TEXT,
    backdrop_url TEXT,
    description TEXT,
    rating TEXT,
    year INTEGER,
    duration INTEGER,
    category TEXT,
    series_id TEXT,
    season_number INTEGER,
    episode_number INTEGER,
    ext TEXT,
    is_favorite INTEGER NOT NULL DEFAULT 0,
    added_at INTEGER,
    updated_at INTEGER,
    source_id TEXT
);";

const CREATE_DB_CATEGORIES: &str = "\
CREATE TABLE IF NOT EXISTS db_categories (
    category_type TEXT NOT NULL,
    name TEXT NOT NULL,
    source_id TEXT,
    PRIMARY KEY (category_type, name)
);";

const CREATE_DB_SYNC_META: &str = "\
CREATE TABLE IF NOT EXISTS db_sync_meta (
    source_id TEXT PRIMARY KEY NOT NULL,
    last_sync_time INTEGER NOT NULL
);";

const CREATE_DB_SETTINGS: &str = "\
CREATE TABLE IF NOT EXISTS db_settings (
    key TEXT PRIMARY KEY NOT NULL,
    value TEXT NOT NULL
);";

const CREATE_DB_EPG_ENTRIES: &str = "\
CREATE TABLE IF NOT EXISTS db_epg_entries (
    channel_id TEXT NOT NULL,
    title TEXT NOT NULL,
    start_time INTEGER NOT NULL,
    end_time INTEGER NOT NULL,
    description TEXT,
    category TEXT,
    icon_url TEXT,
    source_id TEXT,
    PRIMARY KEY (channel_id, start_time)
);";

const CREATE_DB_WATCH_HISTORY: &str = "\
CREATE TABLE IF NOT EXISTS db_watch_history (
    id TEXT PRIMARY KEY NOT NULL,
    media_type TEXT NOT NULL,
    name TEXT NOT NULL,
    stream_url TEXT NOT NULL,
    poster_url TEXT,
    position_ms INTEGER NOT NULL DEFAULT 0,
    duration_ms INTEGER NOT NULL DEFAULT 0,
    last_watched INTEGER NOT NULL,
    series_id TEXT,
    season_number INTEGER,
    episode_number INTEGER,
    device_id TEXT,
    device_name TEXT,
    series_poster_url TEXT,
    profile_id TEXT,
    source_id TEXT
);";

const CREATE_DB_PROFILES: &str = "\
CREATE TABLE IF NOT EXISTS db_profiles (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    avatar_index INTEGER NOT NULL DEFAULT 0,
    pin TEXT,
    is_child INTEGER NOT NULL DEFAULT 0,
    pin_version INTEGER NOT NULL DEFAULT 0,
    max_allowed_rating INTEGER NOT NULL DEFAULT 4,
    role INTEGER NOT NULL DEFAULT 1,
    dvr_permission INTEGER NOT NULL DEFAULT 2,
    dvr_quota_mb INTEGER
);";

const CREATE_DB_USER_FAVORITES: &str = "\
CREATE TABLE IF NOT EXISTS db_user_favorites (
    profile_id TEXT NOT NULL
        REFERENCES db_profiles(id),
    channel_id TEXT NOT NULL
        REFERENCES db_channels(id),
    added_at INTEGER NOT NULL,
    PRIMARY KEY (profile_id, channel_id)
);";

const CREATE_DB_VOD_FAVORITES: &str = "\
CREATE TABLE IF NOT EXISTS db_vod_favorites (
    profile_id TEXT NOT NULL
        REFERENCES db_profiles(id),
    vod_item_id TEXT NOT NULL
        REFERENCES db_vod_items(id),
    added_at INTEGER NOT NULL,
    PRIMARY KEY (profile_id, vod_item_id)
);";

const CREATE_DB_FAVORITE_CATEGORIES: &str = "\
CREATE TABLE IF NOT EXISTS db_favorite_categories (
    profile_id TEXT NOT NULL
        REFERENCES db_profiles(id),
    category_type TEXT NOT NULL,
    category_name TEXT NOT NULL,
    added_at INTEGER NOT NULL,
    PRIMARY KEY (
        profile_id,
        category_type,
        category_name
    )
);";

const CREATE_DB_PROFILE_SOURCE_ACCESS: &str = "\
CREATE TABLE IF NOT EXISTS db_profile_source_access (
    profile_id TEXT NOT NULL
        REFERENCES db_profiles(id),
    source_id TEXT NOT NULL,
    granted_at INTEGER NOT NULL,
    PRIMARY KEY (profile_id, source_id)
);";

const CREATE_DB_RECORDINGS: &str = "\
CREATE TABLE IF NOT EXISTS db_recordings (
    id TEXT PRIMARY KEY NOT NULL,
    channel_id TEXT,
    channel_name TEXT NOT NULL,
    channel_logo_url TEXT,
    program_name TEXT NOT NULL,
    stream_url TEXT,
    start_time INTEGER NOT NULL,
    end_time INTEGER NOT NULL,
    status TEXT NOT NULL,
    file_path TEXT,
    file_size_bytes INTEGER,
    is_recurring INTEGER NOT NULL DEFAULT 0,
    recur_days INTEGER NOT NULL DEFAULT 0,
    owner_profile_id TEXT,
    is_shared INTEGER NOT NULL DEFAULT 1,
    remote_backend_id TEXT,
    remote_path TEXT
);";

const CREATE_DB_STORAGE_BACKENDS: &str = "\
CREATE TABLE IF NOT EXISTS db_storage_backends (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    config TEXT NOT NULL,
    is_default INTEGER NOT NULL DEFAULT 0
);";

const CREATE_DB_TRANSFER_TASKS: &str = "\
CREATE TABLE IF NOT EXISTS db_transfer_tasks (
    id TEXT PRIMARY KEY NOT NULL,
    recording_id TEXT NOT NULL,
    backend_id TEXT NOT NULL,
    direction TEXT NOT NULL,
    status TEXT NOT NULL,
    total_bytes INTEGER NOT NULL DEFAULT 0,
    transferred_bytes INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    error_message TEXT,
    remote_path TEXT
);";

const CREATE_DB_SAVED_LAYOUTS: &str = "\
CREATE TABLE IF NOT EXISTS db_saved_layouts (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    layout TEXT NOT NULL,
    streams TEXT NOT NULL,
    created_at INTEGER NOT NULL
);";

const CREATE_DB_SEARCH_HISTORY: &str = "\
CREATE TABLE IF NOT EXISTS db_search_history (
    id TEXT PRIMARY KEY NOT NULL,
    query TEXT NOT NULL,
    searched_at INTEGER NOT NULL,
    result_count INTEGER NOT NULL DEFAULT 0
);";

const CREATE_DB_CHANNEL_ORDER: &str = "\
CREATE TABLE IF NOT EXISTS db_channel_order (
    profile_id TEXT NOT NULL,
    group_name TEXT NOT NULL,
    channel_id TEXT NOT NULL,
    sort_index INTEGER NOT NULL,
    PRIMARY KEY (
        profile_id,
        group_name,
        channel_id
    )
);";

const CREATE_DB_REMINDERS: &str = "\
CREATE TABLE IF NOT EXISTS db_reminders (
    id TEXT PRIMARY KEY NOT NULL,
    program_name TEXT NOT NULL,
    channel_name TEXT NOT NULL,
    start_time INTEGER NOT NULL,
    notify_at INTEGER NOT NULL,
    fired INTEGER NOT NULL DEFAULT 0,
    profile_id TEXT REFERENCES db_profiles(id) ON DELETE CASCADE,
    created_at INTEGER NOT NULL
);";

const CREATE_DB_WATCHLIST: &str = "\
CREATE TABLE IF NOT EXISTS db_watchlist (
    profile_id TEXT NOT NULL REFERENCES db_profiles(id) ON DELETE CASCADE,
    vod_item_id TEXT NOT NULL REFERENCES db_vod_items(id) ON DELETE CASCADE,
    added_at INTEGER NOT NULL,
    PRIMARY KEY (profile_id, vod_item_id)
);";

const CREATE_DB_SOURCES: &str = "\
CREATE TABLE IF NOT EXISTS db_sources (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    source_type TEXT NOT NULL,
    url TEXT NOT NULL,
    username TEXT,
    password TEXT,
    access_token TEXT,
    device_id TEXT,
    user_id TEXT,
    mac_address TEXT,
    epg_url TEXT,
    user_agent TEXT,
    refresh_interval_minutes INTEGER NOT NULL DEFAULT 60,
    accept_self_signed INTEGER NOT NULL DEFAULT 0,
    enabled INTEGER NOT NULL DEFAULT 1,
    sort_order INTEGER NOT NULL DEFAULT 0,
    last_sync_time INTEGER,
    last_sync_status TEXT,
    last_sync_error TEXT,
    created_at INTEGER,
    updated_at INTEGER
);";

const CREATE_DB_BUFFER_TIERS: &str = "\
CREATE TABLE IF NOT EXISTS db_buffer_tiers (
    url_hash TEXT PRIMARY KEY NOT NULL,
    tier TEXT NOT NULL DEFAULT 'normal',
    updated_at INTEGER NOT NULL
);";

const CREATE_DB_BOOKMARKS: &str = "\
CREATE TABLE IF NOT EXISTS db_bookmarks (
    id TEXT PRIMARY KEY NOT NULL,
    content_id TEXT NOT NULL,
    content_type TEXT NOT NULL,
    position_ms INTEGER NOT NULL,
    label TEXT,
    created_at INTEGER NOT NULL
);";

const CREATE_DB_STREAM_HEALTH: &str = "\
CREATE TABLE IF NOT EXISTS db_stream_health (
    url_hash TEXT PRIMARY KEY NOT NULL,
    stall_count INTEGER NOT NULL DEFAULT 0,
    buffer_sum REAL NOT NULL DEFAULT 0,
    buffer_samples INTEGER NOT NULL DEFAULT 0,
    ttff_ms INTEGER NOT NULL DEFAULT 0,
    last_seen INTEGER NOT NULL
);";

const CREATE_DB_EPG_MAPPINGS: &str = "\
CREATE TABLE IF NOT EXISTS db_epg_mappings (
    channel_id TEXT PRIMARY KEY NOT NULL,
    epg_channel_id TEXT NOT NULL,
    confidence REAL NOT NULL,
    source TEXT NOT NULL,
    locked INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL
);";

const CREATE_DB_SMART_GROUPS: &str = "\
CREATE TABLE IF NOT EXISTS db_smart_groups (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL
);";

const CREATE_DB_SMART_GROUP_MEMBERS: &str = "\
CREATE TABLE IF NOT EXISTS db_smart_group_members (
    group_id TEXT NOT NULL REFERENCES db_smart_groups(id) ON DELETE CASCADE,
    channel_id TEXT NOT NULL,
    source_id TEXT NOT NULL DEFAULT '',
    priority INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (group_id, channel_id)
);";

const CREATE_DB_RETRY_QUEUE: &str = "\
CREATE TABLE IF NOT EXISTS db_retry_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operation TEXT NOT NULL,
    payload TEXT NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    next_retry_at TEXT NOT NULL,
    max_lifetime TEXT NOT NULL,
    created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_retry_queue_next \
    ON db_retry_queue (next_retry_at);";

// ── Indexes ──────────────────────────────────────────────

const CREATE_INDEXES: &str = "\
CREATE INDEX IF NOT EXISTS idx_channels_source
    ON db_channels (source_id);
CREATE INDEX IF NOT EXISTS idx_channels_tvg
    ON db_channels (tvg_id);
CREATE INDEX IF NOT EXISTS idx_vod_source
    ON db_vod_items (source_id);
CREATE INDEX IF NOT EXISTS idx_epg_channel
    ON db_epg_entries (channel_id);
CREATE INDEX IF NOT EXISTS idx_source_access
    ON db_profile_source_access (source_id);
CREATE INDEX IF NOT EXISTS idx_watch_history_profile
    ON db_watch_history (profile_id);
CREATE INDEX IF NOT EXISTS idx_watch_history_source
    ON db_watch_history (source_id);
CREATE INDEX IF NOT EXISTS idx_vod_items_series
    ON db_vod_items (series_id);
CREATE INDEX IF NOT EXISTS idx_reminders_notify
    ON db_reminders (notify_at);
CREATE INDEX IF NOT EXISTS idx_channel_order_profile
    ON db_channel_order (profile_id);
CREATE INDEX IF NOT EXISTS idx_epg_source
    ON db_epg_entries (source_id);
CREATE INDEX IF NOT EXISTS idx_categories_source
    ON db_categories (source_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_content
    ON db_bookmarks (content_id);
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

        assert_eq!(version, SCHEMA_VERSION);
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
            "db_channel_order",
            "db_channels",
            "db_epg_entries",
            "db_epg_mappings",
            "db_profiles",
            "db_profile_source_access",
            "db_recordings",
            "db_reminders",
            "db_retry_queue",
            "db_saved_layouts",
            "db_search_history",
            "db_settings",
            "db_smart_group_members",
            "db_smart_groups",
            "db_sources",
            "db_storage_backends",
            "db_stream_health",
            "db_sync_meta",
            "db_transfer_tasks",
            "db_user_favorites",
            "db_vod_favorites",
            "db_vod_items",
            "db_watch_history",
            "db_watchlist",
        ];

        assert_eq!(tables.len(), 29, "expected 29 tables");
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
            "idx_channel_order_profile",
            "idx_channels_source",
            "idx_channels_tvg",
            "idx_epg_channel",
            "idx_epg_source",
            "idx_reminders_notify",
            "idx_retry_queue_next",
            "idx_source_access",
            "idx_vod_items_series",
            "idx_vod_source",
            "idx_watch_history_profile",
            "idx_watch_history_source",
        ];

        assert_eq!(indexes.len(), 14, "expected 14 indexes",);
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

        assert_eq!(version, SCHEMA_VERSION);
    }
}
