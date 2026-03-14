//! EPG window merging and upcoming program filtering.

/// Filter upcoming programs on favorite channels within a time window.
///
/// For each favorite channel, resolves its EPG key (`tvg_id` if present, else `id`),
/// then looks up entries in `epg_map_json`. Programs whose `startTime` is strictly
/// after `now_ms` and strictly before `now_ms + window_minutes * 60_000` are included.
///
/// Results are sorted by `startTime` ascending, capped at `limit`.
///
/// * `epg_map_json`   — JSON object `{ "channelKey": [{ "title", "startTime" (ms),
///   "endTime" (ms), ... }] }`
/// * `favorites_json` — JSON array of channel objects with `id`, `tvg_id`, `name`,
///   `stream_url`, `logo_url`.
/// * `now_ms`         — current time as epoch-ms.
/// * `window_minutes` — how many minutes ahead to look (default 120).
/// * `limit`          — maximum results to return (default 20).
///
/// Returns JSON array of `{ channel_id, channel_name, logo_url, stream_url, title,
///   start_time, end_time, description, category }`.
pub fn filter_upcoming_programs(
    epg_map_json: &str,
    favorites_json: &str,
    now_ms: i64,
    window_minutes: u32,
    limit: usize,
) -> String {
    use serde_json::Value;

    let epg_map: serde_json::Map<String, Value> = serde_json::from_str::<Value>(epg_map_json)
        .ok()
        .and_then(|v| {
            if let Value::Object(m) = v {
                Some(m)
            } else {
                None
            }
        })
        .unwrap_or_default();

    let favorites: Vec<Value> = serde_json::from_str::<Value>(favorites_json)
        .ok()
        .and_then(|v| {
            if let Value::Array(a) = v {
                Some(a)
            } else {
                None
            }
        })
        .unwrap_or_default();

    let cutoff_ms = now_ms + (window_minutes as i64) * 60_000;
    let mut results: Vec<Value> = Vec::new();

    for ch in &favorites {
        let ch_id = ch.get("id").and_then(|v| v.as_str()).unwrap_or("");
        let tvg_id = ch
            .get("tvg_id")
            .and_then(|v| v.as_str())
            .filter(|s| !s.is_empty());
        let epg_key = tvg_id.unwrap_or(ch_id);

        let entries = match epg_map.get(epg_key).and_then(|v| v.as_array()) {
            Some(arr) => arr,
            None => continue,
        };

        let ch_name = ch.get("name").and_then(|v| v.as_str()).unwrap_or("");
        let logo_url = ch.get("logo_url").and_then(|v| v.as_str());
        let stream_url = ch.get("stream_url").and_then(|v| v.as_str()).unwrap_or("");

        for entry in entries {
            let start = entry.get("startTime").and_then(|v| v.as_i64()).unwrap_or(0);
            if start > now_ms && start < cutoff_ms {
                let mut result = serde_json::json!({
                    "channel_id": ch_id,
                    "channel_name": ch_name,
                    "stream_url": stream_url,
                    "title": entry.get("title").and_then(|v| v.as_str()).unwrap_or(""),
                    "start_time": start,
                    "end_time": entry.get("endTime").and_then(|v| v.as_i64()).unwrap_or(0),
                });
                if let Some(url) = logo_url {
                    result["logo_url"] = Value::String(url.to_string());
                }
                if let Some(desc) = entry.get("description").and_then(|v| v.as_str()) {
                    result["description"] = Value::String(desc.to_string());
                }
                if let Some(cat) = entry.get("category").and_then(|v| v.as_str()) {
                    result["category"] = Value::String(cat.to_string());
                }
                results.push(result);
            }
        }
    }

    // Sort by start_time ascending.
    results.sort_by_key(|r| r.get("start_time").and_then(|v| v.as_i64()).unwrap_or(0));
    results.truncate(limit);

    serde_json::to_string(&results).unwrap_or_else(|_| "[]".to_string())
}

/// Remove overlapping EPG entries from a sorted list.
///
/// For each candidate entry, checks overlap against all already-accepted
/// entries. If the overlap exceeds 50% of the candidate's duration, the
/// candidate is dropped. The first entry always survives (existing entries
/// appear first after a stable sort, giving them priority).
fn dedup_overlapping_entries(sorted: Vec<serde_json::Value>) -> Vec<serde_json::Value> {
    let mut accepted: Vec<serde_json::Value> = Vec::with_capacity(sorted.len());

    for entry in sorted {
        let start = entry
            .get("startTime")
            .and_then(serde_json::Value::as_i64)
            .unwrap_or(0);
        let end = entry
            .get("endTime")
            .and_then(serde_json::Value::as_i64)
            .unwrap_or(start);
        let duration = end - start;

        // Zero-duration or negative entries: keep unconditionally.
        if duration <= 0 {
            accepted.push(entry);
            continue;
        }

        // Check against accepted entries for >50% overlap.
        let dominated = accepted.iter().any(|u| {
            let u_start = u
                .get("startTime")
                .and_then(serde_json::Value::as_i64)
                .unwrap_or(0);
            let u_end = u
                .get("endTime")
                .and_then(serde_json::Value::as_i64)
                .unwrap_or(u_start);
            let overlap_start = start.max(u_start);
            let overlap_end = end.min(u_end);
            let overlap_ms = overlap_end - overlap_start;
            overlap_ms > 0 && overlap_ms > duration / 2
        });

        if !dominated {
            accepted.push(entry);
        }
    }

    accepted
}

/// Merges new EPG entries into existing entries, deduplicating by `startTime`.
///
/// Both inputs are JSON objects:
/// `{ "channelId": [ { "startTime": epochMs, ... }, ... ] }`
///
/// For each channel:
/// - Keep all existing entries.
/// - Add new entries whose `startTime` is not already present in existing.
/// - Sort merged list by `startTime` ascending.
///
/// Returns the merged JSON object. Invalid JSON inputs return `"{}"`.
pub fn merge_epg_window(existing_json: &str, new_json: &str) -> String {
    use serde_json::{Map, Value};

    let parse = |s: &str| -> Map<String, Value> {
        serde_json::from_str::<Value>(s)
            .ok()
            .and_then(|v| {
                if let Value::Object(m) = v {
                    Some(m)
                } else {
                    None
                }
            })
            .unwrap_or_default()
    };

    let existing = parse(existing_json);
    let new = parse(new_json);

    // Collect all channel keys from both maps.
    let all_keys: std::collections::BTreeSet<String> =
        existing.keys().chain(new.keys()).cloned().collect();

    let mut result = Map::new();

    for key in all_keys {
        let existing_entries = existing
            .get(&key)
            .and_then(Value::as_array)
            .map(Vec::as_slice)
            .unwrap_or(&[]);
        let new_entries = new
            .get(&key)
            .and_then(Value::as_array)
            .map(Vec::as_slice)
            .unwrap_or(&[]);

        // Collect existing startTime values as a set.
        let existing_starts: std::collections::HashSet<i64> = existing_entries
            .iter()
            .filter_map(|e| e.get("startTime").and_then(Value::as_i64))
            .collect();

        // Start with all existing entries.
        let mut merged: Vec<Value> = existing_entries.to_vec();

        // Append new entries that aren't already present.
        for entry in new_entries {
            let start = entry.get("startTime").and_then(Value::as_i64);
            let is_dup = start.is_some_and(|s| existing_starts.contains(&s));
            if !is_dup {
                merged.push(entry.clone());
            }
        }

        // Sort by startTime ascending (stable — existing entries precede
        // new entries at the same startTime since they were appended first).
        merged.sort_by_key(|e| e.get("startTime").and_then(Value::as_i64).unwrap_or(0));

        // Overlap dedup: sweep through sorted entries and remove any entry
        // whose duration overlaps > 50% with an already-accepted entry.
        // Existing entries have priority because they appear first.
        let deduped = dedup_overlapping_entries(merged);

        result.insert(key, Value::Array(deduped));
    }

    serde_json::to_string(&Value::Object(result)).unwrap_or_else(|_| "{}".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── merge_epg_window ────────────────────────────

    #[test]
    fn merge_epg_window_empty_existing_returns_new() {
        let existing = "{}";
        let new = r#"{"ch1": [{"startTime": 1000, "title": "News"}]}"#;
        let merged = merge_epg_window(existing, new);
        let v: serde_json::Value = serde_json::from_str(&merged).unwrap();
        let ch1 = v.get("ch1").and_then(|v| v.as_array()).unwrap();
        assert_eq!(ch1.len(), 1);
        assert_eq!(ch1[0].get("startTime").and_then(|v| v.as_i64()), Some(1000),);
    }

    #[test]
    fn merge_epg_window_non_empty_existing_empty_new_returns_existing() {
        let existing = r#"{"ch1": [{"startTime": 2000, "title": "Sports"}]}"#;
        let new = "{}";
        let merged = merge_epg_window(existing, new);
        let v: serde_json::Value = serde_json::from_str(&merged).unwrap();
        let ch1 = v.get("ch1").and_then(|v| v.as_array()).unwrap();
        assert_eq!(ch1.len(), 1);
        assert_eq!(ch1[0].get("title").and_then(|v| v.as_str()), Some("Sports"),);
    }

    #[test]
    fn merge_epg_window_both_empty_returns_empty_object() {
        let merged = merge_epg_window("{}", "{}");
        let v: serde_json::Value = serde_json::from_str(&merged).unwrap();
        assert!(v.as_object().unwrap().is_empty());
    }

    #[test]
    fn merge_epg_window_same_channel_deduped_by_start_time() {
        let existing = r#"{"ch1": [
            {"startTime": 1000, "title": "A"},
            {"startTime": 2000, "title": "B"}
        ]}"#;
        let new = r#"{"ch1": [
            {"startTime": 2000, "title": "B_dup"},
            {"startTime": 3000, "title": "C"}
        ]}"#;
        let merged = merge_epg_window(existing, new);
        let v: serde_json::Value = serde_json::from_str(&merged).unwrap();
        let ch1 = v.get("ch1").and_then(|v| v.as_array()).unwrap();
        assert_eq!(ch1.len(), 3);
        let titles: Vec<&str> = ch1
            .iter()
            .filter_map(|e| e.get("title").and_then(|v| v.as_str()))
            .collect();
        assert!(titles.contains(&"B"));
        assert!(!titles.contains(&"B_dup"));
    }

    #[test]
    fn merge_epg_window_non_overlapping_all_included_sorted() {
        let existing = r#"{"ch1": [
            {"startTime": 3000, "title": "C"},
            {"startTime": 1000, "title": "A"}
        ]}"#;
        let new = r#"{"ch1": [
            {"startTime": 2000, "title": "B"}
        ]}"#;
        let merged = merge_epg_window(existing, new);
        let v: serde_json::Value = serde_json::from_str(&merged).unwrap();
        let ch1 = v.get("ch1").and_then(|v| v.as_array()).unwrap();
        assert_eq!(ch1.len(), 3);
        let starts: Vec<i64> = ch1
            .iter()
            .filter_map(|e| e.get("startTime").and_then(|v| v.as_i64()))
            .collect();
        assert_eq!(starts, vec![1000, 2000, 3000]);
    }

    #[test]
    fn merge_epg_window_multiple_channels_merged_independently() {
        let existing = r#"{"ch1": [{"startTime": 1000, "title": "A"}]}"#;
        let new = r#"{"ch2": [{"startTime": 2000, "title": "B"}]}"#;
        let merged = merge_epg_window(existing, new);
        let v: serde_json::Value = serde_json::from_str(&merged).unwrap();
        let obj = v.as_object().unwrap();
        assert!(obj.contains_key("ch1"));
        assert!(obj.contains_key("ch2"));
        assert_eq!(obj.get("ch1").and_then(|v| v.as_array()).unwrap().len(), 1,);
        assert_eq!(obj.get("ch2").and_then(|v| v.as_array()).unwrap().len(), 1,);
    }

    // ── filter_upcoming_programs ───────────────────

    #[test]
    fn upcoming_programs_within_window_returned() {
        let epg_map = r#"{"bbc1": [
            {"title": "News", "startTime": 5000, "endTime": 6000},
            {"title": "Sport", "startTime": 8000, "endTime": 9000}
        ]}"#;
        let favorites = r#"[{"id": "c1", "tvg_id": "bbc1", "name": "BBC One", "stream_url": "http://bbc.com"}]"#;
        let result = filter_upcoming_programs(epg_map, favorites, 1000, 1, 20);
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        let arr = v.as_array().unwrap();
        assert_eq!(arr.len(), 2);
        assert_eq!(arr[0]["title"], "News");
        assert_eq!(arr[0]["channel_id"], "c1");
        assert_eq!(arr[0]["channel_name"], "BBC One");
        assert_eq!(arr[1]["title"], "Sport");
    }

    #[test]
    fn upcoming_programs_outside_window_excluded() {
        let epg_map = r#"{"ch1": [
            {"title": "Early", "startTime": 500, "endTime": 1500},
            {"title": "Future", "startTime": 200000, "endTime": 300000}
        ]}"#;
        let favorites = r#"[{"id": "ch1", "name": "CH1", "stream_url": "http://ch1.com"}]"#;
        let result = filter_upcoming_programs(epg_map, favorites, 1000, 1, 20);
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert!(v.as_array().unwrap().is_empty());
    }

    #[test]
    fn upcoming_programs_uses_tvg_id_over_channel_id() {
        let epg_map = r#"{"tvg-key": [
            {"title": "Show", "startTime": 5000, "endTime": 6000}
        ]}"#;
        let favorites = r#"[{"id": "c1", "tvg_id": "tvg-key", "name": "My CH", "stream_url": ""}]"#;
        let result = filter_upcoming_programs(epg_map, favorites, 1000, 10, 20);
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert_eq!(v.as_array().unwrap().len(), 1);
    }

    #[test]
    fn upcoming_programs_falls_back_to_channel_id_when_no_tvg_id() {
        let epg_map = r#"{"c1": [
            {"title": "Show", "startTime": 5000, "endTime": 6000}
        ]}"#;
        let favorites = r#"[{"id": "c1", "name": "My CH", "stream_url": ""}]"#;
        let result = filter_upcoming_programs(epg_map, favorites, 1000, 10, 20);
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert_eq!(v.as_array().unwrap().len(), 1);
    }

    #[test]
    fn upcoming_programs_respects_limit() {
        let entries: Vec<String> = (1..=5)
            .map(|i| {
                format!(
                    r#"{{"title":"Show {i}","startTime":{},"endTime":{}}}"#,
                    1000 + i * 100,
                    1000 + i * 100 + 50
                )
            })
            .collect();
        let epg_map = format!(r#"{{"ch1":[{}]}}"#, entries.join(","));
        let favorites = r#"[{"id": "ch1", "name": "CH1", "stream_url": ""}]"#;
        let result = filter_upcoming_programs(&epg_map, favorites, 1000, 10, 2);
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert_eq!(v.as_array().unwrap().len(), 2);
    }

    #[test]
    fn upcoming_programs_sorted_by_start_time() {
        let epg_map = r#"{"ch1": [
            {"title": "Late", "startTime": 9000, "endTime": 10000},
            {"title": "Early", "startTime": 2000, "endTime": 3000}
        ]}"#;
        let favorites = r#"[{"id": "ch1", "name": "CH1", "stream_url": ""}]"#;
        let result = filter_upcoming_programs(epg_map, favorites, 1000, 10, 20);
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        let arr = v.as_array().unwrap();
        assert_eq!(arr[0]["title"], "Early");
        assert_eq!(arr[1]["title"], "Late");
    }

    #[test]
    fn upcoming_programs_empty_favorites_returns_empty() {
        let epg_map = r#"{"ch1": [{"title": "A", "startTime": 5000, "endTime": 6000}]}"#;
        let result = filter_upcoming_programs(epg_map, "[]", 1000, 10, 20);
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert!(v.as_array().unwrap().is_empty());
    }

    // ── dedup_overlapping_entries / merge overlap tests ──

    #[test]
    fn merge_dedup_removes_high_overlap_entry() {
        let existing = r#"{"ch1": [{"startTime": 1000, "endTime": 2000, "title": "A"}]}"#;
        let new = r#"{"ch1": [{"startTime": 1100, "endTime": 2100, "title": "B"}]}"#;
        let merged = merge_epg_window(existing, new);
        let v: serde_json::Value = serde_json::from_str(&merged).unwrap();
        let ch1 = v.get("ch1").and_then(|v| v.as_array()).unwrap();
        assert_eq!(ch1.len(), 1);
        assert_eq!(ch1[0]["title"], "A");
    }

    #[test]
    fn merge_dedup_keeps_low_overlap_entries() {
        let existing = r#"{"ch1": [{"startTime": 1000, "endTime": 2000, "title": "A"}]}"#;
        let new = r#"{"ch1": [{"startTime": 1700, "endTime": 2700, "title": "B"}]}"#;
        let merged = merge_epg_window(existing, new);
        let v: serde_json::Value = serde_json::from_str(&merged).unwrap();
        let ch1 = v.get("ch1").and_then(|v| v.as_array()).unwrap();
        assert_eq!(ch1.len(), 2);
    }

    #[test]
    fn merge_dedup_removes_identical_programmes() {
        let existing = r#"{"ch1": [{"startTime": 1000, "endTime": 2000, "title": "A"}]}"#;
        let new = r#"{"ch1": [{"startTime": 1000, "endTime": 2000, "title": "A_dup"}]}"#;
        let merged = merge_epg_window(existing, new);
        let v: serde_json::Value = serde_json::from_str(&merged).unwrap();
        let ch1 = v.get("ch1").and_then(|v| v.as_array()).unwrap();
        assert_eq!(ch1.len(), 1);
        assert_eq!(ch1[0]["title"], "A");
    }

    #[test]
    fn merge_dedup_non_overlapping_all_kept() {
        let existing = r#"{"ch1": [{"startTime": 1000, "endTime": 2000, "title": "A"}]}"#;
        let new = r#"{"ch1": [{"startTime": 3000, "endTime": 4000, "title": "B"}]}"#;
        let merged = merge_epg_window(existing, new);
        let v: serde_json::Value = serde_json::from_str(&merged).unwrap();
        let ch1 = v.get("ch1").and_then(|v| v.as_array()).unwrap();
        assert_eq!(ch1.len(), 2);
    }

    #[test]
    fn merge_dedup_chain_a_overlaps_b_but_not_c() {
        let existing = r#"{"ch1": [
            {"startTime": 1000, "endTime": 2000, "title": "A"}
        ]}"#;
        let new = r#"{"ch1": [
            {"startTime": 1400, "endTime": 2400, "title": "B"},
            {"startTime": 2600, "endTime": 3600, "title": "C"}
        ]}"#;
        let merged = merge_epg_window(existing, new);
        let v: serde_json::Value = serde_json::from_str(&merged).unwrap();
        let ch1 = v.get("ch1").and_then(|v| v.as_array()).unwrap();
        let titles: Vec<&str> = ch1.iter().filter_map(|e| e["title"].as_str()).collect();
        assert_eq!(titles, vec!["A", "C"]);
    }

    #[test]
    fn merge_dedup_existing_wins_over_new_same_time() {
        let existing = r#"{"ch1": [{"startTime": 1000, "endTime": 2000, "title": "A_existing"}]}"#;
        let new = r#"{"ch1": [{"startTime": 1000, "endTime": 2000, "title": "B_new"}]}"#;
        let merged = merge_epg_window(existing, new);
        let v: serde_json::Value = serde_json::from_str(&merged).unwrap();
        let ch1 = v.get("ch1").and_then(|v| v.as_array()).unwrap();
        assert_eq!(ch1.len(), 1);
        assert_eq!(ch1[0]["title"], "A_existing");
    }

    #[test]
    fn dedup_overlapping_entries_preserves_zero_duration() {
        let entries = vec![
            serde_json::json!({"startTime": 1000, "endTime": 1000, "title": "Zero"}),
            serde_json::json!({"startTime": 1000, "endTime": 2000, "title": "Normal"}),
        ];
        let result = dedup_overlapping_entries(entries);
        assert_eq!(result.len(), 2);
    }
}
