use crate::errors::DomainError;
use crate::models::Reminder;

/// Persistence contract for EPG reminders.
pub trait ReminderRepository {
    fn load_reminders(&self) -> Result<Vec<Reminder>, DomainError>;
    fn save_reminder(&self, reminder: &Reminder) -> Result<(), DomainError>;
    fn delete_reminder(&self, id: &str) -> Result<(), DomainError>;
    fn clear_fired_reminders(&self) -> Result<(), DomainError>;
    fn mark_reminder_fired(&self, id: &str) -> Result<(), DomainError>;
}
