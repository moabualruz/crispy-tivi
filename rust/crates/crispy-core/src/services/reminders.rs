use rusqlite::{Row, params};

use crate::insert_or_replace;
use super::{ServiceContext, bool_to_int, dt_to_ts, int_to_bool, ts_to_dt};
use crate::database::DbError;
use crate::errors::DomainError;
use crate::events::DataChangeEvent;
use crate::models::Reminder;
use crate::traits::ReminderRepository;

fn reminder_from_row(row: &Row) -> rusqlite::Result<Reminder> {
    Ok(Reminder {
        id: row.get(0)?,
        program_name: row.get(1)?,
        channel_name: row.get(2)?,
        start_time: ts_to_dt(row.get(3)?),
        notify_at: ts_to_dt(row.get(4)?),
        fired: int_to_bool(row.get(5)?),
        profile_id: row.get(6)?,
        created_at: ts_to_dt(row.get(7)?),
    })
}

/// Domain service for reminder operations.
pub struct ReminderService(pub ServiceContext);

impl ReminderService {
    // ── Reminders ─────────────────────────────────────

    /// Load all reminders ordered by notify_at
    /// ascending.
    pub fn load_reminders(&self) -> Result<Vec<Reminder>, DbError> {
        let conn = self.0.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT
                id, program_name, channel_name,
                start_time, notify_at, fired,
                profile_id, created_at
            FROM db_reminders
            ORDER BY notify_at ASC",
        )?;
        let rows = stmt.query_map([], reminder_from_row)?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Save (upsert) a reminder.
    pub fn save_reminder(&self, reminder: &Reminder) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        insert_or_replace!(
            conn,
            "db_reminders",
            [
                "id",
                "program_name",
                "channel_name",
                "start_time",
                "notify_at",
                "fired",
                "profile_id",
                "created_at",
            ],
            params![
                reminder.id,
                reminder.program_name,
                reminder.channel_name,
                dt_to_ts(&reminder.start_time),
                dt_to_ts(&reminder.notify_at),
                bool_to_int(reminder.fired),
                reminder.profile_id,
                dt_to_ts(&reminder.created_at),
            ],
        )?;
        self.0.emit(DataChangeEvent::ReminderChanged);
        Ok(())
    }

    /// Delete a reminder by ID.
    pub fn delete_reminder(&self, id: &str) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        conn.execute(
            "DELETE FROM db_reminders
             WHERE id = ?1",
            params![id],
        )?;
        self.0.emit(DataChangeEvent::ReminderChanged);
        Ok(())
    }

    /// Delete all fired reminders.
    pub fn clear_fired_reminders(&self) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        conn.execute(
            "DELETE FROM db_reminders
             WHERE fired = 1",
            [],
        )?;
        self.0.emit(DataChangeEvent::ReminderChanged);
        Ok(())
    }

    /// Mark a reminder as fired (direct update).
    pub fn mark_reminder_fired(&self, id: &str) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        conn.execute(
            "UPDATE db_reminders
             SET fired = 1
             WHERE id = ?1",
            params![id],
        )?;
        self.0.emit(DataChangeEvent::ReminderChanged);
        Ok(())
    }
}

impl ReminderRepository for ReminderService {
    fn load_reminders(&self) -> Result<Vec<Reminder>, DomainError> {
        Ok(self.load_reminders()?)
    }

    fn save_reminder(&self, reminder: &Reminder) -> Result<(), DomainError> {
        Ok(self.save_reminder(reminder)?)
    }

    fn delete_reminder(&self, id: &str) -> Result<(), DomainError> {
        Ok(self.delete_reminder(id)?)
    }

    fn clear_fired_reminders(&self) -> Result<(), DomainError> {
        Ok(self.clear_fired_reminders()?)
    }

    fn mark_reminder_fired(&self, id: &str) -> Result<(), DomainError> {
        Ok(self.mark_reminder_fired(id)?)
    }
}

#[cfg(test)]
mod tests {
    use crate::services::test_helpers::*;
    use super::ReminderService;

    fn make_reminder(id: &str, fired: bool) -> crate::models::Reminder {
        let dt = parse_dt("2025-01-15 12:00:00");
        crate::models::Reminder {
            id: id.to_string(),
            program_name: "News at 9".to_string(),
            channel_name: "CNN".to_string(),
            start_time: dt,
            notify_at: dt,
            fired,
            profile_id: Some("p1".to_string()),
            created_at: dt,
        }
    }

    #[test]
    fn reminders_crud() {
        let base = make_service();
        crate::services::ProfileService(base.clone())
            .save_profile(&make_profile("p1", "Test"))
            .unwrap();
        let svc = ReminderService(base);

        let reminders = svc.load_reminders().unwrap();
        assert!(reminders.is_empty());

        svc.save_reminder(&make_reminder("r1", false)).unwrap();
        svc.save_reminder(&make_reminder("r2", false)).unwrap();

        let reminders = svc.load_reminders().unwrap();
        assert_eq!(reminders.len(), 2);

        svc.delete_reminder("r1").unwrap();
        let reminders = svc.load_reminders().unwrap();
        assert_eq!(reminders.len(), 1);
        assert_eq!(reminders[0].id, "r2");
    }

    #[test]
    fn reminders_upsert() {
        let base = make_service();
        crate::services::ProfileService(base.clone())
            .save_profile(&make_profile("p1", "Test"))
            .unwrap();
        let svc = ReminderService(base);
        let mut reminder = make_reminder("r1", false);
        svc.save_reminder(&reminder).unwrap();

        reminder.program_name = "Updated Show".to_string();
        svc.save_reminder(&reminder).unwrap();

        let reminders = svc.load_reminders().unwrap();
        assert_eq!(reminders.len(), 1);
        assert_eq!(reminders[0].program_name, "Updated Show",);
    }

    #[test]
    fn clear_fired_reminders() {
        let base = make_service();
        crate::services::ProfileService(base.clone())
            .save_profile(&make_profile("p1", "Test"))
            .unwrap();
        let svc = ReminderService(base);
        svc.save_reminder(&make_reminder("r1", true)).unwrap();
        svc.save_reminder(&make_reminder("r2", false)).unwrap();
        svc.save_reminder(&make_reminder("r3", true)).unwrap();

        svc.clear_fired_reminders().unwrap();

        let reminders = svc.load_reminders().unwrap();
        assert_eq!(reminders.len(), 1);
        assert_eq!(reminders[0].id, "r2");
        assert!(!reminders[0].fired);
    }

    #[test]
    fn mark_reminder_fired_updates() {
        let base = make_service();
        crate::services::ProfileService(base.clone())
            .save_profile(&make_profile("p1", "Test"))
            .unwrap();
        let svc = ReminderService(base);
        svc.save_reminder(&make_reminder("r1", false)).unwrap();

        svc.mark_reminder_fired("r1").unwrap();

        let reminders = svc.load_reminders().unwrap();
        assert_eq!(reminders.len(), 1);
        assert!(reminders[0].fired);
    }

    #[test]
    fn mark_reminder_fired_nonexistent() {
        let svc = ReminderService(make_service());
        svc.mark_reminder_fired("nonexistent").unwrap();
    }
}
