//! Backup merge functions for cloud sync.

use std::collections::{BTreeMap, BTreeSet, HashMap, HashSet};

use chrono::Utc;
use serde_json::{Map, Value, json};

use super::{as_array, as_object, max_i64, parse_iso_datetime};

/// Sync metadata settings keys to preserve from local during merge.
///
/// These keys track cloud sync state and must never be overwritten
/// by remote data. Canonical source of truth for both Rust and Dart.
///
/// Dart mirror: `kSyncLastTimeKey` / `kSyncLocalModifiedTimeKey`
/// in `lib/core/constants.dart`.
pub const SYNC_META_KEYS: &[&str] = &[
    "crispy_tivi_last_sync_time",
    "crispy_tivi_local_modified_time",
];

/// Merge local and cloud backup JSON objects.
///
/// The merge strategy varies by data type:
/// - Profiles: union by ID, prefer local
/// - Favorites: union all per profile
/// - Channel orders: keep local (device-specific)
/// - Source access: union grants per profile
/// - Settings: prefer newer backup, skip sync metadata
/// - Watch history: per ID, take later lastWatched +
///   max position
/// - Recordings: union by ID, prefer local if local newer
/// - Sources: union by name+URL uniqueness
/// - Version: take max of both
pub fn merge_backups(local: &Value, cloud: &Value, _current_device_id: &str) -> Value {
    let local_time = parse_iso_datetime(
        local
            .get("exportedAt")
            .and_then(Value::as_str)
            .unwrap_or(""),
    );
    let cloud_time = parse_iso_datetime(
        cloud
            .get("exportedAt")
            .and_then(Value::as_str)
            .unwrap_or(""),
    );
    let local_is_newer = match (local_time, cloud_time) {
        (Some(lt), Some(ct)) => lt > ct,
        _ => false,
    };

    let version = max_i64(
        local.get("version").and_then(Value::as_i64).unwrap_or(1),
        cloud.get("version").and_then(Value::as_i64).unwrap_or(1),
    );

    let profiles = merge_profiles(
        as_array(local.get("profiles")),
        as_array(cloud.get("profiles")),
    );

    let favorites = merge_map_of_lists(
        as_object(local.get("favorites")),
        as_object(cloud.get("favorites")),
    );

    let channel_orders = merge_by_id(
        as_array(local.get("channelOrders")),
        as_array(cloud.get("channelOrders")),
        channel_order_key,
        true, // prefer local
    );

    let source_access = merge_map_of_lists(
        as_object(local.get("sourceAccess")),
        as_object(cloud.get("sourceAccess")),
    );

    let settings = merge_settings(
        as_object(local.get("settings")),
        as_object(cloud.get("settings")),
        local_is_newer,
    );

    let watch_history = merge_watch_history(
        as_array(local.get("watchHistory")),
        as_array(cloud.get("watchHistory")),
    );

    let recordings = merge_by_id(
        as_array(local.get("recordings")),
        as_array(cloud.get("recordings")),
        recording_key,
        local_is_newer,
    );

    let sources = merge_sources(
        as_array(local.get("sources")),
        as_array(cloud.get("sources")),
    );

    json!({
        "version": version,
        "exportedAt": Utc::now().to_rfc3339(),
        "profiles": profiles,
        "favorites": favorites,
        "channelOrders": channel_orders,
        "sourceAccess": source_access,
        "settings": settings,
        "watchHistory": watch_history,
        "recordings": recordings,
        "sources": sources,
    })
}

// ── Profiles ──────────────────────────────────────────

/// Merges profiles by `id`, preferring local on conflict.
fn merge_profiles(local: &[Value], cloud: &[Value]) -> Value {
    // Use BTreeMap to maintain deterministic order.
    let mut by_id: BTreeMap<String, &Value> = BTreeMap::new();

    // Cloud first so local overwrites.
    for item in cloud {
        if let Some(id) = item.get("id").and_then(Value::as_str) {
            by_id.insert(id.to_string(), item);
        }
    }
    for item in local {
        if let Some(id) = item.get("id").and_then(Value::as_str) {
            by_id.insert(id.to_string(), item);
        }
    }

    Value::Array(by_id.values().map(|v| (*v).clone()).collect())
}

// ── Favorites / Source Access ─────────────────────────

/// Merges map-of-lists structures (favorites, source
/// access) as set union per key.
fn merge_map_of_lists(local: &Map<String, Value>, cloud: &Map<String, Value>) -> Value {
    let mut result = Map::new();
    let all_keys: BTreeSet<&String> = local.keys().chain(cloud.keys()).collect();

    for key in all_keys {
        let local_set = extract_string_set(local.get(key));
        let cloud_set = extract_string_set(cloud.get(key));
        let union: BTreeSet<String> = local_set.union(&cloud_set).cloned().collect();
        let list: Vec<Value> = union.into_iter().map(Value::String).collect();
        result.insert(key.clone(), Value::Array(list));
    }

    Value::Object(result)
}

fn extract_string_set(v: Option<&Value>) -> BTreeSet<String> {
    v.and_then(Value::as_array)
        .map(|arr| {
            arr.iter()
                .filter_map(Value::as_str)
                .map(String::from)
                .collect()
        })
        .unwrap_or_default()
}

// ── Settings ──────────────────────────────────────────

/// Merges settings, preferring the newer backup.
///
/// Sync metadata keys are always kept from local.
fn merge_settings(
    local: &Map<String, Value>,
    cloud: &Map<String, Value>,
    local_is_newer: bool,
) -> Value {
    let (base, override_map) = if local_is_newer {
        (cloud, local)
    } else {
        (local, cloud)
    };

    let mut result = Map::new();
    // Start with base, then apply override.
    for (k, v) in base {
        result.insert(k.clone(), v.clone());
    }
    for (k, v) in override_map {
        result.insert(k.clone(), v.clone());
    }

    // Always keep local sync metadata.
    for key in SYNC_META_KEYS {
        let key_str = (*key).to_string();
        if let Some(v) = local.get(*key) {
            result.insert(key_str, v.clone());
        } else {
            result.remove(&key_str);
        }
    }

    Value::Object(result)
}

// ── Watch History ─────────────────────────────────────

/// Merges watch history by `id`, taking the entry with
/// the later `lastWatched` and the max `positionMs`.
fn merge_watch_history(local: &[Value], cloud: &[Value]) -> Value {
    let mut by_id: HashMap<String, Value> = HashMap::new();

    // Add cloud entries first.
    for item in cloud {
        if let Some(id) = item.get("id").and_then(Value::as_str) {
            by_id.insert(id.to_string(), item.clone());
        }
    }

    // Process local entries, merging where needed.
    for item in local {
        let id = match item.get("id").and_then(Value::as_str) {
            Some(id) => id.to_string(),
            None => continue,
        };

        let existing = by_id.get(&id);
        if existing.is_none() {
            by_id.insert(id, item.clone());
            continue;
        }
        let existing = existing.unwrap();

        // Compute max position.
        let local_pos = item.get("positionMs").and_then(Value::as_i64).unwrap_or(0);
        let cloud_pos = existing
            .get("positionMs")
            .and_then(Value::as_i64)
            .unwrap_or(0);
        let max_pos = local_pos.max(cloud_pos);

        // Take entry with later lastWatched.
        let local_time = parse_iso_datetime(
            item.get("lastWatched")
                .and_then(Value::as_str)
                .unwrap_or(""),
        );
        let cloud_time = parse_iso_datetime(
            existing
                .get("lastWatched")
                .and_then(Value::as_str)
                .unwrap_or(""),
        );

        let use_local = match (local_time, cloud_time) {
            (Some(lt), Some(ct)) => lt > ct,
            _ => false,
        };

        if use_local {
            by_id.insert(id.clone(), item.clone());
        }

        // Always apply max position.
        if let Some(entry) = by_id.get_mut(&id)
            && let Some(obj) = entry.as_object_mut()
        {
            obj.insert("positionMs".to_string(), Value::Number(max_pos.into()));
        }
    }

    // Sort by lastWatched descending.
    let mut entries: Vec<Value> = by_id.into_values().collect();
    entries.sort_by(|a, b| {
        let ta = parse_iso_datetime(a.get("lastWatched").and_then(Value::as_str).unwrap_or(""));
        let tb = parse_iso_datetime(b.get("lastWatched").and_then(Value::as_str).unwrap_or(""));
        tb.cmp(&ta)
    });

    Value::Array(entries)
}

// ── Sources ───────────────────────────────────────────

/// Merges sources by `name` + `url` uniqueness, preferring
/// local entries.
fn merge_sources(local: &[Value], cloud: &[Value]) -> Value {
    let mut seen: HashSet<String> = HashSet::new();
    let mut result: Vec<Value> = Vec::new();

    // Local first (preferred).
    for item in local {
        let key = source_key(item);
        if seen.insert(key) {
            result.push(item.clone());
        }
    }

    // Then cloud.
    for item in cloud {
        let key = source_key(item);
        if seen.insert(key) {
            result.push(item.clone());
        }
    }

    Value::Array(result)
}

fn source_key(v: &Value) -> String {
    let name = v.get("name").and_then(Value::as_str).unwrap_or("");
    let url = v.get("url").and_then(Value::as_str).unwrap_or("");
    format!("{name}_{url}")
}

// ── Generic merge-by-ID ───────────────────────────────

/// Merges two arrays of objects by a key function.
///
/// On conflict, `prefer_local` determines which entry wins.
fn merge_by_id(
    local: &[Value],
    cloud: &[Value],
    key_fn: fn(&Value) -> String,
    prefer_local: bool,
) -> Value {
    let mut by_key: BTreeMap<String, Value> = BTreeMap::new();

    // Add base first, then preferred overwrites.
    let (base, preferred) = if prefer_local {
        (cloud, local)
    } else {
        (local, cloud)
    };

    for item in base {
        let key = key_fn(item);
        by_key.insert(key, item.clone());
    }
    for item in preferred {
        let key = key_fn(item);
        by_key.insert(key, item.clone());
    }

    Value::Array(by_key.into_values().collect())
}

fn channel_order_key(v: &Value) -> String {
    let profile_id = v.get("profileId").and_then(Value::as_str).unwrap_or("");
    let group_name = v.get("groupName").and_then(Value::as_str).unwrap_or("");
    let channel_id = v.get("channelId").and_then(Value::as_str).unwrap_or("");
    format!("{profile_id}_{group_name}_{channel_id}")
}

fn recording_key(v: &Value) -> String {
    v.get("id")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string()
}

// ── Tests ─────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::*;

    // ── merge_backups: both empty ─────────────────────

    #[test]
    fn test_merge_backups_both_empty() {
        let local = json!({});
        let cloud = json!({});
        let result = merge_backups(&local, &cloud, "dev1");

        assert_eq!(result.get("version").and_then(Value::as_i64), Some(1));
        assert!(
            result
                .get("profiles")
                .and_then(Value::as_array)
                .unwrap()
                .is_empty(),
        );
        assert!(
            result
                .get("sources")
                .and_then(Value::as_array)
                .unwrap()
                .is_empty(),
        );
        assert!(
            result
                .get("watchHistory")
                .and_then(Value::as_array)
                .unwrap()
                .is_empty(),
        );
    }

    // ── merge_backups: local-only ─────────────────────

    #[test]
    fn test_merge_backups_local_only() {
        let local = json!({
            "version": 4,
            "profiles": [{"id": "p1", "name": "Alice"}],
            "sources": [{"name": "S1", "url": "http://s1.com"}],
        });
        let cloud = json!({});
        let result = merge_backups(&local, &cloud, "dev1");

        assert_eq!(result.get("version").and_then(Value::as_i64), Some(4));
        let profiles = result.get("profiles").and_then(Value::as_array).unwrap();
        assert_eq!(profiles.len(), 1);
        assert_eq!(
            profiles[0].get("name").and_then(Value::as_str),
            Some("Alice"),
        );
        assert_eq!(
            result
                .get("sources")
                .and_then(Value::as_array)
                .unwrap()
                .len(),
            1,
        );
    }

    // ── merge_backups: cloud-only ─────────────────────

    #[test]
    fn test_merge_backups_cloud_only() {
        let local = json!({});
        let cloud = json!({
            "version": 6,
            "profiles": [{"id": "p1", "name": "Bob"}, {"id": "p2", "name": "Carol"}],
            "watchHistory": [
                {
                    "id": "w1",
                    "positionMs": 2000,
                    "lastWatched": "2024-06-01T10:00:00Z",
                },
            ],
        });
        let result = merge_backups(&local, &cloud, "dev1");

        assert_eq!(result.get("version").and_then(Value::as_i64), Some(6));
        assert_eq!(
            result
                .get("profiles")
                .and_then(Value::as_array)
                .unwrap()
                .len(),
            2,
        );
        assert_eq!(
            result
                .get("watchHistory")
                .and_then(Value::as_array)
                .unwrap()
                .len(),
            1,
        );
    }

    // ── merge_profiles ────────────────────────────────

    #[test]
    fn test_merge_profiles_prefer_local() {
        let local = vec![json!({"id": "p1", "name": "LocalName", "pin": "1234"})];
        let cloud = vec![json!({"id": "p1", "name": "CloudName", "pin": "9999"})];
        let result = merge_profiles(&local, &cloud);
        let arr = result.as_array().unwrap();

        assert_eq!(arr.len(), 1);
        assert_eq!(
            arr[0].get("name").and_then(Value::as_str),
            Some("LocalName")
        );
        assert_eq!(arr[0].get("pin").and_then(Value::as_str), Some("1234"));
    }

    #[test]
    fn test_merge_profiles_union() {
        let local = vec![json!({"id": "p1", "name": "Alice"})];
        let cloud = vec![
            json!({"id": "p2", "name": "Bob"}),
            json!({"id": "p3", "name": "Carol"}),
        ];
        let result = merge_profiles(&local, &cloud);
        let arr = result.as_array().unwrap();

        assert_eq!(arr.len(), 3);
        let ids: Vec<&str> = arr
            .iter()
            .filter_map(|p| p.get("id").and_then(Value::as_str))
            .collect();
        assert!(ids.contains(&"p1"));
        assert!(ids.contains(&"p2"));
        assert!(ids.contains(&"p3"));
    }

    #[test]
    fn test_merge_profiles_empty_inputs() {
        let result = merge_profiles(&[], &[]);
        assert!(result.as_array().unwrap().is_empty());
    }

    // ── merge_map_of_lists ────────────────────────────

    #[test]
    fn test_merge_map_of_lists_union() {
        let local_map = json!({"p1": ["ch1", "ch2"]});
        let cloud_map = json!({"p1": ["ch2", "ch3"], "p2": ["ch9"]});
        let local = local_map.as_object().unwrap();
        let cloud = cloud_map.as_object().unwrap();
        let result = merge_map_of_lists(local, cloud);
        let obj = result.as_object().unwrap();

        let p1: Vec<&str> = obj
            .get("p1")
            .and_then(Value::as_array)
            .unwrap()
            .iter()
            .filter_map(Value::as_str)
            .collect();
        // Union of {ch1,ch2} ∪ {ch2,ch3} = {ch1,ch2,ch3}
        assert_eq!(p1.len(), 3);
        assert!(p1.contains(&"ch1"));
        assert!(p1.contains(&"ch2"));
        assert!(p1.contains(&"ch3"));

        // p2 only in cloud → appears in result.
        assert!(obj.contains_key("p2"));
    }

    #[test]
    fn test_merge_map_of_lists_empty() {
        use serde_json::Map;
        let empty: Map<String, Value> = Map::new();
        let result = merge_map_of_lists(&empty, &empty);
        assert!(result.as_object().unwrap().is_empty());
    }

    // ── merge_settings ────────────────────────────────

    #[test]
    fn test_merge_settings_local_newer() {
        let local_map = json!({
            "theme": "dark",
            "lang": "en",
            "crispy_tivi_last_sync_time": "local_ts",
        });
        let cloud_map = json!({"theme": "light", "volume": 80});
        let local = local_map.as_object().unwrap();
        let cloud = cloud_map.as_object().unwrap();

        let result = merge_settings(local, cloud, true); // local is newer
        let obj = result.as_object().unwrap();

        // Local wins on shared key.
        assert_eq!(obj.get("theme").and_then(Value::as_str), Some("dark"));
        // Cloud-only key preserved.
        assert_eq!(obj.get("volume").and_then(Value::as_i64), Some(80));
        // Sync meta always from local.
        assert_eq!(
            obj.get("crispy_tivi_last_sync_time")
                .and_then(Value::as_str),
            Some("local_ts"),
        );
    }

    #[test]
    fn test_merge_settings_cloud_newer() {
        let local_map = json!({
            "theme": "dark",
            "crispy_tivi_last_sync_time": "local_ts",
        });
        let cloud_map = json!({"theme": "light", "extra": "cloud_val"});
        let local = local_map.as_object().unwrap();
        let cloud = cloud_map.as_object().unwrap();

        let result = merge_settings(local, cloud, false); // cloud is newer
        let obj = result.as_object().unwrap();

        // Cloud wins on shared key when cloud is newer.
        assert_eq!(obj.get("theme").and_then(Value::as_str), Some("light"));
        // Cloud-only key present.
        assert_eq!(obj.get("extra").and_then(Value::as_str), Some("cloud_val"),);
        // Sync meta STILL from local regardless of who is newer.
        assert_eq!(
            obj.get("crispy_tivi_last_sync_time")
                .and_then(Value::as_str),
            Some("local_ts"),
        );
    }

    #[test]
    fn test_merge_settings_sync_meta_preserved_when_cloud_newer() {
        // Even if cloud is explicitly newer, SYNC_META_KEYS must
        // always reflect the local value.
        let local_map = json!({
            "crispy_tivi_last_sync_time": "local_sync",
            "crispy_tivi_local_modified_time": "local_mod",
        });
        let cloud_map = json!({
            "crispy_tivi_last_sync_time": "cloud_sync",
            "crispy_tivi_local_modified_time": "cloud_mod",
        });
        let local = local_map.as_object().unwrap();
        let cloud = cloud_map.as_object().unwrap();

        let result = merge_settings(local, cloud, false); // cloud newer
        let obj = result.as_object().unwrap();

        assert_eq!(
            obj.get("crispy_tivi_last_sync_time")
                .and_then(Value::as_str),
            Some("local_sync"),
        );
        assert_eq!(
            obj.get("crispy_tivi_local_modified_time")
                .and_then(Value::as_str),
            Some("local_mod"),
        );
    }

    #[test]
    fn test_merge_settings_sync_meta_absent_in_local_removed_from_result() {
        // If local doesn't have a sync meta key, it should be
        // removed from the merged result even if cloud has it.
        let local_map = json!({"theme": "dark"});
        let cloud_map = json!({
            "theme": "light",
            "crispy_tivi_last_sync_time": "cloud_val",
        });
        let local = local_map.as_object().unwrap();
        let cloud = cloud_map.as_object().unwrap();

        let result = merge_settings(local, cloud, false);
        let obj = result.as_object().unwrap();

        // Key absent in local → must be absent in result.
        assert!(!obj.contains_key("crispy_tivi_last_sync_time"));
    }

    // ── merge_watch_history ───────────────────────────

    #[test]
    fn test_merge_watch_history_later_wins() {
        // Cloud has later lastWatched → cloud base entry wins.
        let local = vec![json!({
            "id": "w1",
            "title": "LocalTitle",
            "positionMs": 1000,
            "lastWatched": "2024-05-01T10:00:00Z",
        })];
        let cloud = vec![json!({
            "id": "w1",
            "title": "CloudTitle",
            "positionMs": 500,
            "lastWatched": "2024-06-01T10:00:00Z",
        })];
        let result = merge_watch_history(&local, &cloud);
        let arr = result.as_array().unwrap();

        assert_eq!(arr.len(), 1);
        // Cloud has later lastWatched → cloud base entry used.
        assert_eq!(
            arr[0].get("title").and_then(Value::as_str),
            Some("CloudTitle"),
        );
        // Max position: max(1000, 500) = 1000.
        assert_eq!(arr[0].get("positionMs").and_then(Value::as_i64), Some(1000));
    }

    #[test]
    fn test_merge_watch_history_max_position() {
        // Local has later lastWatched → local base, but
        // position is always the max of both.
        let local = vec![json!({
            "id": "w1",
            "positionMs": 9000,
            "lastWatched": "2024-07-01T10:00:00Z",
        })];
        let cloud = vec![json!({
            "id": "w1",
            "positionMs": 3000,
            "lastWatched": "2024-06-01T10:00:00Z",
        })];
        let result = merge_watch_history(&local, &cloud);
        let arr = result.as_array().unwrap();

        assert_eq!(arr.len(), 1);
        assert_eq!(arr[0].get("positionMs").and_then(Value::as_i64), Some(9000),);
    }

    #[test]
    fn test_merge_watch_history_disjoint_sorted_desc() {
        let local = vec![json!({
            "id": "w1",
            "positionMs": 1000,
            "lastWatched": "2024-06-01T10:00:00Z",
        })];
        let cloud = vec![
            json!({
                "id": "w2",
                "positionMs": 2000,
                "lastWatched": "2024-07-01T10:00:00Z",
            }),
            json!({
                "id": "w3",
                "positionMs": 500,
                "lastWatched": "2024-05-01T10:00:00Z",
            }),
        ];
        let result = merge_watch_history(&local, &cloud);
        let arr = result.as_array().unwrap();

        assert_eq!(arr.len(), 3);
        // Sorted by lastWatched descending:
        // w2 (July) > w1 (June) > w3 (May).
        assert_eq!(arr[0].get("id").and_then(Value::as_str), Some("w2"));
        assert_eq!(arr[1].get("id").and_then(Value::as_str), Some("w1"));
        assert_eq!(arr[2].get("id").and_then(Value::as_str), Some("w3"));
    }

    // ── merge_sources ─────────────────────────────────

    #[test]
    fn test_merge_sources_local_preferred() {
        let local = vec![json!({
            "name": "IPTV",
            "url": "http://a.com",
            "local_field": "kept",
        })];
        let cloud = vec![json!({
            "name": "IPTV",
            "url": "http://a.com",
            "cloud_field": "dropped",
        })];
        let result = merge_sources(&local, &cloud);
        let arr = result.as_array().unwrap();

        // Deduplicated: only 1 entry.
        assert_eq!(arr.len(), 1);
        // Local version wins.
        assert_eq!(
            arr[0].get("local_field").and_then(Value::as_str),
            Some("kept"),
        );
        assert!(arr[0].get("cloud_field").is_none());
    }

    #[test]
    fn test_merge_sources_disjoint() {
        let local = vec![json!({"name": "Src1", "url": "http://a.com"})];
        let cloud = vec![
            json!({"name": "Src2", "url": "http://b.com"}),
            json!({"name": "Src3", "url": "http://c.com"}),
        ];
        let result = merge_sources(&local, &cloud);
        let arr = result.as_array().unwrap();

        assert_eq!(arr.len(), 3);
        let names: Vec<&str> = arr
            .iter()
            .filter_map(|s| s.get("name").and_then(Value::as_str))
            .collect();
        assert!(names.contains(&"Src1"));
        assert!(names.contains(&"Src2"));
        assert!(names.contains(&"Src3"));
    }

    // ── merge_by_id ───────────────────────────────────

    #[test]
    fn test_merge_by_id_prefer_local() {
        let local = vec![json!({"id": "r1", "val": "local_val"})];
        let cloud = vec![json!({"id": "r1", "val": "cloud_val"})];
        let result = merge_by_id(&local, &cloud, recording_key, true);
        let arr = result.as_array().unwrap();

        assert_eq!(arr.len(), 1);
        assert_eq!(arr[0].get("val").and_then(Value::as_str), Some("local_val"));
    }

    #[test]
    fn test_merge_by_id_prefer_cloud() {
        let local = vec![json!({"id": "r1", "val": "local_val"})];
        let cloud = vec![json!({"id": "r1", "val": "cloud_val"})];
        let result = merge_by_id(&local, &cloud, recording_key, false);
        let arr = result.as_array().unwrap();

        assert_eq!(arr.len(), 1);
        assert_eq!(arr[0].get("val").and_then(Value::as_str), Some("cloud_val"),);
    }

    #[test]
    fn test_merge_by_id_union_of_disjoint() {
        let local = vec![json!({"id": "r1", "val": "a"})];
        let cloud = vec![json!({"id": "r2", "val": "b"})];
        let result = merge_by_id(&local, &cloud, recording_key, true);
        let arr = result.as_array().unwrap();

        assert_eq!(arr.len(), 2);
        let ids: Vec<&str> = arr
            .iter()
            .filter_map(|v| v.get("id").and_then(Value::as_str))
            .collect();
        assert!(ids.contains(&"r1"));
        assert!(ids.contains(&"r2"));
    }

    // ── key extractor functions ───────────────────────

    #[test]
    fn test_channel_order_key_format() {
        let v = json!({
            "profileId": "p1",
            "groupName": "Sports",
            "channelId": "ch42",
        });
        assert_eq!(channel_order_key(&v), "p1_Sports_ch42");
    }

    #[test]
    fn test_channel_order_key_missing_fields() {
        let v = json!({});
        assert_eq!(channel_order_key(&v), "__");
    }

    #[test]
    fn test_recording_key_extracts_id() {
        let v = json!({"id": "rec-99"});
        assert_eq!(recording_key(&v), "rec-99");
    }

    #[test]
    fn test_recording_key_missing_id() {
        let v = json!({});
        assert_eq!(recording_key(&v), "");
    }

    #[test]
    fn test_source_key_format() {
        let v = json!({"name": "IPTV", "url": "http://test.com"});
        assert_eq!(source_key(&v), "IPTV_http://test.com");
    }
}
