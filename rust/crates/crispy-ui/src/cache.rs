/// In-memory cache and pure filter/search functions for CrispyTivi UI.
///
/// This module is intentionally free of DB access, Slint calls, and async code.
/// All functions are pure: given input slices, return computed output.
use std::collections::{BTreeSet, HashSet};

use crispy_server::models::{Channel, Source, SourceStats, VodItem};

use crate::events::{ChannelInfo, Screen, SourceInfo, VodInfo};

// ── Constants ────────────────────────────────────────────────────────────────

pub const SEARCH_MAX_RESULTS: usize = 100;

// ── AppDataCache ─────────────────────────────────────────────────────────────

/// Central in-memory cache for all content loaded from the DB/service layer.
///
/// Rebuilt after every sync or source change. All UI reads come from here —
/// no DB round-trips during browsing.
#[derive(Debug, Default)]
pub struct AppDataCache {
    pub sources: Vec<Source>,
    pub source_stats: Vec<SourceStats>,
    pub all_channels: Vec<Channel>,
    pub all_vod: Vec<VodItem>,
    /// Sorted, deduplicated list of channel group names.
    pub channel_groups: Vec<String>,
    /// Sorted, deduplicated list of VOD category names.
    pub vod_categories: Vec<String>,
    /// Set of favorited channel IDs.
    pub favorites: HashSet<String>,
}

impl AppDataCache {
    /// Construct an empty cache (used before first sync completes).
    pub fn empty() -> Self {
        Self::default()
    }

    /// Find a channel by its ID. Returns `None` if not present.
    pub fn find_channel(&self, id: &str) -> Option<&Channel> {
        self.all_channels.iter().find(|c| c.id == id)
    }

    /// Find a VOD item by its ID. Returns `None` if not present.
    pub fn find_vod(&self, id: &str) -> Option<&VodItem> {
        self.all_vod.iter().find(|v| v.id == id)
    }

    /// Toggle the favorite state for a channel ID.
    ///
    /// Returns `true` if the channel is now a favorite, `false` if removed.
    pub fn toggle_favorite(&mut self, id: &str) -> bool {
        if self.favorites.contains(id) {
            self.favorites.remove(id);
            false
        } else {
            self.favorites.insert(id.to_owned());
            true
        }
    }

    /// Rebuild `channel_groups` from `all_channels`.
    ///
    /// Call after loading or refreshing channels.
    pub fn rebuild_groups(&mut self) {
        let set: BTreeSet<String> = self
            .all_channels
            .iter()
            .filter_map(|c| c.channel_group.clone())
            .filter(|g| !g.is_empty())
            .collect();
        self.channel_groups = set.into_iter().collect();
    }

    /// Rebuild `vod_categories` from `all_vod`.
    ///
    /// Call after loading or refreshing VOD content.
    pub fn rebuild_vod_categories(&mut self) {
        let set: BTreeSet<String> = self
            .all_vod
            .iter()
            .filter_map(|v| v.category.clone())
            .filter(|c| !c.is_empty())
            .collect();
        self.vod_categories = set.into_iter().collect();
    }
}

// ── FilterState ──────────────────────────────────────────────────────────────

/// Describes the current filter/search state for a browsing session.
#[derive(Debug, Clone)]
pub struct FilterState {
    pub active_group: String,
    pub active_vod_category: String,
    pub active_screen: Screen,
}

impl Default for FilterState {
    fn default() -> Self {
        Self {
            active_group: String::new(),
            active_vod_category: String::new(),
            active_screen: Screen::Home,
        }
    }
}

// ── Conversion helpers ───────────────────────────────────────────────────────

/// Convert a `Channel` to a UI-facing `ChannelInfo`.
pub fn channel_to_info(c: &Channel, favorites: &HashSet<String>) -> ChannelInfo {
    ChannelInfo {
        id: c.id.clone(),
        name: c.name.clone(),
        stream_url: c.stream_url.clone(),
        logo_url: c.logo_url.clone(),
        channel_group: c.channel_group.clone(),
        number: c.number,
        is_favorite: favorites.contains(&c.id),
        source_id: c.source_id.clone(),
        resolution: c.resolution.clone(),
        has_catchup: c.has_catchup,
    }
}

/// Convert a `VodItem` to a UI-facing `VodInfo`.
pub fn vod_to_info(v: &VodItem) -> VodInfo {
    VodInfo {
        id: v.id.clone(),
        name: v.name.clone(),
        stream_url: v.stream_url.clone(),
        item_type: v.item_type.clone(),
        poster_url: v.poster_url.clone(),
        backdrop_url: v.backdrop_url.clone(),
        description: v.description.clone(),
        rating: v.rating.clone(),
        year: v.year,
        duration_minutes: v.duration,
        source_id: v.source_id.clone(),
        is_favorite: v.is_favorite,
    }
}

/// Convert a `Source` (and optional `SourceStats`) to a UI-facing `SourceInfo`.
///
/// `stats` provides channel/VOD counts; pass `None` when counts are unavailable.
pub fn source_to_info(s: &Source, _stats: Option<&SourceStats>) -> SourceInfo {
    SourceInfo {
        id: s.id.clone(),
        name: s.name.clone(),
        source_type: s.source_type.clone(),
        url: s.url.clone(),
        enabled: s.enabled,
        last_sync_status: s.last_sync_status.clone(),
        last_sync_error: s.last_sync_error.clone(),
    }
}

// ── Pure filter functions ────────────────────────────────────────────────────

/// Filter channels by group and paginate.
///
/// - `group`: empty string means "all groups"; any other value filters by exact match.
/// - Channels in `favorites` are always present regardless of group when group is empty.
///
/// Returns `(page_items, total_matching, has_more)`.
pub fn filter_channels(
    all: &[Channel],
    group: &str,
    favorites: &HashSet<String>,
    offset: usize,
    page_size: usize,
) -> (Vec<ChannelInfo>, i32, bool) {
    let filtered: Vec<&Channel> = all
        .iter()
        .filter(|c| {
            if group.is_empty() {
                true
            } else if group == "Favorites" {
                // "Favorites" is a virtual group — show only favorited channels
                favorites.contains(&c.id)
            } else {
                c.channel_group.as_deref().unwrap_or("") == group
            }
        })
        .collect();

    let total = filtered.len();
    let page: Vec<ChannelInfo> = filtered
        .into_iter()
        .skip(offset)
        .take(page_size)
        .map(|c| channel_to_info(c, favorites))
        .collect();

    let has_more = offset + page_size < total;
    (page, total as i32, has_more)
}

/// Filter VOD items by type and category, then paginate.
///
/// - `item_type`: `"movie"` returns only movies; `"series"` returns series and episodes;
///   empty string returns all.
/// - `category`: empty string means all categories.
///
/// Returns `(page_items, categories_in_filtered_set, total_matching, has_more)`.
pub fn filter_vod(
    all: &[VodItem],
    item_type: &str,
    category: &str,
    offset: usize,
    page_size: usize,
) -> (Vec<VodInfo>, Vec<String>, i32, bool) {
    let type_filtered: Vec<&VodItem> = all
        .iter()
        .filter(|v| {
            if item_type.is_empty() {
                true
            } else if item_type == "series" {
                // "series" group covers series headers and individual episodes
                v.item_type == "series" || v.item_type == "episode"
            } else {
                v.item_type == item_type
            }
        })
        .collect();

    // Collect categories present in the type-filtered set.
    let categories: Vec<String> = {
        let set: BTreeSet<String> = type_filtered
            .iter()
            .filter_map(|v| v.category.clone())
            .filter(|c| !c.is_empty())
            .collect();
        set.into_iter().collect()
    };

    let cat_filtered: Vec<&VodItem> = type_filtered
        .into_iter()
        .filter(|v| {
            if category.is_empty() {
                true
            } else {
                v.category.as_deref().unwrap_or("") == category
            }
        })
        .collect();

    let total = cat_filtered.len();
    let page: Vec<VodInfo> = cat_filtered
        .into_iter()
        .skip(offset)
        .take(page_size)
        .map(vod_to_info)
        .collect();

    let has_more = offset + page_size < total;
    (page, categories, total as i32, has_more)
}

/// Search channels and VOD by name (case-insensitive), capped at `max` results each.
///
/// Returns `(matching_channels, matching_vod)`.
pub fn search_cached(
    channels: &[Channel],
    vod: &[VodItem],
    query: &str,
    max: usize,
) -> (Vec<ChannelInfo>, Vec<VodInfo>) {
    if query.is_empty() {
        return (Vec::new(), Vec::new());
    }

    let q = query.to_lowercase();
    let empty_favs = HashSet::new();

    let matched_channels: Vec<ChannelInfo> = channels
        .iter()
        .filter(|c| c.name.to_lowercase().contains(&q))
        .take(max)
        .map(|c| channel_to_info(c, &empty_favs))
        .collect();

    let matched_vod: Vec<VodInfo> = vod
        .iter()
        .filter(|v| v.name.to_lowercase().contains(&q))
        .take(max)
        .map(vod_to_info)
        .collect();

    (matched_channels, matched_vod)
}

// ── Tests ────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    const CHANNEL_PAGE_SIZE: usize = 200;
    const VOD_PAGE_SIZE: usize = 100;

    fn make_channel(id: &str, name: &str, group: Option<&str>) -> Channel {
        Channel {
            id: id.to_owned(),
            name: name.to_owned(),
            stream_url: format!("http://example.com/{id}.ts"),
            number: None,
            channel_group: group.map(str::to_owned),
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
        }
    }

    fn make_vod(id: &str, name: &str, item_type: &str, category: Option<&str>) -> VodItem {
        VodItem {
            id: id.to_owned(),
            name: name.to_owned(),
            stream_url: format!("http://example.com/{id}.mp4"),
            item_type: item_type.to_owned(),
            poster_url: None,
            backdrop_url: None,
            description: None,
            rating: None,
            year: None,
            duration: None,
            category: category.map(str::to_owned),
            series_id: None,
            season_number: None,
            episode_number: None,
            ext: None,
            is_favorite: false,
            added_at: None,
            updated_at: None,
            source_id: None,
        }
    }

    // ── filter_channels ──────────────────────────────────────────────────────

    #[test]
    fn test_filter_channels_empty_group_returns_all() {
        let channels = vec![
            make_channel("c1", "BBC One", Some("UK")),
            make_channel("c2", "CNN", Some("News")),
            make_channel("c3", "Ungrouped", None),
        ];
        let favs = HashSet::new();
        let (page, total, has_more) = filter_channels(&channels, "", &favs, 0, CHANNEL_PAGE_SIZE);
        assert_eq!(total, 3);
        assert_eq!(page.len(), 3);
        assert!(!has_more);
    }

    #[test]
    fn test_filter_channels_group_filters_correctly() {
        let channels = vec![
            make_channel("c1", "BBC One", Some("UK")),
            make_channel("c2", "BBC Two", Some("UK")),
            make_channel("c3", "CNN", Some("News")),
        ];
        let favs = HashSet::new();
        let (page, total, has_more) = filter_channels(&channels, "UK", &favs, 0, CHANNEL_PAGE_SIZE);
        assert_eq!(total, 2);
        assert_eq!(page.len(), 2);
        assert!(
            page.iter()
                .all(|c| c.channel_group.as_deref() == Some("UK"))
        );
        assert!(!has_more);
    }

    #[test]
    fn test_filter_channels_pagination_works() {
        let channels: Vec<Channel> = (0..10)
            .map(|i| make_channel(&format!("c{i}"), &format!("Ch {i}"), Some("All")))
            .collect();
        let favs = HashSet::new();

        let (page1, total, has_more) = filter_channels(&channels, "", &favs, 0, 4);
        assert_eq!(total, 10);
        assert_eq!(page1.len(), 4);
        assert!(has_more);

        let (page2, _, has_more2) = filter_channels(&channels, "", &favs, 4, 4);
        assert_eq!(page2.len(), 4);
        assert!(has_more2);

        let (page3, _, has_more3) = filter_channels(&channels, "", &favs, 8, 4);
        assert_eq!(page3.len(), 2);
        assert!(!has_more3);
    }

    #[test]
    fn test_filter_channels_favorites_group() {
        let channels = vec![
            make_channel("c1", "BBC One", Some("UK")),
            make_channel("c2", "CNN", Some("News")),
            make_channel("c3", "Al Jazeera", Some("News")),
        ];
        let mut favs = HashSet::new();
        favs.insert("c2".to_owned());

        let (page, total, _) = filter_channels(&channels, "Favorites", &favs, 0, CHANNEL_PAGE_SIZE);
        assert_eq!(total, 1);
        assert_eq!(page[0].id, "c2");
        assert!(
            page[0].is_favorite,
            "channel in Favorites group must have is_favorite=true"
        );
    }

    // ── filter_vod ───────────────────────────────────────────────────────────

    #[test]
    fn test_filter_vod_splits_movie_vs_series() {
        let vod = vec![
            make_vod("v1", "Dune", "movie", Some("SciFi")),
            make_vod("v2", "Breaking Bad", "series", Some("Drama")),
            make_vod("v3", "Inception", "movie", Some("SciFi")),
            make_vod("v4", "BB S01E01", "episode", Some("Drama")),
        ];

        let (movies, _, total_m, _) = filter_vod(&vod, "movie", "", 0, VOD_PAGE_SIZE);
        assert_eq!(total_m, 2);
        assert!(movies.iter().all(|v| v.item_type == "movie"));

        let (series, _, total_s, _) = filter_vod(&vod, "series", "", 0, VOD_PAGE_SIZE);
        assert_eq!(total_s, 2); // series + episode
    }

    #[test]
    fn test_filter_vod_category_filter() {
        let vod = vec![
            make_vod("v1", "Dune", "movie", Some("SciFi")),
            make_vod("v2", "Matrix", "movie", Some("SciFi")),
            make_vod("v3", "Scarface", "movie", Some("Crime")),
        ];
        let (page, cats, total, _) = filter_vod(&vod, "movie", "SciFi", 0, VOD_PAGE_SIZE);
        assert_eq!(total, 2);
        assert_eq!(page.len(), 2);
        // categories come from entire type-filtered set, not just the category-filtered one
        assert!(cats.contains(&"SciFi".to_owned()));
        assert!(cats.contains(&"Crime".to_owned()));
    }

    #[test]
    fn test_filter_vod_pagination() {
        let vod: Vec<VodItem> = (0..10)
            .map(|i| make_vod(&format!("v{i}"), &format!("Film {i}"), "movie", Some("All")))
            .collect();
        let (page1, _, total, has_more) = filter_vod(&vod, "movie", "", 0, 4);
        assert_eq!(total, 10);
        assert_eq!(page1.len(), 4);
        assert!(has_more);
    }

    // ── search_cached ────────────────────────────────────────────────────────

    #[test]
    fn test_search_cached_matches_channels_and_vod() {
        let channels = vec![
            make_channel("c1", "BBC News", Some("News")),
            make_channel("c2", "CNN International", Some("News")),
        ];
        let vod = vec![
            make_vod("v1", "BBC Documentary", "movie", Some("Docs")),
            make_vod("v2", "Inception", "movie", Some("SciFi")),
        ];

        let (ch, vo) = search_cached(&channels, &vod, "bbc", SEARCH_MAX_RESULTS);
        assert_eq!(ch.len(), 1);
        assert_eq!(ch[0].name, "BBC News");
        assert_eq!(vo.len(), 1, "expected 1 VOD result for 'bbc'");
        assert_eq!(vo[0].name, "BBC Documentary");
    }

    #[test]
    fn test_search_cached_empty_query_returns_empty() {
        let channels = vec![make_channel("c1", "BBC One", Some("UK"))];
        let vod = vec![make_vod("v1", "Dune", "movie", None)];
        let (ch, vo) = search_cached(&channels, &vod, "", SEARCH_MAX_RESULTS);
        assert!(ch.is_empty());
        assert!(vo.is_empty());
    }

    #[test]
    fn test_search_cached_caps_at_max() {
        let channels: Vec<Channel> = (0..20)
            .map(|i| make_channel(&format!("c{i}"), &format!("BBC {i}"), None))
            .collect();
        let (ch, _) = search_cached(&channels, &[], "bbc", 5);
        assert_eq!(ch.len(), 5);
    }

    #[test]
    fn test_search_cached_case_insensitive() {
        let channels = vec![make_channel("c1", "Al Jazeera English", Some("News"))];
        let (ch, _) = search_cached(&channels, &[], "AL JAZEERA", SEARCH_MAX_RESULTS);
        assert_eq!(ch.len(), 1);
    }

    // ── toggle_favorite ──────────────────────────────────────────────────────

    #[test]
    fn test_toggle_favorite_adds_then_removes() {
        let mut cache = AppDataCache::empty();
        let added = cache.toggle_favorite("ch-1");
        assert!(added);
        assert!(cache.favorites.contains("ch-1"));

        let removed = cache.toggle_favorite("ch-1");
        assert!(!removed);
        assert!(!cache.favorites.contains("ch-1"));
    }

    // ── rebuild helpers ──────────────────────────────────────────────────────

    #[test]
    fn test_find_vod_returns_item_when_present() {
        let mut cache = AppDataCache::empty();
        cache.all_vod = vec![
            make_vod("v1", "Dune", "movie", Some("SciFi")),
            make_vod("v2", "Inception", "movie", Some("SciFi")),
        ];
        assert!(cache.find_vod("v1").is_some());
        assert_eq!(cache.find_vod("v1").unwrap().name, "Dune");
        assert!(cache.find_vod("v99").is_none());
    }

    #[test]
    fn test_rebuild_groups_deduplicates_and_sorts() {
        let mut cache = AppDataCache::empty();
        cache.all_channels = vec![
            make_channel("c1", "Ch1", Some("ZZZ")),
            make_channel("c2", "Ch2", Some("AAA")),
            make_channel("c3", "Ch3", Some("AAA")),
            make_channel("c4", "Ch4", None),
        ];
        cache.rebuild_groups();
        assert_eq!(cache.channel_groups, vec!["AAA", "ZZZ"]);
    }

    #[test]
    fn test_rebuild_vod_categories_deduplicates_and_sorts() {
        let mut cache = AppDataCache::empty();
        cache.all_vod = vec![
            make_vod("v1", "Film1", "movie", Some("SciFi")),
            make_vod("v2", "Film2", "movie", Some("Drama")),
            make_vod("v3", "Film3", "movie", Some("SciFi")),
        ];
        cache.rebuild_vod_categories();
        assert_eq!(cache.vod_categories, vec!["Drama", "SciFi"]);
    }
}
