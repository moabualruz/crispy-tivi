//! Domain model structs for CrispyTivi.
//!
//! Each struct maps 1:1 to a Drift SQLite table in the
//! Flutter app's database schema. All types derive
//! `Debug, Clone, Serialize, Deserialize` for
//! interop and diagnostics.

pub mod content_rating;
pub mod stream_quality;
pub use content_rating::ContentRating;

use chrono::NaiveDateTime;
use serde::{Deserialize, Serialize};

// ── Channel ─────────────────────────────────────────

/// A live TV channel from an IPTV source.
///
/// Maps to the `channels` Drift table. Contains
/// stream metadata, EPG identifiers, and catchup
/// configuration.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Channel {
    /// Unique channel identifier.
    pub id: String,
    /// Display name.
    pub name: String,
    /// Direct stream URL.
    pub stream_url: String,
    /// Logical channel number for ordering.
    #[serde(default)]
    pub number: Option<i32>,
    /// Group/category this channel belongs to.
    #[serde(default)]
    pub channel_group: Option<String>,
    /// URL of the channel logo image.
    #[serde(default)]
    pub logo_url: Option<String>,
    /// EPG `tvg-id` for guide matching.
    #[serde(default)]
    pub tvg_id: Option<String>,
    /// EPG `tvg-name` for guide matching.
    #[serde(default)]
    pub tvg_name: Option<String>,
    /// Whether the channel is favorited.
    #[serde(default)]
    pub is_favorite: bool,
    /// Custom user-agent for stream requests.
    #[serde(default)]
    pub user_agent: Option<String>,
    /// Whether catchup/timeshift is available.
    #[serde(default)]
    pub has_catchup: bool,
    /// Number of days of catchup archive.
    #[serde(default)]
    pub catchup_days: i32,
    /// Catchup type (e.g. "flussonic", "xc").
    #[serde(default)]
    pub catchup_type: Option<String>,
    /// Catchup source URL template.
    #[serde(default)]
    pub catchup_source: Option<String>,
    /// Detected resolution (e.g. "HD", "FHD", "4K").
    /// Transient field — populated by parsers, not persisted to DB.
    #[serde(default)]
    pub resolution: Option<String>,
    /// ID of the playlist/source this came from.
    #[serde(default)]
    pub source_id: Option<String>,
    /// When the channel was first imported.
    #[serde(default)]
    pub added_at: Option<NaiveDateTime>,
    /// When the channel was last refreshed.
    #[serde(default)]
    pub updated_at: Option<NaiveDateTime>,
    /// Whether this is a 24/7 loop channel.
    #[serde(default)]
    pub is_247: bool,
}

// ── EpgMapping ────────────────────────────────────────

/// A persisted EPG channel-to-channel mapping.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EpgMapping {
    /// Internal channel ID.
    pub channel_id: String,
    /// XMLTV EPG channel ID.
    pub epg_channel_id: String,
    /// Confidence score (0.0 - 1.0).
    pub confidence: f64,
    /// Matching strategy that produced this mapping.
    pub source: String,
    /// Whether the user has locked this mapping.
    #[serde(default)]
    pub locked: bool,
    /// When the mapping was created (epoch seconds).
    pub created_at: i64,
}

// ── VodItem ─────────────────────────────────────────

/// A video-on-demand item (movie, series, or episode).
///
/// Maps to the `vod_items` Drift table. Covers all
/// VOD content types with optional series/episode
/// metadata for hierarchical browsing.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VodItem {
    /// Unique VOD item identifier.
    pub id: String,
    /// Display name / title.
    pub name: String,
    /// Direct stream URL.
    pub stream_url: String,
    /// Content type: "movie", "series", or "episode".
    #[serde(rename = "type")]
    pub item_type: String,
    /// URL of the poster image.
    #[serde(default)]
    pub poster_url: Option<String>,
    /// URL of the backdrop / fanart image.
    #[serde(default)]
    pub backdrop_url: Option<String>,
    /// Synopsis / plot description.
    #[serde(default)]
    pub description: Option<String>,
    /// Content rating string (e.g. "PG-13").
    #[serde(default)]
    pub rating: Option<String>,
    /// Release year.
    #[serde(default)]
    pub year: Option<i32>,
    /// Duration in minutes.
    #[serde(default)]
    pub duration: Option<i32>,
    /// VOD category / genre.
    #[serde(default)]
    pub category: Option<String>,
    /// Parent series ID (for episodes).
    #[serde(default)]
    pub series_id: Option<String>,
    /// Season number (for episodes).
    #[serde(default)]
    pub season_number: Option<i32>,
    /// Episode number within the season.
    #[serde(default)]
    pub episode_number: Option<i32>,
    /// File extension / container format.
    #[serde(default)]
    pub ext: Option<String>,
    /// Whether the item is favorited.
    #[serde(default)]
    pub is_favorite: bool,
    /// When the item was first imported.
    #[serde(default)]
    pub added_at: Option<NaiveDateTime>,
    /// When the item was last refreshed.
    #[serde(default)]
    pub updated_at: Option<NaiveDateTime>,
    /// ID of the playlist/source this came from.
    #[serde(default)]
    pub source_id: Option<String>,
}

// ── Category ────────────────────────────────────────

/// A content category for live, VOD, or series.
///
/// Maps to the `categories` Drift table. Composite
/// primary key: (`category_type`, `name`).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Category {
    /// Type discriminator: "live", "vod", or "series".
    pub category_type: String,
    /// Human-readable category name.
    pub name: String,
    /// Source this category belongs to.
    #[serde(default)]
    pub source_id: Option<String>,
}

// ── SyncReport ─────────────────────────────────────

/// Result of a source synchronisation operation.
///
/// Returned by `xtream_sync`, `m3u_sync`, and `stalker_sync`
/// functions. Serialised to JSON for the FFI boundary.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct SyncReport {
    /// Number of live channels saved.
    pub channels_count: usize,
    /// Sorted unique channel group names.
    pub channel_groups: Vec<String>,
    /// Number of VOD items saved (movies + series).
    pub vod_count: usize,
    /// Sorted unique VOD category names.
    pub vod_categories: Vec<String>,
    /// EPG URL discovered from M3U header (if any).
    #[serde(default)]
    pub epg_url: Option<String>,
}

// ── SyncProgress ──────────────────────────────────

/// Progress event emitted during source synchronisation.
///
/// Serialised to JSON and pushed to Flutter via FRB
/// `StreamSink` for real-time UI progress updates.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncProgress {
    /// The source being synced.
    pub source_id: String,
    /// Current sync phase.
    pub phase: String,
    /// Progress within the current phase (0.0–1.0).
    pub progress: f64,
    /// Human-readable status message.
    pub message: String,
}

// ── SyncMeta ────────────────────────────────────────

/// Tracks the last synchronisation time per source.
///
/// Maps to the `sync_meta` Drift table. Used to
/// determine whether a playlist refresh is needed.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncMeta {
    /// Source/playlist identifier.
    pub source_id: String,
    /// Timestamp of the last successful sync.
    pub last_sync_time: NaiveDateTime,
}

// ── Setting ─────────────────────────────────────────

/// A key-value application setting.
///
/// Maps to the `settings` Drift table. All values
/// are stored as strings and parsed by the consumer.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Setting {
    /// Setting key (unique).
    pub key: String,
    /// Setting value (string-encoded).
    pub value: String,
}

// ── EpgEntry ────────────────────────────────────────

/// An electronic programme guide entry.
///
/// Maps to the `epg_entries` Drift table. Composite
/// primary key: (`channel_id`, `start_time`).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EpgEntry {
    /// Channel this programme airs on.
    pub channel_id: String,
    /// Programme title.
    pub title: String,
    /// Scheduled start time.
    pub start_time: NaiveDateTime,
    /// Scheduled end time.
    pub end_time: NaiveDateTime,
    /// Programme description / synopsis.
    #[serde(default)]
    pub description: Option<String>,
    /// Programme genre / category.
    #[serde(default)]
    pub category: Option<String>,
    /// URL of the programme icon/thumbnail.
    #[serde(default)]
    pub icon_url: Option<String>,
    /// Source this EPG entry came from.
    #[serde(default)]
    pub source_id: Option<String>,
}

// ── WatchHistory ────────────────────────────────────

/// A playback history entry for resume support.
///
/// Maps to the `watch_history` Drift table. Stores
/// the last playback position so users can resume
/// across sessions and devices.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WatchHistory {
    /// Unique history entry identifier.
    pub id: String,
    /// Content type: "channel", "movie", or "episode".
    pub media_type: String,
    /// Display name of the watched content.
    pub name: String,
    /// Stream URL that was playing.
    pub stream_url: String,
    /// Poster image URL for the history list.
    #[serde(default)]
    pub poster_url: Option<String>,
    /// Fallback show image (series poster) URL.
    #[serde(default)]
    pub series_poster_url: Option<String>,
    /// Playback position in milliseconds.
    #[serde(default)]
    pub position_ms: i64,
    /// Total duration in milliseconds.
    #[serde(default)]
    pub duration_ms: i64,
    /// When this content was last watched.
    pub last_watched: NaiveDateTime,
    /// Parent series ID (for episodes).
    #[serde(default)]
    pub series_id: Option<String>,
    /// Season number (for episodes).
    #[serde(default)]
    pub season_number: Option<i32>,
    /// Episode number (for episodes).
    #[serde(default)]
    pub episode_number: Option<i32>,
    /// Device ID for multi-device sync.
    #[serde(default)]
    pub device_id: Option<String>,
    /// Human-readable device name.
    #[serde(default)]
    pub device_name: Option<String>,
    /// Profile ID this history belongs to.
    #[serde(default)]
    pub profile_id: Option<String>,
    /// Which source/playlist this stream belongs to.
    #[serde(default)]
    pub source_id: Option<String>,
}

// ── UserProfile ─────────────────────────────────────

/// A user profile with parental controls and roles.
///
/// Maps to the `user_profiles` Drift table. Supports
/// multi-profile households with per-profile
/// permissions and content restrictions.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserProfile {
    /// Unique profile identifier.
    pub id: String,
    /// Display name.
    pub name: String,
    /// Index into the avatar asset list.
    #[serde(default)]
    pub avatar_index: i32,
    /// Optional PIN for profile lock.
    #[serde(default)]
    pub pin: Option<String>,
    /// Whether this is a child/restricted profile.
    #[serde(default)]
    pub is_child: bool,
    /// PIN version counter for rotation tracking.
    #[serde(default)]
    pub pin_version: i32,
    /// Maximum allowed content rating (0-4 scale).
    #[serde(default = "default_max_rating")]
    pub max_allowed_rating: i32,
    /// Profile role: 0=admin, 1=viewer, 2=restricted.
    #[serde(default = "default_role")]
    pub role: i32,
    /// DVR permission level.
    #[serde(default = "default_dvr_permission")]
    pub dvr_permission: i32,
    /// DVR storage quota in megabytes.
    #[serde(default)]
    pub dvr_quota_mb: Option<i32>,
}

fn default_max_rating() -> i32 {
    4
}

fn default_role() -> i32 {
    1
}

fn default_dvr_permission() -> i32 {
    2
}

// ── UserFavorite ────────────────────────────────────

/// A per-profile channel favourite.
///
/// Maps to the `user_favorites` Drift table. Composite
/// primary key: (`profile_id`, `channel_id`).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserFavorite {
    /// Profile that owns this favourite.
    pub profile_id: String,
    /// Favourited channel ID.
    pub channel_id: String,
    /// When the favourite was added.
    pub added_at: NaiveDateTime,
}

// ── VodFavorite ─────────────────────────────────────

/// A per-profile VOD favourite.
///
/// Maps to the `vod_favorites` Drift table. Composite
/// primary key: (`profile_id`, `vod_item_id`).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VodFavorite {
    /// Profile that owns this favourite.
    pub profile_id: String,
    /// Favourited VOD item ID.
    pub vod_item_id: String,
    /// When the favourite was added.
    pub added_at: NaiveDateTime,
}

// ── FavoriteCategory ────────────────────────────────

/// A per-profile favourite category bookmark.
///
/// Maps to the `favorite_categories` Drift table.
/// Composite primary key: (`profile_id`,
/// `category_type`, `category_name`).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FavoriteCategory {
    /// Profile that owns this favourite.
    pub profile_id: String,
    /// Type: "live", "vod", or "series".
    pub category_type: String,
    /// Name of the favourited category.
    pub category_name: String,
    /// When the favourite was added.
    pub added_at: NaiveDateTime,
}

// ── ProfileSourceAccess ─────────────────────────────

/// Grants a profile access to a specific source.
///
/// Maps to the `profile_source_access` Drift table.
/// Composite primary key: (`profile_id`, `source_id`).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProfileSourceAccess {
    /// Profile receiving access.
    pub profile_id: String,
    /// Source/playlist being granted.
    pub source_id: String,
    /// When access was granted.
    pub granted_at: NaiveDateTime,
}

// ── Source ─────────────────────────────────────────

/// A content source (IPTV provider or media server).
///
/// Maps to the `db_sources` table. Replaces the old
/// JSON blob in `db_settings`. All content (channels,
/// VOD, EPG) references its source via `source_id`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Source {
    /// Unique source identifier (e.g. "src_1709834567890").
    pub id: String,
    /// Human-readable source name.
    pub name: String,
    /// Source type discriminator.
    pub source_type: String,
    /// Server/playlist URL.
    pub url: String,
    /// Username (Xtream).
    #[serde(default)]
    pub username: Option<String>,
    /// Password (Xtream).
    #[serde(default)]
    pub password: Option<String>,
    /// Access token (Plex/Emby/Jellyfin).
    #[serde(default)]
    pub access_token: Option<String>,
    /// Device identifier (Emby/Jellyfin).
    #[serde(default)]
    pub device_id: Option<String>,
    /// User ID on the server (Emby/Jellyfin).
    #[serde(default)]
    pub user_id: Option<String>,
    /// MAC address (Stalker).
    #[serde(default)]
    pub mac_address: Option<String>,
    /// EPG source URL.
    #[serde(default)]
    pub epg_url: Option<String>,
    /// Custom HTTP user-agent.
    #[serde(default)]
    pub user_agent: Option<String>,
    /// Auto-refresh interval in minutes.
    #[serde(default = "default_refresh_interval")]
    pub refresh_interval_minutes: i32,
    /// Accept self-signed TLS certs.
    #[serde(default)]
    pub accept_self_signed: bool,
    /// Whether this source is enabled.
    #[serde(default = "default_true_for_source")]
    pub enabled: bool,
    /// Sort/priority order (lower = higher priority).
    #[serde(default)]
    pub sort_order: i32,
    /// Last sync timestamp.
    #[serde(default)]
    pub last_sync_time: Option<NaiveDateTime>,
    /// Last sync status: "success", "error", "syncing".
    #[serde(default)]
    pub last_sync_status: Option<String>,
    /// Last sync error message.
    #[serde(default)]
    pub last_sync_error: Option<String>,
    /// When the source was created.
    #[serde(default)]
    pub created_at: Option<NaiveDateTime>,
    /// When the source was last updated.
    #[serde(default)]
    pub updated_at: Option<NaiveDateTime>,
    /// Whether `password`, `access_token`, `mac_address`, and `device_id`
    /// are stored as AES-256-GCM ciphertext (Base64-encoded).
    ///
    /// `false` means plaintext (legacy rows); the service layer re-encrypts
    /// on first load and sets this to `true`.
    #[serde(default)]
    pub credentials_encrypted: bool,
}

// ── SourceStats ─────────────────────────────────────

/// Per-source content counts.
///
/// Returned by `get_source_stats()`. Summarises how many
/// channels and VOD items belong to each source.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SourceStats {
    /// Source identifier.
    pub source_id: String,
    /// Number of live channels for this source.
    pub channel_count: i64,
    /// Number of VOD items for this source.
    pub vod_count: i64,
}

fn default_refresh_interval() -> i32 {
    60
}

fn default_true_for_source() -> bool {
    true
}

// ── Recording ───────────────────────────────────────

/// A DVR recording (scheduled, in-progress, or done).
///
/// Maps to the `recordings` Drift table. Supports
/// one-off and recurring recordings with remote
/// storage backend references.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Recording {
    /// Unique recording identifier.
    pub id: String,
    /// Channel ID being recorded.
    #[serde(default)]
    pub channel_id: Option<String>,
    /// Human-readable channel name.
    pub channel_name: String,
    /// Channel logo URL for display.
    #[serde(default)]
    pub channel_logo_url: Option<String>,
    /// Name of the programme being recorded.
    pub program_name: String,
    /// Stream URL for the recording source.
    #[serde(default)]
    pub stream_url: Option<String>,
    /// Scheduled/actual start time.
    pub start_time: NaiveDateTime,
    /// Scheduled/actual end time.
    pub end_time: NaiveDateTime,
    /// Recording status: "scheduled", "recording",
    /// "completed", or "failed".
    pub status: String,
    /// Local file path of the recorded file.
    #[serde(default)]
    pub file_path: Option<String>,
    /// File size in bytes.
    #[serde(default)]
    pub file_size_bytes: Option<i64>,
    /// Whether this is a recurring recording.
    #[serde(default)]
    pub is_recurring: bool,
    /// Bitmask of days for recurrence (Mon=1..Sun=64).
    #[serde(default)]
    pub recur_days: i32,
    /// Profile that owns this recording.
    #[serde(default)]
    pub owner_profile_id: Option<String>,
    /// Whether the recording is shared with all
    /// profiles.
    #[serde(default = "default_true")]
    pub is_shared: bool,
    /// ID on a remote storage backend.
    #[serde(default)]
    pub remote_backend_id: Option<String>,
    /// Path on the remote storage backend.
    #[serde(default)]
    pub remote_path: Option<String>,
}

fn default_true() -> bool {
    true
}

// ── StorageBackend ──────────────────────────────────

/// A configured storage backend for recordings.
///
/// Maps to the `storage_backends` Drift table. The
/// `config` field holds a JSON-encoded configuration
/// object whose shape depends on `backend_type`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StorageBackend {
    /// Unique backend identifier.
    pub id: String,
    /// Human-readable backend name.
    pub name: String,
    /// Backend type: "local", "s3", "webdav", "smb",
    /// "googleDrive", or "ftp".
    pub backend_type: String,
    /// JSON-encoded configuration object.
    pub config: String,
    /// Whether this is the default backend.
    #[serde(default)]
    pub is_default: bool,
}

// ── TransferTask ────────────────────────────────────

/// A file transfer task between local and remote
/// storage.
///
/// Maps to the `transfer_tasks` Drift table. Tracks
/// upload/download progress for recording files.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransferTask {
    /// Unique task identifier.
    pub id: String,
    /// Recording being transferred.
    pub recording_id: String,
    /// Target/source storage backend.
    pub backend_id: String,
    /// Transfer direction: "upload" or "download".
    pub direction: String,
    /// Task status: "queued", "active", "paused",
    /// "completed", or "failed".
    pub status: String,
    /// Total file size in bytes.
    #[serde(default)]
    pub total_bytes: i64,
    /// Bytes transferred so far.
    #[serde(default)]
    pub transferred_bytes: i64,
    /// When the task was created.
    pub created_at: NaiveDateTime,
    /// Error message if the task failed.
    #[serde(default)]
    pub error_message: Option<String>,
    /// Path on the remote backend.
    #[serde(default)]
    pub remote_path: Option<String>,
}

// ── SavedLayout ─────────────────────────────────────

/// A saved multi-view layout configuration.
///
/// Maps to the `saved_layouts` Drift table. The
/// `streams` field holds a JSON array of stream
/// URLs / channel references.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SavedLayout {
    /// Unique layout identifier.
    pub id: String,
    /// Human-readable layout name.
    pub name: String,
    /// Layout enum name (e.g. "pip", "quad", "grid").
    pub layout: String,
    /// JSON array of stream references.
    pub streams: String,
    /// When the layout was created.
    pub created_at: NaiveDateTime,
}

// ── SearchHistory ───────────────────────────────────

/// A saved search query for autocomplete / history.
///
/// Maps to the `search_history` Drift table.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchHistory {
    /// Unique entry identifier.
    pub id: String,
    /// The search query text.
    pub query: String,
    /// When the search was performed.
    pub searched_at: NaiveDateTime,
    /// Number of results returned.
    #[serde(default)]
    pub result_count: i32,
}

// ── Bookmark ───────────────────────────────────────

/// A user-defined timestamp pin in a video.
///
/// Maps to the `db_bookmarks` table. Stores bookmark
/// position so users can mark and return to specific
/// moments across app restarts.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Bookmark {
    /// Unique bookmark identifier.
    pub id: String,
    /// Content identifier (channel ID or VOD item ID).
    pub content_id: String,
    /// Content type: "channel" or "vod".
    pub content_type: String,
    /// Playback position in milliseconds.
    pub position_ms: i64,
    /// Optional user label (e.g. "Best scene").
    #[serde(default)]
    pub label: Option<String>,
    /// When the bookmark was created.
    pub created_at: NaiveDateTime,
}

// ── ChannelOrder ────────────────────────────────────

/// A per-profile custom channel sort order within a
/// group.
///
/// Maps to the `channel_orders` Drift table. Composite
/// primary key: (`profile_id`, `group_name`,
/// `channel_id`).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChannelOrder {
    /// Profile that owns this ordering.
    pub profile_id: String,
    /// Channel group name.
    pub group_name: String,
    /// Channel being ordered.
    pub channel_id: String,
    /// Zero-based sort position.
    pub sort_index: i32,
}

// ── Reminder ────────────────────────────────────────

/// A programme reminder / notification schedule.
///
/// Maps to the `reminders` Drift table. Fires a
/// notification at `notify_at` to alert the user
/// about an upcoming programme.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Reminder {
    /// Unique reminder identifier.
    pub id: String,
    /// Name of the programme to remind about.
    pub program_name: String,
    /// Channel the programme airs on.
    pub channel_name: String,
    /// Programme start time.
    pub start_time: NaiveDateTime,
    /// When to fire the notification.
    pub notify_at: NaiveDateTime,
    /// Whether the reminder has already fired.
    #[serde(default)]
    pub fired: bool,
    /// Profile that created this reminder.
    #[serde(default)]
    pub profile_id: Option<String>,
    /// When the reminder was created.
    pub created_at: NaiveDateTime,
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::NaiveDateTime;

    fn dummy_dt() -> NaiveDateTime {
        NaiveDateTime::from_timestamp_opt(0, 0).unwrap()
    }

    // ── SyncReport ──────────────────────────────────

    #[test]
    fn test_sync_report_default_has_zero_counts() {
        let r = SyncReport::default();
        assert_eq!(r.channels_count, 0);
        assert_eq!(r.vod_count, 0);
        assert!(r.channel_groups.is_empty());
        assert!(r.vod_categories.is_empty());
        assert!(r.epg_url.is_none());
    }

    #[test]
    fn test_sync_report_roundtrips_via_serde() {
        let r = SyncReport {
            channels_count: 5,
            channel_groups: vec!["News".to_string(), "Sports".to_string()],
            vod_count: 10,
            vod_categories: vec!["Action".to_string()],
            epg_url: Some("http://epg.example.com".to_string()),
        };
        let json = serde_json::to_string(&r).unwrap();
        let back: SyncReport = serde_json::from_str(&json).unwrap();
        assert_eq!(back.channels_count, 5);
        assert_eq!(back.vod_count, 10);
        assert_eq!(back.epg_url.as_deref(), Some("http://epg.example.com"));
        assert_eq!(back.channel_groups, vec!["News", "Sports"]);
    }

    // ── Channel ─────────────────────────────────────

    #[test]
    fn test_channel_required_fields_are_preserved() {
        let ch = Channel {
            id: "ch1".to_string(),
            name: "BBC One".to_string(),
            stream_url: "http://stream.example.com/bbc1".to_string(),
            number: Some(1),
            channel_group: Some("News".to_string()),
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
        };
        assert_eq!(ch.id, "ch1");
        assert_eq!(ch.name, "BBC One");
        assert_eq!(ch.stream_url, "http://stream.example.com/bbc1");
        assert_eq!(ch.number, Some(1));
        assert!(!ch.is_favorite);
        assert!(!ch.has_catchup);
        assert!(!ch.is_247);
    }

    #[test]
    fn test_channel_serde_default_fields_omit_none() {
        let json = r#"{"id":"c","name":"n","stream_url":"u"}"#;
        let ch: Channel = serde_json::from_str(json).unwrap();
        assert_eq!(ch.id, "c");
        assert!(ch.number.is_none());
        assert!(ch.channel_group.is_none());
        assert!(!ch.is_favorite);
        assert_eq!(ch.catchup_days, 0);
        assert!(!ch.has_catchup);
    }

    #[test]
    fn test_channel_clone_is_independent() {
        let ch = Channel {
            id: "ch1".to_string(),
            name: "Original".to_string(),
            stream_url: "u".to_string(),
            number: None,
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
        };
        let mut cloned = ch.clone();
        cloned.name = "Clone".to_string();
        assert_eq!(ch.name, "Original");
        assert_eq!(cloned.name, "Clone");
    }

    // ── VodItem ─────────────────────────────────────

    #[test]
    fn test_vod_item_serde_required_and_defaults() {
        let json = r#"{"id":"v1","name":"Inception","stream_url":"u","type":"movie"}"#;
        let v: VodItem = serde_json::from_str(json).unwrap();
        assert_eq!(v.id, "v1");
        assert_eq!(v.item_type, "movie");
        assert!(v.poster_url.is_none());
        assert!(v.year.is_none());
        assert!(v.duration.is_none());
        assert!(!v.is_favorite);
        assert!(v.series_id.is_none());
    }

    #[test]
    fn test_vod_item_episode_type_preserved() {
        let json = r#"{"id":"e1","name":"Ep1","stream_url":"u","type":"episode","series_id":"s1","season_number":2,"episode_number":3}"#;
        let v: VodItem = serde_json::from_str(json).unwrap();
        assert_eq!(v.item_type, "episode");
        assert_eq!(v.series_id.as_deref(), Some("s1"));
        assert_eq!(v.season_number, Some(2));
        assert_eq!(v.episode_number, Some(3));
    }

    // ── Category ────────────────────────────────────

    #[test]
    fn test_category_roundtrips_via_serde() {
        let c = Category {
            category_type: "live".to_string(),
            name: "Sports".to_string(),
            source_id: Some("src1".to_string()),
        };
        let json = serde_json::to_string(&c).unwrap();
        let back: Category = serde_json::from_str(&json).unwrap();
        assert_eq!(back.category_type, "live");
        assert_eq!(back.name, "Sports");
        assert_eq!(back.source_id.as_deref(), Some("src1"));
    }

    #[test]
    fn test_category_source_id_defaults_to_none() {
        let json = r#"{"category_type":"vod","name":"Action"}"#;
        let c: Category = serde_json::from_str(json).unwrap();
        assert!(c.source_id.is_none());
    }

    // ── Setting ─────────────────────────────────────

    #[test]
    fn test_setting_roundtrips_via_serde() {
        let s = Setting {
            key: "theme".to_string(),
            value: "dark".to_string(),
        };
        let json = serde_json::to_string(&s).unwrap();
        let back: Setting = serde_json::from_str(&json).unwrap();
        assert_eq!(back.key, "theme");
        assert_eq!(back.value, "dark");
    }

    // ── Source ──────────────────────────────────────

    #[test]
    fn test_source_default_refresh_interval_is_60() {
        let json = r#"{"id":"s1","name":"My IPTV","source_type":"m3u","url":"http://x.m3u"}"#;
        let s: Source = serde_json::from_str(json).unwrap();
        assert_eq!(s.refresh_interval_minutes, 60);
    }

    #[test]
    fn test_source_enabled_defaults_to_true() {
        let json = r#"{"id":"s1","name":"My IPTV","source_type":"m3u","url":"http://x.m3u"}"#;
        let s: Source = serde_json::from_str(json).unwrap();
        assert!(s.enabled);
    }

    #[test]
    fn test_source_optional_fields_default_to_none() {
        let json = r#"{"id":"s1","name":"n","source_type":"m3u","url":"u"}"#;
        let s: Source = serde_json::from_str(json).unwrap();
        assert!(s.username.is_none());
        assert!(s.password.is_none());
        assert!(s.mac_address.is_none());
        assert!(s.epg_url.is_none());
        assert!(s.last_sync_time.is_none());
        assert!(s.last_sync_status.is_none());
        assert!(s.last_sync_error.is_none());
    }

    #[test]
    fn test_source_accept_self_signed_defaults_false() {
        let json = r#"{"id":"s1","name":"n","source_type":"m3u","url":"u"}"#;
        let s: Source = serde_json::from_str(json).unwrap();
        assert!(!s.accept_self_signed);
    }

    // ── UserProfile ─────────────────────────────────

    #[test]
    fn test_user_profile_max_rating_defaults_to_4() {
        let json = r#"{"id":"p1","name":"Alice"}"#;
        let p: UserProfile = serde_json::from_str(json).unwrap();
        assert_eq!(p.max_allowed_rating, 4);
    }

    #[test]
    fn test_user_profile_role_defaults_to_1() {
        let json = r#"{"id":"p1","name":"Alice"}"#;
        let p: UserProfile = serde_json::from_str(json).unwrap();
        assert_eq!(p.role, 1);
    }

    #[test]
    fn test_user_profile_dvr_permission_defaults_to_2() {
        let json = r#"{"id":"p1","name":"Alice"}"#;
        let p: UserProfile = serde_json::from_str(json).unwrap();
        assert_eq!(p.dvr_permission, 2);
    }

    #[test]
    fn test_user_profile_is_child_defaults_false() {
        let json = r#"{"id":"p1","name":"Bob"}"#;
        let p: UserProfile = serde_json::from_str(json).unwrap();
        assert!(!p.is_child);
        assert!(p.pin.is_none());
    }

    // ── Recording ───────────────────────────────────

    #[test]
    fn test_recording_is_shared_defaults_true() {
        let now = dummy_dt();
        let r = Recording {
            id: "r1".to_string(),
            channel_id: None,
            channel_name: "ESPN".to_string(),
            channel_logo_url: None,
            program_name: "Match".to_string(),
            stream_url: None,
            start_time: now,
            end_time: now,
            status: "scheduled".to_string(),
            file_path: None,
            file_size_bytes: None,
            is_recurring: false,
            recur_days: 0,
            owner_profile_id: None,
            is_shared: default_true(),
            remote_backend_id: None,
            remote_path: None,
        };
        assert!(r.is_shared);
        assert!(!r.is_recurring);
    }

    #[test]
    fn test_recording_status_field_preserved() {
        let now = dummy_dt();
        let r = Recording {
            id: "r1".to_string(),
            channel_id: Some("ch1".to_string()),
            channel_name: "CNN".to_string(),
            channel_logo_url: None,
            program_name: "News".to_string(),
            stream_url: Some("http://s".to_string()),
            start_time: now,
            end_time: now,
            status: "completed".to_string(),
            file_path: Some("/recordings/news.ts".to_string()),
            file_size_bytes: Some(1_048_576),
            is_recurring: false,
            recur_days: 0,
            owner_profile_id: None,
            is_shared: true,
            remote_backend_id: None,
            remote_path: None,
        };
        assert_eq!(r.status, "completed");
        assert_eq!(r.file_size_bytes, Some(1_048_576));
    }

    // ── WatchHistory ────────────────────────────────

    #[test]
    fn test_watch_history_position_and_duration_default_to_zero() {
        let json = r#"{"id":"h1","media_type":"channel","name":"BBC","stream_url":"u","last_watched":"1970-01-01T00:00:00"}"#;
        let h: WatchHistory = serde_json::from_str(json).unwrap();
        assert_eq!(h.position_ms, 0);
        assert_eq!(h.duration_ms, 0);
        assert!(h.device_id.is_none());
        assert!(h.profile_id.is_none());
    }

    // ── EpgMapping ──────────────────────────────────

    #[test]
    fn test_epg_mapping_locked_defaults_false() {
        let json = r#"{"channel_id":"c1","epg_channel_id":"e1","confidence":0.9,"source":"tvg-id","created_at":0}"#;
        let m: EpgMapping = serde_json::from_str(json).unwrap();
        assert!(!m.locked);
        assert_eq!(m.confidence, 0.9);
    }

    // ── SourceStats ─────────────────────────────────

    #[test]
    fn test_source_stats_roundtrips_via_serde() {
        let s = SourceStats {
            source_id: "src1".to_string(),
            channel_count: 100,
            vod_count: 500,
        };
        let json = serde_json::to_string(&s).unwrap();
        let back: SourceStats = serde_json::from_str(&json).unwrap();
        assert_eq!(back.source_id, "src1");
        assert_eq!(back.channel_count, 100);
        assert_eq!(back.vod_count, 500);
    }

    // ── Bookmark ────────────────────────────────────

    #[test]
    fn test_bookmark_label_defaults_to_none() {
        let now = dummy_dt();
        let b = Bookmark {
            id: "bk1".to_string(),
            content_id: "ch1".to_string(),
            content_type: "channel".to_string(),
            position_ms: 12345,
            label: None,
            created_at: now,
        };
        assert!(b.label.is_none());
        assert_eq!(b.position_ms, 12345);
    }

    // ── SearchHistory ───────────────────────────────

    #[test]
    fn test_search_history_result_count_defaults_zero() {
        let json = r#"{"id":"sh1","query":"breaking news","searched_at":"1970-01-01T00:00:00"}"#;
        let s: SearchHistory = serde_json::from_str(json).unwrap();
        assert_eq!(s.result_count, 0);
        assert_eq!(s.query, "breaking news");
    }
}
