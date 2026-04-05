use rusqlite::{Row, params};

use super::{
    CrispyService, bool_to_int, build_in_placeholders, int_to_bool, opt_dt_to_ts, opt_ts_to_dt,
    str_params,
};
use crate::database::DbError;
use crate::events::DataChangeEvent;
use crate::models::Channel;

/// SELECT column list for `db_channels` (39 columns, positional order).
///
/// Use with `format!("SELECT {CHANNEL_COLUMNS} FROM db_channels ...")`.
/// Column order matches `channel_from_row` index bindings.
pub(crate) const CHANNEL_COLUMNS: &str = "id, native_id, name, stream_url, number, \
     channel_group, logo_url, tvg_id, xtream_stream_id, epg_channel_id, \
     tvg_name, is_favorite, user_agent, \
     has_catchup, catchup_days, \
     catchup_type, catchup_source, \
     source_id, added_at, updated_at, is_247, \
     tvg_shift, tvg_language, tvg_country, \
     parent_code, is_radio, tvg_rec, \
     is_adult, custom_sid, direct_source, \
     stalker_cmd, resolved_url, resolved_at, \
     tvg_url, stream_properties_json, vlc_options_json, \
     timeshift, stream_type, thumbnail_url";

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
        is_favorite: int_to_bool(row.get(11)?),
        user_agent: row.get(12)?,
        has_catchup: int_to_bool(row.get(13)?),
        catchup_days: row.get(14)?,
        catchup_type: row.get(15)?,
        catchup_source: row.get(16)?,
        resolution: None,
        source_id: row.get(17)?,
        added_at: opt_ts_to_dt(row.get(18)?),
        updated_at: opt_ts_to_dt(row.get(19)?),
        is_247: int_to_bool(row.get(20)?),
        tvg_shift: row.get(21)?,
        tvg_language: row.get(22)?,
        tvg_country: row.get(23)?,
        parent_code: row.get(24)?,
        is_radio: int_to_bool(row.get(25)?),
        tvg_rec: row.get(26)?,
        is_adult: int_to_bool(row.get(27)?),
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

impl CrispyService {
    // ── Channels ────────────────────────────────────

    /// Batch upsert channels using a caller-supplied connection.
    ///
    /// Intended for use inside a shared outer transaction (e.g. `save_sync_data`).
    /// The caller owns the transaction boundary; this method does not commit.
    pub(super) fn save_channels_inner(
        conn: &rusqlite::Connection,
        channels: &[Channel],
    ) -> Result<usize, DbError> {
        let mut count = 0usize;
        for ch in channels {
            conn.execute(
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
                    added_at = excluded.added_at,
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
                params![
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
                ],
            )?;
            count += 1;
        }
        #[cfg(debug_assertions)]
        eprintln!("[debug] Inserted {} channels", count);
        Ok(count)
    }

    /// Batch upsert channels. Returns count inserted.
    pub fn save_channels(&self, channels: &[Channel]) -> Result<usize, DbError> {
        let conn = self.db.get()?;
        let tx = conn.unchecked_transaction()?;
        let count = Self::save_channels_inner(&tx, channels)?;
        tx.commit()?;
        // Emit one event per distinct source_id so each
        // source's subscribers are notified independently.
        self.emit_per_source(
            channels,
            |ch| ch.source_id.as_deref(),
            |sid| DataChangeEvent::ChannelsUpdated { source_id: sid },
        );
        Ok(count)
    }

    /// Load all channels.
    pub fn load_channels(&self) -> Result<Vec<Channel>, DbError> {
        let conn = self.db.get()?;
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
        let conn = self.db.get()?;
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
        let conn = self.db.get()?;
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

    /// Delete channels from `source_id` whose `id` is not in `keep_ids`.
    ///
    /// Used by external callers (Flutter / server) that track IDs explicitly.
    /// Returns count deleted.
    pub fn delete_removed_channels(
        &self,
        source_id: &str,
        keep_ids: &[String],
    ) -> Result<usize, DbError> {
        let conn = self.db.get()?;
        let tx = conn.unchecked_transaction()?;
        let deleted = super::delete_removed_by_source_conn(
            &tx,
            crate::database::TABLE_CHANNELS,
            source_id,
            keep_ids,
        )?;
        tx.commit()?;
        self.emit(DataChangeEvent::ChannelsUpdated {
            source_id: source_id.to_string(),
        });
        Ok(deleted)
    }

    // ── Channel Favorites (profile-scoped) ──────────

    /// Get favourite channel IDs for a profile.
    pub fn get_favorites(&self, profile_id: &str) -> Result<Vec<String>, DbError> {
        let conn = self.db.get()?;
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
        let conn = self.db.get()?;
        let now = chrono::Utc::now().timestamp();
        conn.execute(
            "INSERT OR REPLACE INTO db_user_favorites
             (profile_id, channel_id, added_at)
             VALUES (?1, ?2, ?3)",
            params![profile_id, channel_id, now],
        )?;
        self.emit(DataChangeEvent::FavoriteToggled {
            item_id: channel_id.to_string(),
            is_favorite: true,
        });
        Ok(())
    }

    /// Remove a channel from a profile's favourites.
    pub fn remove_favorite(&self, profile_id: &str, channel_id: &str) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute(
            "DELETE FROM db_user_favorites
             WHERE profile_id = ?1
             AND channel_id = ?2",
            params![profile_id, channel_id],
        )?;
        self.emit(DataChangeEvent::FavoriteToggled {
            item_id: channel_id.to_string(),
            is_favorite: false,
        });
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use crate::services::test_helpers::*;

    #[test]
    fn save_and_load_channels() {
        let svc = make_service();
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
        let svc = make_service_with_fixtures();
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
        let svc = make_service_with_fixtures();
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
        let svc = make_service();
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
    fn delete_removed_channels() {
        let svc = make_service_with_fixtures();
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
        let svc = make_service();
        // source_id must be non-NULL so the (source_id, native_id) conflict
        // key triggers on the second save instead of hitting the PK constraint.
        // A matching source row must exist first to satisfy the FK constraint.
        svc.save_source(&make_source("src1", "Source 1", "m3u")).unwrap();
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
        let svc = make_service();
        let profile = make_profile("p1", "Alice");
        svc.save_profile(&profile).unwrap();
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
        let svc = make_service();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        svc.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
        svc.save_profile(&make_profile("p1", "Alice")).unwrap();
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
        let svc = make_service();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        svc.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
        svc.save_profile(&make_profile("p1", "Alice")).unwrap();
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
        let svc = make_service();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        svc.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
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
        let svc = make_service_with_fixtures();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        svc.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
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
