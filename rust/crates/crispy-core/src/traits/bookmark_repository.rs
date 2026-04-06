use crate::database::DbError;
use crate::models::Bookmark;

/// Persistence contract for playback bookmarks.
pub trait BookmarkRepository {
    fn load_bookmarks(&self, content_id: &str) -> Result<Vec<Bookmark>, DbError>;
    fn save_bookmark(&self, bookmark: &Bookmark) -> Result<(), DbError>;
    fn delete_bookmark(&self, id: &str) -> Result<(), DbError>;
    fn clear_bookmarks(&self, content_id: &str) -> Result<(), DbError>;
}
