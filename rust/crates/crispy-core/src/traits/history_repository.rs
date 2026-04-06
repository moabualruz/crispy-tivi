use crate::errors::DomainError;
use crate::models::WatchHistory;

/// Persistence contract for watch history.
pub trait HistoryRepository {
    fn save_watch_history(&self, entry: &WatchHistory) -> Result<(), DomainError>;
    fn load_watch_history(&self) -> Result<Vec<WatchHistory>, DomainError>;
    fn load_watch_history_for_profile(
        &self,
        profile_id: &str,
    ) -> Result<Vec<WatchHistory>, DomainError>;
    fn compute_episode_progress_from_db(
        &self,
        series_id: &str,
    ) -> Result<String, DomainError>;
    fn delete_watch_history(&self, id: &str) -> Result<(), DomainError>;
}
