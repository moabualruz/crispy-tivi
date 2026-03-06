use chrono::{DateTime, Utc};

use crate::algorithms::json_utils::parse_json_vec;
use crate::models::VodItem;

use super::parse_rating;

/// Returns `true` if `url` is non-empty and starts with
/// "http" (case-insensitive), matching the Dart
/// `hasValidPoster` predicate in `top10Vod`.
fn has_http_poster(url: Option<&str>) -> bool {
    url.is_some_and(|u| {
        let trimmed = u.trim();
        !trimmed.is_empty() && trimmed.to_ascii_lowercase().starts_with("http")
    })
}

/// Filter and rank top VOD items by rating.
///
/// Keeps items with a non-empty rating AND a valid HTTP
/// poster URL (starts with "http", case-insensitive).
/// Sorts by rating descending and caps at `limit`.
///
/// Falls back to newest items by year descending if
/// fewer than `limit` rated items exist. Fallback items
/// must also have a valid HTTP poster URL.
///
/// Input/output: JSON arrays of `VodItem`.
pub fn filter_top_vod(items_json: &str, limit: usize) -> String {
    let Some(items) = parse_json_vec::<VodItem>(items_json) else {
        return "[]".to_string();
    };

    // Primary: items with rating + HTTP poster URL.
    let mut with_rating: Vec<&VodItem> = items
        .iter()
        .filter(|i| {
            let has_rating = i.rating.as_deref().is_some_and(|r| !r.is_empty());
            let has_poster = has_http_poster(i.poster_url.as_deref());
            has_rating && has_poster
        })
        .collect();

    with_rating.sort_by(|a, b| {
        let ra = parse_rating(a.rating.as_deref());
        let rb = parse_rating(b.rating.as_deref());
        // NaN sorts last (after all real values).
        rb.total_cmp(&ra)
    });

    if with_rating.len() >= limit {
        let top: Vec<&VodItem> = with_rating.into_iter().take(limit).collect();
        return serde_json::to_string(&top).unwrap_or_else(|_| "[]".to_string());
    }

    // Fallback: newest items by year descending,
    // excluding items already in with_rating, and
    // requiring a valid HTTP poster URL.
    let rated_ids: std::collections::HashSet<&str> =
        with_rating.iter().map(|i| i.id.as_str()).collect();
    let mut by_year: Vec<&VodItem> = items
        .iter()
        .filter(|i| {
            i.year.is_some()
                && !rated_ids.contains(i.id.as_str())
                && has_http_poster(i.poster_url.as_deref())
        })
        .collect();
    by_year.sort_by(|a, b| b.year.unwrap_or(0).cmp(&a.year.unwrap_or(0)));
    let remaining = limit.saturating_sub(with_rating.len());
    let mut combined = with_rating;
    combined.extend(by_year.into_iter().take(remaining));

    serde_json::to_string(&combined).unwrap_or_else(|_| "[]".to_string())
}

/// Filter VOD items to those added within the last
/// `cutoff_days` days, then sort newest-first.
///
/// - `items_json`: JSON array of `VodItem`.
/// - `cutoff_days`: number of days to look back.
/// - `now_ms`: current Unix time in milliseconds (UTC).
///
/// Items without `added_at` are excluded. Items whose
/// `added_at` is on or before the cutoff are excluded.
/// Returns a JSON array sorted by `added_at` descending
/// (newest first).
pub fn filter_recently_added(items_json: &str, cutoff_days: u32, now_ms: i64) -> String {
    let Some(items) = parse_json_vec::<VodItem>(items_json) else {
        return "[]".to_string();
    };

    // Cutoff = now - cutoff_days * 86_400_000 ms.
    let cutoff_ms = now_ms.saturating_sub(cutoff_days as i64 * 86_400_000);
    // Convert cutoff ms to NaiveDateTime for comparison.
    let cutoff_secs = cutoff_ms / 1000;
    let cutoff_nanos = ((cutoff_ms % 1000) * 1_000_000) as u32;
    let Some(cutoff_dt) =
        DateTime::from_timestamp(cutoff_secs, cutoff_nanos).map(|dt: DateTime<Utc>| dt.naive_utc())
    else {
        return "[]".to_string();
    };

    let mut recent: Vec<&VodItem> = items
        .iter()
        .filter(|i| i.added_at.as_ref().is_some_and(|dt| dt > &cutoff_dt))
        .collect();

    // Sort newest-first.
    recent.sort_by(|a, b| b.added_at.cmp(&a.added_at));

    serde_json::to_string(&recent).unwrap_or_else(|_| "[]".to_string())
}

/// MPAA/TV content rating levels.
/// 0=G, 1=PG, 2=PG-13, 3=R, 4=NC-17, 5=Unrated
pub fn parse_content_rating(rating: Option<&str>) -> i32 {
    let rating = match rating {
        Some(r) if !r.is_empty() => r,
        _ => return 5, // unrated
    };
    let s = rating.to_uppercase();
    let s = s.trim();

    // NC-17 / TV-MA (most restrictive rated)
    if s.contains("NC-17") || s == "NC17" {
        return 4;
    }
    if s.contains("TV-MA") || s == "TVMA" {
        return 4;
    }

    // R rated
    if s == "R" || s == "RATED R" {
        return 3;
    }

    // PG-13 / TV-14
    if s.contains("PG-13") || s == "PG13" {
        return 2;
    }
    if s.contains("TV-14") || s == "TV14" {
        return 2;
    }

    // PG / TV-PG
    if s == "PG" || s == "RATED PG" {
        return 1;
    }
    if s.contains("TV-PG") || s == "TVPG" {
        return 1;
    }

    // G / TV-G / TV-Y (most permissive)
    if s == "G" || s == "RATED G" {
        return 0;
    }
    if s.contains("TV-G") || s == "TVG" {
        return 0;
    }
    if s.contains("TV-Y") {
        return 0;
    }

    5 // unrated
}

/// Return VOD items in the same category as a given item.
///
/// - `items_json`: JSON array of VOD items (must have `id` and `category`).
/// - `item_id`: the ID of the reference item.
/// - `limit`: maximum number of results to return.
///
/// Finds the item whose `id` matches `item_id`, reads its `category`,
/// then returns up to `limit` other items that share the same non-empty
/// category. The reference item itself is excluded from results.
///
/// Returns `"[]"` if `item_id` is not found, if the item's category is
/// null or empty, or if the JSON cannot be parsed.
#[allow(dead_code)]
pub fn similar_vod_items(items_json: &str, item_id: &str, limit: usize) -> String {
    let Ok(items) = serde_json::from_str::<Vec<serde_json::Value>>(items_json) else {
        return "[]".to_string();
    };

    // Find the reference item's category.
    let category = items
        .iter()
        .find(|v| v.get("id").and_then(|id| id.as_str()) == Some(item_id))
        .and_then(|v| v.get("category"))
        .and_then(|c| c.as_str())
        .map(|s| s.trim())
        .filter(|s| !s.is_empty());

    let Some(category) = category else {
        return "[]".to_string();
    };

    let similar: Vec<&serde_json::Value> = items
        .iter()
        .filter(|v| {
            // Exclude the reference item itself.
            let id = v.get("id").and_then(|id| id.as_str()).unwrap_or("");
            if id == item_id {
                return false;
            }
            // Match on category.
            v.get("category")
                .and_then(|c| c.as_str())
                .map(|c| c.trim())
                .is_some_and(|c| c == category)
        })
        .take(limit)
        .collect();

    serde_json::to_string(&similar).unwrap_or_else(|_| "[]".to_string())
}

/// Resolve a quality label ("4K" or "HD") from a file
/// extension and stream URL, matching the Dart
/// `resolveVodQuality` implementation exactly.
///
/// - Checks `extension` (if `Some`) and `stream_url`
///   after lowercasing both.
/// - Returns `Some("4K")` if either contains "4k" or "uhd".
/// - Returns `Some("HD")` if either contains "hd", "720",
///   or "1080".
/// - Returns `None` otherwise.
pub fn resolve_vod_quality(extension: Option<&str>, stream_url: &str) -> Option<String> {
    let ext_lower = extension.map(|e| e.to_ascii_lowercase());
    let url_lower = stream_url.to_ascii_lowercase();

    let ext = ext_lower.as_deref().unwrap_or("");

    // 4K check takes priority over HD.
    if ext.contains("4k")
        || ext.contains("uhd")
        || url_lower.contains("4k")
        || url_lower.contains("uhd")
    {
        return Some("4K".to_string());
    }

    if ext.contains("hd")
        || ext.contains("720")
        || ext.contains("1080")
        || url_lower.contains("hd")
        || url_lower.contains("720")
        || url_lower.contains("1080")
    {
        return Some("HD".to_string());
    }

    None
}

/// Filter VOD items by content rating.
///
/// Items with rating level <= `max_rating_value` pass.
/// Unrated items (level 5) always pass.
///
/// Rating levels: 0=G, 1=PG, 2=PG-13, 3=R, 4=NC-17,
/// 5=Unrated
pub fn filter_vod_by_content_rating(items_json: &str, max_rating_value: i32) -> String {
    let Some(items) = parse_json_vec::<VodItem>(items_json) else {
        return "[]".to_string();
    };

    let filtered: Vec<&VodItem> = items
        .iter()
        .filter(|item| {
            let level = parse_content_rating(item.rating.as_deref());
            // Unrated always passes; otherwise check level
            level == 5 || level <= max_rating_value
        })
        .collect();

    serde_json::to_string(&filtered).unwrap_or_else(|_| "[]".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_item(id: &str, category: Option<&str>) -> serde_json::Value {
        let mut obj = serde_json::json!({
            "id": id,
            "name": id,
            "stream_url": "",
            "type": "movie",
        });
        if let Some(cat) = category {
            obj["category"] = serde_json::Value::String(cat.to_string());
        } else {
            obj["category"] = serde_json::Value::Null;
        }
        obj
    }

    fn items_json(items: &[serde_json::Value]) -> String {
        serde_json::to_string(items).unwrap()
    }

    #[test]
    fn similar_vod_items_returns_same_category_items() {
        let items = vec![
            make_item("1", Some("Action")),
            make_item("2", Some("Action")),
            make_item("3", Some("Action")),
            make_item("4", Some("Drama")),
        ];
        let result = similar_vod_items(&items_json(&items), "1", 10);
        let parsed: Vec<serde_json::Value> = serde_json::from_str(&result).unwrap();
        let ids: Vec<&str> = parsed.iter().map(|v| v["id"].as_str().unwrap()).collect();
        assert_eq!(ids, vec!["2", "3"]);
    }

    #[test]
    fn similar_vod_items_excludes_reference_item_itself() {
        let items = vec![
            make_item("1", Some("Action")),
            make_item("2", Some("Action")),
        ];
        let result = similar_vod_items(&items_json(&items), "1", 10);
        let parsed: Vec<serde_json::Value> = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed.len(), 1);
        assert_eq!(parsed[0]["id"].as_str().unwrap(), "2");
    }

    #[test]
    fn similar_vod_items_returns_empty_when_item_not_found() {
        let items = vec![make_item("1", Some("Action"))];
        let result = similar_vod_items(&items_json(&items), "999", 10);
        assert_eq!(result, "[]");
    }

    #[test]
    fn similar_vod_items_returns_empty_when_category_is_null() {
        let items = vec![make_item("1", None), make_item("2", Some("Action"))];
        let result = similar_vod_items(&items_json(&items), "1", 10);
        assert_eq!(result, "[]");
    }

    #[test]
    fn similar_vod_items_returns_empty_when_no_items_in_same_category() {
        let items = vec![
            make_item("1", Some("Action")),
            make_item("2", Some("Drama")),
            make_item("3", Some("Comedy")),
        ];
        let result = similar_vod_items(&items_json(&items), "1", 10);
        assert_eq!(result, "[]");
    }

    #[test]
    fn similar_vod_items_respects_limit() {
        let items = vec![
            make_item("1", Some("Action")),
            make_item("2", Some("Action")),
            make_item("3", Some("Action")),
            make_item("4", Some("Action")),
            make_item("5", Some("Action")),
        ];
        let result = similar_vod_items(&items_json(&items), "1", 2);
        let parsed: Vec<serde_json::Value> = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed.len(), 2);
    }

    #[test]
    fn similar_vod_items_returns_empty_for_invalid_json() {
        let result = similar_vod_items("not-json", "1", 10);
        assert_eq!(result, "[]");
    }

    #[test]
    fn similar_vod_items_returns_empty_when_category_is_empty_string() {
        let items = vec![make_item("1", Some("")), make_item("2", Some(""))];
        let result = similar_vod_items(&items_json(&items), "1", 10);
        assert_eq!(result, "[]");
    }
}
