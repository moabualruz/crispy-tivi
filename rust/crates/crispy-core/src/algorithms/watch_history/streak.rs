//! Watch streak and profile stats computation.

use chrono::{NaiveDate, TimeZone, Utc};
use serde::{Deserialize, Serialize};

use crate::algorithms::json_utils::parse_json_vec;

/// Converts an epoch-ms timestamp to a `NaiveDate` (UTC).
pub(super) fn epoch_ms_to_date(epoch_ms: i64) -> NaiveDate {
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
pub(super) fn media_type_to_genre(media_type: &str) -> &'static str {
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
            .entry(media_type_to_genre(e.media_type.as_str()))
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

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::TimeZone;

    /// Helper: epoch-ms for a UTC calendar date at midnight.
    fn date_ms(year: i32, month: u32, day: u32) -> i64 {
        Utc.with_ymd_and_hms(year, month, day, 0, 0, 0)
            .unwrap()
            .timestamp_millis()
    }

    // ── compute_watch_streak ─────────────────────────

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
}
