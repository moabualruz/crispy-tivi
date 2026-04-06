use chrono::NaiveDateTime;

use crate::errors::DomainError;

/// Persistence contract for key-value settings and sync metadata.
pub trait SettingsRepository {
    fn get_setting(&self, key: &str) -> Result<Option<String>, DomainError>;
    fn set_setting(&self, key: &str, value: &str) -> Result<(), DomainError>;
    fn remove_setting(&self, key: &str) -> Result<(), DomainError>;
    fn set_last_sync_time(
        &self,
        source_id: &str,
        time: NaiveDateTime,
    ) -> Result<(), DomainError>;
    fn get_last_sync_time(
        &self,
        source_id: &str,
    ) -> Result<Option<NaiveDateTime>, DomainError>;
}
