use crate::errors::DomainError;
use crate::models::VodItem;

/// Persistence contract for VOD items and VOD favorites.
pub trait VodRepository {
    fn save_vod_items(&self, items: &[VodItem]) -> Result<usize, DomainError>;
    fn load_vod_items(&self) -> Result<Vec<VodItem>, DomainError>;
    fn get_vod_by_sources(&self, source_ids: &[String]) -> Result<Vec<VodItem>, DomainError>;
    fn get_filtered_vod(
        &self,
        source_ids: &[String],
        item_type: Option<&str>,
        category: Option<&str>,
        query: Option<&str>,
        sort_by: &str,
    ) -> Result<Vec<VodItem>, DomainError>;
    fn find_vod_alternatives(
        &self,
        name: &str,
        year: Option<i32>,
        exclude_id: &str,
        limit: usize,
    ) -> Result<Vec<VodItem>, DomainError>;
    fn delete_removed_vod_items(
        &self,
        source_id: &str,
        keep_ids: &[String],
    ) -> Result<usize, DomainError>;
    fn get_vod_favorites(&self, profile_id: &str) -> Result<Vec<String>, DomainError>;
    fn add_vod_favorite(&self, profile_id: &str, vod_item_id: &str) -> Result<(), DomainError>;
    fn remove_vod_favorite(&self, profile_id: &str, vod_item_id: &str) -> Result<(), DomainError>;
}
