use crate::errors::DomainError;
use crate::models::{Source, SourceStats};

/// Persistence contract for IPTV sources.
pub trait SourceRepository {
    fn get_sources(&self) -> Result<Vec<Source>, DomainError>;
    fn get_source(&self, id: &str) -> Result<Option<Source>, DomainError>;
    fn save_source(&self, source: &Source) -> Result<(), DomainError>;
    fn delete_source(&self, id: &str) -> Result<(), DomainError>;
    fn reorder_sources(&self, source_ids: &[String]) -> Result<(), DomainError>;
    fn get_source_stats(&self) -> Result<Vec<SourceStats>, DomainError>;
    fn update_source_sync_status(
        &self,
        id: &str,
        status: &str,
        error: Option<&str>,
        sync_time: Option<chrono::NaiveDateTime>,
    ) -> Result<(), DomainError>;
}
