//! VOD sorting, categorization, filtering, and episode
//! progress algorithms.
//!
//! Ports `sortVodItems()`, `_buildCategoryMap()`,
//! `_buildTypeCategories()`, `top10VodProvider`, and
//! `episodeProgressMapProvider` / `lastWatchedEpisodeIdProvider`
//! from Dart `vod_providers.dart` and `home_providers.dart`.

mod categorize;
mod filter;
mod progress;
mod sorting;

use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};

// ── sort_vod_items ──────────────────────────────────

/// Sort criteria matching Dart `VodSortOption`.
pub(super) const SORT_ADDED_DESC: &str = "added_desc";
pub(super) const SORT_NAME_ASC: &str = "name_asc";
pub(super) const SORT_NAME_DESC: &str = "name_desc";
pub(super) const SORT_YEAR_DESC: &str = "year_desc";
pub(super) const SORT_RATING_DESC: &str = "rating_desc";

/// Parse a rating string to `f64`, returning
/// `f64::NEG_INFINITY` on failure so missing/invalid
/// values sort last under `total_cmp` descending.
pub(super) fn parse_rating(r: Option<&str>) -> f64 {
    r.and_then(|s| s.parse::<f64>().ok())
        .unwrap_or(f64::NEG_INFINITY)
}

// ── build_vod_category_map ──────────────────────────

/// Output shape for [`build_vod_category_map`].
#[derive(Debug, Serialize, Deserialize, PartialEq)]
pub struct VodCategoryMap {
    /// All unique categories, sorted alphabetically.
    pub categories: Vec<String>,
    /// Categories that contain at least one movie.
    pub movie_categories: Vec<String>,
    /// Categories that contain at least one series.
    pub series_categories: Vec<String>,
}

// ── compute_episode_progress ────────────────────────

/// A watch history entry with optional series metadata.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EpisodeHistoryEntry {
    /// Unique item identifier.
    pub item_id: String,
    /// Current playback position in milliseconds.
    pub position_ms: i64,
    /// Total duration in milliseconds.
    pub duration_ms: i64,
    /// ISO-8601 timestamp of last watch.
    pub last_watched: String,
    /// Optional nested metadata.
    #[serde(default)]
    pub metadata: Option<EpisodeMetadata>,
}

/// Series/episode metadata embedded in a history entry.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EpisodeMetadata {
    /// Parent series ID.
    #[serde(default)]
    pub series_id: Option<String>,
    /// Episode identifier within the series.
    #[serde(default)]
    pub episode_id: Option<String>,
}

/// Output shape for [`compute_episode_progress`].
#[derive(Debug, Serialize, Deserialize, PartialEq)]
pub struct EpisodeProgressResult {
    /// Map of episode_id -> progress (0.0..1.0).
    pub progress_map: BTreeMap<String, f64>,
    /// Episode with the most recent last_watched.
    pub last_watched_episode_id: Option<String>,
}

// ── Re-exports ──────────────────────────────────────

pub use categorize::build_vod_category_map;
pub use filter::{
    filter_recently_added, filter_top_vod, filter_vod_by_content_rating, parse_content_rating,
    resolve_vod_quality, similar_vod_items,
};
pub use progress::compute_episode_progress;
pub use sorting::{sort_vod_items, sort_vod_items_vec};

// ── Tests ───────────────────────────────────────────

#[cfg(test)]
mod tests {
    use crate::models::VodItem;

    use super::*;

    /// Helper: build a minimal VodItem JSON object.
    #[allow(clippy::too_many_arguments)]
    fn vod_json(
        id: &str,
        name: &str,
        item_type: &str,
        rating: Option<&str>,
        year: Option<i32>,
        category: Option<&str>,
        poster: Option<&str>,
        backdrop: Option<&str>,
        added_at: Option<&str>,
    ) -> serde_json::Value {
        let mut obj = serde_json::json!({
            "id": id,
            "name": name,
            "stream_url": format!("http://x/{id}"),
            "type": item_type,
        });
        if let Some(r) = rating {
            obj["rating"] = serde_json::json!(r);
        }
        if let Some(y) = year {
            obj["year"] = serde_json::json!(y);
        }
        if let Some(c) = category {
            obj["category"] = serde_json::json!(c);
        }
        if let Some(p) = poster {
            obj["poster_url"] = serde_json::json!(p);
        }
        if let Some(b) = backdrop {
            obj["backdrop_url"] = serde_json::json!(b);
        }
        if let Some(a) = added_at {
            obj["added_at"] = serde_json::json!(a);
        }
        obj
    }

    fn to_json_array(items: &[serde_json::Value]) -> String {
        serde_json::to_string(items).unwrap()
    }

    fn parse_vod_array(json: &str) -> Vec<VodItem> {
        serde_json::from_str(json).unwrap()
    }

    // ── sort_vod_items ──────────────────────────────

    #[test]
    fn sort_by_name_asc() {
        let items = vec![
            vod_json("c", "Charlie", "movie", None, None, None, None, None, None),
            vod_json("a", "Alpha", "movie", None, None, None, None, None, None),
            vod_json("b", "Bravo", "movie", None, None, None, None, None, None),
        ];
        let json = to_json_array(&items);
        let result = sort_vod_items(&json, "name_asc");
        let sorted = parse_vod_array(&result);
        assert_eq!(sorted[0].name, "Alpha");
        assert_eq!(sorted[1].name, "Bravo");
        assert_eq!(sorted[2].name, "Charlie");
    }

    #[test]
    fn sort_by_name_desc() {
        let items = vec![
            vod_json("a", "Alpha", "movie", None, None, None, None, None, None),
            vod_json("c", "Charlie", "movie", None, None, None, None, None, None),
            vod_json("b", "Bravo", "movie", None, None, None, None, None, None),
        ];
        let json = to_json_array(&items);
        let result = sort_vod_items(&json, "name_desc");
        let sorted = parse_vod_array(&result);
        assert_eq!(sorted[0].name, "Charlie");
        assert_eq!(sorted[1].name, "Bravo");
        assert_eq!(sorted[2].name, "Alpha");
    }

    #[test]
    fn sort_by_year_desc() {
        let items = vec![
            vod_json(
                "a",
                "Old",
                "movie",
                None,
                Some(2000),
                None,
                None,
                None,
                None,
            ),
            vod_json(
                "b",
                "New",
                "movie",
                None,
                Some(2024),
                None,
                None,
                None,
                None,
            ),
            vod_json(
                "c",
                "Mid",
                "movie",
                None,
                Some(2015),
                None,
                None,
                None,
                None,
            ),
        ];
        let json = to_json_array(&items);
        let result = sort_vod_items(&json, "year_desc");
        let sorted = parse_vod_array(&result);
        assert_eq!(sorted[0].name, "New");
        assert_eq!(sorted[1].name, "Mid");
        assert_eq!(sorted[2].name, "Old");
    }

    #[test]
    fn sort_by_rating_desc() {
        let items = vec![
            vod_json(
                "a",
                "Low",
                "movie",
                Some("3.5"),
                None,
                None,
                None,
                None,
                None,
            ),
            vod_json(
                "b",
                "High",
                "movie",
                Some("9.1"),
                None,
                None,
                None,
                None,
                None,
            ),
            vod_json(
                "c",
                "Mid",
                "movie",
                Some("7.0"),
                None,
                None,
                None,
                None,
                None,
            ),
        ];
        let json = to_json_array(&items);
        let result = sort_vod_items(&json, "rating_desc");
        let sorted = parse_vod_array(&result);
        assert_eq!(sorted[0].name, "High");
        assert_eq!(sorted[1].name, "Mid");
        assert_eq!(sorted[2].name, "Low");
    }

    #[test]
    fn sort_by_rating_missing_ratings_last() {
        let items = vec![
            vod_json("a", "NoRate", "movie", None, None, None, None, None, None),
            vod_json(
                "b",
                "Rated",
                "movie",
                Some("8.0"),
                None,
                None,
                None,
                None,
                None,
            ),
            vod_json(
                "c",
                "Empty",
                "movie",
                Some(""),
                None,
                None,
                None,
                None,
                None,
            ),
        ];
        let json = to_json_array(&items);
        let result = sort_vod_items(&json, "rating_desc");
        let sorted = parse_vod_array(&result);
        assert_eq!(sorted[0].name, "Rated");
        // NaN items come after.
        assert!(sorted[1].name == "NoRate" || sorted[1].name == "Empty");
    }

    #[test]
    fn sort_by_added_desc() {
        let items = vec![
            vod_json(
                "a",
                "Old",
                "movie",
                None,
                None,
                None,
                None,
                None,
                Some("2024-01-01T00:00:00"),
            ),
            vod_json(
                "b",
                "New",
                "movie",
                None,
                None,
                None,
                None,
                None,
                Some("2024-06-01T00:00:00"),
            ),
            vod_json(
                "c",
                "Mid",
                "movie",
                None,
                None,
                None,
                None,
                None,
                Some("2024-03-15T00:00:00"),
            ),
        ];
        let json = to_json_array(&items);
        let result = sort_vod_items(&json, "added_desc");
        let sorted = parse_vod_array(&result);
        assert_eq!(sorted[0].name, "New");
        assert_eq!(sorted[1].name, "Mid");
        assert_eq!(sorted[2].name, "Old");
    }

    #[test]
    fn sort_empty_list() {
        let result = sort_vod_items("[]", "name_asc");
        assert_eq!(result, "[]");
    }

    #[test]
    fn sort_invalid_json() {
        let result = sort_vod_items("not json", "name_asc");
        assert_eq!(result, "[]");
    }

    #[test]
    fn sort_equal_ratings_stable() {
        let items = vec![
            vod_json(
                "a",
                "Alpha",
                "movie",
                Some("8.0"),
                None,
                None,
                None,
                None,
                None,
            ),
            vod_json(
                "b",
                "Bravo",
                "movie",
                Some("8.0"),
                None,
                None,
                None,
                None,
                None,
            ),
        ];
        let json = to_json_array(&items);
        let result = sort_vod_items(&json, "rating_desc");
        let sorted = parse_vod_array(&result);
        // Both have same rating — order preserved
        // (Rust sort_by is stable).
        assert_eq!(sorted[0].name, "Alpha");
        assert_eq!(sorted[1].name, "Bravo");
    }

    #[test]
    fn year_none_sorts_last_in_desc() {
        let items = vec![
            vod_json(
                "a",
                "Recent",
                "movie",
                None,
                Some(2024),
                None,
                None,
                None,
                None,
            ),
            vod_json("b", "NoYear", "movie", None, None, None, None, None, None),
            vod_json(
                "c",
                "Older",
                "movie",
                None,
                Some(2020),
                None,
                None,
                None,
                None,
            ),
        ];
        let json = to_json_array(&items);
        let result = sort_vod_items(&json, "year_desc");
        let sorted = parse_vod_array(&result);
        // [2024, 2020, None] — null-year item sorts LAST.
        assert_eq!(sorted[0].name, "Recent");
        assert_eq!(sorted[1].name, "Older");
        assert_eq!(sorted[2].name, "NoYear");
    }

    // ── build_vod_category_map ──────────────────────

    #[test]
    fn category_map_multiple_categories() {
        let items = vec![
            vod_json(
                "a",
                "A",
                "movie",
                None,
                None,
                Some("Action"),
                None,
                None,
                None,
            ),
            vod_json(
                "b",
                "B",
                "series",
                None,
                None,
                Some("Comedy"),
                None,
                None,
                None,
            ),
            vod_json(
                "c",
                "C",
                "movie",
                None,
                None,
                Some("Action"),
                None,
                None,
                None,
            ),
            vod_json(
                "d",
                "D",
                "series",
                None,
                None,
                Some("Action"),
                None,
                None,
                None,
            ),
        ];
        let json = to_json_array(&items);
        let result = build_vod_category_map(&json);
        let map: VodCategoryMap = serde_json::from_str(&result).unwrap();

        assert_eq!(map.categories, vec!["Action", "Comedy"]);
        assert_eq!(map.movie_categories, vec!["Action"]);
        assert_eq!(map.series_categories, vec!["Action", "Comedy"]);
    }

    #[test]
    fn category_map_empty_input() {
        let result = build_vod_category_map("[]");
        let map: VodCategoryMap = serde_json::from_str(&result).unwrap();
        assert!(map.categories.is_empty());
        assert!(map.movie_categories.is_empty());
        assert!(map.series_categories.is_empty());
    }

    #[test]
    fn category_map_null_categories_excluded() {
        let items = vec![
            vod_json("a", "A", "movie", None, None, None, None, None, None),
            vod_json(
                "b",
                "B",
                "movie",
                None,
                None,
                Some("Drama"),
                None,
                None,
                None,
            ),
        ];
        let json = to_json_array(&items);
        let result = build_vod_category_map(&json);
        let map: VodCategoryMap = serde_json::from_str(&result).unwrap();
        assert_eq!(map.categories, vec!["Drama"]);
    }

    #[test]
    fn category_map_sorted_alphabetically() {
        let items = vec![
            vod_json(
                "a",
                "A",
                "movie",
                None,
                None,
                Some("Zulu"),
                None,
                None,
                None,
            ),
            vod_json(
                "b",
                "B",
                "movie",
                None,
                None,
                Some("Alpha"),
                None,
                None,
                None,
            ),
            vod_json(
                "c",
                "C",
                "movie",
                None,
                None,
                Some("Mike"),
                None,
                None,
                None,
            ),
        ];
        let json = to_json_array(&items);
        let result = build_vod_category_map(&json);
        let map: VodCategoryMap = serde_json::from_str(&result).unwrap();
        assert_eq!(map.categories, vec!["Alpha", "Mike", "Zulu"]);
    }

    // ── filter_top_vod ──────────────────────────────

    #[test]
    fn top_vod_normal_case() {
        let items: Vec<serde_json::Value> = (0..20)
            .map(|i| {
                vod_json(
                    &format!("v{i}"),
                    &format!("Movie {i}"),
                    "movie",
                    Some(&format!("{:.1}", i as f64)),
                    Some(2020 + (i % 5)),
                    None,
                    Some("http://poster"),
                    None,
                    None,
                )
            })
            .collect();
        let json = to_json_array(&items);
        let result = filter_top_vod(&json, 10);
        let top = parse_vod_array(&result);
        assert_eq!(top.len(), 10);
        // Highest rating first.
        assert_eq!(top[0].name, "Movie 19");
    }

    #[test]
    fn top_vod_fallback_to_newest() {
        // No ratings — should fall back to year sort.
        let items = vec![
            vod_json(
                "a",
                "Old",
                "movie",
                None,
                Some(2010),
                None,
                Some("http://p"),
                None,
                None,
            ),
            vod_json(
                "b",
                "New",
                "movie",
                None,
                Some(2024),
                None,
                Some("http://p"),
                None,
                None,
            ),
            vod_json(
                "c",
                "Mid",
                "movie",
                None,
                Some(2018),
                None,
                Some("http://p"),
                None,
                None,
            ),
        ];
        let json = to_json_array(&items);
        let result = filter_top_vod(&json, 10);
        let top = parse_vod_array(&result);
        assert_eq!(top.len(), 3);
        assert_eq!(top[0].name, "New");
        assert_eq!(top[1].name, "Mid");
        assert_eq!(top[2].name, "Old");
    }

    #[test]
    fn top_vod_fewer_than_limit_triggers_fallback() {
        // Only 2 rated items, limit=5 → fallback.
        let items = vec![
            vod_json(
                "a",
                "Rated1",
                "movie",
                Some("9.0"),
                Some(2020),
                None,
                Some("http://p"),
                None,
                None,
            ),
            vod_json(
                "b",
                "Rated2",
                "movie",
                Some("8.0"),
                Some(2019),
                None,
                Some("http://p"),
                None,
                None,
            ),
            vod_json(
                "c",
                "Unrated",
                "movie",
                None,
                Some(2024),
                None,
                Some("http://p"),
                None,
                None,
            ),
        ];
        let json = to_json_array(&items);
        let result = filter_top_vod(&json, 5);
        let top = parse_vod_array(&result);
        // Rated items first (by rating desc), then
        // unrated fill-in (by year desc).
        assert_eq!(top[0].name, "Rated1");
        assert_eq!(top[1].name, "Rated2");
        assert_eq!(top[2].name, "Unrated");
    }

    #[test]
    fn top_vod_empty_input() {
        let result = filter_top_vod("[]", 10);
        assert_eq!(result, "[]");
    }

    #[test]
    fn top_vod_no_poster_excluded() {
        let items = vec![
            vod_json(
                "a",
                "NoPoster",
                "movie",
                Some("9.0"),
                None,
                None,
                None,
                None,
                None,
            ),
            vod_json(
                "b",
                "WithPoster",
                "movie",
                Some("8.0"),
                Some(2020),
                None,
                Some("http://p"),
                None,
                None,
            ),
        ];
        let json = to_json_array(&items);
        // Only 1 rated+image item < limit → fallback.
        let result = filter_top_vod(&json, 5);
        let top = parse_vod_array(&result);
        // Fallback: only item with year.
        assert_eq!(top.len(), 1);
        assert_eq!(top[0].name, "WithPoster");
    }

    // ── compute_episode_progress ────────────────────

    fn ep_entry(
        item_id: &str,
        series_id: &str,
        episode_id: &str,
        position_ms: i64,
        duration_ms: i64,
        last_watched: &str,
    ) -> serde_json::Value {
        serde_json::json!({
            "item_id": item_id,
            "position_ms": position_ms,
            "duration_ms": duration_ms,
            "last_watched": last_watched,
            "metadata": {
                "series_id": series_id,
                "episode_id": episode_id,
            }
        })
    }

    #[test]
    fn episode_progress_normal() {
        let entries = vec![
            ep_entry("e1", "s1", "ep1", 5000, 10000, "2024-03-01T10:00:00"),
            ep_entry("e2", "s1", "ep2", 7500, 10000, "2024-03-02T10:00:00"),
        ];
        let json = to_json_array(&entries);
        let result = compute_episode_progress(&json, "s1");
        let parsed: EpisodeProgressResult = serde_json::from_str(&result).unwrap();

        assert_eq!(parsed.progress_map.len(), 2);
        assert!((parsed.progress_map["ep1"] - 0.5).abs() < f64::EPSILON);
        assert!((parsed.progress_map["ep2"] - 0.75).abs() < f64::EPSILON);
        assert_eq!(parsed.last_watched_episode_id, Some("ep2".to_string()));
    }

    #[test]
    fn episode_progress_no_matches() {
        let entries = vec![ep_entry(
            "e1",
            "other_series",
            "ep1",
            5000,
            10000,
            "2024-03-01T10:00:00",
        )];
        let json = to_json_array(&entries);
        let result = compute_episode_progress(&json, "s1");
        let parsed: EpisodeProgressResult = serde_json::from_str(&result).unwrap();

        assert!(parsed.progress_map.is_empty());
        assert_eq!(parsed.last_watched_episode_id, None);
    }

    #[test]
    fn episode_progress_zero_duration() {
        let entries = vec![ep_entry("e1", "s1", "ep1", 5000, 0, "2024-03-01T10:00:00")];
        let json = to_json_array(&entries);
        let result = compute_episode_progress(&json, "s1");
        let parsed: EpisodeProgressResult = serde_json::from_str(&result).unwrap();

        assert_eq!(parsed.progress_map["ep1"], 0.0);
    }

    #[test]
    fn episode_progress_clamped_to_one() {
        let entries = vec![ep_entry(
            "e1",
            "s1",
            "ep1",
            15000,
            10000,
            "2024-03-01T10:00:00",
        )];
        let json = to_json_array(&entries);
        let result = compute_episode_progress(&json, "s1");
        let parsed: EpisodeProgressResult = serde_json::from_str(&result).unwrap();

        assert_eq!(parsed.progress_map["ep1"], 1.0);
    }

    #[test]
    fn episode_progress_last_watched_is_most_recent() {
        let entries = vec![
            ep_entry("e1", "s1", "ep1", 5000, 10000, "2024-01-01T10:00:00"),
            ep_entry("e2", "s1", "ep3", 5000, 10000, "2024-06-01T10:00:00"),
            ep_entry("e3", "s1", "ep2", 5000, 10000, "2024-03-01T10:00:00"),
        ];
        let json = to_json_array(&entries);
        let result = compute_episode_progress(&json, "s1");
        let parsed: EpisodeProgressResult = serde_json::from_str(&result).unwrap();

        assert_eq!(parsed.last_watched_episode_id, Some("ep3".to_string()));
    }

    #[test]
    fn episode_progress_empty_input() {
        let result = compute_episode_progress("[]", "s1");
        let parsed: EpisodeProgressResult = serde_json::from_str(&result).unwrap();
        assert!(parsed.progress_map.is_empty());
        assert_eq!(parsed.last_watched_episode_id, None);
    }

    #[test]
    fn episode_progress_invalid_json() {
        let result = compute_episode_progress("not json", "s1");
        let parsed: EpisodeProgressResult = serde_json::from_str(&result).unwrap();
        assert!(parsed.progress_map.is_empty());
        assert_eq!(parsed.last_watched_episode_id, None);
    }

    // ── Content Rating Filter Tests ──────────────────

    #[test]
    fn parse_content_rating_mpaa() {
        assert_eq!(parse_content_rating(Some("G")), 0);
        assert_eq!(parse_content_rating(Some("Rated G")), 0);
        assert_eq!(parse_content_rating(Some("PG")), 1);
        assert_eq!(parse_content_rating(Some("Rated PG")), 1);
        assert_eq!(parse_content_rating(Some("PG-13")), 2);
        assert_eq!(parse_content_rating(Some("PG13")), 2);
        assert_eq!(parse_content_rating(Some("R")), 3);
        assert_eq!(parse_content_rating(Some("Rated R")), 3);
        assert_eq!(parse_content_rating(Some("NC-17")), 4);
        assert_eq!(parse_content_rating(Some("NC17")), 4);
    }

    #[test]
    fn parse_content_rating_tv() {
        assert_eq!(parse_content_rating(Some("TV-Y")), 0);
        assert_eq!(parse_content_rating(Some("TV-G")), 0);
        assert_eq!(parse_content_rating(Some("TVG")), 0);
        assert_eq!(parse_content_rating(Some("TV-PG")), 1);
        assert_eq!(parse_content_rating(Some("TVPG")), 1);
        assert_eq!(parse_content_rating(Some("TV-14")), 2);
        assert_eq!(parse_content_rating(Some("TV14")), 2);
        assert_eq!(parse_content_rating(Some("TV-MA")), 4);
        assert_eq!(parse_content_rating(Some("TVMA")), 4);
    }

    #[test]
    fn parse_content_rating_edge_cases() {
        assert_eq!(parse_content_rating(None), 5);
        assert_eq!(parse_content_rating(Some("")), 5);
        assert_eq!(parse_content_rating(Some("Unknown")), 5);
        assert_eq!(parse_content_rating(Some("  pg-13  ")), 2);
        assert_eq!(parse_content_rating(Some("tv-ma")), 4);
    }

    #[test]
    fn filter_vod_by_content_rating_basic() {
        let items = serde_json::to_string(&vec![
            vod_json(
                "1",
                "Kids",
                "movie",
                Some("G"),
                None,
                None,
                None,
                None,
                None,
            ),
            vod_json(
                "2",
                "Teen",
                "movie",
                Some("PG-13"),
                None,
                None,
                None,
                None,
                None,
            ),
            vod_json(
                "3",
                "Adult",
                "movie",
                Some("R"),
                None,
                None,
                None,
                None,
                None,
            ),
            vod_json("4", "Unrated", "movie", None, None, None, None, None, None),
        ])
        .unwrap();

        // Max PG (level 1): only G and Unrated pass
        let result = filter_vod_by_content_rating(&items, 1);
        let filtered: Vec<serde_json::Value> = serde_json::from_str(&result).unwrap();
        assert_eq!(filtered.len(), 2);
        assert_eq!(filtered[0]["id"], "1");
        assert_eq!(filtered[1]["id"], "4");
    }

    #[test]
    fn filter_vod_by_content_rating_all_pass() {
        let items = serde_json::to_string(&vec![
            vod_json(
                "1",
                "Kids",
                "movie",
                Some("G"),
                None,
                None,
                None,
                None,
                None,
            ),
            vod_json(
                "2",
                "Adult",
                "movie",
                Some("R"),
                None,
                None,
                None,
                None,
                None,
            ),
        ])
        .unwrap();

        // Max NC-17 (level 4): everything passes
        let result = filter_vod_by_content_rating(&items, 4);
        let filtered: Vec<serde_json::Value> = serde_json::from_str(&result).unwrap();
        assert_eq!(filtered.len(), 2);
    }

    #[test]
    fn filter_vod_by_content_rating_invalid_json() {
        let result = filter_vod_by_content_rating("invalid", 3);
        assert_eq!(result, "[]");
    }

    #[test]
    fn filter_vod_by_content_rating_empty() {
        let result = filter_vod_by_content_rating("[]", 3);
        assert_eq!(result, "[]");
    }

    // ── filter_recently_added ───────────────────────

    /// Epoch ms for a fixed reference point: 2024-03-15 12:00:00 UTC
    /// = 1710504000000 ms.
    const NOW_MS: i64 = 1_710_504_000_000;

    /// 2024-03-14 12:00:00 UTC (1 day before NOW_MS)
    const ONE_DAY_AGO: &str = "2024-03-14T12:00:00";
    /// 2024-03-10 12:00:00 UTC (5 days before NOW_MS)
    const FIVE_DAYS_AGO: &str = "2024-03-10T12:00:00";
    /// 2024-03-01 12:00:00 UTC (14 days before NOW_MS)
    const FOURTEEN_DAYS_AGO: &str = "2024-03-01T12:00:00";

    #[test]
    fn recently_added_items_within_cutoff_returned() {
        // Default cutoff = 7 days.  Items 1 day and 5 days ago pass;
        // item 14 days ago is excluded.
        let items = vec![
            vod_json(
                "a",
                "Recent",
                "movie",
                None,
                None,
                None,
                None,
                None,
                Some(ONE_DAY_AGO),
            ),
            vod_json(
                "b",
                "AlsoRecent",
                "movie",
                None,
                None,
                None,
                None,
                None,
                Some(FIVE_DAYS_AGO),
            ),
            vod_json(
                "c",
                "TooOld",
                "movie",
                None,
                None,
                None,
                None,
                None,
                Some(FOURTEEN_DAYS_AGO),
            ),
        ];
        let json = to_json_array(&items);
        let result = filter_recently_added(&json, 7, NOW_MS);
        let filtered = parse_vod_array(&result);
        assert_eq!(filtered.len(), 2);
        // Newest first: ONE_DAY_AGO > FIVE_DAYS_AGO.
        assert_eq!(filtered[0].name, "Recent");
        assert_eq!(filtered[1].name, "AlsoRecent");
    }

    #[test]
    fn recently_added_empty_input() {
        let result = filter_recently_added("[]", 7, NOW_MS);
        assert_eq!(result, "[]");
    }

    #[test]
    fn recently_added_items_without_added_at_excluded() {
        let items = vec![
            vod_json("a", "NoDate", "movie", None, None, None, None, None, None),
            vod_json(
                "b",
                "HasDate",
                "movie",
                None,
                None,
                None,
                None,
                None,
                Some(ONE_DAY_AGO),
            ),
        ];
        let json = to_json_array(&items);
        let result = filter_recently_added(&json, 7, NOW_MS);
        let filtered = parse_vod_array(&result);
        assert_eq!(filtered.len(), 1);
        assert_eq!(filtered[0].name, "HasDate");
    }

    #[test]
    fn recently_added_sort_order_newest_first() {
        let items = vec![
            vod_json(
                "a",
                "Oldest",
                "movie",
                None,
                None,
                None,
                None,
                None,
                Some(FIVE_DAYS_AGO),
            ),
            vod_json(
                "b",
                "Newest",
                "movie",
                None,
                None,
                None,
                None,
                None,
                Some(ONE_DAY_AGO),
            ),
        ];
        let json = to_json_array(&items);
        let result = filter_recently_added(&json, 7, NOW_MS);
        let filtered = parse_vod_array(&result);
        assert_eq!(filtered.len(), 2);
        assert_eq!(filtered[0].name, "Newest");
        assert_eq!(filtered[1].name, "Oldest");
    }

    #[test]
    fn recently_added_cutoff_boundary_excluded() {
        // An item added EXACTLY at the cutoff (not after) must be excluded.
        // cutoff_ms = NOW_MS - 7 * 86_400_000 = 1_710_504_000_000 - 604_800_000
        //           = 1_709_899_200_000 ms → 2024-03-08T12:00:00 UTC.
        let exactly_at_cutoff = "2024-03-08T12:00:00";
        let items = vec![
            vod_json(
                "a",
                "AtCutoff",
                "movie",
                None,
                None,
                None,
                None,
                None,
                Some(exactly_at_cutoff),
            ),
            vod_json(
                "b",
                "JustAfter",
                "movie",
                None,
                None,
                None,
                None,
                None,
                Some(ONE_DAY_AGO),
            ),
        ];
        let json = to_json_array(&items);
        let result = filter_recently_added(&json, 7, NOW_MS);
        let filtered = parse_vod_array(&result);
        // Only the item strictly AFTER the cutoff passes.
        assert_eq!(filtered.len(), 1);
        assert_eq!(filtered[0].name, "JustAfter");
    }

    #[test]
    fn recently_added_zero_cutoff_days_nothing_passes() {
        // cutoff = now, so nothing is strictly after now.
        let items = vec![vod_json(
            "a",
            "Recent",
            "movie",
            None,
            None,
            None,
            None,
            None,
            Some(ONE_DAY_AGO),
        )];
        let json = to_json_array(&items);
        // With 0 cutoff days, cutoff == now → item (1 day ago) is before now,
        // so it is NOT strictly after the cutoff.
        let result = filter_recently_added(&json, 0, NOW_MS);
        let filtered = parse_vod_array(&result);
        assert_eq!(filtered.len(), 0);
    }

    // ── filter_top_vod poster URL alignment ─────────

    #[test]
    fn top_vod_non_http_poster_excluded_from_primary() {
        // poster_url without "http" prefix must not appear
        // in the rated primary bucket.
        let items = vec![
            vod_json(
                "a",
                "NoHTTP",
                "movie",
                Some("9.5"),
                Some(2024),
                None,
                Some("/local/poster.jpg"),
                None,
                None,
            ),
            vod_json(
                "b",
                "WithHTTP",
                "movie",
                Some("8.0"),
                Some(2023),
                None,
                Some("http://cdn/poster.jpg"),
                None,
                None,
            ),
        ];
        let json = to_json_array(&items);
        let result = filter_top_vod(&json, 10);
        let top = parse_vod_array(&result);
        // Only "WithHTTP" has a valid HTTP poster.
        assert_eq!(top.len(), 1);
        assert_eq!(top[0].name, "WithHTTP");
    }

    #[test]
    fn top_vod_https_poster_accepted() {
        // "https://" also starts with "http" (case-insensitive).
        let items = vec![vod_json(
            "a",
            "HTTPS",
            "movie",
            Some("7.0"),
            Some(2022),
            None,
            Some("https://cdn/poster.jpg"),
            None,
            None,
        )];
        let json = to_json_array(&items);
        let result = filter_top_vod(&json, 10);
        let top = parse_vod_array(&result);
        assert_eq!(top.len(), 1);
        assert_eq!(top[0].name, "HTTPS");
    }

    // ── resolve_vod_quality ─────────────────────────

    #[test]
    fn resolve_vod_quality_4k_from_extension() {
        assert_eq!(
            resolve_vod_quality(Some("4k"), "http://example.com/movie"),
            Some("4K".to_string())
        );
    }

    #[test]
    fn resolve_vod_quality_hd_from_url_1080() {
        assert_eq!(
            resolve_vod_quality(None, "http://example.com/movie_1080p.mkv"),
            Some("HD".to_string())
        );
    }

    #[test]
    fn resolve_vod_quality_4k_from_url_uhd() {
        assert_eq!(
            resolve_vod_quality(None, "http://example.com/movie.uhd.mkv"),
            Some("4K".to_string())
        );
    }

    #[test]
    fn resolve_vod_quality_none_when_no_quality_indicators() {
        assert_eq!(
            resolve_vod_quality(None, "http://example.com/movie.mkv"),
            None
        );
    }

    #[test]
    fn resolve_vod_quality_case_insensitive_4k_in_extension() {
        // Mixed case "4K" in extension should still return Some("4K").
        assert_eq!(
            resolve_vod_quality(Some("4K"), "http://example.com/movie"),
            Some("4K".to_string())
        );
    }

    #[test]
    fn resolve_vod_quality_hd_from_extension_hd() {
        assert_eq!(
            resolve_vod_quality(Some("hd"), "http://example.com/movie"),
            Some("HD".to_string())
        );
    }

    #[test]
    fn top_vod_fallback_non_http_poster_excluded() {
        // In fallback mode (no rated items), items without
        // HTTP poster are excluded even when they have a year.
        let items = vec![
            vod_json(
                "a",
                "NoPoster",
                "movie",
                None,
                Some(2024),
                None,
                None,
                None,
                None,
            ),
            vod_json(
                "b",
                "LocalPoster",
                "movie",
                None,
                Some(2023),
                None,
                Some("/local/img.jpg"),
                None,
                None,
            ),
            vod_json(
                "c",
                "GoodPoster",
                "movie",
                None,
                Some(2022),
                None,
                Some("http://cdn/img.jpg"),
                None,
                None,
            ),
        ];
        let json = to_json_array(&items);
        let result = filter_top_vod(&json, 10);
        let top = parse_vod_array(&result);
        // Only "GoodPoster" passes the fallback HTTP poster check.
        assert_eq!(top.len(), 1);
        assert_eq!(top[0].name, "GoodPoster");
    }
}
