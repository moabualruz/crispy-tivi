//! Durable retry queue backed by SQLite.
//!
//! Operations that fail transiently (e.g. network unavailable) can be
//! enqueued here and retried later by a background worker. Each item
//! records the operation name, a JSON payload, attempt count, and the
//! next retry timestamp.
//!
//! The table `db_retry_queue` is created by migration 001_initial_schema.sql.

use chrono::{DateTime, Duration as ChronoDuration, Utc};
use rusqlite::params;

use crate::database::{Database, DbError};

// ── Model ─────────────────────────────────────────────────────────────────────

/// A single queued operation.
#[derive(Debug, Clone, PartialEq)]
pub struct QueueItem {
    pub id: i64,
    pub operation: String,
    pub payload: String,
    pub attempts: i32,
    pub next_retry_at: DateTime<Utc>,
    pub max_lifetime: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
}

// ── RetryQueue ────────────────────────────────────────────────────────────────

/// Durable retry queue backed by the app SQLite database.
#[derive(Clone)]
pub struct RetryQueue {
    db: Database,
}

impl RetryQueue {
    /// Create a `RetryQueue` wrapping the given database handle.
    pub fn new(db: Database) -> Self {
        Self { db }
    }

    /// Add a new operation to the queue.
    ///
    /// `operation` is a short tag (e.g. `"sync_source"`).
    /// `payload` is an opaque JSON string.
    /// `max_lifetime` is how long from now until the item is abandoned.
    pub fn enqueue(
        &self,
        operation: &str,
        payload: &str,
        max_lifetime: ChronoDuration,
    ) -> Result<i64, DbError> {
        let now = Utc::now();
        let max_lifetime_at = now + max_lifetime;
        let conn = self.db.get()?;
        conn.execute(
            "INSERT INTO db_retry_queue \
             (operation, payload, attempts, next_retry_at, max_lifetime, created_at) \
             VALUES (?1, ?2, 0, ?3, ?4, ?5)",
            params![
                operation,
                payload,
                now.to_rfc3339(),
                max_lifetime_at.to_rfc3339(),
                now.to_rfc3339(),
            ],
        )?;
        Ok(conn.last_insert_rowid())
    }

    /// Return all items whose `next_retry_at` is in the past and that are
    /// still within their `max_lifetime`.
    pub fn dequeue_ready(&self) -> Result<Vec<QueueItem>, DbError> {
        let now = Utc::now().to_rfc3339();
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT id, operation, payload, attempts, \
                    next_retry_at, max_lifetime, created_at \
             FROM db_retry_queue \
             WHERE next_retry_at <= ?1 \
               AND max_lifetime  >  ?1 \
             ORDER BY next_retry_at ASC",
        )?;
        let items = stmt
            .query_map(params![now], |row| {
                Ok(QueueItem {
                    id: row.get(0)?,
                    operation: row.get(1)?,
                    payload: row.get(2)?,
                    attempts: row.get(3)?,
                    next_retry_at: parse_dt(row.get::<_, String>(4)?),
                    max_lifetime: parse_dt(row.get::<_, String>(5)?),
                    created_at: parse_dt(row.get::<_, String>(6)?),
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(items)
    }

    /// Mark an item as successfully completed (delete from queue).
    pub fn mark_done(&self, id: i64) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute("DELETE FROM db_retry_queue WHERE id = ?1", params![id])?;
        Ok(())
    }

    /// Increment attempt count and schedule the next retry with backoff.
    ///
    /// Backoff: `10s * 2^attempts`, capped at 1 hour.
    pub fn mark_failed(&self, id: i64) -> Result<(), DbError> {
        let conn = self.db.get()?;

        let attempts: i32 = conn.query_row(
            "SELECT attempts FROM db_retry_queue WHERE id = ?1",
            params![id],
            |row| row.get(0),
        )?;

        let new_attempts = attempts + 1;
        let shift = (new_attempts as u32).min(12); // cap at 2^12 = 4096 s ≈ 68 min
        let backoff_secs = 10i64 * (1i64 << shift);
        let backoff_secs = backoff_secs.min(3600);
        let next_retry = Utc::now() + ChronoDuration::seconds(backoff_secs);

        conn.execute(
            "UPDATE db_retry_queue \
             SET attempts = ?1, next_retry_at = ?2 \
             WHERE id = ?3",
            params![new_attempts, next_retry.to_rfc3339(), id],
        )?;
        Ok(())
    }

    /// Delete items that have exceeded their `max_lifetime`.
    pub fn prune_expired(&self) -> Result<usize, DbError> {
        let now = Utc::now().to_rfc3339();
        let conn = self.db.get()?;
        let n = conn.execute(
            "DELETE FROM db_retry_queue WHERE max_lifetime <= ?1",
            params![now],
        )?;
        Ok(n)
    }

    /// Total items currently in the queue (for monitoring).
    pub fn len(&self) -> Result<usize, DbError> {
        let conn = self.db.get()?;
        let n: i64 =
            conn.query_row("SELECT COUNT(*) FROM db_retry_queue", [], |row| row.get(0))?;
        Ok(n as usize)
    }

    /// Returns `true` if the queue is empty.
    pub fn is_empty(&self) -> Result<bool, DbError> {
        Ok(self.len()? == 0)
    }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

fn parse_dt(s: String) -> DateTime<Utc> {
    s.parse::<DateTime<Utc>>().unwrap_or_else(|_| Utc::now())
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::database::Database;

    fn make_queue() -> RetryQueue {
        RetryQueue::new(Database::open_in_memory().expect("in-memory DB"))
    }

    #[test]
    fn enqueue_and_len() {
        let q = make_queue();
        assert_eq!(q.len().unwrap(), 0);

        q.enqueue("sync_source", r#"{"id":"s1"}"#, ChronoDuration::hours(1))
            .unwrap();
        assert_eq!(q.len().unwrap(), 1);
    }

    #[test]
    fn dequeue_ready_returns_item() {
        let q = make_queue();
        let id = q
            .enqueue("op_a", r#"{"x":1}"#, ChronoDuration::hours(1))
            .unwrap();

        let ready = q.dequeue_ready().unwrap();
        assert_eq!(ready.len(), 1);
        assert_eq!(ready[0].id, id);
        assert_eq!(ready[0].operation, "op_a");
        assert_eq!(ready[0].attempts, 0);
    }

    #[test]
    fn mark_done_removes_item() {
        let q = make_queue();
        let id = q
            .enqueue("op_b", "{}", ChronoDuration::hours(1))
            .unwrap();

        q.mark_done(id).unwrap();
        assert_eq!(q.len().unwrap(), 0);
    }

    #[test]
    fn mark_failed_increments_attempts_and_reschedules() {
        let q = make_queue();
        let id = q
            .enqueue("op_c", "{}", ChronoDuration::hours(1))
            .unwrap();

        q.mark_failed(id).unwrap();

        // After failure: attempts = 1, next_retry_at should be in the future.
        let items = q.dequeue_ready().unwrap();
        // next_retry_at is now in the future so dequeue_ready returns empty.
        assert!(
            items.is_empty(),
            "item should not be ready immediately after mark_failed"
        );
        assert_eq!(q.len().unwrap(), 1);
    }

    #[test]
    fn prune_expired_removes_old_items() {
        let db = Database::open_in_memory().expect("in-memory DB");
        let conn = db.get().unwrap();

        // Insert an already-expired item directly.
        let past = (Utc::now() - ChronoDuration::hours(2)).to_rfc3339();
        let now_s = Utc::now().to_rfc3339();
        conn.execute(
            "INSERT INTO db_retry_queue \
             (operation, payload, attempts, next_retry_at, max_lifetime, created_at) \
             VALUES ('old_op', '{}', 0, ?1, ?2, ?3)",
            params![past, past, now_s],
        )
        .unwrap();
        drop(conn);

        let q = RetryQueue::new(db);
        assert_eq!(q.len().unwrap(), 1);

        let pruned = q.prune_expired().unwrap();
        assert_eq!(pruned, 1);
        assert_eq!(q.len().unwrap(), 0);
    }

    #[test]
    fn dequeue_excludes_expired() {
        let db = Database::open_in_memory().expect("in-memory DB");
        let conn = db.get().unwrap();

        // Insert an expired item with past next_retry_at.
        let past = (Utc::now() - ChronoDuration::hours(2)).to_rfc3339();
        let now_s = Utc::now().to_rfc3339();
        conn.execute(
            "INSERT INTO db_retry_queue \
             (operation, payload, attempts, next_retry_at, max_lifetime, created_at) \
             VALUES ('expired_op', '{}', 0, ?1, ?2, ?3)",
            params![past, past, now_s],
        )
        .unwrap();
        drop(conn);

        let q = RetryQueue::new(db);
        // dequeue_ready excludes items past max_lifetime.
        let ready = q.dequeue_ready().unwrap();
        assert!(ready.is_empty(), "expired item must not be dequeued");
    }

    #[test]
    fn is_empty_reflects_queue_state() {
        let q = make_queue();
        assert!(q.is_empty().unwrap());
        q.enqueue("op", "{}", ChronoDuration::minutes(5)).unwrap();
        assert!(!q.is_empty().unwrap());
    }
}
