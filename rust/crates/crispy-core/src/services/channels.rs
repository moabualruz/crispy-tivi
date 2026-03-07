use rusqlite::{Row, params};

use super::{
    CrispyService, bool_to_int, build_in_placeholders, int_to_bool, opt_dt_to_ts, opt_ts_to_dt,
    str_params,
};
use crate::database::{DbError, TABLE_CHANNELS};
use crate::events::DataChangeEvent;
use crate::models::Channel;

/// SELECT column list for `db_channels` (17 columns, positional order).
///
/// Use with `format!("SELECT {CHANNEL_COLUMNS} FROM db_channels ...")`.
/// Column order matches `channel_from_row` index bindings.
pub(crate) const CHANNEL_COLUMNS: &str = "id, name, stream_url, number, \
     channel_group, logo_url, tvg_id, \
     tvg_name, is_favorite, user_agent, \
     has_catchup, catchup_days, \
     catchup_type, catchup_source, \
     source_id, added_at, updated_at";

/// Map a single SQLite row to a `Channel`.
///
/// Column order must match `CHANNEL_COLUMNS`:
/// `id, name, stream_url, number, channel_group, logo_url, tvg_id,
///  tvg_name, is_favorite, user_agent, has_catchup, catchup_days,
///  catchup_type, catchup_source, source_id, added_at, updated_at`
fn channel_from_row(row: &Row) -> rusqlite::Result<Channel> {
    Ok(Channel {
        id: row.get(0)?,
        name: row.get(1)?,
        stream_url: row.get(2)?,
        number: row.get(3)?,
        channel_group: row.get(4)?,
        logo_url: row.get(5)?,
        tvg_id: row.get(6)?,
        tvg_name: row.get(7)?,
        is_favorite: int_to_bool(row.get(8)?),
        user_agent: row.get(9)?,
        has_catchup: int_to_bool(row.get(10)?),
        catchup_days: row.get(11)?,
        catchup_type: row.get(12)?,
        catchup_source: row.get(13)?,
        resolution: None,
        source_id: row.get(14)?,
        added_at: opt_ts_to_dt(row.get(15)?),
        updated_at: opt_ts_to_dt(row.get(16)?),
    })
}

impl CrispyService {
    // ── Channels ────────────────────────────────────

    /// Batch upsert channels. Returns count inserted.
    pub fn save_channels(&self, channels: &[Channel]) -> Result<usize, DbError> {
        let conn = self.db.get()?;
        let tx = conn.unchecked_transaction()?;
        let mut count = 0usize;
        for ch in channels {
            tx.execute(
                "INSERT OR REPLACE INTO db_channels (
                    id, name, stream_url, number,
                    channel_group, logo_url, tvg_id,
                    tvg_name, is_favorite, user_agent,
                    has_catchup, catchup_days,
                    catchup_type, catchup_source,
                    source_id, added_at, updated_at
                ) VALUES (
                    ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8,
                    ?9, ?10, ?11, ?12, ?13, ?14, ?15,
                    ?16, ?17
                )",
                params![
                    ch.id,
                    ch.name,
                    ch.stream_url,
                    ch.number,
                    ch.channel_group,
                    ch.logo_url,
                    ch.tvg_id,
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
                ],
            )?;
            count += 1;
        }
        tx.commit()?;
        // Emit one event per distinct source_id so each
        // source's subscribers are notified independently.
        self.emit_per_source(
            channels,
            |ch| ch.source_id.as_deref(),
            |sid| DataChangeEvent::ChannelsUpdated { source_id: sid },
        );
        #[cfg(debug_assertions)]
        eprintln!("[debug] Inserted {} channels", count);
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

    /// Delete channels from `source_id` not in
    /// `keep_ids`. Returns count deleted.
    pub fn delete_removed_channels(
        &self,
        source_id: &str,
        keep_ids: &[String],
    ) -> Result<usize, DbError> {
        let conn = self.db.get()?;
        let tx = conn.unchecked_transaction()?;
        let deleted = super::delete_removed_by_source(&tx, TABLE_CHANNELS, source_id, keep_ids)?;
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
        let svc = make_service();
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
        let svc = make_service();
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
        let svc = make_service();
        let channels = vec![
            make_channel("ch1", "Channel 1"),
            make_channel("ch2", "Channel 2"),
            make_channel("ch3", "Channel 3"),
        ];
        svc.save_channels(&channels).unwrap();

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
        let mut ch = make_channel("ch1", "Original");
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
        let svc = make_service();
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
