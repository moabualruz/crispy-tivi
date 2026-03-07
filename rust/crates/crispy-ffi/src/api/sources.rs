use anyhow::Result;
use crispy_core::models::Source;

use super::{from_json, svc};

/// Get per-source channel and VOD counts. Returns JSON array of SourceStats.
pub fn get_source_stats() -> Result<String> {
    let stats = svc()?.get_source_stats()?;
    Ok(serde_json::to_string(&stats)?)
}

/// Get all sources as JSON array.
pub fn get_sources() -> Result<String> {
    let sources = svc()?.get_sources()?;
    Ok(serde_json::to_string(&sources)?)
}

/// Get a single source by ID as JSON (null if not found).
pub fn get_source(id: String) -> Result<String> {
    let source = svc()?.get_source(&id)?;
    Ok(serde_json::to_string(&source)?)
}

/// Save a source from JSON.
pub fn save_source(json: String) -> Result<()> {
    let source: Source = from_json(&json)?;
    Ok(svc()?.save_source(&source)?)
}

/// Delete a source and cascade-delete all its data.
pub fn delete_source(id: String) -> Result<()> {
    Ok(svc()?.delete_source(&id)?)
}

/// Reorder sources. Takes JSON array of source IDs.
pub fn reorder_sources(ids_json: String) -> Result<()> {
    let ids: Vec<String> = from_json(&ids_json)?;
    Ok(svc()?.reorder_sources(&ids)?)
}

/// Update sync status on a source.
pub fn update_source_sync_status(
    id: String,
    status: String,
    error: Option<String>,
    sync_time_ms: Option<i64>,
) -> Result<()> {
    let sync_time = sync_time_ms
        .and_then(|ms| chrono::DateTime::from_timestamp(ms / 1000, 0))
        .map(|dt| dt.naive_utc());
    Ok(svc()?.update_source_sync_status(&id, &status, error.as_deref(), sync_time)?)
}
