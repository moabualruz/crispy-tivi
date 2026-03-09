//! Channel sorting by number and name.
//!
//! Ports `_channelSort()` from Dart
//! `channel_repository_impl.dart`.

use std::collections::HashMap;

use serde::{Deserialize, Serialize};

use crate::models::Channel;

// ── FilterSortParams ─────────────────────────────────

/// Parameters for [`filter_and_sort_channels`].
///
/// Serialised from JSON at the FFI/WS boundary.
#[derive(Debug, Serialize, Deserialize)]
pub struct FilterSortParams {
    /// Free-text search query (empty = no filter).
    pub search_query: String,
    /// Sort mode: "default", "name", "dateAdded",
    /// "watchTime", or "manual".
    pub sort_mode: String,
    /// Group mode: "category" or "playlist".
    pub group_mode: String,
    /// Currently selected group (None = all).
    pub selected_group: Option<String>,
    /// Group names to hide entirely.
    #[serde(default)]
    pub hidden_groups: Vec<String>,
    /// Individual channel IDs to hide.
    #[serde(default)]
    pub hidden_channel_ids: Vec<String>,
    /// Whether to suppress duplicate channels.
    #[serde(default)]
    pub hide_duplicates: bool,
    /// Channel IDs considered duplicates.
    #[serde(default)]
    pub duplicate_ids: Vec<String>,
    /// channel_id → custom sort index (manual mode).
    #[serde(default)]
    pub custom_order_map: Option<HashMap<String, i32>>,
    /// source_id → display name mapping.
    #[serde(default)]
    pub source_names: HashMap<String, String>,
    /// channel_id → last-watched epoch milliseconds.
    #[serde(default)]
    pub last_watched_map: HashMap<String, i64>,
    /// When true, hidden channel IDs are included
    /// (for the "show hidden channels" toggle).
    #[serde(default)]
    pub show_hidden_channels: bool,
}

/// Sentinel group name for the favourites group,
/// matching Dart's `ChannelListState.favoritesGroup`.
const FAVORITES_GROUP: &str = "\u{2B50} Favorites";

// ── default sort helper ───────────────────────────

/// Default sort: by channel number asc (nulls last),
/// then by name asc case-insensitive.
///
/// Matches Dart's `_defaultChannelSort`.
fn default_channel_sort(a: &Channel, b: &Channel) -> std::cmp::Ordering {
    match (&a.number, &b.number) {
        (Some(na), Some(nb)) => {
            let cmp = na.cmp(nb);
            if cmp != std::cmp::Ordering::Equal {
                return cmp;
            }
        }
        (Some(_), None) => return std::cmp::Ordering::Less,
        (None, Some(_)) => return std::cmp::Ordering::Greater,
        (None, None) => {}
    }
    a.name.to_lowercase().cmp(&b.name.to_lowercase())
}

// ── filter_and_sort_channels ──────────────────────

/// Filter and sort a JSON-encoded channel list.
///
/// Ports the Dart `filterAndSortChannels()` function
/// from `channel_list_state.dart`.
///
/// # Arguments
/// * `channels_json` – JSON array of [`Channel`].
/// * `params_json`   – JSON-encoded [`FilterSortParams`].
///
/// # Returns
/// JSON array of [`Channel`] after filtering and
/// sorting.  Returns `"[]"` on parse error.
pub fn filter_and_sort_channels(channels_json: &str, params_json: &str) -> String {
    let channels: Vec<Channel> = match serde_json::from_str(channels_json) {
        Ok(v) => v,
        Err(_) => return "[]".to_string(),
    };
    let params: FilterSortParams = match serde_json::from_str(params_json) {
        Ok(v) => v,
        Err(_) => return "[]".to_string(),
    };

    let hidden_groups: std::collections::HashSet<&str> =
        params.hidden_groups.iter().map(String::as_str).collect();
    let hidden_ids: std::collections::HashSet<&str> = params
        .hidden_channel_ids
        .iter()
        .map(String::as_str)
        .collect();
    let duplicate_ids: std::collections::HashSet<&str> =
        params.duplicate_ids.iter().map(String::as_str).collect();

    // Pass 1: exclude hidden groups.
    let mut result: Vec<&Channel> = if hidden_groups.is_empty() {
        channels.iter().collect()
    } else {
        channels
            .iter()
            .filter(|c| {
                !c.channel_group
                    .as_deref()
                    .map(|g| hidden_groups.contains(g))
                    .unwrap_or(false)
            })
            .collect()
    };

    // Pass 2: exclude hidden channel IDs (unless
    // show_hidden_channels is set).
    if !hidden_ids.is_empty() && !params.show_hidden_channels {
        result.retain(|c| !hidden_ids.contains(c.id.as_str()));
    }

    // Pass 3: exclude duplicates.
    if params.hide_duplicates && !duplicate_ids.is_empty() {
        result.retain(|c| !duplicate_ids.contains(c.id.as_str()));
    }

    // Pass 4: group filter.
    if let Some(ref sel) = params.selected_group {
        if sel == FAVORITES_GROUP {
            result.retain(|c| c.is_favorite);
        } else if params.group_mode == "playlist" {
            // Resolve display name back to source_id.
            let source_id = params
                .source_names
                .iter()
                .find(|(_, name)| name.as_str() == sel.as_str())
                .map(|(id, _)| id.as_str())
                .unwrap_or(sel.as_str());
            result.retain(|c| c.source_id.as_deref() == Some(source_id));
        } else {
            result.retain(|c| c.channel_group.as_deref() == Some(sel.as_str()));
        }
    }

    // Pass 5: search predicate.
    if !params.search_query.is_empty() {
        let query = params.search_query.to_lowercase();
        result.retain(|c| {
            c.name.to_lowercase().contains(&query)
                || c.channel_group
                    .as_deref()
                    .map(|g| g.to_lowercase().contains(&query))
                    .unwrap_or(false)
        });
    }

    // Sort.
    let mut result: Vec<Channel> = result.into_iter().cloned().collect();
    match params.sort_mode.as_str() {
        "name" => {
            result.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
        }
        "dateAdded" => {
            result.sort_by(|a, b| {
                match (&a.added_at, &b.added_at) {
                    (Some(ta), Some(tb)) => tb.cmp(ta), // desc
                    (Some(_), None) => std::cmp::Ordering::Less,
                    (None, Some(_)) => std::cmp::Ordering::Greater,
                    (None, None) => default_channel_sort(a, b),
                }
            });
        }
        "watchTime" => {
            result.sort_by(|a, b| {
                let ta = params.last_watched_map.get(&a.id);
                let tb = params.last_watched_map.get(&b.id);
                match (ta, tb) {
                    (Some(ta), Some(tb)) => tb.cmp(ta), // desc
                    (Some(_), None) => std::cmp::Ordering::Less,
                    (None, Some(_)) => std::cmp::Ordering::Greater,
                    (None, None) => default_channel_sort(a, b),
                }
            });
        }
        "manual" => {
            if let Some(ref order_map) = params.custom_order_map {
                if !order_map.is_empty() {
                    result.sort_by(|a, b| {
                        let ao = order_map.get(&a.id);
                        let bo = order_map.get(&b.id);
                        match (ao, bo) {
                            (Some(ai), Some(bi)) => ai.cmp(bi),
                            (Some(_), None) => std::cmp::Ordering::Less,
                            (None, Some(_)) => std::cmp::Ordering::Greater,
                            (None, None) => default_channel_sort(a, b),
                        }
                    });
                } else {
                    result.sort_by(default_channel_sort);
                }
            } else {
                result.sort_by(default_channel_sort);
            }
        }
        // "default" and anything else.
        _ => {
            result.sort_by(default_channel_sort);
        }
    }

    serde_json::to_string(&result).unwrap_or_else(|_| "[]".to_string())
}

// ── sort_favorites ────────────────────────────────

/// Sort a JSON-encoded list of favourite channels.
///
/// Ports `sortFavorites()` from
/// `favorites_sort_utils.dart`.
///
/// # Arguments
/// * `channels_json` – JSON array of [`Channel`].
/// * `sort_mode`     – One of `"recentlyAdded"`,
///   `"nameAsc"`, `"nameDesc"`, `"contentType"`.
///
/// `"recentlyAdded"` is a no-op (preserves order).
/// Returns `"[]"` on parse error.
pub fn sort_favorites(channels_json: &str, sort_mode: &str) -> String {
    let mut channels: Vec<Channel> = match serde_json::from_str(channels_json) {
        Ok(v) => v,
        Err(_) => return "[]".to_string(),
    };

    match sort_mode {
        "recentlyAdded" => {
            // Preserve insertion order — no-op.
        }
        "nameAsc" => {
            channels.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
        }
        "nameDesc" => {
            channels.sort_by(|a, b| b.name.to_lowercase().cmp(&a.name.to_lowercase()));
        }
        "contentType" => {
            // Group by channel_group, then alphabetical
            // within group.  None group treated as "".
            channels.sort_by(|a, b| {
                let ga = a.channel_group.as_deref().unwrap_or("");
                let gb = b.channel_group.as_deref().unwrap_or("");
                let cmp = ga.cmp(gb);
                if cmp != std::cmp::Ordering::Equal {
                    return cmp;
                }
                a.name.to_lowercase().cmp(&b.name.to_lowercase())
            });
        }
        _ => {}
    }

    serde_json::to_string(&channels).unwrap_or_else(|_| "[]".to_string())
}

/// Sort channels by number (ascending, nulls last) then
/// by name (ascending, case-insensitive).
///
/// Pre-computes lowercase name keys to avoid O(N log N)
/// allocations in sort comparisons.
pub fn sort_channels(channels: &mut [Channel]) {
    // Pre-compute lowercase keys once — O(N) allocations
    // instead of O(N log N).
    let keys: Vec<String> = channels.iter().map(|c| c.name.to_lowercase()).collect();

    // Sort indices using number + cached key.
    let mut indices: Vec<usize> = (0..channels.len()).collect();
    indices.sort_by(|&i, &j| {
        let a = &channels[i];
        let b = &channels[j];
        match (&a.number, &b.number) {
            (Some(na), Some(nb)) => {
                let cmp = na.cmp(nb);
                if cmp != std::cmp::Ordering::Equal {
                    return cmp;
                }
            }
            (Some(_), None) => return std::cmp::Ordering::Less,
            (None, Some(_)) => return std::cmp::Ordering::Greater,
            (None, None) => {}
        }
        keys[i].cmp(&keys[j])
    });

    // Reorder channels according to the sorted indices.
    let sorted: Vec<Channel> = indices.into_iter().map(|i| channels[i].clone()).collect();
    channels.clone_from_slice(&sorted);
}

// ── Tests ────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn ch(id: &str, name: &str, num: Option<i32>) -> Channel {
        Channel {
            id: id.to_string(),
            name: name.to_string(),
            stream_url: String::new(),
            number: num,
            channel_group: None,
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

    #[test]
    fn channels_with_numbers_sort_ascending() {
        let mut channels = vec![
            ch("c", "CNN", Some(3)),
            ch("a", "ABC", Some(1)),
            ch("b", "BBC", Some(2)),
        ];
        sort_channels(&mut channels);
        let ids: Vec<&str> = channels.iter().map(|c| c.id.as_str()).collect();
        assert_eq!(ids, vec!["a", "b", "c"]);
    }

    #[test]
    fn null_numbers_go_last() {
        let mut channels = vec![
            ch("x", "No Num", None),
            ch("a", "ABC", Some(1)),
            ch("y", "Also None", None),
        ];
        sort_channels(&mut channels);
        let ids: Vec<&str> = channels.iter().map(|c| c.id.as_str()).collect();
        assert_eq!(ids, vec!["a", "y", "x"]);
    }

    #[test]
    fn same_number_sorts_by_name() {
        let mut channels = vec![
            ch("z", "Zebra", Some(5)),
            ch("a", "Alpha", Some(5)),
            ch("m", "Mike", Some(5)),
        ];
        sort_channels(&mut channels);
        let names: Vec<&str> = channels.iter().map(|c| c.name.as_str()).collect();
        assert_eq!(names, vec!["Alpha", "Mike", "Zebra"]);
    }

    #[test]
    fn all_nulls_sort_by_name_case_insensitive() {
        let mut channels = vec![
            ch("c", "charlie", None),
            ch("a", "Alpha", None),
            ch("b", "BRAVO", None),
        ];
        sort_channels(&mut channels);
        let names: Vec<&str> = channels.iter().map(|c| c.name.as_str()).collect();
        assert_eq!(names, vec!["Alpha", "BRAVO", "charlie"]);
    }

    // ── Additional sorting tests ────────────────────

    #[test]
    fn sort_by_number_ascending() {
        let mut channels = vec![
            ch("d", "Delta", Some(10)),
            ch("a", "Alpha", Some(1)),
            ch("c", "Charlie", Some(7)),
            ch("b", "Bravo", Some(3)),
        ];
        sort_channels(&mut channels);
        let nums: Vec<Option<i32>> = channels.iter().map(|c| c.number).collect();
        assert_eq!(nums, vec![Some(1), Some(3), Some(7), Some(10)]);
    }

    #[test]
    fn sort_nulls_last() {
        // Channels without number come after all numbered ones.
        let mut channels = vec![
            ch("x", "Xray", None),
            ch("a", "Alpha", Some(5)),
            ch("y", "Yankee", None),
            ch("b", "Bravo", Some(2)),
        ];
        sort_channels(&mut channels);
        let ids: Vec<&str> = channels.iter().map(|c| c.id.as_str()).collect();
        assert_eq!(ids, vec!["b", "a", "x", "y"]);
    }

    #[test]
    fn sort_tiebreak_by_name() {
        // Same number → alphabetical by name.
        let mut channels = vec![
            ch("c", "Charlie", Some(3)),
            ch("a", "Alpha", Some(3)),
            ch("b", "Bravo", Some(3)),
        ];
        sort_channels(&mut channels);
        let names: Vec<&str> = channels.iter().map(|c| c.name.as_str()).collect();
        assert_eq!(names, vec!["Alpha", "Bravo", "Charlie"]);
    }

    #[test]
    fn sort_case_insensitive_name() {
        // "abc" and "ABC" treated equivalently for ordering.
        let mut channels = vec![
            ch("c", "charlie", Some(1)),
            ch("a", "ALPHA", Some(1)),
            ch("b", "Bravo", Some(1)),
        ];
        sort_channels(&mut channels);
        let names: Vec<&str> = channels.iter().map(|c| c.name.as_str()).collect();
        assert_eq!(names, vec!["ALPHA", "Bravo", "charlie"]);
    }

    #[test]
    fn sort_empty_list() {
        let mut channels: Vec<Channel> = vec![];
        sort_channels(&mut channels);
        assert!(channels.is_empty());
    }

    #[test]
    fn sort_single_item() {
        let mut channels = vec![ch("a", "Alpha", Some(1))];
        sort_channels(&mut channels);
        assert_eq!(channels.len(), 1);
        assert_eq!(channels[0].id, "a");
        assert_eq!(channels[0].name, "Alpha");
    }

    // ── filter_and_sort_channels helpers ─────────────

    fn fch(
        id: &str,
        name: &str,
        num: Option<i32>,
        group: Option<&str>,
        favorite: bool,
        source_id: Option<&str>,
    ) -> Channel {
        Channel {
            id: id.to_string(),
            name: name.to_string(),
            stream_url: String::new(),
            number: num,
            channel_group: group.map(String::from),
            logo_url: None,
            tvg_id: None,
            tvg_name: None,
            is_favorite: favorite,
            user_agent: None,
            has_catchup: false,
            catchup_days: 0,
            catchup_type: None,
            catchup_source: None,
            resolution: None,
            source_id: source_id.map(String::from),
            added_at: None,
            updated_at: None,
            is_247: false,
        }
    }

    fn default_params() -> FilterSortParams {
        FilterSortParams {
            search_query: String::new(),
            sort_mode: "default".to_string(),
            group_mode: "category".to_string(),
            selected_group: None,
            hidden_groups: vec![],
            hidden_channel_ids: vec![],
            hide_duplicates: false,
            duplicate_ids: vec![],
            custom_order_map: None,
            source_names: HashMap::new(),
            last_watched_map: HashMap::new(),
            show_hidden_channels: false,
        }
    }

    fn run(channels: Vec<Channel>, params: FilterSortParams) -> Vec<String> {
        let channels_json = serde_json::to_string(&channels).unwrap();
        let params_json = serde_json::to_string(&params).unwrap();
        let result = filter_and_sort_channels(&channels_json, &params_json);
        let out: Vec<Channel> = serde_json::from_str(&result).unwrap();
        out.into_iter().map(|c| c.id).collect()
    }

    // ── filter_and_sort_channels tests ───────────────

    #[test]
    fn fas_empty_input() {
        let ids = run(vec![], default_params());
        assert!(ids.is_empty());
    }

    #[test]
    fn fas_filter_hidden_groups() {
        let channels = vec![
            fch("a", "News 1", Some(1), Some("News"), false, None),
            fch("b", "Sports 1", Some(2), Some("Sports"), false, None),
            fch("c", "News 2", Some(3), Some("News"), false, None),
        ];
        let params = FilterSortParams {
            hidden_groups: vec!["News".to_string()],
            ..default_params()
        };
        let ids = run(channels, params);
        assert_eq!(ids, vec!["b"]);
    }

    #[test]
    fn fas_filter_hidden_channel_ids() {
        let channels = vec![
            fch("a", "Alpha", Some(1), Some("G"), false, None),
            fch("b", "Bravo", Some(2), Some("G"), false, None),
            fch("c", "Charlie", Some(3), Some("G"), false, None),
        ];
        let params = FilterSortParams {
            hidden_channel_ids: vec!["b".to_string()],
            ..default_params()
        };
        let ids = run(channels, params);
        assert_eq!(ids, vec!["a", "c"]);
    }

    #[test]
    fn fas_show_hidden_channels_bypasses_filter() {
        let channels = vec![
            fch("a", "Alpha", Some(1), Some("G"), false, None),
            fch("b", "Bravo", Some(2), Some("G"), false, None),
        ];
        let params = FilterSortParams {
            hidden_channel_ids: vec!["b".to_string()],
            show_hidden_channels: true,
            ..default_params()
        };
        let ids = run(channels, params);
        assert_eq!(ids, vec!["a", "b"]);
    }

    #[test]
    fn fas_filter_duplicates() {
        let channels = vec![
            fch("a", "Alpha", Some(1), Some("G"), false, None),
            fch("b", "Bravo", Some(2), Some("G"), false, None),
            fch("c", "Charlie", Some(3), Some("G"), false, None),
        ];
        let params = FilterSortParams {
            hide_duplicates: true,
            duplicate_ids: vec!["b".to_string()],
            ..default_params()
        };
        let ids = run(channels, params);
        assert_eq!(ids, vec!["a", "c"]);
    }

    #[test]
    fn fas_filter_favorites_group() {
        let channels = vec![
            fch("a", "Alpha", Some(1), Some("G"), true, None),
            fch("b", "Bravo", Some(2), Some("G"), false, None),
            fch("c", "Charlie", Some(3), Some("G"), true, None),
        ];
        let params = FilterSortParams {
            selected_group: Some("\u{2B50} Favorites".to_string()),
            ..default_params()
        };
        let ids = run(channels, params);
        assert_eq!(ids, vec!["a", "c"]);
    }

    #[test]
    fn fas_filter_by_category_group() {
        let channels = vec![
            fch("a", "Alpha", Some(1), Some("News"), false, None),
            fch("b", "Bravo", Some(2), Some("Sports"), false, None),
            fch("c", "Charlie", Some(3), Some("News"), false, None),
        ];
        let params = FilterSortParams {
            selected_group: Some("News".to_string()),
            ..default_params()
        };
        let ids = run(channels, params);
        assert_eq!(ids, vec!["a", "c"]);
    }

    #[test]
    fn fas_filter_by_playlist_group() {
        let channels = vec![
            fch("a", "Alpha", Some(1), Some("G"), false, Some("src1")),
            fch("b", "Bravo", Some(2), Some("G"), false, Some("src2")),
            fch("c", "Charlie", Some(3), Some("G"), false, Some("src1")),
        ];
        let mut source_names = HashMap::new();
        source_names.insert("src1".to_string(), "Source One".to_string());
        source_names.insert("src2".to_string(), "Source Two".to_string());
        let params = FilterSortParams {
            group_mode: "playlist".to_string(),
            selected_group: Some("Source One".to_string()),
            source_names,
            ..default_params()
        };
        let ids = run(channels, params);
        assert_eq!(ids, vec!["a", "c"]);
    }

    #[test]
    fn fas_search_case_insensitive() {
        let channels = vec![
            fch("a", "BBC News", Some(1), Some("News"), false, None),
            fch("b", "CNN Sports", Some(2), Some("Sports"), false, None),
            fch("c", "abc Local", Some(3), Some("Local"), false, None),
        ];
        let params = FilterSortParams {
            search_query: "bbc".to_string(),
            ..default_params()
        };
        let ids = run(channels, params);
        assert_eq!(ids, vec!["a"]);
    }

    #[test]
    fn fas_search_matches_group() {
        let channels = vec![
            fch("a", "Channel A", Some(1), Some("News Extra"), false, None),
            fch("b", "Channel B", Some(2), Some("Sports"), false, None),
        ];
        let params = FilterSortParams {
            search_query: "news".to_string(),
            ..default_params()
        };
        let ids = run(channels, params);
        assert_eq!(ids, vec!["a"]);
    }

    #[test]
    fn fas_sort_by_name() {
        let channels = vec![
            fch("c", "Charlie", Some(3), None, false, None),
            fch("a", "Alpha", Some(1), None, false, None),
            fch("b", "bravo", Some(2), None, false, None),
        ];
        let params = FilterSortParams {
            sort_mode: "name".to_string(),
            ..default_params()
        };
        let ids = run(channels, params);
        assert_eq!(ids, vec!["a", "b", "c"]);
    }

    #[test]
    fn fas_sort_by_date_added() {
        let mut ch_a = fch("a", "Alpha", Some(1), None, false, None);
        let mut ch_b = fch("b", "Bravo", Some(2), None, false, None);
        let mut ch_c = fch("c", "Charlie", Some(3), None, false, None);
        // c added most recently, then b, then a.
        ch_a.added_at = Some(
            chrono::NaiveDateTime::parse_from_str("2024-01-01 00:00:00", "%Y-%m-%d %H:%M:%S")
                .unwrap(),
        );
        ch_b.added_at = Some(
            chrono::NaiveDateTime::parse_from_str("2024-06-01 00:00:00", "%Y-%m-%d %H:%M:%S")
                .unwrap(),
        );
        ch_c.added_at = Some(
            chrono::NaiveDateTime::parse_from_str("2024-12-01 00:00:00", "%Y-%m-%d %H:%M:%S")
                .unwrap(),
        );
        let channels = vec![ch_a, ch_b, ch_c];
        let params = FilterSortParams {
            sort_mode: "dateAdded".to_string(),
            ..default_params()
        };
        let ids = run(channels, params);
        // Most recent first.
        assert_eq!(ids, vec!["c", "b", "a"]);
    }

    #[test]
    fn fas_sort_by_watch_time() {
        let channels = vec![
            fch("a", "Alpha", Some(1), None, false, None),
            fch("b", "Bravo", Some(2), None, false, None),
            fch("c", "Charlie", Some(3), None, false, None),
        ];
        let mut last_watched_map = HashMap::new();
        last_watched_map.insert("a".to_string(), 1_000i64);
        last_watched_map.insert("b".to_string(), 3_000i64);
        // c has no entry → last.
        let params = FilterSortParams {
            sort_mode: "watchTime".to_string(),
            last_watched_map,
            ..default_params()
        };
        let ids = run(channels, params);
        assert_eq!(ids, vec!["b", "a", "c"]);
    }

    #[test]
    fn fas_sort_manual_order() {
        let channels = vec![
            fch("a", "Alpha", Some(1), None, false, None),
            fch("b", "Bravo", Some(2), None, false, None),
            fch("c", "Charlie", Some(3), None, false, None),
        ];
        let mut order_map = HashMap::new();
        order_map.insert("c".to_string(), 0i32);
        order_map.insert("a".to_string(), 1i32);
        order_map.insert("b".to_string(), 2i32);
        let params = FilterSortParams {
            sort_mode: "manual".to_string(),
            custom_order_map: Some(order_map),
            ..default_params()
        };
        let ids = run(channels, params);
        assert_eq!(ids, vec!["c", "a", "b"]);
    }

    #[test]
    fn fas_manual_unordered_items_fallback() {
        // Items not in custom_order_map fall back to default sort.
        let channels = vec![
            fch("a", "Alpha", Some(1), None, false, None),
            fch("b", "Bravo", Some(3), None, false, None),
            fch("c", "Charlie", Some(2), None, false, None),
        ];
        let mut order_map = HashMap::new();
        order_map.insert("c".to_string(), 0i32);
        // a and b are NOT in the map → fallback to default (number asc).
        let params = FilterSortParams {
            sort_mode: "manual".to_string(),
            custom_order_map: Some(order_map),
            ..default_params()
        };
        let ids = run(channels, params);
        // c is ordered first (explicit 0), then a (num=1) then b (num=3).
        assert_eq!(ids, vec!["c", "a", "b"]);
    }

    #[test]
    fn fas_combined_filter_and_sort() {
        let channels = vec![
            fch("a", "Alpha News", Some(3), Some("News"), false, None),
            fch("b", "Bravo Sports", Some(1), Some("Sports"), false, None),
            fch("c", "Charlie News", Some(2), Some("News"), false, None),
        ];
        let params = FilterSortParams {
            selected_group: Some("News".to_string()),
            sort_mode: "name".to_string(),
            ..default_params()
        };
        let ids = run(channels, params);
        assert_eq!(ids, vec!["a", "c"]);
    }

    // ── sort_favorites tests ──────────────────────────

    fn fav_ch(id: &str, name: &str, group: Option<&str>) -> Channel {
        Channel {
            id: id.to_string(),
            name: name.to_string(),
            stream_url: String::new(),
            number: None,
            channel_group: group.map(String::from),
            logo_url: None,
            tvg_id: None,
            tvg_name: None,
            is_favorite: true,
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

    fn run_sort_favorites(channels: Vec<Channel>, mode: &str) -> Vec<String> {
        let json = serde_json::to_string(&channels).unwrap();
        let result = sort_favorites(&json, mode);
        let out: Vec<Channel> = serde_json::from_str(&result).unwrap();
        out.into_iter().map(|c| c.id).collect()
    }

    #[test]
    fn sf_recently_added_preserves_order() {
        let channels = vec![
            fav_ch("c", "Charlie", None),
            fav_ch("a", "Alpha", None),
            fav_ch("b", "Bravo", None),
        ];
        let ids = run_sort_favorites(channels, "recentlyAdded");
        assert_eq!(ids, vec!["c", "a", "b"]);
    }

    #[test]
    fn sf_name_asc() {
        let channels = vec![
            fav_ch("c", "Charlie", None),
            fav_ch("a", "alpha", None),
            fav_ch("b", "Bravo", None),
        ];
        let ids = run_sort_favorites(channels, "nameAsc");
        assert_eq!(ids, vec!["a", "b", "c"]);
    }

    #[test]
    fn sf_name_desc() {
        let channels = vec![
            fav_ch("a", "alpha", None),
            fav_ch("b", "Bravo", None),
            fav_ch("c", "Charlie", None),
        ];
        let ids = run_sort_favorites(channels, "nameDesc");
        assert_eq!(ids, vec!["c", "b", "a"]);
    }

    #[test]
    fn sf_content_type_groups_then_name() {
        let channels = vec![
            fav_ch("a", "Zebra", Some("Sports")),
            fav_ch("b", "Alpha", Some("News")),
            fav_ch("c", "Bravo", Some("News")),
            fav_ch("d", "Mango", Some("Sports")),
        ];
        let ids = run_sort_favorites(channels, "contentType");
        // News group first (alphabetically), then Sports.
        // Within each group alphabetically by name.
        assert_eq!(ids, vec!["b", "c", "d", "a"]);
    }

    #[test]
    fn sf_empty_input() {
        let ids = run_sort_favorites(vec![], "nameAsc");
        assert!(ids.is_empty());
    }
}
