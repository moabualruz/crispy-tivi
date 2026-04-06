//! Series-related watch history algorithms.

use serde::{Deserialize, Serialize};

use crate::algorithms::json_utils::parse_json_vec;
use crate::algorithms::watch_progress::COMPLETION_THRESHOLD;

/// An item exposing `id` and an optional `updated_at` epoch-ms timestamp.
#[derive(Debug, Deserialize)]
struct SeriesItem {
    id: String,
    #[serde(default)]
    updated_at: Option<i64>,
}

/// Returns a JSON array of series IDs whose `updated_at` is within the last
/// `days` days relative to `now_ms`.
///
/// Ports `seriesIdsWithNewEpisodes` from Dart
/// `lib/features/dvr/domain/utils/dvr_payload.dart` (lines 31-41).
pub fn series_ids_with_new_episodes(series_json: &str, days: u32, now_ms: i64) -> String {
    let Some(items) = parse_json_vec::<SeriesItem>(series_json) else {
        return "[]".to_string();
    };

    let cutoff = now_ms - (days as i64) * 86_400_000;

    let ids: Vec<&str> = items
        .iter()
        .filter(|s| s.updated_at.is_some_and(|ts| ts > cutoff))
        .map(|s| s.id.as_str())
        .collect();

    serde_json::to_string(&ids).unwrap_or_else(|_| "[]".to_string())
}

/// A minimal watch-history-like entry used by `count_in_progress_episodes`.
#[derive(Debug, Deserialize)]
struct EpisodeEntry {
    #[serde(default)]
    series_id: Option<String>,
    media_type: String,
    duration_ms: i64,
    position_ms: i64,
}

/// Counts in-progress episodes for a given `series_id`.
///
/// An episode is in-progress when:
/// - `series_id` matches,
/// - `media_type == "episode"`,
/// - `duration_ms > 0`, and
/// - progress (`position_ms / duration_ms`) < `COMPLETION_THRESHOLD`.
///
/// Ports `countInProgressEpisodesForSeries` from Dart
/// `lib/features/dvr/domain/utils/dvr_payload.dart` (lines 49-71).
pub fn count_in_progress_episodes(history_json: &str, series_id: &str) -> usize {
    let Some(entries) = parse_json_vec::<EpisodeEntry>(history_json) else {
        return 0;
    };

    entries
        .iter()
        .filter(|e| {
            e.series_id.as_deref() == Some(series_id)
                && e.media_type.as_str() == "episode"
                && e.duration_ms > 0
                && (e.position_ms as f64 / e.duration_ms as f64) < COMPLETION_THRESHOLD
        })
        .count()
}

/// A minimal VOD item used by `resolve_next_episodes`.
#[derive(Debug, Deserialize)]
struct VodEpisodeItem {
    id: String,
    name: String,
    #[serde(rename = "type")]
    item_type: String,
    stream_url: String,
    #[serde(default)]
    poster_url: Option<String>,
    #[serde(default)]
    series_id: Option<String>,
    #[serde(default)]
    season_number: Option<i32>,
    #[serde(default)]
    episode_number: Option<i32>,
}

/// A watch-history entry as passed to `resolve_next_episodes`.
///
/// Mirrors `WatchHistory` but `last_watched` is an ISO 8601 string
/// (flexible serde) and position/duration come from the JSON payload.
#[derive(Debug, Deserialize, Serialize, Clone)]
struct ResolveEntry {
    id: String,
    media_type: String,
    name: String,
    stream_url: String,
    #[serde(default)]
    poster_url: Option<String>,
    #[serde(default)]
    series_poster_url: Option<String>,
    #[serde(default)]
    position_ms: i64,
    #[serde(default)]
    duration_ms: i64,
    last_watched: String,
    #[serde(default)]
    series_id: Option<String>,
    #[serde(default)]
    season_number: Option<i32>,
    #[serde(default)]
    episode_number: Option<i32>,
    #[serde(default)]
    device_id: Option<String>,
    #[serde(default)]
    device_name: Option<String>,
    #[serde(default)]
    profile_id: Option<String>,
}

/// Resolves "next episode" substitution for watch-history entries.
///
/// For each entry whose `media_type == "episode"` and progress (
/// `position_ms / duration_ms`) is **at or above** `threshold`, looks
/// up the next episode in the same series and substitutes it so the
/// continue-watching row points forward.
///
/// * `entries_json`   — JSON array of `ResolveEntry` objects.
/// * `vod_items_json` — JSON array of `VodEpisodeItem` objects.
/// * `threshold`      — completion ratio (e.g. `0.90`) at or above
///   which the entry is considered finished and the next episode should
///   be shown.
///
/// Returns a JSON array in the same order as the input, with qualifying
/// entries replaced by their successor episode data.
pub fn resolve_next_episodes(entries_json: &str, vod_items_json: &str, threshold: f64) -> String {
    let entries: Vec<ResolveEntry> = serde_json::from_str(entries_json).unwrap_or_default();
    let vod_items: Vec<VodEpisodeItem> = serde_json::from_str(vod_items_json).unwrap_or_default();

    let resolved: Vec<ResolveEntry> = entries
        .into_iter()
        .map(|entry| {
            // Only process episode entries with positive duration.
            if entry.media_type != "episode" || entry.duration_ms <= 0 {
                return entry;
            }

            let progress = entry.position_ms as f64 / entry.duration_ms as f64;
            if progress < threshold {
                return entry;
            }

            // Find all episodes for the same series.
            let series_id = match &entry.series_id {
                Some(s) => s.clone(),
                None => return entry,
            };

            let mut siblings: Vec<&VodEpisodeItem> = vod_items
                .iter()
                .filter(|v| {
                    v.item_type == "episode"
                        && v.series_id.as_deref() == Some(series_id.as_str())
                        && v.season_number.is_some()
                        && v.episode_number.is_some()
                })
                .collect();

            // Sort by (season_number ASC, episode_number ASC).
            siblings.sort_by_key(|v| (v.season_number.unwrap(), v.episode_number.unwrap()));

            // Find the current episode position.
            let current_pos = siblings.iter().position(|v| {
                v.season_number == entry.season_number && v.episode_number == entry.episode_number
            });

            match current_pos {
                Some(idx) if idx + 1 < siblings.len() => {
                    let next = siblings[idx + 1];
                    ResolveEntry {
                        id: next.id.clone(),
                        name: next.name.clone(),
                        stream_url: next.stream_url.clone(),
                        poster_url: next.poster_url.clone().or(entry.poster_url),
                        series_poster_url: entry.series_poster_url,
                        position_ms: 0,
                        duration_ms: 0,
                        last_watched: entry.last_watched,
                        series_id: next.series_id.clone(),
                        season_number: next.season_number,
                        episode_number: next.episode_number,
                        device_id: entry.device_id,
                        device_name: entry.device_name,
                        profile_id: entry.profile_id,
                        // keep episode media_type
                        media_type: "episode".to_string(),
                    }
                }
                _ => entry,
            }
        })
        .collect();

    serde_json::to_string(&resolved).unwrap_or_else(|_| "[]".to_string())
}

/// A minimal episode item used by `episode_count_by_season`.
#[derive(Debug, Deserialize)]
struct EpisodeSeasonItem {
    #[serde(default)]
    season_number: Option<i32>,
}

/// Counts episodes per season for a list of episode objects.
///
/// * `episodes_json` — JSON array of objects with a `season_number`
///   field (nullable integer). Items with `null` or missing
///   `season_number` are skipped.
///
/// Returns a JSON object whose keys are stringified season numbers and
/// whose values are episode counts: `{ "1": 5, "2": 3 }`.
pub fn episode_count_by_season(episodes_json: &str) -> String {
    let items: Vec<EpisodeSeasonItem> = serde_json::from_str(episodes_json).unwrap_or_default();

    let mut counts: std::collections::BTreeMap<i32, usize> = std::collections::BTreeMap::new();

    for item in &items {
        if let Some(season) = item.season_number {
            *counts.entry(season).or_insert(0) += 1;
        }
    }

    // Build a JSON object with string keys.
    let obj: serde_json::Map<String, serde_json::Value> = counts
        .into_iter()
        .map(|(k, v)| (k.to_string(), serde_json::Value::from(v)))
        .collect();

    serde_json::to_string(&serde_json::Value::Object(obj)).unwrap_or_else(|_| "{}".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── series_ids_with_new_episodes ─────────────────

    fn date_ms(year: i32, month: u32, day: u32) -> i64 {
        use chrono::TimeZone;
        chrono::Utc
            .with_ymd_and_hms(year, month, day, 0, 0, 0)
            .unwrap()
            .timestamp_millis()
    }

    #[test]
    fn new_episodes_within_window_returned() {
        let now = date_ms(2024, 3, 15);
        // updated 5 days ago — within 14-day window
        let recent = now - 5 * 86_400_000;
        let items =
            serde_json::to_string(&vec![serde_json::json!({"id": "s1", "updated_at": recent})])
                .unwrap();
        let result: Vec<String> =
            serde_json::from_str(&series_ids_with_new_episodes(&items, 14, now)).unwrap();
        assert_eq!(result, vec!["s1"]);
    }

    #[test]
    fn new_episodes_outside_window_excluded() {
        let now = date_ms(2024, 3, 15);
        // updated 20 days ago — outside 14-day window
        let old = now - 20 * 86_400_000;
        let items =
            serde_json::to_string(&vec![serde_json::json!({"id": "s1", "updated_at": old})])
                .unwrap();
        let result: Vec<String> =
            serde_json::from_str(&series_ids_with_new_episodes(&items, 14, now)).unwrap();
        assert!(result.is_empty());
    }

    #[test]
    fn new_episodes_no_updated_at_excluded() {
        let now = date_ms(2024, 3, 15);
        let items = serde_json::to_string(&vec![
            serde_json::json!({"id": "s1", "updated_at": null}),
            serde_json::json!({"id": "s2"}),
        ])
        .unwrap();
        let result: Vec<String> =
            serde_json::from_str(&series_ids_with_new_episodes(&items, 14, now)).unwrap();
        assert!(result.is_empty());
    }

    // ── count_in_progress_episodes ───────────────────

    fn make_ep_entry(
        series_id: Option<&str>,
        media_type: &str,
        duration_ms: i64,
        position_ms: i64,
    ) -> serde_json::Value {
        serde_json::json!({
            "series_id": series_id,
            "media_type": media_type,
            "duration_ms": duration_ms,
            "position_ms": position_ms,
        })
    }

    #[test]
    fn count_in_progress_matches_correct_series() {
        let entries = serde_json::to_string(&vec![
            make_ep_entry(Some("series-1"), "episode", 10000, 5000), // in-progress
            make_ep_entry(Some("series-1"), "episode", 10000, 5000), // in-progress
            make_ep_entry(Some("series-2"), "episode", 10000, 5000), // wrong series
        ])
        .unwrap();
        assert_eq!(count_in_progress_episodes(&entries, "series-1"), 2);
    }

    #[test]
    fn count_in_progress_wrong_series_excluded() {
        let entries = serde_json::to_string(&vec![make_ep_entry(
            Some("series-2"),
            "episode",
            10000,
            5000,
        )])
        .unwrap();
        assert_eq!(count_in_progress_episodes(&entries, "series-1"), 0);
    }

    #[test]
    fn count_in_progress_completed_excluded() {
        // 9500/10000 = 95% >= COMPLETION_THRESHOLD → not in-progress
        let entries = serde_json::to_string(&vec![
            make_ep_entry(Some("s1"), "episode", 10000, 9500),
            make_ep_entry(Some("s1"), "episode", 10000, 5000), // in-progress
        ])
        .unwrap();
        assert_eq!(count_in_progress_episodes(&entries, "s1"), 1);
    }

    // ── resolve_next_episodes ────────────────────────

    fn make_resolve_entry(
        id: &str,
        series_id: Option<&str>,
        season_number: Option<i32>,
        episode_number: Option<i32>,
        position_ms: i64,
        duration_ms: i64,
    ) -> serde_json::Value {
        serde_json::json!({
            "id": id,
            "media_type": "episode",
            "name": format!("Episode {}", id),
            "stream_url": format!("http://example.com/{}", id),
            "poster_url": null,
            "series_poster_url": "http://example.com/series_poster.jpg",
            "position_ms": position_ms,
            "duration_ms": duration_ms,
            "last_watched": "2024-03-01T10:00:00",
            "series_id": series_id,
            "season_number": season_number,
            "episode_number": episode_number,
            "device_id": "dev-1",
            "device_name": "My Device",
            "profile_id": "profile-1",
        })
    }

    fn make_vod_episode(
        id: &str,
        series_id: &str,
        season_number: i32,
        episode_number: i32,
    ) -> serde_json::Value {
        serde_json::json!({
            "id": id,
            "name": format!("S{:02}E{:02}", season_number, episode_number),
            "type": "episode",
            "stream_url": format!("http://example.com/vod/{}", id),
            "poster_url": format!("http://example.com/poster/{}.jpg", id),
            "series_id": series_id,
            "season_number": season_number,
            "episode_number": episode_number,
        })
    }

    #[test]
    fn resolve_next_episode_same_season() {
        let entries = serde_json::to_string(&vec![make_resolve_entry(
            "ep1",
            Some("s1"),
            Some(1),
            Some(1),
            9500,
            10000,
        )])
        .unwrap();
        let vod = serde_json::to_string(&vec![
            make_vod_episode("ep1", "s1", 1, 1),
            make_vod_episode("ep2", "s1", 1, 2),
        ])
        .unwrap();

        let result: Vec<serde_json::Value> =
            serde_json::from_str(&resolve_next_episodes(&entries, &vod, 0.9)).unwrap();
        assert_eq!(result.len(), 1);
        assert_eq!(result[0]["id"], "ep2");
        assert_eq!(result[0]["season_number"], 1);
        assert_eq!(result[0]["episode_number"], 2);
        assert_eq!(result[0]["position_ms"], 0);
        assert_eq!(result[0]["duration_ms"], 0);
        // series_poster_url from original entry preserved
        assert_eq!(
            result[0]["series_poster_url"],
            "http://example.com/series_poster.jpg"
        );
        // device / profile from original entry preserved
        assert_eq!(result[0]["device_id"], "dev-1");
        assert_eq!(result[0]["profile_id"], "profile-1");
    }

    #[test]
    fn resolve_next_episode_crosses_season_boundary() {
        let entries = serde_json::to_string(&vec![make_resolve_entry(
            "ep3",
            Some("s1"),
            Some(1),
            Some(3),
            9000,
            10000,
        )])
        .unwrap();
        let vod = serde_json::to_string(&vec![
            make_vod_episode("ep1", "s1", 1, 1),
            make_vod_episode("ep2", "s1", 1, 2),
            make_vod_episode("ep3", "s1", 1, 3),
            make_vod_episode("ep4", "s1", 2, 1), // next season
        ])
        .unwrap();

        let result: Vec<serde_json::Value> =
            serde_json::from_str(&resolve_next_episodes(&entries, &vod, 0.9)).unwrap();
        assert_eq!(result[0]["id"], "ep4");
        assert_eq!(result[0]["season_number"], 2);
        assert_eq!(result[0]["episode_number"], 1);
    }

    #[test]
    fn resolve_last_episode_keeps_original() {
        let entries = serde_json::to_string(&vec![make_resolve_entry(
            "ep2",
            Some("s1"),
            Some(1),
            Some(2),
            9500,
            10000,
        )])
        .unwrap();
        let vod = serde_json::to_string(&vec![
            make_vod_episode("ep1", "s1", 1, 1),
            make_vod_episode("ep2", "s1", 1, 2), // last episode
        ])
        .unwrap();

        let result: Vec<serde_json::Value> =
            serde_json::from_str(&resolve_next_episodes(&entries, &vod, 0.9)).unwrap();
        assert_eq!(result[0]["id"], "ep2"); // unchanged
        assert_eq!(result[0]["position_ms"], 9500); // position preserved
    }

    #[test]
    fn resolve_below_threshold_keeps_original() {
        let entries = serde_json::to_string(&vec![make_resolve_entry(
            "ep1",
            Some("s1"),
            Some(1),
            Some(1),
            5000,
            10000, // 50% — below threshold
        )])
        .unwrap();
        let vod = serde_json::to_string(&vec![
            make_vod_episode("ep1", "s1", 1, 1),
            make_vod_episode("ep2", "s1", 1, 2),
        ])
        .unwrap();

        let result: Vec<serde_json::Value> =
            serde_json::from_str(&resolve_next_episodes(&entries, &vod, 0.9)).unwrap();
        assert_eq!(result[0]["id"], "ep1"); // unchanged
    }

    #[test]
    fn resolve_non_episode_entry_keeps_original() {
        let entry = serde_json::json!({
            "id": "movie1",
            "media_type": "movie",
            "name": "Some Movie",
            "stream_url": "http://example.com/movie1",
            "position_ms": 9500i64,
            "duration_ms": 10000i64,
            "last_watched": "2024-03-01T10:00:00",
        });
        let entries = serde_json::to_string(&vec![entry]).unwrap();
        let vod = "[]";

        let result: Vec<serde_json::Value> =
            serde_json::from_str(&resolve_next_episodes(&entries, vod, 0.9)).unwrap();
        assert_eq!(result[0]["id"], "movie1");
        assert_eq!(result[0]["media_type"], "movie");
    }

    #[test]
    fn resolve_empty_vod_items_keeps_original() {
        let entries = serde_json::to_string(&vec![make_resolve_entry(
            "ep1",
            Some("s1"),
            Some(1),
            Some(1),
            9500,
            10000,
        )])
        .unwrap();

        let result: Vec<serde_json::Value> =
            serde_json::from_str(&resolve_next_episodes(&entries, "[]", 0.9)).unwrap();
        assert_eq!(result[0]["id"], "ep1"); // unchanged — no VOD items to look up
    }

    #[test]
    fn resolve_multiple_series_resolved_independently() {
        let entries = serde_json::to_string(&vec![
            make_resolve_entry("s1e1", Some("series-a"), Some(1), Some(1), 9500, 10000),
            make_resolve_entry("s2e1", Some("series-b"), Some(1), Some(1), 9500, 10000),
        ])
        .unwrap();
        let vod = serde_json::to_string(&vec![
            make_vod_episode("s1e1", "series-a", 1, 1),
            make_vod_episode("s1e2", "series-a", 1, 2),
            make_vod_episode("s2e1", "series-b", 1, 1),
            make_vod_episode("s2e2", "series-b", 1, 2),
        ])
        .unwrap();

        let result: Vec<serde_json::Value> =
            serde_json::from_str(&resolve_next_episodes(&entries, &vod, 0.9)).unwrap();
        assert_eq!(result.len(), 2);
        assert_eq!(result[0]["id"], "s1e2");
        assert_eq!(result[1]["id"], "s2e2");
    }

    // ── episode_count_by_season ──────────────────────

    #[test]
    fn episode_count_by_season_multiple_seasons() {
        let episodes = serde_json::to_string(&vec![
            serde_json::json!({"season_number": 1}),
            serde_json::json!({"season_number": 1}),
            serde_json::json!({"season_number": 2}),
            serde_json::json!({"season_number": 2}),
            serde_json::json!({"season_number": 2}),
        ])
        .unwrap();

        let result: std::collections::HashMap<String, usize> =
            serde_json::from_str(&episode_count_by_season(&episodes)).unwrap();
        assert_eq!(result["1"], 2);
        assert_eq!(result["2"], 3);
    }

    #[test]
    fn episode_count_null_season_skipped() {
        let episodes = serde_json::to_string(&vec![
            serde_json::json!({"season_number": 1}),
            serde_json::json!({"season_number": null}),
            serde_json::json!({}), // no season_number key
        ])
        .unwrap();

        let result: std::collections::HashMap<String, usize> =
            serde_json::from_str(&episode_count_by_season(&episodes)).unwrap();
        assert_eq!(result.len(), 1);
        assert_eq!(result["1"], 1);
    }

    #[test]
    fn episode_count_empty_returns_empty_object() {
        let result: std::collections::HashMap<String, usize> =
            serde_json::from_str(&episode_count_by_season("[]")).unwrap();
        assert!(result.is_empty());
    }
}
