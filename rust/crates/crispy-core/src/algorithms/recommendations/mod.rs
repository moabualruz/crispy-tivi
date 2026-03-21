//! Recommendation engine algorithms.
//!
//! Ports `RecommendationEngine.computeSections()` and all
//! sub-builder functions from the Dart
//! `recommendation_engine.dart` to Rust for
//! performance-critical isolate offloading.

mod helpers;
mod sections;
mod typed;
mod types;

// Public API re-exports.
pub use typed::*;
pub use types::{Recommendation, RecommendationSection, WatchSignal};

use std::collections::{HashMap, HashSet};

use crate::models::{Channel, VodItem};

use helpers::naive_from_epoch_ms;
use sections::{
    build_because_you_watched, build_cold_start, build_genre_affinity, build_new_for_you,
    build_popular_in_genre, build_top_picks, build_trending,
};
use types::COLD_START_THRESHOLD;

// ── Main entry point ─────────────────────────────────

/// Compute all recommendation sections.
///
/// Pure function with no side effects. Receives all data
/// as parameters and returns ordered sections.
pub fn compute_recommendations(
    vod_items: &[VodItem],
    channels: &[Channel],
    history: &[WatchSignal],
    favorite_channel_ids: &[String],
    favorite_vod_ids: &[String],
    _max_allowed_rating: i32,
    now_utc_ms: i64,
) -> Vec<RecommendationSection> {
    let now = naive_from_epoch_ms(now_utc_ms);

    // Index lookups.
    let vod_by_id: HashMap<&str, &VodItem> = vod_items.iter().map(|v| (v.id.as_str(), v)).collect();
    let channel_by_id: HashMap<&str, &Channel> =
        channels.iter().map(|c| (c.id.as_str(), c)).collect();

    // Watched-item ID set for dedup.
    let watched_ids: HashSet<&str> = history.iter().map(|h| h.item_id.as_str()).collect();

    // Genre affinity map.
    let genre_affinity = build_genre_affinity(
        history,
        favorite_channel_ids,
        favorite_vod_ids,
        vod_items,
        &vod_by_id,
        &channel_by_id,
        now,
    );

    // Cold-start check.
    if history.len() < COLD_START_THRESHOLD {
        return build_cold_start(vod_items, &watched_ids);
    }

    let mut sections = Vec::new();

    // Top Picks.
    let top_picks = build_top_picks(vod_items, &watched_ids, &genre_affinity, history, now);
    if !top_picks.items.is_empty() {
        sections.push(top_picks);
    }

    // Because You Watched.
    sections.extend(build_because_you_watched(
        history,
        vod_items,
        &vod_by_id,
        &watched_ids,
    ));

    // Popular in Genre.
    sections.extend(build_popular_in_genre(
        &genre_affinity,
        vod_items,
        &watched_ids,
        history,
    ));

    // Trending.
    let trending = build_trending(history, vod_items, &vod_by_id, &watched_ids, now);
    if !trending.items.is_empty() {
        sections.push(trending);
    }

    // New for You.
    let new_for_you = build_new_for_you(vod_items, &watched_ids, &genre_affinity, now);
    if !new_for_you.items.is_empty() {
        sections.push(new_for_you);
    }

    sections
}

// ── Tests ────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::NaiveDate;
    use std::collections::{HashMap, HashSet};

    use crate::algorithms::watch_progress::COMPLETION_THRESHOLD;
    use helpers::{title_case, vod_to_recommendation};
    use sections::{
        build_because_you_watched, build_genre_affinity, build_new_for_you, build_popular_in_genre,
        build_top_picks, build_trending,
    };
    use typed::{
        RecommendationSectionType, deserialize_full_sections, parse_recommendation_sections,
    };
    use types::{MAX_BECAUSE_SECTIONS, SECTION_SIZE, TOP_PICKS_SIZE};

    /// Helper: build a minimal `VodItem` for tests.
    fn make_vod(
        id: &str,
        name: &str,
        item_type: &str,
        category: Option<&str>,
        rating: Option<&str>,
        year: Option<i32>,
        added_at: Option<chrono::NaiveDateTime>,
    ) -> VodItem {
        VodItem {
            id: id.to_string(),
            name: name.to_string(),
            stream_url: format!("http://example.com/{}", id),
            item_type: item_type.to_string(),
            poster_url: None,
            backdrop_url: None,
            description: None,
            rating: rating.map(|r| r.to_string()),
            year,
            duration: None,
            category: category.map(|c| c.to_string()),
            series_id: None,
            season_number: None,
            episode_number: None,
            ext: None,
            is_favorite: false,
            added_at,
            updated_at: None,
            source_id: None,
            cast: None,
            director: None,
            genre: None,
            youtube_trailer: None,
            tmdb_id: None,
            rating_5based: None,
            original_name: None,
            is_adult: false,
            content_rating: None,
        }
    }

    /// Helper: build a minimal `Channel` for tests.
    #[allow(dead_code)]
    fn make_channel(id: &str, group: Option<&str>) -> Channel {
        Channel {
            id: id.to_string(),
            name: format!("Channel {}", id),
            stream_url: format!("http://example.com/ch/{}", id),
            number: None,
            channel_group: group.map(|g| g.to_string()),
            logo_url: None,
            tvg_id: None,
            tvg_name: None,
            is_favorite: false,
            user_agent: None,
            has_catchup: false,
            catchup_days: 0,
            catchup_type: None,
            catchup_source: None,
            resolution: None,
            source_id: None,
            added_at: None,
            updated_at: None,
            is_247: false,
            tvg_shift: None,
            tvg_language: None,
            tvg_country: None,
            parent_code: None,
            is_radio: false,
            tvg_rec: None,
            is_adult: false,
            custom_sid: None,
            direct_source: None,
        }
    }

    fn now_ms() -> i64 {
        let dt = NaiveDate::from_ymd_opt(2026, 1, 15)
            .unwrap()
            .and_hms_opt(12, 0, 0)
            .unwrap();
        dt.and_utc().timestamp_millis()
    }

    fn now_dt() -> chrono::NaiveDateTime {
        NaiveDate::from_ymd_opt(2026, 1, 15)
            .unwrap()
            .and_hms_opt(12, 0, 0)
            .unwrap()
    }

    // 1. Cold start with < 3 history returns
    //    highly_rated + recently_added.
    #[test]
    fn cold_start_returns_two_sections() {
        let vod = vec![
            make_vod(
                "v1",
                "Movie A",
                "movie",
                Some("Action"),
                Some("8.5"),
                Some(2025),
                Some(now_dt() - chrono::Duration::days(1)),
            ),
            make_vod(
                "v2",
                "Movie B",
                "movie",
                Some("Drama"),
                Some("7.0"),
                Some(2024),
                Some(now_dt() - chrono::Duration::days(5)),
            ),
        ];
        let history = vec![WatchSignal {
            item_id: "other".to_string(),
            media_type: "movie".to_string(),
            watched_percent: 0.5,
            last_watched_ms: now_ms() - 86_400_000,
        }];

        let sections = compute_recommendations(&vod, &[], &history, &[], &[], 4, now_ms());

        assert_eq!(sections.len(), 2);
        assert_eq!(sections[0].section_type, "highlyRated");
        assert_eq!(sections[1].section_type, "recentlyAdded");
    }

    // 2. Genre affinity calculation with decay.
    #[test]
    fn genre_affinity_applies_decay() {
        let vod = vec![make_vod(
            "v1",
            "Movie A",
            "movie",
            Some("Action"),
            None,
            None,
            None,
        )];
        let _channels: Vec<Channel> = vec![];
        let vod_by_id: HashMap<&str, &VodItem> = vod.iter().map(|v| (v.id.as_str(), v)).collect();
        let ch_by_id: HashMap<&str, &Channel> = HashMap::new();
        let now = now_dt();

        // Recent watch (0 days ago) vs old watch
        // (60 days ago).
        let history = vec![WatchSignal {
            item_id: "v1".to_string(),
            media_type: "movie".to_string(),
            watched_percent: COMPLETION_THRESHOLD,
            last_watched_ms: now.and_utc().timestamp_millis(),
        }];

        let affinity = build_genre_affinity(&history, &[], &[], &vod, &vod_by_id, &ch_by_id, now);

        // "action" should exist with score = 1.0
        // (normalized, only entry).
        let action_score = affinity.get("action").copied().unwrap_or(0.0);
        assert!(
            (action_score - 1.0).abs() < 0.01,
            "expected ~1.0, got {}",
            action_score
        );

        // Now test with an old entry: 60 days ago
        // should have lower raw score.
        let old_history = vec![WatchSignal {
            item_id: "v1".to_string(),
            media_type: "movie".to_string(),
            watched_percent: COMPLETION_THRESHOLD,
            last_watched_ms: (now - chrono::Duration::days(60))
                .and_utc()
                .timestamp_millis(),
        }];
        let old_affinity =
            build_genre_affinity(&old_history, &[], &[], &vod, &vod_by_id, &ch_by_id, now);
        // Still normalized to 1.0 (only entry), but
        // raw is lower. With two entries we can compare.
        let _ = old_affinity;

        // Two-entry test with different categories.
        let vod2 = vec![
            make_vod("v1", "Movie A", "movie", Some("Action"), None, None, None),
            make_vod("v2", "Movie B", "movie", Some("Drama"), None, None, None),
        ];
        let vod2_by_id: HashMap<&str, &VodItem> = vod2.iter().map(|v| (v.id.as_str(), v)).collect();

        let history2 = vec![
            WatchSignal {
                item_id: "v1".to_string(),
                media_type: "movie".to_string(),
                watched_percent: COMPLETION_THRESHOLD,
                last_watched_ms: now.and_utc().timestamp_millis(),
            },
            WatchSignal {
                item_id: "v2".to_string(),
                media_type: "movie".to_string(),
                watched_percent: COMPLETION_THRESHOLD,
                last_watched_ms: (now - chrono::Duration::days(60))
                    .and_utc()
                    .timestamp_millis(),
            },
        ];

        let affinity2 =
            build_genre_affinity(&history2, &[], &[], &vod2, &vod2_by_id, &ch_by_id, now);
        let action2 = affinity2.get("action").copied().unwrap_or(0.0);
        let drama2 = affinity2.get("drama").copied().unwrap_or(0.0);
        // Recent action should dominate.
        assert!(
            action2 > drama2,
            "action {} should > drama {}",
            action2,
            drama2
        );
    }

    // 3. Top picks scoring formula.
    #[test]
    fn top_picks_scoring() {
        let now = now_dt();
        let vod = vec![
            make_vod(
                "v1",
                "High Affinity Movie",
                "movie",
                Some("Action"),
                Some("9.0"),
                Some(2025),
                Some(now - chrono::Duration::days(1)),
            ),
            make_vod(
                "v2",
                "Low Affinity Movie",
                "movie",
                Some("Unknown"),
                Some("3.0"),
                Some(2020),
                Some(now - chrono::Duration::days(100)),
            ),
        ];

        let mut genre_affinity = HashMap::new();
        genre_affinity.insert("action".to_string(), 1.0);

        let watched_ids: HashSet<&str> = HashSet::new();
        let history: Vec<WatchSignal> = vec![];

        let section = build_top_picks(&vod, &watched_ids, &genre_affinity, &history, now);

        assert_eq!(section.items.len(), 2);
        // First item should be the high-affinity one.
        assert_eq!(section.items[0].id, "v1");
        assert!(section.items[0].score > section.items[1].score);
    }

    // 4. Because you watched with >25% threshold.
    #[test]
    fn because_you_watched_threshold() {
        let vod = vec![
            make_vod(
                "v1",
                "Source Movie",
                "movie",
                Some("Horror"),
                Some("7.0"),
                Some(2024),
                None,
            ),
            make_vod(
                "v2",
                "Similar Movie",
                "movie",
                Some("Horror"),
                Some("6.0"),
                Some(2023),
                None,
            ),
        ];
        let vod_by_id: HashMap<&str, &VodItem> = vod.iter().map(|v| (v.id.as_str(), v)).collect();

        // Watched < 25% — should produce nothing.
        let history_low = vec![WatchSignal {
            item_id: "v1".to_string(),
            media_type: "movie".to_string(),
            watched_percent: 0.10,
            last_watched_ms: now_ms(),
        }];
        let watched_low: HashSet<&str> = history_low.iter().map(|h| h.item_id.as_str()).collect();
        let sections_low = build_because_you_watched(&history_low, &vod, &vod_by_id, &watched_low);
        assert!(
            sections_low.is_empty(),
            "low watch% should yield no sections"
        );

        // Watched > 25% — should produce a section.
        let history_hi = vec![WatchSignal {
            item_id: "v1".to_string(),
            media_type: "movie".to_string(),
            watched_percent: 0.60,
            last_watched_ms: now_ms(),
        }];
        let watched_hi: HashSet<&str> = history_hi.iter().map(|h| h.item_id.as_str()).collect();
        let sections_hi = build_because_you_watched(&history_hi, &vod, &vod_by_id, &watched_hi);
        assert_eq!(sections_hi.len(), 1);
        assert!(sections_hi[0].title.contains("Source Movie"));
    }

    // 5. Trending counts only last 7 days.
    #[test]
    fn trending_only_recent_7_days() {
        let now = now_dt();
        let vod = vec![
            make_vod(
                "v1",
                "Recent Hit",
                "movie",
                Some("Action"),
                None,
                None,
                None,
            ),
            make_vod("v2", "Old Hit", "movie", Some("Drama"), None, None, None),
        ];
        let vod_by_id: HashMap<&str, &VodItem> = vod.iter().map(|v| (v.id.as_str(), v)).collect();
        let watched_ids: HashSet<&str> = HashSet::new();

        // v1: watched 3 days ago. v2: watched 10 days
        // ago (outside 7-day window).
        let history = vec![
            WatchSignal {
                item_id: "v1".to_string(),
                media_type: "movie".to_string(),
                watched_percent: 0.8,
                last_watched_ms: (now - chrono::Duration::days(3))
                    .and_utc()
                    .timestamp_millis(),
            },
            WatchSignal {
                item_id: "v2".to_string(),
                media_type: "movie".to_string(),
                watched_percent: 0.8,
                last_watched_ms: (now - chrono::Duration::days(10))
                    .and_utc()
                    .timestamp_millis(),
            },
        ];

        let section = build_trending(&history, &vod, &vod_by_id, &watched_ids, now);

        // Only v1 should appear (v2 is outside window).
        assert_eq!(section.items.len(), 1);
        assert_eq!(section.items[0].id, "v1");
    }

    // 6. New for you filters to last 14 days.
    #[test]
    fn new_for_you_14_day_filter() {
        let now = now_dt();
        let vod = vec![
            make_vod(
                "v1",
                "Fresh Movie",
                "movie",
                Some("Action"),
                Some("8.0"),
                None,
                Some(now - chrono::Duration::days(5)),
            ),
            make_vod(
                "v2",
                "Stale Movie",
                "movie",
                Some("Action"),
                Some("9.0"),
                None,
                Some(now - chrono::Duration::days(30)),
            ),
        ];
        let watched_ids: HashSet<&str> = HashSet::new();
        let affinity = HashMap::new();

        let section = build_new_for_you(&vod, &watched_ids, &affinity, now);

        assert_eq!(section.items.len(), 1);
        assert_eq!(section.items[0].id, "v1");
    }

    // 7. Empty input returns empty sections.
    #[test]
    fn empty_input_returns_empty() {
        let sections = compute_recommendations(&[], &[], &[], &[], &[], 4, now_ms());
        assert!(sections.is_empty());
    }

    // 8. Rating parsing from string.
    #[test]
    fn rating_parsing() {
        let vod = make_vod("v1", "Test", "movie", None, Some("7.5"), None, None);
        let rec = vod_to_recommendation(&vod, "test", 0.5);
        assert_eq!(rec.rating, Some(7.5));

        // Bad rating parses to None.
        let vod_bad = make_vod("v2", "Test Bad", "movie", None, Some("N/A"), None, None);
        let rec_bad = vod_to_recommendation(&vod_bad, "test", 0.5);
        assert_eq!(rec_bad.rating, None);

        // No rating.
        let vod_none = make_vod("v3", "Test None", "movie", None, None, None, None);
        let rec_none = vod_to_recommendation(&vod_none, "test", 0.5);
        assert_eq!(rec_none.rating, None);
    }

    // 9. Watched items excluded from recommendations.
    #[test]
    fn watched_items_excluded() {
        let now = now_dt();
        let vod = vec![
            make_vod(
                "v1",
                "Watched Movie",
                "movie",
                Some("Action"),
                Some("9.0"),
                Some(2025),
                Some(now - chrono::Duration::days(1)),
            ),
            make_vod(
                "v2",
                "Unwatched Movie",
                "movie",
                Some("Action"),
                Some("8.0"),
                Some(2025),
                Some(now - chrono::Duration::days(1)),
            ),
        ];

        // Enough history to avoid cold start, and v1
        // is watched.
        let history = vec![
            WatchSignal {
                item_id: "v1".to_string(),
                media_type: "movie".to_string(),
                watched_percent: COMPLETION_THRESHOLD,
                last_watched_ms: (now - chrono::Duration::days(1))
                    .and_utc()
                    .timestamp_millis(),
            },
            WatchSignal {
                item_id: "x1".to_string(),
                media_type: "movie".to_string(),
                watched_percent: 0.5,
                last_watched_ms: (now - chrono::Duration::days(2))
                    .and_utc()
                    .timestamp_millis(),
            },
            WatchSignal {
                item_id: "x2".to_string(),
                media_type: "movie".to_string(),
                watched_percent: 0.5,
                last_watched_ms: (now - chrono::Duration::days(3))
                    .and_utc()
                    .timestamp_millis(),
            },
        ];

        let sections = compute_recommendations(
            &vod,
            &[],
            &history,
            &[],
            &[],
            4,
            now.and_utc().timestamp_millis(),
        );

        // v1 should not appear in any section.
        for section in &sections {
            for item in &section.items {
                assert_ne!(
                    item.id, "v1",
                    "Watched item v1 should be excluded \
                     from section '{}'",
                    section.title
                );
            }
        }
    }

    // 10. Title case helper.
    #[test]
    fn title_case_works() {
        assert_eq!(title_case("action"), "Action");
        assert_eq!(title_case("sci fi"), "Sci Fi");
        assert_eq!(title_case(""), "");
        assert_eq!(title_case("already Capitalized"), "Already Capitalized");
    }

    // ── parse_recommendation_sections ────────────────────

    // 11. Parse valid recommendation sections.
    #[test]
    fn parse_valid_sections() {
        let sections = vec![RecommendationSection {
            title: "Top Picks for You".to_string(),
            section_type: "topPicks".to_string(),
            items: vec![Recommendation {
                id: "v1".to_string(),
                title: "Movie A".to_string(),
                poster_url: None,
                backdrop_url: None,
                rating: Some(8.5),
                year: Some(2025),
                media_type: "movie".to_string(),
                reason: "topPick".to_string(),
                score: 0.9,
                category: Some("Action".to_string()),
                stream_url: Some("http://example.com/v1".to_string()),
                series_id: None,
            }],
        }];

        let typed = parse_recommendation_sections(&sections);
        assert!(typed.is_ok());
        let typed = typed.unwrap();
        assert_eq!(typed.len(), 1);
        assert_eq!(typed[0].section_type, RecommendationSectionType::TopPicks,);
        assert_eq!(typed[0].items.len(), 1);
        assert_eq!(typed[0].items[0].id, "v1");
        assert_eq!(typed[0].items[0].name, "Movie A");
    }

    // 12. Parse empty array.
    #[test]
    fn parse_empty_sections() {
        let typed = parse_recommendation_sections(&[]);
        assert!(typed.is_ok());
        assert!(typed.unwrap().is_empty());
    }

    // 13. Parse with missing optional fields.
    #[test]
    fn parse_section_items_have_none_optionals() {
        let sections = vec![RecommendationSection {
            title: "Trending Now".to_string(),
            section_type: "trending".to_string(),
            items: vec![Recommendation {
                id: "v2".to_string(),
                title: "Movie B".to_string(),
                poster_url: None,
                backdrop_url: None,
                rating: None,
                year: None,
                media_type: "movie".to_string(),
                reason: "trending".to_string(),
                score: 0.7,
                category: None,
                stream_url: None,
                series_id: None,
            }],
        }];

        let typed = parse_recommendation_sections(&sections);
        assert!(typed.is_ok());
        let typed = typed.unwrap();
        assert_eq!(typed[0].items[0].genre, None);
        assert_eq!(typed[0].items[0].source_title, None,);
        assert_eq!(
            typed[0].items[0].reason_type,
            RecommendationSectionType::Trending,
        );
    }

    // ── deserialize_full_sections ──────────────────────

    // 14. Full deserialization merges all fields.
    #[test]
    fn deserialize_full_merges_all_fields() {
        let sections = vec![RecommendationSection {
            title: "Top Picks for You".to_string(),
            section_type: "topPicks".to_string(),
            items: vec![Recommendation {
                id: "v1".to_string(),
                title: "Movie A".to_string(),
                poster_url: Some("http://img/a.jpg".to_string()),
                backdrop_url: None,
                rating: Some(8.5),
                year: Some(2025),
                media_type: "movie".to_string(),
                reason: "topPick".to_string(),
                score: 0.9,
                category: Some("Action".to_string()),
                stream_url: Some("http://stream/v1".to_string()),
                series_id: None,
            }],
        }];

        let full = deserialize_full_sections(&sections).unwrap();
        assert_eq!(full.len(), 1);
        assert_eq!(full[0].section_type, RecommendationSectionType::TopPicks,);
        let item = &full[0].items[0];
        assert_eq!(item.id, "v1");
        assert_eq!(item.name, "Movie A");
        assert_eq!(item.score, 0.9);
        assert_eq!(item.poster_url.as_deref(), Some("http://img/a.jpg"),);
        assert_eq!(item.category.as_deref(), Some("Action"),);
        assert_eq!(item.stream_url.as_deref(), Some("http://stream/v1"),);
        assert_eq!(item.rating.as_deref(), Some("8.5"),);
        assert_eq!(item.year, Some(2025));
        assert!(item.series_id.is_none());
        assert_eq!(item.reason_type, RecommendationSectionType::TopPicks,);
    }

    // 15. Full deserialization with empty input.
    #[test]
    fn deserialize_full_empty() {
        let full = deserialize_full_sections(&[]).unwrap();
        assert!(full.is_empty());
    }

    /// Helper: build a `WatchSignal` for tests.
    fn make_signal(
        item_id: &str,
        media_type: &str,
        watched_percent: f64,
        last_watched_ms: i64,
    ) -> WatchSignal {
        WatchSignal {
            item_id: item_id.to_string(),
            media_type: media_type.to_string(),
            watched_percent,
            last_watched_ms,
        }
    }

    // 16. Favourite channels boost their genre
    //     in genre affinity.
    #[test]
    fn genre_affinity_favorite_channels_boost() {
        let vod: Vec<VodItem> = vec![];
        let channels = [
            make_channel("ch1", Some("Sports")),
            make_channel("ch2", Some("News")),
            make_channel("ch3", Some("Sports")),
        ];
        let vod_by_id: HashMap<&str, &VodItem> = HashMap::new();
        let ch_by_id: HashMap<&str, &Channel> =
            channels.iter().map(|c| (c.id.as_str(), c)).collect();
        let now = now_dt();

        // No history — only favourite channel boost.
        let fav_ids: Vec<String> = vec!["ch1".to_string(), "ch3".to_string()];
        let affinity = build_genre_affinity(&[], &fav_ids, &[], &vod, &vod_by_id, &ch_by_id, now);

        // "sports" should be boosted (2 channels
        // × 1.5 = 3.0 raw, normalized to 1.0).
        let sports = affinity.get("sports").copied().unwrap_or(0.0);
        assert!(
            (sports - 1.0).abs() < f64::EPSILON,
            "expected sports = 1.0, got {}",
            sports,
        );

        // "news" should NOT appear (ch2 is not
        // in favourites).
        assert!(
            !affinity.contains_key("news"),
            "news should not be in affinity",
        );
    }

    // 17. Genre affinity normalizes max score to
    //     1.0.
    #[test]
    fn genre_affinity_normalizes_to_one() {
        let now = now_dt();
        let vod = vec![
            make_vod("v1", "A", "movie", Some("Action"), None, None, None),
            make_vod("v2", "B", "movie", Some("Drama"), None, None, None),
            make_vod("v3", "C", "movie", Some("Action"), None, None, None),
        ];
        let vod_by_id: HashMap<&str, &VodItem> = vod.iter().map(|v| (v.id.as_str(), v)).collect();
        let ch_by_id: HashMap<&str, &Channel> = HashMap::new();

        // Multiple watches across genres.
        let history = vec![
            make_signal("v1", "movie", 0.95, now.and_utc().timestamp_millis()),
            make_signal("v2", "movie", 0.95, now.and_utc().timestamp_millis()),
            make_signal(
                "v3",
                "movie",
                0.95,
                (now - chrono::Duration::days(1))
                    .and_utc()
                    .timestamp_millis(),
            ),
        ];

        let affinity = build_genre_affinity(&history, &[], &[], &vod, &vod_by_id, &ch_by_id, now);

        let max_score = affinity.values().copied().fold(0.0_f64, f64::max);
        assert!(
            (max_score - 1.0).abs() < f64::EPSILON,
            "max genre score should be 1.0, got {}",
            max_score,
        );
    }

    // 18. Top picks respects TOP_PICKS_SIZE (20).
    #[test]
    fn top_picks_respects_max_size() {
        let now = now_dt();
        // Create 35 unwatched VOD items.
        let vod: Vec<VodItem> = (0..35)
            .map(|i| {
                make_vod(
                    &format!("v{}", i),
                    &format!("Movie {}", i),
                    "movie",
                    Some("Action"),
                    Some("7.0"),
                    Some(2025),
                    Some(now - chrono::Duration::days(i as i64)),
                )
            })
            .collect();

        let mut genre_affinity = HashMap::new();
        genre_affinity.insert("action".to_string(), 1.0);

        let watched_ids: HashSet<&str> = HashSet::new();

        // Enough history for non-cold-start context.
        let history = vec![
            make_signal("x1", "movie", 0.5, now.and_utc().timestamp_millis()),
            make_signal("x2", "movie", 0.5, now.and_utc().timestamp_millis()),
            make_signal("x3", "movie", 0.5, now.and_utc().timestamp_millis()),
        ];

        let section = build_top_picks(&vod, &watched_ids, &genre_affinity, &history, now);

        assert!(
            section.items.len() <= TOP_PICKS_SIZE,
            "top picks has {} items, max is {}",
            section.items.len(),
            TOP_PICKS_SIZE,
        );
    }

    // 19. At most MAX_BECAUSE_SECTIONS (3)
    //     "Because you watched" sections.
    #[test]
    fn because_you_watched_max_sections() {
        // Create 6 distinct genres, each with a
        // source watch + candidate items.
        let genres = ["Horror", "Comedy", "Drama", "Sci-Fi", "Romance", "Thriller"];
        let mut vod: Vec<VodItem> = Vec::new();
        let mut history: Vec<WatchSignal> = Vec::new();

        for (i, genre) in genres.iter().enumerate() {
            // Source item (watched).
            let src_id = format!("src{}", i);
            vod.push(make_vod(
                &src_id,
                &format!("Source {}", genre),
                "movie",
                Some(genre),
                Some("7.0"),
                Some(2024),
                None,
            ));
            history.push(make_signal(
                &src_id,
                "movie",
                0.96,
                now_ms() - (i as i64 * 86_400_000),
            ));

            // Candidate item (unwatched, same genre).
            let cand_id = format!("cand{}", i);
            vod.push(make_vod(
                &cand_id,
                &format!("Candidate {}", genre),
                "movie",
                Some(genre),
                Some("6.0"),
                Some(2023),
                None,
            ));
        }

        let vod_by_id: HashMap<&str, &VodItem> = vod.iter().map(|v| (v.id.as_str(), v)).collect();
        let watched_ids: HashSet<&str> = history.iter().map(|h| h.item_id.as_str()).collect();

        let sections = build_because_you_watched(&history, &vod, &vod_by_id, &watched_ids);

        assert!(
            sections.len() <= MAX_BECAUSE_SECTIONS,
            "got {} 'Because you watched' sections, \
             max is {}",
            sections.len(),
            MAX_BECAUSE_SECTIONS,
        );
    }

    // 20. Popular in genre sections respect
    //     SECTION_SIZE (15).
    #[test]
    fn popular_in_genre_section_size() {
        let now = now_dt();
        // Create 25 items in one genre.
        let vod: Vec<VodItem> = (0..25)
            .map(|i| {
                make_vod(
                    &format!("v{}", i),
                    &format!("Movie {}", i),
                    "movie",
                    Some("Action"),
                    Some("7.0"),
                    Some(2025),
                    Some(now),
                )
            })
            .collect();

        let mut genre_affinity = HashMap::new();
        genre_affinity.insert("action".to_string(), 1.0);

        let watched_ids: HashSet<&str> = HashSet::new();

        // Some history so watch_counts are populated.
        let history: Vec<WatchSignal> = (0..25)
            .map(|i| {
                make_signal(
                    &format!("v{}", i),
                    "movie",
                    0.8,
                    now.and_utc().timestamp_millis(),
                )
            })
            .collect();

        let sections = build_popular_in_genre(&genre_affinity, &vod, &watched_ids, &history);

        for section in &sections {
            assert!(
                section.items.len() <= SECTION_SIZE,
                "section '{}' has {} items, max is {}",
                section.title,
                section.items.len(),
                SECTION_SIZE,
            );
        }
    }

    // 21. Single VOD item with no history does
    //     not panic.
    #[test]
    fn single_vod_item_no_crash() {
        let vod = vec![make_vod(
            "v1",
            "Only Movie",
            "movie",
            Some("Action"),
            Some("5.0"),
            Some(2025),
            None,
        )];
        // Should not panic — cold-start path.
        let sections = compute_recommendations(&vod, &[], &[], &[], &[], 4, now_ms());
        // Cold start with 0 history: sections
        // depend on item having a rating/added_at.
        // Just verify no panic.
        let _ = sections;
    }

    // 22. compute → parse round trip succeeds.
    #[test]
    fn compute_then_parse_round_trip() {
        let now = now_dt();
        let vod: Vec<VodItem> = (0..10)
            .map(|i| {
                make_vod(
                    &format!("v{}", i),
                    &format!("Movie {}", i),
                    "movie",
                    Some("Action"),
                    Some("7.0"),
                    Some(2025),
                    Some(now - chrono::Duration::days(i as i64)),
                )
            })
            .collect();

        let history: Vec<WatchSignal> = (0..5)
            .map(|i| {
                make_signal(
                    &format!("v{}", i),
                    "movie",
                    0.8,
                    (now - chrono::Duration::days(i as i64))
                        .and_utc()
                        .timestamp_millis(),
                )
            })
            .collect();

        let sections = compute_recommendations(
            &vod,
            &[],
            &history,
            &[],
            &[],
            4,
            now.and_utc().timestamp_millis(),
        );

        let parsed = parse_recommendation_sections(&sections);
        assert!(parsed.is_ok(), "parse failed: {:?}", parsed.err(),);
        assert_eq!(parsed.unwrap().len(), sections.len(),);
    }

    // 23. compute → deserialize_full round trip
    //     succeeds.
    #[test]
    fn compute_then_deserialize_full_round_trip() {
        let now = now_dt();
        let vod: Vec<VodItem> = (0..10)
            .map(|i| {
                make_vod(
                    &format!("v{}", i),
                    &format!("Movie {}", i),
                    "movie",
                    Some("Action"),
                    Some("7.0"),
                    Some(2025),
                    Some(now - chrono::Duration::days(i as i64)),
                )
            })
            .collect();

        let history: Vec<WatchSignal> = (0..5)
            .map(|i| {
                make_signal(
                    &format!("v{}", i),
                    "movie",
                    0.8,
                    (now - chrono::Duration::days(i as i64))
                        .and_utc()
                        .timestamp_millis(),
                )
            })
            .collect();

        let sections = compute_recommendations(
            &vod,
            &[],
            &history,
            &[],
            &[],
            4,
            now.and_utc().timestamp_millis(),
        );

        let full = deserialize_full_sections(&sections);
        assert!(full.is_ok(), "deserialize_full failed: {:?}", full.err(),);
        let full = full.unwrap();
        assert_eq!(full.len(), sections.len());

        // Verify each section has matching type.
        for (orig, deser) in sections.iter().zip(full.iter()) {
            assert_eq!(orig.title, deser.title);
            assert_eq!(orig.items.len(), deser.items.len(),);
        }
    }

    // 24. All items watched → sections are empty
    //     or minimal.
    #[test]
    fn all_items_watched_returns_minimal() {
        let now = now_dt();
        let vod: Vec<VodItem> = (0..5)
            .map(|i| {
                make_vod(
                    &format!("v{}", i),
                    &format!("Movie {}", i),
                    "movie",
                    Some("Action"),
                    Some("7.0"),
                    Some(2025),
                    Some(now - chrono::Duration::days(i as i64)),
                )
            })
            .collect();

        // ALL items watched at 95%+.
        let history: Vec<WatchSignal> = (0..5)
            .map(|i| {
                make_signal(
                    &format!("v{}", i),
                    "movie",
                    0.96,
                    (now - chrono::Duration::days(i as i64))
                        .and_utc()
                        .timestamp_millis(),
                )
            })
            .collect();

        let sections = compute_recommendations(
            &vod,
            &[],
            &history,
            &[],
            &[],
            4,
            now.and_utc().timestamp_millis(),
        );

        // Every section should have 0 items
        // (all items are in watched_ids so
        // they're excluded everywhere).
        for section in &sections {
            assert!(
                section.items.is_empty(),
                "section '{}' should be empty but \
                 has {} items",
                section.title,
                section.items.len(),
            );
        }
    }

    // 25. Empty history + empty favourites →
    //     genre affinity is empty.
    #[test]
    fn genre_affinity_no_history_empty() {
        let vod: Vec<VodItem> = vec![make_vod(
            "v1",
            "A",
            "movie",
            Some("Action"),
            None,
            None,
            None,
        )];
        let vod_by_id: HashMap<&str, &VodItem> = vod.iter().map(|v| (v.id.as_str(), v)).collect();
        let ch_by_id: HashMap<&str, &Channel> = HashMap::new();

        let affinity = build_genre_affinity(&[], &[], &[], &vod, &vod_by_id, &ch_by_id, now_dt());

        assert!(
            affinity.is_empty(),
            "expected empty genre affinity, got {:?}",
            affinity,
        );
    }
}
