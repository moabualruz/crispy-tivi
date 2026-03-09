//! Data-change events emitted by `CrispyService` after
//! mutations. Consumed by the FFI bridge (via
//! `StreamSink`) and WebSocket server (via broadcast
//! channel) to push updates to Flutter.

use std::sync::Arc;

use serde::Serialize;

/// Every variant represents a mutation category that
/// Flutter may need to react to. Serialized as
/// `{"type":"VariantName", ...fields}` via serde.
#[derive(Debug, Clone, Serialize)]
#[serde(tag = "type")]
pub enum DataChangeEvent {
    // ── Channels / Playlists ──────────────────────
    ChannelsUpdated {
        source_id: String,
    },
    CategoriesUpdated {
        source_id: String,
    },
    ChannelOrderChanged,

    // ── EPG ───────────────────────────────────────
    EpgUpdated {
        source_id: String,
    },

    // ── Watch history ─────────────────────────────
    WatchHistoryUpdated {
        channel_id: String,
    },
    WatchHistoryCleared,

    // ── Favorites ─────────────────────────────────
    FavoriteToggled {
        item_id: String,
        is_favorite: bool,
    },
    FavoriteCategoryToggled {
        category_type: String,
        category_name: String,
    },

    // ── VOD ───────────────────────────────────────
    VodUpdated {
        source_id: String,
    },
    VodFavoriteToggled {
        vod_id: String,
        is_favorite: bool,
    },
    VodWatchProgressUpdated {
        vod_id: String,
    },

    // ── Recordings / DVR ──────────────────────────
    WatchlistUpdated {
        profile_id: String,
    },
    RecordingChanged {
        recording_id: String,
    },
    StorageBackendChanged {
        backend_id: String,
    },
    TransferTaskChanged {
        task_id: String,
    },

    // ── Profiles ──────────────────────────────────
    ProfileChanged {
        profile_id: String,
    },

    // ── Sources ──────────────────────────────────
    SourceChanged {
        source_id: String,
    },
    SourceDeleted {
        source_id: String,
    },

    // ── Settings ──────────────────────────────────
    SettingsUpdated {
        key: String,
    },

    // ── Misc UI data ──────────────────────────────
    BookmarkChanged,
    SavedLayoutChanged,
    SearchHistoryChanged,
    ReminderChanged,
    SmartGroupChanged,

    // ── Bulk ──────────────────────────────────────
    CloudSyncCompleted,
    BulkDataRefresh,
}

/// Callback type for event delivery. Stored in
/// `CrispyService` behind `Arc<Mutex<Option<…>>>`.
pub type EventCallback = Arc<dyn Fn(&DataChangeEvent) + Send + Sync>;

/// Serialize an event to a JSON string for bridge
/// transport. Falls back to `BulkDataRefresh` if
/// serialization fails (shouldn't happen).
pub fn serialize_event(event: &DataChangeEvent) -> String {
    serde_json::to_string(event).unwrap_or_else(|_| r#"{"type":"BulkDataRefresh"}"#.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn serialize_channels_updated() {
        let e = DataChangeEvent::ChannelsUpdated {
            source_id: "src1".into(),
        };
        let json = serialize_event(&e);
        assert!(json.contains(r#""type":"ChannelsUpdated""#));
        assert!(json.contains(r#""source_id":"src1""#));
    }

    #[test]
    fn serialize_favorite_toggled() {
        let e = DataChangeEvent::FavoriteToggled {
            item_id: "ch42".into(),
            is_favorite: true,
        };
        let json = serialize_event(&e);
        assert!(json.contains(r#""type":"FavoriteToggled""#));
        assert!(json.contains(r#""is_favorite":true"#));
    }

    #[test]
    fn serialize_unit_variants() {
        let e = DataChangeEvent::BulkDataRefresh;
        let json = serialize_event(&e);
        assert_eq!(json, r#"{"type":"BulkDataRefresh"}"#);
    }

    #[test]
    fn serialize_watch_history_cleared() {
        let e = DataChangeEvent::WatchHistoryCleared;
        let json = serialize_event(&e);
        assert_eq!(json, r#"{"type":"WatchHistoryCleared"}"#);
    }

    #[test]
    fn serialize_settings_updated() {
        let e = DataChangeEvent::SettingsUpdated {
            key: "theme".into(),
        };
        let json = serialize_event(&e);
        assert!(json.contains(r#""key":"theme""#));
    }

    #[test]
    fn serialize_vod_favorite_toggled() {
        let e = DataChangeEvent::VodFavoriteToggled {
            vod_id: "vod99".into(),
            is_favorite: false,
        };
        let json = serialize_event(&e);
        assert!(json.contains(r#""vod_id":"vod99""#));
        assert!(json.contains(r#""is_favorite":false"#));
    }

    #[test]
    fn serialize_recording_changed() {
        let e = DataChangeEvent::RecordingChanged {
            recording_id: "rec1".into(),
        };
        let json = serialize_event(&e);
        assert!(json.contains(r#""recording_id":"rec1""#));
    }

    #[test]
    fn serialize_all_unit_variants() {
        for e in [
            DataChangeEvent::WatchHistoryCleared,
            DataChangeEvent::ChannelOrderChanged,
            DataChangeEvent::BookmarkChanged,
            DataChangeEvent::SavedLayoutChanged,
            DataChangeEvent::SearchHistoryChanged,
            DataChangeEvent::ReminderChanged,
            DataChangeEvent::CloudSyncCompleted,
            DataChangeEvent::BulkDataRefresh,
        ] {
            let json = serialize_event(&e);
            assert!(json.starts_with(r#"{"type":""#), "{json}");
        }
    }
}
