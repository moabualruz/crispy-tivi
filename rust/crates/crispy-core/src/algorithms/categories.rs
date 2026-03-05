//! Category map builder and resolution for Xtream API
//! responses.
//!
//! Ports `_buildCategoryMap` from Dart
//! `refresh_playlist.dart`, plus category resolution
//! helpers for channels and VOD items.

use std::collections::{HashMap, HashSet};

use serde_json::Value;

use crate::models::{Channel, VodItem};

/// Build a category ID to name map from a raw JSON
/// category list.
///
/// Expects each item to contain `category_id` and
/// `category_name` fields. Items missing either field
/// (or with an empty `category_id`) are skipped.
/// Numeric IDs are converted to strings.
pub fn build_category_map(data: &[Value]) -> HashMap<String, String> {
    let mut map = HashMap::new();

    for item in data {
        let Some(obj) = item.as_object() else {
            continue;
        };

        let id = match obj.get("category_id") {
            Some(Value::String(s)) if !s.is_empty() => s.clone(),
            Some(Value::Number(n)) => n.to_string(),
            _ => continue,
        };

        let name = match obj.get("category_name") {
            Some(Value::String(s)) => s.clone(),
            Some(Value::Number(n)) => n.to_string(),
            _ => continue,
        };

        map.insert(id, name);
    }

    map
}

/// Resolve category IDs to names in a list of channels.
///
/// For each channel whose `channel_group` matches a key
/// in `cat_map`, replace the group with the mapped name.
/// Returns a new `Vec` with resolved groups.
pub fn resolve_channel_categories(
    channels: &[Channel],
    cat_map: &HashMap<String, String>,
) -> Vec<Channel> {
    channels
        .iter()
        .map(|ch| {
            let mut c = ch.clone();
            if let Some(ref group) = c.channel_group
                && let Some(name) = cat_map.get(group)
            {
                c.channel_group = Some(name.clone());
            }
            c
        })
        .collect()
}

/// Resolve category IDs to names in a list of VOD items.
///
/// Same logic as [`resolve_channel_categories`] but
/// operates on [`VodItem::category`].
pub fn resolve_vod_categories(
    items: &[VodItem],
    cat_map: &HashMap<String, String>,
) -> Vec<VodItem> {
    items
        .iter()
        .map(|item| {
            let mut v = item.clone();
            if let Some(ref cat) = v.category
                && let Some(name) = cat_map.get(cat)
            {
                v.category = Some(name.clone());
            }
            v
        })
        .collect()
}

/// Returns `true` when the first non-whitespace, non-digit
/// character of `s` falls in the Basic Latin (A-Z / a-z) or
/// Latin Extended (U+00C0–U+024F) ranges.
///
/// Non-Latin scripts (Arabic, Cyrillic, CJK, etc.) return
/// `false`. An empty or all-digit/whitespace string returns
/// `true` (treated as Latin for sorting purposes).
fn is_latin(s: &str) -> bool {
    let first = s
        .chars()
        .find(|c| !c.is_ascii_whitespace() && !c.is_ascii_digit());
    match first {
        None => true,
        Some(c) => {
            let cp = c as u32;
            (0x0041..=0x007A).contains(&cp) || (0x00C0..=0x024F).contains(&cp)
        }
    }
}

/// Extract unique, sorted group names from channels.
///
/// Filters out `None` and empty groups, deduplicates,
/// and returns a sorted `Vec` where non-Latin groups
/// (Arabic, Cyrillic, CJK, etc.) come first, followed
/// by Latin groups. Each bucket is sorted
/// case-insensitively. This matches the Dart reference
/// implementation in `channel_utils.dart`.
pub fn extract_sorted_groups(channels: &[Channel]) -> Vec<String> {
    let set: HashSet<&str> = channels
        .iter()
        .filter_map(|ch| ch.channel_group.as_deref())
        .filter(|g| !g.is_empty())
        .collect();

    let mut non_latin: Vec<String> = set
        .iter()
        .filter(|g| !is_latin(g))
        .map(|g| g.to_string())
        .collect();
    let mut latin: Vec<String> = set
        .iter()
        .filter(|g| is_latin(g))
        .map(|g| g.to_string())
        .collect();

    non_latin.sort_by_key(|a: &String| a.to_lowercase());
    latin.sort_by_key(|a: &String| a.to_lowercase());

    non_latin.extend(latin);
    non_latin
}

/// Extract unique, sorted category names from VOD items.
///
/// Filters out `None` and empty categories, deduplicates,
/// and returns an alphabetically sorted `Vec`.
pub fn extract_sorted_vod_categories(items: &[VodItem]) -> Vec<String> {
    let set: HashSet<&str> = items
        .iter()
        .filter_map(|v| v.category.as_deref())
        .filter(|c| !c.is_empty())
        .collect();
    let mut sorted: Vec<String> = set.into_iter().map(String::from).collect();
    sorted.sort();
    sorted
}

// ── Tests ────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn normal_categories() {
        let data = vec![
            json!({
                "category_id": "1",
                "category_name": "News",
            }),
            json!({
                "category_id": "2",
                "category_name": "Sports",
            }),
        ];
        let map = build_category_map(&data);
        assert_eq!(map.len(), 2);
        assert_eq!(map.get("1").unwrap(), "News");
        assert_eq!(map.get("2").unwrap(), "Sports");
    }

    #[test]
    fn missing_category_id_skipped() {
        let data = vec![json!({
            "category_name": "Orphan",
        })];
        let map = build_category_map(&data);
        assert!(map.is_empty());
    }

    #[test]
    fn missing_category_name_skipped() {
        let data = vec![json!({
            "category_id": "1",
        })];
        let map = build_category_map(&data);
        assert!(map.is_empty());
    }

    #[test]
    fn empty_list_returns_empty_map() {
        let map = build_category_map(&[]);
        assert!(map.is_empty());
    }

    #[test]
    fn numeric_category_id_converted() {
        let data = vec![json!({
            "category_id": 42,
            "category_name": "Sci-Fi",
        })];
        let map = build_category_map(&data);
        assert_eq!(map.len(), 1);
        assert_eq!(map.get("42").unwrap(), "Sci-Fi");
    }

    #[test]
    fn empty_category_id_skipped() {
        let data = vec![json!({
            "category_id": "",
            "category_name": "Empty ID",
        })];
        let map = build_category_map(&data);
        assert!(map.is_empty());
    }

    #[test]
    fn null_values_skipped() {
        let data = vec![
            json!({
                "category_id": null,
                "category_name": "Null ID",
            }),
            json!({
                "category_id": "3",
                "category_name": null,
            }),
        ];
        let map = build_category_map(&data);
        assert!(map.is_empty());
    }

    #[test]
    fn non_object_items_skipped() {
        let data = vec![json!("string"), json!(123), json!(null)];
        let map = build_category_map(&data);
        assert!(map.is_empty());
    }

    #[test]
    fn duplicate_id_last_wins() {
        let data = vec![
            json!({
                "category_id": "1",
                "category_name": "First",
            }),
            json!({
                "category_id": "1",
                "category_name": "Second",
            }),
        ];
        let map = build_category_map(&data);
        assert_eq!(map.len(), 1);
        assert_eq!(map.get("1").unwrap(), "Second");
    }

    // ── resolve_channel_categories ───────────────

    fn make_channel(id: &str, group: Option<&str>) -> Channel {
        Channel {
            id: id.to_string(),
            name: format!("Ch {id}"),
            stream_url: String::new(),
            number: None,
            channel_group: group.map(String::from),
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
        }
    }

    fn make_vod(id: &str, cat: Option<&str>) -> VodItem {
        VodItem {
            id: id.to_string(),
            name: format!("Vod {id}"),
            stream_url: String::new(),
            item_type: "movie".to_string(),
            poster_url: None,
            backdrop_url: None,
            description: None,
            rating: None,
            year: None,
            duration: None,
            category: cat.map(String::from),
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

    #[test]
    fn resolve_channel_categories_basic() {
        let channels = vec![make_channel("a", Some("1")), make_channel("b", Some("2"))];
        let mut cat_map = HashMap::new();
        cat_map.insert("1".to_string(), "News".to_string());
        cat_map.insert("2".to_string(), "Sports".to_string());

        let resolved = resolve_channel_categories(&channels, &cat_map);
        assert_eq!(resolved[0].channel_group.as_deref(), Some("News"),);
        assert_eq!(resolved[1].channel_group.as_deref(), Some("Sports"),);
    }

    #[test]
    fn resolve_channel_categories_missing_key_unchanged() {
        let channels = vec![make_channel("a", Some("999"))];
        let cat_map = HashMap::new();

        let resolved = resolve_channel_categories(&channels, &cat_map);
        assert_eq!(resolved[0].channel_group.as_deref(), Some("999"),);
    }

    #[test]
    fn resolve_vod_categories_basic() {
        let items = vec![make_vod("a", Some("10")), make_vod("b", Some("20"))];
        let mut cat_map = HashMap::new();
        cat_map.insert("10".to_string(), "Action".to_string());
        cat_map.insert("20".to_string(), "Comedy".to_string());

        let resolved = resolve_vod_categories(&items, &cat_map);
        assert_eq!(resolved[0].category.as_deref(), Some("Action"),);
        assert_eq!(resolved[1].category.as_deref(), Some("Comedy"),);
    }

    #[test]
    fn resolve_vod_categories_missing_key_unchanged() {
        let items = vec![make_vod("a", Some("99"))];
        let cat_map = HashMap::new();

        let resolved = resolve_vod_categories(&items, &cat_map);
        assert_eq!(resolved[0].category.as_deref(), Some("99"),);
    }

    // ── extract_sorted_groups ────────────────────

    #[test]
    fn extract_sorted_groups_empty() {
        let channels: Vec<Channel> = vec![];
        let groups = extract_sorted_groups(&channels);
        assert!(groups.is_empty());
    }

    #[test]
    fn extract_sorted_groups_dedup_and_sort() {
        let channels = vec![
            make_channel("a", Some("Sports")),
            make_channel("b", Some("News")),
            make_channel("c", Some("Sports")),
            make_channel("d", None),
            make_channel("e", Some("")),
        ];
        let groups = extract_sorted_groups(&channels);
        assert_eq!(groups, vec!["News", "Sports"]);
    }

    #[test]
    fn extract_sorted_groups_arabic_before_latin() {
        let channels = vec![
            make_channel("a", Some("Sports")),
            make_channel("b", Some("أخبار")),
            make_channel("c", Some("News")),
            make_channel("d", Some("ترفيه")),
        ];
        let groups = extract_sorted_groups(&channels);
        // Non-Latin (Arabic) groups first, then Latin groups.
        assert_eq!(groups.len(), 4);
        // First two must be Arabic groups.
        assert!(
            !is_latin(&groups[0]),
            "expected non-Latin first, got: {}",
            groups[0]
        );
        assert!(
            !is_latin(&groups[1]),
            "expected non-Latin second, got: {}",
            groups[1]
        );
        // Last two must be Latin groups.
        assert!(
            is_latin(&groups[2]),
            "expected Latin third, got: {}",
            groups[2]
        );
        assert!(
            is_latin(&groups[3]),
            "expected Latin fourth, got: {}",
            groups[3]
        );
        // Verify specific ordering within each bucket.
        assert_eq!(groups[2], "News");
        assert_eq!(groups[3], "Sports");
    }

    // ── extract_sorted_vod_categories ────────────

    #[test]
    fn extract_sorted_vod_categories_empty() {
        let items: Vec<VodItem> = vec![];
        let cats = extract_sorted_vod_categories(&items);
        assert!(cats.is_empty());
    }

    #[test]
    fn extract_sorted_vod_categories_dedup_and_sort() {
        let items = vec![
            make_vod("a", Some("Comedy")),
            make_vod("b", Some("Action")),
            make_vod("c", Some("Comedy")),
            make_vod("d", None),
            make_vod("e", Some("")),
        ];
        let cats = extract_sorted_vod_categories(&items);
        assert_eq!(cats, vec!["Action", "Comedy"]);
    }
}
