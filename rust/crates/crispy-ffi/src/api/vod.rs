use super::svc;
use anyhow::{Context, Result};
use crispy_core::models::VodItem;
use std::collections::HashMap;

/// Load all VOD items as JSON array.
pub fn load_vod_items() -> Result<String> {
    let items = svc()?.load_vod_items()?;
    Ok(serde_json::to_string(&items)?)
}

/// Save VOD items from JSON array. Returns count.
pub fn save_vod_items(json: String) -> Result<usize> {
    let items: Vec<VodItem> = serde_json::from_str(&json).context("Invalid VOD JSON")?;
    Ok(svc()?.save_vod_items(&items)?)
}

/// Load VOD items filtered by source IDs. Returns JSON array.
///
/// Deserialises `source_ids_json` as `Vec<String>`. An empty
/// array returns ALL VOD items (same as `load_vod_items`).
pub fn get_vod_by_sources(source_ids_json: String) -> Result<String> {
    let ids: Vec<String> =
        serde_json::from_str(&source_ids_json).context("Invalid source_ids JSON")?;
    let items = svc()?.get_vod_by_sources(&ids)?;
    Ok(serde_json::to_string(&items)?)
}

/// Delete VOD items not in keep_ids for a source.
pub fn delete_removed_vod_items(source_id: String, keep_ids: Vec<String>) -> Result<usize> {
    Ok(svc()?.delete_removed_vod_items(&source_id, &keep_ids)?)
}

// ── VOD Favorites ────────────────────────────────────

/// Get favourite VOD item IDs for a profile.
pub fn get_vod_favorites(profile_id: String) -> Result<Vec<String>> {
    Ok(svc()?.get_vod_favorites(&profile_id)?)
}

/// Add a VOD item to profile favourites.
pub fn add_vod_favorite(profile_id: String, vod_item_id: String) -> Result<()> {
    Ok(svc()?.add_vod_favorite(&profile_id, &vod_item_id)?)
}

/// Remove a VOD item from profile favourites.
pub fn remove_vod_favorite(profile_id: String, vod_item_id: String) -> Result<()> {
    Ok(svc()?.remove_vod_favorite(&profile_id, &vod_item_id)?)
}

/// Update the is_favorite flag on a VOD item.
pub fn update_vod_favorite(item_id: String, is_favorite: bool) -> Result<()> {
    Ok(svc()?.update_vod_favorite(&item_id, is_favorite)?)
}

// ── VOD Algorithms ───────────────────────────────────

/// Resolve category IDs to names in VOD items.
/// Returns JSON array of VodItem.
pub fn resolve_vod_categories(items_json: String, cat_map_json: String) -> Result<String> {
    let items: Vec<VodItem> =
        serde_json::from_str(&items_json).context("Invalid VOD items JSON")?;
    let cat_map: HashMap<String, String> =
        serde_json::from_str(&cat_map_json).context("Invalid cat map JSON")?;
    let resolved = crispy_core::algorithms::categories::resolve_vod_categories(&items, &cat_map);
    Ok(serde_json::to_string(&resolved)?)
}

/// Extract unique sorted category names from VOD.
pub fn extract_sorted_vod_categories(items_json: String) -> Result<Vec<String>> {
    let items: Vec<VodItem> =
        serde_json::from_str(&items_json).context("Invalid VOD items JSON")?;
    Ok(crispy_core::algorithms::categories::extract_sorted_vod_categories(&items))
}

/// Sort VOD items by the given criterion.
/// Input/output: JSON arrays of VodItem.
pub fn sort_vod_items(items_json: String, sort_by: String) -> String {
    crispy_core::algorithms::vod_sorting::sort_vod_items(&items_json, &sort_by)
}

/// Group VOD items by category.
/// Returns JSON VodCategoryMap.
pub fn build_vod_category_map(items_json: String) -> String {
    crispy_core::algorithms::vod_sorting::build_vod_category_map(&items_json)
}

/// Filter and rank top VOD items by rating.
/// Returns JSON array of VodItem.
pub fn filter_top_vod(items_json: String, limit: usize) -> String {
    crispy_core::algorithms::vod_sorting::filter_top_vod(&items_json, limit)
}

/// Compute per-episode progress for a series.
/// Returns JSON EpisodeProgressResult.
pub fn compute_episode_progress(history_json: String, series_id: String) -> String {
    crispy_core::algorithms::vod_sorting::compute_episode_progress(&history_json, &series_id)
}

/// Compute episode progress from DB for a series.
/// Returns JSON with progress_map + last_watched_url.
pub fn compute_episode_progress_from_db(series_id: String) -> Result<String> {
    let result = svc()?
        .compute_episode_progress_from_db(&series_id)
        .context("compute_episode_progress_from_db")?;
    Ok(result)
}

/// Filter VOD items by content rating.
/// Returns JSON array of allowed VodItem.
pub fn filter_vod_by_content_rating(items_json: String, max_rating_value: i32) -> String {
    crispy_core::algorithms::vod_sorting::filter_vod_by_content_rating(
        &items_json,
        max_rating_value,
    )
}
