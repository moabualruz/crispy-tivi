//! Xtream Codes API response types.
//!
//! These types mirror the JSON responses from Xtream-compatible servers.
//! Fields use `serde(alias)` to handle both `snake_case` and `camelCase` variants
//! that different server implementations may return.

use std::collections::HashMap;

use serde::{Deserialize, Serialize};

// ---------------------------------------------------------------------------
// Profile
// ---------------------------------------------------------------------------

/// Top-level profile response from `player_api.php` (no action or `get_profile`).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct XtreamProfile {
    pub user_info: XtreamUserProfile,
    pub server_info: XtreamServerInfo,
}

/// User account information.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct XtreamUserProfile {
    #[serde(default)]
    pub username: String,

    #[serde(default)]
    pub password: String,

    /// Server message (MOTD, notices).
    #[serde(default)]
    pub message: String,

    /// Authentication flag (1 = authenticated).
    #[serde(default)]
    pub auth: u8,

    /// Account status (e.g. "Active", "Disabled").
    #[serde(default)]
    pub status: String,

    /// Expiration date as a Unix timestamp string.
    #[serde(default)]
    pub exp_date: Option<String>,

    /// Whether this is a trial account ("0" or "1").
    #[serde(default)]
    pub is_trial: Option<String>,

    /// Number of currently active connections.
    #[serde(default)]
    pub active_cons: Option<serde_json::Value>,

    /// Account creation date.
    #[serde(default)]
    pub created_at: Option<String>,

    /// Maximum concurrent connections (string in many implementations).
    #[serde(default)]
    pub max_connections: Option<serde_json::Value>,

    /// Formats the user is allowed to access (e.g. `["ts", "m3u8"]`).
    #[serde(default)]
    pub allowed_output_formats: Vec<String>,
}

/// Server information.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct XtreamServerInfo {
    /// Whether this is a XUI instance.
    #[serde(default)]
    pub xui: Option<serde_json::Value>,

    /// Software version.
    #[serde(default)]
    pub version: Option<String>,

    /// Software revision.
    #[serde(default)]
    pub revision: Option<String>,

    /// Base URL of the server.
    #[serde(default)]
    pub url: Option<String>,

    /// HTTP port.
    #[serde(default)]
    pub port: Option<serde_json::Value>,

    /// HTTPS port.
    #[serde(default)]
    pub https_port: Option<serde_json::Value>,

    /// Server protocol (http / https).
    #[serde(default)]
    pub server_protocol: Option<String>,

    /// RTMP port.
    #[serde(default)]
    pub rtmp_port: Option<serde_json::Value>,

    /// Server timezone.
    #[serde(default)]
    pub timezone: Option<String>,

    /// Current server timestamp.
    #[serde(default)]
    pub timestamp_now: Option<i64>,

    /// Current server time as formatted string.
    #[serde(default)]
    pub time_now: Option<String>,
}

// ---------------------------------------------------------------------------
// Categories
// ---------------------------------------------------------------------------

/// A content category (live, VOD, or series).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct XtreamCategory {
    #[serde(default)]
    pub category_id: String,

    #[serde(default)]
    pub category_name: String,

    #[serde(default)]
    pub parent_id: Option<serde_json::Value>,
}

// ---------------------------------------------------------------------------
// Live Channels
// ---------------------------------------------------------------------------

/// A live TV channel from `get_live_streams`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct XtreamChannel {
    /// Position / order number.
    #[serde(default)]
    pub num: Option<i64>,

    /// Channel display name.
    #[serde(default)]
    pub name: String,

    /// Stream type (e.g. "live").
    #[serde(default)]
    pub stream_type: Option<String>,

    /// Unique stream identifier.
    #[serde(default)]
    pub stream_id: i64,

    /// Channel logo URL.
    #[serde(default)]
    pub stream_icon: Option<String>,

    /// Thumbnail URL.
    #[serde(default)]
    pub thumbnail: Option<String>,

    /// EPG channel identifier.
    #[serde(default)]
    pub epg_channel_id: Option<String>,

    /// Date added (Unix timestamp string or formatted date).
    #[serde(default)]
    pub added: Option<String>,

    /// Primary category ID.
    #[serde(default)]
    pub category_id: Option<String>,

    /// All category IDs this channel belongs to.
    #[serde(default)]
    pub category_ids: Vec<serde_json::Value>,

    /// Custom SID.
    #[serde(default)]
    pub custom_sid: Option<String>,

    /// Whether TV archive is available (0 or 1).
    #[serde(default)]
    pub tv_archive: Option<i64>,

    /// Direct source URL.
    #[serde(default)]
    pub direct_source: Option<String>,

    /// Days of archive available.
    #[serde(default)]
    pub tv_archive_duration: Option<i64>,

    /// Whether this channel is flagged as adult content by the provider.
    #[serde(default)]
    pub is_adult: bool,

    /// Generated stream URL (populated by the client).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub url: Option<String>,
}

// ---------------------------------------------------------------------------
// Movies (VOD)
// ---------------------------------------------------------------------------

/// A movie listing from `get_vod_streams`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct XtreamMovieListing {
    #[serde(default)]
    pub num: Option<i64>,

    #[serde(default)]
    pub name: String,

    #[serde(default)]
    pub year: Option<String>,

    #[serde(default)]
    pub title: Option<String>,

    #[serde(default)]
    pub stream_type: Option<String>,

    #[serde(default)]
    pub stream_id: i64,

    #[serde(default)]
    pub stream_icon: Option<String>,

    #[serde(default)]
    pub rating: Option<serde_json::Value>,

    #[serde(default)]
    pub rating_5based: Option<serde_json::Value>,

    #[serde(default)]
    pub genre: Option<String>,

    #[serde(default)]
    pub added: Option<String>,

    #[serde(default)]
    pub episode_run_time: Option<serde_json::Value>,

    #[serde(default)]
    pub category_id: Option<String>,

    #[serde(default)]
    pub category_ids: Vec<serde_json::Value>,

    #[serde(default)]
    pub container_extension: Option<String>,

    #[serde(default)]
    pub custom_sid: Option<serde_json::Value>,

    #[serde(default)]
    pub direct_source: Option<String>,

    #[serde(default)]
    pub release_date: Option<String>,

    #[serde(default)]
    pub cast: Option<String>,

    #[serde(default)]
    pub director: Option<String>,

    #[serde(default)]
    pub plot: Option<String>,

    #[serde(default)]
    pub youtube_trailer: Option<String>,

    /// Generated stream URL (populated by the client).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub url: Option<String>,
}

/// Detailed movie info from `get_vod_info`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct XtreamMovie {
    pub info: Option<XtreamMovieInfo>,
    pub movie_data: Option<XtreamMovieData>,

    /// Generated stream URL (populated by the client).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub url: Option<String>,
}

/// Movie stream data.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct XtreamMovieData {
    #[serde(default)]
    pub stream_id: i64,

    #[serde(default)]
    pub name: Option<String>,

    #[serde(default)]
    pub title: Option<String>,

    #[serde(default)]
    pub year: Option<String>,

    #[serde(default)]
    pub added: Option<String>,

    #[serde(default)]
    pub category_id: Option<String>,

    #[serde(default)]
    pub category_ids: Vec<serde_json::Value>,

    #[serde(default)]
    pub container_extension: Option<String>,

    #[serde(default)]
    pub custom_sid: Option<String>,

    #[serde(default)]
    pub direct_source: Option<String>,
}

/// Extended movie metadata.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct XtreamMovieInfo {
    #[serde(default)]
    pub kinopoisk_url: Option<String>,

    #[serde(default)]
    pub tmdb_id: Option<serde_json::Value>,

    #[serde(default)]
    pub name: Option<String>,

    #[serde(default, alias = "o_name")]
    pub original_name: Option<String>,

    #[serde(default)]
    pub cover_big: Option<String>,

    #[serde(default)]
    pub movie_image: Option<String>,

    #[serde(default)]
    pub release_date: Option<String>,

    #[serde(default)]
    pub episode_run_time: Option<serde_json::Value>,

    #[serde(default)]
    pub youtube_trailer: Option<String>,

    #[serde(default)]
    pub director: Option<String>,

    #[serde(default)]
    pub actors: Option<String>,

    #[serde(default)]
    pub cast: Option<String>,

    #[serde(default)]
    pub description: Option<String>,

    #[serde(default)]
    pub plot: Option<String>,

    #[serde(default)]
    pub age: Option<String>,

    #[serde(default)]
    pub mpaa_rating: Option<String>,

    #[serde(default)]
    pub rating_count_kinopoisk: Option<serde_json::Value>,

    #[serde(default)]
    pub country: Option<String>,

    #[serde(default)]
    pub genre: Option<String>,

    #[serde(default)]
    pub backdrop_path: Option<serde_json::Value>,

    #[serde(default)]
    pub duration_secs: Option<i64>,

    #[serde(default)]
    pub duration: Option<String>,

    #[serde(default)]
    pub bitrate: Option<serde_json::Value>,

    #[serde(default, alias = "releasedate")]
    pub release_date_alt: Option<String>,

    #[serde(default)]
    pub subtitles: Option<serde_json::Value>,

    #[serde(default)]
    pub rating: Option<serde_json::Value>,
}

// ---------------------------------------------------------------------------
// Series / Shows
// ---------------------------------------------------------------------------

/// A series listing from `get_series`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct XtreamShowListing {
    #[serde(default)]
    pub num: Option<i64>,

    #[serde(default)]
    pub name: String,

    #[serde(default)]
    pub title: Option<String>,

    #[serde(default)]
    pub year: Option<String>,

    #[serde(default)]
    pub series_id: i64,

    #[serde(default)]
    pub stream_type: Option<String>,

    #[serde(default)]
    pub cover: Option<String>,

    #[serde(default)]
    pub plot: Option<String>,

    #[serde(default)]
    pub cast: Option<String>,

    #[serde(default)]
    pub director: Option<String>,

    #[serde(default)]
    pub genre: Option<String>,

    #[serde(default, alias = "releaseDate")]
    pub release_date: Option<String>,

    #[serde(default)]
    pub last_modified: Option<String>,

    #[serde(default)]
    pub rating: Option<serde_json::Value>,

    #[serde(default)]
    pub rating_5based: Option<serde_json::Value>,

    #[serde(default)]
    pub backdrop_path: Option<serde_json::Value>,

    #[serde(default)]
    pub youtube_trailer: Option<String>,

    #[serde(default)]
    pub episode_run_time: Option<serde_json::Value>,

    #[serde(default)]
    pub category_id: Option<String>,

    #[serde(default)]
    pub category_ids: Vec<serde_json::Value>,
}

/// Detailed series info from `get_series_info`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct XtreamShow {
    #[serde(default)]
    pub seasons: Vec<XtreamSeason>,

    pub info: Option<XtreamShowInfo>,

    /// Episodes grouped by season number (key is season number as string).
    #[serde(default)]
    pub episodes: HashMap<String, Vec<XtreamEpisode>>,
}

/// Series metadata.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct XtreamShowInfo {
    #[serde(default)]
    pub name: Option<String>,

    #[serde(default)]
    pub title: Option<String>,

    #[serde(default)]
    pub year: Option<String>,

    #[serde(default)]
    pub series_id: Option<i64>,

    #[serde(default)]
    pub cover: Option<String>,

    #[serde(default)]
    pub plot: Option<String>,

    #[serde(default)]
    pub cast: Option<String>,

    #[serde(default)]
    pub director: Option<String>,

    #[serde(default)]
    pub genre: Option<String>,

    #[serde(default, alias = "releaseDate")]
    pub release_date: Option<String>,

    #[serde(default)]
    pub last_modified: Option<String>,

    #[serde(default)]
    pub rating: Option<serde_json::Value>,

    #[serde(default)]
    pub rating_5based: Option<serde_json::Value>,

    #[serde(default)]
    pub backdrop_path: Option<serde_json::Value>,

    #[serde(default)]
    pub youtube_trailer: Option<String>,

    #[serde(default)]
    pub episode_run_time: Option<serde_json::Value>,

    #[serde(default)]
    pub category_id: Option<String>,

    #[serde(default)]
    pub category_ids: Vec<serde_json::Value>,
}

/// A season within a series.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct XtreamSeason {
    #[serde(default)]
    pub id: Option<i64>,

    #[serde(default)]
    pub name: Option<String>,

    #[serde(default)]
    pub episode_count: Option<i64>,

    #[serde(default)]
    pub overview: Option<String>,

    #[serde(default)]
    pub air_date: Option<String>,

    #[serde(default)]
    pub cover: Option<String>,

    #[serde(default)]
    pub season_number: Option<i64>,

    #[serde(default)]
    pub cover_big: Option<String>,

    #[serde(default)]
    pub vote_average: Option<f64>,
}

/// An episode within a series season.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct XtreamEpisode {
    #[serde(default)]
    pub id: Option<serde_json::Value>,

    #[serde(default)]
    pub episode_num: Option<serde_json::Value>,

    #[serde(default)]
    pub title: Option<String>,

    #[serde(default)]
    pub container_extension: Option<String>,

    #[serde(default)]
    pub info: Option<XtreamEpisodeInfo>,

    #[serde(default)]
    pub custom_sid: Option<String>,

    #[serde(default)]
    pub added: Option<String>,

    #[serde(default)]
    pub season: Option<serde_json::Value>,

    #[serde(default)]
    pub direct_source: Option<String>,

    #[serde(default)]
    pub subtitles: Option<serde_json::Value>,

    /// Generated stream URL (populated by the client).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub url: Option<String>,
}

/// Episode metadata.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct XtreamEpisodeInfo {
    #[serde(default)]
    pub air_date: Option<String>,

    #[serde(default)]
    pub release_date: Option<String>,

    #[serde(default)]
    pub plot: Option<String>,

    #[serde(default)]
    pub rating: Option<serde_json::Value>,

    #[serde(default)]
    pub movie_image: Option<String>,

    #[serde(default)]
    pub cover_big: Option<String>,

    #[serde(default)]
    pub duration_secs: Option<i64>,

    #[serde(default)]
    pub duration: Option<String>,

    #[serde(default)]
    pub tmdb_id: Option<serde_json::Value>,

    #[serde(default)]
    pub video: Option<serde_json::Value>,

    #[serde(default)]
    pub audio: Option<serde_json::Value>,

    #[serde(default)]
    pub bitrate: Option<serde_json::Value>,

    #[serde(default)]
    pub season: Option<serde_json::Value>,
}

// ---------------------------------------------------------------------------
// EPG (Electronic Programme Guide)
// ---------------------------------------------------------------------------

/// Short EPG response from `get_short_epg`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct XtreamShortEpg {
    #[serde(default)]
    pub epg_listings: Vec<XtreamEpgListing>,
}

/// A single EPG listing entry.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct XtreamEpgListing {
    #[serde(default)]
    pub id: Option<String>,

    #[serde(default)]
    pub epg_id: Option<String>,

    /// Title — may be base64-encoded by the server.
    #[serde(default)]
    pub title: Option<String>,

    #[serde(default)]
    pub lang: Option<String>,

    #[serde(default)]
    pub start: Option<String>,

    #[serde(default)]
    pub end: Option<String>,

    /// Description — may be base64-encoded by the server.
    #[serde(default)]
    pub description: Option<String>,

    #[serde(default)]
    pub channel_id: Option<String>,

    #[serde(default)]
    pub start_timestamp: Option<serde_json::Value>,

    #[serde(default)]
    pub stop_timestamp: Option<serde_json::Value>,

    #[serde(default)]
    pub stop: Option<String>,
}

/// Full EPG response from `get_simple_data_table`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct XtreamFullEpg {
    #[serde(default)]
    pub epg_listings: Vec<XtreamFullEpgListing>,
}

/// A full EPG listing entry with archive/playback flags.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct XtreamFullEpgListing {
    #[serde(default)]
    pub id: Option<String>,

    #[serde(default)]
    pub epg_id: Option<String>,

    /// Title — may be base64-encoded by the server.
    #[serde(default)]
    pub title: Option<String>,

    #[serde(default)]
    pub lang: Option<String>,

    #[serde(default)]
    pub start: Option<String>,

    #[serde(default)]
    pub end: Option<String>,

    /// Description — may be base64-encoded by the server.
    #[serde(default)]
    pub description: Option<String>,

    #[serde(default)]
    pub channel_id: Option<String>,

    #[serde(default)]
    pub start_timestamp: Option<serde_json::Value>,

    #[serde(default)]
    pub stop_timestamp: Option<serde_json::Value>,

    /// Whether this programme is currently playing (0 or 1).
    #[serde(default)]
    pub now_playing: Option<i64>,

    /// Whether archive is available for this programme (0 or 1).
    #[serde(default)]
    pub has_archive: Option<i64>,
}

// ---------------------------------------------------------------------------
// Stream format
// ---------------------------------------------------------------------------

/// Preferred stream output format.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum StreamFormat {
    /// MPEG Transport Stream.
    #[default]
    Ts,
    /// HTTP Live Streaming.
    M3u8,
    /// Real-Time Messaging Protocol.
    Rtmp,
}

impl StreamFormat {
    /// File extension for URL construction.
    pub fn extension(self) -> &'static str {
        match self {
            Self::Ts => "ts",
            Self::M3u8 => "m3u8",
            Self::Rtmp => "ts", // RTMP falls back to TS for the URL path
        }
    }
}

impl std::fmt::Display for StreamFormat {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.extension())
    }
}

/// Type of content for stream URL generation.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum StreamType {
    /// Live TV channel.
    Channel,
    /// VOD movie.
    Movie,
    /// Series episode.
    Episode,
}

impl StreamType {
    /// URL path segment for this stream type.
    pub fn path_segment(self) -> &'static str {
        match self {
            Self::Channel => "live",
            Self::Movie => "movie",
            Self::Episode => "series",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn stream_format_extensions() {
        assert_eq!(StreamFormat::Ts.extension(), "ts");
        assert_eq!(StreamFormat::M3u8.extension(), "m3u8");
        assert_eq!(StreamFormat::Rtmp.extension(), "ts");
    }

    #[test]
    fn stream_type_segments() {
        assert_eq!(StreamType::Channel.path_segment(), "live");
        assert_eq!(StreamType::Movie.path_segment(), "movie");
        assert_eq!(StreamType::Episode.path_segment(), "series");
    }

    #[test]
    fn deserialize_profile() {
        let json = r#"{
            "user_info": {
                "username": "test",
                "password": "pass",
                "message": "",
                "auth": 1,
                "status": "Active",
                "exp_date": "1735689600",
                "is_trial": "0",
                "active_cons": 0,
                "created_at": "1704067200",
                "max_connections": "1",
                "allowed_output_formats": ["ts", "m3u8"]
            },
            "server_info": {
                "xui": true,
                "version": "1.5.12",
                "revision": null,
                "url": "example.com",
                "port": "80",
                "https_port": "443",
                "server_protocol": "http",
                "rtmp_port": "8880",
                "timezone": "UTC",
                "timestamp_now": 1704067200,
                "time_now": "2024-01-01 00:00:00"
            }
        }"#;

        let profile: XtreamProfile = serde_json::from_str(json).unwrap();
        assert_eq!(profile.user_info.username, "test");
        assert_eq!(profile.user_info.auth, 1);
        assert_eq!(profile.user_info.status, "Active");
        assert_eq!(profile.user_info.allowed_output_formats.len(), 2);
        assert_eq!(profile.server_info.timezone.as_deref(), Some("UTC"));
    }

    #[test]
    fn deserialize_category() {
        let json = r#"{"category_id": "1", "category_name": "Sports", "parent_id": 0}"#;
        let cat: XtreamCategory = serde_json::from_str(json).unwrap();
        assert_eq!(cat.category_id, "1");
        assert_eq!(cat.category_name, "Sports");
    }

    #[test]
    fn deserialize_channel() {
        let json = r#"{
            "num": 1,
            "name": "BBC One",
            "stream_type": "live",
            "stream_id": 42,
            "stream_icon": "http://img.example.com/bbc1.png",
            "thumbnail": "",
            "epg_channel_id": "bbc1.uk",
            "added": "1704067200",
            "category_id": "1",
            "category_ids": [1],
            "custom_sid": "",
            "tv_archive": 1,
            "direct_source": "",
            "tv_archive_duration": 7
        }"#;

        let ch: XtreamChannel = serde_json::from_str(json).unwrap();
        assert_eq!(ch.stream_id, 42);
        assert_eq!(ch.name, "BBC One");
        assert_eq!(ch.epg_channel_id.as_deref(), Some("bbc1.uk"));
        assert_eq!(ch.tv_archive, Some(1));
    }

    #[test]
    fn deserialize_epg_listing() {
        let json = r#"{
            "id": "123",
            "epg_id": "bbc1.uk",
            "title": "TmV3cw==",
            "lang": "en",
            "start": "2024-01-01 10:00:00",
            "end": "2024-01-01 11:00:00",
            "description": "RGFpbHkgbmV3cw==",
            "channel_id": "bbc1.uk",
            "start_timestamp": "1704106800",
            "stop_timestamp": "1704110400",
            "stop": "2024-01-01 11:00:00"
        }"#;

        let listing: XtreamEpgListing = serde_json::from_str(json).unwrap();
        assert_eq!(listing.id.as_deref(), Some("123"));
        assert_eq!(listing.title.as_deref(), Some("TmV3cw=="));
    }
}
