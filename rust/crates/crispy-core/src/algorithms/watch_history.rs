//! Watch history filtering algorithms.
//!
//! Ports `getContinueWatching` and `getFromOtherDevices`
//! from Dart `watch_history_service.dart`.
//! Also ports streak/stats/merge/filter helpers from
//! profiles and favorites domain utils.

use chrono::{NaiveDate, NaiveDateTime, TimeZone, Utc};
use serde::{Deserialize, Serialize};

use crate::algorithms::json_utils::parse_json_vec;
use crate::algorithms::watch_progress::COMPLETION_THRESHOLD;
use crate::models::WatchHistory;

/// Maximum items returned by [`filter_continue_watching`].
const CONTINUE_WATCHING_LIMIT: usize = 20;

/// Maximum items returned by [`filter_cross_device`].
const CROSS_DEVICE_LIMIT: usize = 10;

/// Returns `true` when an entry has meaningful progress
/// but has not been completed (< 95%).
fn is_in_progress(entry: &WatchHistory) -> bool {
    entry.position_ms > 0
        && entry.duration_ms > 0
        && (entry.position_ms as f64 / entry.duration_ms as f64) < COMPLETION_THRESHOLD
}

/// Filter watch history for "continue watching" items.
///
/// Returns items with progress > 0% and < 95%, sorted by
/// most recently watched, limited to 20. Optionally
/// filtered by `media_type` ("channel", "movie",
/// "episode").
pub fn filter_continue_watching(
    entries: &[WatchHistory],
    media_type: Option<&str>,
    profile_id: Option<&str>,
) -> Vec<WatchHistory> {
    let mut result: Vec<WatchHistory> = entries
        .iter()
        .filter(|e| {
            let in_prog = is_in_progress(e);
            let mt_match = media_type.is_none_or(|mt| e.media_type == mt);
            let pid_match = profile_id.is_none_or(|pid| e.profile_id.as_deref() == Some(pid));

            in_prog && mt_match && pid_match
        })
        .cloned()
        .collect();

    result.sort_by(|a, b| b.last_watched.cmp(&a.last_watched));

    // Deduplicate series episodes: keep only the most recently watched
    let mut seen_series = std::collections::HashSet::new();
    result.retain(|e| {
        if let Some(sid) = &e.series_id
            && !seen_series.insert(sid.clone())
        {
            return false;
        }
        true
    });

    // Deduplicate by (profile_id, name): keep only the most recently
    // watched entry per title. This handles duplicate rows that arise
    // when a stream URL changes (token rotation, playlist reload) so
    // that the same content gets a different primary-key hash but the
    // same human-readable name.
    // The list is already sorted by last_watched descending, so the
    // first occurrence of each name is always the most recent.
    let mut seen_names = std::collections::HashSet::new();
    result.retain(|e| {
        let key = format!("{}:{}", e.profile_id.as_deref().unwrap_or(""), &e.name);
        seen_names.insert(key)
    });

    result.truncate(CONTINUE_WATCHING_LIMIT);
    result
}

/// Filter watch history for items watched on other
/// devices.
///
/// Returns items from different devices, within the
/// `cutoff` date, with progress > 0% and < 95%, sorted
/// by most recent, limited to 10.
pub fn filter_cross_device(
    entries: &[WatchHistory],
    current_device_id: &str,
    cutoff: NaiveDateTime,
) -> Vec<WatchHistory> {
    let mut result: Vec<WatchHistory> = entries
        .iter()
        .filter(|e| {
            is_in_progress(e)
                && e.device_id
                    .as_deref()
                    .is_some_and(|did| did != current_device_id)
                && e.last_watched >= cutoff
        })
        .cloned()
        .collect();

    result.sort_by(|a, b| b.last_watched.cmp(&a.last_watched));

    // Deduplicate series episodes: keep only the most recently watched
    let mut seen_series = std::collections::HashSet::new();
    result.retain(|e| {
        if let Some(sid) = &e.series_id
            && !seen_series.insert(sid.clone())
        {
            return false;
        }
        true
    });

    result.truncate(CROSS_DEVICE_LIMIT);
    result
}

// ─────────────────────────────────────────────────────────────────────────────
// Function 1: compute_watch_streak
// ─────────────────────────────────────────────────────────────────────────────

/// Converts an epoch-ms timestamp to a `NaiveDate` (UTC).
fn epoch_ms_to_date(epoch_ms: i64) -> NaiveDate {
    Utc.timestamp_millis_opt(epoch_ms)
        .single()
        .unwrap_or_default()
        .naive_utc()
        .date()
}

/// Computes the current watch streak (consecutive calendar days ending today
/// or yesterday that each have at least one entry).
///
/// Ports `computeWatchStreak` from Dart
/// `lib/features/profiles/domain/utils/watch_streak.dart`.
///
/// `timestamps_json` — JSON array of epoch-ms `i64` values.
/// `now_ms`          — current time as epoch-ms (injectable for tests).
///
/// Returns 0 when the input is empty or the streak is broken.
pub fn compute_watch_streak(timestamps_json: &str, now_ms: i64) -> u32 {
    let Some(timestamps) = parse_json_vec::<i64>(timestamps_json) else {
        return 0;
    };
    if timestamps.is_empty() {
        return 0;
    }

    // Collect distinct calendar days.
    let mut days: std::collections::HashSet<NaiveDate> = std::collections::HashSet::new();
    for ts in &timestamps {
        days.insert(epoch_ms_to_date(*ts));
    }

    let today = epoch_ms_to_date(now_ms);

    // Walk backwards from today; allow starting from yesterday too.
    let mut current = if days.contains(&today) {
        today
    } else {
        today.pred_opt().unwrap_or(today)
    };

    if !days.contains(&current) {
        return 0;
    }

    let mut streak: u32 = 0;
    while days.contains(&current) {
        streak += 1;
        current = current.pred_opt().unwrap_or(current);
        // Safety: pred_opt returns None only before NaiveDate::MIN, which
        // cannot happen with real watch-history timestamps.
        if streak > 10_000 {
            break; // guard against infinite loops on degenerate input
        }
    }
    streak
}

// ─────────────────────────────────────────────────────────────────────────────
// Function 2: compute_profile_stats
// ─────────────────────────────────────────────────────────────────────────────

/// Aggregated viewing statistics for a single profile.
///
/// Serialised to JSON for the FFI boundary.
#[derive(Debug, Serialize, Deserialize)]
pub struct ProfileStats {
    /// Total hours watched (sum of position_ms / 3_600_000).
    pub total_hours_watched: f64,
    /// Top 3 channels/shows by watch count.
    pub top_channels: Vec<String>,
    /// Top 3 genre labels by watch count.
    pub top_genres: Vec<String>,
    /// Current consecutive watch streak in days.
    pub watch_streak_days: u32,
}

/// Minimal history entry shape used by `compute_profile_stats`.
#[derive(Debug, Deserialize)]
struct HistoryEntry {
    name: String,
    media_type: String,
    position_ms: i64,
    last_watched: i64,
    #[serde(default)]
    series_id: Option<String>,
}

/// Maps a media-type string to a genre label.
fn media_type_to_genre(media_type: &str) -> &'static str {
    match media_type {
        "movie" => "Movies",
        "episode" => "Series",
        "channel" => "Live TV",
        _ => "Other",
    }
}

/// Computes aggregated viewing statistics for a single profile.
///
/// Ports `ProfileViewingStats.compute` from Dart
/// `lib/features/profiles/domain/utils/profile_stats.dart`.
///
/// `history_json` — JSON array of watch-history objects with fields:
///   `name`, `media_type`, `position_ms`, `last_watched` (epoch-ms),
///   `series_id` (optional).
/// `now_ms`       — current time as epoch-ms.
///
/// Returns a JSON-serialised `ProfileStats`.
pub fn compute_profile_stats(history_json: &str, now_ms: i64) -> String {
    let Some(entries) = parse_json_vec::<HistoryEntry>(history_json) else {
        return serde_json::to_string(&ProfileStats {
            total_hours_watched: 0.0,
            top_channels: vec![],
            top_genres: vec![],
            watch_streak_days: 0,
        })
        .unwrap_or_else(|_| "{}".to_string());
    };

    if entries.is_empty() {
        return serde_json::to_string(&ProfileStats {
            total_hours_watched: 0.0,
            top_channels: vec![],
            top_genres: vec![],
            watch_streak_days: 0,
        })
        .unwrap_or_else(|_| "{}".to_string());
    }

    // Total hours watched.
    let total_ms: i64 = entries.iter().map(|e| e.position_ms).sum();
    let total_hours = total_ms as f64 / 3_600_000.0;

    // Top channels — for series entries, use name.split(" - ").first().
    let mut channel_counts: std::collections::HashMap<String, u32> =
        std::collections::HashMap::new();
    for e in &entries {
        let key = if e.series_id.is_some() {
            e.name.split(" - ").next().unwrap_or(&e.name).to_string()
        } else {
            e.name.clone()
        };
        *channel_counts.entry(key).or_insert(0) += 1;
    }
    let mut channel_vec: Vec<(String, u32)> = channel_counts.into_iter().collect();
    channel_vec.sort_by(|a, b| b.1.cmp(&a.1).then(a.0.cmp(&b.0)));
    let top_channels: Vec<String> = channel_vec.into_iter().take(3).map(|(k, _)| k).collect();

    // Top genres — derived from media_type.
    let mut genre_counts: std::collections::HashMap<&str, u32> = std::collections::HashMap::new();
    for e in &entries {
        *genre_counts
            .entry(media_type_to_genre(&e.media_type))
            .or_insert(0) += 1;
    }
    let mut genre_vec: Vec<(&str, u32)> = genre_counts.into_iter().collect();
    genre_vec.sort_by(|a, b| b.1.cmp(&a.1).then(a.0.cmp(b.0)));
    let top_genres: Vec<String> = genre_vec
        .into_iter()
        .take(3)
        .map(|(k, _)| k.to_string())
        .collect();

    // Watch streak — extract last_watched timestamps.
    let timestamps: Vec<i64> = entries.iter().map(|e| e.last_watched).collect();
    let timestamps_json = serde_json::to_string(&timestamps).unwrap_or_else(|_| "[]".to_string());
    let watch_streak_days = compute_watch_streak(&timestamps_json, now_ms);

    serde_json::to_string(&ProfileStats {
        total_hours_watched: total_hours,
        top_channels,
        top_genres,
        watch_streak_days,
    })
    .unwrap_or_else(|_| "{}".to_string())
}

// ─────────────────────────────────────────────────────────────────────────────
// Function 3: merge_dedup_sort_history
// ─────────────────────────────────────────────────────────────────────────────

/// Merges two `WatchHistory` JSON arrays, deduplicates by `id` (first
/// occurrence wins), and sorts by `last_watched` descending.
///
/// Ports `mergeDedupSort` from Dart
/// `lib/features/favorites/domain/utils/cw_filter_utils.dart` (lines 15-29).
///
/// Returns a JSON array.
pub fn merge_dedup_sort_history(a_json: &str, b_json: &str) -> String {
    let a: Vec<WatchHistory> = parse_json_vec(a_json).unwrap_or_default();
    let b: Vec<WatchHistory> = parse_json_vec(b_json).unwrap_or_default();

    let mut combined: Vec<WatchHistory> = Vec::with_capacity(a.len() + b.len());
    combined.extend(a);
    combined.extend(b);

    // Deduplicate by id — first occurrence wins.
    let mut seen: std::collections::HashSet<String> = std::collections::HashSet::new();
    combined.retain(|e| seen.insert(e.id.clone()));

    // Sort by last_watched descending.
    combined.sort_by(|x, y| y.last_watched.cmp(&x.last_watched));

    serde_json::to_string(&combined).unwrap_or_else(|_| "[]".to_string())
}

// ─────────────────────────────────────────────────────────────────────────────
// Function 4: filter_by_cw_status
// ─────────────────────────────────────────────────────────────────────────────

/// Filters a `WatchHistory` JSON array by continue-watching status.
///
/// Ports `filterByCwStatus` from Dart
/// `lib/features/favorites/domain/utils/cw_filter_utils.dart` (lines 54-68).
///
/// `filter` values:
/// - `"all"`       — return all entries unchanged.
/// - `"watching"`  — progress > 0 and < `COMPLETION_THRESHOLD`.
/// - `"completed"` — progress >= `COMPLETION_THRESHOLD`.
///
/// Returns a JSON array.
pub fn filter_by_cw_status(history_json: &str, filter: &str) -> String {
    let Some(entries) = parse_json_vec::<WatchHistory>(history_json) else {
        return "[]".to_string();
    };

    let filtered: Vec<&WatchHistory> = entries
        .iter()
        .filter(|e| {
            let progress = if e.duration_ms > 0 {
                e.position_ms as f64 / e.duration_ms as f64
            } else {
                0.0
            };
            match filter {
                "all" => true,
                "watching" => progress > 0.0 && progress < COMPLETION_THRESHOLD,
                "completed" => progress >= COMPLETION_THRESHOLD,
                _ => false,
            }
        })
        .collect();

    serde_json::to_string(&filtered).unwrap_or_else(|_| "[]".to_string())
}

// ─────────────────────────────────────────────────────────────────────────────
// Function 5: series_ids_with_new_episodes
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// Function 6: count_in_progress_episodes
// ─────────────────────────────────────────────────────────────────────────────

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
                && e.media_type == "episode"
                && e.duration_ms > 0
                && (e.position_ms as f64 / e.duration_ms as f64) < COMPLETION_THRESHOLD
        })
        .count()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::algorithms::normalize::EPG_FORMAT;

    fn ts(s: &str) -> NaiveDateTime {
        NaiveDateTime::parse_from_str(s, EPG_FORMAT).unwrap()
    }

    fn make_entry(
        id: &str,
        media_type: &str,
        position_ms: i64,
        duration_ms: i64,
        last_watched: &str,
        device_id: Option<&str>,
    ) -> WatchHistory {
        WatchHistory {
            id: id.to_string(),
            media_type: media_type.to_string(),
            name: format!("Item {id}"),
            stream_url: format!("http://example.com/{id}"),
            poster_url: None,
            series_poster_url: None,
            position_ms,
            duration_ms,
            last_watched: ts(last_watched),
            series_id: None,
            season_number: None,
            episode_number: None,
            device_id: device_id.map(String::from),
            device_name: None,
            profile_id: None,
        }
    }

    // ── filter_continue_watching ─────────────────────

    #[test]
    fn continue_watching_filters_zero_progress() {
        let entries = vec![
            make_entry("a", "movie", 0, 10000, "2024-03-01 10:00:00", None),
            make_entry("b", "movie", 5000, 10000, "2024-03-01 10:00:00", None),
        ];
        let r = filter_continue_watching(&entries, None, None);
        assert_eq!(r.len(), 1);
        assert_eq!(r[0].id, "b");
    }

    #[test]
    fn continue_watching_filters_completed() {
        let entries = vec![
            // 95% — excluded (>= threshold)
            make_entry("a", "movie", 9500, 10000, "2024-03-01 10:00:00", None),
            // 96% — excluded
            make_entry("b", "movie", 9600, 10000, "2024-03-01 10:00:00", None),
            // 100% — excluded
            make_entry("c", "movie", 10000, 10000, "2024-03-01 10:00:00", None),
            // 50% — included
            make_entry("d", "movie", 5000, 10000, "2024-03-01 10:00:00", None),
        ];
        let r = filter_continue_watching(&entries, None, None);
        assert_eq!(r.len(), 1);
        assert_eq!(r[0].id, "d");
    }

    #[test]
    fn continue_watching_filters_zero_duration() {
        let entries = vec![make_entry(
            "a",
            "movie",
            5000,
            0,
            "2024-03-01 10:00:00",
            None,
        )];
        let r = filter_continue_watching(&entries, None, None);
        assert!(r.is_empty());
    }

    #[test]
    fn continue_watching_sorts_by_most_recent() {
        let entries = vec![
            make_entry("old", "movie", 5000, 10000, "2024-01-01 10:00:00", None),
            make_entry("new", "movie", 5000, 10000, "2024-03-01 10:00:00", None),
            make_entry("mid", "movie", 5000, 10000, "2024-02-01 10:00:00", None),
        ];
        let r = filter_continue_watching(&entries, None, None);
        assert_eq!(r.len(), 3);
        assert_eq!(r[0].id, "new");
        assert_eq!(r[1].id, "mid");
        assert_eq!(r[2].id, "old");
    }

    #[test]
    fn continue_watching_limits_to_20() {
        let entries: Vec<WatchHistory> = (0..30)
            .map(|i| {
                make_entry(
                    &format!("e{i}"),
                    "movie",
                    5000,
                    10000,
                    &format!("2024-03-{:02} 10:00:00", (i % 28) + 1),
                    None,
                )
            })
            .collect();
        let r = filter_continue_watching(&entries, None, None);
        assert_eq!(r.len(), 20);
    }

    #[test]
    fn continue_watching_filters_by_media_type() {
        let entries = vec![
            make_entry("ch", "channel", 5000, 10000, "2024-03-01 10:00:00", None),
            make_entry("mv", "movie", 5000, 10000, "2024-03-01 10:00:00", None),
            make_entry("ep", "episode", 5000, 10000, "2024-03-01 10:00:00", None),
        ];

        let movies = filter_continue_watching(&entries, Some("movie"), None);
        assert_eq!(movies.len(), 1);
        assert_eq!(movies[0].id, "mv");

        let all = filter_continue_watching(&entries, None, None);
        assert_eq!(all.len(), 3);
    }

    // ── filter_cross_device ──────────────────────────

    #[test]
    fn cross_device_filters_same_device() {
        let entries = vec![
            make_entry(
                "a",
                "movie",
                5000,
                10000,
                "2024-03-01 10:00:00",
                Some("dev-1"),
            ),
            make_entry(
                "b",
                "movie",
                5000,
                10000,
                "2024-03-01 10:00:00",
                Some("dev-2"),
            ),
        ];
        let cutoff = ts("2024-01-01 00:00:00");
        let r = filter_cross_device(&entries, "dev-1", cutoff);
        assert_eq!(r.len(), 1);
        assert_eq!(r[0].id, "b");
    }

    #[test]
    fn cross_device_filters_null_device() {
        let entries = vec![
            make_entry("a", "movie", 5000, 10000, "2024-03-01 10:00:00", None),
            make_entry(
                "b",
                "movie",
                5000,
                10000,
                "2024-03-01 10:00:00",
                Some("dev-2"),
            ),
        ];
        let cutoff = ts("2024-01-01 00:00:00");
        let r = filter_cross_device(&entries, "dev-1", cutoff);
        assert_eq!(r.len(), 1);
        assert_eq!(r[0].id, "b");
    }

    #[test]
    fn cross_device_filters_before_cutoff() {
        let entries = vec![
            make_entry(
                "old",
                "movie",
                5000,
                10000,
                "2024-01-01 10:00:00",
                Some("dev-2"),
            ),
            make_entry(
                "new",
                "movie",
                5000,
                10000,
                "2024-03-01 10:00:00",
                Some("dev-2"),
            ),
        ];
        let cutoff = ts("2024-02-01 00:00:00");
        let r = filter_cross_device(&entries, "dev-1", cutoff);
        assert_eq!(r.len(), 1);
        assert_eq!(r[0].id, "new");
    }

    #[test]
    fn cross_device_limits_to_10() {
        let entries: Vec<WatchHistory> = (0..20)
            .map(|i| {
                make_entry(
                    &format!("e{i}"),
                    "movie",
                    5000,
                    10000,
                    &format!("2024-03-{:02} 10:00:00", (i % 28) + 1),
                    Some("other-dev"),
                )
            })
            .collect();
        let cutoff = ts("2024-01-01 00:00:00");
        let r = filter_cross_device(&entries, "my-dev", cutoff);
        assert_eq!(r.len(), 10);
    }

    #[test]
    fn cross_device_sorts_by_most_recent() {
        let entries = vec![
            make_entry(
                "old",
                "movie",
                5000,
                10000,
                "2024-02-01 10:00:00",
                Some("dev-2"),
            ),
            make_entry(
                "new",
                "movie",
                5000,
                10000,
                "2024-03-01 10:00:00",
                Some("dev-2"),
            ),
        ];
        let cutoff = ts("2024-01-01 00:00:00");
        let r = filter_cross_device(&entries, "dev-1", cutoff);
        assert_eq!(r[0].id, "new");
        assert_eq!(r[1].id, "old");
    }

    #[test]
    fn continue_watching_deduplicates_by_name() {
        // Two entries with the same name (same content, different URL/id due to
        // token rotation). The more recently watched one should be kept.
        let mut older = make_entry("old-id", "movie", 5000, 10000, "2024-02-01 10:00:00", None);
        older.name = "My Movie".to_string();

        let mut newer = make_entry("new-id", "movie", 6000, 10000, "2024-03-01 10:00:00", None);
        newer.name = "My Movie".to_string();

        let entries = vec![older, newer];
        let r = filter_continue_watching(&entries, None, None);
        assert_eq!(r.len(), 1);
        assert_eq!(r[0].id, "new-id");
        assert_eq!(r[0].position_ms, 6000);
    }

    #[test]
    fn continue_watching_deduplicates_by_name_per_profile() {
        // Same name but different profiles — both should survive.
        let mut e1 = make_entry("id-1", "movie", 5000, 10000, "2024-03-01 10:00:00", None);
        e1.name = "My Movie".to_string();
        e1.profile_id = Some("profile-a".to_string());

        let mut e2 = make_entry("id-2", "movie", 5000, 10000, "2024-03-01 10:00:00", None);
        e2.name = "My Movie".to_string();
        e2.profile_id = Some("profile-b".to_string());

        let entries = vec![e1, e2];
        let r = filter_continue_watching(&entries, None, None);
        assert_eq!(r.len(), 2);
    }

    // ── edge cases ───────────────────────────────────

    #[test]
    fn empty_input_returns_empty() {
        let r = filter_continue_watching(&[], None, None);
        assert!(r.is_empty());

        let cutoff = ts("2024-01-01 00:00:00");
        let r = filter_cross_device(&[], "dev-1", cutoff);
        assert!(r.is_empty());
    }

    // ── compute_watch_streak ─────────────────────────

    /// Helper: epoch-ms for a UTC calendar date at midnight.
    fn date_ms(year: i32, month: u32, day: u32) -> i64 {
        Utc.with_ymd_and_hms(year, month, day, 0, 0, 0)
            .unwrap()
            .timestamp_millis()
    }

    #[test]
    fn streak_consecutive_days() {
        // 3 consecutive days: Mar 1, 2, 3. now = Mar 3 → streak 3.
        let timestamps = serde_json::to_string(&vec![
            date_ms(2024, 3, 1),
            date_ms(2024, 3, 2),
            date_ms(2024, 3, 3),
        ])
        .unwrap();
        let now = date_ms(2024, 3, 3) + 3_600_000; // same day, 1h later
        assert_eq!(compute_watch_streak(&timestamps, now), 3);
    }

    #[test]
    fn streak_gap_breaks_streak() {
        // Mar 1 and Mar 3 — no Mar 2 — streak from today (Mar 3) = 1.
        let timestamps =
            serde_json::to_string(&vec![date_ms(2024, 3, 1), date_ms(2024, 3, 3)]).unwrap();
        let now = date_ms(2024, 3, 3) + 3_600_000;
        assert_eq!(compute_watch_streak(&timestamps, now), 1);
    }

    #[test]
    fn streak_start_from_yesterday_when_nothing_today() {
        // Watched Mar 1, 2, 3. now = Mar 4 (nothing today) → start from Mar 3 → streak 3.
        let timestamps = serde_json::to_string(&vec![
            date_ms(2024, 3, 1),
            date_ms(2024, 3, 2),
            date_ms(2024, 3, 3),
        ])
        .unwrap();
        let now = date_ms(2024, 3, 4) + 3_600_000;
        assert_eq!(compute_watch_streak(&timestamps, now), 3);
    }

    #[test]
    fn streak_empty_input_returns_zero() {
        assert_eq!(compute_watch_streak("[]", date_ms(2024, 3, 3)), 0);
    }

    #[test]
    fn streak_single_day_today() {
        let timestamps = serde_json::to_string(&vec![date_ms(2024, 3, 3)]).unwrap();
        let now = date_ms(2024, 3, 3) + 1_000;
        assert_eq!(compute_watch_streak(&timestamps, now), 1);
    }

    // ── compute_profile_stats ────────────────────────

    fn make_history_entry_json(
        name: &str,
        media_type: &str,
        position_ms: i64,
        last_watched: i64,
        series_id: Option<&str>,
    ) -> serde_json::Value {
        serde_json::json!({
            "name": name,
            "media_type": media_type,
            "position_ms": position_ms,
            "last_watched": last_watched,
            "series_id": series_id,
        })
    }

    #[test]
    fn profile_stats_empty_returns_zeros() {
        let result = compute_profile_stats("[]", date_ms(2024, 3, 3));
        let stats: ProfileStats = serde_json::from_str(&result).unwrap();
        assert_eq!(stats.total_hours_watched, 0.0);
        assert!(stats.top_channels.is_empty());
        assert!(stats.top_genres.is_empty());
        assert_eq!(stats.watch_streak_days, 0);
    }

    #[test]
    fn profile_stats_normal_aggregation() {
        // 3_600_000 ms = 1 hour
        let entries = serde_json::to_string(&vec![
            make_history_entry_json("Movie A", "movie", 3_600_000, date_ms(2024, 3, 3), None),
            make_history_entry_json("Movie A", "movie", 3_600_000, date_ms(2024, 3, 2), None),
            make_history_entry_json("Live CH", "channel", 1_800_000, date_ms(2024, 3, 1), None),
        ])
        .unwrap();
        let now = date_ms(2024, 3, 3) + 1_000;
        let result = compute_profile_stats(&entries, now);
        let stats: ProfileStats = serde_json::from_str(&result).unwrap();

        // 3.6M + 3.6M + 1.8M = 9M ms = 2.5 hours
        assert!((stats.total_hours_watched - 2.5).abs() < 1e-9);
        assert_eq!(stats.top_channels[0], "Movie A");
        assert_eq!(stats.top_genres[0], "Movies");
    }

    #[test]
    fn profile_stats_series_name_extraction() {
        // For series entries, name.split(" - ").first() is used.
        let entries = serde_json::to_string(&vec![
            make_history_entry_json(
                "Breaking Bad - S01 E01",
                "episode",
                1_800_000,
                date_ms(2024, 3, 3),
                Some("bb-series"),
            ),
            make_history_entry_json(
                "Breaking Bad - S01 E02",
                "episode",
                1_800_000,
                date_ms(2024, 3, 3),
                Some("bb-series"),
            ),
        ])
        .unwrap();
        let now = date_ms(2024, 3, 3) + 1_000;
        let result = compute_profile_stats(&entries, now);
        let stats: ProfileStats = serde_json::from_str(&result).unwrap();
        assert_eq!(stats.top_channels[0], "Breaking Bad");
    }

    #[test]
    fn profile_stats_genre_mapping() {
        // Two episodes so "Series" beats "Other" (unknown) in top-3 ranking.
        let entries = serde_json::to_string(&vec![
            make_history_entry_json("M1", "movie", 1000, date_ms(2024, 3, 3), None),
            make_history_entry_json("E1", "episode", 1000, date_ms(2024, 3, 3), None),
            make_history_entry_json("E2", "episode", 1000, date_ms(2024, 3, 3), None),
            make_history_entry_json("C1", "channel", 1000, date_ms(2024, 3, 3), None),
            make_history_entry_json("X1", "unknown", 1000, date_ms(2024, 3, 3), None),
        ])
        .unwrap();
        let now = date_ms(2024, 3, 3) + 1_000;
        let result = compute_profile_stats(&entries, now);
        let stats: ProfileStats = serde_json::from_str(&result).unwrap();
        // "Series" has count 2; "Movies" and "Live TV" have count 1 each — all in top 3.
        assert!(stats.top_genres.contains(&"Movies".to_string()));
        assert!(stats.top_genres.contains(&"Series".to_string()));
        assert!(stats.top_genres.contains(&"Live TV".to_string()));
    }

    #[test]
    fn profile_stats_streak_included() {
        // 2 consecutive days, now = day 2 → streak 2.
        let entries = serde_json::to_string(&vec![
            make_history_entry_json("M1", "movie", 1000, date_ms(2024, 3, 1), None),
            make_history_entry_json("M2", "movie", 1000, date_ms(2024, 3, 2), None),
        ])
        .unwrap();
        let now = date_ms(2024, 3, 2) + 1_000;
        let result = compute_profile_stats(&entries, now);
        let stats: ProfileStats = serde_json::from_str(&result).unwrap();
        assert_eq!(stats.watch_streak_days, 2);
    }

    // ── merge_dedup_sort_history ─────────────────────

    /// Build a `WatchHistory`-compatible JSON object.
    ///
    /// `last_watched` must be in `%Y-%m-%dT%H:%M:%S` format (chrono serde).
    fn make_wh_json(id: &str, last_watched: &str, position_ms: i64) -> serde_json::Value {
        serde_json::json!({
            "id": id,
            "media_type": "movie",
            "name": format!("Item {}", id),
            "stream_url": format!("http://example.com/{}", id),
            "position_ms": position_ms,
            "duration_ms": 10000i64,
            "last_watched": last_watched,
        })
    }

    #[test]
    fn merge_dedup_removes_duplicates() {
        let a =
            serde_json::to_string(&vec![make_wh_json("1", "2024-03-01T10:00:00", 5000)]).unwrap();
        let b = serde_json::to_string(&vec![
            make_wh_json("1", "2024-03-02T10:00:00", 6000),
            make_wh_json("2", "2024-03-01T10:00:00", 5000),
        ])
        .unwrap();

        let result = merge_dedup_sort_history(&a, &b);
        let parsed: Vec<serde_json::Value> = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed.len(), 2);
        // id "1" from list `a` wins (first occurrence); position_ms = 5000
        let id1 = parsed.iter().find(|v| v["id"] == "1").unwrap();
        assert_eq!(id1["position_ms"], 5000);
    }

    #[test]
    fn merge_dedup_sort_order() {
        let a = serde_json::to_string(&vec![
            make_wh_json("1", "2024-01-01T10:00:00", 1000),
            make_wh_json("2", "2024-03-01T10:00:00", 2000),
        ])
        .unwrap();
        let b =
            serde_json::to_string(&vec![make_wh_json("3", "2024-02-01T10:00:00", 3000)]).unwrap();

        let result = merge_dedup_sort_history(&a, &b);
        let parsed: Vec<serde_json::Value> = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed.len(), 3);
        assert_eq!(parsed[0]["id"], "2");
        assert_eq!(parsed[1]["id"], "3");
        assert_eq!(parsed[2]["id"], "1");
    }

    #[test]
    fn merge_dedup_one_empty_list() {
        let a =
            serde_json::to_string(&vec![make_wh_json("1", "2024-03-01T10:00:00", 5000)]).unwrap();

        let result = merge_dedup_sort_history(&a, "[]");
        let parsed: Vec<serde_json::Value> = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed.len(), 1);

        let result2 = merge_dedup_sort_history("[]", &a);
        let parsed2: Vec<serde_json::Value> = serde_json::from_str(&result2).unwrap();
        assert_eq!(parsed2.len(), 1);
    }

    #[test]
    fn merge_dedup_both_empty() {
        let result = merge_dedup_sort_history("[]", "[]");
        let parsed: Vec<serde_json::Value> = serde_json::from_str(&result).unwrap();
        assert!(parsed.is_empty());
    }

    // ── filter_by_cw_status ──────────────────────────

    fn make_cw_entry_json(id: &str, position_ms: i64, duration_ms: i64) -> serde_json::Value {
        serde_json::json!({
            "id": id,
            "media_type": "movie",
            "name": format!("Item {}", id),
            "stream_url": format!("http://example.com/{}", id),
            "position_ms": position_ms,
            "duration_ms": duration_ms,
            "last_watched": "2024-03-01T10:00:00",
        })
    }

    #[test]
    fn filter_cw_all_returns_everything() {
        let entries = serde_json::to_string(&vec![
            make_cw_entry_json("a", 5000, 10000),
            make_cw_entry_json("b", 9500, 10000),
            make_cw_entry_json("c", 0, 10000),
        ])
        .unwrap();
        let result: Vec<serde_json::Value> =
            serde_json::from_str(&filter_by_cw_status(&entries, "all")).unwrap();
        assert_eq!(result.len(), 3);
    }

    #[test]
    fn filter_cw_watching_excludes_completed_and_not_started() {
        let entries = serde_json::to_string(&vec![
            make_cw_entry_json("in-prog", 5000, 10000), // 50% — watching
            make_cw_entry_json("done", 9500, 10000),    // 95% — completed
            make_cw_entry_json("not-started", 0, 10000), // 0% — not watching
        ])
        .unwrap();
        let result: Vec<serde_json::Value> =
            serde_json::from_str(&filter_by_cw_status(&entries, "watching")).unwrap();
        assert_eq!(result.len(), 1);
        assert_eq!(result[0]["id"], "in-prog");
    }

    #[test]
    fn filter_cw_completed_returns_at_threshold() {
        let entries = serde_json::to_string(&vec![
            make_cw_entry_json("at-threshold", 9500, 10000), // exactly 95% — completed
            make_cw_entry_json("over", 9800, 10000),         // 98% — completed
            make_cw_entry_json("under", 9400, 10000),        // 94% — watching
        ])
        .unwrap();
        let result: Vec<serde_json::Value> =
            serde_json::from_str(&filter_by_cw_status(&entries, "completed")).unwrap();
        assert_eq!(result.len(), 2);
    }

    #[test]
    fn filter_cw_boundary_at_threshold_exact() {
        // Exactly COMPLETION_THRESHOLD (0.95) = position 950, duration 1000.
        let entries = serde_json::to_string(&vec![make_cw_entry_json("e", 950, 1000)]).unwrap();
        let watching: Vec<serde_json::Value> =
            serde_json::from_str(&filter_by_cw_status(&entries, "watching")).unwrap();
        let completed: Vec<serde_json::Value> =
            serde_json::from_str(&filter_by_cw_status(&entries, "completed")).unwrap();
        assert!(watching.is_empty(), "exactly 95% should not be 'watching'");
        assert_eq!(completed.len(), 1, "exactly 95% should be 'completed'");
    }

    // ── series_ids_with_new_episodes ─────────────────

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
}
