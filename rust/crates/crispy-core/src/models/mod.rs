//! Domain model structs for CrispyTivi.
//!
//! Each struct maps 1:1 to a Drift SQLite table in the
//! Flutter app's database schema. All types derive
//! `Debug, Clone, Serialize, Deserialize` for
//! interop and diagnostics.

pub mod columns;
pub mod content_rating;
pub mod conversions;
pub mod stream_quality;
pub use content_rating::ContentRating;

use chrono::NaiveDateTime;
use serde::{Deserialize, Serialize};

use crate::value_objects::{
    BackendType, CategoryType, DvrPermission, LayoutType, MatchMethod, MediaType, ProfileRole,
    TransferDirection, TransferStatus,
};

pub fn new_entity_id() -> String {
    uuid::Uuid::now_v7().to_string()
}

// ── Channel ─────────────────────────────────────────

/// A live TV channel from an IPTV source.
///
/// Maps to the `channels` Drift table. Contains
/// stream metadata, EPG identifiers, and catchup
/// configuration.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Channel {
    /// Unique channel identifier.
    pub id: String,
    /// Source-native ID (stream_id for Xtream, portal id for Stalker, url-hash for M3U).
    #[serde(default)]
    pub native_id: String,
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
    /// EPG `tvg-id` for guide matching (M3U compatibility).
    #[serde(default)]
    pub tvg_id: Option<String>,
    /// Xtream `stream_id` used for on-demand `get_short_epg` lookups.
    #[serde(default)]
    pub xtream_stream_id: Option<String>,
    /// Unified EPG matching field.
    #[serde(default)]
    pub epg_channel_id: Option<String>,
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
    /// EPG time shift in hours (from `tvg-shift`).
    #[serde(default)]
    pub tvg_shift: Option<f64>,
    /// Stream language (from `tvg-language`).
    #[serde(default)]
    pub tvg_language: Option<String>,
    /// Country code (from `tvg-country`).
    #[serde(default)]
    pub tvg_country: Option<String>,
    /// Parental lock code (from `parent-code`).
    #[serde(default)]
    pub parent_code: Option<String>,
    /// Whether this is a radio/audio-only stream (from `radio` attribute).
    #[serde(default)]
    pub is_radio: bool,
    /// Recording URL template (from `tvg-rec`).
    #[serde(default)]
    pub tvg_rec: Option<String>,
    /// Whether this channel is flagged as adult content
    /// by the provider (Xtream `is_adult` field).
    #[serde(default)]
    pub is_adult: bool,
    /// Provider-assigned custom SID (Xtream `custom_sid`).
    /// Used for alternative EPG matching or stream identification.
    #[serde(default)]
    pub custom_sid: Option<String>,
    /// Direct source URL provided by the Xtream API.
    /// Can serve as a failover stream URL.
    #[serde(default)]
    pub direct_source: Option<String>,
    /// Raw Stalker cmd for re-resolution.
    #[serde(default)]
    pub stalker_cmd: Option<String>,
    /// Resolved URL from cmd.
    #[serde(default)]
    pub resolved_url: Option<String>,
    /// Epoch when resolved.
    #[serde(default)]
    pub resolved_at: Option<i64>,
    /// Per-channel EPG URL (`tvg-url` M3U attribute).
    #[serde(default)]
    pub tvg_url: Option<String>,
    /// Kodi stream properties (KODIPROP) serialised as JSON.
    /// Carries DRM licence keys and adaptive-streaming config.
    #[serde(default)]
    pub stream_properties_json: Option<String>,
    /// VLC options (EXTVLCOPT) serialised as JSON.
    /// Carries HTTP headers, reconnect hints, and caching settings.
    #[serde(default)]
    pub vlc_options_json: Option<String>,
    /// Timeshift duration hint (`timeshift` M3U attribute).
    #[serde(default)]
    pub timeshift: Option<String>,
    /// Xtream stream type (e.g. `"live"`).
    #[serde(default)]
    pub stream_type: Option<String>,
    /// Xtream channel thumbnail URL.
    #[serde(default)]
    pub thumbnail_url: Option<String>,
}

impl Channel {
    /// Returns true if catchup/timeshift is available and has archive days configured.
    pub fn has_catchup(&self) -> bool {
        self.has_catchup && self.catchup_days > 0
    }

    /// Returns true if the channel has a non-empty stream URL.
    pub fn is_live(&self) -> bool {
        !self.stream_url.is_empty()
    }

    /// Returns true if the channel group contains sport-related keywords.
    pub fn is_sport(&self) -> bool {
        let group = self.channel_group.as_deref().unwrap_or("").to_lowercase();
        group.contains("sport") || group.contains("football") || group.contains("soccer")
    }

    /// Returns the display name. The `name` field is always populated on a Channel.
    pub fn display_name(&self) -> &str {
        &self.name
    }
}

impl Movie {
    /// Returns true if the movie is flagged as adult content.
    pub fn is_adult(&self) -> bool {
        self.is_adult
    }

    /// Returns true if a YouTube trailer ID is present.
    pub fn has_trailer(&self) -> bool {
        self.youtube_trailer
            .as_deref()
            .map_or(false, |t| !t.is_empty())
    }
}

impl Series {
    /// Returns true if the series has no end year (still airing).
    pub fn is_ongoing(&self) -> bool {
        self.year.is_none() || self.updated_at.is_some()
    }

    /// Returns the number of seasons stored (always 0 at the Series level;
    /// seasons are a separate collection).
    pub fn season_count(&self) -> usize {
        0
    }
}

impl Season {
    /// Returns the number of episodes in this season, defaulting to 0.
    pub fn episode_count(&self) -> usize {
        self.episode_count.unwrap_or(0) as usize
    }

    /// Returns true if this season has at least one episode.
    pub fn has_episodes(&self) -> bool {
        self.episode_count.unwrap_or(0) > 0
    }
}

impl Episode {
    /// Returns true if a non-empty description is present.
    pub fn has_plot(&self) -> bool {
        self.description.as_deref().map_or(false, |d| !d.is_empty())
    }

    /// Returns a label like "S01E03" for this episode.
    pub fn season_episode_label(&self, season_number: i32) -> String {
        format!("S{:02}E{:02}", season_number, self.episode_number)
    }
}

impl Category {
    /// Returns true if this is a live/channel category.
    pub fn is_live(&self) -> bool {
        self.category_type == CategoryType::Live
    }

    /// Returns true if this is a VOD category.
    pub fn is_vod(&self) -> bool {
        self.category_type == CategoryType::Vod
    }
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
    pub match_method: MatchMethod,
    /// Source of the EPG data.
    #[serde(default)]
    pub epg_source_id: Option<String>,
    /// Whether the user has locked this mapping.
    #[serde(default)]
    pub locked: bool,
    /// When the mapping was created (epoch seconds).
    pub created_at: i64,
}

impl EpgMapping {
    /// Returns true if this mapping was set manually by the user (locked).
    pub fn is_manual(&self) -> bool {
        self.locked
    }

    /// Returns true if a custom EPG channel ID was provided (non-empty).
    pub fn has_custom_name(&self) -> bool {
        !self.epg_channel_id.is_empty()
    }
}

// ── Movie ───────────────────────────────────────────

/// A movie from a VOD source.
///
/// Maps to the `db_movies` table.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Movie {
    /// Unique movie identifier.
    pub id: String,
    /// Source this movie belongs to.
    pub source_id: String,
    /// Source-native ID (stream_id for Xtream, portal id for Stalker).
    pub native_id: String,
    /// Display name / title.
    pub name: String,
    /// Original/alternate title.
    #[serde(default)]
    pub original_name: Option<String>,
    /// URL of the poster image.
    #[serde(default)]
    pub poster_url: Option<String>,
    /// URL of the backdrop / fanart image.
    #[serde(default)]
    pub backdrop_url: Option<String>,
    /// Synopsis / plot description.
    #[serde(default)]
    pub description: Option<String>,
    /// Direct stream URL.
    #[serde(default)]
    pub stream_url: Option<String>,
    /// Container extension (e.g. "mkv", "mp4").
    #[serde(default)]
    pub container_ext: Option<String>,
    /// Raw Stalker cmd for re-resolution.
    #[serde(default)]
    pub stalker_cmd: Option<String>,
    /// Resolved URL from cmd.
    #[serde(default)]
    pub resolved_url: Option<String>,
    /// Epoch when resolved.
    #[serde(default)]
    pub resolved_at: Option<i64>,
    /// Release year.
    #[serde(default)]
    pub year: Option<i32>,
    /// Duration in minutes.
    #[serde(default)]
    pub duration_minutes: Option<i32>,
    /// Rating string (e.g. "7.5").
    #[serde(default)]
    pub rating: Option<String>,
    /// Rating on a 5-star scale.
    #[serde(default)]
    pub rating_5based: Option<f64>,
    /// Content/parental rating (e.g. "PG-13", "R").
    #[serde(default)]
    pub content_rating: Option<String>,
    /// Comma-separated genre tags.
    #[serde(default)]
    pub genre: Option<String>,
    /// YouTube trailer video ID.
    #[serde(default)]
    pub youtube_trailer: Option<String>,
    /// TMDB movie ID.
    #[serde(default)]
    pub tmdb_id: Option<i64>,
    /// Comma-separated cast / actor names.
    #[serde(default)]
    pub cast_names: Option<String>,
    /// Director name(s).
    #[serde(default)]
    pub director: Option<String>,
    /// Whether this content is flagged as adult/NSFW.
    #[serde(default)]
    pub is_adult: bool,
    /// When the movie was first imported.
    #[serde(default)]
    pub added_at: Option<NaiveDateTime>,
    /// When the movie was last refreshed.
    #[serde(default)]
    pub updated_at: Option<NaiveDateTime>,
}

// ── Series ──────────────────────────────────────────

/// A TV series from a VOD source.
///
/// Maps to the `db_series` table.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Series {
    /// Unique series identifier.
    pub id: String,
    /// Source this series belongs to.
    pub source_id: String,
    /// Source-native ID.
    pub native_id: String,
    /// Display name / title.
    pub name: String,
    /// Original/alternate title.
    #[serde(default)]
    pub original_name: Option<String>,
    /// URL of the poster image.
    #[serde(default)]
    pub poster_url: Option<String>,
    /// URL of the backdrop / fanart image.
    #[serde(default)]
    pub backdrop_url: Option<String>,
    /// Synopsis / plot description.
    #[serde(default)]
    pub description: Option<String>,
    /// Release year.
    #[serde(default)]
    pub year: Option<i32>,
    /// Comma-separated genre tags.
    #[serde(default)]
    pub genre: Option<String>,
    /// Content/parental rating (e.g. "PG-13").
    #[serde(default)]
    pub content_rating: Option<String>,
    /// Rating string.
    #[serde(default)]
    pub rating: Option<String>,
    /// Rating on a 5-star scale.
    #[serde(default)]
    pub rating_5based: Option<f64>,
    /// YouTube trailer video ID.
    #[serde(default)]
    pub youtube_trailer: Option<String>,
    /// TMDB series ID.
    #[serde(default)]
    pub tmdb_id: Option<i64>,
    /// Comma-separated cast / actor names.
    #[serde(default)]
    pub cast_names: Option<String>,
    /// Director name(s).
    #[serde(default)]
    pub director: Option<String>,
    /// Whether this content is flagged as adult/NSFW.
    #[serde(default)]
    pub is_adult: bool,
    /// When the series was first imported.
    #[serde(default)]
    pub added_at: Option<NaiveDateTime>,
    /// When the series was last refreshed.
    #[serde(default)]
    pub updated_at: Option<NaiveDateTime>,
}

// ── Season ──────────────────────────────────────────

/// A season within a TV series.
///
/// Maps to the `db_seasons` table.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Season {
    /// Unique season identifier.
    pub id: String,
    /// Parent series ID.
    pub series_id: String,
    /// Season number.
    pub season_number: i32,
    /// Season name/title.
    #[serde(default)]
    pub name: Option<String>,
    /// URL of the season poster image.
    #[serde(default)]
    pub poster_url: Option<String>,
    /// Number of episodes in this season.
    #[serde(default)]
    pub episode_count: Option<i32>,
    /// Air date (e.g. "2024-01-15").
    #[serde(default)]
    pub air_date: Option<String>,
}

// ── Episode ─────────────────────────────────────────

/// An episode within a season.
///
/// Maps to the `db_episodes` table.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Episode {
    /// Unique episode identifier.
    pub id: String,
    /// Parent season ID.
    pub season_id: String,
    /// Source this episode belongs to.
    pub source_id: String,
    /// Source-native ID.
    pub native_id: String,
    /// Episode number within the season.
    pub episode_number: i32,
    /// Episode name/title.
    #[serde(default)]
    pub name: Option<String>,
    /// Synopsis / plot description.
    #[serde(default)]
    pub description: Option<String>,
    /// URL of the episode poster/thumbnail.
    #[serde(default)]
    pub poster_url: Option<String>,
    /// Direct stream URL.
    #[serde(default)]
    pub stream_url: Option<String>,
    /// Container extension.
    #[serde(default)]
    pub container_ext: Option<String>,
    /// Raw Stalker cmd for re-resolution.
    #[serde(default)]
    pub stalker_cmd: Option<String>,
    /// Resolved URL from cmd.
    #[serde(default)]
    pub resolved_url: Option<String>,
    /// Epoch when resolved.
    #[serde(default)]
    pub resolved_at: Option<i64>,
    /// Duration in minutes.
    #[serde(default)]
    pub duration_minutes: Option<i32>,
    /// Air date (e.g. "2024-01-15").
    #[serde(default)]
    pub air_date: Option<String>,
    /// Rating string.
    #[serde(default)]
    pub rating: Option<String>,
    /// Content/parental rating.
    #[serde(default)]
    pub content_rating: Option<String>,
    /// TMDB episode ID.
    #[serde(default)]
    pub tmdb_id: Option<i64>,
    /// When the episode was first imported.
    #[serde(default)]
    pub added_at: Option<NaiveDateTime>,
    /// When the episode was last refreshed.
    #[serde(default)]
    pub updated_at: Option<NaiveDateTime>,
}

// ── VodItem (backward compatibility) ────────────────

/// Legacy VOD item wrapper for backward compatibility.
///
/// Used by parsers and algorithms that haven't been migrated
/// to the new Movie/Series/Episode types yet.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VodItem {
    /// Unique VOD item identifier (UUID v7).
    pub id: String,
    /// Provider's stable ID for this item (e.g. Xtream stream_id).
    /// Used with source_id for upsert conflict resolution.
    #[serde(default)]
    pub native_id: String,
    /// Display name / title.
    pub name: String,
    /// Direct stream URL.
    pub stream_url: String,
    /// Content type: movie, series, or episode.
    #[serde(rename = "type")]
    pub item_type: MediaType,
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
    /// Provider category ID (e.g. Xtream `category_id`).
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
    /// Comma-separated cast / actor names.
    #[serde(default)]
    pub cast: Option<String>,
    /// Director name(s).
    #[serde(default)]
    pub director: Option<String>,
    /// Comma-separated genre tags (e.g. "Action, Drama").
    #[serde(default)]
    pub genre: Option<String>,
    /// YouTube trailer video ID.
    #[serde(default)]
    pub youtube_trailer: Option<String>,
    /// TMDB movie or series ID.
    #[serde(default)]
    pub tmdb_id: Option<i64>,
    /// Rating on a 5-star scale.
    #[serde(default)]
    pub rating_5based: Option<f64>,
    /// Original/alternate title (e.g. foreign language title).
    #[serde(default)]
    pub original_name: Option<String>,
    /// Whether this content is flagged as adult/NSFW.
    #[serde(default)]
    pub is_adult: bool,
    /// Content/parental rating (e.g. "PG-13", "R", "TV-MA").
    #[serde(default)]
    pub content_rating: Option<String>,
}

impl Default for VodItem {
    fn default() -> Self {
        Self {
            id: String::new(),
            native_id: String::new(),
            name: String::new(),
            stream_url: String::new(),
            item_type: MediaType::Movie,
            poster_url: None,
            backdrop_url: None,
            description: None,
            rating: None,
            year: None,
            duration: None,
            category: None,
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
}

impl VodItem {
    /// Returns true if this item is a movie.
    pub fn is_movie(&self) -> bool {
        self.item_type == MediaType::Movie
    }

    /// Returns true if this item is a series.
    pub fn is_series(&self) -> bool {
        self.item_type == MediaType::Series
    }

    /// Returns true if a non-empty rating is present.
    pub fn has_rating(&self) -> bool {
        self.rating.as_deref().map_or(false, |r| !r.is_empty())
    }

    /// Convert a legacy VodItem to a Movie (for items with type "movie").
    pub fn to_movie(&self) -> Movie {
        Movie {
            id: self.id.clone(),
            source_id: self.source_id.clone().unwrap_or_default(),
            native_id: self.id.clone(),
            name: self.name.clone(),
            original_name: self.original_name.clone(),
            poster_url: self.poster_url.clone(),
            backdrop_url: self.backdrop_url.clone(),
            description: self.description.clone(),
            stream_url: if self.stream_url.is_empty() {
                None
            } else {
                Some(self.stream_url.clone())
            },
            container_ext: self.ext.clone(),
            year: self.year,
            duration_minutes: self.duration,
            rating: self.rating.clone(),
            rating_5based: self.rating_5based,
            content_rating: self.content_rating.clone(),
            genre: self.genre.clone(),
            youtube_trailer: self.youtube_trailer.clone(),
            tmdb_id: self.tmdb_id,
            cast_names: self.cast.clone(),
            director: self.director.clone(),
            is_adult: self.is_adult,
            added_at: self.added_at,
            updated_at: self.updated_at,
            ..Movie::default()
        }
    }
}

impl From<Movie> for VodItem {
    fn from(m: Movie) -> Self {
        VodItem {
            id: m.id,
            native_id: m.native_id,
            name: m.name,
            stream_url: m.stream_url.unwrap_or_default(),
            item_type: MediaType::Movie,
            poster_url: m.poster_url,
            backdrop_url: m.backdrop_url,
            description: m.description,
            rating: m.rating,
            year: m.year,
            duration: m.duration_minutes,
            category: None,
            series_id: None,
            season_number: None,
            episode_number: None,
            ext: m.container_ext,
            is_favorite: false,
            added_at: m.added_at,
            updated_at: m.updated_at,
            source_id: if m.source_id.is_empty() {
                None
            } else {
                Some(m.source_id)
            },
            cast: m.cast_names,
            director: m.director,
            genre: m.genre,
            youtube_trailer: m.youtube_trailer,
            tmdb_id: m.tmdb_id,
            rating_5based: m.rating_5based,
            original_name: m.original_name,
            is_adult: m.is_adult,
            content_rating: m.content_rating,
        }
    }
}

impl From<Series> for VodItem {
    fn from(s: Series) -> Self {
        VodItem {
            id: s.id,
            native_id: s.native_id,
            name: s.name,
            stream_url: String::new(),
            item_type: MediaType::Series,
            poster_url: s.poster_url,
            backdrop_url: s.backdrop_url,
            description: s.description,
            rating: s.rating,
            year: s.year,
            duration: None,
            category: None,
            series_id: None,
            season_number: None,
            episode_number: None,
            ext: None,
            is_favorite: false,
            added_at: s.added_at,
            updated_at: s.updated_at,
            source_id: if s.source_id.is_empty() {
                None
            } else {
                Some(s.source_id)
            },
            cast: s.cast_names,
            director: s.director,
            genre: s.genre,
            youtube_trailer: s.youtube_trailer,
            tmdb_id: s.tmdb_id,
            rating_5based: s.rating_5based,
            original_name: s.original_name,
            is_adult: s.is_adult,
            content_rating: s.content_rating,
        }
    }
}

// ── Category ────────────────────────────────────────

/// A content category for live, VOD, or series.
///
/// Maps to the `categories` Drift table. Composite
/// primary key: (`category_type`, `name`).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Category {
    /// Type discriminator: live, vod, series, or radio.
    pub category_type: CategoryType,
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
/// Maps to the `db_epg_entries` table. Composite
/// primary key: (`source_id`, `epg_channel_id`, `start_time`).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EpgEntry {
    /// XMLTV channel ID — the EPG bridge key.
    /// Joins to `db_channels.tvg_id`. Stored as `epg_channel_id` in the DB.
    pub epg_channel_id: String,
    /// XMLTV channel ID (maps to tvg_id in M3U).
    #[serde(default)]
    pub xmltv_id: Option<String>,
    /// Programme title.
    pub title: String,
    /// Scheduled start time.
    pub start_time: NaiveDateTime,
    /// Scheduled end time.
    pub end_time: NaiveDateTime,
    /// Programme description / synopsis.
    #[serde(default)]
    pub description: Option<String>,
    /// Programme genre / category (semicolon-separated when multiple).
    #[serde(default)]
    pub category: Option<String>,
    /// URL of the programme icon/thumbnail.
    #[serde(default)]
    pub icon_url: Option<String>,
    /// Source this EPG entry came from.
    #[serde(default)]
    pub source_id: Option<String>,
    /// Whether this is an auto-generated placeholder entry.
    #[serde(default)]
    pub is_placeholder: bool,
    /// Episode/sub-title (XMLTV `<sub-title>`).
    #[serde(default)]
    pub sub_title: Option<String>,
    /// Season number parsed from `<episode-num system="xmltv_ns">`.
    #[serde(default)]
    pub season: Option<i32>,
    /// Episode number parsed from `<episode-num system="xmltv_ns">`.
    #[serde(default)]
    pub episode: Option<i32>,
    /// On-screen episode label (e.g. "S01E05").
    #[serde(default)]
    pub episode_label: Option<String>,
    /// Original air date (XMLTV `<date>`, typically "YYYY" or "YYYYMMDD").
    #[serde(default)]
    pub air_date: Option<String>,
    /// Content rating (e.g. "PG-13", from XMLTV `<rating><value>`).
    #[serde(default)]
    pub content_rating: Option<String>,
    /// Star/review rating (e.g. "7.5/10", from XMLTV `<star-rating><value>`).
    #[serde(default)]
    pub star_rating: Option<String>,
    /// JSON-encoded credits (directors, cast, writers, presenters).
    #[serde(default)]
    pub credits_json: Option<String>,
    /// Programme language (XMLTV `<language>`).
    #[serde(default)]
    pub language: Option<String>,
    /// Country of origin (XMLTV `<country>`).
    #[serde(default)]
    pub country: Option<String>,
    /// Whether this is a rerun (`<previously-shown>` present).
    #[serde(default)]
    pub is_rerun: bool,
    /// Whether this is a first-run (`<new/>` present).
    #[serde(default)]
    pub is_new: bool,
    /// Whether this is a premiere (`<premiere>` present).
    #[serde(default)]
    pub is_premiere: bool,
    /// Programme duration in minutes (from `<length>` element).
    #[serde(default)]
    pub length_minutes: Option<i32>,
}

impl Default for EpgEntry {
    fn default() -> Self {
        let epoch = NaiveDateTime::new(
            chrono::NaiveDate::from_ymd_opt(1970, 1, 1).unwrap(),
            chrono::NaiveTime::from_hms_opt(0, 0, 0).unwrap(),
        );
        Self {
            epg_channel_id: String::new(),
            xmltv_id: None,
            title: String::new(),
            start_time: epoch,
            end_time: epoch,
            description: None,
            category: None,
            icon_url: None,
            source_id: None,
            is_placeholder: false,
            sub_title: None,
            season: None,
            episode: None,
            episode_label: None,
            air_date: None,
            content_rating: None,
            star_rating: None,
            credits_json: None,
            language: None,
            country: None,
            is_rerun: false,
            is_new: false,
            is_premiere: false,
            length_minutes: None,
        }
    }
}

impl EpgEntry {
    /// Returns true if the programme is currently airing at the given Unix timestamp.
    pub fn is_currently_airing(&self, now: i64) -> bool {
        let start = self.start_time.and_utc().timestamp();
        let stop = self.end_time.and_utc().timestamp();
        start <= now && now < stop
    }

    /// Returns the programme duration in whole minutes.
    pub fn duration_minutes(&self) -> i64 {
        let start = self.start_time.and_utc().timestamp();
        let stop = self.end_time.and_utc().timestamp();
        (stop - start) / 60
    }

    /// Returns true if a non-empty description is present.
    pub fn has_description(&self) -> bool {
        self.description.as_deref().map_or(false, |d| !d.is_empty())
    }
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
    /// Content type: channel, movie, series, or episode.
    pub media_type: MediaType,
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
    /// Profile role.
    #[serde(default)]
    pub role: ProfileRole,
    /// DVR permission level.
    #[serde(default)]
    pub dvr_permission: DvrPermission,
    /// DVR storage quota in megabytes.
    #[serde(default)]
    pub dvr_quota_mb: Option<i32>,
}

fn default_max_rating() -> i32 {
    4
}

impl UserProfile {
    /// Returns true if this profile has the admin role.
    pub fn is_admin(&self) -> bool {
        self.role == ProfileRole::Admin
    }

    /// Returns true if this profile has a PIN set.
    pub fn has_pin(&self) -> bool {
        self.pin.as_deref().map_or(false, |p| !p.is_empty())
    }
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
/// Maps to the `db_vod_favorites` table. Composite
/// primary key: (`profile_id`, `content_id`, `content_type`).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VodFavorite {
    /// Profile that owns this favourite.
    pub profile_id: String,
    /// Favourited content ID (movie or series).
    pub content_id: String,
    /// Content type discriminator.
    pub content_type: MediaType,
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
    /// Category domain discriminator.
    pub category_type: crate::value_objects::CategoryType,
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
    pub source_type: crate::value_objects::SourceType,
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
    /// Soft-delete timestamp (Unix seconds). NULL = active; set = soft-deleted.
    #[serde(default)]
    pub deleted_at: Option<i64>,
    /// ETag header from the last EPG fetch for conditional HTTP requests.
    #[serde(default)]
    pub epg_etag: Option<String>,
    /// Last-Modified header from the last EPG fetch for conditional HTTP requests.
    #[serde(default)]
    pub epg_last_modified: Option<String>,
}

impl Source {
    /// Returns true if this source is an Xtream Codes provider.
    pub fn is_xtream(&self) -> bool {
        self.source_type == crate::value_objects::SourceType::Xtream
    }

    /// Returns true if this source is a Stalker portal.
    pub fn is_stalker(&self) -> bool {
        self.source_type == crate::value_objects::SourceType::Stalker
    }

    /// Returns true if this source is an M3U playlist.
    pub fn is_m3u(&self) -> bool {
        self.source_type == crate::value_objects::SourceType::M3u
    }

    /// Returns true if this source requires username/password or MAC credentials.
    pub fn uses_credentials(&self) -> bool {
        self.source_type.uses_credentials()
    }

    /// Returns true if this source is a media server (Plex, Emby, or Jellyfin).
    pub fn is_media_server(&self) -> bool {
        self.source_type.uses_token()
    }
}

// ── AccountStatus ────────────────────────────────────

/// Domain representation of an Xtream account status string.
///
/// The Xtream API sends a raw status string (e.g. `"Active"`).
/// This enum centralises interpretation so callers use typed
/// variants instead of comparing raw string literals.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AccountStatus {
    /// Account is active and usable.
    Active,
    /// Account has been banned by the server.
    Banned,
    /// Account is disabled (suspended).
    Disabled,
    /// Subscription has expired.
    Expired,
    /// Any other status value returned by the server.
    Unknown(String),
}

// ── XtreamAccountInfo ───────────────────────────────

/// Parsed Xtream Codes account and server information.
///
/// Populated from the authentication response at
/// `player_api.php?username=X&password=Y` (no action param
/// or `action=get_account_info`). Contains subscription
/// status, connection limits, and server configuration.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct XtreamAccountInfo {
    // ── user_info fields ──────────────────────────────
    /// Username on the Xtream server.
    #[serde(default)]
    pub username: Option<String>,
    /// Server-provided status message.
    #[serde(default)]
    pub message: Option<String>,
    /// Whether the user is authenticated (1 = yes).
    #[serde(default)]
    pub auth: i32,
    /// Account status string (e.g. "Active", "Banned", "Disabled", "Expired").
    #[serde(default)]
    pub status: Option<String>,
    /// Subscription expiration as a Unix timestamp string.
    #[serde(default)]
    pub exp_date: Option<String>,
    /// Whether this is a trial account ("0" or "1").
    #[serde(default)]
    pub is_trial: Option<String>,
    /// Number of currently active connections.
    #[serde(default)]
    pub active_cons: Option<String>,
    /// Account creation Unix timestamp string.
    #[serde(default)]
    pub created_at: Option<String>,
    /// Maximum simultaneous connections allowed.
    #[serde(default)]
    pub max_connections: Option<String>,
    /// Allowed output stream formats (e.g. ["m3u8", "ts", "rtmp"]).
    #[serde(default)]
    pub allowed_output_formats: Vec<String>,

    // ── server_info fields ────────────────────────────
    /// Server hostname or IP.
    #[serde(default)]
    pub server_url: Option<String>,
    /// HTTP port.
    #[serde(default)]
    pub server_port: Option<String>,
    /// HTTPS port.
    #[serde(default)]
    pub server_https_port: Option<String>,
    /// Server protocol ("http" or "https").
    #[serde(default)]
    pub server_protocol: Option<String>,
    /// RTMP port.
    #[serde(default)]
    pub server_rtmp_port: Option<String>,
    /// Server timezone (e.g. "Europe/London").
    #[serde(default)]
    pub server_timezone: Option<String>,
    /// Server current Unix timestamp.
    #[serde(default)]
    pub server_timestamp_now: Option<i64>,
    /// Server current time as readable string.
    #[serde(default)]
    pub server_time_now: Option<String>,
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
    /// Recording lifecycle state.
    pub status: crate::value_objects::RecordingStatus,
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

impl Recording {
    /// Returns true if this recording is currently in progress.
    pub fn is_active(&self) -> bool {
        self.status == crate::value_objects::RecordingStatus::Recording
    }

    /// Returns true if this recording has finished successfully.
    pub fn is_completed(&self) -> bool {
        self.status == crate::value_objects::RecordingStatus::Completed
    }
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
    /// Backend type discriminator.
    pub backend_type: BackendType,
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
    /// Transfer direction discriminator.
    pub direction: TransferDirection,
    /// Transfer status discriminator.
    pub status: TransferStatus,
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
    /// Layout type discriminator.
    pub layout: LayoutType,
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
    /// Content type discriminator.
    pub content_type: MediaType,
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

impl WatchHistory {
    /// Returns true if this entry was watched within `threshold_secs` of `now`.
    pub fn is_recent(&self, now: i64, threshold_secs: i64) -> bool {
        now - self.last_watched.and_utc().timestamp() <= threshold_secs
    }

    /// Returns playback progress as a percentage (0.0–100.0).
    pub fn progress_percent(&self) -> f64 {
        if self.duration_ms == 0 {
            return 0.0;
        }
        (self.position_ms as f64 / self.duration_ms as f64 * 100.0).clamp(0.0, 100.0)
    }
}

impl UserFavorite {
    /// Returns true — UserFavorite always references a channel.
    pub fn is_channel(&self) -> bool {
        !self.channel_id.is_empty()
    }

    /// Returns true if this favourite belongs to the given channel.
    pub fn matches_channel(&self, channel_id: &str) -> bool {
        self.channel_id == channel_id
    }
}

impl VodFavorite {
    /// Returns true if the content ID references a non-empty source.
    pub fn has_source(&self) -> bool {
        !self.content_id.is_empty()
    }

    /// Returns true if this favourite matches the given item ID.
    pub fn matches_item(&self, item_id: &str) -> bool {
        self.content_id == item_id
    }
}

impl FavoriteCategory {
    /// Returns true if the category name is empty.
    pub fn is_empty(&self) -> bool {
        self.category_name.is_empty()
    }

    /// Returns true if this favourite matches the given category name.
    pub fn contains(&self, category: &str) -> bool {
        self.category_name == category
    }
}

impl ProfileSourceAccess {
    /// Returns true — a row existing means access is granted.
    pub fn is_granted(&self) -> bool {
        !self.source_id.is_empty()
    }

    /// Returns true if this access entry is for the given source.
    pub fn matches_source(&self, source_id: &str) -> bool {
        self.source_id == source_id
    }
}

impl XtreamAccountInfo {
    /// Returns `true` if this is a trial account.
    ///
    /// The Xtream API encodes this as the string `"1"` (trial) or `"0"` (full).
    /// This method centralises the string-to-bool conversion so callers never
    /// repeat the `== "1"` primitive comparison.
    pub fn is_trial_account(&self) -> bool {
        self.is_trial.as_deref() == Some("1")
    }

    /// Returns the server port as a `u16`, or `None` if absent or unparseable.
    pub fn server_port_u16(&self) -> Option<u16> {
        self.server_port.as_deref()?.parse().ok()
    }

    /// Returns the account status as a domain-meaningful enum.
    pub fn account_status(&self) -> AccountStatus {
        match self.status.as_deref() {
            Some("Active") => AccountStatus::Active,
            Some("Banned") => AccountStatus::Banned,
            Some("Disabled") => AccountStatus::Disabled,
            Some("Expired") => AccountStatus::Expired,
            Some(other) => AccountStatus::Unknown(other.to_string()),
            None => AccountStatus::Unknown(String::new()),
        }
    }

    /// Returns true if the account expiry date is in the past relative to `now` (epoch seconds).
    pub fn is_expired(&self, now: i64) -> bool {
        self.exp_date
            .as_deref()
            .and_then(|s| s.parse::<i64>().ok())
            .map_or(false, |exp| exp < now)
    }

    /// Returns the number of days remaining until expiry, or `None` if unknown.
    pub fn days_remaining(&self, now: i64) -> Option<i64> {
        let exp = self.exp_date.as_deref()?.parse::<i64>().ok()?;
        Some((exp - now) / 86_400)
    }
}

impl SourceStats {
    /// Returns true if at least one live channel exists for this source.
    pub fn has_channels(&self) -> bool {
        self.channel_count > 0
    }

    /// Returns the total number of items (channels + VOD) for this source.
    pub fn total_items(&self) -> i64 {
        self.channel_count + self.vod_count
    }
}

impl StorageBackend {
    /// Returns true if this is a local filesystem backend.
    pub fn is_local(&self) -> bool {
        self.backend_type == BackendType::Local
    }

    /// Returns true if this is a remote backend (S3, WebDAV, SMB, etc.).
    pub fn is_remote(&self) -> bool {
        !self.is_local()
    }
}

impl TransferTask {
    /// Returns true if the task is queued (not yet started).
    pub fn is_pending(&self) -> bool {
        self.status == TransferStatus::Pending
    }

    /// Returns true if the task has completed successfully.
    pub fn is_completed(&self) -> bool {
        self.status == TransferStatus::Completed
    }
}

impl SavedLayout {
    /// Returns the number of stream panels in this layout by parsing the JSON array.
    pub fn panel_count(&self) -> usize {
        serde_json::from_str::<Vec<serde_json::Value>>(&self.streams)
            .map(|v| v.len())
            .unwrap_or(0)
    }

    /// Returns true if the streams JSON array is empty or unparseable.
    pub fn is_empty(&self) -> bool {
        self.panel_count() == 0
    }
}

impl SearchHistory {
    /// Returns true if this search was performed within the last hour relative to `now`.
    pub fn is_recent(&self, now: i64) -> bool {
        now - self.searched_at.and_utc().timestamp() <= 3_600
    }

    /// Returns true if the stored query matches the given search term (case-insensitive).
    pub fn matches_query(&self, query: &str) -> bool {
        self.query.to_lowercase().contains(&query.to_lowercase())
    }
}

impl Bookmark {
    /// Returns true if a non-empty user label is present.
    pub fn has_note(&self) -> bool {
        self.label.as_deref().map_or(false, |l| !l.is_empty())
    }

    /// Returns true if the bookmark position is within `tolerance_ms` of `pos_ms`.
    pub fn is_at_position(&self, pos_ms: f64) -> bool {
        (self.position_ms as f64 - pos_ms).abs() < 1000.0
    }
}

impl ChannelOrder {
    /// Returns true if this entry is the first in its group (sort_index == 0).
    pub fn is_first(&self) -> bool {
        self.sort_index == 0
    }

    /// Returns true if this entry has a non-zero custom sort position.
    pub fn has_custom_position(&self) -> bool {
        self.sort_index != 0
    }
}

impl Reminder {
    /// Returns true if the notification time has passed and the reminder hasn't fired yet.
    pub fn is_due(&self, now: i64) -> bool {
        !self.fired && self.notify_at.and_utc().timestamp() <= now
    }

    /// Returns true if the programme start time is in the past relative to `now`.
    pub fn is_past(&self, now: i64) -> bool {
        self.start_time.and_utc().timestamp() < now
    }
}

impl SyncReport {
    /// Returns true if no channels or VOD items were synced (likely an error state).
    pub fn has_errors(&self) -> bool {
        self.channels_count == 0 && self.vod_count == 0
    }

    /// Returns the total number of synced items (channels + VOD).
    pub fn total_items(&self) -> i64 {
        (self.channels_count + self.vod_count) as i64
    }
}

impl SyncProgress {
    /// Returns true if progress has reached 1.0 (complete).
    pub fn is_complete(&self) -> bool {
        self.progress >= 1.0
    }

    /// Returns true if sync has started (progress > 0.0).
    pub fn has_started(&self) -> bool {
        self.progress > 0.0
    }
}

impl SyncMeta {
    /// Returns true if the last sync is older than `max_age_secs` seconds.
    pub fn is_stale(&self, now: i64, max_age_secs: i64) -> bool {
        now - self.last_sync_time.and_utc().timestamp() > max_age_secs
    }

    /// Returns true if a refresh is needed: last sync time is older than `max_age_secs`.
    pub fn needs_refresh(&self, now: i64, max_age_secs: i64) -> bool {
        self.is_stale(now, max_age_secs)
    }
}

impl Setting {
    /// Returns true if the setting value is empty.
    pub fn is_empty(&self) -> bool {
        self.value.is_empty()
    }

    /// Returns true if the setting value is non-empty.
    pub fn has_value(&self) -> bool {
        !self.value.is_empty()
    }
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
            ..Default::default()
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
            ..Default::default()
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
        assert_eq!(v.item_type, MediaType::Movie);
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
        assert_eq!(v.item_type, MediaType::Episode);
        assert_eq!(v.series_id.as_deref(), Some("s1"));
        assert_eq!(v.season_number, Some(2));
        assert_eq!(v.episode_number, Some(3));
    }

    // ── Category ────────────────────────────────────

    #[test]
    fn test_category_roundtrips_via_serde() {
        let c = Category {
            category_type: CategoryType::Live,
            name: "Sports".to_string(),
            source_id: Some("src1".to_string()),
        };
        let json = serde_json::to_string(&c).unwrap();
        let back: Category = serde_json::from_str(&json).unwrap();
        assert_eq!(back.category_type, CategoryType::Live);
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
        assert_eq!(p.role, ProfileRole::Viewer);
    }

    #[test]
    fn test_user_profile_dvr_permission_defaults_to_2() {
        let json = r#"{"id":"p1","name":"Alice"}"#;
        let p: UserProfile = serde_json::from_str(json).unwrap();
        assert_eq!(p.dvr_permission, DvrPermission::Full);
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
            status: crate::value_objects::RecordingStatus::Scheduled,
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
            status: crate::value_objects::RecordingStatus::Completed,
            file_path: Some("/recordings/news.ts".to_string()),
            file_size_bytes: Some(1_048_576),
            is_recurring: false,
            recur_days: 0,
            owner_profile_id: None,
            is_shared: true,
            remote_backend_id: None,
            remote_path: None,
        };
        assert_eq!(r.status, crate::value_objects::RecordingStatus::Completed);
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
        let json = r#"{"channel_id":"c1","epg_channel_id":"e1","confidence":0.9,"match_method":"tvg_id_exact","created_at":0}"#;
        let m: EpgMapping = serde_json::from_str(json).unwrap();
        assert!(!m.locked);
        assert_eq!(m.confidence, 0.9);
        assert!(m.epg_source_id.is_none());
    }

    // ── XtreamAccountInfo ────────────────────────────

    #[test]
    fn test_xtream_account_info_default_has_zero_auth() {
        let info = XtreamAccountInfo::default();
        assert_eq!(info.auth, 0);
        assert!(info.username.is_none());
        assert!(info.status.is_none());
        assert!(info.exp_date.is_none());
        assert!(info.server_url.is_none());
        assert!(info.allowed_output_formats.is_empty());
    }

    #[test]
    fn test_xtream_account_info_roundtrips_via_serde() {
        let info = XtreamAccountInfo {
            username: Some("testuser".to_string()),
            auth: 1,
            status: Some("Active".to_string()),
            exp_date: Some("1735689600".to_string()),
            is_trial: Some("0".to_string()),
            max_connections: Some("2".to_string()),
            allowed_output_formats: vec!["m3u8".to_string(), "ts".to_string()],
            server_url: Some("server.example.com".to_string()),
            server_port: Some("80".to_string()),
            server_timezone: Some("Europe/London".to_string()),
            server_timestamp_now: Some(1711000000),
            ..Default::default()
        };
        let json = serde_json::to_string(&info).unwrap();
        let back: XtreamAccountInfo = serde_json::from_str(&json).unwrap();
        assert_eq!(back.auth, 1);
        assert_eq!(back.username.as_deref(), Some("testuser"));
        assert_eq!(back.status.as_deref(), Some("Active"));
        assert_eq!(back.exp_date.as_deref(), Some("1735689600"));
        assert_eq!(back.max_connections.as_deref(), Some("2"));
        assert_eq!(back.allowed_output_formats, vec!["m3u8", "ts"]);
        assert_eq!(back.server_url.as_deref(), Some("server.example.com"));
        assert_eq!(back.server_timezone.as_deref(), Some("Europe/London"));
        assert_eq!(back.server_timestamp_now, Some(1711000000));
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
            content_type: MediaType::Channel,
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

// ── Domain value object: EpisodeProgress ─────────────────────────────────────

/// Computed progress across episodes in a series.
///
/// Pure domain logic — takes raw watch data, computes progress
/// percentages and identifies the last-watched episode.
pub struct EpisodeProgress {
    pub progress_map: std::collections::BTreeMap<String, f64>,
    pub last_watched_url: Option<String>,
}

impl EpisodeProgress {
    /// Compute episode progress from raw watch-history rows.
    /// Each tuple is `(stream_url, position_ms, duration_ms, last_watched_ts)`.
    pub fn compute(entries: Vec<(String, i64, i64, i64)>) -> Self {
        let mut progress_map = std::collections::BTreeMap::new();
        let mut latest_ts: Option<i64> = None;
        let mut latest_url: Option<String> = None;

        for (url, pos, dur, ts) in entries {
            let progress = if dur <= 0 {
                0.0
            } else {
                (pos as f64 / dur as f64).clamp(0.0, 1.0)
            };
            progress_map.insert(url.clone(), progress);
            if latest_ts.is_none_or(|lt| ts > lt) {
                latest_ts = Some(ts);
                latest_url = Some(url);
            }
        }

        Self { progress_map, last_watched_url: latest_url }
    }

    /// Serialize to JSON string for FFI transport.
    pub fn to_json(&self) -> String {
        let result = serde_json::json!({
            "progress_map": self.progress_map,
            "last_watched_url": self.last_watched_url,
        });
        serde_json::to_string(&result)
            .unwrap_or_else(|_| r#"{"progress_map":{},"last_watched_url":null}"#.to_string())
    }
}
