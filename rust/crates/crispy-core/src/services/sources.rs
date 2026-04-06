use rusqlite::params;

use super::{CrispyService, bool_to_int, dt_to_ts, opt_dt_to_ts};
use crate::algorithms::crypto::{decrypt_field, encrypt_field, get_or_create_encryption_key};
use crate::database::row_helpers::RowExt;
use crate::database::{DbError, TABLE_CHANNELS, TABLE_MOVIES, TABLE_SOURCES};
use crate::errors::CrispyError;
use crate::events::DataChangeEvent;
use crate::insert_or_replace;
use crate::models::{Source, SourceStats};
use crate::traits::SourceRepository;

// ── Credential encryption helpers ─────────────────────────────────────────────

/// Map a `CrispyError::Security` to a `DbError::Migration` so that the
/// service methods (which return `DbError`) can propagate encryption failures.
///
/// Using `DbError::Migration` is intentional: it carries a `String` message
/// and bubbles up as a non-fatal service error (no SQLite error code).
fn crypto_to_db(e: CrispyError) -> DbError {
    DbError::Migration(format!("Credential encryption error: {e}"))
}

/// Encrypt one optional credential field.
///
/// Returns `Ok(None)` when `value` is `None`. On encryption failure the
/// error is mapped to `DbError` via [`crypto_to_db`].
fn encrypt_opt(value: &Option<String>, key: &[u8; 32]) -> Result<Option<String>, DbError> {
    match value {
        Some(v) => encrypt_field(v, key).map(Some).map_err(crypto_to_db),
        None => Ok(None),
    }
}

/// Decrypt one optional credential field.
///
/// Returns `Ok(None)` when `value` is `None`. On decryption failure the
/// error is mapped to `DbError` via [`crypto_to_db`].
fn decrypt_opt(value: &Option<String>, key: &[u8; 32]) -> Result<Option<String>, DbError> {
    match value {
        Some(v) => decrypt_field(v, key).map(Some).map_err(crypto_to_db),
        None => Ok(None),
    }
}

/// Map a raw DB row into a `Source` (without decryption).
///
/// Column order: id, name, source_type, url, username, password,
/// access_token, device_id, user_id, mac_address, epg_url, user_agent,
/// refresh_interval_minutes, accept_self_signed, enabled, sort_order,
/// last_sync_time, last_sync_status, last_sync_error, created_at,
/// updated_at, credentials_encrypted, deleted_at, epg_etag,
/// epg_last_modified.
fn row_to_source(row: &rusqlite::Row<'_>) -> rusqlite::Result<Source> {
    Ok(Source {
        id: row.get(0)?,
        name: row.get(1)?,
        source_type: row
            .get::<_, String>(2)?
            .as_str()
            .try_into()
            .unwrap_or_default(),
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
        accept_self_signed: row.get_bool(13)?,
        enabled: row.get_bool(14)?,
        sort_order: row.get(15)?,
        last_sync_time: row.get_datetime(16)?,
        last_sync_status: row.get(17)?,
        last_sync_error: row.get(18)?,
        created_at: row.get_datetime(19)?,
        updated_at: row.get_datetime(20)?,
        credentials_encrypted: row.get_bool(21).unwrap_or(false),
        deleted_at: row.get(22)?,
        epg_etag: row.get(23)?,
        epg_last_modified: row.get(24)?,
    })
}

/// Decrypt credential fields on a source loaded from the DB.
///
/// If the source has `credentials_encrypted = false` (legacy plaintext row)
/// and a keyring is available, this re-encrypts and saves the row so that
/// future loads are encrypted.
fn decrypt_source(svc: &CrispyService, mut source: Source) -> Result<Source, DbError> {
    let Some(kr) = svc.keyring.as_deref() else {
        // No keyring configured (tests or no-keyring build): return as-is.
        return Ok(source);
    };

    let key = get_or_create_encryption_key(kr).map_err(crypto_to_db)?;

    if source.credentials_encrypted {
        // Already encrypted — decrypt in place.
        source.password = decrypt_opt(&source.password, &key)?;
        source.access_token = decrypt_opt(&source.access_token, &key)?;
        source.mac_address = decrypt_opt(&source.mac_address, &key)?;
        source.device_id = decrypt_opt(&source.device_id, &key)?;
        source.credentials_encrypted = false; // expose plaintext to callers
    } else {
        // Legacy plaintext row — encrypt and persist immediately.
        let encrypted = Source {
            password: encrypt_opt(&source.password, &key)?,
            access_token: encrypt_opt(&source.access_token, &key)?,
            mac_address: encrypt_opt(&source.mac_address, &key)?,
            device_id: encrypt_opt(&source.device_id, &key)?,
            credentials_encrypted: true,
            ..source.clone()
        };
        svc.save_source_raw(&encrypted)?;
        // Return the plaintext version to the caller.
    }

    Ok(source)
}

impl CrispyService {
    /// Get all sources ordered by sort_order.
    pub fn get_sources(&self) -> Result<Vec<Source>, DbError> {
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(&format!(
            "SELECT id, name, source_type, url, username, password,
                    access_token, device_id, user_id, mac_address,
                    epg_url, user_agent, refresh_interval_minutes,
                    accept_self_signed, enabled, sort_order,
                    last_sync_time, last_sync_status, last_sync_error,
                    created_at, updated_at, credentials_encrypted,
                    deleted_at, epg_etag, epg_last_modified
             FROM {TABLE_SOURCES} WHERE deleted_at IS NULL ORDER BY sort_order, name"
        ))?;
        let rows = stmt.query_map([], row_to_source)?;
        let sources: Vec<Source> = rows
            .collect::<Result<Vec<_>, _>>()
            .map_err(DbError::Sqlite)?;
        // Decrypt outside the borrow of `conn`.
        drop(stmt);
        sources
            .into_iter()
            .map(|s| decrypt_source(self, s))
            .collect()
    }

    /// Get a single source by ID.
    pub fn get_source(&self, id: &str) -> Result<Option<Source>, DbError> {
        let conn = self.db.get()?;
        let result = conn.query_row(
            &format!(
                "SELECT id, name, source_type, url, username, password,
                        access_token, device_id, user_id, mac_address,
                        epg_url, user_agent, refresh_interval_minutes,
                        accept_self_signed, enabled, sort_order,
                        last_sync_time, last_sync_status, last_sync_error,
                        created_at, updated_at, credentials_encrypted,
                        deleted_at, epg_etag, epg_last_modified
                 FROM {TABLE_SOURCES} WHERE id = ?1 AND deleted_at IS NULL"
            ),
            params![id],
            row_to_source,
        );
        match result {
            Ok(s) => {
                drop(conn);
                Ok(Some(decrypt_source(self, s)?))
            }
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(DbError::Sqlite(e)),
        }
    }

    /// Save (insert or replace) a source, encrypting credentials if a keyring
    /// is configured.
    ///
    /// Callers pass a source with plaintext credentials; this method encrypts
    /// them before writing to the DB and sets `credentials_encrypted = true`.
    pub fn save_source(&self, source: &Source) -> Result<(), DbError> {
        if let Some(kr) = self.keyring.as_deref() {
            let key = get_or_create_encryption_key(kr).map_err(crypto_to_db)?;
            let encrypted = Source {
                password: encrypt_opt(&source.password, &key)?,
                access_token: encrypt_opt(&source.access_token, &key)?,
                mac_address: encrypt_opt(&source.mac_address, &key)?,
                device_id: encrypt_opt(&source.device_id, &key)?,
                credentials_encrypted: true,
                ..source.clone()
            };
            self.save_source_raw(&encrypted)
        } else {
            // No keyring (tests / no-keyring build): store as-is.
            self.save_source_raw(source)
        }
    }

    /// Write a source row verbatim — callers are responsible for encryption.
    ///
    /// Not part of the public API; used by [`save_source`] and the legacy
    /// re-encryption path in [`decrypt_source`].
    pub(super) fn save_source_raw(&self, source: &Source) -> Result<(), DbError> {
        let conn = self.db.get()?;
        insert_or_replace!(
            conn,
            TABLE_SOURCES,
            [
                "id", "name", "source_type", "url", "username", "password",
                "access_token", "device_id", "user_id", "mac_address",
                "epg_url", "user_agent", "refresh_interval_minutes",
                "accept_self_signed", "enabled", "sort_order",
                "last_sync_time", "last_sync_status", "last_sync_error",
                "created_at", "updated_at", "credentials_encrypted",
                "deleted_at", "epg_etag", "epg_last_modified",
            ],
            params![
                source.id,
                source.name,
                source.source_type.as_str(),
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
                bool_to_int(source.credentials_encrypted),
                source.deleted_at,
                source.epg_etag,
                source.epg_last_modified,
            ],
        )?;
        self.emit(DataChangeEvent::SourceChanged {
            source_id: source.id.clone(),
        });
        Ok(())
    }

    /// Delete a source. FK CASCADE handles all child table cleanup
    /// (channels, VOD, EPG, categories, sync_meta, profile_source_access).
    pub fn delete_source(&self, id: &str) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute(
            &format!("DELETE FROM {TABLE_SOURCES} WHERE id = ?1"),
            params![id],
        )?;
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
                &format!("UPDATE {TABLE_SOURCES} SET sort_order = ?1 WHERE id = ?2"),
                params![i as i32, id],
            )?;
        }
        tx.commit()?;
        self.emit(DataChangeEvent::BulkDataRefresh);
        Ok(())
    }

    /// Get per-source channel and VOD item counts.
    ///
    /// Runs two aggregate queries and merges the results into one
    /// `SourceStats` entry per distinct `source_id`.
    pub fn get_source_stats(&self) -> Result<Vec<SourceStats>, DbError> {
        let conn = self.db.get()?;

        // Channel counts per source.
        let mut ch_stmt = conn.prepare(&format!(
            "SELECT source_id, COUNT(*) AS cnt
             FROM {TABLE_CHANNELS}
             WHERE source_id IS NOT NULL
             GROUP BY source_id"
        ))?;
        let ch_rows = ch_stmt.query_map([], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, i64>(1)?))
        })?;
        let mut ch_map: std::collections::HashMap<String, i64> = std::collections::HashMap::new();
        for r in ch_rows {
            let (sid, cnt) = r?;
            ch_map.insert(sid, cnt);
        }

        // VOD counts per source.
        let mut vod_stmt = conn.prepare(&format!(
            "SELECT source_id, COUNT(*) AS cnt
             FROM {TABLE_MOVIES}
             WHERE source_id IS NOT NULL
             GROUP BY source_id"
        ))?;
        let vod_rows = vod_stmt.query_map([], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, i64>(1)?))
        })?;
        let mut vod_map: std::collections::HashMap<String, i64> = std::collections::HashMap::new();
        for r in vod_rows {
            let (sid, cnt) = r?;
            vod_map.insert(sid, cnt);
        }

        // Merge: union of all source_ids from both maps.
        let mut all_ids: std::collections::HashSet<String> = std::collections::HashSet::new();
        all_ids.extend(ch_map.keys().cloned());
        all_ids.extend(vod_map.keys().cloned());

        let mut stats: Vec<SourceStats> = all_ids
            .into_iter()
            .map(|sid| SourceStats {
                channel_count: *ch_map.get(&sid).unwrap_or(&0),
                vod_count: *vod_map.get(&sid).unwrap_or(&0),
                source_id: sid,
            })
            .collect();

        // Stable ordering by source_id.
        stats.sort_by(|a, b| a.source_id.cmp(&b.source_id));
        Ok(stats)
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
            &format!(
                "UPDATE {TABLE_SOURCES}
                 SET last_sync_status = ?1,
                     last_sync_error = ?2,
                     last_sync_time = ?3
                 WHERE id = ?4"
            ),
            params![status, error, sync_time.as_ref().map(dt_to_ts), id,],
        )?;
        Ok(())
    }
}

impl SourceRepository for CrispyService {
    fn get_sources(&self) -> Result<Vec<Source>, DbError> {
        self.get_sources()
    }

    fn get_source(&self, id: &str) -> Result<Option<Source>, DbError> {
        self.get_source(id)
    }

    fn save_source(&self, source: &Source) -> Result<(), DbError> {
        self.save_source(source)
    }

    fn delete_source(&self, id: &str) -> Result<(), DbError> {
        self.delete_source(id)
    }

    fn reorder_sources(&self, source_ids: &[String]) -> Result<(), DbError> {
        self.reorder_sources(source_ids)
    }

    fn get_source_stats(&self) -> Result<Vec<SourceStats>, DbError> {
        self.get_source_stats()
    }

    fn update_source_sync_status(
        &self,
        id: &str,
        status: &str,
        error: Option<&str>,
        sync_time: Option<chrono::NaiveDateTime>,
    ) -> Result<(), DbError> {
        self.update_source_sync_status(id, status, error, sync_time)
    }
}

#[cfg(test)]
mod tests {
    use crate::services::test_helpers::*;

    #[test]
    fn test_get_source_stats() {
        let svc = make_service();

        // Two sources.
        svc.save_source(&make_source("src_a", "A", "m3u")).unwrap();
        svc.save_source(&make_source("src_b", "B", "xtream"))
            .unwrap();

        // 2 channels on src_a, 1 on src_b.
        let mut ch1 = make_channel("ch1", "Ch1");
        ch1.source_id = Some("src_a".to_string());
        let mut ch2 = make_channel("ch2", "Ch2");
        ch2.source_id = Some("src_a".to_string());
        let mut ch3 = make_channel("ch3", "Ch3");
        ch3.source_id = Some("src_b".to_string());
        svc.save_channels(&[ch1, ch2, ch3]).unwrap();

        // 3 VOD items on src_b, 0 on src_a.
        let mut v1 = make_vod_item("v1", "Movie 1");
        v1.source_id = Some("src_b".to_string());
        let mut v2 = make_vod_item("v2", "Movie 2");
        v2.source_id = Some("src_b".to_string());
        let mut v3 = make_vod_item("v3", "Movie 3");
        v3.source_id = Some("src_b".to_string());
        svc.save_vod_items(&[v1, v2, v3]).unwrap();

        let stats = svc.get_source_stats().unwrap();
        assert_eq!(stats.len(), 2);

        let a = stats.iter().find(|s| s.source_id == "src_a").unwrap();
        assert_eq!(a.channel_count, 2);
        assert_eq!(a.vod_count, 0);

        let b = stats.iter().find(|s| s.source_id == "src_b").unwrap();
        assert_eq!(b.channel_count, 1);
        assert_eq!(b.vod_count, 3);
    }

    #[test]
    fn source_crud_roundtrip() {
        let svc = make_service();
        let source = make_source("src1", "My IPTV", "xtream");

        // Save.
        svc.save_source(&source).unwrap();

        // Get by ID.
        let loaded = svc.get_source("src1").unwrap().unwrap();
        assert_eq!(loaded.name, "My IPTV");
        assert_eq!(loaded.source_type, crate::value_objects::SourceType::Xtream);
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
