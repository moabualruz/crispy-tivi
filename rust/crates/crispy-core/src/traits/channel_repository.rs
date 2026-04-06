use crate::errors::DomainError;
use crate::models::Channel;

/// Persistence contract for live channels and channel favorites.
pub trait ChannelRepository {
    fn save_channels(&self, channels: &[Channel]) -> Result<usize, DomainError>;
    fn load_channels(&self) -> Result<Vec<Channel>, DomainError>;
    fn get_channels_by_sources(
        &self,
        source_ids: &[String],
    ) -> Result<Vec<Channel>, DomainError>;
    fn get_channels_by_ids(&self, ids: &[String]) -> Result<Vec<Channel>, DomainError>;
    fn delete_removed_channels(
        &self,
        source_id: &str,
        keep_ids: &[String],
    ) -> Result<usize, DomainError>;
    fn get_favorites(&self, profile_id: &str) -> Result<Vec<String>, DomainError>;
    fn add_favorite(&self, profile_id: &str, channel_id: &str) -> Result<(), DomainError>;
    fn remove_favorite(
        &self,
        profile_id: &str,
        channel_id: &str,
    ) -> Result<(), DomainError>;
}
