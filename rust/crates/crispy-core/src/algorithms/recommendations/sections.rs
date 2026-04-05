//! Section-builder functions for the recommendation
//! engine.
//!
//! Tests live at the bottom of this file in a `#[cfg(test)] mod tests` block.

use std::collections::{HashMap, HashSet};

use chrono::NaiveDateTime;

use crate::algorithms::normalize::normalize_category;
use crate::algorithms::watch_progress::NEXT_EPISODE_THRESHOLD;
use crate::models::{Channel, VodItem};

use super::helpers::{naive_from_epoch_ms, title_case, top_n_by_score, vod_to_recommendation};
use super::types::weights;
use super::types::{
    MAX_BECAUSE_SECTIONS, Recommendation, RecommendationSection, SECTION_SIZE, TOP_PICKS_SIZE,
    WatchSignal,
};

// ── Genre Affinity ───────────────────────────────────

pub(super) fn build_genre_affinity(
    history: &[WatchSignal],
    favorite_channel_ids: &[String],
    favorite_vod_ids: &[String],
    vod_items: &[VodItem],
    vod_by_id: &HashMap<&str, &VodItem>,
    channel_by_id: &HashMap<&str, &Channel>,
    now: NaiveDateTime,
) -> HashMap<String, f64> {
    let mut scores: HashMap<String, f64> = HashMap::new();

    let fav_vod_set: HashSet<&str> = favorite_vod_ids.iter().map(|s| s.as_str()).collect();

    for entry in history {
        let category = category_for(&entry.item_id, &entry.media_type, vod_by_id, channel_by_id);
        let cat = match category {
            Some(c) => normalize_category(&c),
            None => continue,
        };

        let entry_time = naive_from_epoch_ms(entry.last_watched_ms);
        let days = (now - entry_time).num_days() as f64;
        let decay = (-days / 30.0).exp();

        let signal = if entry.watched_percent > NEXT_EPISODE_THRESHOLD {
            1.0
        } else if entry.watched_percent > 0.1 {
            0.5
        } else {
            0.2
        };

        *scores.entry(cat).or_insert(0.0) += signal * decay;
    }

    // Boost favourite channels.
    for fav_id in favorite_channel_ids {
        if let Some(ch) = channel_by_id.get(fav_id.as_str())
            && let Some(ref group) = ch.channel_group
        {
            let cat = normalize_category(group);
            *scores.entry(cat).or_insert(0.0) += 1.5;
        }
    }

    // Boost favourite VOD items.
    for vod in vod_items {
        if fav_vod_set.contains(vod.id.as_str())
            && let Some(ref cat_raw) = vod.category
        {
            let cat = normalize_category(cat_raw);
            *scores.entry(cat).or_insert(0.0) += 1.5;
        }
    }

    // Normalize to [0, 1].
    let max_score = scores.values().copied().fold(0.0_f64, f64::max);
    if max_score > 0.0 {
        for v in scores.values_mut() {
            *v /= max_score;
        }
    }

    scores
}

pub(super) fn category_for(
    item_id: &str,
    media_type: &str,
    vod_by_id: &HashMap<&str, &VodItem>,
    channel_by_id: &HashMap<&str, &Channel>,
) -> Option<String> {
    if media_type == "channel" {
        channel_by_id
            .get(item_id)
            .and_then(|c| c.channel_group.clone())
    } else {
        vod_by_id.get(item_id).and_then(|v| v.category.clone())
    }
}

// ── Top Picks ────────────────────────────────────────

pub(super) fn build_top_picks(
    vod_items: &[VodItem],
    watched_ids: &HashSet<&str>,
    genre_affinity: &HashMap<String, f64>,
    history: &[WatchSignal],
    now: NaiveDateTime,
) -> RecommendationSection {
    // Recent watch counts (7 days) for trend scoring.
    let cutoff_ms = (now - chrono::Duration::days(7))
        .and_utc()
        .timestamp_millis();

    let mut watch_counts: HashMap<&str, u32> = HashMap::new();
    for h in history {
        if h.last_watched_ms >= cutoff_ms {
            *watch_counts.entry(h.item_id.as_str()).or_insert(0) += 1;
        }
    }
    let max_watches = watch_counts.values().copied().max().unwrap_or(1).max(1) as f64;

    let mut scored: Vec<Recommendation> = Vec::new();

    for item in vod_items {
        if watched_ids.contains(item.id.as_str()) {
            continue;
        }
        if item.item_type == "episode" {
            continue;
        }

        let cat = normalize_category(item.category.as_deref().unwrap_or(""));
        let affinity = genre_affinity.get(&cat).copied().unwrap_or(0.0);

        let freshness = match item.added_at {
            Some(added) => {
                let days = (now - added).num_days() as f64;
                (-days / 14.0).exp()
            }
            None => 0.0,
        };

        let num_rating = item
            .rating
            .as_deref()
            .and_then(|r| r.parse::<f64>().ok())
            .unwrap_or(0.0)
            .clamp(0.0, 10.0);
        let rating_score = num_rating / 10.0;

        let trend = watch_counts.get(item.id.as_str()).copied().unwrap_or(0) as f64 / max_watches;

        let fav_boost = if item.is_favorite { 1.0 } else { 0.0 };

        let score = (affinity * weights::GENRE_AFFINITY
            + fav_boost * weights::FAVORITE_BOOST
            + freshness * weights::FRESHNESS
            + rating_score * weights::CONTENT_RATING
            + trend * weights::TRENDING_BOOST)
            .clamp(0.0, 1.0);

        scored.push(vod_to_recommendation(item, "topPick", score));
    }

    top_n_by_score(&mut scored, TOP_PICKS_SIZE);

    RecommendationSection {
        title: "Top Picks for You".to_string(),
        section_type: "topPicks".to_string(),
        items: scored,
    }
}

// ── Because You Watched ──────────────────────────────

pub(super) fn build_because_you_watched(
    history: &[WatchSignal],
    vod_items: &[VodItem],
    vod_by_id: &HashMap<&str, &VodItem>,
    watched_ids: &HashSet<&str>,
) -> Vec<RecommendationSection> {
    let mut seen_categories: HashSet<String> = HashSet::new();
    let mut source_items: Vec<&WatchSignal> = Vec::new();

    for h in history {
        if h.media_type == "channel" {
            continue;
        }
        if h.watched_percent < 0.25 {
            continue;
        }

        let vod = match vod_by_id.get(h.item_id.as_str()) {
            Some(v) => v,
            None => continue,
        };
        let cat_raw = match &vod.category {
            Some(c) => normalize_category(c),
            None => continue,
        };

        if seen_categories.contains(&cat_raw) {
            continue;
        }

        seen_categories.insert(cat_raw);
        source_items.push(h);

        if source_items.len() >= MAX_BECAUSE_SECTIONS {
            break;
        }
    }

    let mut sections = Vec::new();
    for source in &source_items {
        let source_vod = match vod_by_id.get(source.item_id.as_str()) {
            Some(v) => v,
            None => continue,
        };
        let cat = normalize_category(source_vod.category.as_ref().unwrap());

        let mut scored: Vec<Recommendation> = vod_items
            .iter()
            .filter(|item| {
                !watched_ids.contains(item.id.as_str())
                    && item.item_type != "episode"
                    && item
                        .category
                        .as_ref()
                        .is_some_and(|c| normalize_category(c) == cat)
            })
            .map(|item| {
                let mut score = 0.5;

                if let (Some(src_yr), Some(itm_yr)) = (source_vod.year, item.year) {
                    let diff = (src_yr - itm_yr).unsigned_abs();
                    if diff < 3 {
                        score += 0.3;
                    }
                    if diff < 1 {
                        score += 0.1;
                    }
                }

                if let Some(nr) = item.rating.as_deref().and_then(|r| r.parse::<f64>().ok()) {
                    score += (nr / 10.0) * 0.1;
                }

                vod_to_recommendation(item, "becauseYouWatched", score.clamp(0.0, 1.0))
            })
            .collect();

        top_n_by_score(&mut scored, 10);

        if !scored.is_empty() {
            sections.push(RecommendationSection {
                title: format!("Because you watched {}", source_vod.name),
                section_type: "becauseYouWatched".to_string(),
                items: scored,
            });
        }
    }

    sections
}

// ── Popular in Genre ─────────────────────────────────

pub(super) fn build_popular_in_genre(
    genre_affinity: &HashMap<String, f64>,
    vod_items: &[VodItem],
    watched_ids: &HashSet<&str>,
    history: &[WatchSignal],
) -> Vec<RecommendationSection> {
    if genre_affinity.is_empty() {
        return Vec::new();
    }

    // Sort genres by affinity descending.
    let mut sorted_genres: Vec<(&String, &f64)> = genre_affinity.iter().collect();
    sorted_genres.sort_by(|a, b| b.1.total_cmp(a.1));
    let top_genres: Vec<&String> = sorted_genres.iter().take(3).map(|(k, _)| *k).collect();

    // Total watch counts per item (all time).
    let mut watch_counts: HashMap<&str, u32> = HashMap::new();
    for h in history {
        *watch_counts.entry(h.item_id.as_str()).or_insert(0) += 1;
    }

    let mut sections = Vec::new();
    for genre in &top_genres {
        let mut scored: Vec<Recommendation> = vod_items
            .iter()
            .filter(|item| {
                !watched_ids.contains(item.id.as_str())
                    && item.item_type != "episode"
                    && item
                        .category
                        .as_ref()
                        .is_some_and(|c| normalize_category(c) == **genre)
            })
            .map(|item| {
                let watches = watch_counts.get(item.id.as_str()).copied().unwrap_or(0) as f64;
                let num_rating = item
                    .rating
                    .as_deref()
                    .and_then(|r| r.parse::<f64>().ok())
                    .unwrap_or(0.0);
                let recency = if item.added_at.is_some() { 0.3 } else { 0.0 };
                let score = watches * 0.4 + (num_rating / 10.0) * 0.3 + recency;

                vod_to_recommendation(item, "popularInGenre", score.clamp(0.0, 1.0))
            })
            .collect();

        top_n_by_score(&mut scored, SECTION_SIZE);

        if !scored.is_empty() {
            sections.push(RecommendationSection {
                title: format!("Popular in {}", title_case(genre)),
                section_type: "popularInGenre".to_string(),
                items: scored,
            });
        }
    }

    sections
}

// ── Trending ─────────────────────────────────────────

pub(super) fn build_trending(
    history: &[WatchSignal],
    _vod_items: &[VodItem],
    vod_by_id: &HashMap<&str, &VodItem>,
    watched_ids: &HashSet<&str>,
    now: NaiveDateTime,
) -> RecommendationSection {
    let cutoff_ms = (now - chrono::Duration::days(7))
        .and_utc()
        .timestamp_millis();

    let mut watch_counts: HashMap<&str, u32> = HashMap::new();
    for h in history {
        if h.last_watched_ms >= cutoff_ms && h.media_type != "channel" {
            *watch_counts.entry(h.item_id.as_str()).or_insert(0) += 1;
        }
    }

    let mut sorted: Vec<(&str, u32)> = watch_counts.into_iter().collect();
    sorted.sort_by(|a, b| b.1.cmp(&a.1));

    let max_count = sorted.first().map(|(_, c)| *c).unwrap_or(1).max(1) as f64;

    let mut items: Vec<Recommendation> = Vec::new();
    for (id, count) in &sorted {
        if watched_ids.contains(id) {
            continue;
        }
        let vod = match vod_by_id.get(id) {
            Some(v) => v,
            None => continue,
        };
        if vod.item_type == "episode" {
            continue;
        }

        items.push(vod_to_recommendation(
            vod,
            "trending",
            *count as f64 / max_count,
        ));

        if items.len() >= SECTION_SIZE {
            break;
        }
    }

    RecommendationSection {
        title: "Trending Now".to_string(),
        section_type: "trending".to_string(),
        items,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::NaiveDateTime;
    use std::collections::{HashMap, HashSet};

    fn epoch_ms(days_ago: i64) -> i64 {
        let now = chrono::Utc::now();
        let past = now - chrono::Duration::days(days_ago);
        past.timestamp_millis()
    }

    fn now_dt() -> NaiveDateTime {
        chrono::Utc::now().naive_utc()
    }

    fn make_vod(
        id: &str,
        category: Option<&str>,
        item_type: &str,
        rating: Option<&str>,
        added_days_ago: Option<i64>,
    ) -> VodItem {
        use chrono::Duration;
        VodItem {
            id: id.to_string(),
            native_id: id.to_string(),
            name: format!("Film {id}"),
            stream_url: "http://stream".to_string(),
            item_type: item_type.to_string(),
            poster_url: None,
            backdrop_url: None,
            description: None,
            rating: rating.map(|s| s.to_string()),
            year: Some(2020),
            duration: None,
            category: category.map(|s| s.to_string()),
            series_id: None,
            season_number: None,
            episode_number: None,
            ext: None,
            is_favorite: false,
            added_at: added_days_ago.map(|d| (chrono::Utc::now() - Duration::days(d)).naive_utc()),
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

    fn make_channel(id: &str, group: Option<&str>) -> Channel {
        Channel {
            id: id.to_string(),
            name: format!("Channel {id}"),
            stream_url: "http://stream".to_string(),
            number: None,
            channel_group: group.map(|s| s.to_string()),
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
            ..Default::default()
        }
    }

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

    // ── category_for ────────────────────────────────

    #[test]
    fn test_category_for_returns_channel_group_when_media_type_is_channel() {
        let ch = make_channel("c1", Some("Sports"));
        let mut channel_by_id: HashMap<&str, &Channel> = HashMap::new();
        channel_by_id.insert("c1", &ch);
        let vod_by_id: HashMap<&str, &VodItem> = HashMap::new();
        let result = category_for("c1", "channel", &vod_by_id, &channel_by_id);
        assert_eq!(result.as_deref(), Some("Sports"));
    }

    #[test]
    fn test_category_for_returns_vod_category_when_media_type_is_movie() {
        let vod = make_vod("v1", Some("Action"), "movie", None, None);
        let mut vod_by_id: HashMap<&str, &VodItem> = HashMap::new();
        vod_by_id.insert("v1", &vod);
        let channel_by_id: HashMap<&str, &Channel> = HashMap::new();
        let result = category_for("v1", "movie", &vod_by_id, &channel_by_id);
        assert_eq!(result.as_deref(), Some("Action"));
    }

    #[test]
    fn test_category_for_returns_none_when_item_not_found() {
        let vod_by_id: HashMap<&str, &VodItem> = HashMap::new();
        let channel_by_id: HashMap<&str, &Channel> = HashMap::new();
        let result = category_for("missing", "movie", &vod_by_id, &channel_by_id);
        assert!(result.is_none());
    }

    #[test]
    fn test_category_for_returns_none_when_channel_has_no_group() {
        let ch = make_channel("c1", None);
        let mut channel_by_id: HashMap<&str, &Channel> = HashMap::new();
        channel_by_id.insert("c1", &ch);
        let vod_by_id: HashMap<&str, &VodItem> = HashMap::new();
        let result = category_for("c1", "channel", &vod_by_id, &channel_by_id);
        assert!(result.is_none());
    }

    // ── build_genre_affinity ─────────────────────────

    #[test]
    fn test_build_genre_affinity_empty_history_and_no_favs_returns_empty() {
        let vod_by_id: HashMap<&str, &VodItem> = HashMap::new();
        let channel_by_id: HashMap<&str, &Channel> = HashMap::new();
        let scores = build_genre_affinity(&[], &[], &[], &[], &vod_by_id, &channel_by_id, now_dt());
        assert!(scores.is_empty());
    }

    #[test]
    fn test_build_genre_affinity_normalizes_to_one() {
        let vod = make_vod("v1", Some("Action"), "movie", None, None);
        let vods = vec![vod.clone()];
        let mut vod_by_id: HashMap<&str, &VodItem> = HashMap::new();
        vod_by_id.insert("v1", &vod);
        let channel_by_id: HashMap<&str, &Channel> = HashMap::new();
        let history = vec![make_signal("v1", "movie", 0.9, epoch_ms(1))];
        let scores = build_genre_affinity(
            &history,
            &[],
            &[],
            &vods,
            &vod_by_id,
            &channel_by_id,
            now_dt(),
        );
        let max: f64 = scores.values().copied().fold(0.0_f64, f64::max);
        assert!(max <= 1.0 + f64::EPSILON, "max score {max} exceeds 1.0");
    }

    #[test]
    fn test_build_genre_affinity_favorite_channel_boosts_group() {
        let ch = make_channel("c1", Some("news"));
        let channels = vec![ch.clone()];
        let mut channel_by_id: HashMap<&str, &Channel> = HashMap::new();
        channel_by_id.insert("c1", &ch);
        let vod_by_id: HashMap<&str, &VodItem> = HashMap::new();
        let scores = build_genre_affinity(
            &[],
            &["c1".to_string()],
            &[],
            &[],
            &vod_by_id,
            &channel_by_id,
            now_dt(),
        );
        assert!(scores.contains_key("news"));
    }

    // ── build_top_picks ──────────────────────────────

    #[test]
    fn test_build_top_picks_excludes_episodes() {
        let ep = make_vod("e1", Some("drama"), "episode", None, None);
        let vods = vec![ep];
        let watched: HashSet<&str> = HashSet::new();
        let affinity: HashMap<String, f64> = HashMap::new();
        let section = build_top_picks(&vods, &watched, &affinity, &[], now_dt());
        assert!(section.items.is_empty());
    }

    #[test]
    fn test_build_top_picks_excludes_already_watched() {
        let movie = make_vod("v1", Some("action"), "movie", None, None);
        let vods = vec![movie];
        let mut watched: HashSet<&str> = HashSet::new();
        watched.insert("v1");
        let affinity: HashMap<String, f64> = HashMap::new();
        let section = build_top_picks(&vods, &watched, &affinity, &[], now_dt());
        assert!(section.items.is_empty());
    }

    #[test]
    fn test_build_top_picks_section_type_is_correct() {
        let section = build_top_picks(&[], &HashSet::new(), &HashMap::new(), &[], now_dt());
        assert_eq!(section.section_type, "topPicks");
        assert_eq!(section.title, "Top Picks for You");
    }

    #[test]
    fn test_build_top_picks_includes_unwatched_movies() {
        let movie = make_vod("v1", Some("action"), "movie", Some("8.0"), Some(5));
        let vods = vec![movie];
        let watched: HashSet<&str> = HashSet::new();
        let mut affinity: HashMap<String, f64> = HashMap::new();
        affinity.insert("action".to_string(), 1.0);
        let section = build_top_picks(&vods, &watched, &affinity, &[], now_dt());
        assert_eq!(section.items.len(), 1);
        assert_eq!(section.items[0].id, "v1");
    }

    // ── build_because_you_watched ────────────────────

    #[test]
    fn test_build_because_you_watched_empty_history_returns_empty() {
        let vod_by_id: HashMap<&str, &VodItem> = HashMap::new();
        let watched: HashSet<&str> = HashSet::new();
        let sections = build_because_you_watched(&[], &[], &vod_by_id, &watched);
        assert!(sections.is_empty());
    }

    #[test]
    fn test_build_because_you_watched_skips_channel_history() {
        let vod_by_id: HashMap<&str, &VodItem> = HashMap::new();
        let watched: HashSet<&str> = HashSet::new();
        let history = vec![make_signal("c1", "channel", 0.9, epoch_ms(1))];
        let sections = build_because_you_watched(&history, &[], &vod_by_id, &watched);
        assert!(sections.is_empty());
    }

    #[test]
    fn test_build_because_you_watched_skips_low_watch_percent() {
        let vod = make_vod("v1", Some("drama"), "movie", None, None);
        let vods = vec![vod.clone()];
        let mut vod_by_id: HashMap<&str, &VodItem> = HashMap::new();
        vod_by_id.insert("v1", &vod);
        let watched: HashSet<&str> = HashSet::new();
        // 0.2 < NEXT_EPISODE_THRESHOLD (0.25) so should be skipped
        let history = vec![make_signal("v1", "movie", 0.2, epoch_ms(1))];
        let sections = build_because_you_watched(&history, &vods, &vod_by_id, &watched);
        assert!(sections.is_empty());
    }

    // ── build_trending ───────────────────────────────

    #[test]
    fn test_build_trending_section_type_and_title() {
        let vod_by_id: HashMap<&str, &VodItem> = HashMap::new();
        let watched: HashSet<&str> = HashSet::new();
        let section = build_trending(&[], &[], &vod_by_id, &watched, now_dt());
        assert_eq!(section.section_type, "trending");
        assert_eq!(section.title, "Trending Now");
        assert!(section.items.is_empty());
    }

    #[test]
    fn test_build_trending_excludes_channel_history() {
        let vod_by_id: HashMap<&str, &VodItem> = HashMap::new();
        let watched: HashSet<&str> = HashSet::new();
        let history = vec![make_signal("c1", "channel", 1.0, epoch_ms(1))];
        let section = build_trending(&history, &[], &vod_by_id, &watched, now_dt());
        assert!(section.items.is_empty());
    }

    #[test]
    fn test_build_trending_excludes_old_history_beyond_7_days() {
        let vod = make_vod("v1", Some("action"), "movie", None, None);
        let vod_clone = vod.clone();
        let mut vod_by_id: HashMap<&str, &VodItem> = HashMap::new();
        vod_by_id.insert("v1", &vod);
        let watched: HashSet<&str> = HashSet::new();
        // 8 days ago — outside the 7-day window
        let history = vec![make_signal("v1", "movie", 1.0, epoch_ms(8))];
        let vods = vec![vod_clone];
        let section = build_trending(&history, &vods, &vod_by_id, &watched, now_dt());
        assert!(section.items.is_empty());
    }

    // ── build_new_for_you ────────────────────────────

    #[test]
    fn test_build_new_for_you_excludes_items_older_than_14_days() {
        let old = make_vod("v1", Some("action"), "movie", None, Some(20));
        let vods = vec![old];
        let watched: HashSet<&str> = HashSet::new();
        let affinity: HashMap<String, f64> = HashMap::new();
        let section = build_new_for_you(&vods, &watched, &affinity, now_dt());
        assert!(section.items.is_empty());
    }

    #[test]
    fn test_build_new_for_you_includes_items_within_14_days() {
        let recent = make_vod("v1", Some("action"), "movie", None, Some(5));
        let vods = vec![recent];
        let watched: HashSet<&str> = HashSet::new();
        let mut affinity: HashMap<String, f64> = HashMap::new();
        affinity.insert("action".to_string(), 1.0);
        let section = build_new_for_you(&vods, &watched, &affinity, now_dt());
        assert_eq!(section.items.len(), 1);
        assert_eq!(section.section_type, "newForYou");
    }

    #[test]
    fn test_build_new_for_you_excludes_episodes() {
        let ep = make_vod("e1", Some("drama"), "episode", None, Some(3));
        let vods = vec![ep];
        let watched: HashSet<&str> = HashSet::new();
        let section = build_new_for_you(&vods, &watched, &HashMap::new(), now_dt());
        assert!(section.items.is_empty());
    }

    // ── build_cold_start ─────────────────────────────

    #[test]
    fn test_build_cold_start_returns_empty_when_no_vod() {
        let sections = build_cold_start(&[], &HashSet::new());
        assert!(sections.is_empty());
    }

    #[test]
    fn test_build_cold_start_highly_rated_section_created() {
        let movie = make_vod("v1", Some("action"), "movie", Some("9.0"), None);
        let vods = vec![movie];
        let sections = build_cold_start(&vods, &HashSet::new());
        let types: Vec<&str> = sections.iter().map(|s| s.section_type.as_str()).collect();
        assert!(types.contains(&"highlyRated"));
    }

    #[test]
    fn test_build_cold_start_recently_added_section_created() {
        let movie = make_vod("v1", Some("action"), "movie", None, Some(3));
        let vods = vec![movie];
        let sections = build_cold_start(&vods, &HashSet::new());
        let types: Vec<&str> = sections.iter().map(|s| s.section_type.as_str()).collect();
        assert!(types.contains(&"recentlyAdded"));
    }

    #[test]
    fn test_build_cold_start_excludes_episodes() {
        let ep = make_vod("e1", Some("drama"), "episode", Some("9.5"), Some(1));
        let vods = vec![ep];
        let sections = build_cold_start(&vods, &HashSet::new());
        // No section can have episodes
        for s in &sections {
            for item in &s.items {
                assert_ne!(item.id, "e1");
            }
        }
    }

    // ── build_popular_in_genre ───────────────────────

    #[test]
    fn test_build_popular_in_genre_empty_affinity_returns_empty() {
        let movie = make_vod("v1", Some("action"), "movie", None, None);
        let vods = vec![movie];
        let watched: HashSet<&str> = HashSet::new();
        let sections = build_popular_in_genre(&HashMap::new(), &vods, &watched, &[]);
        assert!(sections.is_empty());
    }

    #[test]
    fn test_build_popular_in_genre_creates_section_per_top_genre() {
        let movie = make_vod("v1", Some("action"), "movie", Some("7.0"), None);
        let vods = vec![movie];
        let watched: HashSet<&str> = HashSet::new();
        let mut affinity: HashMap<String, f64> = HashMap::new();
        affinity.insert("action".to_string(), 1.0);
        let sections = build_popular_in_genre(&affinity, &vods, &watched, &[]);
        assert!(!sections.is_empty());
        assert_eq!(sections[0].section_type, "popularInGenre");
        assert!(sections[0].title.contains("Action"));
    }
}

// ── New for You ──────────────────────────────────────

pub(super) fn build_new_for_you(
    vod_items: &[VodItem],
    watched_ids: &HashSet<&str>,
    genre_affinity: &HashMap<String, f64>,
    now: NaiveDateTime,
) -> RecommendationSection {
    let cutoff = now - chrono::Duration::days(14);

    let mut scored: Vec<Recommendation> = vod_items
        .iter()
        .filter(|item| {
            !watched_ids.contains(item.id.as_str())
                && item.item_type != "episode"
                && item.added_at.map(|a| a > cutoff).unwrap_or(false)
        })
        .map(|item| {
            let cat = normalize_category(item.category.as_deref().unwrap_or(""));
            let affinity = genre_affinity.get(&cat).copied().unwrap_or(0.0);
            let num_rating = item
                .rating
                .as_deref()
                .and_then(|r| r.parse::<f64>().ok())
                .unwrap_or(0.0);

            let score = affinity * 0.7 + (num_rating / 10.0) * 0.3;

            vod_to_recommendation(item, "newForYou", score.clamp(0.0, 1.0))
        })
        .collect();

    top_n_by_score(&mut scored, SECTION_SIZE);

    RecommendationSection {
        title: "New for You".to_string(),
        section_type: "newForYou".to_string(),
        items: scored,
    }
}

// ── Cold Start ───────────────────────────────────────

pub(super) fn build_cold_start(
    vod_items: &[VodItem],
    watched_ids: &HashSet<&str>,
) -> Vec<RecommendationSection> {
    let mut sections = Vec::new();

    // Highly Rated.
    let mut rated: Vec<&VodItem> = vod_items
        .iter()
        .filter(|item| {
            !watched_ids.contains(item.id.as_str())
                && item.item_type != "episode"
                && item
                    .rating
                    .as_deref()
                    .and_then(|r| r.parse::<f64>().ok())
                    .is_some()
        })
        .collect();
    rated.sort_by(|a, b| {
        let ra = a
            .rating
            .as_deref()
            .and_then(|r| r.parse::<f64>().ok())
            .unwrap_or(0.0);
        let rb = b
            .rating
            .as_deref()
            .and_then(|r| r.parse::<f64>().ok())
            .unwrap_or(0.0);
        rb.total_cmp(&ra)
    });
    if !rated.is_empty() {
        sections.push(RecommendationSection {
            title: "Highly Rated".to_string(),
            section_type: "highlyRated".to_string(),
            items: rated
                .iter()
                .take(SECTION_SIZE)
                .map(|v| {
                    vod_to_recommendation(
                        v,
                        "highlyRated",
                        v.rating
                            .as_deref()
                            .and_then(|r| r.parse::<f64>().ok())
                            .unwrap_or(0.0)
                            .clamp(0.0, 10.0)
                            / 10.0,
                    )
                })
                .collect(),
        });
    }

    // Recently Added.
    let mut recent: Vec<&VodItem> = vod_items
        .iter()
        .filter(|item| {
            !watched_ids.contains(item.id.as_str())
                && item.item_type != "episode"
                && item.added_at.is_some()
        })
        .collect();
    recent.sort_by(|a, b| b.added_at.unwrap().cmp(&a.added_at.unwrap()));
    if !recent.is_empty() {
        sections.push(RecommendationSection {
            title: "Recently Added".to_string(),
            section_type: "recentlyAdded".to_string(),
            items: recent
                .iter()
                .take(SECTION_SIZE)
                .map(|v| vod_to_recommendation(v, "recentlyAdded", 0.0))
                .collect(),
        });
    }

    sections
}
