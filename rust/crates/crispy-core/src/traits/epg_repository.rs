use std::collections::HashMap;

use crate::database::DbError;
use crate::models::{Channel, EpgEntry};

/// Persistence contract for EPG (Electronic Programme Guide) entries.
pub trait EpgRepository {
    fn save_epg_entries(
        &self,
        entries: &HashMap<String, Vec<EpgEntry>>,
    ) -> Result<usize, DbError>;
    fn load_epg_entries(&self) -> Result<HashMap<String, Vec<EpgEntry>>, DbError>;
    fn get_epgs_for_channels(
        &self,
        channel_ids: &[String],
        start_time: i64,
        end_time: i64,
    ) -> Result<HashMap<String, Vec<EpgEntry>>, DbError>;
    fn get_epg_by_sources(
        &self,
        source_ids: &[String],
    ) -> Result<HashMap<String, Vec<EpgEntry>>, DbError>;
    fn generate_placeholders_for_channels(
        &self,
        channels: &[Channel],
    ) -> Result<usize, DbError>;
    fn get_real_epg_coverage_end(
        &self,
        channel_id: &str,
    ) -> Result<Option<i64>, DbError>;
    fn has_real_epg_coverage(
        &self,
        channel_id: &str,
        start_time: i64,
        end_time: i64,
    ) -> Result<bool, DbError>;
    fn evict_stale_epg(&self, days: i64) -> Result<usize, DbError>;
    fn clear_epg_entries(&self) -> Result<(), DbError>;
}
