use super::{ctx, from_json, json_result};
use anyhow::Result;
use crispy_core::models::Channel;
use crispy_core::services::{CategoryService, ChannelService, ProfileService};
use std::collections::HashMap;

/// Load all channels as JSON array.
pub fn load_channels() -> Result<String> {
    json_result(ChannelService(ctx()?).load_channels()?)
}

/// Save channels from JSON array. Returns count.
pub fn save_channels(json: String) -> Result<usize> {
    let channels: Vec<Channel> = from_json(&json)?;
    Ok(ChannelService(ctx()?).save_channels(&channels)?)
}

/// Load channels filtered by source IDs. Returns JSON array.
///
/// Deserialises `source_ids_json` as `Vec<String>`. An empty
/// array returns ALL channels (same as `load_channels`).
pub fn get_channels_by_sources(source_ids_json: String) -> Result<String> {
    let ids: Vec<String> = from_json(&source_ids_json)?;
    json_result(ChannelService(ctx()?).get_channels_by_sources(&ids)?)
}

/// Load channels by IDs. Returns JSON array.
pub fn get_channels_by_ids(ids: Vec<String>) -> Result<String> {
    json_result(ChannelService(ctx()?).get_channels_by_ids(&ids)?)
}

/// Load channel groups with item counts filtered by source IDs.
pub fn get_channel_groups(source_ids_json: String) -> Result<String> {
    let source_ids: Vec<String> = from_json(&source_ids_json)?;
    json_result(ChannelService(ctx()?).get_channel_groups(&source_ids)?)
}

/// Load a page of channels filtered by source IDs and group.
pub fn get_channels_page(
    source_ids_json: String,
    group: Option<String>,
    sort: String,
    offset: i64,
    limit: i64,
) -> Result<String> {
    let source_ids: Vec<String> = from_json(&source_ids_json)?;
    json_result(ChannelService(ctx()?).get_channels_page(
        &source_ids,
        group.as_deref(),
        &sort,
        offset,
        limit,
    )?)
}

/// Count channels filtered by source IDs and group.
pub fn get_channel_count(source_ids_json: String, group: Option<String>) -> Result<i64> {
    let source_ids: Vec<String> = from_json(&source_ids_json)?;
    Ok(ChannelService(ctx()?).get_channel_count(&source_ids, group.as_deref())?)
}

/// Load ordered channel IDs for a group filtered by source IDs.
pub fn get_channel_ids_for_group(
    source_ids_json: String,
    group: Option<String>,
    sort: String,
) -> Result<String> {
    let source_ids: Vec<String> = from_json(&source_ids_json)?;
    json_result(ChannelService(ctx()?).get_channel_ids_for_group(
        &source_ids,
        group.as_deref(),
        &sort,
    )?)
}

/// Load a single channel by ID. Returns JSON object or null.
pub fn get_channel_by_id(id: String) -> Result<String> {
    json_result(ChannelService(ctx()?).get_channel_by_id(&id)?)
}

/// Load favourite channels for a profile filtered by source IDs.
pub fn get_favorite_channels(source_ids_json: String, profile_id: String) -> Result<String> {
    let source_ids: Vec<String> = from_json(&source_ids_json)?;
    json_result(ChannelService(ctx()?).get_favorite_channels(&source_ids, &profile_id)?)
}

/// Search channels by query with pagination.
pub fn search_channels(
    query: String,
    source_ids_json: String,
    offset: i64,
    limit: i64,
) -> Result<String> {
    let source_ids: Vec<String> = from_json(&source_ids_json)?;
    json_result(ChannelService(ctx()?).search_channels(&query, &source_ids, offset, limit)?)
}

/// Delete channels not in keep_ids for a source.
/// Returns count deleted.
pub fn delete_removed_channels(source_id: String, keep_ids: Vec<String>) -> Result<usize> {
    Ok(ChannelService(ctx()?).delete_removed_channels(&source_id, &keep_ids)?)
}

// ── Channel Favorites ────────────────────────────────

/// Get favourite channel IDs for a profile.
pub fn get_favorites(profile_id: String) -> Result<Vec<String>> {
    Ok(ChannelService(ctx()?).get_favorites(&profile_id)?)
}

/// Add a channel to profile favourites.
pub fn add_favorite(profile_id: String, channel_id: String) -> Result<()> {
    Ok(ChannelService(ctx()?).add_favorite(&profile_id, &channel_id)?)
}

/// Remove a channel from profile favourites.
pub fn remove_favorite(profile_id: String, channel_id: String) -> Result<()> {
    Ok(ChannelService(ctx()?).remove_favorite(&profile_id, &channel_id)?)
}

// ── Categories ───────────────────────────────────────

/// Load categories filtered by source IDs as JSON object {type: [names]}.
///
/// Deserialises `source_ids_json` as `Vec<String>`. An empty
/// array returns ALL categories (same as `load_categories`).
pub fn get_categories_by_sources(source_ids_json: String) -> Result<String> {
    let ids: Vec<String> = from_json(&source_ids_json)?;
    json_result(CategoryService(ctx()?).get_categories_by_sources(&ids)?)
}

/// Load categories as JSON object {type: [names]}.
pub fn load_categories() -> Result<String> {
    json_result(CategoryService(ctx()?).load_categories()?)
}

/// Save categories from JSON object {source_id: str, categories: {type: [names]}}.
pub fn save_categories(source_id: String, json: String) -> Result<()> {
    let cats: HashMap<String, Vec<String>> = from_json(&json)?;
    Ok(CategoryService(ctx()?).save_categories(&source_id, &cats)?)
}

// ── Favorite Categories ──────────────────────────────

/// Get favourite category names for profile + type.
pub fn get_favorite_categories(profile_id: String, category_type: String) -> Result<Vec<String>> {
    Ok(CategoryService(ctx()?).get_favorite_categories(&profile_id, &category_type)?)
}

/// Add a category to profile favourites.
pub fn add_favorite_category(
    profile_id: String,
    category_type: String,
    category_name: String,
) -> Result<()> {
    Ok(CategoryService(ctx()?).add_favorite_category(
        &profile_id,
        &category_type,
        &category_name,
    )?)
}

/// Remove a category from profile favourites.
pub fn remove_favorite_category(
    profile_id: String,
    category_type: String,
    category_name: String,
) -> Result<()> {
    Ok(CategoryService(ctx()?).remove_favorite_category(
        &profile_id,
        &category_type,
        &category_name,
    )?)
}

// ── Channel Order ────────────────────────────────────

/// Save custom channel order for profile + group.
pub fn save_channel_order(
    profile_id: String,
    group_name: String,
    channel_ids: Vec<String>,
) -> Result<()> {
    Ok(ProfileService(ctx()?).save_channel_order(&profile_id, &group_name, &channel_ids)?)
}

/// Load channel order as JSON {channel_id: index}
/// or null if no custom order.
pub fn load_channel_order(profile_id: String, group_name: String) -> Result<Option<String>> {
    let order = ProfileService(ctx()?).load_channel_order(&profile_id, &group_name)?;
    match order {
        Some(map) => Ok(Some(serde_json::to_string(&map)?)),
        None => Ok(None),
    }
}

/// Reset channel order for profile + group.
pub fn reset_channel_order(profile_id: String, group_name: String) -> Result<()> {
    Ok(ProfileService(ctx()?).reset_channel_order(&profile_id, &group_name)?)
}

// ── Channel Algorithms ───────────────────────────────

/// Sort channels by number then name (in-place).
/// Input/output: JSON array of Channel.
pub fn sort_channels_json(json: String) -> Result<String> {
    let mut channels: Vec<Channel> = from_json(&json)?;
    crispy_core::algorithms::sorting::sort_channels(&mut channels);
    json_result(channels)
}

/// Resolve category IDs to names in channels.
/// Returns JSON array of Channel.
pub fn resolve_channel_categories(channels_json: String, cat_map_json: String) -> Result<String> {
    let channels: Vec<Channel> = from_json(&channels_json)?;
    let cat_map: HashMap<String, String> = from_json(&cat_map_json)?;
    let resolved =
        crispy_core::algorithms::categories::resolve_channel_categories(&channels, &cat_map);
    json_result(resolved)
}

/// Extract unique sorted group names from channels.
pub fn extract_sorted_groups(channels_json: String) -> Result<Vec<String>> {
    let channels: Vec<Channel> = from_json(&channels_json)?;
    Ok(crispy_core::algorithms::categories::extract_sorted_groups(
        &channels,
    ))
}

/// Find the duplicate group containing a channel.
/// Returns JSON of DuplicateGroup or null.
pub fn find_group_for_channel(groups_json: String, channel_id: String) -> Result<Option<String>> {
    let groups: Vec<crispy_core::algorithms::dedup::DuplicateGroup> = from_json(&groups_json)?;
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
