//! Migration runner — applies pending SQL migrations on startup.
//!
//! Migrations are numbered SQL files under `migrations/`.  Each file
//! is embedded at compile time via `include_str!`.  The runner reads
//! `PRAGMA user_version` to determine which migrations have already
//! been applied and executes only the pending ones, each inside an
//! ACID transaction.  After a successful run the version is bumped to
//! match the migration number.
//!
//! ## Adding a new migration
//!
//! 1. Create `migrations/NNN_description.sql` (zero-padded three digits).
//! 2. Add the SQL content to the `MIGRATIONS` slice below using `include_str!`.
//! 3. Bump `LATEST_VERSION` to `NNN`.
//! 4. Write a test (or extend the existing integration test) to cover the new table/column.

use rusqlite::Connection;

use super::DbError;

/// The SQLite `user_version` left in the database after all migrations
/// have been applied.  This equals the version number in the last
/// migration's `PRAGMA user_version = N` statement.
///
/// When adding a new migration file, update this constant to match the
/// new `PRAGMA user_version` value set by that file.
pub const LATEST_VERSION: u32 = 36;

/// Ordered list of `(target_user_version, sql)` pairs.
///
/// `target_user_version` is the value this migration sets
/// `PRAGMA user_version` to.  The runner skips a migration when the
/// current DB `user_version` is already ≥ that target.
///
/// SQL is embedded at compile time via `include_str!`.
///
/// All former migrations (002-010) have been absorbed into the
/// consolidated 001 schema.  Data is disposable — sources re-sync
/// on startup, so no incremental migration path is needed.
static MIGRATIONS: &[(u32, &str)] = &[
    // 001 — consolidated schema: all tables, FK CASCADE, CHECK
    //        constraints, indexes.  Absorbs former 001-010.
    (36, include_str!("migrations/001_initial_schema.sql")),
];

/// Run all pending migrations against `conn`.
///
/// Reads `PRAGMA user_version` to discover the applied version,
/// then executes each migration whose target version exceeds the
/// current one.  Every migration runs inside a `BEGIN … COMMIT`
/// transaction; on failure the transaction is rolled back and an
/// error is returned without touching later migrations.
///
/// Safe to call on every startup — already-applied migrations are
/// skipped in O(1) without touching the database.
pub fn run_migrations(conn: &Connection) -> Result<(), DbError> {
    let current: u32 = conn.pragma_query_value(None, "user_version", |row| row.get(0))?;

    for (target, sql) in MIGRATIONS {
        if *target <= current {
            // Already at or past this migration — skip.
            continue;
        }

        // Each migration runs in its own transaction for atomicity.
        conn.execute_batch("BEGIN;")?;
        match conn.execute_batch(sql) {
            Ok(()) => {
                // The SQL file sets PRAGMA user_version itself; commit.
                conn.execute_batch("COMMIT;")?;
                tracing::info!(version = target, "db migration applied");
            }
            Err(e) => {
                let _ = conn.execute_batch("ROLLBACK;");
                return Err(DbError::Migration(format!(
                    "migration to v{target} failed: {e}"
                )));
            }
        }
    }

    Ok(())
}

// ── Tests ────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use rusqlite::Connection;

    use super::*;

    fn open_memory() -> Connection {
        let conn = Connection::open_in_memory().expect("open :memory:");
        // Enable foreign keys so constraint tests are meaningful.
        conn.execute_batch("PRAGMA foreign_keys = ON;")
            .expect("foreign_keys");
        conn
    }

    fn user_version(conn: &Connection) -> u32 {
        conn.pragma_query_value(None, "user_version", |row| row.get(0))
            .expect("read user_version")
    }

    // ── Required tests ───────────────────────────────────

    /// Fresh database (user_version = 0) must have all migrations applied
    /// and user_version bumped to LATEST_VERSION after `run_migrations`.
    #[test]
    fn test_migrations_apply_on_fresh_db() {
        let conn = open_memory();
        assert_eq!(user_version(&conn), 0, "precondition: fresh db is at v0");

        run_migrations(&conn).expect("run_migrations");

        assert_eq!(
            user_version(&conn),
            LATEST_VERSION,
            "user_version must equal LATEST_VERSION after fresh migration",
        );

        // Spot-check: a core table must exist.
        let count: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM sqlite_master \
                 WHERE type = 'table' AND name = 'db_channels'",
                [],
                |row| row.get(0),
            )
            .expect("query sqlite_master");
        assert_eq!(count, 1, "db_channels table must exist after migration");
    }

    /// Calling `run_migrations` on a database that is already at the
    /// latest version must be a no-op — no errors, version unchanged.
    #[test]
    fn test_migrations_skip_already_applied() {
        let conn = open_memory();

        // First pass — apply all migrations.
        run_migrations(&conn).expect("first run_migrations");
        let version_after_first = user_version(&conn);
        assert_eq!(version_after_first, LATEST_VERSION);

        // Second pass — must succeed silently and leave version unchanged.
        run_migrations(&conn).expect("second run_migrations must not fail");
        let version_after_second = user_version(&conn);
        assert_eq!(
            version_after_second, version_after_first,
            "re-running migrations must not change user_version",
        );
    }

    // ── Additional coverage ──────────────────────────────

    /// All expected tables must be present after migration.
    #[test]
    fn test_all_tables_created() {
        let conn = open_memory();
        run_migrations(&conn).expect("run_migrations");

        let tables: Vec<String> = {
            let mut stmt = conn
                .prepare(
                    "SELECT name FROM sqlite_master \
                     WHERE type = 'table' ORDER BY name",
                )
                .expect("prepare");
            stmt.query_map([], |row| row.get(0))
                .expect("query")
                .filter_map(|r| r.ok())
                .collect()
        };

        let required = [
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

        for name in &required {
            assert!(
                tables.contains(&(*name).to_string()),
                "missing table after migration: {name}",
            );
        }
    }

    /// Consolidated schema: `credentials_encrypted` column must exist on db_sources.
    #[test]
    fn test_credentials_encrypted_column_exists() {
        let conn = open_memory();
        run_migrations(&conn).expect("run_migrations");

        let mut stmt = conn
            .prepare("PRAGMA table_info(db_sources)")
            .expect("prepare pragma");
        let columns: Vec<String> = stmt
            .query_map([], |row| row.get(1))
            .expect("query")
            .filter_map(|r| r.ok())
            .collect();

        assert!(
            columns.contains(&"credentials_encrypted".to_string()),
            "credentials_encrypted column must exist on db_sources"
        );
    }

    /// EPG entries must have xmltv_id and is_placeholder columns.
    #[test]
    fn test_epg_new_columns_exist() {
        let conn = open_memory();
        run_migrations(&conn).expect("run_migrations");

        let mut stmt = conn
            .prepare("PRAGMA table_info(db_epg_entries)")
            .expect("prepare pragma");
        let columns: Vec<String> = stmt
            .query_map([], |row| row.get(1))
            .expect("query")
            .filter_map(|r| r.ok())
            .collect();

        assert!(
            columns.contains(&"xmltv_id".to_string()),
            "xmltv_id must exist"
        );
        assert!(
            columns.contains(&"is_placeholder".to_string()),
            "is_placeholder must exist"
        );
    }

    /// Categories UNIQUE constraint must include source_id.
    #[test]
    fn test_categories_pk_includes_source_id() {
        let conn = open_memory();
        run_migrations(&conn).expect("run_migrations");

        // Inserting same (type, name) with different source_id must succeed.
        conn.execute(
            "INSERT INTO db_sources (id, name, source_type, url) VALUES ('s1', 'S1', 'm3u', 'http://a')",
            [],
        )
        .expect("insert source s1");
        conn.execute(
            "INSERT INTO db_sources (id, name, source_type, url) VALUES ('s2', 'S2', 'm3u', 'http://b')",
            [],
        )
        .expect("insert source s2");

        conn.execute(
            "INSERT INTO db_categories (id, category_type, name, source_id) VALUES ('cat1', 'live', 'Sports', 's1')",
            [],
        )
        .expect("insert cat s1");
        conn.execute(
            "INSERT INTO db_categories (id, category_type, name, source_id) VALUES ('cat2', 'live', 'Sports', 's2')",
            [],
        )
        .expect("insert cat s2 — must not conflict");
    }

    /// FK CASCADE: deleting a source must cascade-delete its channels.
    #[test]
    fn test_fk_cascade_source_delete() {
        let conn = open_memory();
        run_migrations(&conn).expect("run_migrations");

        conn.execute(
            "INSERT INTO db_sources (id, name, source_type, url) VALUES ('s1', 'S1', 'm3u', 'http://a')",
            [],
        )
        .expect("insert source");
        conn.execute(
            "INSERT INTO db_channels (id, native_id, name, stream_url, source_id) VALUES ('ch1', 'n1', 'Ch1', 'http://s', 's1')",
            [],
        )
        .expect("insert channel");

        conn.execute("DELETE FROM db_sources WHERE id = 's1'", [])
            .expect("delete source");

        let count: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM db_channels WHERE source_id = 's1'",
                [],
                |row| row.get(0),
            )
            .expect("count channels");
        assert_eq!(count, 0, "channels must be cascade-deleted with source");
    }

    /// CHECK constraint: EPG confidence must be in [0.0, 1.0].
    #[test]
    fn test_epg_mapping_confidence_check() {
        let conn = open_memory();
        run_migrations(&conn).expect("run_migrations");

        let result = conn.execute(
            "INSERT INTO db_epg_mappings (channel_id, epg_channel_id, confidence, match_method, created_at) \
             VALUES ('ch1', 'epg1', 1.5, 'auto', 0)",
            [],
        );
        assert!(result.is_err(), "confidence > 1.0 must be rejected");
    }

    /// smart_group_members.source_id must default to NULL, not empty string.
    #[test]
    fn test_smart_group_members_source_id_nullable() {
        let conn = open_memory();
        run_migrations(&conn).expect("run_migrations");

        conn.execute(
            "INSERT INTO db_sources (id, name, source_type, url) VALUES ('s1', 'S1', 'm3u', 'http://a')",
            [],
        )
        .expect("insert source");
        conn.execute(
            "INSERT INTO db_channels (id, native_id, name, stream_url, source_id) VALUES ('ch1', 'n1', 'Ch1', 'http://s', 's1')",
            [],
        )
        .expect("insert channel");
        conn.execute(
            "INSERT INTO db_smart_groups (id, name, created_at) VALUES ('g1', 'G1', 0)",
            [],
        )
        .expect("insert group");
        conn.execute(
            "INSERT INTO db_smart_group_members (group_id, channel_id) VALUES ('g1', 'ch1')",
            [],
        )
        .expect("insert member without source_id");

        let val: Option<String> = conn
            .query_row(
                "SELECT source_id FROM db_smart_group_members WHERE group_id = 'g1'",
                [],
                |row| row.get(0),
            )
            .expect("query source_id");
        assert!(
            val.is_none(),
            "source_id must default to NULL, not empty string"
        );
    }

    /// All expected indexes must be present after migration.
    #[test]
    fn test_all_indexes_created() {
        let conn = open_memory();
        run_migrations(&conn).expect("run_migrations");

        let indexes: Vec<String> = {
            let mut stmt = conn
                .prepare(
                    "SELECT name FROM sqlite_master \
                     WHERE type = 'index' AND name LIKE 'idx_%' \
                     ORDER BY name",
                )
                .expect("prepare");
            stmt.query_map([], |row| row.get(0))
                .expect("query")
                .filter_map(|r| r.ok())
                .collect()
        };

        let required = [
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

        for name in &required {
            assert!(
                indexes.contains(&(*name).to_string()),
                "missing index after migration: {name}",
            );
        }
    }
}
