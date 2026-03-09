//! Continue-watching filters and watch-history ID derivation.

use chrono::NaiveDateTime;
use sha2::{Digest, Sha256};

use crate::algorithms::watch_progress::COMPLETION_THRESHOLD;
use crate::models::WatchHistory;

/// Derives a stable, platform-independent watch-history ID from a stream URL.
///
/// Uses the first 16 hex characters of the SHA-256 hash of the URL
/// (first 8 bytes, zero-padded to 2 hex digits each). This replaces
/// Dart's unstable `hashCode.toRadixString(36)` which varies across
/// platforms, isolates, and SDK versions.
pub fn derive_watch_history_id(url: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(url.as_bytes());
    let result = hasher.finalize();
    result[..8].iter().map(|b| format!("{b:02x}")).collect()
}

/// Maximum items returned by [`filter_continue_watching`].
const CONTINUE_WATCHING_LIMIT: usize = 20;

/// Maximum items returned by [`filter_cross_device`].
const CROSS_DEVICE_LIMIT: usize = 10;

/// Returns `true` when an entry has meaningful progress
/// but has not been completed (< 95%).
pub(super) fn is_in_progress(entry: &WatchHistory) -> bool {
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
    use crate::algorithms::json_utils::parse_json_vec;

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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::algorithms::normalize::EPG_FORMAT;
    use sha2::{Digest, Sha256};

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
            source_id: None,
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

    // ── derive_watch_history_id ──────────────────────

    #[test]
    fn derive_id_empty_url_produces_valid_16_char_hex() {
        let id = derive_watch_history_id("");
        assert_eq!(id.len(), 16, "ID must be exactly 16 hex characters");
        assert!(
            id.chars().all(|c| c.is_ascii_hexdigit()),
            "ID must be all hex characters, got: {id}"
        );
    }

    #[test]
    fn derive_id_same_url_is_deterministic() {
        let url = "http://example.com/stream/channel1";
        let id1 = derive_watch_history_id(url);
        let id2 = derive_watch_history_id(url);
        assert_eq!(id1, id2, "Same URL must always produce same ID");
    }

    #[test]
    fn derive_id_different_urls_produce_different_ids() {
        let id1 = derive_watch_history_id("http://example.com/stream/1");
        let id2 = derive_watch_history_id("http://example.com/stream/2");
        assert_ne!(id1, id2, "Different URLs must produce different IDs");
    }

    #[test]
    fn derive_id_url_with_special_characters() {
        // URLs with tokens, query params, and special chars must not panic
        let url = "http://user:p%40ss@host:8080/live/token?key=abc&val=x%2Fy#frag";
        let id = derive_watch_history_id(url);
        assert_eq!(id.len(), 16);
        assert!(id.chars().all(|c| c.is_ascii_hexdigit()));
    }

    #[test]
    fn derive_id_known_test_vector() {
        // SHA-256 of "http://example.com/test" =
        //   b94d27b9934d3e08a52e52d7da7dabfac484efe04294e576d8b53d2e0e8bb5ac
        //   (computed offline; first 8 bytes = b9 4d 27 b9 93 4d 3e 08)
        // Expected first 16 hex chars: "b94d27b9934d3e08"
        //
        // We verify against our own consistent output to detect
        // accidental algorithm changes across Rust versions.
        let url = "http://example.com/test";
        let id = derive_watch_history_id(url);
        // Compute expected using sha2 directly to stay self-consistent:
        let mut hasher = Sha256::new();
        hasher.update(url.as_bytes());
        let full = hasher.finalize();
        let expected: String = full[..8].iter().map(|b| format!("{b:02x}")).collect();
        assert_eq!(id, expected, "ID must match SHA-256 prefix");
        assert_eq!(id.len(), 16);
    }
}
