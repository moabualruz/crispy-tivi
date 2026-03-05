use rusqlite::params;

use super::{CrispyService, bool_to_int, dt_to_ts, int_to_bool, opt_dt_to_ts, opt_ts_to_dt};
use crate::database::DbError;
use crate::events::DataChangeEvent;
use crate::models::Source;

impl CrispyService {
    /// Get all sources ordered by sort_order.
    pub fn get_sources(&self) -> Result<Vec<Source>, DbError> {
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT id, name, source_type, url, username, password,
                    access_token, device_id, user_id, mac_address,
                    epg_url, user_agent, refresh_interval_minutes,
                    accept_self_signed, enabled, sort_order,
                    last_sync_time, last_sync_status, last_sync_error,
                    created_at, updated_at
             FROM db_sources ORDER BY sort_order, name",
        )?;
        let rows = stmt.query_map([], |row| {
            Ok(Source {
                id: row.get(0)?,
                name: row.get(1)?,
                source_type: row.get(2)?,
                url: row.get(3)?,
                username: row.get(4)?,
                password: row.get(5)?,
                access_token: row.get(6)?,
                device_id: row.get(7)?,
                user_id: row.get(8)?,
                mac_address: row.get(9)?,
                epg_url: row.get(10)?,
                user_agent: row.get(11)?,
                refresh_interval_minutes: row.get(12)?,
                accept_self_signed: int_to_bool(row.get(13)?),
                enabled: int_to_bool(row.get(14)?),
                sort_order: row.get(15)?,
                last_sync_time: opt_ts_to_dt(row.get(16)?),
                last_sync_status: row.get(17)?,
                last_sync_error: row.get(18)?,
                created_at: opt_ts_to_dt(row.get(19)?),
                updated_at: opt_ts_to_dt(row.get(20)?),
            })
        })?;
        rows.collect::<Result<Vec<_>, _>>().map_err(DbError::Sqlite)
    }

    /// Get a single source by ID.
    pub fn get_source(&self, id: &str) -> Result<Option<Source>, DbError> {
        let conn = self.db.get()?;
        let result = conn.query_row(
            "SELECT id, name, source_type, url, username, password,
                    access_token, device_id, user_id, mac_address,
                    epg_url, user_agent, refresh_interval_minutes,
                    accept_self_signed, enabled, sort_order,
                    last_sync_time, last_sync_status, last_sync_error,
                    created_at, updated_at
             FROM db_sources WHERE id = ?1",
            params![id],
            |row| {
                Ok(Source {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    source_type: row.get(2)?,
                    url: row.get(3)?,
                    username: row.get(4)?,
                    password: row.get(5)?,
                    access_token: row.get(6)?,
                    device_id: row.get(7)?,
                    user_id: row.get(8)?,
                    mac_address: row.get(9)?,
                    epg_url: row.get(10)?,
                    user_agent: row.get(11)?,
                    refresh_interval_minutes: row.get(12)?,
                    accept_self_signed: int_to_bool(row.get(13)?),
                    enabled: int_to_bool(row.get(14)?),
                    sort_order: row.get(15)?,
                    last_sync_time: opt_ts_to_dt(row.get(16)?),
                    last_sync_status: row.get(17)?,
                    last_sync_error: row.get(18)?,
                    created_at: opt_ts_to_dt(row.get(19)?),
                    updated_at: opt_ts_to_dt(row.get(20)?),
                })
            },
        );
        match result {
            Ok(s) => Ok(Some(s)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(DbError::Sqlite(e)),
        }
    }

    /// Save (insert or replace) a source.
    pub fn save_source(&self, source: &Source) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute(
            "INSERT OR REPLACE INTO db_sources
             (id, name, source_type, url, username, password,
              access_token, device_id, user_id, mac_address,
              epg_url, user_agent, refresh_interval_minutes,
              accept_self_signed, enabled, sort_order,
              last_sync_time, last_sync_status, last_sync_error,
              created_at, updated_at)
             VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,
                     ?11,?12,?13,?14,?15,?16,?17,?18,?19,?20,?21)",
            params![
                source.id,
                source.name,
                source.source_type,
                source.url,
                source.username,
                source.password,
                source.access_token,
                source.device_id,
                source.user_id,
                source.mac_address,
                source.epg_url,
                source.user_agent,
                source.refresh_interval_minutes,
                bool_to_int(source.accept_self_signed),
                bool_to_int(source.enabled),
                source.sort_order,
                opt_dt_to_ts(&source.last_sync_time),
                source.last_sync_status,
                source.last_sync_error,
                opt_dt_to_ts(&source.created_at),
                opt_dt_to_ts(&source.updated_at),
            ],
        )?;
        self.emit(DataChangeEvent::SourceChanged {
            source_id: source.id.clone(),
        });
        Ok(())
    }

    /// Delete a source and cascade-delete all associated data.
    ///
    /// Deletes: channels, VOD, EPG, categories, sync_meta,
    /// profile_source_access for this source_id.
    pub fn delete_source(&self, id: &str) -> Result<(), DbError> {
        let mut conn = self.db.get()?;
        let tx = conn.transaction()?;
        tx.execute("DELETE FROM db_channels WHERE source_id = ?1", params![id])?;
        tx.execute("DELETE FROM db_vod_items WHERE source_id = ?1", params![id])?;
        tx.execute(
            "DELETE FROM db_epg_entries WHERE source_id = ?1",
            params![id],
        )?;
        tx.execute(
            "DELETE FROM db_categories WHERE source_id = ?1",
            params![id],
        )?;
        tx.execute("DELETE FROM db_sync_meta WHERE source_id = ?1", params![id])?;
        tx.execute(
            "DELETE FROM db_profile_source_access WHERE source_id = ?1",
            params![id],
        )?;
        tx.execute("DELETE FROM db_sources WHERE id = ?1", params![id])?;
        tx.commit()?;
        self.emit(DataChangeEvent::SourceDeleted {
            source_id: id.to_string(),
        });
        Ok(())
    }

    /// Reorder sources by setting sort_order from the given ID list.
    pub fn reorder_sources(&self, source_ids: &[String]) -> Result<(), DbError> {
        let mut conn = self.db.get()?;
        let tx = conn.transaction()?;
        for (i, id) in source_ids.iter().enumerate() {
            tx.execute(
                "UPDATE db_sources SET sort_order = ?1 WHERE id = ?2",
                params![i as i32, id],
            )?;
        }
        tx.commit()?;
        self.emit(DataChangeEvent::BulkDataRefresh);
        Ok(())
    }

    /// Update only the sync status fields on a source.
    pub fn update_source_sync_status(
        &self,
        id: &str,
        status: &str,
        error: Option<&str>,
        sync_time: Option<chrono::NaiveDateTime>,
    ) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute(
            "UPDATE db_sources
             SET last_sync_status = ?1,
                 last_sync_error = ?2,
                 last_sync_time = ?3
             WHERE id = ?4",
            params![status, error, sync_time.as_ref().map(dt_to_ts), id,],
        )?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use crate::services::test_helpers::*;

    #[test]
    fn source_crud_roundtrip() {
        let svc = make_service();
        let source = make_source("src1", "My IPTV", "xtream");

        // Save.
        svc.save_source(&source).unwrap();

        // Get by ID.
        let loaded = svc.get_source("src1").unwrap().unwrap();
        assert_eq!(loaded.name, "My IPTV");
        assert_eq!(loaded.source_type, "xtream");
        assert_eq!(loaded.refresh_interval_minutes, 60);
        assert!(loaded.enabled);

        // Get all.
        let all = svc.get_sources().unwrap();
        assert_eq!(all.len(), 1);

        // Update.
        let mut updated = source.clone();
        updated.name = "Updated IPTV".to_string();
        svc.save_source(&updated).unwrap();
        let reloaded = svc.get_source("src1").unwrap().unwrap();
        assert_eq!(reloaded.name, "Updated IPTV");
    }

    #[test]
    fn source_not_found_returns_none() {
        let svc = make_service();
        assert!(svc.get_source("nonexistent").unwrap().is_none());
    }

    #[test]
    fn delete_source_cascades() {
        let svc = make_service();
        let source = make_source("src1", "Test", "m3u");
        svc.save_source(&source).unwrap();

        // Add channels and VOD belonging to this source.
        let mut ch = make_channel("ch1", "Channel 1");
        ch.source_id = Some("src1".to_string());
        svc.save_channels(&[ch]).unwrap();

        let mut vod = make_vod_item("vod1", "Movie 1");
        vod.source_id = Some("src1".to_string());
        svc.save_vod_items(&[vod]).unwrap();

        // Verify data exists.
        assert_eq!(svc.load_channels().unwrap().len(), 1);
        assert_eq!(svc.load_vod_items().unwrap().len(), 1);

        // Delete source — should cascade.
        svc.delete_source("src1").unwrap();

        assert!(svc.get_source("src1").unwrap().is_none());
        assert_eq!(svc.load_channels().unwrap().len(), 0);
        assert_eq!(svc.load_vod_items().unwrap().len(), 0);
    }

    #[test]
    fn reorder_sources() {
        let svc = make_service();
        svc.save_source(&make_source("a", "Alpha", "m3u")).unwrap();
        svc.save_source(&make_source("b", "Beta", "xtream"))
            .unwrap();
        svc.save_source(&make_source("c", "Charlie", "stalker"))
            .unwrap();

        // Reorder: c, a, b.
        svc.reorder_sources(&["c".into(), "a".into(), "b".into()])
            .unwrap();

        let all = svc.get_sources().unwrap();
        assert_eq!(all[0].id, "c");
        assert_eq!(all[0].sort_order, 0);
        assert_eq!(all[1].id, "a");
        assert_eq!(all[1].sort_order, 1);
        assert_eq!(all[2].id, "b");
        assert_eq!(all[2].sort_order, 2);
    }

    #[test]
    fn update_sync_status() {
        let svc = make_service();
        svc.save_source(&make_source("src1", "Test", "m3u"))
            .unwrap();

        svc.update_source_sync_status("src1", "error", Some("timeout"), None)
            .unwrap();

        let loaded = svc.get_source("src1").unwrap().unwrap();
        assert_eq!(loaded.last_sync_status.as_deref(), Some("error"));
        assert_eq!(loaded.last_sync_error.as_deref(), Some("timeout"));
    }

    #[test]
    fn multiple_sources_same_type() {
        let svc = make_service();
        svc.save_source(&make_source("src1", "IPTV One", "xtream"))
            .unwrap();
        svc.save_source(&make_source("src2", "IPTV Two", "xtream"))
            .unwrap();

        let all = svc.get_sources().unwrap();
        assert_eq!(all.len(), 2);
    }

    #[test]
    fn cascade_delete_preserves_other_sources() {
        let svc = make_service();
        svc.save_source(&make_source("src1", "Source A", "m3u"))
            .unwrap();
        svc.save_source(&make_source("src2", "Source B", "m3u"))
            .unwrap();

        let mut ch1 = make_channel("ch1", "Ch from A");
        ch1.source_id = Some("src1".to_string());
        let mut ch2 = make_channel("ch2", "Ch from B");
        ch2.source_id = Some("src2".to_string());
        svc.save_channels(&[ch1, ch2]).unwrap();

        // Delete only source A.
        svc.delete_source("src1").unwrap();

        assert!(svc.get_source("src1").unwrap().is_none());
        assert!(svc.get_source("src2").unwrap().is_some());
        let channels = svc.load_channels().unwrap();
        assert_eq!(channels.len(), 1);
        assert_eq!(channels[0].id, "ch2");
    }

    #[test]
    fn source_events_emitted() {
        use crate::events::serialize_event;
        use std::sync::{Arc, Mutex};
        let svc = make_service();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        svc.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));

        let source = make_source("src1", "Test", "m3u");
        svc.save_source(&source).unwrap();
        svc.delete_source("src1").unwrap();

        let recorded = log.lock().unwrap();
        assert!(
            recorded.iter().any(|s| s.contains("SourceChanged")),
            "expected SourceChanged event",
        );
        assert!(
            recorded.iter().any(|s| s.contains("SourceDeleted")),
            "expected SourceDeleted event",
        );
    }

    #[test]
    fn get_sources_empty() {
        let svc = make_service();
        let all = svc.get_sources().unwrap();
        assert!(all.is_empty());
    }

    #[test]
    fn update_sync_status_sets_success() {
        let svc = make_service();
        svc.save_source(&make_source("s1", "Test", "m3u")).unwrap();

        svc.update_source_sync_status("s1", "success", None, None)
            .unwrap();

        let loaded = svc.get_source("s1").unwrap().unwrap();
        assert_eq!(loaded.last_sync_status.as_deref(), Some("success"));
        assert!(loaded.last_sync_error.is_none());
    }
}
