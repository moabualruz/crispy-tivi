//! Durable retry queue backed by SQLite.
//!
//! Background operations that fail (source sync, EPG fetch, image download)
//! are enqueued here instead of being silently dropped.  The queue persists
//! across app restarts.  A worker polls `fetch_due` on a timer, executes each
//! item, and calls `mark_success` or `mark_failure` accordingly.
//!
//! ## Lifecycle
//!
//! ```text
//! enqueue() → pending
//!   ↓ fetch_due / worker picks up
//! processing  (set manually by worker before executing)
//!   ↓ success              ↓ failure, attempts < max_attempts
//! completed             pending (with backoff next_retry_at)
//!                         ↓ failure, attempts == max_attempts
//!                       failed (terminal)
//! ```
//!
//! Completed and permanently-failed rows are cleaned up by
//! `cleanup_completed` after a configurable retention period.

use chrono::{DateTime, Utc};
use rusqlite::{Connection, params};

// ── Types ─────────────────────────────────────────────────

/// Lifecycle status of a retry queue item.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RetryStatus {
    Pending,
    Processing,
    Completed,
    Failed,
}

impl RetryStatus {
    /// Returns the string representation stored in the database.
    /// Used for serialization and display; kept even if not called by the module itself.
    #[allow(dead_code)]
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Pending => "pending",
            Self::Processing => "processing",
            Self::Completed => "completed",
            Self::Failed => "failed",
        }
    }

    fn from_str(s: &str) -> Self {
        match s {
            "processing" => Self::Processing,
            "completed" => Self::Completed,
            "failed" => Self::Failed,
            _ => Self::Pending,
        }
    }
}

/// A single item in the retry queue.
#[derive(Debug, Clone)]
pub struct RetryItem {
    /// Row primary key.
    pub id: i64,
    /// JSON-serialized operation descriptor understood by the worker.
    pub operation: String,
    /// How many times execution has been attempted so far.
    pub attempts: u32,
    /// Maximum number of attempts before the item is permanently failed.
    pub max_attempts: u32,
    /// Earliest time at which this item should be retried.
    pub next_retry_at: DateTime<Utc>,
    /// Human-readable error message from the most recent failure, if any.
    pub last_error: Option<String>,
    /// Current lifecycle status.
    pub status: RetryStatus,
}

// ── RetryQueue ────────────────────────────────────────────

/// Data-access object for the `db_retry_queue` table.
///
/// All methods take a `&Connection` so callers control connection
/// lifecycle and can participate in wider transactions when needed.
pub struct RetryQueue;

impl RetryQueue {
    /// Enqueue a new operation for eventual execution.
    ///
    /// The item is created with `status = 'pending'`, `attempts = 0`, and
    /// `next_retry_at` set to the current UTC time (i.e. immediately eligible).
    ///
    /// Returns the `ROWID` / primary key of the newly inserted row.
    pub fn enqueue(conn: &Connection, operation: &str, max_attempts: u32) -> rusqlite::Result<i64> {
        // Use SQLite-native format so timestamp comparisons with datetime('now') work.
        let now = Utc::now().format("%Y-%m-%d %H:%M:%S").to_string();
        conn.execute(
            "INSERT INTO db_retry_queue \
             (operation, attempts, max_attempts, next_retry_at, status) \
             VALUES (?1, 0, ?2, ?3, 'pending')",
            params![operation, max_attempts, now],
        )?;
        Ok(conn.last_insert_rowid())
    }

    /// Fetch up to `limit` items that are due for execution right now.
    ///
    /// An item is "due" when:
    /// - `status = 'pending'`
    /// - `next_retry_at <= datetime('now')`
    ///
    /// Results are ordered oldest-due-first so the queue drains in FIFO order.
    pub fn fetch_due(conn: &Connection, limit: u32) -> rusqlite::Result<Vec<RetryItem>> {
        // Pass the current UTC time as a parameter so that the comparison works
        // regardless of whether timestamps are stored as RFC 3339 (with offset)
        // or in SQLite's native `YYYY-MM-DD HH:MM:SS` format.
        let now = Utc::now().format("%Y-%m-%d %H:%M:%S").to_string();
        let mut stmt = conn.prepare(
            "SELECT id, operation, attempts, max_attempts, next_retry_at, last_error, status \
             FROM db_retry_queue \
             WHERE status = 'pending' AND next_retry_at <= ?2 \
             ORDER BY next_retry_at ASC \
             LIMIT ?1",
        )?;

        let items = stmt
            .query_map(params![limit, now], |row| {
                let next_retry_raw: String = row.get(4)?;
                // Timestamps are stored in SQLite-native format: "YYYY-MM-DD HH:MM:SS"
                use chrono::NaiveDateTime;
                let next_retry_at =
                    NaiveDateTime::parse_from_str(&next_retry_raw, "%Y-%m-%d %H:%M:%S")
                        .map(|ndt| ndt.and_utc())
                        .unwrap_or_else(|_| Utc::now());

                let status_raw: String = row.get(6)?;

                Ok(RetryItem {
                    id: row.get(0)?,
                    operation: row.get(1)?,
                    attempts: row.get::<_, u32>(2)?,
                    max_attempts: row.get::<_, u32>(3)?,
                    next_retry_at,
                    last_error: row.get(5)?,
                    status: RetryStatus::from_str(&status_raw),
                })
            })?
            .filter_map(|r| r.ok())
            .collect();

        Ok(items)
    }

    /// Mark an item as successfully completed.
    ///
    /// Sets `status = 'completed'`.
    pub fn mark_success(conn: &Connection, id: i64) -> rusqlite::Result<()> {
        conn.execute(
            "UPDATE db_retry_queue SET status = 'completed' WHERE id = ?1",
            params![id],
        )?;
        Ok(())
    }

    /// Record a transient failure and schedule the next retry.
    ///
    /// Increments `attempts`, stores `error` in `last_error`, sets
    /// `next_retry_at`, and resets `status` to `'pending'` so the item
    /// will be picked up again after the backoff period.
    pub fn mark_failure(
        conn: &Connection,
        id: i64,
        error: &str,
        next_retry_at: DateTime<Utc>,
    ) -> rusqlite::Result<()> {
        conn.execute(
            "UPDATE db_retry_queue \
             SET attempts = attempts + 1, \
                 last_error = ?2, \
                 next_retry_at = ?3, \
                 status = 'pending' \
             WHERE id = ?1",
            params![
                id,
                error,
                next_retry_at.format("%Y-%m-%d %H:%M:%S").to_string()
            ],
        )?;
        Ok(())
    }

    /// Permanently fail an item — no further retries will be attempted.
    ///
    /// Sets `status = 'failed'`.  The row is retained for audit/debug
    /// purposes and will be removed by `cleanup_completed`.
    pub fn mark_permanently_failed(conn: &Connection, id: i64) -> rusqlite::Result<()> {
        conn.execute(
            "UPDATE db_retry_queue SET status = 'failed' WHERE id = ?1",
            params![id],
        )?;
        Ok(())
    }

    /// Delete rows that are `'completed'` or `'failed'` and were created
    /// more than `older_than_days` days ago.
    ///
    /// Returns the number of rows deleted.
    pub fn cleanup_completed(conn: &Connection, older_than_days: u32) -> rusqlite::Result<usize> {
        let deleted = conn.execute(
            "DELETE FROM db_retry_queue \
             WHERE status IN ('completed', 'failed') \
             AND created_at <= datetime('now', printf('-%d days', ?1))",
            params![older_than_days],
        )?;
        Ok(deleted)
    }
}

// ── Tests ─────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use chrono::Utc;
    use rusqlite::Connection;

    use super::*;

    // ── Helpers ───────────────────────────────────────────

    /// Open an in-memory SQLite connection with the minimal schema required
    /// for these tests.  Using a raw `Connection` (not the pool-backed
    /// `Database`) keeps the tests fast and self-contained.
    fn open_memory() -> Connection {
        let conn = Connection::open_in_memory().expect("open :memory:");
        conn.execute_batch(
            "CREATE TABLE db_retry_queue (
                id           INTEGER PRIMARY KEY AUTOINCREMENT,
                operation    TEXT    NOT NULL,
                attempts     INTEGER NOT NULL DEFAULT 0,
                max_attempts INTEGER NOT NULL DEFAULT 5,
                next_retry_at TEXT   NOT NULL,
                last_error   TEXT,
                created_at   TEXT    NOT NULL DEFAULT (datetime('now')),
                status       TEXT    NOT NULL DEFAULT 'pending'
            );
            CREATE INDEX idx_retry_queue_status_next
                ON db_retry_queue(status, next_retry_at);",
        )
        .expect("create schema");
        conn
    }

    // ── Required tests ────────────────────────────────────

    /// `enqueue` must insert a row with `status = 'pending'` and return its id.
    #[test]
    fn test_enqueue_creates_pending_item() {
        let conn = open_memory();

        let id = RetryQueue::enqueue(&conn, r#"{"op":"sync","source_id":1}"#, 3).expect("enqueue");

        assert!(id > 0, "returned id must be positive");

        let (status, attempts, max_attempts): (String, u32, u32) = conn
            .query_row(
                "SELECT status, attempts, max_attempts FROM db_retry_queue WHERE id = ?1",
                params![id],
                |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?)),
            )
            .expect("select");

        assert_eq!(status, "pending");
        assert_eq!(attempts, 0);
        assert_eq!(max_attempts, 3);
    }

    /// `fetch_due` must return only `pending` items whose `next_retry_at` is
    /// in the past; future-scheduled items must be excluded.
    #[test]
    fn test_fetch_due_returns_only_pending_past_items() {
        let conn = open_memory();

        // Insert a past-due item (next_retry_at = 1 hour ago).
        let past = (Utc::now() - chrono::Duration::hours(1))
            .format("%Y-%m-%d %H:%M:%S")
            .to_string();
        conn.execute(
            "INSERT INTO db_retry_queue (operation, next_retry_at, status) \
             VALUES ('past_op', ?1, 'pending')",
            params![past],
        )
        .expect("insert past");

        // Insert a future item (next_retry_at = 1 hour from now).
        let future = (Utc::now() + chrono::Duration::hours(1))
            .format("%Y-%m-%d %H:%M:%S")
            .to_string();
        conn.execute(
            "INSERT INTO db_retry_queue (operation, next_retry_at, status) \
             VALUES ('future_op', ?1, 'pending')",
            params![future],
        )
        .expect("insert future");

        // Insert a completed item that is also past-due (should be excluded).
        conn.execute(
            "INSERT INTO db_retry_queue (operation, next_retry_at, status) \
             VALUES ('done_op', ?1, 'completed')",
            params![past.clone()],
        )
        .expect("insert completed");

        let due = RetryQueue::fetch_due(&conn, 10).expect("fetch_due");

        assert_eq!(
            due.len(),
            1,
            "only the past-due pending item should be returned"
        );
        assert_eq!(due[0].operation, "past_op");
        assert_eq!(due[0].status, RetryStatus::Pending);
    }

    /// `mark_success` must set `status = 'completed'`.
    #[test]
    fn test_mark_success_sets_completed() {
        let conn = open_memory();

        let id = RetryQueue::enqueue(&conn, r#"{"op":"epg_fetch"}"#, 5).expect("enqueue");
        RetryQueue::mark_success(&conn, id).expect("mark_success");

        let status: String = conn
            .query_row(
                "SELECT status FROM db_retry_queue WHERE id = ?1",
                params![id],
                |row| row.get(0),
            )
            .expect("select");

        assert_eq!(status, "completed");
    }

    /// `mark_failure` must increment `attempts` and preserve the error message.
    #[test]
    fn test_mark_failure_increments_attempts() {
        let conn = open_memory();

        let id = RetryQueue::enqueue(&conn, r#"{"op":"image_dl","url":"http://x"}"#, 5)
            .expect("enqueue");

        let retry_at = Utc::now() + chrono::Duration::minutes(5);
        RetryQueue::mark_failure(&conn, id, "connection timeout", retry_at)
            .expect("mark_failure first");

        let (attempts, last_error, status): (u32, Option<String>, String) = conn
            .query_row(
                "SELECT attempts, last_error, status FROM db_retry_queue WHERE id = ?1",
                params![id],
                |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?)),
            )
            .expect("select after first failure");

        assert_eq!(attempts, 1);
        assert_eq!(last_error.as_deref(), Some("connection timeout"));
        assert_eq!(status, "pending", "item should remain pending for retry");

        // Second failure.
        let retry_at2 = Utc::now() + chrono::Duration::minutes(30);
        RetryQueue::mark_failure(&conn, id, "DNS failure", retry_at2).expect("mark_failure second");

        let attempts2: u32 = conn
            .query_row(
                "SELECT attempts FROM db_retry_queue WHERE id = ?1",
                params![id],
                |row| row.get(0),
            )
            .expect("select after second failure");

        assert_eq!(attempts2, 2);
    }

    /// `cleanup_completed` must remove old completed/failed rows but leave
    /// recent ones and pending ones untouched.
    #[test]
    fn test_cleanup_removes_old_completed() {
        let conn = open_memory();

        // Insert an old completed row (created 10 days ago).
        conn.execute(
            "INSERT INTO db_retry_queue \
             (operation, next_retry_at, status, created_at) \
             VALUES ('old_done', datetime('now'), 'completed', datetime('now', '-10 days'))",
            [],
        )
        .expect("insert old completed");

        // Insert a recent completed row (created now).
        let id_recent = RetryQueue::enqueue(&conn, r#"{"op":"recent"}"#, 5).expect("enqueue");
        RetryQueue::mark_success(&conn, id_recent).expect("mark_success");

        // Insert a pending row (should never be deleted).
        let id_pending = RetryQueue::enqueue(&conn, r#"{"op":"pending"}"#, 5).expect("enqueue");

        // Insert an old failed row (created 10 days ago).
        conn.execute(
            "INSERT INTO db_retry_queue \
             (operation, next_retry_at, status, created_at) \
             VALUES ('old_failed', datetime('now'), 'failed', datetime('now', '-10 days'))",
            [],
        )
        .expect("insert old failed");

        // Clean up rows older than 7 days.
        let deleted = RetryQueue::cleanup_completed(&conn, 7).expect("cleanup");

        assert_eq!(
            deleted, 2,
            "old completed and old failed rows should be removed"
        );

        // Verify pending row still exists.
        let pending_count: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM db_retry_queue WHERE id = ?1",
                params![id_pending],
                |row| row.get(0),
            )
            .expect("count pending");
        assert_eq!(pending_count, 1, "pending row must not be deleted");

        // Verify recent completed row still exists.
        let recent_count: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM db_retry_queue WHERE id = ?1",
                params![id_recent],
                |row| row.get(0),
            )
            .expect("count recent");
        assert_eq!(recent_count, 1, "recent completed row must not be deleted");
    }

    // ── Extra coverage ────────────────────────────────────

    /// `mark_permanently_failed` must set `status = 'failed'`.
    #[test]
    fn test_mark_permanently_failed_sets_failed_status() {
        let conn = open_memory();

        let id = RetryQueue::enqueue(&conn, r#"{"op":"sync"}"#, 1).expect("enqueue");
        RetryQueue::mark_permanently_failed(&conn, id).expect("mark_permanently_failed");

        let status: String = conn
            .query_row(
                "SELECT status FROM db_retry_queue WHERE id = ?1",
                params![id],
                |row| row.get(0),
            )
            .expect("select");

        assert_eq!(status, "failed");
    }

    /// `fetch_due` must respect the `limit` argument.
    #[test]
    fn test_fetch_due_respects_limit() {
        let conn = open_memory();

        let past = (Utc::now() - chrono::Duration::seconds(1))
            .format("%Y-%m-%d %H:%M:%S")
            .to_string();
        for i in 0..5 {
            conn.execute(
                "INSERT INTO db_retry_queue (operation, next_retry_at, status) \
                 VALUES (?1, ?2, 'pending')",
                params![format!("op_{i}"), past],
            )
            .expect("insert");
        }

        let due = RetryQueue::fetch_due(&conn, 3).expect("fetch_due");
        assert_eq!(due.len(), 3);
    }

    /// Unused `Duration` import guard — ensures the test helper compiles
    /// even if `std::time::Duration` is not used directly in a specific test.
    #[allow(dead_code)]
    fn _uses_duration(_: Duration) {}
}
