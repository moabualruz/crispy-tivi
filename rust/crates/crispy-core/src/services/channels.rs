use rusqlite::{Row, params};

use super::{
    ServiceContext, bool_to_int, build_in_placeholders, build_in_placeholders_from, opt_dt_to_ts,
    str_params,
};
use crate::database::row_helpers::RowExt;
use crate::database::{DbError, optional};
use crate::errors::DomainError;
use crate::events::DataChangeEvent;
use crate::insert_or_replace;
use crate::models::Channel;
use crate::models::columns::CHANNEL_COLUMNS;
use crate::traits::ChannelRepository;

/// Domain service for channel operations.
pub struct ChannelService(pub ServiceContext);

/// Map a single SQLite row to a `Channel`.
///
/// Column order must match `CHANNEL_COLUMNS`.
fn channel_from_row(row: &Row) -> rusqlite::Result<Channel> {
    Ok(Channel {
        id: row.get(0)?,
        native_id: row.get(1)?,
        name: row.get(2)?,
        stream_url: row.get(3)?,
        number: row.get(4)?,
        channel_group: row.get(5)?,
        logo_url: row.get(6)?,
        tvg_id: row.get(7)?,
        xtream_stream_id: row.get(8)?,
        epg_channel_id: row.get(9)?,
        tvg_name: row.get(10)?,
        is_favorite: row.get_bool(11)?,
        user_agent: row.get(12)?,
        has_catchup: row.get_bool(13)?,
        catchup_days: row.get(14)?,
        catchup_type: row.get(15)?,
        catchup_source: row.get(16)?,
        resolution: None,
        source_id: row.get(17)?,
        added_at: row.get_datetime(18)?,
        updated_at: row.get_datetime(19)?,
        is_247: row.get_bool(20)?,
        tvg_shift: row.get(21)?,
        tvg_language: row.get(22)?,
        tvg_country: row.get(23)?,
        parent_code: row.get(24)?,
        is_radio: row.get_bool(25)?,
        tvg_rec: row.get(26)?,
        is_adult: row.get_bool(27)?,
        custom_sid: row.get(28)?,
        direct_source: row.get(29)?,
        stalker_cmd: row.get(30)?,
        resolved_url: row.get(31)?,
        resolved_at: row.get(32)?,
        tvg_url: row.get(33)?,
        stream_properties_json: row.get(34)?,
        vlc_options_json: row.get(35)?,
        timeshift: row.get(36)?,
        stream_type: row.get(37)?,
        thumbnail_url: row.get(38)?,
    })
}

fn channel_sort_clause(sort: &str) -> &'static str {
    match sort {
        "name_desc" => "name DESC",
        "added_desc" => "added_at DESC, name ASC",
        "number_asc" => "COALESCE(number, 999999) ASC, name ASC",
        "name_asc" => "name ASC",
        _ => "name ASC",
    }
}

fn build_channel_filters(
    source_ids: &[String],
    group: Option<&str>,
) -> (String, Vec<Box<dyn rusqlite::types::ToSql>>, usize) {
    let mut clauses = Vec::new();
    let mut params: Vec<Box<dyn rusqlite::types::ToSql>> = Vec::new();
    let mut param_idx = 1;

    if !source_ids.is_empty() {
        clauses.push(build_source_id_clause(param_idx, source_ids.len()));
        push_source_id_params(&mut params, &mut param_idx, source_ids);
    }

    if let Some(group) = group {
        clauses.push(format!(
            "COALESCE(channel_group, 'Ungrouped') = ?{param_idx}"
        ));
        params.push(Box::new(group.to_string()));
        param_idx += 1;
    }

    let where_sql = if clauses.is_empty() {
        String::new()
    } else {
        format!(" WHERE {}", clauses.join(" AND "))
    };

    (where_sql, params, param_idx)
}

fn build_source_id_clause(start_idx: usize, len: usize) -> String {
    format!(
        "source_id IN ({})",
        build_in_placeholders_from(start_idx, len)
    )
}

fn push_source_id_params(
    params: &mut Vec<Box<dyn rusqlite::types::ToSql>>,
    param_idx: &mut usize,
    source_ids: &[String],
) {
    for source_id in source_ids {
        params.push(Box::new(source_id.clone()));
    }
    *param_idx += source_ids.len();
}

fn build_filtered_channel_query(
    select_sql: &str,
    source_ids: &[String],
    group: Option<&str>,
    order_by: Option<&str>,
) -> (String, Vec<Box<dyn rusqlite::types::ToSql>>, usize) {
    let (where_sql, params, param_idx) = build_channel_filters(source_ids, group);
    let mut sql = format!("{select_sql}{where_sql}");
    if let Some(order_by) = order_by {
        sql.push_str(" ORDER BY ");
        sql.push_str(order_by);
    }
    (sql, params, param_idx)
}

fn build_channel_search_query(
    select_sql: &str,
    query: &str,
    source_ids: &[String],
) -> (String, Vec<Box<dyn rusqlite::types::ToSql>>, usize) {
    let mut sql = format!("{select_sql} WHERE (name LIKE ?1 OR channel_group LIKE ?2)");
    let mut params: Vec<Box<dyn rusqlite::types::ToSql>> = Vec::new();
    let like = format!("%{query}%");
    let mut param_idx = 3;

    params.push(Box::new(like.clone()));
    params.push(Box::new(like));

    if !source_ids.is_empty() {
        sql.push_str(&format!(
            " AND {}",
            build_source_id_clause(param_idx, source_ids.len())
        ));
        push_source_id_params(&mut params, &mut param_idx, source_ids);
    }

    (sql, params, param_idx)
}

fn qualified_channel_columns(alias: &str) -> String {
    CHANNEL_COLUMNS
        .split(',')
        .map(|column| format!("{alias}.{}", column.trim()))
        .collect::<Vec<_>>()
        .join(", ")
}

impl ChannelService {
    // ── Channels ────────────────────────────────────

    /// Batch upsert channels using a caller-supplied connection.
    ///
    /// Intended for use inside a shared outer transaction (e.g. `save_sync_data`).
    /// The caller owns the transaction boundary; this method does not commit.
    pub(super) fn save_channels_inner(
        conn: &rusqlite::Connection,
        channels: &[Channel],
    ) -> Result<usize, DbError> {
        let mut stmt = conn.prepare(
            "INSERT INTO db_channels (
                    id, native_id, name, stream_url, number,
                    channel_group, logo_url, tvg_id, xtream_stream_id, epg_channel_id,
                    tvg_name, is_favorite, user_agent,
                    has_catchup, catchup_days,
                    catchup_type, catchup_source,
                    source_id, added_at, updated_at, is_247,
                    tvg_shift, tvg_language, tvg_country,
                    parent_code, is_radio, tvg_rec,
                    is_adult, custom_sid, direct_source,
                    stalker_cmd, resolved_url, resolved_at,
                    tvg_url, stream_properties_json, vlc_options_json,
                    timeshift, stream_type, thumbnail_url
                ) VALUES (
                    ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9,
                    ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17,
                    ?18,
                    COALESCE(?19, strftime('%s','now')),
                    COALESCE(?20, strftime('%s','now')),
                    ?21, ?22, ?23, ?24,
                    ?25, ?26, ?27, ?28, ?29, ?30,
                    ?31, ?32, ?33,
                    ?34, ?35, ?36, ?37, ?38, ?39
                )
                ON CONFLICT (source_id, native_id) DO UPDATE SET
                    name = excluded.name,
                    stream_url = excluded.stream_url,
                    number = excluded.number,
                    channel_group = excluded.channel_group,
                    logo_url = excluded.logo_url,
                    tvg_id = excluded.tvg_id,
                    xtream_stream_id = excluded.xtream_stream_id,
                    epg_channel_id = excluded.epg_channel_id,
                    tvg_name = excluded.tvg_name,
                    is_favorite = excluded.is_favorite,
                    user_agent = excluded.user_agent,
                    has_catchup = excluded.has_catchup,
                    catchup_days = excluded.catchup_days,
                    catchup_type = excluded.catchup_type,
                    catchup_source = excluded.catchup_source,
                    updated_at = strftime('%s','now'),
                    is_247 = excluded.is_247,
                    tvg_shift = excluded.tvg_shift,
                    tvg_language = excluded.tvg_language,
                    tvg_country = excluded.tvg_country,
                    parent_code = excluded.parent_code,
                    is_radio = excluded.is_radio,
                    tvg_rec = excluded.tvg_rec,
                    is_adult = excluded.is_adult,
                    custom_sid = excluded.custom_sid,
                    direct_source = excluded.direct_source,
                    stalker_cmd = excluded.stalker_cmd,
                    resolved_url = excluded.resolved_url,
                    resolved_at = excluded.resolved_at,
                    tvg_url = excluded.tvg_url,
                    stream_properties_json = excluded.stream_properties_json,
                    vlc_options_json = excluded.vlc_options_json,
                    timeshift = excluded.timeshift,
                    stream_type = excluded.stream_type,
                    thumbnail_url = excluded.thumbnail_url",
        )?;
        let mut count = 0usize;
        for ch in channels {
            stmt.execute(params![
                ch.id,
                ch.native_id,
                ch.name,
                ch.stream_url,
                ch.number,
                ch.channel_group,
                ch.logo_url,
                ch.tvg_id,
                ch.xtream_stream_id,
                ch.epg_channel_id,
                ch.tvg_name,
                bool_to_int(ch.is_favorite),
                ch.user_agent,
                bool_to_int(ch.has_catchup),
                ch.catchup_days,
                ch.catchup_type,
                ch.catchup_source,
                ch.source_id,
                opt_dt_to_ts(&ch.added_at),
                opt_dt_to_ts(&ch.updated_at),
                bool_to_int(ch.is_247),
                ch.tvg_shift,
                ch.tvg_language,
                ch.tvg_country,
                ch.parent_code,
                bool_to_int(ch.is_radio),
                ch.tvg_rec,
                bool_to_int(ch.is_adult),
                ch.custom_sid,
                ch.direct_source,
                ch.stalker_cmd,
                ch.resolved_url,
                ch.resolved_at,
                ch.tvg_url,
                ch.stream_properties_json,
                ch.vlc_options_json,
                ch.timeshift,
                ch.stream_type,
                ch.thumbnail_url,
            ])?;
            count += 1;
        }
        #[cfg(debug_assertions)]
        eprintln!("[debug] Inserted {} channels", count);
        Ok(count)
    }

    /// Batch upsert channels. Returns count inserted.
    pub fn save_channels(&self, channels: &[Channel]) -> Result<usize, DbError> {
        crate::perf_scope!("save_channels");
        crate::profiling::log_memory_usage("save_channels:start");
        let conn = self.0.db.get()?;
        let tx = conn.unchecked_transaction()?;
        let count = Self::save_channels_inner(&tx, channels)?;
        tx.commit()?;
        // Emit one event per distinct source_id so each
        // source's subscribers are notified independently.
        self.0.emit_per_source(
            channels,
            |ch| ch.source_id.as_deref(),
            |sid| DataChangeEvent::ChannelsUpdated { source_id: sid },
        );
        Ok(count)
    }

    /// Load all channels.
    pub fn load_channels(&self) -> Result<Vec<Channel>, DbError> {
        crate::perf_scope!("load_channels");
        let conn = self.0.db.get()?;
        let mut stmt = conn.prepare(&format!("SELECT {CHANNEL_COLUMNS} FROM db_channels",))?;
        let rows = stmt.query_map([], channel_from_row)?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Load channels filtered by source IDs.
    ///
    /// If `source_ids` is empty, all channels are returned
    /// (same behaviour as `load_channels()`). Otherwise only
    /// channels whose `source_id` is in the list are returned.
    pub fn get_channels_by_sources(&self, source_ids: &[String]) -> Result<Vec<Channel>, DbError> {
        if source_ids.is_empty() {
            return self.load_channels();
        }
        let conn = self.0.db.get()?;
        let sql = format!(
            "SELECT {CHANNEL_COLUMNS} FROM db_channels WHERE source_id IN ({})",
            build_in_placeholders(source_ids.len())
        );
        let mut stmt = conn.prepare(&sql)?;
        let params = str_params(source_ids);
        let rows = stmt.query_map(params.as_slice(), channel_from_row)?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Load channels by a list of IDs.
    pub fn get_channels_by_ids(&self, ids: &[String]) -> Result<Vec<Channel>, DbError> {
        let conn = self.0.db.get()?;
        if ids.is_empty() {
            return Ok(Vec::new());
        }
        let sql = format!(
            "SELECT {CHANNEL_COLUMNS} FROM db_channels WHERE id IN ({})",
            build_in_placeholders(ids.len())
        );
        let mut stmt = conn.prepare(&sql)?;
        let params = str_params(ids);
        let rows = stmt.query_map(params.as_slice(), channel_from_row)?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    pub fn get_channel_groups(&self, source_ids: &[String]) -> Result<Vec<(String, i32)>, DbError> {
        let conn = self.0.db.get()?;

        if source_ids.is_empty() {
            let mut stmt = conn.prepare(
                "SELECT COALESCE(channel_group, 'Ungrouped') AS grp, COUNT(*) AS cnt
                 FROM db_channels
                 GROUP BY grp
                 ORDER BY grp",
            )?;
            let rows = stmt.query_map([], |row| {
                Ok((row.get::<_, String>(0)?, row.get::<_, i32>(1)?))
            })?;
            return Ok(rows.collect::<Result<Vec<_>, _>>()?);
        }

        let sql = format!(
            "SELECT COALESCE(channel_group, 'Ungrouped') AS grp, COUNT(*) AS cnt
             FROM db_channels
             WHERE source_id IN ({})
             GROUP BY grp
             ORDER BY grp",
            build_in_placeholders(source_ids.len())
        );
        let mut stmt = conn.prepare(&sql)?;
        let params = str_params(source_ids);
        let rows = stmt.query_map(params.as_slice(), |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, i32>(1)?))
        })?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    pub fn get_channels_page(
        &self,
        source_ids: &[String],
        group: Option<&str>,
        sort: &str,
        offset: i64,
        limit: i64,
    ) -> Result<Vec<Channel>, DbError> {
        let conn = self.0.db.get()?;
        let (mut sql, mut params, param_idx) = build_filtered_channel_query(
            &format!("SELECT {CHANNEL_COLUMNS} FROM db_channels"),
            source_ids,
            group,
            Some(channel_sort_clause(sort)),
        );
        sql.push_str(&format!(" LIMIT ?{param_idx} OFFSET ?{}", param_idx + 1));
        params.push(Box::new(limit));
        params.push(Box::new(offset));

        let mut stmt = conn.prepare(&sql)?;
        let refs: Vec<&dyn rusqlite::types::ToSql> = params.iter().map(|b| b.as_ref()).collect();
        let rows = stmt.query_map(refs.as_slice(), channel_from_row)?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    pub fn get_channel_count(
        &self,
        source_ids: &[String],
        group: Option<&str>,
    ) -> Result<i64, DbError> {
        let conn = self.0.db.get()?;
        let (sql, params, _) = build_filtered_channel_query(
            "SELECT COUNT(*) FROM db_channels",
            source_ids,
            group,
            None,
        );
        let refs: Vec<&dyn rusqlite::types::ToSql> = params.iter().map(|b| b.as_ref()).collect();
        conn.query_row(&sql, refs.as_slice(), |row| row.get(0))
            .map_err(Into::into)
    }

    pub fn search_channels(
        &self,
        query: &str,
        source_ids: &[String],
        offset: i64,
        limit: i64,
    ) -> Result<Vec<Channel>, DbError> {
        if query.trim().is_empty() {
            return Ok(vec![]);
        }

        let conn = self.0.db.get()?;
        let (mut sql, mut params, param_idx) = build_channel_search_query(
            &format!("SELECT {CHANNEL_COLUMNS} FROM db_channels"),
            query,
            source_ids,
        );

        sql.push_str(&format!(
            " ORDER BY name LIMIT ?{} OFFSET ?{}",
            param_idx,
            param_idx + 1
        ));
        params.push(Box::new(limit));
        params.push(Box::new(offset));

        let mut stmt = conn.prepare(&sql)?;
        let refs: Vec<&dyn rusqlite::types::ToSql> = params.iter().map(|b| b.as_ref()).collect();
        let rows = stmt.query_map(refs.as_slice(), channel_from_row)?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    pub fn get_channel_ids_for_group(
        &self,
        source_ids: &[String],
        group: Option<&str>,
        sort: &str,
    ) -> Result<Vec<String>, DbError> {
        let conn = self.0.db.get()?;
        let (sql, params, _) = build_filtered_channel_query(
            "SELECT id FROM db_channels",
            source_ids,
            group,
            Some(channel_sort_clause(sort)),
        );
        let refs: Vec<&dyn rusqlite::types::ToSql> = params.iter().map(|b| b.as_ref()).collect();
        let mut stmt = conn.prepare(&sql)?;
        let rows = stmt.query_map(refs.as_slice(), |row| row.get(0))?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    pub fn get_channel_by_id(&self, id: &str) -> Result<Option<Channel>, DbError> {
        let conn = self.0.db.get()?;
        let result = conn.query_row(
            &format!("SELECT {CHANNEL_COLUMNS} FROM db_channels WHERE id = ?1"),
            params![id],
            channel_from_row,
        );
        optional(result)
    }

    pub fn get_favorite_channels(
        &self,
        source_ids: &[String],
        profile_id: &str,
    ) -> Result<Vec<Channel>, DbError> {
        let conn = self.0.db.get()?;
        let channel_columns = qualified_channel_columns("c");
        let mut sql = format!(
            "SELECT {channel_columns}
             FROM db_channels c
             JOIN db_user_favorites f ON f.channel_id = c.id
             WHERE f.profile_id = ?1"
        );
        let mut params: Vec<Box<dyn rusqlite::types::ToSql>> =
            vec![Box::new(profile_id.to_string())];

        if !source_ids.is_empty() {
            let placeholders = (2..source_ids.len() + 2)
                .map(|i| format!("?{i}"))
                .collect::<Vec<_>>()
                .join(", ");
            sql.push_str(&format!(" AND c.source_id IN ({placeholders})"));
            for source_id in source_ids {
                params.push(Box::new(source_id.clone()));
            }
        }

        let refs: Vec<&dyn rusqlite::types::ToSql> = params.iter().map(|b| b.as_ref()).collect();
        let mut stmt = conn.prepare(&sql)?;
        let rows = stmt.query_map(refs.as_slice(), channel_from_row)?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Delete channels from `source_id` whose `id` is not in `keep_ids`.
    ///
    /// Used by external callers (Flutter / server) that track IDs explicitly.
    /// Returns count deleted.
    pub fn delete_removed_channels(
        &self,
        source_id: &str,
        keep_ids: &[String],
    ) -> Result<usize, DbError> {
        let conn = self.0.db.get()?;
        let tx = conn.unchecked_transaction()?;
        let deleted = super::delete_removed_by_source_conn(
            &tx,
            crate::database::TABLE_CHANNELS,
            source_id,
            keep_ids,
        )?;
        tx.commit()?;
        self.0.emit(DataChangeEvent::ChannelsUpdated {
            source_id: source_id.to_string(),
        });
        Ok(deleted)
    }

    // ── Channel Favorites (profile-scoped) ──────────

    /// Get favourite channel IDs for a profile.
    pub fn get_favorites(&self, profile_id: &str) -> Result<Vec<String>, DbError> {
        let conn = self.0.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT channel_id
             FROM db_user_favorites
             WHERE profile_id = ?1",
        )?;
        let rows = stmt.query_map(params![profile_id], |row| row.get(0))?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Add a channel to a profile's favourites.
    pub fn add_favorite(&self, profile_id: &str, channel_id: &str) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        let now = chrono::Utc::now().timestamp();
        insert_or_replace!(
            conn,
            "db_user_favorites",
            ["profile_id", "channel_id", "added_at"],
            params![profile_id, channel_id, now]
        )?;
        self.0.emit(DataChangeEvent::FavoriteToggled {
            item_id: channel_id.to_string(),
            is_favorite: true,
        });
        Ok(())
    }

    /// Remove a channel from a profile's favourites.
    pub fn remove_favorite(&self, profile_id: &str, channel_id: &str) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        conn.execute(
            "DELETE FROM db_user_favorites
             WHERE profile_id = ?1
             AND channel_id = ?2",
            params![profile_id, channel_id],
        )?;
        self.0.emit(DataChangeEvent::FavoriteToggled {
            item_id: channel_id.to_string(),
            is_favorite: false,
        });
        Ok(())
    }
}

impl ChannelRepository for ChannelService {
    fn save_channels(&self, channels: &[Channel]) -> Result<usize, DomainError> {
        Ok(self.save_channels(channels)?)
    }

    fn load_channels(&self) -> Result<Vec<Channel>, DomainError> {
        Ok(self.load_channels()?)
    }

    fn get_channels_by_sources(&self, source_ids: &[String]) -> Result<Vec<Channel>, DomainError> {
        Ok(self.get_channels_by_sources(source_ids)?)
    }

    fn get_channels_by_ids(&self, ids: &[String]) -> Result<Vec<Channel>, DomainError> {
        Ok(self.get_channels_by_ids(ids)?)
    }

    fn delete_removed_channels(
        &self,
        source_id: &str,
        keep_ids: &[String],
    ) -> Result<usize, DomainError> {
        Ok(self.delete_removed_channels(source_id, keep_ids)?)
    }

    fn get_favorites(&self, profile_id: &str) -> Result<Vec<String>, DomainError> {
        Ok(self.get_favorites(profile_id)?)
    }

    fn add_favorite(&self, profile_id: &str, channel_id: &str) -> Result<(), DomainError> {
        Ok(self.add_favorite(profile_id, channel_id)?)
    }

    fn remove_favorite(&self, profile_id: &str, channel_id: &str) -> Result<(), DomainError> {
        Ok(self.remove_favorite(profile_id, channel_id)?)
    }
}

#[cfg(test)]
mod tests {
    use super::ChannelService;
    use crate::services::test_helpers::*;

    #[test]
    fn save_and_load_channels() {
        let svc = ChannelService(make_service());
        let channels = vec![
            make_channel("ch1", "Channel 1"),
            make_channel("ch2", "Channel 2"),
        ];
        let count = svc.save_channels(&channels).unwrap();
        assert_eq!(count, 2);

        let loaded = svc.load_channels().unwrap();
        assert_eq!(loaded.len(), 2);
        assert!(loaded.iter().any(|c| c.id == "ch1"));
        assert!(loaded.iter().any(|c| c.id == "ch2"));
    }

    #[test]
    fn test_get_channels_by_sources_empty_returns_all() {
        let svc = ChannelService(make_service_with_fixtures());
        let mut ch1 = make_channel("ch1", "Channel 1");
        ch1.source_id = Some("src_a".to_string());
        let mut ch2 = make_channel("ch2", "Channel 2");
        ch2.source_id = Some("src_b".to_string());
        svc.save_channels(&[ch1, ch2]).unwrap();

        // Empty slice => all channels.
        let result = svc.get_channels_by_sources(&[]).unwrap();
        assert_eq!(result.len(), 2);
    }

    #[test]
    fn test_get_channels_by_sources_filters() {
        let svc = ChannelService(make_service_with_fixtures());
        let mut ch1 = make_channel("ch1", "Channel 1");
        ch1.source_id = Some("src_a".to_string());
        let mut ch2 = make_channel("ch2", "Channel 2");
        ch2.source_id = Some("src_b".to_string());
        let mut ch3 = make_channel("ch3", "Channel 3");
        ch3.source_id = Some("src_a".to_string());
        svc.save_channels(&[ch1, ch2, ch3]).unwrap();

        let result = svc.get_channels_by_sources(&["src_a".to_string()]).unwrap();
        assert_eq!(result.len(), 2);
        let ids: Vec<&str> = result.iter().map(|c| c.id.as_str()).collect();
        assert!(ids.contains(&"ch1"));
        assert!(ids.contains(&"ch3"));
        assert!(!ids.contains(&"ch2"));
    }

    #[test]
    fn get_channels_by_ids() {
        let svc = ChannelService(make_service());
        let channels = vec![
            make_channel("ch1", "Channel 1"),
            make_channel("ch2", "Channel 2"),
            make_channel("ch3", "Channel 3"),
        ];
        svc.save_channels(&channels).unwrap();

        let found = svc
            .get_channels_by_ids(&["ch1".to_string(), "ch3".to_string()])
            .unwrap();
        assert_eq!(found.len(), 2);
        let ids: Vec<&str> = found.iter().map(|c| c.id.as_str()).collect();
        assert!(ids.contains(&"ch1"));
        assert!(ids.contains(&"ch3"));
    }

    #[test]
    fn get_channel_groups_returns_counts() {
        let svc = ChannelService(make_service_with_fixtures());

        let mut ch1 = make_channel("ch1", "Channel 1");
        ch1.source_id = Some("src_a".to_string());
        ch1.channel_group = Some("News".to_string());

        let mut ch2 = make_channel("ch2", "Channel 2");
        ch2.source_id = Some("src_a".to_string());
        ch2.channel_group = Some("News".to_string());

        let mut ch3 = make_channel("ch3", "Channel 3");
        ch3.source_id = Some("src_a".to_string());
        ch3.channel_group = None;

        svc.save_channels(&[ch1, ch2, ch3]).unwrap();

        let groups = svc.get_channel_groups(&["src_a".to_string()]).unwrap();
        assert_eq!(
            groups,
            vec![("News".to_string(), 2), ("Ungrouped".to_string(), 1)]
        );
    }

    #[test]
    fn get_channels_page_respects_offset_limit() {
        let svc = ChannelService(make_service_with_fixtures());

        let channels = (0..10)
            .map(|idx| {
                let mut ch = make_channel(&format!("ch{idx:02}"), &format!("Channel {idx:02}"));
                ch.source_id = Some("src_a".to_string());
                ch
            })
            .collect::<Vec<_>>();

        svc.save_channels(&channels).unwrap();

        let page = svc
            .get_channels_page(&["src_a".to_string()], None, "name_asc", 3, 3)
            .unwrap();

        assert_eq!(page.len(), 3);
        assert_eq!(page[0].id, "ch03");
        assert_eq!(page[1].id, "ch04");
        assert_eq!(page[2].id, "ch05");
    }

    #[test]
    fn delete_removed_channels() {
        let svc = ChannelService(make_service_with_fixtures());
        let mut ch1 = make_channel("ch1", "Channel 1");
        ch1.source_id = Some("src1".to_string());
        let mut ch2 = make_channel("ch2", "Channel 2");
        ch2.source_id = Some("src1".to_string());
        let mut ch3 = make_channel("ch3", "Channel 3");
        ch3.source_id = Some("src1".to_string());
        svc.save_channels(&[ch1, ch2, ch3]).unwrap();

        let deleted = svc
            .delete_removed_channels("src1", &["ch1".to_string()])
            .unwrap();
        assert_eq!(deleted, 2);

        let remaining = svc.load_channels().unwrap();
        assert_eq!(remaining.len(), 1);
        assert_eq!(remaining[0].id, "ch1");
    }

    #[test]
    fn channel_upsert_overwrites() {
        let base = make_service();
        // source_id must be non-NULL so the (source_id, native_id) conflict
        // key triggers on the second save instead of hitting the PK constraint.
        // A matching source row must exist first to satisfy the FK constraint.
        crate::services::SourceService(base.clone())
            .save_source(&make_source("src1", "Source 1", "m3u"))
            .unwrap();
        let svc = ChannelService(base);
        let mut ch = make_channel("ch1", "Original");
        ch.source_id = Some("src1".to_string());
        svc.save_channels(&[ch.clone()]).unwrap();

        ch.name = "Updated".to_string();
        svc.save_channels(&[ch]).unwrap();

        let loaded = svc.load_channels().unwrap();
        assert_eq!(loaded.len(), 1);
        assert_eq!(loaded[0].name, "Updated");
    }

    #[test]
    fn channel_favorites_crud() {
        let base = make_service();
        let profile = make_profile("p1", "Alice");
        crate::services::ProfileService(base.clone())
            .save_profile(&profile)
            .unwrap();
        let svc = ChannelService(base);
        let ch = make_channel("ch1", "Channel 1");
        svc.save_channels(&[ch]).unwrap();

        svc.add_favorite("p1", "ch1").unwrap();
        let favs = svc.get_favorites("p1").unwrap();
        assert_eq!(favs, vec!["ch1"]);

        svc.remove_favorite("p1", "ch1").unwrap();
        let favs = svc.get_favorites("p1").unwrap();
        assert!(favs.is_empty());
    }

    #[test]
    fn emit_favorite_toggled_on_add() {
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
        let svc = ChannelService(base);
        svc.save_channels(&[make_channel("ch1", "Channel 1")])
            .unwrap();
        svc.add_favorite("p1", "ch1").unwrap();
        let recorded = log.lock().unwrap();
        assert!(!recorded.is_empty());
        let last = recorded.last().unwrap();
        assert!(last.contains("FavoriteToggled"), "{last}");
        assert!(last.contains("\"is_favorite\":true"), "{last}");
    }

    #[test]
    fn emit_favorite_toggled_on_remove() {
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
        let svc = ChannelService(base);
        svc.save_channels(&[make_channel("ch1", "Channel 1")])
            .unwrap();
        svc.add_favorite("p1", "ch1").unwrap();
        svc.remove_favorite("p1", "ch1").unwrap();
        let recorded = log.lock().unwrap();
        let last = recorded.last().unwrap();
        assert!(last.contains("FavoriteToggled"), "{last}");
        assert!(last.contains("\"is_favorite\":false"), "{last}");
    }

    #[test]
    fn save_channels_empty_slice_emits_with_empty_source_id() {
        use crate::events::serialize_event;
        use std::sync::{Arc, Mutex};
        let base = make_service();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        base.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
        let svc = ChannelService(base);
        let count = svc.save_channels(&[]).unwrap();
        assert_eq!(count, 0);
        let recorded = log.lock().unwrap();
        let last = recorded.last().unwrap();
        assert!(last.contains("ChannelsUpdated"), "{last}");
        assert!(last.contains("\"source_id\":\"\""), "{last}");
    }

    #[test]
    fn save_channels_multi_source_emits_per_source() {
        use crate::events::serialize_event;
        use std::collections::HashSet;
        use std::sync::{Arc, Mutex};
        let base = make_service_with_fixtures();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        base.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
        let svc = ChannelService(base);
        let mut ch1 = make_channel("ch1", "Channel 1");
        ch1.source_id = Some("src_a".to_string());
        let mut ch2 = make_channel("ch2", "Channel 2");
        ch2.source_id = Some("src_b".to_string());
        let mut ch3 = make_channel("ch3", "Channel 3");
        ch3.source_id = Some("src_a".to_string());
        svc.save_channels(&[ch1, ch2, ch3]).unwrap();
        let recorded = log.lock().unwrap();
        let sources: HashSet<String> = recorded
            .iter()
            .filter(|s| s.contains("ChannelsUpdated"))
            .filter_map(|s| {
                // Extract source_id from JSON like {"ChannelsUpdated":{"source_id":"src_a"}}
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
