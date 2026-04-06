use rusqlite::params;

use super::{CrispyService, bool_to_int, dt_to_ts, int_to_bool, ts_to_dt};
use crate::database::DbError;
use crate::events::DataChangeEvent;
use crate::models::{Recording, StorageBackend, TransferTask};

impl CrispyService {
    // ── Recordings ──────────────────────────────────

    /// Save (insert) a recording.
    pub fn save_recording(&self, rec: &Recording) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute(
            "INSERT OR REPLACE INTO db_recordings (
                id, channel_id, channel_name,
                channel_logo_url, program_name,
                stream_url, start_time, end_time,
                status, file_path, file_size_bytes,
                is_recurring, recur_days,
                owner_profile_id, is_shared,
                remote_backend_id, remote_path
            ) VALUES (
                ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8,
                ?9, ?10, ?11, ?12, ?13, ?14, ?15,
                ?16, ?17
            )",
            params![
                rec.id,
                rec.channel_id,
                rec.channel_name,
                rec.channel_logo_url,
                rec.program_name,
                rec.stream_url,
                dt_to_ts(&rec.start_time),
                dt_to_ts(&rec.end_time),
                rec.status.as_str(),
                rec.file_path,
                rec.file_size_bytes,
                bool_to_int(rec.is_recurring),
                rec.recur_days,
                rec.owner_profile_id,
                bool_to_int(rec.is_shared),
                rec.remote_backend_id,
                rec.remote_path,
            ],
        )?;
        self.emit(DataChangeEvent::RecordingChanged {
            recording_id: rec.id.clone(),
        });
        Ok(())
    }

    /// Load all recordings.
    pub fn load_recordings(&self) -> Result<Vec<Recording>, DbError> {
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT
                id, channel_id, channel_name,
                channel_logo_url, program_name,
                stream_url, start_time, end_time,
                status, file_path, file_size_bytes,
                is_recurring, recur_days,
                owner_profile_id, is_shared,
                remote_backend_id, remote_path
            FROM db_recordings",
        )?;
        let rows = stmt.query_map([], |row| {
            Ok(Recording {
                id: row.get(0)?,
                channel_id: row.get(1)?,
                channel_name: row.get(2)?,
                channel_logo_url: row.get(3)?,
                program_name: row.get(4)?,
                stream_url: row.get(5)?,
                start_time: ts_to_dt(row.get(6)?),
                end_time: ts_to_dt(row.get(7)?),
                status: row
                    .get::<_, String>(8)?
                    .as_str()
                    .try_into()
                    .unwrap_or_default(),
                file_path: row.get(9)?,
                file_size_bytes: row.get(10)?,
                is_recurring: int_to_bool(row.get(11)?),
                recur_days: row.get(12)?,
                owner_profile_id: row.get(13)?,
                is_shared: int_to_bool(row.get(14)?),
                remote_backend_id: row.get(15)?,
                remote_path: row.get(16)?,
            })
        })?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    pub fn update_recording(&self, rec: &Recording) -> Result<(), DbError> {
        self.save_recording(rec)
    }

    /// Delete a recording by ID.
    pub fn delete_recording(&self, id: &str) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute(
            "DELETE FROM db_recordings
             WHERE id = ?1",
            params![id],
        )?;
        self.emit(DataChangeEvent::RecordingChanged {
            recording_id: id.to_string(),
        });
        Ok(())
    }

    // ── Storage Backends ────────────────────────────

    /// Save (upsert) a storage backend.
    pub fn save_storage_backend(&self, backend: &StorageBackend) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute(
            "INSERT OR REPLACE INTO
             db_storage_backends (
                 id, name, type, config, is_default
             ) VALUES (?1, ?2, ?3, ?4, ?5)",
            params![
                backend.id,
                backend.name,
                backend.backend_type,
                backend.config,
                bool_to_int(backend.is_default),
            ],
        )?;
        self.emit(DataChangeEvent::StorageBackendChanged {
            backend_id: backend.id.clone(),
        });
        Ok(())
    }

    /// Load all storage backends.
    pub fn load_storage_backends(&self) -> Result<Vec<StorageBackend>, DbError> {
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT id, name, type, config, is_default
             FROM db_storage_backends",
        )?;
        let rows = stmt.query_map([], |row| {
            Ok(StorageBackend {
                id: row.get(0)?,
                name: row.get(1)?,
                backend_type: row.get(2)?,
                config: row.get(3)?,
                is_default: int_to_bool(row.get(4)?),
            })
        })?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Delete a storage backend by ID.
    pub fn delete_storage_backend(&self, id: &str) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute(
            "DELETE FROM db_storage_backends
             WHERE id = ?1",
            params![id],
        )?;
        self.emit(DataChangeEvent::StorageBackendChanged {
            backend_id: id.to_string(),
        });
        Ok(())
    }

    // ── Transfer Tasks ──────────────────────────────

    /// Save (insert) a transfer task.
    pub fn save_transfer_task(&self, task: &TransferTask) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute(
            "INSERT OR REPLACE INTO
             db_transfer_tasks (
                 id, recording_id, backend_id,
                 direction, status, total_bytes,
                 transferred_bytes, created_at,
                 error_message, remote_path
             ) VALUES (
                 ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8,
                 ?9, ?10
             )",
            params![
                task.id,
                task.recording_id,
                task.backend_id,
                task.direction,
                task.status,
                task.total_bytes,
                task.transferred_bytes,
                dt_to_ts(&task.created_at),
                task.error_message,
                task.remote_path,
            ],
        )?;
        self.emit(DataChangeEvent::TransferTaskChanged {
            task_id: task.id.clone(),
        });
        Ok(())
    }

    /// Load all transfer tasks.
    pub fn load_transfer_tasks(&self) -> Result<Vec<TransferTask>, DbError> {
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT
                id, recording_id, backend_id,
                direction, status, total_bytes,
                transferred_bytes, created_at,
                error_message, remote_path
            FROM db_transfer_tasks",
        )?;
        let rows = stmt.query_map([], |row| {
            Ok(TransferTask {
                id: row.get(0)?,
                recording_id: row.get(1)?,
                backend_id: row.get(2)?,
                direction: row.get(3)?,
                status: row.get(4)?,
                total_bytes: row.get(5)?,
                transferred_bytes: row.get(6)?,
                created_at: ts_to_dt(row.get(7)?),
                error_message: row.get(8)?,
                remote_path: row.get(9)?,
            })
        })?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    pub fn update_transfer_task(&self, task: &TransferTask) -> Result<(), DbError> {
        self.save_transfer_task(task)
    }

    /// Delete a transfer task by ID.
    pub fn delete_transfer_task(&self, id: &str) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute(
            "DELETE FROM db_transfer_tasks
             WHERE id = ?1",
            params![id],
        )?;
        self.emit(DataChangeEvent::TransferTaskChanged {
            task_id: id.to_string(),
        });
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::services::test_helpers::*;

    /// Create a service with fixtures and seed channel "ch1" for recording FK.
    fn make_dvr_service() -> crate::services::CrispyService {
        let svc = make_service_with_fixtures();
        svc.save_channels(&[make_channel("ch1", "Channel 1")])
            .unwrap();
        svc
    }

    fn make_recording(id: &str) -> Recording {
        let dt = parse_dt("2025-01-15 12:00:00");
        let dt_end = parse_dt("2025-01-15 13:00:00");
        Recording {
            id: id.to_string(),
            channel_id: Some("ch1".to_string()),
            channel_name: "Channel 1".to_string(),
            channel_logo_url: None,
            program_name: "Show".to_string(),
            stream_url: Some("http://stream".to_string()),
            start_time: dt,
            end_time: dt_end,
            status: crate::value_objects::RecordingStatus::Scheduled,
            file_path: None,
            file_size_bytes: None,
            is_recurring: false,
            recur_days: 0,
            owner_profile_id: None,
            is_shared: false,
            remote_backend_id: None,
            remote_path: None,
        }
    }

    fn make_storage_backend(id: &str) -> StorageBackend {
        StorageBackend {
            id: id.to_string(),
            name: format!("Backend {id}"),
            backend_type: "local".to_string(),
            config: "{}".to_string(),
            is_default: false,
        }
    }

    fn make_transfer_task(id: &str, recording_id: &str) -> TransferTask {
        TransferTask {
            id: id.to_string(),
            recording_id: recording_id.to_string(),
            backend_id: "b1".to_string(),
            direction: "upload".to_string(),
            status: "pending".to_string(),
            total_bytes: 1024,
            transferred_bytes: 0,
            created_at: parse_dt("2025-01-15 12:00:00"),
            error_message: None,
            remote_path: None,
        }
    }

    #[test]
    fn recordings_crud() {
        let svc = make_dvr_service();

        svc.save_recording(&make_recording("rec1")).unwrap();
        svc.save_recording(&make_recording("rec2")).unwrap();

        let loaded = svc.load_recordings().unwrap();
        assert_eq!(loaded.len(), 2);

        svc.delete_recording("rec1").unwrap();
        let loaded = svc.load_recordings().unwrap();
        assert_eq!(loaded.len(), 1);
        assert_eq!(loaded[0].id, "rec2");
    }

    #[test]
    fn recording_upsert_via_update() {
        let svc = make_dvr_service();
        let mut rec = make_recording("rec1");
        svc.save_recording(&rec).unwrap();

        rec.status = crate::value_objects::RecordingStatus::Completed;
        svc.update_recording(&rec).unwrap();

        let loaded = svc.load_recordings().unwrap();
        assert_eq!(loaded.len(), 1);
        assert_eq!(
            loaded[0].status,
            crate::value_objects::RecordingStatus::Completed
        );
    }

    #[test]
    fn storage_backends_crud() {
        let svc = make_dvr_service();

        svc.save_storage_backend(&make_storage_backend("b1"))
            .unwrap();
        svc.save_storage_backend(&make_storage_backend("b2"))
            .unwrap();

        let loaded = svc.load_storage_backends().unwrap();
        assert_eq!(loaded.len(), 2);

        svc.delete_storage_backend("b1").unwrap();
        let loaded = svc.load_storage_backends().unwrap();
        assert_eq!(loaded.len(), 1);
        assert_eq!(loaded[0].id, "b2");
    }

    #[test]
    fn transfer_tasks_crud() {
        let svc = make_dvr_service();
        svc.save_recording(&make_recording("rec1")).unwrap();
        svc.save_storage_backend(&make_storage_backend("b1"))
            .unwrap();

        svc.save_transfer_task(&make_transfer_task("t1", "rec1"))
            .unwrap();
        svc.save_transfer_task(&make_transfer_task("t2", "rec1"))
            .unwrap();

        let loaded = svc.load_transfer_tasks().unwrap();
        assert_eq!(loaded.len(), 2);

        svc.delete_transfer_task("t1").unwrap();
        let loaded = svc.load_transfer_tasks().unwrap();
        assert_eq!(loaded.len(), 1);
        assert_eq!(loaded[0].id, "t2");
    }

    #[test]
    fn transfer_task_upsert_via_update() {
        let svc = make_dvr_service();
        svc.save_recording(&make_recording("rec1")).unwrap();
        svc.save_storage_backend(&make_storage_backend("b1"))
            .unwrap();
        let mut task = make_transfer_task("t1", "rec1");
        svc.save_transfer_task(&task).unwrap();

        task.status = "done".to_string();
        svc.update_transfer_task(&task).unwrap();

        let loaded = svc.load_transfer_tasks().unwrap();
        assert_eq!(loaded.len(), 1);
        assert_eq!(loaded[0].status, "done");
    }

    #[test]
    fn emit_recording_changed_on_save() {
        use crate::events::serialize_event;
        use std::sync::{Arc, Mutex};
        let svc = make_dvr_service();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        svc.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
        svc.save_recording(&make_recording("rec1")).unwrap();
        let recorded = log.lock().unwrap();
        let last = recorded.last().unwrap();
        assert!(last.contains("RecordingChanged"), "{last}");
        assert!(last.contains("\"recording_id\":\"rec1\""), "{last}");
    }

    #[test]
    fn emit_recording_changed_on_delete() {
        use crate::events::serialize_event;
        use std::sync::{Arc, Mutex};
        let svc = make_service();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        svc.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
        svc.delete_recording("rec-nonexistent").unwrap();
        let recorded = log.lock().unwrap();
        let last = recorded.last().unwrap();
        assert!(last.contains("RecordingChanged"), "{last}");
        assert!(
            last.contains("\"recording_id\":\"rec-nonexistent\""),
            "{last}"
        );
    }

    #[test]
    fn emit_storage_backend_changed_on_save() {
        use crate::events::serialize_event;
        use std::sync::{Arc, Mutex};
        let svc = make_service();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        svc.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
        svc.save_storage_backend(&make_storage_backend("sb1"))
            .unwrap();
        let recorded = log.lock().unwrap();
        let last = recorded.last().unwrap();
        assert!(last.contains("StorageBackendChanged"), "{last}");
        assert!(last.contains("\"backend_id\":\"sb1\""), "{last}");
    }

    #[test]
    fn emit_storage_backend_changed_on_delete() {
        use crate::events::serialize_event;
        use std::sync::{Arc, Mutex};
        let svc = make_service();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        svc.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
        svc.delete_storage_backend("sb-gone").unwrap();
        let recorded = log.lock().unwrap();
        let last = recorded.last().unwrap();
        assert!(last.contains("StorageBackendChanged"), "{last}");
        assert!(last.contains("\"backend_id\":\"sb-gone\""), "{last}");
    }

    #[test]
    fn emit_transfer_task_changed_on_save() {
        use crate::events::serialize_event;
        use std::sync::{Arc, Mutex};
        let svc = make_dvr_service();
        svc.save_recording(&make_recording("rec1")).unwrap();
        svc.save_storage_backend(&make_storage_backend("b1"))
            .unwrap();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        svc.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
        svc.save_transfer_task(&make_transfer_task("tt1", "rec1"))
            .unwrap();
        let recorded = log.lock().unwrap();
        let last = recorded.last().unwrap();
        assert!(last.contains("TransferTaskChanged"), "{last}");
        assert!(last.contains("\"task_id\":\"tt1\""), "{last}");
    }

    #[test]
    fn emit_transfer_task_changed_on_delete() {
        use crate::events::serialize_event;
        use std::sync::{Arc, Mutex};
        let svc = make_service();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        svc.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
        svc.delete_transfer_task("tt-gone").unwrap();
        let recorded = log.lock().unwrap();
        let last = recorded.last().unwrap();
        assert!(last.contains("TransferTaskChanged"), "{last}");
        assert!(last.contains("\"task_id\":\"tt-gone\""), "{last}");
    }
}
