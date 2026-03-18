//! Integration tests for the CrispyTivi database layer.
//!
//! Tests the full DB lifecycle: connection → migrations → CRUD → verify.
//! Uses real SQLite files via `tempfile` so WAL mode and file persistence
//! are exercised, not just in-memory behaviour.

use crispy_core::database::Database;
use tempfile::TempDir;

// ── Helpers ────────────────────────────────────────────────────────────────────

fn temp_db() -> (TempDir, Database) {
    let dir = tempfile::tempdir().expect("tempdir");
    let path = dir.path().join("test.db");
    let db = Database::open(path.to_str().unwrap()).expect("open file db");
    (dir, db)
}

// ── Migration lifecycle ────────────────────────────────────────────────────────

#[test]
fn schema_version_is_current_after_open() {
    let (_dir, db) = temp_db();
    let version: u32 = db
        .get()
        .unwrap()
        .pragma_query_value(None, "user_version", |row| row.get(0))
        .expect("read user_version");
    assert!(version >= 35, "expected version >= 35, got {version}");
}

#[test]
fn open_twice_does_not_fail_migration_is_idempotent() {
    let dir = tempfile::tempdir().expect("tempdir");
    let path = dir.path().join("idempotent.db");
    let path_str = path.to_str().unwrap();

    let db1 = Database::open(path_str).expect("first open");
    let v1: u32 = db1
        .get()
        .unwrap()
        .pragma_query_value(None, "user_version", |row| row.get(0))
        .unwrap();
    drop(db1);

    let db2 = Database::open(path_str).expect("second open");
    let v2: u32 = db2
        .get()
        .unwrap()
        .pragma_query_value(None, "user_version", |row| row.get(0))
        .unwrap();

    assert_eq!(v1, v2, "version must not change on second open");
}

#[test]
fn in_memory_schema_has_all_expected_tables() {
    let db = Database::open_in_memory().expect("in-memory open");
    let conn = db.get().unwrap();

    let tables: Vec<String> = conn
        .prepare("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
        .unwrap()
        .query_map([], |row| row.get(0))
        .unwrap()
        .filter_map(|r| r.ok())
        .collect();

    let required = [
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
    for name in &required {
        assert!(
            tables.contains(&name.to_string()),
            "missing required table: {name}"
        );
    }
}

// ── Insert / query / update / delete ─────────────────────────────────────────

#[test]
fn settings_crud_roundtrip() {
    let (_dir, db) = temp_db();
    let conn = db.get().unwrap();

    // Insert
    conn.execute(
        "INSERT INTO db_settings (key, value) VALUES (?1, ?2)",
        rusqlite::params!["theme", "dark"],
    )
    .unwrap();

    // Query
    let val: String = conn
        .query_row(
            "SELECT value FROM db_settings WHERE key = ?1",
            rusqlite::params!["theme"],
            |row| row.get(0),
        )
        .unwrap();
    assert_eq!(val, "dark");

    // Update
    conn.execute(
        "INSERT OR REPLACE INTO db_settings (key, value) VALUES (?1, ?2)",
        rusqlite::params!["theme", "light"],
    )
    .unwrap();
    let updated: String = conn
        .query_row(
            "SELECT value FROM db_settings WHERE key = ?1",
            rusqlite::params!["theme"],
            |row| row.get(0),
        )
        .unwrap();
    assert_eq!(updated, "light");

    // Delete
    conn.execute(
        "DELETE FROM db_settings WHERE key = ?1",
        rusqlite::params!["theme"],
    )
    .unwrap();
    let count: i64 = conn
        .query_row(
            "SELECT COUNT(*) FROM db_settings WHERE key = ?1",
            rusqlite::params!["theme"],
            |row| row.get(0),
        )
        .unwrap();
    assert_eq!(count, 0);
}

#[test]
fn channel_insert_and_load() {
    let (_dir, db) = temp_db();
    let conn = db.get().unwrap();

    conn.execute(
        "INSERT INTO db_channels \
         (id, name, stream_url, is_favorite, has_catchup, catchup_days, is_247) \
         VALUES (?1, ?2, ?3, 0, 0, 0, 0)",
        rusqlite::params!["ch1", "BBC News", "http://bbc.com/stream"],
    )
    .unwrap();

    let (id, name): (String, String) = conn
        .query_row(
            "SELECT id, name FROM db_channels WHERE id = ?1",
            rusqlite::params!["ch1"],
            |row| Ok((row.get(0)?, row.get(1)?)),
        )
        .unwrap();

    assert_eq!(id, "ch1");
    assert_eq!(name, "BBC News");
}

#[test]
fn vod_item_insert_and_load() {
    let (_dir, db) = temp_db();
    let conn = db.get().unwrap();

    conn.execute(
        "INSERT INTO db_vod_items \
         (id, name, stream_url, type, is_favorite) \
         VALUES (?1, ?2, ?3, ?4, 0)",
        rusqlite::params!["vod1", "Inception", "http://cdn.com/inception.mp4", "movie"],
    )
    .unwrap();

    let name: String = conn
        .query_row(
            "SELECT name FROM db_vod_items WHERE id = ?1",
            rusqlite::params!["vod1"],
            |row| row.get(0),
        )
        .unwrap();
    assert_eq!(name, "Inception");
}

// ── File persistence ──────────────────────────────────────────────────────────

#[test]
fn data_persists_across_open_close_cycle() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("persist.db");
    let path_str = path.to_str().unwrap();

    // Write in first session.
    {
        let db = Database::open(path_str).unwrap();
        db.get()
            .unwrap()
            .execute(
                "INSERT INTO db_settings (key, value) VALUES (?1, ?2)",
                rusqlite::params!["language", "ar"],
            )
            .unwrap();
    }

    // Read back in second session.
    {
        let db = Database::open(path_str).unwrap();
        let val: String = db
            .get()
            .unwrap()
            .query_row(
                "SELECT value FROM db_settings WHERE key = ?1",
                rusqlite::params!["language"],
                |row| row.get(0),
            )
            .unwrap();
        assert_eq!(val, "ar");
    }
}

// ── WAL mode ──────────────────────────────────────────────────────────────────

#[test]
fn wal_mode_enabled_for_file_db() {
    let (_dir, db) = temp_db();
    let mode: String = db
        .get()
        .unwrap()
        .pragma_query_value(None, "journal_mode", |row| row.get(0))
        .unwrap();
    assert_eq!(mode, "wal", "file-backed DB must use WAL mode");
}

// ── Foreign keys ──────────────────────────────────────────────────────────────

#[test]
fn foreign_keys_enforced_on_file_db() {
    let (_dir, db) = temp_db();
    let fk: i64 = db
        .get()
        .unwrap()
        .pragma_query_value(None, "foreign_keys", |row| row.get(0))
        .unwrap();
    assert_eq!(fk, 1, "foreign_keys must be ON");
}

// ── Concurrent access (multi-connection pool) ─────────────────────────────────

#[test]
fn concurrent_reads_do_not_deadlock() {
    use std::thread;

    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("concurrent.db");
    let path_str = path.to_str().unwrap().to_string();

    let db = Database::open(&path_str).unwrap();
    db.get()
        .unwrap()
        .execute(
            "INSERT INTO db_settings (key, value) VALUES (?1, ?2)",
            rusqlite::params!["k", "v"],
        )
        .unwrap();

    let db = std::sync::Arc::new(db);
    let mut handles = Vec::new();

    for _ in 0..8 {
        let db_clone = std::sync::Arc::clone(&db);
        handles.push(thread::spawn(move || {
            let _v: String = db_clone
                .get()
                .unwrap()
                .query_row(
                    "SELECT value FROM db_settings WHERE key = ?1",
                    rusqlite::params!["k"],
                    |row| row.get(0),
                )
                .unwrap();
        }));
    }

    for h in handles {
        h.join().expect("thread panicked");
    }
}

// ── Retry queue table ─────────────────────────────────────────────────────────

#[test]
fn retry_queue_table_exists_and_accepts_insert() {
    let (_dir, db) = temp_db();
    let conn = db.get().unwrap();

    let now = chrono::Utc::now().to_rfc3339();
    conn.execute(
        "INSERT INTO db_retry_queue \
         (operation, payload, attempts, next_retry_at, max_lifetime, created_at) \
         VALUES (?1, ?2, 0, ?3, ?4, ?5)",
        rusqlite::params!["test_op", r#"{"id":1}"#, now, now, now],
    )
    .unwrap();

    let count: i64 = conn
        .query_row("SELECT COUNT(*) FROM db_retry_queue", [], |row| row.get(0))
        .unwrap();
    assert_eq!(count, 1);
}
