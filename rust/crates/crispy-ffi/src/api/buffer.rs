use std::collections::HashMap;
use std::sync::Mutex;

use super::ctx;
use anyhow::Result;
use crispy_core::services::BufferTierService;

/// In-memory buffer health counters, keyed by URL hash.
///
/// Stored outside `CrispyService` because these are
/// ephemeral (reset on app restart) and the service
/// singleton is immutable after init.
static BUFFER_STATE: Mutex<Option<HashMap<String, (u32, u32)>>> = Mutex::new(None);

fn state_map() -> std::sync::MutexGuard<'static, Option<HashMap<String, (u32, u32)>>> {
    let mut guard = BUFFER_STATE
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner);
    if guard.is_none() {
        *guard = Some(HashMap::new());
    }
    guard
}

// ── Buffer Tier Persistence ─────────────────────────

/// Get the persisted tier for a URL hash.
pub fn get_buffer_tier(url_hash: String) -> Result<Option<String>> {
    Ok(BufferTierService(ctx()?).get_buffer_tier(&url_hash)?)
}

/// Persist a tier for a URL hash.
pub fn set_buffer_tier(url_hash: String, tier: String) -> Result<()> {
    Ok(BufferTierService(ctx()?).set_buffer_tier(&url_hash, &tier)?)
}

/// Prune buffer tier entries, keeping only the newest
/// `max_entries`.
pub fn prune_buffer_tiers(max_entries: i64) -> Result<usize> {
    Ok(BufferTierService(ctx()?).prune_buffer_tiers(max_entries)?)
}

/// Feed a buffer health sample and get back the
/// (possibly updated) tier as JSON.
///
/// Returns: `{"tier":"normal","changed":false,"readahead_secs":120}`
pub fn evaluate_buffer_sample(url_hash: String, cache_duration_secs: f64) -> Result<String> {
    let svc = BufferTierService(ctx()?);
    let mut guard = state_map();
    let map = guard.as_mut().unwrap();
    Ok(svc.evaluate_buffer_sample(&url_hash, cache_duration_secs, map)?)
}

/// Reset in-memory buffer counters for a URL (on channel change).
pub fn reset_buffer_state(url_hash: String) -> Result<()> {
    let mut guard = state_map();
    let map = guard.as_mut().unwrap();
    crispy_core::services::BufferTierService::reset_buffer_state(&url_hash, map);
    Ok(())
}

/// Android heap-adaptive buffer cap.
///
/// Returns maximum forward buffer in MB.
#[flutter_rust_bridge::frb(sync)]
pub fn get_buffer_cap_mb(heap_max_mb: i64) -> i64 {
    crispy_core::services::BufferTierService::get_buffer_cap_mb(heap_max_mb)
}
