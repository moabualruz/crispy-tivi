//! Watch history merge and deduplication.

use crate::algorithms::json_utils::parse_json_vec;
use crate::models::WatchHistory;

/// Merges two `WatchHistory` JSON arrays, deduplicates by `id` (first
/// occurrence wins), and sorts by `last_watched` descending.
///
/// Ports `mergeDedupSort` from Dart
/// `lib/features/favorites/domain/utils/cw_filter_utils.dart` (lines 15-29).
///
/// Returns a JSON array.
pub fn merge_dedup_sort_history(a_json: &str, b_json: &str) -> String {
    let a: Vec<WatchHistory> = parse_json_vec(a_json).unwrap_or_default();
    let b: Vec<WatchHistory> = parse_json_vec(b_json).unwrap_or_default();

    let mut combined: Vec<WatchHistory> = Vec::with_capacity(a.len() + b.len());
    combined.extend(a);
    combined.extend(b);

    // Deduplicate by id — first occurrence wins.
    let mut seen: std::collections::HashSet<String> = std::collections::HashSet::new();
    combined.retain(|e| seen.insert(e.id.clone()));

    // Sort by last_watched descending.
    combined.sort_by(|x, y| y.last_watched.cmp(&x.last_watched));

    serde_json::to_string(&combined).unwrap_or_else(|_| "[]".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Build a `WatchHistory`-compatible JSON object.
    ///
    /// `last_watched` must be in `%Y-%m-%dT%H:%M:%S` format (chrono serde).
    fn make_wh_json(id: &str, last_watched: &str, position_ms: i64) -> serde_json::Value {
        serde_json::json!({
            "id": id,
            "media_type": "movie",
            "name": format!("Item {}", id),
            "stream_url": format!("http://example.com/{}", id),
            "position_ms": position_ms,
            "duration_ms": 10000i64,
            "last_watched": last_watched,
        })
    }

    #[test]
    fn merge_dedup_removes_duplicates() {
        let a =
            serde_json::to_string(&vec![make_wh_json("1", "2024-03-01T10:00:00", 5000)]).unwrap();
        let b = serde_json::to_string(&vec![
            make_wh_json("1", "2024-03-02T10:00:00", 6000),
            make_wh_json("2", "2024-03-01T10:00:00", 5000),
        ])
        .unwrap();

        let result = merge_dedup_sort_history(&a, &b);
        let parsed: Vec<serde_json::Value> = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed.len(), 2);
        // id "1" from list `a` wins (first occurrence); position_ms = 5000
        let id1 = parsed.iter().find(|v| v["id"] == "1").unwrap();
        assert_eq!(id1["position_ms"], 5000);
    }

    #[test]
    fn merge_dedup_sort_order() {
        let a = serde_json::to_string(&vec![
            make_wh_json("1", "2024-01-01T10:00:00", 1000),
            make_wh_json("2", "2024-03-01T10:00:00", 2000),
        ])
        .unwrap();
        let b =
            serde_json::to_string(&vec![make_wh_json("3", "2024-02-01T10:00:00", 3000)]).unwrap();

        let result = merge_dedup_sort_history(&a, &b);
        let parsed: Vec<serde_json::Value> = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed.len(), 3);
        assert_eq!(parsed[0]["id"], "2");
        assert_eq!(parsed[1]["id"], "3");
        assert_eq!(parsed[2]["id"], "1");
    }

    #[test]
    fn merge_dedup_one_empty_list() {
        let a =
            serde_json::to_string(&vec![make_wh_json("1", "2024-03-01T10:00:00", 5000)]).unwrap();

        let result = merge_dedup_sort_history(&a, "[]");
        let parsed: Vec<serde_json::Value> = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed.len(), 1);

        let result2 = merge_dedup_sort_history("[]", &a);
        let parsed2: Vec<serde_json::Value> = serde_json::from_str(&result2).unwrap();
        assert_eq!(parsed2.len(), 1);
    }

    #[test]
    fn merge_dedup_both_empty() {
        let result = merge_dedup_sort_history("[]", "[]");
        let parsed: Vec<serde_json::Value> = serde_json::from_str(&result).unwrap();
        assert!(parsed.is_empty());
    }
}
