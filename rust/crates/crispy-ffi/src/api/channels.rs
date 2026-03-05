use super::svc;
use anyhow::{Context, Result};
use crispy_core::models::Channel;
use std::collections::HashMap;

/// Load all channels as JSON array.
pub fn load_channels() -> Result<String> {
    let channels = svc()?.load_channels()?;
    Ok(serde_json::to_string(&channels)?)
}

/// Save channels from JSON array. Returns count.
pub fn save_channels(json: String) -> Result<usize> {
    let channels: Vec<Channel> = serde_json::from_str(&json).context("Invalid channel JSON")?;
    Ok(svc()?.save_channels(&channels)?)
}

/// Load channels filtered by source IDs. Returns JSON array.
///
/// Deserialises `source_ids_json` as `Vec<String>`. An empty
/// array returns ALL channels (same as `load_channels`).
pub fn get_channels_by_sources(source_ids_json: String) -> Result<String> {
    let ids: Vec<String> =
        serde_json::from_str(&source_ids_json).context("Invalid source_ids JSON")?;
    let channels = svc()?.get_channels_by_sources(&ids)?;
    Ok(serde_json::to_string(&channels)?)
}

/// Load channels by IDs. Returns JSON array.
pub fn get_channels_by_ids(ids: Vec<String>) -> Result<String> {
    let channels = svc()?.get_channels_by_ids(&ids)?;
    Ok(serde_json::to_string(&channels)?)
}

/// Delete channels not in keep_ids for a source.
/// Returns count deleted.
pub fn delete_removed_channels(source_id: String, keep_ids: Vec<String>) -> Result<usize> {
    Ok(svc()?.delete_removed_channels(&source_id, &keep_ids)?)
}

// ── Channel Favorites ────────────────────────────────

/// Get favourite channel IDs for a profile.
pub fn get_favorites(profile_id: String) -> Result<Vec<String>> {
    Ok(svc()?.get_favorites(&profile_id)?)
}

/// Add a channel to profile favourites.
pub fn add_favorite(profile_id: String, channel_id: String) -> Result<()> {
    Ok(svc()?.add_favorite(&profile_id, &channel_id)?)
}

/// Remove a channel from profile favourites.
pub fn remove_favorite(profile_id: String, channel_id: String) -> Result<()> {
    Ok(svc()?.remove_favorite(&profile_id, &channel_id)?)
}

// ── Categories ───────────────────────────────────────

/// Load categories filtered by source IDs as JSON object {type: [names]}.
///
/// Deserialises `source_ids_json` as `Vec<String>`. An empty
/// array returns ALL categories (same as `load_categories`).
pub fn get_categories_by_sources(source_ids_json: String) -> Result<String> {
    let ids: Vec<String> =
        serde_json::from_str(&source_ids_json).context("Invalid source_ids JSON")?;
    let cats = svc()?.get_categories_by_sources(&ids)?;
    Ok(serde_json::to_string(&cats)?)
}

/// Load categories as JSON object {type: [names]}.
pub fn load_categories() -> Result<String> {
    let cats = svc()?.load_categories()?;
    Ok(serde_json::to_string(&cats)?)
}

/// Save categories from JSON object {type: [names]}.
pub fn save_categories(json: String) -> Result<()> {
    let cats: HashMap<String, Vec<String>> =
        serde_json::from_str(&json).context("Invalid categories JSON")?;
    Ok(svc()?.save_categories(&cats)?)
}

// ── Favorite Categories ──────────────────────────────

/// Get favourite category names for profile + type.
pub fn get_favorite_categories(profile_id: String, category_type: String) -> Result<Vec<String>> {
    Ok(svc()?.get_favorite_categories(&profile_id, &category_type)?)
}

/// Add a category to profile favourites.
pub fn add_favorite_category(
    profile_id: String,
    category_type: String,
    category_name: String,
) -> Result<()> {
    Ok(svc()?.add_favorite_category(&profile_id, &category_type, &category_name)?)
}

/// Remove a category from profile favourites.
pub fn remove_favorite_category(
    profile_id: String,
    category_type: String,
    category_name: String,
) -> Result<()> {
    Ok(svc()?.remove_favorite_category(&profile_id, &category_type, &category_name)?)
}

// ── Channel Order ────────────────────────────────────

/// Save custom channel order for profile + group.
pub fn save_channel_order(
    profile_id: String,
    group_name: String,
    channel_ids: Vec<String>,
) -> Result<()> {
    Ok(svc()?.save_channel_order(&profile_id, &group_name, &channel_ids)?)
}

/// Load channel order as JSON {channel_id: index}
/// or null if no custom order.
pub fn load_channel_order(profile_id: String, group_name: String) -> Result<Option<String>> {
    let order = svc()?.load_channel_order(&profile_id, &group_name)?;
    match order {
        Some(map) => Ok(Some(serde_json::to_string(&map)?)),
        None => Ok(None),
    }
}

/// Reset channel order for profile + group.
pub fn reset_channel_order(profile_id: String, group_name: String) -> Result<()> {
    Ok(svc()?.reset_channel_order(&profile_id, &group_name)?)
}

// ── Channel Algorithms ───────────────────────────────

/// Sort channels by number then name (in-place).
/// Input/output: JSON array of Channel.
pub fn sort_channels_json(json: String) -> Result<String> {
    let mut channels: Vec<Channel> =
        serde_json::from_str(&json).context("Invalid channels JSON")?;
    crispy_core::algorithms::sorting::sort_channels(&mut channels);
    Ok(serde_json::to_string(&channels)?)
}

/// Resolve category IDs to names in channels.
/// Returns JSON array of Channel.
pub fn resolve_channel_categories(channels_json: String, cat_map_json: String) -> Result<String> {
    let channels: Vec<Channel> =
        serde_json::from_str(&channels_json).context("Invalid channels JSON")?;
    let cat_map: HashMap<String, String> =
        serde_json::from_str(&cat_map_json).context("Invalid cat map JSON")?;
    let resolved =
        crispy_core::algorithms::categories::resolve_channel_categories(&channels, &cat_map);
    Ok(serde_json::to_string(&resolved)?)
}

/// Extract unique sorted group names from channels.
pub fn extract_sorted_groups(channels_json: String) -> Result<Vec<String>> {
    let channels: Vec<Channel> =
        serde_json::from_str(&channels_json).context("Invalid channels JSON")?;
    Ok(crispy_core::algorithms::categories::extract_sorted_groups(
        &channels,
    ))
}

/// Find the duplicate group containing a channel.
/// Returns JSON of DuplicateGroup or null.
pub fn find_group_for_channel(groups_json: String, channel_id: String) -> Result<Option<String>> {
    let groups: Vec<crispy_core::algorithms::dedup::DuplicateGroup> =
        serde_json::from_str(&groups_json).context("Invalid groups JSON")?;
    match crispy_core::algorithms::dedup::find_group_for_channel(&groups, &channel_id) {
        Some(g) => Ok(Some(serde_json::to_string(g)?)),
        None => Ok(None),
    }
}

/// Filter channels by source access.
/// Returns JSON array of channels.
///
/// Note: returns `String` (not `Result`) because the underlying algorithm
/// returns a fallback empty array `[]` on parse errors rather than
/// propagating them. Changing to `Result` would require FRB codegen.
pub fn filter_channels_by_source(
    channels_json: String,
    accessible_source_ids_json: String,
    is_admin: bool,
) -> String {
    crispy_core::algorithms::source_filter::filter_channels_by_source(
        &channels_json,
        &accessible_source_ids_json,
        is_admin,
    )
}
