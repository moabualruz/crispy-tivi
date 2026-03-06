use rusqlite::params;

use super::{CrispyService, bool_to_int, int_to_bool, opt_dt_to_ts, opt_ts_to_dt};
use crate::database::{DbError, TABLE_VOD_ITEMS};
use crate::events::DataChangeEvent;
use crate::models::VodItem;

impl CrispyService {
    // ── VOD Items ───────────────────────────────────

    /// Batch upsert VOD items. Returns count inserted.
    pub fn save_vod_items(&self, items: &[VodItem]) -> Result<usize, DbError> {
        let conn = self.db.get()?;
        let tx = conn.unchecked_transaction()?;
        let mut count = 0usize;
        for v in items {
            tx.execute(
                "INSERT OR REPLACE INTO db_vod_items (
                    id, name, stream_url, type,
                    poster_url, backdrop_url,
                    description, rating, year,
                    duration, category, series_id,
                    season_number, episode_number,
                    ext, is_favorite, added_at,
                    updated_at, source_id
                ) VALUES (
                    ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8,
                    ?9, ?10, ?11, ?12, ?13, ?14, ?15,
                    ?16, ?17, ?18, ?19
                )",
                params![
                    v.id,
                    v.name,
                    v.stream_url,
                    v.item_type,
                    v.poster_url,
                    v.backdrop_url,
                    v.description,
                    v.rating,
                    v.year,
                    v.duration,
                    v.category,
                    v.series_id,
                    v.season_number,
                    v.episode_number,
                    v.ext,
                    bool_to_int(v.is_favorite),
                    opt_dt_to_ts(&v.added_at),
                    opt_dt_to_ts(&v.updated_at),
                    v.source_id,
                ],
            )?;
            count += 1;
        }
        tx.commit()?;
        // Emit one event per distinct source_id so each
        // source's subscribers are notified independently.
        let mut seen = std::collections::HashSet::new();
        for v in items {
            let sid = v.source_id.clone().unwrap_or_default();
            if seen.insert(sid.clone()) {
                self.emit(DataChangeEvent::VodUpdated { source_id: sid });
            }
        }
        if items.is_empty() {
            // Preserve existing behaviour: always emit at least once.
            self.emit(DataChangeEvent::VodUpdated {
                source_id: String::new(),
            });
        }
        #[cfg(debug_assertions)]
        eprintln!("[debug] Inserted {} VOD items", count);
        Ok(count)
    }

    /// Load all VOD items.
    pub fn load_vod_items(&self) -> Result<Vec<VodItem>, DbError> {
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT
                id, name, stream_url, type,
                poster_url, backdrop_url,
                description, rating, year,
                duration, category, series_id,
                season_number, episode_number,
                ext, is_favorite, added_at,
                updated_at, source_id
            FROM db_vod_items",
        )?;
        let rows = stmt.query_map([], |row| {
            Ok(VodItem {
                id: row.get(0)?,
                name: row.get(1)?,
                stream_url: row.get(2)?,
                item_type: row.get(3)?,
                poster_url: row.get(4)?,
                backdrop_url: row.get(5)?,
                description: row.get(6)?,
                rating: row.get(7)?,
                year: row.get(8)?,
                duration: row.get(9)?,
                category: row.get(10)?,
                series_id: row.get(11)?,
                season_number: row.get(12)?,
                episode_number: row.get(13)?,
                ext: row.get(14)?,
                is_favorite: int_to_bool(row.get(15)?),
                added_at: opt_ts_to_dt(row.get(16)?),
                updated_at: opt_ts_to_dt(row.get(17)?),
                source_id: row.get(18)?,
            })
        })?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Load VOD items filtered by source IDs.
    ///
    /// If `source_ids` is empty, all VOD items are returned
    /// (same behaviour as `load_vod_items()`). Otherwise only
    /// items whose `source_id` is in the list are returned.
    pub fn get_vod_by_sources(&self, source_ids: &[String]) -> Result<Vec<VodItem>, DbError> {
        if source_ids.is_empty() {
            return self.load_vod_items();
        }
        let conn = self.db.get()?;
        let placeholders: Vec<String> = (1..=source_ids.len()).map(|i| format!("?{i}")).collect();
        let sql = format!(
            "SELECT
                id, name, stream_url, type,
                poster_url, backdrop_url,
                description, rating, year,
                duration, category, series_id,
                season_number, episode_number,
                ext, is_favorite, added_at,
                updated_at, source_id
            FROM db_vod_items
            WHERE source_id IN ({})",
            placeholders.join(", ")
        );
        let mut stmt = conn.prepare(&sql)?;
        let params: Vec<&dyn rusqlite::types::ToSql> = source_ids
            .iter()
            .map(|s| s as &dyn rusqlite::types::ToSql)
            .collect();
        let rows = stmt.query_map(params.as_slice(), |row| {
            Ok(VodItem {
                id: row.get(0)?,
                name: row.get(1)?,
                stream_url: row.get(2)?,
                item_type: row.get(3)?,
                poster_url: row.get(4)?,
                backdrop_url: row.get(5)?,
                description: row.get(6)?,
                rating: row.get(7)?,
                year: row.get(8)?,
                duration: row.get(9)?,
                category: row.get(10)?,
                series_id: row.get(11)?,
                season_number: row.get(12)?,
                episode_number: row.get(13)?,
                ext: row.get(14)?,
                is_favorite: int_to_bool(row.get(15)?),
                added_at: opt_ts_to_dt(row.get(16)?),
                updated_at: opt_ts_to_dt(row.get(17)?),
                source_id: row.get(18)?,
            })
        })?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Find VOD items from other sources with the same title and year.
    ///
    /// Uses case-insensitive exact name match (LOWER + TRIM) to avoid
    /// false positives. Results are ordered by source priority
    /// (lower `sort_order` = higher priority).
    pub fn find_vod_alternatives(
        &self,
        name: &str,
        year: Option<i32>,
        exclude_id: &str,
        limit: usize,
    ) -> Result<Vec<VodItem>, DbError> {
        let conn = self.db.get()?;
        let name_lower = name.to_lowercase().trim().to_string();
        let mut stmt = conn.prepare(
            "SELECT
                v.id, v.name, v.stream_url, v.type,
                v.poster_url, v.backdrop_url,
                v.description, v.rating, v.year,
                v.duration, v.category, v.series_id,
                v.season_number, v.episode_number,
                v.ext, v.is_favorite, v.added_at,
                v.updated_at, v.source_id
            FROM db_vod_items v
            LEFT JOIN db_sources s ON s.id = v.source_id
            WHERE LOWER(TRIM(v.name)) = ?1
              AND (?2 IS NULL OR v.year = ?2)
              AND v.id != ?3
            ORDER BY COALESCE(s.sort_order, 999), v.name
            LIMIT ?4",
        )?;
        let rows = stmt.query_map(params![name_lower, year, exclude_id, limit as i64], |row| {
            Ok(VodItem {
                id: row.get(0)?,
                name: row.get(1)?,
                stream_url: row.get(2)?,
                item_type: row.get(3)?,
                poster_url: row.get(4)?,
                backdrop_url: row.get(5)?,
                description: row.get(6)?,
                rating: row.get(7)?,
                year: row.get(8)?,
                duration: row.get(9)?,
                category: row.get(10)?,
                series_id: row.get(11)?,
                season_number: row.get(12)?,
                episode_number: row.get(13)?,
                ext: row.get(14)?,
                is_favorite: int_to_bool(row.get(15)?),
                added_at: opt_ts_to_dt(row.get(16)?),
                updated_at: opt_ts_to_dt(row.get(17)?),
                source_id: row.get(18)?,
            })
        })?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Delete VOD items from `source_id` not in
    /// `keep_ids`. Returns count deleted.
    pub fn delete_removed_vod_items(
        &self,
        source_id: &str,
        keep_ids: &[String],
    ) -> Result<usize, DbError> {
        let conn = self.db.get()?;
        let tx = conn.unchecked_transaction()?;
        let deleted = super::delete_removed_by_source(&tx, TABLE_VOD_ITEMS, source_id, keep_ids)?;
        tx.commit()?;
        self.emit(DataChangeEvent::VodUpdated {
            source_id: source_id.to_string(),
        });
        Ok(deleted)
    }

    // ── VOD Favorites ───────────────────────────────

    /// Get favourite VOD item IDs for a profile.
    pub fn get_vod_favorites(&self, profile_id: &str) -> Result<Vec<String>, DbError> {
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT vod_item_id
             FROM db_vod_favorites
             WHERE profile_id = ?1",
        )?;
        let rows = stmt.query_map(params![profile_id], |row| row.get(0))?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Add a VOD item to a profile's favourites.
    pub fn add_vod_favorite(&self, profile_id: &str, vod_item_id: &str) -> Result<(), DbError> {
        let conn = self.db.get()?;
        let now = chrono::Utc::now().timestamp();
        conn.execute(
            "INSERT OR REPLACE INTO db_vod_favorites
             (profile_id, vod_item_id, added_at)
             VALUES (?1, ?2, ?3)",
            params![profile_id, vod_item_id, now],
        )?;
        self.emit(DataChangeEvent::VodFavoriteToggled {
            vod_id: vod_item_id.to_string(),
            is_favorite: true,
        });
        Ok(())
    }

    /// Remove a VOD item from a profile's favourites.
    pub fn remove_vod_favorite(&self, profile_id: &str, vod_item_id: &str) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute(
            "DELETE FROM db_vod_favorites
             WHERE profile_id = ?1
             AND vod_item_id = ?2",
            params![profile_id, vod_item_id],
        )?;
        self.emit(DataChangeEvent::VodFavoriteToggled {
            vod_id: vod_item_id.to_string(),
            is_favorite: false,
        });
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use crate::services::test_helpers::*;

    #[test]
    fn save_and_load_vod_items() {
        let svc = make_service();
        let items = vec![
            make_vod_item("v1", "Movie 1"),
            make_vod_item("v2", "Movie 2"),
        ];
        let count = svc.save_vod_items(&items).unwrap();
        assert_eq!(count, 2);

        let loaded = svc.load_vod_items().unwrap();
        assert_eq!(loaded.len(), 2);
        assert!(loaded.iter().any(|v| v.id == "v1"));
        assert!(loaded.iter().any(|v| v.id == "v2"));
    }

    #[test]
    fn test_get_vod_by_sources_empty_returns_all() {
        let svc = make_service();
        let mut v1 = make_vod_item("v1", "Movie 1");
        v1.source_id = Some("src_a".to_string());
        let mut v2 = make_vod_item("v2", "Movie 2");
        v2.source_id = Some("src_b".to_string());
        svc.save_vod_items(&[v1, v2]).unwrap();

        // Empty slice => all items.
        let result = svc.get_vod_by_sources(&[]).unwrap();
        assert_eq!(result.len(), 2);
    }

    #[test]
    fn test_get_vod_by_sources_filters() {
        let svc = make_service();
        let mut v1 = make_vod_item("v1", "Movie 1");
        v1.source_id = Some("src_a".to_string());
        let mut v2 = make_vod_item("v2", "Movie 2");
        v2.source_id = Some("src_b".to_string());
        let mut v3 = make_vod_item("v3", "Movie 3");
        v3.source_id = Some("src_a".to_string());
        svc.save_vod_items(&[v1, v2, v3]).unwrap();

        let result = svc.get_vod_by_sources(&["src_a".to_string()]).unwrap();
        assert_eq!(result.len(), 2);
        let ids: Vec<&str> = result.iter().map(|v| v.id.as_str()).collect();
        assert!(ids.contains(&"v1"));
        assert!(ids.contains(&"v3"));
        assert!(!ids.contains(&"v2"));
    }

    #[test]
    fn vod_upsert_overwrites() {
        let svc = make_service();
        let mut v = make_vod_item("v1", "Original");
        svc.save_vod_items(&[v.clone()]).unwrap();

        v.name = "Updated".to_string();
        svc.save_vod_items(&[v]).unwrap();

        let loaded = svc.load_vod_items().unwrap();
        assert_eq!(loaded.len(), 1);
        assert_eq!(loaded[0].name, "Updated");
    }

    #[test]
    fn delete_removed_vod_items() {
        let svc = make_service();
        let items = vec![
            make_vod_item("v1", "Movie 1"),
            make_vod_item("v2", "Movie 2"),
            make_vod_item("v3", "Movie 3"),
        ];
        svc.save_vod_items(&items).unwrap();

        let deleted = svc
            .delete_removed_vod_items("src1", &["v1".to_string()])
            .unwrap();
        assert_eq!(deleted, 2);

        let remaining = svc.load_vod_items().unwrap();
        assert_eq!(remaining.len(), 1);
        assert_eq!(remaining[0].id, "v1");
    }

    #[test]
    fn vod_favorites_crud() {
        let svc = make_service();
        svc.save_profile(&make_profile("p1", "Alice")).unwrap();
        svc.save_vod_items(&[make_vod_item("v1", "Movie")]).unwrap();

        svc.add_vod_favorite("p1", "v1").unwrap();
        let favs = svc.get_vod_favorites("p1").unwrap();
        assert_eq!(favs, vec!["v1"]);

        svc.remove_vod_favorite("p1", "v1").unwrap();
        let favs = svc.get_vod_favorites("p1").unwrap();
        assert!(favs.is_empty());
    }

    #[test]
    fn emit_vod_favorite_toggled_on_add() {
        use crate::events::serialize_event;
        use std::sync::{Arc, Mutex};
        let svc = make_service();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        svc.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
        svc.save_profile(&make_profile("p1", "Alice")).unwrap();
        svc.save_vod_items(&[make_vod_item("v1", "Movie")]).unwrap();
        svc.add_vod_favorite("p1", "v1").unwrap();
        let recorded = log.lock().unwrap();
        let last = recorded.last().unwrap();
        assert!(last.contains("VodFavoriteToggled"), "{last}");
        assert!(last.contains("\"is_favorite\":true"), "{last}");
    }

    #[test]
    fn find_vod_alternatives_returns_matches() {
        let svc = make_service();
        let mut src_a = make_source("src_a", "Source A", "m3u");
        src_a.sort_order = 0;
        let mut src_b = make_source("src_b", "Source B", "m3u");
        src_b.sort_order = 1;
        svc.save_source(&src_a).unwrap();
        svc.save_source(&src_b).unwrap();

        let mut v1 = make_vod_item("v1", "Dune");
        v1.year = Some(2021);
        v1.source_id = Some("src_a".to_string());
        let mut v2 = make_vod_item("v2", "Dune");
        v2.year = Some(2021);
        v2.source_id = Some("src_b".to_string());
        svc.save_vod_items(&[v1, v2]).unwrap();

        let result = svc
            .find_vod_alternatives("Dune", Some(2021), "v1", 10)
            .unwrap();
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].id, "v2");
    }

    #[test]
    fn find_vod_alternatives_excludes_self() {
        let svc = make_service();
        let src = make_source("src_a", "Source A", "m3u");
        svc.save_source(&src).unwrap();

        let mut v1 = make_vod_item("v1", "Dune");
        v1.year = Some(2021);
        v1.source_id = Some("src_a".to_string());
        svc.save_vod_items(&[v1]).unwrap();

        let result = svc
            .find_vod_alternatives("Dune", Some(2021), "v1", 10)
            .unwrap();
        assert!(result.is_empty());
    }

    #[test]
    fn find_vod_alternatives_year_mismatch() {
        let svc = make_service();
        let mut src_a = make_source("src_a", "Source A", "m3u");
        src_a.sort_order = 0;
        let mut src_b = make_source("src_b", "Source B", "m3u");
        src_b.sort_order = 1;
        svc.save_source(&src_a).unwrap();
        svc.save_source(&src_b).unwrap();

        let mut v1 = make_vod_item("v1", "Dune");
        v1.year = Some(2021);
        v1.source_id = Some("src_a".to_string());
        let mut v2 = make_vod_item("v2", "Dune");
        v2.year = Some(2024);
        v2.source_id = Some("src_b".to_string());
        svc.save_vod_items(&[v1, v2]).unwrap();

        // Filtering by 2021 should not include the 2024 item.
        let result = svc
            .find_vod_alternatives("Dune", Some(2021), "v1", 10)
            .unwrap();
        assert!(result.is_empty(), "expected no results, got: {result:?}");
    }

    #[test]
    fn find_vod_alternatives_nil_year_matches_any() {
        let svc = make_service();
        let mut src_a = make_source("src_a", "Source A", "m3u");
        src_a.sort_order = 0;
        let mut src_b = make_source("src_b", "Source B", "m3u");
        src_b.sort_order = 1;
        let mut src_c = make_source("src_c", "Source C", "m3u");
        src_c.sort_order = 2;
        svc.save_source(&src_a).unwrap();
        svc.save_source(&src_b).unwrap();
        svc.save_source(&src_c).unwrap();

        let mut v1 = make_vod_item("v1", "Dune");
        v1.year = None;
        v1.source_id = Some("src_a".to_string());
        let mut v2 = make_vod_item("v2", "Dune");
        v2.year = Some(2021);
        v2.source_id = Some("src_b".to_string());
        let mut v3 = make_vod_item("v3", "Dune");
        v3.year = Some(2024);
        v3.source_id = Some("src_c".to_string());
        svc.save_vod_items(&[v1, v2, v3]).unwrap();

        // None year filter => all same-name items except v1 itself.
        let result = svc.find_vod_alternatives("Dune", None, "v1", 10).unwrap();
        assert_eq!(result.len(), 2);
        let ids: Vec<&str> = result.iter().map(|v| v.id.as_str()).collect();
        assert!(ids.contains(&"v2"));
        assert!(ids.contains(&"v3"));
    }

    #[test]
    fn find_vod_alternatives_ordered_by_priority() {
        let svc = make_service();
        let mut src_a = make_source("src_a", "Source A", "m3u");
        src_a.sort_order = 5;
        let mut src_b = make_source("src_b", "Source B", "m3u");
        src_b.sort_order = 0;
        let mut src_c = make_source("src_c", "Source C", "m3u");
        src_c.sort_order = 10;
        svc.save_source(&src_a).unwrap();
        svc.save_source(&src_b).unwrap();
        svc.save_source(&src_c).unwrap();

        let mut v1 = make_vod_item("v1", "Inception");
        v1.year = Some(2010);
        v1.source_id = Some("src_a".to_string());
        let mut v2 = make_vod_item("v2", "Inception");
        v2.year = Some(2010);
        v2.source_id = Some("src_b".to_string());
        let mut v3 = make_vod_item("v3", "Inception");
        v3.year = Some(2010);
        v3.source_id = Some("src_c".to_string());
        svc.save_vod_items(&[v1, v2, v3]).unwrap();

        // Exclude v1 (sort_order=5). Remaining: v2 (sort_order=0), v3 (sort_order=10).
        // Expected order: v2 first (sort_order=0), v3 last (sort_order=10).
        let result = svc
            .find_vod_alternatives("Inception", Some(2010), "v1", 10)
            .unwrap();
        assert_eq!(result.len(), 2);
        assert_eq!(result[0].id, "v2", "v2 (sort_order=0) should be first");
        assert_eq!(result[1].id, "v3", "v3 (sort_order=10) should be second");
    }

    #[test]
    fn save_vod_items_multi_source_emits_per_source() {
        use crate::events::serialize_event;
        use std::collections::HashSet;
        use std::sync::{Arc, Mutex};
        let svc = make_service();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        svc.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
        let mut v1 = make_vod_item("v1", "Movie 1");
        v1.source_id = Some("src_a".to_string());
        let mut v2 = make_vod_item("v2", "Movie 2");
        v2.source_id = Some("src_b".to_string());
        let mut v3 = make_vod_item("v3", "Movie 3");
        v3.source_id = Some("src_a".to_string());
        svc.save_vod_items(&[v1, v2, v3]).unwrap();
        let recorded = log.lock().unwrap();
        let sources: HashSet<String> = recorded
            .iter()
            .filter(|s| s.contains("VodUpdated"))
            .filter_map(|s| {
                let start = s.find("\"source_id\":\"")? + 13;
                let rest = &s[start..];
                let end = rest.find('"')?;
                Some(rest[..end].to_string())
            })
            .collect();
        assert!(sources.contains("src_a"), "{sources:?}");
        assert!(sources.contains("src_b"), "{sources:?}");
        assert_eq!(sources.len(), 2, "expected 2 distinct source events");
    }
}
