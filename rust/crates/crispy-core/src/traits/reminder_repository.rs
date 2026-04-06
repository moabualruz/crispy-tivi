use crate::database::DbError;
use crate::models::Reminder;

/// Persistence contract for EPG reminders.
pub trait ReminderRepository {
    fn load_reminders(&self) -> Result<Vec<Reminder>, DbError>;
    fn save_reminder(&self, reminder: &Reminder) -> Result<(), DbError>;
    fn delete_reminder(&self, id: &str) -> Result<(), DbError>;
    fn clear_fired_reminders(&self) -> Result<(), DbError>;
    fn mark_reminder_fired(&self, id: &str) -> Result<(), DbError>;
}
