//! Protocol-agnostic VOD (Video on Demand) types.

use serde::{Deserialize, Serialize};

/// A single VOD entry (movie, series, or episode).
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct VodEntry {
    /// Unique identifier from the source.
    pub id: String,

    /// Display name.
    pub name: String,

    /// Original / untranslated title.
    pub original_name: Option<String>,

    /// Stream URL.
    pub stream_url: Option<String>,

    /// Content type.
    pub vod_type: VodType,

    /// Poster / cover image URL.
    pub poster_url: Option<String>,

    /// Backdrop / fanart image URL.
    pub backdrop_url: Option<String>,

    /// Plot summary / description.
    pub description: Option<String>,

    /// Content rating (e.g. "PG-13", "TV-MA").
    pub content_rating: Option<String>,

    /// Rating score (0.0 – 10.0).
    pub rating: Option<f64>,

    /// Rating on a 5-point scale.
    pub rating_5based: Option<f64>,

    /// Release year.
    pub year: Option<u32>,

    /// Duration in seconds.
    pub duration: Option<u32>,

    /// Genre / category name.
    pub genre: Option<String>,

    /// Cast members (comma-separated or structured).
    pub cast: Option<String>,

    /// Director(s).
    pub director: Option<String>,

    /// Writer(s).
    pub writer: Option<String>,

    /// File extension (e.g. "mp4", "mkv").
    pub container_extension: Option<String>,

    /// YouTube trailer ID.
    pub youtube_trailer: Option<String>,

    /// TMDB ID for metadata enrichment.
    pub tmdb_id: Option<i64>,

    /// IMDB ID.
    pub imdb_id: Option<String>,

    /// Series ID (for episodes).
    pub series_id: Option<String>,

    /// Season number (for episodes).
    pub season_number: Option<u32>,

    /// Episode number (for episodes).
    pub episode_number: Option<u32>,

    /// Whether this is adult content.
    #[serde(default)]
    pub is_adult: bool,

    /// Xtream custom stream identifier.
    pub custom_sid: Option<String>,

    /// Category IDs (Xtream supports multiple).
    #[serde(default)]
    pub category_ids: Vec<String>,

    /// Direct source / fallback URL.
    pub direct_source: Option<String>,

    /// When this item was added to the source (epoch seconds).
    pub added_at: Option<i64>,

    /// When this item was last modified (epoch seconds).
    pub updated_at: Option<i64>,
}

/// VOD content type.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum VodType {
    #[default]
    Movie,
    Series,
    Episode,
}

impl std::fmt::Display for VodType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Movie => write!(f, "movie"),
            Self::Series => write!(f, "series"),
            Self::Episode => write!(f, "episode"),
        }
    }
}

/// A VOD category / genre.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct VodCategory {
    pub id: String,
    pub name: String,
    pub parent_id: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_vod_type_is_movie() {
        assert_eq!(VodType::default(), VodType::Movie);
    }

    #[test]
    fn vod_type_display() {
        assert_eq!(VodType::Episode.to_string(), "episode");
        assert_eq!(VodType::Series.to_string(), "series");
    }
}
