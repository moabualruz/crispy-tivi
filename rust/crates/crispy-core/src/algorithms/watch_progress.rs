//! Watch position progress calculation and
//! continue-watching filtering.
//!
//! Ports the `WatchPosition.progress` calculation and
//! `continueWatching` filtering/sorting from Dart
//! `favorites_history_service.dart`.

use serde::{Deserialize, Serialize};

/// Completion threshold: items >= 95% are finished.
///
/// Canonical definition shared with `watch_history`.
/// Matches Dart `kCompletionThreshold` in `lib/core/constants.dart`.
pub(crate) const COMPLETION_THRESHOLD: f64 = 0.95;

/// A watch position entry for filtering.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WatchPositionEntry {
    /// Unique item identifier.
    pub item_id: String,
    /// Current playback position in milliseconds.
    pub position_ms: i64,
    /// Total duration in milliseconds.
    pub duration_ms: i64,
    /// ISO-8601 timestamp of last watch.
    pub last_watched: String,
}

/// Calculate progress ratio from position and duration.
///
/// Returns a value clamped to 0.0..=1.0.
/// Handles zero and negative duration by returning 0.0.
pub fn calculate_progress(position_ms: i64, duration_ms: i64) -> f64 {
    if duration_ms <= 0 {
        return 0.0;
    }
    let ratio = position_ms as f64 / duration_ms as f64;
    ratio.clamp(0.0, 1.0)
}

/// Filter watch positions for "continue watching".
///
/// Keeps entries where progress > 0 and < 95%, sorts by
/// `last_watched` descending (most recent first), and
/// limits to `limit` results.
///
/// Input/output: JSON arrays of `WatchPositionEntry`.
pub fn filter_continue_watching_positions(json: &str, limit: usize) -> String {
    let entries: Vec<WatchPositionEntry> = match serde_json::from_str(json) {
        Ok(v) => v,
        Err(_) => return "[]".to_string(),
    };

    let mut filtered: Vec<&WatchPositionEntry> = entries
        .iter()
        .filter(|e| {
            let progress = calculate_progress(e.position_ms, e.duration_ms);
            progress > 0.0 && progress < COMPLETION_THRESHOLD
        })
        .collect();

    // Sort by last_watched descending (lexicographic on
    // ISO-8601 strings works correctly).
    filtered.sort_by(|a, b| b.last_watched.cmp(&a.last_watched));
    filtered.truncate(limit);

    serde_json::to_string(&filtered).unwrap_or_else(|_| "[]".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── calculate_progress ────────────────────────

    #[test]
    fn progress_normal() {
        assert!((calculate_progress(5000, 10000) - 0.5).abs() < f64::EPSILON);
    }

    #[test]
    fn progress_zero_duration() {
        assert_eq!(calculate_progress(5000, 0), 0.0);
    }

    #[test]
    fn progress_negative_duration() {
        assert_eq!(calculate_progress(5000, -100), 0.0);
    }

    #[test]
    fn progress_zero_position() {
        assert_eq!(calculate_progress(0, 10000), 0.0);
    }

    #[test]
    fn progress_exactly_95_percent() {
        let p = calculate_progress(9500, 10000);
        assert!((p - 0.95).abs() < f64::EPSILON);
    }

    #[test]
    fn progress_over_100_clamped() {
        assert_eq!(calculate_progress(15000, 10000), 1.0);
    }

    #[test]
    fn progress_negative_position_clamped() {
        assert_eq!(calculate_progress(-100, 10000), 0.0);
    }

    #[test]
    fn progress_both_zero() {
        assert_eq!(calculate_progress(0, 0), 0.0);
    }

    // ── filter_continue_watching_positions ────────

    #[test]
    fn filter_empty_list() {
        let r = filter_continue_watching_positions("[]", 20);
        assert_eq!(r, "[]");
    }

    #[test]
    fn filter_invalid_json() {
        let r = filter_continue_watching_positions("not json", 20);
        assert_eq!(r, "[]");
    }

    #[test]
    fn filter_excludes_zero_position() {
        let json = r#"[
            {"item_id":"a","position_ms":0,"duration_ms":10000,"last_watched":"2024-01-01T00:00:00"}
        ]"#;
        let result: Vec<WatchPositionEntry> =
            serde_json::from_str(&filter_continue_watching_positions(json, 20)).unwrap();
        assert!(result.is_empty());
    }

    #[test]
    fn filter_excludes_completed() {
        let json = r#"[
            {"item_id":"a","position_ms":9500,"duration_ms":10000,"last_watched":"2024-01-01T00:00:00"},
            {"item_id":"b","position_ms":10000,"duration_ms":10000,"last_watched":"2024-01-01T00:00:00"},
            {"item_id":"c","position_ms":5000,"duration_ms":10000,"last_watched":"2024-01-01T00:00:00"}
        ]"#;
        let result: Vec<WatchPositionEntry> =
            serde_json::from_str(&filter_continue_watching_positions(json, 20)).unwrap();
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].item_id, "c");
    }

    #[test]
    fn filter_sorts_by_most_recent() {
        let json = r#"[
            {"item_id":"old","position_ms":5000,"duration_ms":10000,"last_watched":"2024-01-01T00:00:00"},
            {"item_id":"new","position_ms":5000,"duration_ms":10000,"last_watched":"2024-03-01T00:00:00"},
            {"item_id":"mid","position_ms":5000,"duration_ms":10000,"last_watched":"2024-02-01T00:00:00"}
        ]"#;
        let result: Vec<WatchPositionEntry> =
            serde_json::from_str(&filter_continue_watching_positions(json, 20)).unwrap();
        assert_eq!(result.len(), 3);
        assert_eq!(result[0].item_id, "new");
        assert_eq!(result[1].item_id, "mid");
        assert_eq!(result[2].item_id, "old");
    }

    #[test]
    fn filter_respects_limit() {
        let mut entries = Vec::new();
        for i in 0..10 {
            entries.push(serde_json::json!({
                "item_id": format!("e{i}"),
                "position_ms": 5000,
                "duration_ms": 10000,
                "last_watched": format!("2024-03-{:02}T00:00:00", i + 1),
            }));
        }
        let json = serde_json::to_string(&entries).unwrap();
        let result: Vec<WatchPositionEntry> =
            serde_json::from_str(&filter_continue_watching_positions(&json, 3)).unwrap();
        assert_eq!(result.len(), 3);
    }

    #[test]
    fn filter_excludes_zero_duration() {
        let json = r#"[
            {"item_id":"a","position_ms":5000,"duration_ms":0,"last_watched":"2024-01-01T00:00:00"}
        ]"#;
        let result: Vec<WatchPositionEntry> =
            serde_json::from_str(&filter_continue_watching_positions(json, 20)).unwrap();
        assert!(result.is_empty());
    }
}
