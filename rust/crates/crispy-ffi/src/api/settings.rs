use super::{from_json, svc};
use anyhow::{Result, anyhow};
use crispy_core::models::{SavedLayout, SearchHistory};

// ── Settings (KV Store) ──────────────────────────────

/// Get a setting value by key.
pub fn get_setting(key: String) -> Result<Option<String>> {
    Ok(svc()?.get_setting(&key)?)
}

/// Set a setting value.
pub fn set_setting(key: String, value: String) -> Result<()> {
    Ok(svc()?.set_setting(&key, &value)?)
}

/// Remove a setting.
pub fn remove_setting(key: String) -> Result<()> {
    Ok(svc()?.remove_setting(&key)?)
}

// ── Sync Meta ────────────────────────────────────────

/// Get last sync time for a source (Unix seconds).
pub fn get_last_sync_time(source_id: String) -> Result<Option<i64>> {
    let time = svc()?.get_last_sync_time(&source_id)?;
    Ok(time.map(|t| t.and_utc().timestamp()))
}

/// Set last sync time for a source (Unix seconds).
pub fn set_last_sync_time(source_id: String, timestamp: i64) -> Result<()> {
    let dt = chrono::DateTime::from_timestamp(timestamp, 0)
        .ok_or_else(|| anyhow!("Invalid timestamp"))?
        .naive_utc();
    Ok(svc()?.set_last_sync_time(&source_id, dt)?)
}

// ── Bulk ─────────────────────────────────────────────

/// Delete all data from all tables.
pub fn clear_all() -> Result<()> {
    Ok(svc()?.clear_all()?)
}

// ── Backup ──────────────────────────────────────────

/// Export all data as a JSON backup string.
pub fn export_backup() -> Result<String> {
    let svc = svc()?;
    crispy_core::backup::export_backup(&svc).map_err(|e| anyhow!("{e}"))
}

/// Import data from a JSON backup string.
/// Returns JSON summary of imported entities.
pub fn import_backup(json: String) -> Result<String> {
    let svc = svc()?;
    let summary = crispy_core::backup::import_backup(&svc, &json).map_err(|e| anyhow!("{e}"))?;
    Ok(serde_json::to_string(&summary)?)
}

// ── Config Merge ────────────────────────────────────

/// Deep-merge two JSON objects.
#[flutter_rust_bridge::frb(sync)]
pub fn deep_merge_json(base_json: String, overrides_json: String) -> String {
    crispy_core::algorithms::config_merge::deep_merge_json(&base_json, &overrides_json)
}

/// Set a value at a dot-separated path in a JSON
/// object.
#[flutter_rust_bridge::frb(sync)]
pub fn set_nested_value(map_json: String, dot_path: String, value_json: String) -> String {
    crispy_core::algorithms::config_merge::set_nested_value(&map_json, &dot_path, &value_json)
}

// ── GPU Detection ───────────────────────────────────

/// Detect GPU info for video upscaling. Returns JSON.
/// Does NOT require backend init — can be called
/// anytime.
pub fn detect_gpu() -> Result<String> {
    let info = crispy_core::gpu::detect_gpu();
    Ok(serde_json::to_string(&info)?)
}

// ── Cloud Sync Direction ────────────────────────────

/// Determines cloud sync direction from timestamps and
/// device IDs.
///
/// Returns one of: `"upload"`, `"download"`,
/// `"no_change"`, `"conflict"`.
///
/// Pure CPU — no DB access required.
#[flutter_rust_bridge::frb(sync)]
pub fn determine_sync_direction(
    local_ms: i64,
    cloud_ms: i64,
    last_sync_ms: i64,
    local_device: String,
    cloud_device: String,
) -> String {
    crispy_core::algorithms::cloud_sync::determine_sync_direction(
        local_ms,
        cloud_ms,
        last_sync_ms,
        &local_device,
        &cloud_device,
    )
}

// ── Saved Layouts ───────────────────────────────────

/// Load all saved layouts as JSON array.
pub fn load_saved_layouts() -> Result<String> {
    let layouts = svc()?.load_saved_layouts()?;
    Ok(serde_json::to_string(&layouts)?)
}

/// Save a layout from JSON.
pub fn save_saved_layout(json: String) -> Result<()> {
    let layout: SavedLayout = from_json(&json)?;
    Ok(svc()?.save_saved_layout(&layout)?)
}

/// Delete a saved layout by ID.
pub fn delete_saved_layout(id: String) -> Result<()> {
    Ok(svc()?.delete_saved_layout(&id)?)
}

/// Get a saved layout by ID (direct query).
pub fn get_saved_layout_by_id(id: String) -> Result<String> {
    let layout = svc()?.get_saved_layout_by_id(&id)?;
    Ok(serde_json::to_string(&layout)?)
}

// ── Search History ──────────────────────────────────

/// Load all search history as JSON array.
pub fn load_search_history() -> Result<String> {
    let history = svc()?.load_search_history()?;
    Ok(serde_json::to_string(&history)?)
}

/// Save a search entry from JSON.
pub fn save_search_entry(json: String) -> Result<()> {
    let entry: SearchHistory = from_json(&json)?;
    Ok(svc()?.save_search_entry(&entry)?)
}

/// Delete a search entry by ID.
pub fn delete_search_entry(id: String) -> Result<()> {
    Ok(svc()?.delete_search_entry(&id)?)
}

/// Clear all search history.
pub fn clear_search_history() -> Result<()> {
    Ok(svc()?.clear_search_history()?)
}

/// Delete search history by query text
/// (case-insensitive). Returns count deleted.
pub fn delete_search_by_query(query: String) -> Result<usize> {
    Ok(svc()?.delete_search_by_query(&query)?)
}
