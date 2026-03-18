//! Durable local outbox for offline user actions.
//!
//! Queues position updates, favorites toggles, and watchlist
//! changes while the device is offline. On reconnect, the
//! caller drains the queue and replays actions to the server.
//!
//! Conflict resolution:
//! - **Position updates** — last-write-wins by `created_at`.
//! - **Favorites / watchlist** — union merge (all actions kept
//!   until explicitly synced and marked).

use chrono::Utc;
use rusqlite::params;
use serde_json::Value;

use crate::database::{Database, DbError};

// ── Table DDL ────────────────────────────────────────────

/// DDL for the outbox table (created on demand).
const CREATE_OUTBOX: &str = "\
CREATE TABLE IF NOT EXISTS db_offline_outbox (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    action_type TEXT    NOT NULL,
    payload     TEXT    NOT NULL,
    created_at  INTEGER NOT NULL,
    synced      INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_outbox_unsynced
    ON db_offline_outbox (synced, created_at);
";

// ── PendingAction ────────────────────────────────────────

/// A single queued offline action.
#[derive(Debug, Clone)]
pub struct PendingAction {
    /// Rowid in `db_offline_outbox`.
    pub id: i64,
    /// Semantic action type, e.g. `"position_update"`,
    /// `"favorite_toggle"`, `"watchlist_change"`.
    pub action_type: String,
    /// Arbitrary JSON payload for the action.
    pub payload: Value,
    /// Unix timestamp (seconds) when the action was enqueued.
    pub created_at: i64,
}

// ── OfflineOutbox ────────────────────────────────────────

/// Service for the durable local offline action outbox.
pub struct OfflineOutbox;

impl OfflineOutbox {
    /// Ensure the outbox table exists. Call once at startup.
    pub fn ensure_table(db: &Database) -> Result<(), DbError> {
        db.get()?.execute_batch(CREATE_OUTBOX)?;
        Ok(())
    }

    /// Enqueue an offline action. `payload` must be a valid
    /// `serde_json::Value`.
    pub fn enqueue_action(
        db: &Database,
        action_type: &str,
        payload: Value,
    ) -> Result<i64, DbError> {
        let now = Utc::now().timestamp();
        let payload_str = serde_json::to_string(&payload)
            .map_err(|e| DbError::Migration(format!("serialize payload: {e}")))?;

        let conn = db.get()?;

        // For position updates, apply last-write-wins by
        // replacing any existing unsynced entry for the same
        // content_id before inserting the new one.
        if action_type == "position_update" {
            if let Some(content_id) = payload.get("content_id").and_then(|v| v.as_str()) {
                conn.execute(
                    "DELETE FROM db_offline_outbox \
                     WHERE action_type = 'position_update' \
                       AND synced = 0 \
                       AND json_extract(payload, '$.content_id') = ?1",
                    params![content_id],
                )?;
            }
        }

        conn.execute(
            "INSERT INTO db_offline_outbox (action_type, payload, created_at) \
             VALUES (?1, ?2, ?3)",
            params![action_type, payload_str, now],
        )?;

        Ok(conn.last_insert_rowid())
    }

    /// Return all unsynced actions ordered by `created_at` ascending.
    pub fn drain_pending(db: &Database) -> Result<Vec<PendingAction>, DbError> {
        let conn = db.get()?;
        let mut stmt = conn.prepare(
            "SELECT id, action_type, payload, created_at \
             FROM db_offline_outbox \
             WHERE synced = 0 \
             ORDER BY created_at ASC",
        )?;

        let rows = stmt
            .query_map([], |row| {
                Ok((
                    row.get::<_, i64>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, String>(2)?,
                    row.get::<_, i64>(3)?,
                ))
            })?
            .filter_map(|r| r.ok())
            .filter_map(|(id, action_type, payload_str, created_at)| {
                let payload = serde_json::from_str(&payload_str).ok()?;
                Some(PendingAction {
                    id,
                    action_type,
                    payload,
                    created_at,
                })
            })
            .collect();

        Ok(rows)
    }

    /// Mark the given action ids as synced.
    pub fn mark_synced(db: &Database, ids: &[i64]) -> Result<(), DbError> {
        if ids.is_empty() {
            return Ok(());
        }
        let conn = db.get()?;
        for id in ids {
            conn.execute(
                "UPDATE db_offline_outbox SET synced = 1 WHERE id = ?1",
                params![id],
            )?;
        }
        Ok(())
    }

    /// Remove all synced entries to keep the table compact.
    pub fn purge_synced(db: &Database) -> Result<usize, DbError> {
        let conn = db.get()?;
        let deleted = conn.execute("DELETE FROM db_offline_outbox WHERE synced = 1", [])?;
        Ok(deleted)
    }
}

// ── Tests ─────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::database::Database;
    use serde_json::json;

    fn setup() -> Database {
        let db = Database::open_in_memory().expect("open_in_memory");
        OfflineOutbox::ensure_table(&db).expect("ensure_table");
        db
    }

    #[test]
    fn test_enqueue_and_drain_basic() {
        let db = setup();
        OfflineOutbox::enqueue_action(&db, "favorite_toggle", json!({"id": "ch1", "value": true}))
            .unwrap();
        OfflineOutbox::enqueue_action(&db, "watchlist_change", json!({"id": "m1", "add": true}))
            .unwrap();

        let pending = OfflineOutbox::drain_pending(&db).unwrap();
        assert_eq!(pending.len(), 2);
        assert_eq!(pending[0].action_type, "favorite_toggle");
        assert_eq!(pending[1].action_type, "watchlist_change");
    }

    #[test]
    fn test_mark_synced_hides_from_drain() {
        let db = setup();
        let id =
            OfflineOutbox::enqueue_action(&db, "favorite_toggle", json!({"id": "ch1"})).unwrap();

        OfflineOutbox::mark_synced(&db, &[id]).unwrap();
        let pending = OfflineOutbox::drain_pending(&db).unwrap();
        assert!(pending.is_empty());
    }

    #[test]
    fn test_position_update_last_write_wins() {
        let db = setup();
        OfflineOutbox::enqueue_action(
            &db,
            "position_update",
            json!({"content_id": "vod-1", "position_secs": 100.0}),
        )
        .unwrap();
        OfflineOutbox::enqueue_action(
            &db,
            "position_update",
            json!({"content_id": "vod-1", "position_secs": 200.0}),
        )
        .unwrap();

        let pending = OfflineOutbox::drain_pending(&db).unwrap();
        // Only the latest position update for the same content_id survives.
        let pos_updates: Vec<_> = pending
            .iter()
            .filter(|a| a.action_type == "position_update")
            .collect();
        assert_eq!(pos_updates.len(), 1);
        assert_eq!(
            pos_updates[0].payload["position_secs"],
            serde_json::json!(200.0)
        );
    }

    #[test]
    fn test_favorites_union_merge_kept() {
        let db = setup();
        // Two different favorite toggles for different channels
        // should both survive (union merge).
        OfflineOutbox::enqueue_action(&db, "favorite_toggle", json!({"id": "ch1"})).unwrap();
        OfflineOutbox::enqueue_action(&db, "favorite_toggle", json!({"id": "ch2"})).unwrap();

        let pending = OfflineOutbox::drain_pending(&db).unwrap();
        assert_eq!(pending.len(), 2);
    }

    #[test]
    fn test_purge_synced_removes_only_synced() {
        let db = setup();
        let id1 =
            OfflineOutbox::enqueue_action(&db, "favorite_toggle", json!({"id": "ch1"})).unwrap();
        OfflineOutbox::enqueue_action(&db, "favorite_toggle", json!({"id": "ch2"})).unwrap();

        OfflineOutbox::mark_synced(&db, &[id1]).unwrap();
        let deleted = OfflineOutbox::purge_synced(&db).unwrap();
        assert_eq!(deleted, 1);

        // One unsynchronised entry remains.
        let pending = OfflineOutbox::drain_pending(&db).unwrap();
        assert_eq!(pending.len(), 1);
    }

    #[test]
    fn test_drain_ordering_by_created_at() {
        let db = setup();
        // Insert with explicit timestamps to guarantee order.
        let conn = db.get().unwrap();
        conn.execute(
            "INSERT INTO db_offline_outbox (action_type, payload, created_at) VALUES ('a', '{}', 10)",
            [],
        )
        .unwrap();
        conn.execute(
            "INSERT INTO db_offline_outbox (action_type, payload, created_at) VALUES ('b', '{}', 5)",
            [],
        )
        .unwrap();
        drop(conn);

        let pending = OfflineOutbox::drain_pending(&db).unwrap();
        assert_eq!(pending[0].action_type, "b"); // oldest first
        assert_eq!(pending[1].action_type, "a");
    }
}
