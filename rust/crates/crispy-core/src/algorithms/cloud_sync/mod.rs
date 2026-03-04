//! Cloud sync merge algorithms.
//!
//! Ports `CloudSyncService.mergeBackups()` and all helper
//! merge functions from Dart `cloud_sync_service.dart`.
//!
//! All functions are pure — no I/O, no DB access. Input and
//! output are `serde_json::Value` (arbitrary JSON).

mod merge;
mod sync_direction;

pub use merge::SYNC_META_KEYS;
pub use merge::merge_backups;
pub use sync_direction::determine_sync_direction;

// ── Helper: safe accessors ────────────────────────────

use chrono::{DateTime, Utc};
use serde_json::{Map, Value};

pub(super) fn as_array(v: Option<&Value>) -> &[Value] {
    v.and_then(Value::as_array)
        .map(Vec::as_slice)
        .unwrap_or(&[])
}

pub(super) fn as_object(v: Option<&Value>) -> &Map<String, Value> {
    static EMPTY: std::sync::LazyLock<Map<String, Value>> = std::sync::LazyLock::new(Map::new);
    v.and_then(Value::as_object).unwrap_or(&EMPTY)
}

pub(super) fn parse_iso_datetime(s: &str) -> Option<DateTime<Utc>> {
    DateTime::parse_from_rfc3339(s)
        .ok()
        .map(|dt| dt.with_timezone(&Utc))
}

pub(super) fn max_i64(a: i64, b: i64) -> i64 {
    a.max(b)
}

// ── Tests ─────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn merge_both_empty_returns_defaults() {
        let local = json!({});
        let cloud = json!({});
        let result = merge_backups(&local, &cloud, "dev1");

        assert_eq!(result.get("version").and_then(Value::as_i64), Some(1),);
        assert!(
            result
                .get("profiles")
                .and_then(Value::as_array)
                .unwrap()
                .is_empty()
        );
        assert!(
            result
                .get("sources")
                .and_then(Value::as_array)
                .unwrap()
                .is_empty()
        );
    }

    #[test]
    fn profiles_local_wins_on_conflict() {
        let local = json!({
            "profiles": [
                {"id": "p1", "name": "Local Name"},
                {"id": "p2", "name": "Only Local"},
            ]
        });
        let cloud = json!({
            "profiles": [
                {"id": "p1", "name": "Cloud Name"},
                {"id": "p3", "name": "Only Cloud"},
            ]
        });
        let result = merge_backups(&local, &cloud, "dev1");
        let profiles = result.get("profiles").and_then(Value::as_array).unwrap();

        assert_eq!(profiles.len(), 3);

        // p1 should have local name.
        let p1 = profiles
            .iter()
            .find(|p| p.get("id").and_then(Value::as_str) == Some("p1"))
            .unwrap();
        assert_eq!(p1.get("name").and_then(Value::as_str), Some("Local Name"),);
    }

    #[test]
    fn favorites_union_per_profile() {
        let local = json!({
            "favorites": {
                "p1": ["ch1", "ch2"],
                "p2": ["ch5"],
            }
        });
        let cloud = json!({
            "favorites": {
                "p1": ["ch2", "ch3"],
                "p3": ["ch9"],
            }
        });
        let result = merge_backups(&local, &cloud, "dev1");
        let favs = result.get("favorites").and_then(Value::as_object).unwrap();

        // p1: union of {ch1,ch2} and {ch2,ch3} = {ch1,ch2,ch3}
        let p1: Vec<&str> = favs
            .get("p1")
            .and_then(Value::as_array)
            .unwrap()
            .iter()
            .filter_map(Value::as_str)
            .collect();
        assert_eq!(p1.len(), 3);
        assert!(p1.contains(&"ch1"));
        assert!(p1.contains(&"ch2"));
        assert!(p1.contains(&"ch3"));

        // p2: only in local
        assert!(favs.contains_key("p2"));
        // p3: only in cloud
        assert!(favs.contains_key("p3"));
    }

    #[test]
    fn watch_history_max_position_later_watched() {
        let local = json!({
            "watchHistory": [
                {
                    "id": "w1",
                    "positionMs": 5000,
                    "lastWatched":
                        "2024-06-01T12:00:00Z",
                },
                {
                    "id": "w2",
                    "positionMs": 1000,
                    "lastWatched":
                        "2024-06-02T10:00:00Z",
                },
            ]
        });
        let cloud = json!({
            "watchHistory": [
                {
                    "id": "w1",
                    "positionMs": 3000,
                    "lastWatched":
                        "2024-06-02T12:00:00Z",
                },
                {
                    "id": "w3",
                    "positionMs": 7000,
                    "lastWatched":
                        "2024-05-30T08:00:00Z",
                },
            ]
        });
        let result = merge_backups(&local, &cloud, "dev1");
        let history = result
            .get("watchHistory")
            .and_then(Value::as_array)
            .unwrap();

        assert_eq!(history.len(), 3);

        // w1: cloud has later lastWatched, but position
        // should be max(5000, 3000) = 5000.
        let w1 = history
            .iter()
            .find(|h| h.get("id").and_then(Value::as_str) == Some("w1"))
            .unwrap();
        assert_eq!(w1.get("positionMs").and_then(Value::as_i64), Some(5000),);
        // w1: cloud's lastWatched is later, so cloud wins
        // the base entry.
        assert_eq!(
            w1.get("lastWatched").and_then(Value::as_str),
            Some("2024-06-02T12:00:00Z"),
        );
    }

    #[test]
    fn sources_deduplicate_by_name_url() {
        let local = json!({
            "sources": [
                {"name": "IPTV1", "url": "http://a.com/1"},
                {"name": "IPTV2", "url": "http://b.com/2"},
            ]
        });
        let cloud = json!({
            "sources": [
                {"name": "IPTV1", "url": "http://a.com/1"},
                {"name": "IPTV3", "url": "http://c.com/3"},
            ]
        });
        let result = merge_backups(&local, &cloud, "dev1");
        let sources = result.get("sources").and_then(Value::as_array).unwrap();

        // 3 unique sources, not 4.
        assert_eq!(sources.len(), 3);
    }

    #[test]
    fn settings_newer_backup_wins() {
        let local = json!({
            "exportedAt": "2024-06-10T12:00:00Z",
            "settings": {
                "theme": "dark",
                "language": "en",
                "crispy_tivi_last_sync_time": "local_ts",
            },
        });
        let cloud = json!({
            "exportedAt": "2024-06-05T12:00:00Z",
            "settings": {
                "theme": "light",
                "language": "fr",
                "volume": 80,
            },
        });
        let result = merge_backups(&local, &cloud, "dev1");
        let settings = result.get("settings").and_then(Value::as_object).unwrap();

        // Local is newer, so local settings win.
        assert_eq!(settings.get("theme").and_then(Value::as_str), Some("dark"),);
        assert_eq!(settings.get("language").and_then(Value::as_str), Some("en"),);
        // Cloud-only key preserved from base.
        assert_eq!(settings.get("volume").and_then(Value::as_i64), Some(80),);
        // Sync metadata always from local.
        assert_eq!(
            settings
                .get("crispy_tivi_last_sync_time")
                .and_then(Value::as_str),
            Some("local_ts"),
        );
    }

    #[test]
    fn version_takes_max() {
        let local = json!({"version": 3});
        let cloud = json!({"version": 5});
        let result = merge_backups(&local, &cloud, "dev1");
        assert_eq!(result.get("version").and_then(Value::as_i64), Some(5),);

        // Reverse direction.
        let result2 = merge_backups(&cloud, &local, "dev1");
        assert_eq!(result2.get("version").and_then(Value::as_i64), Some(5),);
    }

    #[test]
    fn channel_orders_local_only_preserved() {
        let local = json!({
            "channelOrders": [
                {
                    "profileId": "p1",
                    "groupName": "Sports",
                    "channelId": "ch1",
                    "order": 1,
                },
                {
                    "profileId": "p1",
                    "groupName": "News",
                    "channelId": "ch2",
                    "order": 2,
                },
            ]
        });
        let cloud = json!({
            "channelOrders": [
                {
                    "profileId": "p1",
                    "groupName": "Sports",
                    "channelId": "ch1",
                    "order": 99,
                },
                {
                    "profileId": "p2",
                    "groupName": "Music",
                    "channelId": "ch5",
                    "order": 3,
                },
            ]
        });
        let result = merge_backups(&local, &cloud, "dev1");
        let orders = result
            .get("channelOrders")
            .and_then(Value::as_array)
            .unwrap();

        // Union: 3 unique keys (p1_Sports_ch1,
        // p1_News_ch2, p2_Music_ch5).
        assert_eq!(orders.len(), 3);

        // For the conflicting entry, local order wins.
        let sports = orders
            .iter()
            .find(|o| o.get("channelId").and_then(Value::as_str) == Some("ch1"))
            .unwrap();
        assert_eq!(sports.get("order").and_then(Value::as_i64), Some(1),);
    }

    // ── Profiles ─────────────────────────────────────────

    #[test]
    fn merge_profiles_local_wins_on_conflict() {
        let local = json!({
            "profiles": [
                {"id": "p1", "name": "LocalName", "icon": "star"},
            ]
        });
        let cloud = json!({
            "profiles": [
                {"id": "p1", "name": "CloudName", "icon": "moon"},
            ]
        });
        let result = merge_backups(&local, &cloud, "dev1");
        let profiles = result.get("profiles").and_then(Value::as_array).unwrap();

        assert_eq!(profiles.len(), 1);
        let p1 = &profiles[0];
        assert_eq!(p1.get("name").and_then(Value::as_str), Some("LocalName"),);
        assert_eq!(p1.get("icon").and_then(Value::as_str), Some("star"),);
    }

    #[test]
    fn merge_profiles_adds_cloud_only() {
        let local = json!({
            "profiles": [
                {"id": "p1", "name": "Alice"},
            ]
        });
        let cloud = json!({
            "profiles": [
                {"id": "p2", "name": "Bob"},
                {"id": "p3", "name": "Charlie"},
            ]
        });
        let result = merge_backups(&local, &cloud, "dev1");
        let profiles = result.get("profiles").and_then(Value::as_array).unwrap();

        assert_eq!(profiles.len(), 3);
        let ids: Vec<&str> = profiles
            .iter()
            .filter_map(|p| p.get("id").and_then(Value::as_str))
            .collect();
        assert!(ids.contains(&"p1"));
        assert!(ids.contains(&"p2"));
        assert!(ids.contains(&"p3"));
    }

    // ── Favorites ────────────────────────────────────────

    #[test]
    fn merge_favorites_union() {
        let local = json!({
            "favorites": {
                "p1": ["ch1", "ch2"],
            }
        });
        let cloud = json!({
            "favorites": {
                "p1": ["ch3", "ch4"],
            }
        });
        let result = merge_backups(&local, &cloud, "dev1");
        let favs = result.get("favorites").and_then(Value::as_object).unwrap();
        let p1: Vec<&str> = favs
            .get("p1")
            .and_then(Value::as_array)
            .unwrap()
            .iter()
            .filter_map(Value::as_str)
            .collect();

        assert_eq!(p1.len(), 4);
        assert!(p1.contains(&"ch1"));
        assert!(p1.contains(&"ch2"));
        assert!(p1.contains(&"ch3"));
        assert!(p1.contains(&"ch4"));
    }

    #[test]
    fn merge_favorites_empty_cloud() {
        let local = json!({
            "favorites": {
                "p1": ["ch1", "ch2"],
                "p2": ["ch5"],
            }
        });
        let cloud = json!({});
        let result = merge_backups(&local, &cloud, "dev1");
        let favs = result.get("favorites").and_then(Value::as_object).unwrap();

        assert_eq!(favs.len(), 2);
        let p1: Vec<&str> = favs
            .get("p1")
            .and_then(Value::as_array)
            .unwrap()
            .iter()
            .filter_map(Value::as_str)
            .collect();
        assert_eq!(p1.len(), 2);
        assert!(p1.contains(&"ch1"));
        assert!(p1.contains(&"ch2"));
    }

    // ── Channel Orders ───────────────────────────────────

    #[test]
    fn merge_channel_orders_cloud_newer_wins() {
        // channel_orders uses merge_by_id with prefer_local
        // = true, so local ALWAYS wins regardless of
        // timestamp. Verify that behavior.
        let local = json!({
            "exportedAt": "2024-01-01T00:00:00Z",
            "channelOrders": [
                {
                    "profileId": "p1",
                    "groupName": "G",
                    "channelId": "c1",
                    "order": 10,
                },
            ]
        });
        let cloud = json!({
            "exportedAt": "2024-12-01T00:00:00Z",
            "channelOrders": [
                {
                    "profileId": "p1",
                    "groupName": "G",
                    "channelId": "c1",
                    "order": 99,
                },
            ]
        });
        let result = merge_backups(&local, &cloud, "dev1");
        let orders = result
            .get("channelOrders")
            .and_then(Value::as_array)
            .unwrap();

        assert_eq!(orders.len(), 1);
        // Local always wins for channel orders.
        assert_eq!(orders[0].get("order").and_then(Value::as_i64), Some(10),);
    }

    #[test]
    fn merge_channel_orders_local_newer_wins() {
        let local = json!({
            "exportedAt": "2024-12-01T00:00:00Z",
            "channelOrders": [
                {
                    "profileId": "p1",
                    "groupName": "G",
                    "channelId": "c1",
                    "order": 5,
                },
            ]
        });
        let cloud = json!({
            "exportedAt": "2024-01-01T00:00:00Z",
            "channelOrders": [
                {
                    "profileId": "p1",
                    "groupName": "G",
                    "channelId": "c1",
                    "order": 50,
                },
            ]
        });
        let result = merge_backups(&local, &cloud, "dev1");
        let orders = result
            .get("channelOrders")
            .and_then(Value::as_array)
            .unwrap();

        assert_eq!(orders.len(), 1);
        assert_eq!(orders[0].get("order").and_then(Value::as_i64), Some(5),);
    }

    // ── Settings ─────────────────────────────────────────

    #[test]
    fn merge_settings_union_unique_keys() {
        let local = json!({
            "exportedAt": "2024-06-10T12:00:00Z",
            "settings": {
                "theme": "dark",
            },
        });
        let cloud = json!({
            "exportedAt": "2024-06-05T12:00:00Z",
            "settings": {
                "volume": 75,
            },
        });
        let result = merge_backups(&local, &cloud, "dev1");
        let settings = result.get("settings").and_then(Value::as_object).unwrap();

        // Both unique keys present.
        assert_eq!(settings.get("theme").and_then(Value::as_str), Some("dark"),);
        assert_eq!(settings.get("volume").and_then(Value::as_i64), Some(75),);
    }

    #[test]
    fn merge_settings_local_wins_same_key() {
        // Local is newer, so local value wins for shared key.
        let local = json!({
            "exportedAt": "2024-08-01T00:00:00Z",
            "settings": {
                "theme": "dark",
                "buffer_size": 4096,
            },
        });
        let cloud = json!({
            "exportedAt": "2024-06-01T00:00:00Z",
            "settings": {
                "theme": "light",
                "buffer_size": 2048,
            },
        });
        let result = merge_backups(&local, &cloud, "dev1");
        let settings = result.get("settings").and_then(Value::as_object).unwrap();

        assert_eq!(settings.get("theme").and_then(Value::as_str), Some("dark"),);
        assert_eq!(
            settings.get("buffer_size").and_then(Value::as_i64),
            Some(4096),
        );
    }

    // ── Watch History ────────────────────────────────────

    #[test]
    fn merge_watch_history_dedup_by_id() {
        let local = json!({
            "watchHistory": [
                {
                    "id": "w1",
                    "positionMs": 9000,
                    "lastWatched":
                        "2024-07-01T12:00:00Z",
                    "title": "LocalTitle",
                },
            ]
        });
        let cloud = json!({
            "watchHistory": [
                {
                    "id": "w1",
                    "positionMs": 3000,
                    "lastWatched":
                        "2024-06-01T12:00:00Z",
                    "title": "CloudTitle",
                },
            ]
        });
        let result = merge_backups(&local, &cloud, "dev1");
        let history = result
            .get("watchHistory")
            .and_then(Value::as_array)
            .unwrap();

        // Only one entry (deduped).
        assert_eq!(history.len(), 1);
        let w1 = &history[0];
        // Local has later lastWatched, so local wins base.
        assert_eq!(w1.get("title").and_then(Value::as_str), Some("LocalTitle"),);
        // Position is max(9000, 3000) = 9000.
        assert_eq!(w1.get("positionMs").and_then(Value::as_i64), Some(9000),);
    }

    #[test]
    fn merge_watch_history_combines_unique() {
        let local = json!({
            "watchHistory": [
                {
                    "id": "w1",
                    "positionMs": 1000,
                    "lastWatched":
                        "2024-06-01T12:00:00Z",
                },
            ]
        });
        let cloud = json!({
            "watchHistory": [
                {
                    "id": "w2",
                    "positionMs": 2000,
                    "lastWatched":
                        "2024-06-02T12:00:00Z",
                },
            ]
        });
        let result = merge_backups(&local, &cloud, "dev1");
        let history = result
            .get("watchHistory")
            .and_then(Value::as_array)
            .unwrap();

        assert_eq!(history.len(), 2);
        let ids: Vec<&str> = history
            .iter()
            .filter_map(|h| h.get("id").and_then(Value::as_str))
            .collect();
        assert!(ids.contains(&"w1"));
        assert!(ids.contains(&"w2"));
    }

    // ── Recordings ───────────────────────────────────────

    #[test]
    fn merge_recordings_dedup_by_id() {
        // Local is newer, so local wins on conflict.
        let local = json!({
            "exportedAt": "2024-08-01T00:00:00Z",
            "recordings": [
                {
                    "id": "r1",
                    "title": "LocalRec",
                    "duration": 3600,
                },
            ]
        });
        let cloud = json!({
            "exportedAt": "2024-06-01T00:00:00Z",
            "recordings": [
                {
                    "id": "r1",
                    "title": "CloudRec",
                    "duration": 1800,
                },
            ]
        });
        let result = merge_backups(&local, &cloud, "dev1");
        let recordings = result.get("recordings").and_then(Value::as_array).unwrap();

        assert_eq!(recordings.len(), 1);
        let r1 = &recordings[0];
        assert_eq!(r1.get("title").and_then(Value::as_str), Some("LocalRec"),);
        assert_eq!(r1.get("duration").and_then(Value::as_i64), Some(3600),);
    }

    #[test]
    fn merge_recordings_combines_unique() {
        let local = json!({
            "recordings": [
                {"id": "r1", "title": "RecA"},
            ]
        });
        let cloud = json!({
            "recordings": [
                {"id": "r2", "title": "RecB"},
            ]
        });
        let result = merge_backups(&local, &cloud, "dev1");
        let recordings = result.get("recordings").and_then(Value::as_array).unwrap();

        assert_eq!(recordings.len(), 2);
        let ids: Vec<&str> = recordings
            .iter()
            .filter_map(|r| r.get("id").and_then(Value::as_str))
            .collect();
        assert!(ids.contains(&"r1"));
        assert!(ids.contains(&"r2"));
    }

    // ── Edge Cases ───────────────────────────────────────

    #[test]
    fn merge_empty_local_returns_cloud() {
        let local = json!({});
        let cloud = json!({
            "version": 3,
            "profiles": [
                {"id": "p1", "name": "CloudProfile"},
            ],
            "favorites": {"p1": ["ch1"]},
            "sources": [
                {"name": "S1", "url": "http://s1.com"},
            ],
            "watchHistory": [
                {
                    "id": "w1",
                    "positionMs": 500,
                    "lastWatched":
                        "2024-06-01T12:00:00Z",
                },
            ],
            "recordings": [
                {"id": "r1", "title": "Rec1"},
            ],
        });
        let result = merge_backups(&local, &cloud, "dev1");

        assert_eq!(result.get("version").and_then(Value::as_i64), Some(3),);
        assert_eq!(
            result
                .get("profiles")
                .and_then(Value::as_array)
                .unwrap()
                .len(),
            1,
        );
        assert!(
            result
                .get("favorites")
                .and_then(Value::as_object)
                .unwrap()
                .contains_key("p1"),
        );
        assert_eq!(
            result
                .get("sources")
                .and_then(Value::as_array)
                .unwrap()
                .len(),
            1,
        );
        assert_eq!(
            result
                .get("watchHistory")
                .and_then(Value::as_array)
                .unwrap()
                .len(),
            1,
        );
        assert_eq!(
            result
                .get("recordings")
                .and_then(Value::as_array)
                .unwrap()
                .len(),
            1,
        );
    }

    #[test]
    fn merge_empty_cloud_returns_local() {
        let local = json!({
            "version": 7,
            "profiles": [
                {"id": "p1", "name": "LocalProfile"},
            ],
            "favorites": {"p1": ["ch10", "ch20"]},
            "sources": [
                {"name": "Src", "url": "http://x.com"},
            ],
        });
        let cloud = json!({});
        let result = merge_backups(&local, &cloud, "dev1");

        assert_eq!(result.get("version").and_then(Value::as_i64), Some(7),);
        let profiles = result.get("profiles").and_then(Value::as_array).unwrap();
        assert_eq!(profiles.len(), 1);
        assert_eq!(
            profiles[0].get("name").and_then(Value::as_str),
            Some("LocalProfile"),
        );
        let favs = result.get("favorites").and_then(Value::as_object).unwrap();
        let p1: Vec<&str> = favs
            .get("p1")
            .and_then(Value::as_array)
            .unwrap()
            .iter()
            .filter_map(Value::as_str)
            .collect();
        assert_eq!(p1.len(), 2);
        assert_eq!(
            result
                .get("sources")
                .and_then(Value::as_array)
                .unwrap()
                .len(),
            1,
        );
    }

    // ── determine_sync_direction ──────────────────────

    #[test]
    fn sync_direction_no_cloud_backup_uploads() {
        // cloud_ms == 0 and local exists → upload.
        let dir = determine_sync_direction(1_000_000, 0, 0, "dev1", "");
        assert_eq!(dir, "upload");
    }

    #[test]
    fn sync_direction_no_local_backup_downloads() {
        // local_ms == 0 and cloud exists → download.
        let dir = determine_sync_direction(0, 1_000_000, 0, "", "dev1");
        assert_eq!(dir, "download");
    }

    #[test]
    fn sync_direction_within_tolerance_no_change() {
        // Difference of 3000 ms (< 5000 ms) → no_change.
        let dir = determine_sync_direction(1_003_000, 1_000_000, 0, "dev1", "dev1");
        assert_eq!(dir, "no_change");
    }

    #[test]
    fn sync_direction_same_device_local_newer_uploads() {
        // Same device, local clearly newer → upload.
        let dir = determine_sync_direction(2_000_000, 1_000_000, 500_000, "dev1", "dev1");
        assert_eq!(dir, "upload");
    }

    #[test]
    fn sync_direction_same_device_cloud_newer_downloads() {
        // Same device, cloud clearly newer → download.
        let dir = determine_sync_direction(1_000_000, 2_000_000, 500_000, "dev1", "dev1");
        assert_eq!(dir, "download");
    }

    #[test]
    fn sync_direction_different_device_local_after_sync_conflict() {
        // Different devices + local modified after last sync → conflict.
        let dir = determine_sync_direction(
            2_000_000, // local
            1_800_000, // cloud
            1_500_000, // last_sync
            "phone", "tablet",
        );
        assert_eq!(dir, "conflict");
    }

    #[test]
    fn sync_direction_different_device_local_not_after_sync_downloads() {
        // Different devices but local was NOT modified after last sync → download.
        let dir = determine_sync_direction(
            1_400_000, // local (before last_sync)
            1_800_000, // cloud (newer)
            1_500_000, // last_sync
            "phone", "tablet",
        );
        assert_eq!(dir, "download");
    }

    #[test]
    fn sync_direction_both_zero_no_change() {
        // Both timestamps zero → no_change (nothing to sync).
        let dir = determine_sync_direction(0, 0, 0, "dev1", "dev1");
        assert_eq!(dir, "no_change");
    }

    // ── merge_both_empty_returns_empty (existing) ─────

    #[test]
    fn merge_both_empty_returns_empty() {
        let local = json!({});
        let cloud = json!({});
        let result = merge_backups(&local, &cloud, "dev1");

        assert_eq!(result.get("version").and_then(Value::as_i64), Some(1),);
        assert!(
            result
                .get("profiles")
                .and_then(Value::as_array)
                .unwrap()
                .is_empty(),
        );
        assert!(
            result
                .get("favorites")
                .and_then(Value::as_object)
                .unwrap()
                .is_empty(),
        );
        assert!(
            result
                .get("channelOrders")
                .and_then(Value::as_array)
                .unwrap()
                .is_empty(),
        );
        assert!(
            result
                .get("sourceAccess")
                .and_then(Value::as_object)
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
        assert!(
            result
                .get("recordings")
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
    }
}
