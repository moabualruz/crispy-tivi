use super::{into_anyhow, svc};
use anyhow::Result;

/// Create a new smart channel group. Returns its UUID.
pub fn create_smart_group(name: String) -> Result<String> {
    into_anyhow(svc()?.create_smart_group(&name))
}

/// Delete a smart group and all its members.
pub fn delete_smart_group(group_id: String) -> Result<()> {
    into_anyhow(svc()?.delete_smart_group(&group_id))
}

/// Rename a smart group.
pub fn rename_smart_group(group_id: String, name: String) -> Result<()> {
    into_anyhow(svc()?.rename_smart_group(&group_id, &name))
}

/// Add a channel to a smart group with a given priority.
pub fn add_smart_group_member(
    group_id: String,
    channel_id: String,
    source_id: String,
    priority: i32,
) -> Result<()> {
    into_anyhow(svc()?.add_smart_group_member(&group_id, &channel_id, &source_id, priority))
}

/// Remove a channel from a smart group.
pub fn remove_smart_group_member(group_id: String, channel_id: String) -> Result<()> {
    into_anyhow(svc()?.remove_smart_group_member(&group_id, &channel_id))
}

/// Reorder members of a smart group.
pub fn reorder_smart_group_members(
    group_id: String,
    ordered_channel_ids_json: String,
) -> Result<()> {
    into_anyhow(svc()?.reorder_smart_group_members(&group_id, &ordered_channel_ids_json))
}

/// Load all smart groups with their members as JSON.
pub fn get_smart_groups_json() -> Result<String> {
    into_anyhow(svc()?.get_smart_groups_json())
}

/// Get the smart group a channel belongs to, if any.
pub fn get_smart_group_for_channel(channel_id: String) -> Result<Option<String>> {
    into_anyhow(svc()?.get_smart_group_for_channel(&channel_id))
}

/// Get smart group alternatives for a channel (excluding same source).
pub fn get_smart_group_alternatives(channel_id: String) -> Result<String> {
    into_anyhow(svc()?.get_smart_group_alternatives(&channel_id))
}

/// Auto-detect potential smart group candidates across sources.
pub fn detect_smart_group_candidates() -> Result<String> {
    into_anyhow(svc()?.detect_smart_group_candidates())
}
