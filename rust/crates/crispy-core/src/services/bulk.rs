use rusqlite::params;

use super::{CrispyService, bool_to_int};
use crate::database::{DbError, TABLE_CHANNELS, TABLE_EPG_ENTRIES, TABLE_VOD_ITEMS};
use crate::events::DataChangeEvent;

impl CrispyService {
    // ── Targeted Updates (N+1 eliminators) ──────────

    /// Update the `is_favorite` flag on a single VOD
    /// item. Returns `DbError::NotFound` if the item
    /// does not exist.
    pub fn update_vod_favorite(&self, item_id: &str, is_favorite: bool) -> Result<(), DbError> {
        let conn = self.db.get()?;
        let affected = conn.execute(
            &format!(
                "UPDATE {TABLE_VOD_ITEMS}
                 SET is_favorite = ?2
                 WHERE id = ?1"
            ),
            params![item_id, bool_to_int(is_favorite)],
        )?;
        if affected == 0 {
            return Err(DbError::NotFound);
        }
        self.emit(DataChangeEvent::VodFavoriteToggled {
            vod_id: item_id.to_string(),
            is_favorite,
        });
        Ok(())
    }

    /// Get profile IDs that have access to a source.
    /// Single JOIN query — no N+1.
    pub fn get_profiles_for_source(&self, source_id: &str) -> Result<Vec<String>, DbError> {
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT DISTINCT p.id
             FROM db_profiles p
             INNER JOIN db_profile_source_access sa
                 ON p.id = sa.profile_id
             WHERE sa.source_id = ?1",
        )?;
        let rows = stmt.query_map(params![source_id], |row| row.get(0))?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Delete search history entries whose query
    /// matches (case-insensitive, trimmed). Returns
    /// count of deleted rows.
    pub fn delete_search_by_query(&self, query: &str) -> Result<usize, DbError> {
        let conn = self.db.get()?;
        let deleted = conn.execute(
            "DELETE FROM db_search_history
             WHERE LOWER(TRIM(query))
                 = LOWER(TRIM(?1))",
            params![query],
        )?;
        self.emit(DataChangeEvent::SearchHistoryChanged);
        Ok(deleted)
    }

    /// Delete all watch history entries. Returns count
    /// of deleted rows.
    pub fn clear_all_watch_history(&self) -> Result<usize, DbError> {
        let conn = self.db.get()?;
        let deleted = conn.execute("DELETE FROM db_watch_history", [])?;
        self.emit(DataChangeEvent::WatchHistoryCleared);
        Ok(deleted)
    }

    // ── Bulk ────────────────────────────────────────

    /// Delete all data from all tables.
    pub fn clear_all(&self) -> Result<(), DbError> {
        let conn = self.db.get()?;
        let tx = conn.unchecked_transaction()?;
        // Order matters for FK constraints: children
        // first.
        tx.execute("DELETE FROM db_user_favorites", [])?;
        tx.execute("DELETE FROM db_vod_favorites", [])?;
        tx.execute("DELETE FROM db_favorite_categories", [])?;
        tx.execute("DELETE FROM db_profile_source_access", [])?;
        tx.execute("DELETE FROM db_channel_order", [])?;
        tx.execute("DELETE FROM db_transfer_tasks", [])?;
        tx.execute("DELETE FROM db_recordings", [])?;
        tx.execute("DELETE FROM db_storage_backends", [])?;
        tx.execute("DELETE FROM db_watch_history", [])?;
        tx.execute(&format!("DELETE FROM {TABLE_EPG_ENTRIES}"), [])?;
        tx.execute("DELETE FROM db_reminders", [])?;
        tx.execute("DELETE FROM db_search_history", [])?;
        tx.execute("DELETE FROM db_saved_layouts", [])?;
        tx.execute("DELETE FROM db_sync_meta", [])?;
        tx.execute("DELETE FROM db_settings", [])?;
        tx.execute("DELETE FROM db_categories", [])?;
        tx.execute(&format!("DELETE FROM {TABLE_VOD_ITEMS}"), [])?;
        tx.execute(&format!("DELETE FROM {TABLE_CHANNELS}"), [])?;
        tx.execute("DELETE FROM db_profiles", [])?;
        tx.commit()?;
        self.emit(DataChangeEvent::BulkDataRefresh);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use crate::database::DbError;
    use crate::services::test_helpers::*;

    #[test]
    fn update_vod_favorite_sets_flag() {
        let svc = make_service();
        let item = make_vod_item("v1", "Movie 1");
        svc.save_vod_items(&[item]).unwrap();

        let items = svc.load_vod_items().unwrap();
        assert!(!items[0].is_favorite);

        svc.update_vod_favorite("v1", true).unwrap();
        let items = svc.load_vod_items().unwrap();
        assert!(items[0].is_favorite);

        svc.update_vod_favorite("v1", false).unwrap();
        let items = svc.load_vod_items().unwrap();
        assert!(!items[0].is_favorite);
    }

    #[test]
    fn update_vod_favorite_not_found() {
        let svc = make_service();
        let result = svc.update_vod_favorite("missing", true);
        assert!(matches!(result, Err(DbError::NotFound)));
    }

    #[test]
    fn delete_search_by_query_case_insensitive() {
        let svc = make_service();
        use crate::models::SearchHistory;
        svc.save_search_entry(&SearchHistory {
            id: "s1".to_string(),
            query: "News".to_string(),
            searched_at: parse_dt("2025-01-15 12:00:00"),
            result_count: 1,
        })
        .unwrap();
        svc.save_search_entry(&SearchHistory {
            id: "s2".to_string(),
            query: "sports".to_string(),
            searched_at: parse_dt("2025-01-15 12:00:00"),
            result_count: 1,
        })
        .unwrap();

        let deleted = svc.delete_search_by_query("  news  ").unwrap();
        assert_eq!(deleted, 1);

        let history = svc.load_search_history().unwrap();
        assert_eq!(history.len(), 1);
        assert_eq!(history[0].query, "sports");
    }

    #[test]
    fn clear_all_watch_history_returns_count() {
        let svc = make_service();
        svc.save_watch_history(&make_watch_entry("w1", "Movie 1"))
            .unwrap();
        svc.save_watch_history(&make_watch_entry("w2", "Movie 2"))
            .unwrap();
        svc.save_watch_history(&make_watch_entry("w3", "Movie 3"))
            .unwrap();

        let deleted = svc.clear_all_watch_history().unwrap();
        assert_eq!(deleted, 3);
        assert!(svc.load_watch_history().unwrap().is_empty());
    }

    #[test]
    fn clear_all_watch_history_empty_table() {
        let svc = make_service();
        let deleted = svc.clear_all_watch_history().unwrap();
        assert_eq!(deleted, 0);
    }

    #[test]
    fn clear_all_empties_everything() {
        let svc = make_service();
        svc.save_channels(&[make_channel("ch1", "A")]).unwrap();
        svc.set_setting("k", "v").unwrap();

        svc.clear_all().unwrap();

        assert!(svc.load_channels().unwrap().is_empty());
        assert_eq!(svc.get_setting("k").unwrap(), None,);
    }

    #[test]
    fn emit_bulk_data_refresh_on_clear_all() {
        use crate::events::serialize_event;
        use std::sync::{Arc, Mutex};
        let svc = make_service();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        svc.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
        svc.clear_all().unwrap();
        let recorded = log.lock().unwrap();
        let last = recorded.last().unwrap();
        assert!(last.contains("BulkDataRefresh"), "{last}");
    }
}
