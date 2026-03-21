use std::collections::HashMap;
use std::sync::Mutex;

use super::{from_json, svc};
use anyhow::Result;
use crispy_core::models::Channel;

/// In-memory failover state counters, keyed by URL hash.
///
/// Stored outside `CrispyService` because these are
/// ephemeral (reset on app restart) and the service
/// singleton is immutable after init.
static FAILOVER_STATE: Mutex<Option<HashMap<String, (u32, u32)>>> = Mutex::new(None);

fn failover_map() -> std::sync::MutexGuard<'static, Option<HashMap<String, (u32, u32)>>> {
    let mut guard = FAILOVER_STATE.lock().unwrap_or_else(|e| e.into_inner());
    if guard.is_none() {
        *guard = Some(HashMap::new());
    }
    guard
}

// ── Stream Health Persistence ─────────────────────────

/// Record a stream stall event for a URL hash.
pub fn record_stream_stall(url_hash: String) -> Result<()> {
    Ok(svc()?.record_stream_stall(&url_hash)?)
}

/// Record a buffer health sample for a URL hash.
pub fn record_buffer_sample(url_hash: String, cache_duration_secs: f64) -> Result<()> {
    Ok(svc()?.record_buffer_sample(&url_hash, cache_duration_secs)?)
}

/// Record time-to-first-frame for a URL hash.
pub fn record_ttff(url_hash: String, ttff_ms: i64) -> Result<()> {
    Ok(svc()?.record_ttff(&url_hash, ttff_ms)?)
}

/// Get the health score for a URL hash (0.0–1.0).
pub fn get_stream_health_score(url_hash: String) -> Result<f64> {
    Ok(svc()?.get_stream_health_score(&url_hash)?)
}

/// Get health scores for multiple URL hashes.
///
/// Returns JSON: `{"hash1": 0.8, "hash2": 0.5}`
pub fn get_stream_health_scores(url_hashes_json: String) -> Result<String> {
    let hashes: Vec<String> = from_json(&url_hashes_json)?;
    let scores = svc()?.get_stream_health_scores(&hashes)?;
    Ok(serde_json::to_string(&scores)?)
}

/// Keep only the newest `max_entries` stream health rows.
pub fn prune_stream_health(max_entries: i64) -> Result<usize> {
    Ok(svc()?.prune_stream_health(max_entries)?)
}

// ── Failover Threshold Evaluation ─────────────────────

/// Feed a failover event and get the action decision.
///
/// Returns JSON: `{"action":"none"|"start_warming"|"swap_warm"}`
pub fn evaluate_failover_event(url_hash: String, event_type: String, value: f64) -> Result<String> {
    let svc = svc()?;
    let mut guard = failover_map();
    let map = guard.as_mut().unwrap();
    Ok(svc.evaluate_failover_event(&url_hash, &event_type, value, map)?)
}

/// Reset in-memory failover counters for a URL.
pub fn reset_failover_state(url_hash: String) -> Result<()> {
    let mut guard = failover_map();
    let map = guard.as_mut().unwrap();
    crispy_core::services::CrispyService::reset_failover_state(&url_hash, map);
    Ok(())
}

// ── Stream Alternatives ───────────────────────────────

/// Rank alternative streams for failover.
///
/// Takes a target channel JSON and all channels JSON,
/// returns ranked alternatives as JSON array.
pub fn rank_stream_alternatives(
    target_json: String,
    all_channels_json: String,
    health_scores_json: String,
) -> Result<String> {
    let target: Channel = from_json(&target_json)?;
    let all_channels: Vec<Channel> = from_json(&all_channels_json)?;
    let health_scores: HashMap<String, f64> = from_json(&health_scores_json)?;
    Ok(
        crispy_core::algorithms::stream_alternatives::rank_stream_alternatives_json(
            &target,
            &all_channels,
            &health_scores,
            &HashMap::new(),
            None,
        ),
    )
}

/// Extract a US broadcast call sign from a channel name.
///
/// Returns the call sign or empty string if none found.
#[flutter_rust_bridge::frb(sync)]
pub fn extract_call_sign(name: String) -> String {
    crispy_core::algorithms::stream_alternatives::extract_call_sign(&name).unwrap_or_default()
}
