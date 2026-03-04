use std::collections::BTreeMap;

use super::{EpisodeHistoryEntry, EpisodeProgressResult};

/// Compute per-episode progress for a given series.
///
/// Input: JSON array of `EpisodeHistoryEntry` plus a
/// `series_id` filter.
///
/// For each matching episode, computes
/// `position_ms / duration_ms` clamped to 0.0..1.0.
/// Returns a map of `episode_id -> progress` and the
/// `last_watched_episode_id` (most recent timestamp).
pub fn compute_episode_progress(history_json: &str, series_id: &str) -> String {
    let entries: Vec<EpisodeHistoryEntry> = match serde_json::from_str(history_json) {
        Ok(v) => v,
        Err(_) => {
            return serde_json::to_string(&EpisodeProgressResult {
                progress_map: BTreeMap::new(),
                last_watched_episode_id: None,
            })
            .unwrap();
        }
    };

    let mut progress_map = BTreeMap::new();
    let mut latest_ts: Option<&str> = None;
    let mut latest_ep: Option<String> = None;

    for entry in &entries {
        let meta = match &entry.metadata {
            Some(m) => m,
            None => continue,
        };

        let entry_series_id = match &meta.series_id {
            Some(sid) => sid.as_str(),
            None => continue,
        };

        if entry_series_id != series_id {
            continue;
        }

        let episode_id = match &meta.episode_id {
            Some(eid) => eid.clone(),
            None => continue,
        };

        // Compute progress clamped 0.0..1.0.
        let progress = if entry.duration_ms <= 0 {
            0.0
        } else {
            (entry.position_ms as f64 / entry.duration_ms as f64).clamp(0.0, 1.0)
        };

        progress_map.insert(episode_id.clone(), progress);

        // Track most recent.
        let ts = entry.last_watched.as_str();
        if latest_ts.is_none_or(|lt| ts > lt) {
            latest_ts = Some(ts);
            latest_ep = Some(episode_id);
        }
    }

    let result = EpisodeProgressResult {
        progress_map,
        last_watched_episode_id: latest_ep,
    };

    serde_json::to_string(&result).unwrap_or_else(|_| "{}".to_string())
}
