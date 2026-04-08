use rusqlite::{Row, params};

use super::{
    ServiceContext, bool_to_int, build_in_placeholders, build_in_placeholders_from, opt_dt_to_ts,
    str_params,
};
use crate::database::row_helpers::RowExt;
use crate::database::{DbError, TABLE_MOVIES};
use crate::errors::DomainError;
use crate::events::DataChangeEvent;
use crate::insert_or_replace;
use crate::models::VodItem;
use crate::models::columns::{VOD_COLUMNS, VOD_COLUMNS_V};
use crate::traits::VodRepository;

/// Domain service for VOD operations.
pub struct VodService(pub ServiceContext);

fn resolved_native_id(item: &VodItem) -> String {
    let native_id = item.native_id.trim();
    if !native_id.is_empty() {
        return native_id.to_string();
    }

    let mut fallback = format!("fallback:{}:", item.item_type.as_str());
    if !item.stream_url.trim().is_empty() {
        fallback.push_str("stream:");
        fallback.push_str(item.stream_url.trim());
        return fallback;
    }

    if let Some(series_id) = item.series_id.as_deref()
        && !series_id.trim().is_empty()
    {
        fallback.push_str("series:");
        fallback.push_str(series_id.trim());
        fallback.push(':');
        fallback.push_str(&item.season_number.unwrap_or_default().to_string());
        fallback.push(':');
        fallback.push_str(&item.episode_number.unwrap_or_default().to_string());
        return fallback;
    }

    if !item.name.trim().is_empty() {
        fallback.push_str("name:");
        fallback.push_str(item.name.trim());
        if let Some(year) = item.year {
            fallback.push(':');
            fallback.push_str(&year.to_string());
        }
        return fallback;
    }

    fallback.push_str("id:");
    fallback.push_str(item.id.trim());
    fallback
}

/// Map a single SQLite row to a `VodItem` (backward compat).
pub(crate) fn vod_item_from_row(row: &Row) -> rusqlite::Result<VodItem> {
    Ok(VodItem {
        id: row.get(0)?,
        name: row.get(1)?,
        stream_url: row.get::<_, Option<String>>(2)?.unwrap_or_default(),
        item_type: row
            .get::<_, String>(3)
            .map(|s| s.as_str().try_into().unwrap_or_default())
            .unwrap_or_default(),
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
        is_favorite: row.get_bool(15)?,
        added_at: row.get_datetime(16)?,
        updated_at: row.get_datetime(17)?,
        source_id: row.get(18)?,
        cast: row.get(19)?,
        director: row.get(20)?,
        genre: row.get(21)?,
        youtube_trailer: row.get(22)?,
        tmdb_id: row.get(23)?,
        rating_5based: row.get(24)?,
        original_name: row.get(25)?,
        is_adult: row.get_bool(26)?,
        content_rating: row.get(27)?,
        native_id: row.get::<_, Option<String>>(28)?.unwrap_or_default(),
    })
}

impl VodService {
    // ── VOD Items (backward compat — writes to db_movies) ──

    /// Batch upsert VOD items using a caller-supplied connection.
    ///
    /// Intended for use inside a shared outer transaction (e.g. `save_sync_data`).
    /// The caller owns the transaction boundary; this method does not commit.
    pub(super) fn save_vod_items_inner(
        conn: &rusqlite::Connection,
        items: &[VodItem],
    ) -> Result<usize, DbError> {
        let mut stmt = conn.prepare(
            "INSERT INTO db_movies (
                    id, source_id, native_id, name,
                    original_name, poster_url, backdrop_url,
                    description, stream_url, container_ext,
                    year, duration_minutes,
                    rating, rating_5based, content_rating,
                    genre, youtube_trailer, tmdb_id,
                    cast_names, director,
                    is_adult, added_at, updated_at, vod_type
                ) VALUES (
                    ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8,
                    ?9, ?10, ?11, ?12, ?13, ?14, ?15,
                    ?16, ?17, ?18, ?19, ?20, ?21,
                    COALESCE(?22, strftime('%s','now')),
                    COALESCE(?23, strftime('%s','now')),
                    ?24
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
                    vod_type = excluded.vod_type,
                    updated_at = strftime('%s','now')",
        )?;
        let mut count = 0usize;
        for v in items {
            let source_id = v.source_id.clone().unwrap_or_default();
            let native_id = resolved_native_id(v);
            stmt.execute(params![
                v.id,
                source_id,
                native_id,
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
                v.item_type.as_str(),
            ])?;
            count += 1;
        }
        #[cfg(debug_assertions)]
        eprintln!("[debug] Inserted {} VOD items", count);
        Ok(count)
    }

    /// Batch upsert VOD items into db_movies. Returns count inserted.
    ///
    /// This is a backward-compatibility shim: parsers still produce
    /// VodItem structs which are mapped to db_movies rows.
    pub fn save_vod_items(&self, items: &[VodItem]) -> Result<usize, DbError> {
        crate::perf_scope!("save_vod_items");
        crate::profiling::log_memory_usage("save_vod_items:start");
        let conn = self.0.db.get()?;
        let tx = conn.unchecked_transaction()?;
        let count = Self::save_vod_items_inner(&tx, items)?;
        tx.commit()?;
        self.0.emit_per_source(
            items,
            |v| v.source_id.as_deref(),
            |sid| DataChangeEvent::VodUpdated { source_id: sid },
        );
        Ok(count)
    }

    /// Load all VOD items (from db_movies).
    pub fn load_vod_items(&self) -> Result<Vec<VodItem>, DbError> {
        let conn = self.0.db.get()?;
        let mut stmt = conn.prepare(&format!("SELECT {VOD_COLUMNS} FROM db_movies",))?;
        let rows = stmt.query_map([], vod_item_from_row)?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Load VOD items filtered by source IDs.
    pub fn get_vod_by_sources(&self, source_ids: &[String]) -> Result<Vec<VodItem>, DbError> {
        if source_ids.is_empty() {
            return self.load_vod_items();
        }
        let conn = self.0.db.get()?;
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
        let conn = self.0.db.get()?;
        let mut sql = format!("SELECT {VOD_COLUMNS} FROM db_movies WHERE 1=1",);

        let mut params: Vec<Box<dyn rusqlite::types::ToSql>> = vec![];
        let mut param_idx = 1;

        if let Some(vt) = item_type {
            sql.push_str(&format!(" AND vod_type = ?{}", param_idx));
            params.push(Box::new(vt.to_string()));
            param_idx += 1;
        }

        if !source_ids.is_empty() {
            let placeholders = build_in_placeholders_from(param_idx, source_ids.len());
            sql.push_str(&format!(" AND source_id IN ({})", placeholders));
            for id in source_ids {
                params.push(Box::new(id.clone()));
            }
            param_idx += source_ids.len();
        }

        if let Some(cat) = category {
            if cat == "Uncategorized" {
                sql.push_str(" AND (genre IS NULL OR genre = '')");
            } else {
                sql.push_str(&format!(" AND genre = ?{}", param_idx));
                params.push(Box::new(cat.to_string()));
                param_idx += 1;
            }
        }

        if let Some(q) = query
            && !q.trim().is_empty()
        {
            let lower = format!("%{}%", q.to_lowercase().trim());
            sql.push_str(&format!(" AND LOWER(name) LIKE ?{}", param_idx));
            params.push(Box::new(lower));
            let _ = param_idx;
        }

        let mut stmt = conn.prepare(&sql)?;
        let refs: Vec<&dyn rusqlite::types::ToSql> = params.iter().map(|b| b.as_ref()).collect();
        let rows = stmt.query_map(refs.as_slice(), vod_item_from_row)?;
        let mut items = rows.collect::<Result<Vec<_>, _>>()?;

        crate::algorithms::vod_sorting::sort_vod_items_vec(&mut items, sort_by);
        Ok(items)
    }

    /// Load a single page of VOD items filtered by multiple criteria and sorted.
    #[expect(
        clippy::too_many_arguments,
        reason = "Public service API mirrors the FFI paging surface and changing it would require non-local API churn"
    )]
    pub fn get_vod_page(
        &self,
        source_ids: &[String],
        item_type: Option<&str>,
        category: Option<&str>,
        query: Option<&str>,
        sort_by: &str,
        offset: i64,
        limit: i64,
    ) -> Result<Vec<VodItem>, DbError> {
        let conn = self.0.db.get()?;
        let mut sql = format!("SELECT {VOD_COLUMNS} FROM db_movies WHERE 1=1",);

        let mut params: Vec<Box<dyn rusqlite::types::ToSql>> = vec![];
        let mut param_idx = 1;

        if let Some(vt) = item_type {
            sql.push_str(&format!(" AND vod_type = ?{}", param_idx));
            params.push(Box::new(vt.to_string()));
            param_idx += 1;
        }

        if !source_ids.is_empty() {
            let placeholders = build_in_placeholders_from(param_idx, source_ids.len());
            sql.push_str(&format!(" AND source_id IN ({})", placeholders));
            for id in source_ids {
                params.push(Box::new(id.clone()));
            }
            param_idx += source_ids.len();
        }

        if let Some(cat) = category {
            if cat == "Uncategorized" {
                sql.push_str(" AND (genre IS NULL OR genre = '')");
            } else {
                sql.push_str(&format!(" AND genre = ?{}", param_idx));
                params.push(Box::new(cat.to_string()));
                param_idx += 1;
            }
        }

        if let Some(q) = query
            && !q.trim().is_empty()
        {
            let lower = format!("%{}%", q.to_lowercase().trim());
            sql.push_str(&format!(" AND LOWER(name) LIKE ?{}", param_idx));
            params.push(Box::new(lower));
            param_idx += 1;
        }

        match sort_by {
            "added_desc" => sql.push_str(" ORDER BY added_at DESC"),
            "name_asc" => sql.push_str(" ORDER BY LOWER(name) ASC"),
            "name_desc" => sql.push_str(" ORDER BY LOWER(name) DESC"),
            "year_desc" => sql.push_str(" ORDER BY year DESC"),
            "rating_desc" => sql.push_str(" ORDER BY CAST(rating AS REAL) DESC"),
            _ => sql.push_str(" ORDER BY name ASC"),
        }

        sql.push_str(&format!(" LIMIT ?{} OFFSET ?{}", param_idx, param_idx + 1));
        params.push(Box::new(limit));
        params.push(Box::new(offset));

        let mut stmt = conn.prepare(&sql)?;
        let refs: Vec<&dyn rusqlite::types::ToSql> = params.iter().map(|b| b.as_ref()).collect();
        let rows = stmt.query_map(refs.as_slice(), vod_item_from_row)?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Count VOD items filtered by the same criteria as `get_vod_page`.
    pub fn get_vod_count(
        &self,
        source_ids: &[String],
        item_type: Option<&str>,
        category: Option<&str>,
        query: Option<&str>,
    ) -> Result<i64, DbError> {
        let conn = self.0.db.get()?;
        let mut sql = "SELECT COUNT(*) FROM db_movies WHERE 1=1".to_string();

        let mut params: Vec<Box<dyn rusqlite::types::ToSql>> = vec![];
        let mut param_idx = 1;

        if let Some(vt) = item_type {
            sql.push_str(&format!(" AND vod_type = ?{}", param_idx));
            params.push(Box::new(vt.to_string()));
            param_idx += 1;
        }

        if !source_ids.is_empty() {
            let placeholders = build_in_placeholders_from(param_idx, source_ids.len());
            sql.push_str(&format!(" AND source_id IN ({})", placeholders));
            for id in source_ids {
                params.push(Box::new(id.clone()));
            }
            param_idx += source_ids.len();
        }

        if let Some(cat) = category {
            if cat == "Uncategorized" {
                sql.push_str(" AND (genre IS NULL OR genre = '')");
            } else {
                sql.push_str(&format!(" AND genre = ?{}", param_idx));
                params.push(Box::new(cat.to_string()));
                param_idx += 1;
            }
        }

        if let Some(q) = query
            && !q.trim().is_empty()
        {
            let lower = format!("%{}%", q.to_lowercase().trim());
            sql.push_str(&format!(" AND LOWER(name) LIKE ?{}", param_idx));
            params.push(Box::new(lower));
            let _ = param_idx;
        }

        let mut stmt = conn.prepare(&sql)?;
        let refs: Vec<&dyn rusqlite::types::ToSql> = params.iter().map(|b| b.as_ref()).collect();
        let count: i64 = stmt.query_row(refs.as_slice(), |row| row.get(0))?;
        Ok(count)
    }

    /// Return grouped VOD categories with item counts.
    pub fn get_vod_categories(
        &self,
        source_ids: &[String],
        item_type: Option<&str>,
    ) -> Result<Vec<(String, i32)>, DbError> {
        let conn = self.0.db.get()?;
        let mut sql =
            "SELECT COALESCE(genre, 'Uncategorized') as cat, COUNT(*) FROM db_movies WHERE 1=1"
                .to_string();

        let mut params: Vec<Box<dyn rusqlite::types::ToSql>> = vec![];
        let mut param_idx = 1;

        if let Some(vt) = item_type {
            sql.push_str(&format!(" AND vod_type = ?{}", param_idx));
            params.push(Box::new(vt.to_string()));
            param_idx += 1;
        }

        if !source_ids.is_empty() {
            sql.push_str(&format!(
                " AND source_id IN ({})",
                build_in_placeholders_from(param_idx, source_ids.len())
            ));
            for id in source_ids {
                params.push(Box::new(id.clone()));
            }
            let _ = param_idx;
        }

        sql.push_str(" GROUP BY cat ORDER BY cat");

        let mut stmt = conn.prepare(&sql)?;
        let refs: Vec<&dyn rusqlite::types::ToSql> = params.iter().map(|b| b.as_ref()).collect();
        let rows = stmt.query_map(refs.as_slice(), |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, i32>(1)?))
        })?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Search VOD items by name or category with pagination.
    pub fn search_vod(
        &self,
        query: &str,
        source_ids: &[String],
        offset: i64,
        limit: i64,
    ) -> Result<Vec<VodItem>, DbError> {
        if query.trim().is_empty() {
            return Ok(vec![]);
        }

        let conn = self.0.db.get()?;
        let mut sql =
            format!("SELECT {VOD_COLUMNS} FROM db_movies WHERE (name LIKE ?1 OR genre LIKE ?2)",);
        let mut params: Vec<Box<dyn rusqlite::types::ToSql>> = vec![];
        let like = format!("%{query}%");
        let mut param_idx = 3;

        params.push(Box::new(like.clone()));
        params.push(Box::new(like));

        if !source_ids.is_empty() {
            let placeholders = (param_idx..param_idx + source_ids.len())
                .map(|i| format!("?{i}"))
                .collect::<Vec<_>>()
                .join(", ");
            sql.push_str(&format!(" AND source_id IN ({})", placeholders));
            for id in source_ids {
                params.push(Box::new(id.clone()));
            }
            param_idx += source_ids.len();
        }

        sql.push_str(&format!(
            " ORDER BY name LIMIT ?{} OFFSET ?{}",
            param_idx,
            param_idx + 1
        ));
        params.push(Box::new(limit));
        params.push(Box::new(offset));

        let mut stmt = conn.prepare(&sql)?;
        let refs: Vec<&dyn rusqlite::types::ToSql> = params.iter().map(|b| b.as_ref()).collect();
        let rows = stmt.query_map(refs.as_slice(), vod_item_from_row)?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Find VOD items from other sources with the same title and year.
    pub fn find_vod_alternatives(
        &self,
        name: &str,
        year: Option<i32>,
        exclude_id: &str,
        limit: usize,
    ) -> Result<Vec<VodItem>, DbError> {
        let conn = self.0.db.get()?;
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

    /// Delete VOD items from `source_id` whose `id` is not in `keep_ids`.
    ///
    /// Used by external callers (Flutter / server) that track IDs explicitly.
    /// Returns count deleted.
    pub fn delete_removed_vod_items(
        &self,
        source_id: &str,
        keep_ids: &[String],
    ) -> Result<usize, DbError> {
        let conn = self.0.db.get()?;
        let tx = conn.unchecked_transaction()?;
        let deleted = super::delete_removed_by_source_conn(&tx, TABLE_MOVIES, source_id, keep_ids)?;
        tx.commit()?;
        self.0.emit(DataChangeEvent::VodUpdated {
            source_id: source_id.to_string(),
        });
        Ok(deleted)
    }

    // ── VOD Favorites ───────────────────────────────

    /// Get favourite VOD content IDs for a profile.
    pub fn get_vod_favorites(&self, profile_id: &str) -> Result<Vec<String>, DbError> {
        let conn = self.0.db.get()?;
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
        let conn = self.0.db.get()?;
        let now = chrono::Utc::now().timestamp();
        insert_or_replace!(
            conn,
            "db_vod_favorites",
            ["profile_id", "content_id", "content_type", "added_at"],
            params![profile_id, vod_item_id, "movie", now]
        )?;
        self.0.emit(DataChangeEvent::VodFavoriteToggled {
            vod_id: vod_item_id.to_string(),
            is_favorite: true,
        });
        Ok(())
    }

    /// Remove a VOD item from a profile's favourites.
    pub fn remove_vod_favorite(&self, profile_id: &str, vod_item_id: &str) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        conn.execute(
            "DELETE FROM db_vod_favorites
             WHERE profile_id = ?1
             AND content_id = ?2",
            params![profile_id, vod_item_id],
        )?;
        self.0.emit(DataChangeEvent::VodFavoriteToggled {
            vod_id: vod_item_id.to_string(),
            is_favorite: false,
        });
        Ok(())
    }
}

impl VodRepository for VodService {
    fn save_vod_items(&self, items: &[VodItem]) -> Result<usize, DomainError> {
        Ok(self.save_vod_items(items)?)
    }

    fn load_vod_items(&self) -> Result<Vec<VodItem>, DomainError> {
        Ok(self.load_vod_items()?)
    }

    fn get_vod_by_sources(&self, source_ids: &[String]) -> Result<Vec<VodItem>, DomainError> {
        Ok(self.get_vod_by_sources(source_ids)?)
    }

    fn get_filtered_vod(
        &self,
        source_ids: &[String],
        item_type: Option<&str>,
        category: Option<&str>,
        query: Option<&str>,
        sort_by: &str,
    ) -> Result<Vec<VodItem>, DomainError> {
        Ok(self.get_filtered_vod(source_ids, item_type, category, query, sort_by)?)
    }

    fn find_vod_alternatives(
        &self,
        name: &str,
        year: Option<i32>,
        exclude_id: &str,
        limit: usize,
    ) -> Result<Vec<VodItem>, DomainError> {
        Ok(self.find_vod_alternatives(name, year, exclude_id, limit)?)
    }

    fn delete_removed_vod_items(
        &self,
        source_id: &str,
        keep_ids: &[String],
    ) -> Result<usize, DomainError> {
        Ok(self.delete_removed_vod_items(source_id, keep_ids)?)
    }

    fn get_vod_favorites(&self, profile_id: &str) -> Result<Vec<String>, DomainError> {
        Ok(self.get_vod_favorites(profile_id)?)
    }

    fn add_vod_favorite(&self, profile_id: &str, vod_item_id: &str) -> Result<(), DomainError> {
        Ok(self.add_vod_favorite(profile_id, vod_item_id)?)
    }

    fn remove_vod_favorite(&self, profile_id: &str, vod_item_id: &str) -> Result<(), DomainError> {
        Ok(self.remove_vod_favorite(profile_id, vod_item_id)?)
    }
}

#[cfg(test)]
mod tests {
    use super::VodService;
    use super::resolved_native_id;
    use crate::services::ChannelService;
    use crate::services::test_helpers::*;

    #[test]
    fn save_and_load_vod_items() {
        let base = make_service();
        let src = make_source("src1", "S1", "m3u");
        crate::services::SourceService(base.clone())
            .save_source(&src)
            .unwrap();
        let svc = VodService(base);
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
    fn resolved_native_id_preserves_explicit_ids() {
        let item = make_vod_item("v1", "Movie 1");
        assert_eq!(resolved_native_id(&item), "v1");
    }

    #[test]
    fn resolved_native_id_uses_stream_url_when_native_id_missing() {
        let mut item = make_vod_item("v1", "Movie 1");
        item.native_id.clear();
        assert_eq!(
            resolved_native_id(&item),
            "fallback:movie:stream:http://example.com/vod/v1"
        );
    }

    #[test]
    fn missing_native_ids_do_not_collapse_same_source_items() {
        let base = make_service();
        let src = make_source("src1", "S1", "m3u");
        crate::services::SourceService(base.clone())
            .save_source(&src)
            .unwrap();
        let svc = VodService(base);

        let mut v1 = make_vod_item("v1", "Movie 1");
        v1.native_id.clear();
        v1.source_id = Some("src1".to_string());

        let mut v2 = make_vod_item("v2", "Movie 2");
        v2.native_id.clear();
        v2.source_id = Some("src1".to_string());
        v2.stream_url = "http://example.com/vod/v2-alt".to_string();

        let count = svc.save_vod_items(&[v1, v2]).unwrap();
        assert_eq!(count, 2);

        let loaded = svc.load_vod_items().unwrap();
        assert_eq!(loaded.len(), 2);
        assert!(loaded.iter().any(|item| item.id == "v1"));
        assert!(loaded.iter().any(|item| item.id == "v2"));
    }

    #[test]
    fn test_get_vod_by_sources_empty_returns_all() {
        let svc = VodService(make_service_with_fixtures());
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
        let svc = VodService(make_service_with_fixtures());
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
        let base = make_service();
        let src = make_source("src1", "S1", "m3u");
        crate::services::SourceService(base.clone())
            .save_source(&src)
            .unwrap();
        let svc = VodService(base);
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
        let svc = VodService(make_service_with_fixtures());
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
        let base = make_service();
        crate::services::ProfileService(base.clone())
            .save_profile(&make_profile("p1", "Alice"))
            .unwrap();
        let src = make_source("src1", "S1", "m3u");
        crate::services::SourceService(base.clone())
            .save_source(&src)
            .unwrap();
        let svc = VodService(base);
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
        let base = make_service();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        base.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
        crate::services::ProfileService(base.clone())
            .save_profile(&make_profile("p1", "Alice"))
            .unwrap();
        let src = make_source("src1", "S1", "m3u");
        crate::services::SourceService(base.clone())
            .save_source(&src)
            .unwrap();
        let svc = VodService(base);
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
        let base = make_service();
        let mut src_a = make_source("src_a", "Source A", "m3u");
        src_a.sort_order = 0;
        let mut src_b = make_source("src_b", "Source B", "m3u");
        src_b.sort_order = 1;
        crate::services::SourceService(base.clone())
            .save_source(&src_a)
            .unwrap();
        crate::services::SourceService(base.clone())
            .save_source(&src_b)
            .unwrap();
        let svc = VodService(base);

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
        let base = make_service();
        let src = make_source("src_a", "Source A", "m3u");
        crate::services::SourceService(base.clone())
            .save_source(&src)
            .unwrap();
        let svc = VodService(base);

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
        let base = make_service();
        let mut src_a = make_source("src_a", "Source A", "m3u");
        src_a.sort_order = 0;
        let mut src_b = make_source("src_b", "Source B", "m3u");
        src_b.sort_order = 1;
        crate::services::SourceService(base.clone())
            .save_source(&src_a)
            .unwrap();
        crate::services::SourceService(base.clone())
            .save_source(&src_b)
            .unwrap();
        let svc = VodService(base);

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
        let base = make_service();
        let mut src_a = make_source("src_a", "Source A", "m3u");
        src_a.sort_order = 0;
        let mut src_b = make_source("src_b", "Source B", "m3u");
        src_b.sort_order = 1;
        let mut src_c = make_source("src_c", "Source C", "m3u");
        src_c.sort_order = 2;
        crate::services::SourceService(base.clone())
            .save_source(&src_a)
            .unwrap();
        crate::services::SourceService(base.clone())
            .save_source(&src_b)
            .unwrap();
        crate::services::SourceService(base.clone())
            .save_source(&src_c)
            .unwrap();
        let svc = VodService(base);

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
        let base = make_service();
        let mut src_a = make_source("src_a", "Source A", "m3u");
        src_a.sort_order = 5;
        let mut src_b = make_source("src_b", "Source B", "m3u");
        src_b.sort_order = 0;
        let mut src_c = make_source("src_c", "Source C", "m3u");
        src_c.sort_order = 10;
        crate::services::SourceService(base.clone())
            .save_source(&src_a)
            .unwrap();
        crate::services::SourceService(base.clone())
            .save_source(&src_b)
            .unwrap();
        crate::services::SourceService(base.clone())
            .save_source(&src_c)
            .unwrap();
        let svc = VodService(base);

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
        let base = make_service_with_fixtures();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        base.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
        let svc = VodService(base);
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

    #[test]
    fn get_vod_page_with_offset_limit() {
        let svc = VodService(make_service_with_fixtures());
        let mut v1 = make_vod_item("v1", "Alpha");
        v1.source_id = Some("src_a".to_string());
        let mut v2 = make_vod_item("v2", "Bravo");
        v2.source_id = Some("src_a".to_string());
        let mut v3 = make_vod_item("v3", "Charlie");
        v3.source_id = Some("src_a".to_string());
        svc.save_vod_items(&[v1, v2, v3]).unwrap();

        let page = svc
            .get_vod_page(&["src_a".to_string()], None, None, None, "name_asc", 1, 1)
            .unwrap();

        assert_eq!(page.len(), 1);
        assert_eq!(page[0].id, "v2");
        assert_eq!(page[0].name, "Bravo");
    }

    #[test]
    fn get_vod_categories_returns_counts() {
        let svc = VodService(make_service_with_fixtures());
        let mut v1 = make_vod_item("v1", "Action 1");
        v1.source_id = Some("src_a".to_string());
        v1.genre = Some("Action".to_string());
        let mut v2 = make_vod_item("v2", "Comedy 1");
        v2.source_id = Some("src_a".to_string());
        v2.genre = Some("Comedy".to_string());
        let mut v3 = make_vod_item("v3", "Action 2");
        v3.source_id = Some("src_a".to_string());
        v3.genre = Some("Action".to_string());
        svc.save_vod_items(&[v1, v2, v3]).unwrap();

        let categories = svc
            .get_vod_categories(&["src_a".to_string()], None)
            .unwrap();

        assert_eq!(
            categories,
            vec![("Action".to_string(), 2), ("Comedy".to_string(), 1)]
        );
    }

    #[test]
    fn search_channels_finds_by_name() {
        let svc = ChannelService(make_service_with_fixtures());
        let mut ch1 = make_channel("ch1", "Movie Hub");
        ch1.source_id = Some("src_a".to_string());
        let mut ch2 = make_channel("ch2", "Sports Live");
        ch2.source_id = Some("src_a".to_string());
        svc.save_channels(&[ch1, ch2]).unwrap();

        let result = svc
            .search_channels("Movie", &["src_a".to_string()], 0, 10)
            .unwrap();

        assert_eq!(result.len(), 1);
        assert_eq!(result[0].id, "ch1");
        assert_eq!(result[0].name, "Movie Hub");
    }
}
