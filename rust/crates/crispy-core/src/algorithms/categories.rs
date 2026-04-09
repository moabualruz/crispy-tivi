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
                if v.genre.as_deref().is_none_or(str::is_empty) {
                    v.genre = Some(name.clone());
                }
            }
            v
        })
        .collect()
}

/// Returns `true` when `c` is in an Arabic / Persian / Urdu
/// Unicode block.
fn is_arabic_script(c: char) -> bool {
    let cp = c as u32;
    (0x0600..=0x06FF).contains(&cp) // Arabic (includes Persian, Urdu)
        || (0x0750..=0x077F).contains(&cp) // Arabic Supplement
        || (0x08A0..=0x08FF).contains(&cp) // Arabic Extended-A
        || (0xFB50..=0xFDFF).contains(&cp) // Arabic Presentation Forms-A
        || (0xFE70..=0xFEFF).contains(&cp) // Arabic Presentation Forms-B
}

/// Returns `true` when `c` is in a Latin Unicode block.
fn is_latin_char(c: char) -> bool {
    let cp = c as u32;
    (0x0041..=0x007A).contains(&cp) // Basic Latin (A-Z, a-z)
        || (0x00C0..=0x024F).contains(&cp) // Latin Extended-A/B
        || (0x1E00..=0x1EFF).contains(&cp) // Latin Extended Additional
}

/// Assigns a sort priority bucket based on the first
/// significant character of a category/group name:
///
/// * `0` — Arabic / Persian / Urdu scripts
/// * `1` — Symbols, punctuation, digits-only
/// * `2` — Latin scripts (English, German, French, etc.)
/// * `3` — All other scripts (Cyrillic, CJK, Devanagari…)
///
/// Each bucket is then sorted case-insensitively.
fn group_sort_bucket(s: &str) -> u8 {
    let first = s
        .chars()
        .find(|c| !c.is_ascii_whitespace() && !c.is_ascii_digit());
    match first {
        None => 1, // All digits/whitespace → symbols bucket
        Some(c) => {
            if is_arabic_script(c) {
                0
            } else if is_latin_char(c) {
                2
            } else if c.is_alphabetic() {
                3 // Other scripts (Cyrillic, CJK, etc.)
            } else {
                1 // Symbols / punctuation
            }
        }
    }
}

/// Sorts category names in-place using the standard bucket
/// ordering: Arabic/Persian/Urdu → Symbols → Latin → Other.
/// Each bucket is sorted case-insensitively.
fn sort_categories(categories: &mut [String]) {
    categories.sort_by(|a, b| {
        let ba = group_sort_bucket(a);
        let bb = group_sort_bucket(b);
        ba.cmp(&bb)
            .then_with(|| a.to_lowercase().cmp(&b.to_lowercase()))
    });
}

/// Same as [`sort_categories`] but for borrowed string slices.
fn sort_categories_ref(categories: &mut [&String]) {
    categories.sort_by(|a, b| {
        let ba = group_sort_bucket(a);
        let bb = group_sort_bucket(b);
        ba.cmp(&bb)
            .then_with(|| a.to_lowercase().cmp(&b.to_lowercase()))
    });
}

/// Extract unique, sorted group names from channels.
///
/// Filters out `None` and empty groups, deduplicates,
/// and returns a sorted `Vec` ordered by script bucket:
/// Arabic/Persian/Urdu → Symbols → Latin → Other.
/// Each bucket is sorted case-insensitively.
pub fn extract_sorted_groups(channels: &[Channel]) -> Vec<String> {
    let set: HashSet<&str> = channels
        .iter()
        .filter_map(|ch| ch.channel_group.as_deref())
        .filter(|g| !g.is_empty())
        .collect();

    let mut groups: Vec<String> = set.into_iter().map(String::from).collect();
    sort_categories(&mut groups);
    groups
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
    sort_categories(&mut sorted);
    sorted
}

// ── sort_categories_with_favorites ───────────────

/// Sort categories with favourites first.
///
/// Ports `sortCategoriesWithFavorites()` from
/// `favorite_categories_provider.dart`.
///
/// Favourite categories (those present in
/// `favorites_json`) are sorted alphabetically and
/// placed before non-favourites, which are also
/// sorted alphabetically.
///
/// # Arguments
/// * `categories_json` – JSON array of `String`.
/// * `favorites_json`  – JSON array of favourite
///   category name strings.
///
/// # Returns
/// JSON array of `String`.  Returns `"[]"` on parse
/// error.
pub fn sort_categories_with_favorites(categories_json: &str, favorites_json: &str) -> String {
    let categories: Vec<String> = match serde_json::from_str(categories_json) {
        Ok(v) => v,
        Err(_) => return "[]".to_string(),
    };
    let favorites: HashSet<String> = match serde_json::from_str::<Vec<String>>(favorites_json) {
        Ok(v) => v.into_iter().collect(),
        Err(_) => return "[]".to_string(),
    };

    let mut favs: Vec<&String> = categories
        .iter()
        .filter(|c| favorites.contains(*c))
        .collect();
    let mut rest: Vec<&String> = categories
        .iter()
        .filter(|c| !favorites.contains(*c))
        .collect();

    sort_categories_ref(&mut favs);
    sort_categories_ref(&mut rest);

    let mut result: Vec<&String> = favs;
    result.extend(rest);

    serde_json::to_string(&result).unwrap_or_else(|_| "[]".to_string())
}

// ── build_type_categories ─────────────────────────

/// Extract unique categories from VOD items
/// filtered by type.
///
/// Filters `items_json` by `item_type == vod_type`,
/// collects unique non-empty categories, sorts them
/// alphabetically, and returns a JSON array.
///
/// # Arguments
/// * `items_json` – JSON array of [`VodItem`].
/// * `vod_type`   – Type to filter by (e.g.
///   `"movie"`, `"series"`).
///
/// # Returns
/// JSON array of `String`.  Returns `"[]"` on parse
/// error.
pub fn build_type_categories(items_json: &str, vod_type: &str) -> String {
    let items: Vec<VodItem> = match serde_json::from_str(items_json) {
        Ok(v) => v,
        Err(_) => return "[]".to_string(),
    };

    let set: HashSet<&str> = items
        .iter()
        .filter(|v| v.item_type.as_str() == vod_type)
        .filter_map(|v| v.category.as_deref())
        .filter(|c| !c.is_empty())
        .collect();

    let mut sorted: Vec<String> = set.into_iter().map(String::from).collect();
    sort_categories(&mut sorted);

    serde_json::to_string(&sorted).unwrap_or_else(|_| "[]".to_string())
}

// ── build_search_categories ───────────────────────

/// Merge VOD categories and channel groups into a single
/// deduplicated, sorted list.
///
/// * `vod_categories_json` — JSON array of nullable strings
/// * `channel_groups_json` — JSON array of strings
///
/// Returns a sorted JSON array of unique non-empty strings.
pub fn build_search_categories(vod_categories_json: &str, channel_groups_json: &str) -> String {
    let vod_cats: Vec<Option<String>> =
        serde_json::from_str(vod_categories_json).unwrap_or_default();
    let groups: Vec<String> = serde_json::from_str(channel_groups_json).unwrap_or_default();

    let mut set = HashSet::new();

    for c in vod_cats.iter().flatten() {
        let trimmed = c.trim();
        if !trimmed.is_empty() {
            set.insert(trimmed.to_string());
        }
    }

    for group in &groups {
        let trimmed = group.trim();
        if !trimmed.is_empty() {
            set.insert(trimmed.to_string());
        }
    }

    let mut sorted: Vec<String> = set.into_iter().collect();
    sort_categories(&mut sorted);

    serde_json::to_string(&sorted).unwrap_or_else(|_| "[]".to_string())
}

// ── Tests ────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::value_objects::MediaType;
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

    fn make_vod(id: &str, cat: Option<&str>) -> VodItem {
        VodItem {
            id: id.to_string(),
            native_id: id.to_string(),
            name: format!("Vod {id}"),
            stream_url: String::new(),
            item_type: MediaType::Movie,
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
        // Bucket order: Arabic → Symbols → Latin → Other.
        // Arabic first (أخبار, ترفيه), then Latin (News, Sports).
        assert_eq!(groups.len(), 4);
        assert_eq!(group_sort_bucket(&groups[0]), 0, "expected Arabic first");
        assert_eq!(group_sort_bucket(&groups[1]), 0, "expected Arabic second");
        assert_eq!(group_sort_bucket(&groups[2]), 2, "expected Latin third");
        assert_eq!(group_sort_bucket(&groups[3]), 2, "expected Latin fourth");
        assert_eq!(groups[2], "News");
        assert_eq!(groups[3], "Sports");
    }

    #[test]
    fn extract_sorted_groups_full_bucket_order() {
        let channels = vec![
            make_channel("a", Some("News")),
            make_channel("b", Some("أخبار")),
            make_channel("c", Some("*** Special ***")),
            make_channel("d", Some("Новости")),
            make_channel("e", Some("فارسی")),
            make_channel("f", Some("123")),
        ];
        let groups = extract_sorted_groups(&channels);
        // Arabic (أخبار, فارسی) → Symbols (*** Special ***, 123) → Latin (News) → Other (Новости)
        assert_eq!(groups.len(), 6);
        assert_eq!(group_sort_bucket(&groups[0]), 0);
        assert_eq!(group_sort_bucket(&groups[1]), 0);
        assert_eq!(group_sort_bucket(&groups[2]), 1);
        assert_eq!(group_sort_bucket(&groups[3]), 1);
        assert_eq!(group_sort_bucket(&groups[4]), 2);
        assert_eq!(group_sort_bucket(&groups[5]), 3);
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

    // ── sort_categories_with_favorites ───────────

    fn run_sort_cats(categories: Vec<&str>, favorites: Vec<&str>) -> Vec<String> {
        let cats_json =
            serde_json::to_string(&categories.iter().map(|s| s.to_string()).collect::<Vec<_>>())
                .unwrap();
        let favs_json =
            serde_json::to_string(&favorites.iter().map(|s| s.to_string()).collect::<Vec<_>>())
                .unwrap();
        let result = sort_categories_with_favorites(&cats_json, &favs_json);
        serde_json::from_str(&result).unwrap()
    }

    #[test]
    fn scwf_favorites_first_with_bucket_order() {
        let result = run_sort_cats(
            vec!["Zoning", "Action", "Comedy", "Drama"],
            vec!["Zoning", "Comedy"],
        );
        // Favs bucket-sorted first, then rest bucket-sorted.
        // All Latin → bucket 2, so case-insensitive alpha within.
        assert_eq!(result, vec!["Comedy", "Zoning", "Action", "Drama"]);
    }

    #[test]
    fn scwf_no_favorites() {
        let result = run_sort_cats(vec!["Zoning", "Action", "Comedy"], vec![]);
        assert_eq!(result, vec!["Action", "Comedy", "Zoning"]);
    }

    #[test]
    fn scwf_all_favorites() {
        let result = run_sort_cats(
            vec!["Zoning", "Action", "Comedy"],
            vec!["Zoning", "Action", "Comedy"],
        );
        assert_eq!(result, vec!["Action", "Comedy", "Zoning"]);
    }

    #[test]
    fn scwf_mixed_scripts_with_favorites() {
        let result = run_sort_cats(
            vec!["Sports", "أخبار", "News", "ترفيه"],
            vec!["News", "أخبار"],
        );
        // Favs: أخبار (Arabic/0) then News (Latin/2).
        // Rest: ترفيه (Arabic/0) then Sports (Latin/2).
        assert_eq!(result, vec!["أخبار", "News", "ترفيه", "Sports"]);
    }

    #[test]
    fn scwf_empty_input() {
        let result = run_sort_cats(vec![], vec![]);
        assert!(result.is_empty());
    }

    // ── build_type_categories ─────────────────────

    fn make_typed_vod(id: &str, cat: Option<&str>, vod_type: &str) -> VodItem {
        VodItem {
            id: id.to_string(),
            native_id: id.to_string(),
            name: format!("Item {id}"),
            stream_url: String::new(),
            item_type: vod_type.try_into().unwrap_or_default(),
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

    fn run_build_type_cats(items: Vec<VodItem>, vod_type: &str) -> Vec<String> {
        let json = serde_json::to_string(&items).unwrap();
        let result = build_type_categories(&json, vod_type);
        serde_json::from_str(&result).unwrap()
    }

    #[test]
    fn btc_filters_by_type_and_sorts() {
        let items = vec![
            make_typed_vod("a", Some("Comedy"), "movie"),
            make_typed_vod("b", Some("Action"), "series"),
            make_typed_vod("c", Some("Drama"), "movie"),
            make_typed_vod("d", Some("Comedy"), "movie"),
        ];
        let cats = run_build_type_cats(items, "movie");
        assert_eq!(cats, vec!["Comedy", "Drama"]);
    }

    #[test]
    fn btc_no_match_returns_empty() {
        let items = vec![
            make_typed_vod("a", Some("Comedy"), "movie"),
            make_typed_vod("b", Some("Action"), "movie"),
        ];
        let cats = run_build_type_cats(items, "series");
        assert!(cats.is_empty());
    }

    #[test]
    fn btc_deduplicates_categories() {
        let items = vec![
            make_typed_vod("a", Some("Action"), "movie"),
            make_typed_vod("b", Some("Action"), "movie"),
            make_typed_vod("c", Some("action"), "movie"),
        ];
        let cats = run_build_type_cats(items, "movie");
        // Exact string dedup — "Action" and "action" are distinct.
        // Both are Latin bucket → case-insensitive sort groups them.
        assert_eq!(cats.len(), 2);
        assert!(cats.contains(&"Action".to_string()));
        assert!(cats.contains(&"action".to_string()));
    }

    #[test]
    fn btc_skips_none_and_empty_categories() {
        let items = vec![
            make_typed_vod("a", None, "movie"),
            make_typed_vod("b", Some(""), "movie"),
            make_typed_vod("c", Some("Drama"), "movie"),
        ];
        let cats = run_build_type_cats(items, "movie");
        assert_eq!(cats, vec!["Drama"]);
    }

    // ── build_search_categories ─────────────────────

    fn run_build_search_cats(
        vod_cats: Vec<Option<&str>>,
        channel_groups: Vec<&str>,
    ) -> Vec<String> {
        let vod_json = serde_json::to_string(
            &vod_cats
                .into_iter()
                .map(|c| c.map(String::from))
                .collect::<Vec<_>>(),
        )
        .unwrap();
        let groups_json = serde_json::to_string(
            &channel_groups
                .into_iter()
                .map(String::from)
                .collect::<Vec<_>>(),
        )
        .unwrap();
        let result = build_search_categories(&vod_json, &groups_json);
        serde_json::from_str(&result).unwrap()
    }

    #[test]
    fn bsc_merges_and_deduplicates() {
        let result = run_build_search_cats(
            vec![Some("Action"), Some("Drama"), Some("Action")],
            vec!["Sports", "Drama", "News"],
        );
        // All Latin → bucket 2, case-insensitive alpha.
        assert_eq!(result, vec!["Action", "Drama", "News", "Sports"]);
    }

    #[test]
    fn bsc_skips_null_and_empty() {
        let result = run_build_search_cats(vec![None, Some(""), Some("Action")], vec!["", "News"]);
        assert_eq!(result, vec!["Action", "News"]);
    }

    #[test]
    fn bsc_both_empty_returns_empty() {
        let result = run_build_search_cats(vec![], vec![]);
        assert!(result.is_empty());
    }

    #[test]
    fn bsc_only_vod_categories() {
        let result = run_build_search_cats(vec![Some("Comedy"), Some("Drama")], vec![]);
        assert_eq!(result, vec!["Comedy", "Drama"]);
    }

    #[test]
    fn bsc_only_channel_groups() {
        let result = run_build_search_cats(vec![], vec!["Sports", "News"]);
        assert_eq!(result, vec!["News", "Sports"]);
    }
}
