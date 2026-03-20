//! Event types for the three-queue bidirectional event bus.
//!
//! `ChannelsReady`, `MoviesReady`, and `SeriesReady` carry `Arc<Vec<T>>` so
//! SharedData can share ownership without copying the full dataset.
//!
//! # Queue Architecture
//!
//! - **PlayerEvent** — bridge-local, instant delivery (pause, seek, volume, etc.)
//! - **HighPriorityEvent** — DataEngine queue, biased first (navigation, playback, search)
//! - **NormalEvent** — DataEngine queue, processed when high-priority queue is empty
//!
//! # No Slint Types
//!
//! All types in this module are plain Rust. Conversion to/from Slint-generated
//! types happens in `event_bridge.rs`.

use std::sync::Arc;

// ── Screen ──────────────────────────────────────────────────────────────────

/// App screens, indexed to match the Slint `ActiveScreen` enum.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[repr(i32)]
pub enum Screen {
    Home = 0,
    LiveTv = 1,
    Epg = 2,
    Movies = 3,
    Series = 4,
    Search = 5,
    Library = 6,
    Settings = 7,
}

impl Screen {
    /// Convert from an i32 discriminant. Returns `None` for unknown values.
    pub fn from_i32(v: i32) -> Option<Self> {
        match v {
            0 => Some(Self::Home),
            1 => Some(Self::LiveTv),
            2 => Some(Self::Epg),
            3 => Some(Self::Movies),
            4 => Some(Self::Series),
            5 => Some(Self::Search),
            6 => Some(Self::Library),
            7 => Some(Self::Settings),
            _ => None,
        }
    }
}

// ── SourceInput ─────────────────────────────────────────────────────────────

/// User-supplied input when adding or editing a source.
///
/// Fields are type-gated by `source_type`:
/// - M3U: `url` required
/// - Xtream Codes: `url`, `username`, `password` required
/// - Stalker Portal: `url`, `mac_address` required
/// - `epg_url` is optional for all types
#[derive(Clone)]
pub struct SourceInput {
    /// Human-readable label chosen by the user.
    pub name: String,
    /// Discriminator: `"m3u"`, `"xtream"`, or `"stalker"`.
    pub source_type: String,
    /// Server or playlist URL.
    pub url: String,
    /// Xtream Codes username (empty string when unused).
    pub username: String,
    /// Xtream Codes password (empty string when unused).
    pub password: String,
    /// Stalker Portal MAC address (empty string when unused).
    pub mac_address: String,
    /// Optional external EPG source URL.
    pub epg_url: String,
}

impl std::fmt::Debug for SourceInput {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("SourceInput")
            .field("name", &self.name)
            .field("source_type", &self.source_type)
            .field("url", &self.url)
            .field("username", &self.username)
            .field("password", &"[REDACTED]")
            .field("mac_address", &self.mac_address)
            .field("epg_url", &self.epg_url)
            .finish()
    }
}

// ── LoadingKind ─────────────────────────────────────────────────────────────

/// Identifies what category of content is currently loading.
#[derive(Debug, Clone)]
pub enum LoadingKind {
    Channels,
    Movies,
    Series,
    Search,
    Sync,
}

// ── Intermediate info structs ────────────────────────────────────────────────

/// Lightweight channel descriptor passed from DataEngine to EventBridge.
///
/// Mirrors the essential display fields of `crispy_core::models::Channel`
/// without pulling in the full domain model into the UI event layer.
#[derive(Debug, Clone, Default)]
pub struct ChannelInfo {
    pub id: String,
    pub name: String,
    pub stream_url: String,
    pub logo_url: Option<String>,
    pub channel_group: Option<String>,
    pub number: Option<i32>,
    pub is_favorite: bool,
    pub source_id: Option<String>,
    pub resolution: Option<String>,
    pub has_catchup: bool,
}

/// Lightweight watch history entry passed from DataEngine to EventBridge.
#[derive(Debug, Clone, Default)]
pub struct WatchHistoryInfo {
    /// Unique history entry ID (derived from stream URL).
    pub id: String,
    /// Display name of the watched content.
    pub name: String,
    /// Content type: `"channel"`, `"movie"`, or `"episode"`.
    pub media_type: String,
    /// Stream URL for resume.
    pub stream_url: String,
    /// Playback position in milliseconds.
    pub position_ms: i64,
    /// Total duration in milliseconds (0 for live).
    pub duration_ms: i64,
    /// ISO-8601 timestamp of last watch.
    pub watched_at: String,
    /// Poster image URL (optional).
    #[allow(dead_code)]
    // Populated by history loader, consumed when Library history tab renders
    pub poster_url: Option<String>,
}

/// Continue-watching item for the home screen lane (J-17/J-21).
#[allow(dead_code)] // Incrementally wired — consumed when home screen continue-watching lane is connected
#[derive(Debug, Clone, Default)]
pub struct ContinueWatchingInfo {
    /// Watch history entry ID (derived from stream URL).
    pub id: String,
    /// Display title.
    pub title: String,
    /// Poster image URL (optional).
    pub image_url: Option<String>,
    /// Fractional progress 0.0–1.0.
    pub progress: f32,
    /// `"channel"`, `"movie"`, or `"episode"`.
    pub content_type: String,
}

/// Lightweight VOD descriptor passed from DataEngine to EventBridge.
///
/// Covers both movies and series/episodes.
#[derive(Debug, Clone, Default)]
pub struct VodInfo {
    pub id: String,
    pub name: String,
    pub stream_url: String,
    /// `"movie"`, `"series"`, or `"episode"`.
    pub item_type: String,
    pub poster_url: Option<String>,
    pub backdrop_url: Option<String>,
    pub description: Option<String>,
    pub rating: Option<String>,
    pub year: Option<i32>,
    pub duration_minutes: Option<i32>,
    pub source_id: Option<String>,
    pub is_favorite: bool,
}

/// Lightweight source descriptor passed from DataEngine to EventBridge.
///
/// Derived from `crispy_core::models::Source` — only display fields.
#[derive(Debug, Clone, Default)]
#[allow(dead_code)] // enabled + last_sync_error wired in Epoch 1 (Settings screen)
pub struct SourceInfo {
    pub id: String,
    pub name: String,
    /// Discriminator: `"m3u"`, `"xtream"`, or `"stalker"`.
    pub source_type: String,
    pub url: String,
    pub enabled: bool,
    pub last_sync_status: Option<String>,
    pub last_sync_error: Option<String>,
}

// ── SyncResult ──────────────────────────────────────────────────────────────

/// Outcome of a source synchronisation attempt.
#[derive(Debug)]
pub enum SyncResult {
    /// Sync completed successfully.
    Success {
        source_id: String,
        channel_count: u32,
        vod_count: u32,
    },
    /// Sync failed with a human-readable error.
    Failed { source_id: String, error: String },
}

// ── PlayerEvent ─────────────────────────────────────────────────────────────

/// Bridge-local player control events — instant delivery, no DataEngine hop.
///
/// Processed directly by the EventBridge on the Slint thread.
#[derive(Debug)]
#[allow(dead_code)] // variants are matched inside spawn_player_handler — rustc can't see cross-task usage
pub enum PlayerEvent {
    /// Pause or resume the current stream.
    TogglePause,
    /// Stop playback entirely.
    Stop,
    /// Seek to an absolute position in seconds.
    Seek { position_secs: f64 },
    /// Seek relative to the current position (positive = forward).
    SeekRelative { delta_secs: f64 },
    /// Set absolute volume (0.0 – 1.0).
    SetVolume { volume: f32 },
    /// Toggle mute state.
    ToggleMute,
    /// Show or hide the on-screen display overlay.
    ShowControls { visible: bool },
    /// Enter or exit fullscreen mode.
    SetFullscreen { fullscreen: bool },
    /// Cycle to the next audio track.
    NextAudioTrack,
    /// Cycle to the next subtitle track.
    NextSubtitleTrack,
    /// Set playback speed (1.0 = normal).
    SetSpeed { speed: f32 },
    /// Select a specific audio track by index.
    SelectAudioTrack { index: i32 },
    /// Select a specific subtitle track by index.
    SelectSubtitleTrack { index: i32 },
}

// ── HighPriorityEvent ────────────────────────────────────────────────────────

/// DataEngine events with elevated priority — drained before NormalEvent queue.
///
/// Covers user-initiated interactions that must feel instantaneous.
#[derive(Debug)]
pub enum HighPriorityEvent {
    /// Navigate the app to a specific screen.
    Navigate { screen: Screen },
    /// Start playing a live channel by its ID.
    PlayChannel { channel_id: String },
    /// Start playing a VOD item by its ID.
    PlayVod { vod_id: String },
    /// Apply a text filter to the currently visible content list.
    FilterContent { query: String },
    /// Execute a full-text search across all content.
    Search { query: String },
    /// Toggle the favourite state of a channel.
    ToggleChannelFavorite { channel_id: String },
    /// Toggle the favourite state of a VOD item.
    ToggleVodFavorite { vod_id: String },
    /// Switch the active UI theme by name.
    ChangeTheme { theme_name: String },
    /// Switch the active UI language by BCP-47 tag (e.g. `"en"`, `"ar"`).
    ChangeLanguage { language_tag: String },
    /// Open the detail view for a VOD item.
    OpenVodDetail { vod_id: String },
    /// Open the detail view for a series.
    OpenSeriesDetail { series_id: String },
    /// Select an EPG date offset (0 = today, -1 = yesterday, etc.).
    SelectEpgDate { offset_days: i32 },
    /// Jump the EPG timeline to a specific channel.
    JumpEpgToChannel { channel_id: String },
    /// Select a season for the currently open series detail view.
    SelectSeriesSeason { series_id: String, season: i32 },
    /// Filter the EPG grid by programme title.
    SearchEpg { query: String },
    /// Apply a VOD category filter to Movies and Series screens.
    FilterVodCategory { category: String },
    /// Set the channel sort mode: `"default"`, `"name"`, or `"date_added"`.
    SetChannelSort { mode: String },
}

// ── NormalEvent ──────────────────────────────────────────────────────────────

/// DataEngine events processed at normal priority — run when high queue is empty.
///
/// Covers background and configuration operations.
#[derive(Debug)]
pub enum NormalEvent {
    /// Persist a new or updated source to the database.
    SaveSource { input: SourceInput },
    /// Delete a source (and all its channels/VOD) by ID.
    DeleteSource { source_id: String },
    /// Flip the `enabled` flag of a source (enabled ↔ disabled).
    ToggleSourceEnabled { source_id: String },
    /// Force a manual sync for one source.
    SyncSource { source_id: String },
    /// Sync all enabled sources.
    SyncAll,
    /// Mark onboarding as complete for the current profile.
    CompleteOnboarding,
    /// Collect and emit diagnostics information.
    RunDiagnostics,
    /// Persist a newly created profile to the database.
    SaveProfile {
        id: String,
        name: String,
        is_child: bool,
        max_allowed_rating: i32,
        role: i32,
    },
    /// Persist a user preference (key/value) to the database.
    SavePreference { key: String, value: String },
    /// Export a full app backup (sources, settings, profiles) to a file.
    /// Handled by BackupService in crispy-core (Epoch 13).
    ExportBackup,
    /// Import a backup file and restore sources, settings, and profiles.
    /// Handled by BackupService in crispy-core (Epoch 13).
    ImportBackup,
    /// Persist a watch history entry (position auto-save or on content finish).
    SaveWatchEntry {
        /// Unique ID derived from stream URL (use `derive_watch_history_id`).
        id: String,
        /// Display name of the watched content.
        name: String,
        /// Content type: `"channel"`, `"movie"`, or `"episode"`.
        media_type: String,
        /// Stream URL that was playing.
        stream_url: String,
        /// Current playback position in milliseconds.
        position_ms: i64,
        /// Total duration in milliseconds (0 for live).
        duration_ms: i64,
        /// Profile ID this entry belongs to.
        profile_id: String,
    },
    /// Clear all watch history for the given profile.
    ClearWatchHistory { profile_id: String },
    /// GDPR Art. 17 — erase all personal data for the given profile (J-47).
    #[allow(dead_code)] // Wired when GDPR delete button is connected in settings
    DeleteAllUserData { profile_id: String },
    /// Load continue-watching items for the home screen (J-17/J-21).
    #[allow(dead_code)] // Wired when home screen continue-watching lane is connected
    LoadContinueWatching { profile_id: String },
    /// Persist the hardware-decode mode preference ("Auto"|"Always"|"Never").
    SetHwdecMode { mode: String },
    /// Persist the aspect-ratio override preference ("Auto"|"16:9"|"4:3"|"Fill").
    SetAspectRatio { ratio: String },
    /// Persist the audio-passthrough preference ("Off"|"On").
    SetAudioPassthrough { enabled: String },
}

// ── DataEvent ────────────────────────────────────────────────────────────────

/// Events emitted by DataEngine back to the UI via EventBridge.
///
/// All payloads use plain Rust types (`ChannelInfo`, `VodInfo`, etc.).
/// EventBridge converts these to Slint model types before applying them.
#[derive(Debug)]
#[allow(dead_code)] // SearchResults.query + SyncProgress wired in Epoch 2
pub enum DataEvent {
    /// Initial source list is ready for display.
    SourcesReady { sources: Vec<SourceInfo> },
    /// Full channel list is ready (all filtered results; set as full VecModel on UI thread).
    ChannelsReady {
        channels: Arc<Vec<ChannelInfo>>,
        groups: Vec<String>,
        total: i32,
    },
    /// Full movies list is ready (all filtered results; set as full VecModel on UI thread).
    MoviesReady {
        movies: Arc<Vec<VodInfo>>,
        categories: Vec<String>,
        total: i32,
    },
    /// Full series list is ready (all filtered results; set as full VecModel on UI thread).
    SeriesReady {
        series: Arc<Vec<VodInfo>>,
        categories: Vec<String>,
        total: i32,
    },
    /// Season count for the currently open series detail.
    SeriesSeasonCount { count: i32 },
    /// Full-text search results.
    SearchResults {
        query: String,
        channels: Vec<ChannelInfo>,
        movies: Vec<VodInfo>,
        series: Vec<VodInfo>,
    },
    /// A loading operation has started.
    LoadingStarted { kind: LoadingKind },
    /// A loading operation has finished.
    LoadingFinished { kind: LoadingKind },
    /// A source sync has begun.
    SyncStarted { source_id: String },
    /// Incremental sync progress (0–100).
    SyncProgress { source_id: String, percent: u8 },
    /// A source sync finished (success or failure).
    SyncCompleted { result: SyncResult },
    /// A source sync failed before completion.
    SyncFailed { source_id: String, error: String },
    /// Playback is ready; EventBridge should start the player.
    PlaybackReady { url: String, title: String },
    /// A theme change has been applied.
    ThemeApplied { theme_name: String },
    /// A language change has been applied.
    LanguageApplied { language_tag: String },
    /// Onboarding has been dismissed for the current profile.
    OnboardingDismissed,
    /// The active screen has changed (e.g. back-navigation).
    ScreenChanged { screen: Screen },
    /// Diagnostics data ready for display.
    DiagnosticsInfo { report: String },
    /// A recoverable error to surface in the UI (toast / banner).
    Error { message: String },
    /// EPG programmes ready for a given time window.
    EpgProgrammesReady {
        window_start: i64,
        window_end: i64,
        programmes: Arc<Vec<crispy_server::models::EpgEntry>>,
    },
    /// EPG grid should scroll to and highlight this channel.
    EpgFocusChannel { channel_id: String },
    /// EPG programme search results filtered by title query.
    EpgSearchResults {
        query: String,
        /// Flat list of matching `EpgEntry` items from SharedData.
        results: Arc<Vec<crispy_server::models::EpgEntry>>,
    },
    /// J-25: persisted recent search queries loaded from DB on startup.
    RecentSearchesReady { queries: Vec<String> },
    /// J-40: Watch history loaded for the Library screen.
    WatchHistoryReady { entries: Vec<WatchHistoryInfo> },
    /// Library Favorites tab — favorited channels.
    FavoriteChannelsReady { channels: Vec<ChannelInfo> },
    /// Library Favorites tab — favorited movies and series.
    FavoriteVodReady { items: Vec<VodInfo> },
    /// J-17/J-21: Continue-watching items ready for the home screen lane.
    ContinueWatchingReady {
        /// id, title, poster_url, progress fraction (0.0–1.0), content_type
        items: Vec<ContinueWatchingInfo>,
    },
    /// Network connectivity state changed — update offline banner.
    /// `status`: 0 = online, 1 = offline, 2 = degraded.
    NetworkStateChanged { status: i32 },
}
