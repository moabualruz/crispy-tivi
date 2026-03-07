//! Business logic services.
//!
//! Orchestrates database operations and domain logic.
//! `CrispyService` is the single API surface consumed
//! by both the FFI bridge and the WebSocket server.

use std::sync::{Arc, Mutex};

use chrono::NaiveDateTime;
use rusqlite::params;

use crate::database::{Database, DbError};
use crate::events::{DataChangeEvent, EventCallback};

pub mod epg_sync;
pub mod m3u_sync;
pub mod stalker_sync;
pub mod xtream_sync;

mod bulk;
mod categories;
mod channels;
mod dvr;
mod epg;
mod history;
mod misc;
mod profiles;
mod reminders;
mod settings;
mod sources;
mod vod;
mod watchlist;

#[cfg(test)]
mod test_helpers;

// ── DateTime helpers ────────────────────────────────

/// Convert `NaiveDateTime` to Unix timestamp (seconds).
pub(crate) fn dt_to_ts(dt: &NaiveDateTime) -> i64 {
    dt.and_utc().timestamp()
}

/// Convert optional `NaiveDateTime` to optional Unix ts.
pub(crate) fn opt_dt_to_ts(dt: &Option<NaiveDateTime>) -> Option<i64> {
    dt.map(|d| d.and_utc().timestamp())
}

/// Convert Unix timestamp (seconds) to `NaiveDateTime`.
///
/// Returns the Unix epoch (1970-01-01 00:00:00) for
/// invalid or out-of-range timestamps instead of
/// panicking.
pub(crate) fn ts_to_dt(ts: i64) -> NaiveDateTime {
    chrono::DateTime::from_timestamp(ts, 0)
        .unwrap_or_default()
        .naive_utc()
}

/// Convert optional Unix ts to optional
/// `NaiveDateTime`.
pub(crate) fn opt_ts_to_dt(ts: Option<i64>) -> Option<NaiveDateTime> {
    ts.map(ts_to_dt)
}

// ── Bool helpers ────────────────────────────────────

/// Convert `bool` to SQLite integer (0/1).
pub(crate) fn bool_to_int(b: bool) -> i32 {
    if b { 1 } else { 0 }
}

/// Convert SQLite integer (0/1) to `bool`.
pub(crate) fn int_to_bool(i: i32) -> bool {
    i != 0
}

// ── CrispyService ──────────────────────────────────

/// Primary service wrapping all CRUD operations.
///
/// Holds a `Database` handle and exposes methods
/// grouped by feature domain. Every method takes
/// `&self` because rusqlite `Connection` uses
/// interior mutability for statements.
///
/// The optional `event_cb` broadcasts data-change
/// events to Flutter via FFI `StreamSink` (native)
/// or `tokio::sync::broadcast` (web). All clones
/// share the same callback via `Arc`.
#[derive(Clone)]
pub struct CrispyService {
    pub(super) db: Database,
    pub(super) event_cb: Arc<Mutex<Option<EventCallback>>>,
    pub(super) batching: Arc<Mutex<bool>>,
}

/// Build a comma-separated SQL IN-clause placeholder string
/// for `count` parameters, e.g. `?1, ?2, ?3`.
///
/// Used by any method that constructs a `WHERE x IN (...)` query
/// with a runtime-sized list of bind parameters.
pub(crate) fn build_in_placeholders(count: usize) -> String {
    (1..=count)
        .map(|i| format!("?{i}"))
        .collect::<Vec<_>>()
        .join(", ")
}

/// Convert a string slice into a `Vec<&dyn ToSql>` for use as
/// rusqlite IN-clause parameters.
///
/// ```ignore
/// let params = str_params(ids);
/// stmt.query_map(params.as_slice(), row_mapper)?;
/// ```
pub(crate) fn str_params(ids: &[String]) -> Vec<&dyn rusqlite::types::ToSql> {
    ids.iter()
        .map(|s| s as &dyn rusqlite::types::ToSql)
        .collect()
}

/// Delete rows from `table` belonging to `source_id` whose `id`
/// is not in `keep_ids`. Runs inside the provided transaction.
/// Returns the number of rows deleted.
pub(super) fn delete_removed_by_source(
    tx: &rusqlite::Transaction,
    table: &str,
    source_id: &str,
    keep_ids: &[String],
) -> Result<usize, DbError> {
    let temp = format!("_keep_{table}");
    tx.execute(
        &format!("CREATE TEMP TABLE IF NOT EXISTS {temp} (id TEXT PRIMARY KEY)"),
        [],
    )?;
    tx.execute(&format!("DELETE FROM {temp}"), [])?;
    let insert_sql = format!("INSERT OR IGNORE INTO {temp} (id) VALUES (?1)");
    for id in keep_ids {
        tx.execute(&insert_sql, params![id])?;
    }
    let deleted = tx.execute(
        &format!("DELETE FROM {table} WHERE source_id = ?1 AND id NOT IN (SELECT id FROM {temp})"),
        params![source_id],
    )?;
    tx.execute(&format!("DROP TABLE IF EXISTS {temp}"), [])?;
    Ok(deleted)
}

impl CrispyService {
    /// Create a service wrapping an existing database.
    pub fn new(db: Database) -> Self {
        Self {
            db,
            event_cb: Arc::new(Mutex::new(None)),
            batching: Arc::new(Mutex::new(false)),
        }
    }

    /// Open a file-backed database at `path`.
    pub fn open(path: &str) -> Result<Self, DbError> {
        Ok(Self::new(Database::open(path)?))
    }

    /// Open an in-memory database (for testing).
    pub fn open_in_memory() -> Result<Self, DbError> {
        Ok(Self::new(Database::open_in_memory()?))
    }

    /// Register an event callback. Replaces any
    /// previous one. All clones share the same
    /// callback.
    pub fn set_event_callback(&self, cb: EventCallback) {
        *self.event_cb.lock().unwrap_or_else(|e| e.into_inner()) = Some(cb);
    }

    /// Emit a data-change event. No-op if no callback
    /// is registered, or if a batch scope is active.
    pub(super) fn emit(&self, event: DataChangeEvent) {
        if *self.batching.lock().unwrap_or_else(|e| e.into_inner()) {
            return;
        }
        if let Some(cb) = self
            .event_cb
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .as_ref()
        {
            cb(&event);
        }
    }

    /// Emit one event per distinct source_id found in `items`.
    ///
    /// Iterates `items`, extracts the source id via `get_source_id`,
    /// and calls `make_event` exactly once per unique non-empty id.
    /// If `items` is empty, calls `make_event` with an empty string
    /// so that callers always get at least one notification.
    pub(super) fn emit_per_source<T, F>(
        &self,
        items: &[T],
        get_source_id: F,
        make_event: impl Fn(String) -> DataChangeEvent,
    ) where
        F: Fn(&T) -> Option<&str>,
    {
        let mut seen = std::collections::HashSet::new();
        for item in items {
            let sid = get_source_id(item).unwrap_or("").to_string();
            if seen.insert(sid.clone()) {
                self.emit(make_event(sid));
            }
        }
        if items.is_empty() {
            self.emit(make_event(String::new()));
        }
    }

    /// Persist a full sync batch (channels + VOD) inside a single
    /// `batch_events` scope so Flutter receives one `BulkDataRefresh`.
    ///
    /// Called by every sync backend (M3U, Xtream, Stalker) after
    /// fetching and parsing content. Saves channels, prunes removed
    /// channels, saves VOD items, and prunes removed VOD items.
    pub fn save_sync_data(
        &self,
        source_id: &str,
        channels: &[crate::models::Channel],
        channel_ids: &[String],
        vod_items: &[crate::models::VodItem],
        vod_ids: &[String],
    ) -> Result<(), crate::database::DbError> {
        self.batch_events(|svc| {
            svc.save_channels(channels)?;
            svc.delete_removed_channels(source_id, channel_ids)?;
            svc.save_vod_items(vod_items)?;
            svc.delete_removed_vod_items(source_id, vod_ids)?;
            Ok(())
        })
    }

    /// Suppresses individual event emission during the
    /// closure. Emits a single `BulkDataRefresh` after
    /// completion. Use for bulk operations like playlist
    /// import or cloud sync.
    pub fn batch_events<F, R>(&self, f: F) -> R
    where
        F: FnOnce(&Self) -> R,
    {
        struct BatchGuard<'a>(&'a std::sync::Mutex<bool>);
        impl Drop for BatchGuard<'_> {
            fn drop(&mut self) {
                *self.0.lock().unwrap_or_else(|e| e.into_inner()) = false;
            }
        }
        *self.batching.lock().unwrap_or_else(|e| e.into_inner()) = true;
        let _guard = BatchGuard(&self.batching);
        let result = f(self);
        drop(_guard);
        self.emit(DataChangeEvent::BulkDataRefresh);
        result
    }
}

#[cfg(test)]
mod batch_tests {
    use super::*;
    use crate::events::serialize_event;

    #[test]
    fn batch_events_suppresses_individual() {
        let svc = CrispyService::open_in_memory().unwrap();
        let events = Arc::new(Mutex::new(Vec::<String>::new()));
        let events_clone = events.clone();
        svc.set_event_callback(Arc::new(move |e: &DataChangeEvent| {
            events_clone.lock().unwrap().push(serialize_event(e));
        }));

        svc.batch_events(|s| {
            s.set_setting("key1", "val1").unwrap();
            s.set_setting("key2", "val2").unwrap();
        });

        let collected = events.lock().unwrap();
        // Only the final BulkDataRefresh should be emitted.
        assert_eq!(collected.len(), 1);
        assert!(collected[0].contains("BulkDataRefresh"));
    }

    #[test]
    fn emit_works_outside_batch() {
        let svc = CrispyService::open_in_memory().unwrap();
        let events = Arc::new(Mutex::new(Vec::<String>::new()));
        let events_clone = events.clone();
        svc.set_event_callback(Arc::new(move |e: &DataChangeEvent| {
            events_clone.lock().unwrap().push(serialize_event(e));
        }));

        svc.set_setting("key1", "val1").unwrap();
        svc.set_setting("key2", "val2").unwrap();

        let collected = events.lock().unwrap();
        assert_eq!(collected.len(), 2);
        assert!(collected[0].contains("SettingsUpdated"));
        assert!(collected[1].contains("SettingsUpdated"));
    }

    #[test]
    fn batch_events_returns_result() {
        let svc = CrispyService::open_in_memory().unwrap();
        let result = svc.batch_events(|_s| 42);
        assert_eq!(result, 42);
    }

    #[test]
    fn batch_events_restores_flag_on_completion() {
        let svc = CrispyService::open_in_memory().unwrap();
        let events = Arc::new(Mutex::new(Vec::<String>::new()));
        let events_clone = events.clone();
        svc.set_event_callback(Arc::new(move |e: &DataChangeEvent| {
            events_clone.lock().unwrap().push(serialize_event(e));
        }));

        svc.batch_events(|s| {
            s.set_setting("key1", "val1").unwrap();
        });

        // After batch_events, normal emit should work again.
        svc.set_setting("key2", "val2").unwrap();

        let collected = events.lock().unwrap();
        assert_eq!(collected.len(), 2); // BulkDataRefresh + SettingsUpdated
        assert!(collected[0].contains("BulkDataRefresh"));
        assert!(collected[1].contains("SettingsUpdated"));
    }
}
