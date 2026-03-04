use super::{ms_to_naive, svc};
use anyhow::{Context, Result};
use crispy_core::models::{Recording, Reminder, StorageBackend, TransferTask, WatchHistory};

// ── Recordings ───────────────────────────────────────

/// Load all recordings as JSON array.
pub fn load_recordings() -> Result<String> {
    let recs = svc()?.load_recordings()?;
    Ok(serde_json::to_string(&recs)?)
}

/// Save a recording from JSON.
pub fn save_recording(json: String) -> Result<()> {
    let rec: Recording = serde_json::from_str(&json).context("Invalid recording JSON")?;
    Ok(svc()?.save_recording(&rec)?)
}

/// Update an existing recording from JSON.
pub fn update_recording(json: String) -> Result<()> {
    let rec: Recording = serde_json::from_str(&json).context("Invalid recording JSON")?;
    Ok(svc()?.update_recording(&rec)?)
}

/// Delete a recording by ID.
pub fn delete_recording(id: String) -> Result<()> {
    Ok(svc()?.delete_recording(&id)?)
}

/// Fetch commercial markers for a given recording by ID.
pub fn get_recording_markers(recording_id: String) -> Result<String> {
    // FE-DVR-11: Fetch from backend or analysis tool.
    // For now, return empty JSON array.
    let _ = recording_id;
    Ok("[]".to_string())
}

// ── Storage Backends ─────────────────────────────────

/// Load all storage backends as JSON array.
pub fn load_storage_backends() -> Result<String> {
    let backends = svc()?.load_storage_backends()?;
    Ok(serde_json::to_string(&backends)?)
}

/// Save a storage backend from JSON.
pub fn save_storage_backend(json: String) -> Result<()> {
    let backend: StorageBackend =
        serde_json::from_str(&json).context("Invalid storage backend JSON")?;
    Ok(svc()?.save_storage_backend(&backend)?)
}

/// Delete a storage backend by ID.
pub fn delete_storage_backend(id: String) -> Result<()> {
    Ok(svc()?.delete_storage_backend(&id)?)
}

// ── Transfer Tasks ───────────────────────────────────

/// Load all transfer tasks as JSON array.
pub fn load_transfer_tasks() -> Result<String> {
    let tasks = svc()?.load_transfer_tasks()?;
    Ok(serde_json::to_string(&tasks)?)
}

/// Save a transfer task from JSON.
pub fn save_transfer_task(json: String) -> Result<()> {
    let task: TransferTask = serde_json::from_str(&json).context("Invalid transfer task JSON")?;
    Ok(svc()?.save_transfer_task(&task)?)
}

/// Update a transfer task from JSON.
pub fn update_transfer_task(json: String) -> Result<()> {
    let task: TransferTask = serde_json::from_str(&json).context("Invalid transfer task JSON")?;
    Ok(svc()?.update_transfer_task(&task)?)
}

/// Delete a transfer task by ID.
pub fn delete_transfer_task(id: String) -> Result<()> {
    Ok(svc()?.delete_transfer_task(&id)?)
}

// ── Watch History ────────────────────────────────────

/// Load watch history as JSON array.
pub fn load_watch_history() -> Result<String> {
    let history = svc()?.load_watch_history()?;
    Ok(serde_json::to_string(&history)?)
}

/// Save a watch history entry from JSON.
pub fn save_watch_history(json: String) -> Result<()> {
    let entry: WatchHistory = serde_json::from_str(&json).context("Invalid watch history JSON")?;
    Ok(svc()?.save_watch_history(&entry)?)
}

/// Delete a watch history entry by ID.
pub fn delete_watch_history(id: String) -> Result<()> {
    Ok(svc()?.delete_watch_history(&id)?)
}

/// Delete all watch history entries. Returns count.
pub fn clear_all_watch_history() -> Result<usize> {
    Ok(svc()?.clear_all_watch_history()?)
}

// ── Reminders ───────────────────────────────────────

/// Load all reminders as JSON array.
pub fn load_reminders() -> Result<String> {
    let reminders = svc()?.load_reminders()?;
    Ok(serde_json::to_string(&reminders)?)
}

/// Save a reminder from JSON.
pub fn save_reminder(json: String) -> Result<()> {
    let reminder: Reminder = serde_json::from_str(&json).context("Invalid reminder JSON")?;
    Ok(svc()?.save_reminder(&reminder)?)
}

/// Delete a reminder by ID.
pub fn delete_reminder(id: String) -> Result<()> {
    Ok(svc()?.delete_reminder(&id)?)
}

/// Delete all fired reminders.
pub fn clear_fired_reminders() -> Result<()> {
    Ok(svc()?.clear_fired_reminders()?)
}

/// Mark a reminder as fired by ID.
pub fn mark_reminder_fired(id: String) -> Result<()> {
    Ok(svc()?.mark_reminder_fired(&id)?)
}

// ── DVR Algorithms ──────────────────────────────────

/// Expand recurring recordings into concrete instances.
/// Returns JSON array of RecordingInstance.
pub fn expand_recurring_recordings(recordings_json: String, now_utc_ms: i64) -> Result<String> {
    let recordings: Vec<Recording> =
        serde_json::from_str(&recordings_json).context("Invalid recordings JSON")?;
    let now = ms_to_naive(now_utc_ms)?;
    let instances = crispy_core::algorithms::dvr::expand_recurring_recordings(&recordings, now);
    Ok(serde_json::to_string(&instances)?)
}

/// Check if a candidate recording conflicts with
/// existing recordings on the same channel.
pub fn detect_recording_conflict(
    recordings_json: String,
    exclude_id: Option<String>,
    channel_name: String,
    start_utc_ms: i64,
    end_utc_ms: i64,
) -> Result<bool> {
    let recordings: Vec<Recording> =
        serde_json::from_str(&recordings_json).context("Invalid recordings JSON")?;
    let start = ms_to_naive(start_utc_ms)?;
    let end = ms_to_naive(end_utc_ms)?;
    Ok(crispy_core::algorithms::dvr::detect_recording_conflict(
        &recordings,
        exclude_id.as_deref(),
        &channel_name,
        start,
        end,
    ))
}

/// Sanitize a string for use as a filename.
#[flutter_rust_bridge::frb(sync)]
pub fn sanitize_filename(name: String) -> String {
    crispy_core::algorithms::dvr::sanitize_filename(&name)
}

/// Filter watch history for "continue watching".
/// Returns JSON array of WatchHistory items.
pub fn filter_continue_watching(
    history_json: String,
    media_type: Option<String>,
    profile_id: Option<String>,
) -> Result<String> {
    let entries: Vec<WatchHistory> =
        serde_json::from_str(&history_json).context("Invalid watch history JSON")?;
    let result = crispy_core::algorithms::watch_history::filter_continue_watching(
        &entries,
        media_type.as_deref(),
        profile_id.as_deref(),
    );
    Ok(serde_json::to_string(&result)?)
}

/// Filter watch history for cross-device items.
/// Returns JSON array of WatchHistory items.
pub fn filter_cross_device(
    history_json: String,
    current_device_id: String,
    cutoff_utc_ms: i64,
) -> Result<String> {
    let entries: Vec<WatchHistory> =
        serde_json::from_str(&history_json).context("Invalid watch history JSON")?;
    let cutoff = ms_to_naive(cutoff_utc_ms)?;
    let result = crispy_core::algorithms::watch_history::filter_cross_device(
        &entries,
        &current_device_id,
        cutoff,
    );
    Ok(serde_json::to_string(&result)?)
}

/// Whether the given role can view a recording.
#[flutter_rust_bridge::frb(sync)]
pub fn can_view_recording(
    role: String,
    recording_owner_id: String,
    current_profile_id: String,
) -> bool {
    crispy_core::algorithms::permission::can_view_recording(
        &role,
        &recording_owner_id,
        &current_profile_id,
    )
}

/// Whether the given role can delete a recording.
#[flutter_rust_bridge::frb(sync)]
pub fn can_delete_recording(
    role: String,
    recording_owner_id: String,
    current_profile_id: String,
) -> bool {
    crispy_core::algorithms::permission::can_delete_recording(
        &role,
        &recording_owner_id,
        &current_profile_id,
    )
}

/// Returns IDs of recordings that should start now.
///
/// Input: JSON array of recording objects with at
/// least: `{ "id", "status", "startTime", "endTime" }`.
///
/// Returns: JSON array of recording ID strings.
pub fn get_recordings_to_start(recordings_json: String, now_ms: i64) -> String {
    crispy_core::algorithms::dvr::get_recordings_to_start(&recordings_json, now_ms)
}
