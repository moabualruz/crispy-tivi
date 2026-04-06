use crate::database::DbError;
use crate::models::WatchHistory;

/// Persistence contract for watch history.
pub trait HistoryRepository {
    fn save_watch_history(&self, entry: &WatchHistory) -> Result<(), DbError>;
    fn load_watch_history(&self) -> Result<Vec<WatchHistory>, DbError>;
    fn load_watch_history_for_profile(
        &self,
        profile_id: &str,
    ) -> Result<Vec<WatchHistory>, DbError>;
    fn compute_episode_progress_from_db(
        &self,
        series_id: &str,
    ) -> Result<String, DbError>;
    fn delete_watch_history(&self, id: &str) -> Result<(), DbError>;
}
