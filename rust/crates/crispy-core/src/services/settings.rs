use chrono::NaiveDateTime;
use rusqlite::params;

use super::{ServiceContext, dt_to_ts, ts_to_dt};
use crate::database::{DbError, optional};
use crate::errors::DomainError;
use crate::traits::SettingsRepository;

/// Domain service for settings and sync metadata.
pub struct SettingsService(pub ServiceContext);

impl SettingsService {
    // ── Sync Meta ───────────────────────────────────
    // last_sync_time is stored directly on db_sources (db_sync_meta removed, D-5 cleanup).

    /// Set the last sync time for a source.
    pub fn set_last_sync_time(&self, source_id: &str, time: NaiveDateTime) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        conn.execute(
            "UPDATE db_sources SET last_sync_time = ?1 WHERE id = ?2",
            params![dt_to_ts(&time), source_id],
        )?;
        Ok(())
    }

    /// Get the last sync time for a source.
    pub fn get_last_sync_time(&self, source_id: &str) -> Result<Option<NaiveDateTime>, DbError> {
        let conn = self.0.db.get()?;
        let result = conn.query_row(
            "SELECT last_sync_time FROM db_sources WHERE id = ?1",
            params![source_id],
            |row| row.get::<_, Option<i64>>(0),
        );
        Ok(optional(result)?.and_then(|ts| ts.map(ts_to_dt)))
    }
}

impl SettingsRepository for SettingsService {
    fn get_setting(&self, key: &str) -> Result<Option<String>, DomainError> {
        Ok(self.0.get_setting(key)?)
    }

    fn set_setting(&self, key: &str, value: &str) -> Result<(), DomainError> {
        Ok(self.0.set_setting(key, value)?)
    }

    fn remove_setting(&self, key: &str) -> Result<(), DomainError> {
        Ok(self.0.remove_setting(key)?)
    }

    fn set_last_sync_time(&self, source_id: &str, time: NaiveDateTime) -> Result<(), DomainError> {
        Ok(self.set_last_sync_time(source_id, time)?)
    }

    fn get_last_sync_time(&self, source_id: &str) -> Result<Option<NaiveDateTime>, DomainError> {
        Ok(self.get_last_sync_time(source_id)?)
    }
}

#[cfg(test)]
mod tests {
    use super::SettingsService;
    use crate::services::test_helpers::*;

    #[test]
    fn settings_crud() {
        let svc = make_service();

        // Initially empty.
        assert_eq!(svc.get_setting("theme").unwrap(), None,);

        // Set.
        svc.set_setting("theme", "dark").unwrap();
        assert_eq!(svc.get_setting("theme").unwrap(), Some("dark".to_string()),);

        // Overwrite.
        svc.set_setting("theme", "light").unwrap();
        assert_eq!(svc.get_setting("theme").unwrap(), Some("light".to_string()),);

        // Remove.
        svc.remove_setting("theme").unwrap();
        assert_eq!(svc.get_setting("theme").unwrap(), None,);
    }

    #[test]
    fn sync_meta_set_and_get() {
        let svc = SettingsService(make_service_with_fixtures());
        let dt = parse_dt("2025-01-15 12:00:00");

        svc.set_last_sync_time("src1", dt).unwrap();
        let loaded = svc.get_last_sync_time("src1").unwrap();
        assert!(loaded.is_some());
        // Timestamps are stored as seconds — compare at second granularity.
        assert_eq!(
            loaded.unwrap().and_utc().timestamp(),
            dt.and_utc().timestamp()
        );
    }

    #[test]
    fn sync_meta_missing_returns_none() {
        let svc = SettingsService(make_service());
        let loaded = svc.get_last_sync_time("nonexistent").unwrap();
        assert!(loaded.is_none());
    }

    #[test]
    fn emit_settings_updated_on_set() {
        use crate::events::serialize_event;
        use std::sync::{Arc, Mutex};
        let svc = make_service();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        svc.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
        svc.set_setting("theme", "dark").unwrap();
        let recorded = log.lock().unwrap();
        let last = recorded.last().unwrap();
        assert!(last.contains("SettingsUpdated"), "{last}");
        assert!(last.contains("\"key\":\"theme\""), "{last}");
    }

    #[test]
    fn no_event_emitted_without_callback() {
        // Verify no panic when no callback is set.
        let svc = make_service();
        crate::services::ProfileService(svc.clone())
            .save_profile(&make_profile("p1", "Alice"))
            .unwrap();
        svc.set_setting("k", "v").unwrap();
        // If we get here without panic, the test passes.
    }

    #[test]
    fn clone_shares_callback() {
        use crate::events::serialize_event;
        use std::sync::{Arc, Mutex};
        let svc = make_service();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        svc.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
        // Clone shares the same Arc<Mutex<Option<EventCallback>>>.
        let svc2 = svc.clone();
        svc2.set_setting("via_clone", "yes").unwrap();
        let recorded = log.lock().unwrap();
        let last = recorded.last().unwrap();
        assert!(last.contains("SettingsUpdated"), "{last}");
        assert!(last.contains("\"key\":\"via_clone\""), "{last}");
    }
}
