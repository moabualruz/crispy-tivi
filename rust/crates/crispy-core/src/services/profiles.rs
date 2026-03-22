use std::collections::HashMap;

use rusqlite::params;

use super::{CrispyService, bool_to_int, int_to_bool};
use crate::database::DbError;
use crate::events::DataChangeEvent;
use crate::models::UserProfile;

impl CrispyService {
    // ── Profiles ────────────────────────────────────

    /// Upsert a user profile.
    pub fn save_profile(&self, profile: &UserProfile) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute(
            "INSERT OR REPLACE INTO db_profiles (
                id, name, avatar_index, pin,
                is_child, pin_version,
                max_allowed_rating, role,
                dvr_permission, dvr_quota_mb
            ) VALUES (
                ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8,
                ?9, ?10
            )",
            params![
                profile.id,
                profile.name,
                profile.avatar_index,
                profile.pin,
                bool_to_int(profile.is_child),
                profile.pin_version,
                profile.max_allowed_rating,
                profile.role,
                profile.dvr_permission,
                profile.dvr_quota_mb,
            ],
        )?;
        self.emit(DataChangeEvent::ProfileChanged {
            profile_id: profile.id.clone(),
        });
        Ok(())
    }

    /// Delete a profile and cascade-delete its
    /// favourites, channel order, and source access.
    pub fn delete_profile(&self, id: &str) -> Result<(), DbError> {
        let conn = self.db.get()?;
        let tx = conn.unchecked_transaction()?;
        tx.execute(
            "DELETE FROM db_watch_history
             WHERE profile_id = ?1",
            params![id],
        )?;
        tx.execute(
            "DELETE FROM db_user_favorites
             WHERE profile_id = ?1",
            params![id],
        )?;
        tx.execute(
            "DELETE FROM db_vod_favorites
             WHERE profile_id = ?1",
            params![id],
        )?;
        tx.execute(
            "DELETE FROM db_favorite_categories
             WHERE profile_id = ?1",
            params![id],
        )?;
        tx.execute(
            "DELETE FROM db_channel_order
             WHERE profile_id = ?1",
            params![id],
        )?;
        tx.execute(
            "DELETE FROM db_profile_source_access
             WHERE profile_id = ?1",
            params![id],
        )?;
        tx.execute(
            "DELETE FROM db_profiles
             WHERE id = ?1",
            params![id],
        )?;
        tx.commit()?;
        self.emit(DataChangeEvent::ProfileChanged {
            profile_id: id.to_string(),
        });
        Ok(())
    }

    /// Load all user profiles.
    pub fn load_profiles(&self) -> Result<Vec<UserProfile>, DbError> {
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT
                id, name, avatar_index, pin,
                is_child, pin_version,
                max_allowed_rating, role,
                dvr_permission, dvr_quota_mb
            FROM db_profiles",
        )?;
        let rows = stmt.query_map([], |row| {
            Ok(UserProfile {
                id: row.get(0)?,
                name: row.get(1)?,
                avatar_index: row.get(2)?,
                pin: row.get(3)?,
                is_child: int_to_bool(row.get(4)?),
                pin_version: row.get(5)?,
                max_allowed_rating: row.get(6)?,
                role: row.get(7)?,
                dvr_permission: row.get(8)?,
                dvr_quota_mb: row.get(9)?,
            })
        })?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    // ── Profile Source Access ────────────────────────

    /// Grant a profile access to a source.
    pub fn grant_source_access(&self, profile_id: &str, source_id: &str) -> Result<(), DbError> {
        let conn = self.db.get()?;
        let now = chrono::Utc::now().timestamp();
        conn.execute(
            "INSERT OR REPLACE INTO
             db_profile_source_access
             (profile_id, source_id, granted_at)
             VALUES (?1, ?2, ?3)",
            params![profile_id, source_id, now],
        )?;
        self.emit(DataChangeEvent::ProfileChanged {
            profile_id: profile_id.to_string(),
        });
        Ok(())
    }

    /// Revoke a profile's access to a source.
    pub fn revoke_source_access(&self, profile_id: &str, source_id: &str) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute(
            "DELETE FROM db_profile_source_access
             WHERE profile_id = ?1
             AND source_id = ?2",
            params![profile_id, source_id],
        )?;
        self.emit(DataChangeEvent::ProfileChanged {
            profile_id: profile_id.to_string(),
        });
        Ok(())
    }

    /// Get source IDs a profile has access to.
    pub fn get_source_access(&self, profile_id: &str) -> Result<Vec<String>, DbError> {
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT source_id
             FROM db_profile_source_access
             WHERE profile_id = ?1",
        )?;
        let rows = stmt.query_map(params![profile_id], |row| row.get(0))?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Replace all source access for a profile with
    /// the given list of source IDs.
    pub fn set_source_access(
        &self,
        profile_id: &str,
        source_ids: &[String],
    ) -> Result<(), DbError> {
        let conn = self.db.get()?;
        let tx = conn.unchecked_transaction()?;
        tx.execute(
            "DELETE FROM db_profile_source_access
             WHERE profile_id = ?1",
            params![profile_id],
        )?;
        let now = chrono::Utc::now().timestamp();
        for sid in source_ids {
            tx.execute(
                "INSERT INTO db_profile_source_access
                 (profile_id, source_id, granted_at)
                 VALUES (?1, ?2, ?3)",
                params![profile_id, sid, now],
            )?;
        }
        tx.commit()?;
        self.emit(DataChangeEvent::ProfileChanged {
            profile_id: profile_id.to_string(),
        });
        Ok(())
    }

    // ── Channel Order ───────────────────────────────

    /// Save custom channel order for a profile and
    /// group. Replaces any existing order.
    pub fn save_channel_order(
        &self,
        profile_id: &str,
        group_name: &str,
        channel_ids: &[String],
    ) -> Result<(), DbError> {
        let conn = self.db.get()?;
        let tx = conn.unchecked_transaction()?;
        tx.execute(
            "DELETE FROM db_channel_order
             WHERE profile_id = ?1
             AND group_name = ?2",
            params![profile_id, group_name],
        )?;
        for (i, cid) in channel_ids.iter().enumerate() {
            tx.execute(
                "INSERT INTO db_channel_order
                 (profile_id, group_name,
                  channel_id, sort_index)
                 VALUES (?1, ?2, ?3, ?4)",
                params![profile_id, group_name, cid, i as i32,],
            )?;
        }
        tx.commit()?;
        self.emit(DataChangeEvent::ChannelOrderChanged);
        Ok(())
    }

    /// Load channel order as channel_id -> sort_index.
    /// Returns `None` if no custom order exists.
    pub fn load_channel_order(
        &self,
        profile_id: &str,
        group_name: &str,
    ) -> Result<Option<HashMap<String, i32>>, DbError> {
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT channel_id, sort_index
             FROM db_channel_order
             WHERE profile_id = ?1
             AND group_name = ?2",
        )?;
        let rows = stmt.query_map(params![profile_id, group_name], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, i32>(1)?))
        })?;
        let mut map = HashMap::new();
        for r in rows {
            let (cid, idx) = r?;
            map.insert(cid, idx);
        }
        if map.is_empty() {
            Ok(None)
        } else {
            Ok(Some(map))
        }
    }

    /// Reset custom channel order for a profile and
    /// group (delete all entries).
    pub fn reset_channel_order(&self, profile_id: &str, group_name: &str) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute(
            "DELETE FROM db_channel_order
             WHERE profile_id = ?1
             AND group_name = ?2",
            params![profile_id, group_name],
        )?;
        self.emit(DataChangeEvent::ChannelOrderChanged);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use crate::services::test_helpers::*;

    #[test]
    fn profile_crud_and_cascade_delete() {
        let svc = make_service();
        let profile = make_profile("p1", "Alice");
        svc.save_profile(&profile).unwrap();

        let ch = make_channel("ch1", "Channel 1");
        svc.save_channels(&[ch]).unwrap();
        svc.add_favorite("p1", "ch1").unwrap();

        let profiles = svc.load_profiles().unwrap();
        assert_eq!(profiles.len(), 1);

        // Cascade delete removes favorites too.
        svc.delete_profile("p1").unwrap();
        let profiles = svc.load_profiles().unwrap();
        assert!(profiles.is_empty());
        let favs = svc.get_favorites("p1").unwrap();
        assert!(favs.is_empty());
    }

    #[test]
    fn emit_profile_changed_on_save() {
        use crate::events::serialize_event;
        use std::sync::{Arc, Mutex};
        let svc = make_service();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        svc.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
        svc.save_profile(&make_profile("p1", "Alice")).unwrap();
        let recorded = log.lock().unwrap();
        let last = recorded.last().unwrap();
        assert!(last.contains("ProfileChanged"), "{last}");
        assert!(last.contains("\"profile_id\":\"p1\""), "{last}");
    }

    #[test]
    fn source_access_crud() {
        let svc = make_service_with_fixtures();
        svc.save_profile(&make_profile("p1", "Alice")).unwrap();

        svc.grant_source_access("p1", "src1").unwrap();
        svc.grant_source_access("p1", "src2").unwrap();
        let access = svc.get_source_access("p1").unwrap();
        assert_eq!(access.len(), 2);

        svc.revoke_source_access("p1", "src1").unwrap();
        let access = svc.get_source_access("p1").unwrap();
        assert_eq!(access.len(), 1);
        assert_eq!(access[0], "src2");
    }

    #[test]
    fn set_source_access_replaces_all() {
        let svc = make_service_with_fixtures();
        svc.save_source(&make_source("src4", "Test Source 4", "m3u"))
            .unwrap();
        svc.save_profile(&make_profile("p1", "Alice")).unwrap();
        svc.grant_source_access("p1", "src1").unwrap();
        svc.grant_source_access("p1", "src2").unwrap();

        svc.set_source_access("p1", &["src3".to_string(), "src4".to_string()])
            .unwrap();
        let access = svc.get_source_access("p1").unwrap();
        assert_eq!(access.len(), 2);
        assert!(access.contains(&"src3".to_string()));
        assert!(access.contains(&"src4".to_string()));
    }

    #[test]
    fn channel_order_save_load_reset() {
        let svc = make_service();
        svc.save_profile(&make_profile("p1", "Alice")).unwrap();
        svc.save_channels(&[
            make_channel("ch1", "Ch1"),
            make_channel("ch2", "Ch2"),
            make_channel("ch3", "Ch3"),
        ])
        .unwrap();

        let order = vec!["ch3".to_string(), "ch1".to_string(), "ch2".to_string()];
        svc.save_channel_order("p1", "News", &order).unwrap();

        let loaded = svc.load_channel_order("p1", "News").unwrap();
        assert!(loaded.is_some());
        let map = loaded.unwrap();
        assert_eq!(map["ch3"], 0);
        assert_eq!(map["ch1"], 1);
        assert_eq!(map["ch2"], 2);

        svc.reset_channel_order("p1", "News").unwrap();
        let loaded = svc.load_channel_order("p1", "News").unwrap();
        assert!(loaded.is_none());
    }
}
