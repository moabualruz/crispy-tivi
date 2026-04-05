use rusqlite::{Row, params};

use super::{
    CrispyService, bool_to_int, build_in_placeholders, int_to_bool, opt_dt_to_ts, opt_ts_to_dt,
    str_params,
};
use crate::database::{DbError, TABLE_MOVIES};
use crate::events::DataChangeEvent;
use crate::models::VodItem;

/// SELECT column list for `db_movies` mapped to VodItem fields (26 columns).
///
/// This provides backward compatibility: the old VodItem-based API
/// reads from the new `db_movies` table. Fields that don't exist in
/// db_movies (series_id, season_number, episode_number) are returned as NULL.
pub(crate) const VOD_COLUMNS: &str = "id, name, stream_url, \
     'movie' AS type, \
     poster_url, backdrop_url, \
     description, rating, year, \
     duration_minutes, genre, NULL AS series_id, \
     NULL AS season_number, NULL AS episode_number, \
     container_ext, 0 AS is_favorite, added_at, \
     updated_at, source_id, \
     cast_names, director, genre, \
     youtube_trailer, tmdb_id, rating_5based, \
     original_name, is_adult, content_rating";

/// Same as `VOD_COLUMNS` but qualified with table alias `v.` for JOIN queries.
pub(crate) const VOD_COLUMNS_V: &str = "v.id, v.name, v.stream_url, \
     'movie' AS type, \
     v.poster_url, v.backdrop_url, \
     v.description, v.rating, v.year, \
     v.duration_minutes, v.genre, NULL AS series_id, \
     NULL AS season_number, NULL AS episode_number, \
     v.container_ext, 0 AS is_favorite, v.added_at, \
     v.updated_at, v.source_id, \
     v.cast_names, v.director, v.genre, \
     v.youtube_trailer, v.tmdb_id, v.rating_5based, \
     v.original_name, v.is_adult, v.content_rating";

/// Map a single SQLite row to a `VodItem` (backward compat).
pub(crate) fn vod_item_from_row(row: &Row) -> rusqlite::Result<VodItem> {
    Ok(VodItem {
        id: row.get(0)?,
        name: row.get(1)?,
        stream_url: row.get::<_, Option<String>>(2)?.unwrap_or_default(),
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
        cast: row.get(19)?,
        director: row.get(20)?,
        genre: row.get(21)?,
        youtube_trailer: row.get(22)?,
        tmdb_id: row.get(23)?,
        rating_5based: row.get(24)?,
        original_name: row.get(25)?,
        is_adult: int_to_bool(row.get(26)?),
        content_rating: row.get(27)?,
    })
}

impl CrispyService {
    // ── VOD Items (backward compat — writes to db_movies) ──

    /// Batch upsert VOD items using a caller-supplied connection.
    ///
    /// Intended for use inside a shared outer transaction (e.g. `save_sync_data`).
    /// The caller owns the transaction boundary; this method does not commit.
    pub(super) fn save_vod_items_inner(
        conn: &rusqlite::Connection,
        items: &[VodItem],
    ) -> Result<usize, DbError> {
        let mut count = 0usize;
        for v in items {
            let source_id = v.source_id.clone().unwrap_or_default();
            conn.execute(
                "INSERT INTO db_movies (
                    id, source_id, native_id, name,
                    original_name, poster_url, backdrop_url,
                    description, stream_url, container_ext,
                    year, duration_minutes,
                    rating, rating_5based, content_rating,
                    genre, youtube_trailer, tmdb_id,
                    cast_names, director,
                    is_adult, added_at, updated_at
                ) VALUES (
                    ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8,
                    ?9, ?10, ?11, ?12, ?13, ?14, ?15,
                    ?16, ?17, ?18, ?19, ?20, ?21, ?22, ?23
                )
                ON CONFLICT (source_id, native_id) DO UPDATE SET
                    name = excluded.name,
                    original_name = excluded.original_name,
                    poster_url = excluded.poster_url,
                    backdrop_url = excluded.backdrop_url,
                    description = excluded.description,
                    stream_url = excluded.stream_url,
                    container_ext = excluded.container_ext,
                    year = excluded.year,
                    duration_minutes = excluded.duration_minutes,
                    rating = excluded.rating,
                    rating_5based = excluded.rating_5based,
                    content_rating = excluded.content_rating,
                    genre = excluded.genre,
                    youtube_trailer = excluded.youtube_trailer,
                    tmdb_id = excluded.tmdb_id,
                    cast_names = excluded.cast_names,
                    director = excluded.director,
                    is_adult = excluded.is_adult,
                    updated_at = excluded.updated_at",
                params![
                    v.id,
                    source_id,
                    v.id, // native_id = id for legacy items
                    v.name,
                    v.original_name,
                    v.poster_url,
                    v.backdrop_url,
                    v.description,
                    v.stream_url,
                    v.ext,
                    v.year,
                    v.duration,
                    v.rating,
                    v.rating_5based,
                    v.content_rating,
                    v.genre,
                    v.youtube_trailer,
                    v.tmdb_id,
                    v.cast,
                    v.director,
                    bool_to_int(v.is_adult),
                    opt_dt_to_ts(&v.added_at),
                    opt_dt_to_ts(&v.updated_at),
                ],
            )?;
            count += 1;
        }
        #[cfg(debug_assertions)]
        eprintln!("[debug] Inserted {} VOD items", count);
        Ok(count)
    }

    /// Delete VOD items not in `keep_ids` using a caller-supplied connection.
    ///
    /// Intended for use inside a shared outer transaction. Does not commit.
    pub(super) fn delete_removed_vod_items_inner(
        conn: &rusqlite::Connection,
        source_id: &str,
        keep_ids: &[String],
    ) -> Result<usize, DbError> {
        super::delete_removed_by_source_conn(conn, TABLE_MOVIES, source_id, keep_ids)
    }

    /// Batch upsert VOD items into db_movies. Returns count inserted.
    ///
    /// This is a backward-compatibility shim: parsers still produce
    /// VodItem structs which are mapped to db_movies rows.
    pub fn save_vod_items(&self, items: &[VodItem]) -> Result<usize, DbError> {
        let conn = self.db.get()?;
        let tx = conn.unchecked_transaction()?;
        let count = Self::save_vod_items_inner(&tx, items)?;
        tx.commit()?;
        self.emit_per_source(
            items,
            |v| v.source_id.as_deref(),
            |sid| DataChangeEvent::VodUpdated { source_id: sid },
        );
        Ok(count)
    }

    /// Load all VOD items (from db_movies).
    pub fn load_vod_items(&self) -> Result<Vec<VodItem>, DbError> {
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(&format!("SELECT {VOD_COLUMNS} FROM db_movies",))?;
        let rows = stmt.query_map([], vod_item_from_row)?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Load VOD items filtered by source IDs.
    pub fn get_vod_by_sources(&self, source_ids: &[String]) -> Result<Vec<VodItem>, DbError> {
        if source_ids.is_empty() {
            return self.load_vod_items();
        }
        let conn = self.db.get()?;
        let sql = format!(
            "SELECT {VOD_COLUMNS} FROM db_movies WHERE source_id IN ({})",
            build_in_placeholders(source_ids.len())
        );
        let mut stmt = conn.prepare(&sql)?;
        let params = str_params(source_ids);
        let rows = stmt.query_map(params.as_slice(), vod_item_from_row)?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Load VOD items filtered by multiple criteria and sorted.
    pub fn get_filtered_vod(
        &self,
        source_ids: &[String],
        item_type: Option<&str>,
        category: Option<&str>,
        query: Option<&str>,
        sort_by: &str,
    ) -> Result<Vec<VodItem>, DbError> {
        let conn = self.db.get()?;
        let mut sql = format!("SELECT {VOD_COLUMNS} FROM db_movies WHERE 1=1",);

        let mut params: Vec<Box<dyn rusqlite::types::ToSql>> = vec![];
        let mut param_idx = 1;

        // item_type filter is ignored for db_movies (all are movies).
        let _ = item_type;

        if !source_ids.is_empty() {
            let placeholders = build_in_placeholders(source_ids.len());
            sql.push_str(&format!(" AND source_id IN ({})", placeholders));
            for id in source_ids {
                params.push(Box::new(id.to_string()));
            }
            param_idx += source_ids.len();
        }

        if let Some(cat) = category {
            sql.push_str(&format!(" AND genre = ?{}", param_idx));
            params.push(Box::new(cat.to_string()));
            param_idx += 1;
        }

        if let Some(q) = query
            && !q.trim().is_empty()
        {
            let lower = format!("%{}%", q.to_lowercase().trim());
            sql.push_str(&format!(" AND LOWER(name) LIKE ?{}", param_idx));
            params.push(Box::new(lower));
            // param_idx += 1;
        }

        let _ = param_idx;
        let mut stmt = conn.prepare(&sql)?;
        let refs: Vec<&dyn rusqlite::types::ToSql> = params.iter().map(|b| b.as_ref()).collect();
        let rows = stmt.query_map(refs.as_slice(), vod_item_from_row)?;
        let mut items = rows.collect::<Result<Vec<_>, _>>()?;

        crate::algorithms::vod_sorting::sort_vod_items_vec(&mut items, sort_by);
        Ok(items)
    }

    /// Find VOD items from other sources with the same title and year.
    pub fn find_vod_alternatives(
        &self,
        name: &str,
        year: Option<i32>,
        exclude_id: &str,
        limit: usize,
    ) -> Result<Vec<VodItem>, DbError> {
        let conn = self.db.get()?;
        let name_lower = name.to_lowercase().trim().to_string();
        let mut stmt = conn.prepare(&format!(
            "SELECT {VOD_COLUMNS_V}
             FROM db_movies v
             LEFT JOIN db_sources s ON s.id = v.source_id
             WHERE LOWER(TRIM(v.name)) = ?1
               AND (?2 IS NULL OR v.year = ?2)
               AND v.id != ?3
             ORDER BY COALESCE(s.sort_order, 999), v.name
             LIMIT ?4",
        ))?;
        let rows = stmt.query_map(
            params![name_lower, year, exclude_id, limit as i64],
            vod_item_from_row,
        )?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Delete VOD items from `source_id` not in `keep_ids`. Returns count deleted.
    pub fn delete_removed_vod_items(
        &self,
        source_id: &str,
        keep_ids: &[String],
    ) -> Result<usize, DbError> {
        let conn = self.db.get()?;
        let tx = conn.unchecked_transaction()?;
        let deleted = Self::delete_removed_vod_items_inner(&tx, source_id, keep_ids)?;
        tx.commit()?;
        self.emit(DataChangeEvent::VodUpdated {
            source_id: source_id.to_string(),
        });
        Ok(deleted)
    }

    // ── VOD Favorites ───────────────────────────────

    /// Get favourite VOD content IDs for a profile.
    pub fn get_vod_favorites(&self, profile_id: &str) -> Result<Vec<String>, DbError> {
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT content_id
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
             (profile_id, content_id, content_type, added_at)
             VALUES (?1, ?2, 'movie', ?3)",
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
             AND content_id = ?2",
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
        let src = make_source("src1", "S1", "m3u");
        svc.save_source(&src).unwrap();
        let mut v1 = make_vod_item("v1", "Movie 1");
        v1.source_id = Some("src1".to_string());
        let mut v2 = make_vod_item("v2", "Movie 2");
        v2.source_id = Some("src1".to_string());
        let count = svc.save_vod_items(&[v1, v2]).unwrap();
        assert_eq!(count, 2);

        let loaded = svc.load_vod_items().unwrap();
        assert_eq!(loaded.len(), 2);
        assert!(loaded.iter().any(|v| v.id == "v1"));
        assert!(loaded.iter().any(|v| v.id == "v2"));
    }

    #[test]
    fn test_get_vod_by_sources_empty_returns_all() {
        let svc = make_service_with_fixtures();
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
        let svc = make_service_with_fixtures();
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
        let src = make_source("src1", "S1", "m3u");
        svc.save_source(&src).unwrap();
        let mut v = make_vod_item("v1", "Original");
        v.source_id = Some("src1".to_string());
        svc.save_vod_items(&[v.clone()]).unwrap();

        v.name = "Updated".to_string();
        svc.save_vod_items(&[v]).unwrap();

        let loaded = svc.load_vod_items().unwrap();
        assert_eq!(loaded.len(), 1);
        assert_eq!(loaded[0].name, "Updated");
    }

    #[test]
    fn delete_removed_vod_items() {
        let svc = make_service_with_fixtures();
        let mut v1 = make_vod_item("v1", "Movie 1");
        v1.source_id = Some("src1".to_string());
        let mut v2 = make_vod_item("v2", "Movie 2");
        v2.source_id = Some("src1".to_string());
        let mut v3 = make_vod_item("v3", "Movie 3");
        v3.source_id = Some("src1".to_string());
        svc.save_vod_items(&[v1, v2, v3]).unwrap();

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
        let src = make_source("src1", "S1", "m3u");
        svc.save_source(&src).unwrap();
        let mut v = make_vod_item("v1", "Movie");
        v.source_id = Some("src1".to_string());
        svc.save_vod_items(&[v]).unwrap();

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
        let src = make_source("src1", "S1", "m3u");
        svc.save_source(&src).unwrap();
        let mut v = make_vod_item("v1", "Movie");
        v.source_id = Some("src1".to_string());
        svc.save_vod_items(&[v]).unwrap();
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
        let svc = make_service_with_fixtures();
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
