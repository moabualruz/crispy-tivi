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
static MIGRATIONS: &[(u32, &str)] = &[
    // 001 — full initial schema (all tables + indexes, user_version = 36)
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
            "db_channel_order",
            "db_channels",
            "db_epg_entries",
            "db_epg_mappings",
            "db_profile_source_access",
            "db_profiles",
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

        for name in &required {
            assert!(
                tables.contains(&(*name).to_string()),
                "missing table after migration: {name}",
            );
        }
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

        for name in &required {
            assert!(
                indexes.contains(&(*name).to_string()),
                "missing index after migration: {name}",
            );
        }
    }
}
