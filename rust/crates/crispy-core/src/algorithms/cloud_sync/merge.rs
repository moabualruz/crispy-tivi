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
