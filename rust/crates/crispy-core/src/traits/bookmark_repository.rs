use crate::errors::DomainError;
use crate::models::Bookmark;

/// Persistence contract for playback bookmarks.
pub trait BookmarkRepository {
    fn load_bookmarks(&self, content_id: &str) -> Result<Vec<Bookmark>, DomainError>;
    fn save_bookmark(&self, bookmark: &Bookmark) -> Result<(), DomainError>;
    fn delete_bookmark(&self, id: &str) -> Result<(), DomainError>;
    fn clear_bookmarks(&self, content_id: &str) -> Result<(), DomainError>;
}
