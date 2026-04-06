use crate::database::DbError;
use crate::models::{Source, SourceStats};

/// Persistence contract for IPTV sources.
pub trait SourceRepository {
    fn get_sources(&self) -> Result<Vec<Source>, DbError>;
    fn get_source(&self, id: &str) -> Result<Option<Source>, DbError>;
    fn save_source(&self, source: &Source) -> Result<(), DbError>;
    fn delete_source(&self, id: &str) -> Result<(), DbError>;
    fn reorder_sources(&self, source_ids: &[String]) -> Result<(), DbError>;
    fn get_source_stats(&self) -> Result<Vec<SourceStats>, DbError>;
    fn update_source_sync_status(
        &self,
        id: &str,
        status: &str,
        error: Option<&str>,
        sync_time: Option<chrono::NaiveDateTime>,
    ) -> Result<(), DbError>;
}
