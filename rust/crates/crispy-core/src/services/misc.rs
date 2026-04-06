use rusqlite::{Row, params};

use super::{ServiceContext, dt_to_ts, ts_to_dt};
use crate::database::DbError;
use crate::events::DataChangeEvent;
use crate::models::{SavedLayout, SearchHistory};
use crate::insert_or_replace;

fn saved_layout_from_row(row: &Row) -> rusqlite::Result<SavedLayout> {
    Ok(SavedLayout {
        id: row.get(0)?,
        name: row.get(1)?,
        layout: row
            .get::<_, String>(2)?
            .as_str()
            .try_into()
            .unwrap_or_default(),
        streams: row.get(3)?,
        created_at: ts_to_dt(row.get(4)?),
    })
}

fn search_history_from_row(row: &Row) -> rusqlite::Result<SearchHistory> {
    Ok(SearchHistory {
        id: row.get(0)?,
        query: row.get(1)?,
        searched_at: ts_to_dt(row.get(2)?),
        result_count: row.get(3)?,
    })
}

/// Domain service for miscellaneous operations.
pub struct MiscService(pub ServiceContext);

impl MiscService {
    // ── Saved Layouts ─────────────────────────────────

    /// Load all saved layouts ordered by created_at
    /// descending.
    pub fn load_saved_layouts(&self) -> Result<Vec<SavedLayout>, DbError> {
        let conn = self.0.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT
                id, name, layout, streams,
                created_at
            FROM db_saved_layouts
            ORDER BY created_at DESC",
        )?;
        let rows = stmt.query_map([], saved_layout_from_row)?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Save (upsert) a layout.
    pub fn save_saved_layout(&self, layout: &SavedLayout) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        insert_or_replace!(
            conn,
            "db_saved_layouts",
            ["id", "name", "layout", "streams", "created_at"],
            params![
                layout.id,
                layout.name,
                layout.layout.as_str(),
                layout.streams,
                dt_to_ts(&layout.created_at),
            ],
        )?;
        self.0.emit(DataChangeEvent::SavedLayoutChanged);
        Ok(())
    }

    /// Delete a saved layout by ID.
    pub fn delete_saved_layout(&self, id: &str) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        conn.execute(
            "DELETE FROM db_saved_layouts
             WHERE id = ?1",
            params![id],
        )?;
        self.0.emit(DataChangeEvent::SavedLayoutChanged);
        Ok(())
    }

    /// Get a saved layout by ID (direct query).
    pub fn get_saved_layout_by_id(&self, id: &str) -> Result<Option<SavedLayout>, DbError> {
        let conn = self.0.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT id, name, layout, streams,
                    created_at
             FROM db_saved_layouts
             WHERE id = ?1",
        )?;
        let mut rows = stmt.query_map(params![id], saved_layout_from_row)?;
        match rows.next() {
            Some(r) => Ok(Some(r?)),
            None => Ok(None),
        }
    }

    // ── Search History ────────────────────────────────

    /// Load all search history ordered by searched_at
    /// descending.
    pub fn load_search_history(&self) -> Result<Vec<SearchHistory>, DbError> {
        let conn = self.0.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT
                id, query, searched_at,
                result_count
            FROM db_search_history
            ORDER BY searched_at DESC",
        )?;
        let rows = stmt.query_map([], search_history_from_row)?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Save a search entry, deduplicating by query
    /// text. Deletes any existing entry with the same
    /// query before inserting.
    pub fn save_search_entry(&self, entry: &SearchHistory) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        let tx = conn.unchecked_transaction()?;
        tx.execute(
            "DELETE FROM db_search_history
             WHERE query = ?1",
            params![entry.query],
        )?;
        tx.execute(
            "INSERT INTO db_search_history (
                id, query, searched_at,
                result_count
            ) VALUES (?1, ?2, ?3, ?4)",
            params![
                entry.id,
                entry.query,
                dt_to_ts(&entry.searched_at),
                entry.result_count,
            ],
        )?;
        tx.commit()?;
        self.0.emit(DataChangeEvent::SearchHistoryChanged);
        Ok(())
    }

    /// Delete a search history entry by ID.
    pub fn delete_search_entry(&self, id: &str) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        conn.execute(
            "DELETE FROM db_search_history
             WHERE id = ?1",
            params![id],
        )?;
        self.0.emit(DataChangeEvent::SearchHistoryChanged);
        Ok(())
    }

    /// Delete all search history entries.
    pub fn clear_search_history(&self) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        conn.execute("DELETE FROM db_search_history", [])?;
        self.0.emit(DataChangeEvent::SearchHistoryChanged);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use crate::services::test_helpers::*;
    use super::MiscService;

    fn make_saved_layout(id: &str, name: &str) -> crate::models::SavedLayout {
        crate::models::SavedLayout {
            id: id.to_string(),
            name: name.to_string(),
            layout: crate::value_objects::LayoutType::Grid2x2,
            streams: r#"["url1","url2"]"#.to_string(),
            created_at: parse_dt("2025-01-15 12:00:00"),
        }
    }

    fn make_search_entry(id: &str, query: &str) -> crate::models::SearchHistory {
        crate::models::SearchHistory {
            id: id.to_string(),
            query: query.to_string(),
            searched_at: parse_dt("2025-01-15 12:00:00"),
            result_count: 42,
        }
    }

    // ── Saved Layouts ────────────────────────────────

    #[test]
    fn saved_layouts_crud() {
        let svc = MiscService(make_service());

        let layouts = svc.load_saved_layouts().unwrap();
        assert!(layouts.is_empty());

        svc.save_saved_layout(&make_saved_layout("l1", "Layout 1"))
            .unwrap();
        svc.save_saved_layout(&make_saved_layout("l2", "Layout 2"))
            .unwrap();

        let layouts = svc.load_saved_layouts().unwrap();
        assert_eq!(layouts.len(), 2);

        svc.delete_saved_layout("l1").unwrap();
        let layouts = svc.load_saved_layouts().unwrap();
        assert_eq!(layouts.len(), 1);
        assert_eq!(layouts[0].id, "l2");
    }

    #[test]
    fn saved_layout_upsert() {
        let svc = MiscService(make_service());
        let mut layout = make_saved_layout("l1", "Original");
        svc.save_saved_layout(&layout).unwrap();

        layout.name = "Updated".to_string();
        svc.save_saved_layout(&layout).unwrap();

        let layouts = svc.load_saved_layouts().unwrap();
        assert_eq!(layouts.len(), 1);
        assert_eq!(layouts[0].name, "Updated");
    }

    #[test]
    fn get_saved_layout_by_id_found() {
        let svc = MiscService(make_service());
        let layout = make_saved_layout("l1", "Layout 1");
        svc.save_saved_layout(&layout).unwrap();

        let found = svc.get_saved_layout_by_id("l1").unwrap();
        assert!(found.is_some());
        let found = found.unwrap();
        assert_eq!(found.id, "l1");
        assert_eq!(found.name, "Layout 1");
        assert_eq!(found.layout, crate::value_objects::LayoutType::Grid2x2);
        assert_eq!(found.streams, r#"["url1","url2"]"#,);
    }

    #[test]
    fn get_saved_layout_by_id_not_found() {
        let svc = MiscService(make_service());
        let found = svc.get_saved_layout_by_id("nonexistent").unwrap();
        assert!(found.is_none());
    }

    #[test]
    fn emit_saved_layout_changed_on_save() {
        use crate::events::serialize_event;
        use std::sync::{Arc, Mutex};
        let svc = MiscService(make_service());
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        svc.0.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
        svc.save_saved_layout(&make_saved_layout("l1", "Layout 1"))
            .unwrap();
        let recorded = log.lock().unwrap();
        let last = recorded.last().unwrap();
        assert!(last.contains("SavedLayoutChanged"), "{last}");
    }

    // ── Search History ───────────────────────────────

    #[test]
    fn search_history_crud() {
        let svc = MiscService(make_service());

        let history = svc.load_search_history().unwrap();
        assert!(history.is_empty());

        svc.save_search_entry(&make_search_entry("s1", "news"))
            .unwrap();
        svc.save_search_entry(&make_search_entry("s2", "sports"))
            .unwrap();

        let history = svc.load_search_history().unwrap();
        assert_eq!(history.len(), 2);

        svc.delete_search_entry("s1").unwrap();
        let history = svc.load_search_history().unwrap();
        assert_eq!(history.len(), 1);
        assert_eq!(history[0].id, "s2");
    }

    #[test]
    fn search_history_dedup_by_query() {
        let svc = MiscService(make_service());

        svc.save_search_entry(&make_search_entry("s1", "news"))
            .unwrap();
        svc.save_search_entry(&make_search_entry("s2", "news"))
            .unwrap();

        let history = svc.load_search_history().unwrap();
        assert_eq!(history.len(), 1);
        assert_eq!(history[0].id, "s2");
    }

    #[test]
    fn search_history_clear() {
        let svc = MiscService(make_service());
        svc.save_search_entry(&make_search_entry("s1", "a"))
            .unwrap();
        svc.save_search_entry(&make_search_entry("s2", "b"))
            .unwrap();

        svc.clear_search_history().unwrap();
        let history = svc.load_search_history().unwrap();
        assert!(history.is_empty());
    }

    #[test]
    fn emit_search_history_changed_on_save() {
        use crate::events::serialize_event;
        use std::sync::{Arc, Mutex};
        let svc = MiscService(make_service());
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        svc.0.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
        svc.save_search_entry(&make_search_entry("s1", "news"))
            .unwrap();
        let recorded = log.lock().unwrap();
        let last = recorded.last().unwrap();
        assert!(last.contains("SearchHistoryChanged"), "{last}");
    }
}
