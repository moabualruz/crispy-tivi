use super::{from_json, json_result, svc};
use anyhow::Result;

/// Load all bookmarks for a content item as JSON.
pub fn load_bookmarks(content_id: String) -> Result<String> {
    json_result(svc()?.load_bookmarks(&content_id)?)
}

/// Save a bookmark from JSON.
pub fn save_bookmark(json: String) -> Result<()> {
    let bm: crispy_core::models::Bookmark = from_json(&json)?;
    Ok(svc()?.save_bookmark(&bm)?)
}

/// Delete a bookmark by ID.
pub fn delete_bookmark(id: String) -> Result<()> {
    Ok(svc()?.delete_bookmark(&id)?)
}

/// Clear all bookmarks for a content item.
pub fn clear_bookmarks(content_id: String) -> Result<()> {
    Ok(svc()?.clear_bookmarks(&content_id)?)
}
