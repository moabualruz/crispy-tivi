//! Stalker portal domain types.
//!
//! These are the protocol-native representations returned by the Stalker
//! middleware API. Consumers implement `From<StalkerChannel>` etc. to map
//! into app-specific models.

use serde::{Deserialize, Serialize};

/// Credentials required to connect to a Stalker portal.
#[derive(Clone, Serialize, Deserialize)]
pub struct StalkerCredentials {
    /// Base URL of the portal (e.g. `http://portal.example.com`).
    pub base_url: String,

    /// MAC address in `XX:XX:XX:XX:XX:XX` format.
    pub mac_address: String,

    /// Timezone for cookie header (e.g. `Europe/Paris`).
    /// Defaults to `Europe/Paris` if `None`.
    #[serde(default)]
    pub timezone: Option<String>,
}

impl std::fmt::Debug for StalkerCredentials {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("StalkerCredentials")
            .field("base_url", &self.base_url)
            .field("mac_address", &"[REDACTED]")
            .finish()
    }
}

/// A live TV channel from the Stalker portal.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct StalkerChannel {
    /// Portal-internal channel ID.
    pub id: String,

    /// Display name.
    pub name: String,

    /// Channel number / LCN.
    pub number: Option<u32>,

    /// Raw stream command (may need resolution via `resolve_stream_url`).
    pub cmd: String,

    /// Genre / category ID on the portal.
    pub tv_genre_id: Option<String>,

    /// Channel logo URL.
    pub logo: Option<String>,

    /// EPG channel identifier for programme matching.
    pub epg_channel_id: Option<String>,

    /// Whether catch-up / archive is available.
    #[serde(default)]
    pub has_archive: bool,

    /// Number of archive days available.
    #[serde(default)]
    pub archive_days: u32,

    /// Whether the channel is marked as adult / censored.
    #[serde(default)]
    pub is_censored: bool,
}

/// A VOD (movie) item from the Stalker portal.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct StalkerVodItem {
    /// Portal-internal VOD ID.
    pub id: String,

    /// Display name.
    pub name: String,

    /// Raw stream command.
    pub cmd: String,

    /// Category ID on the portal.
    pub category_id: Option<String>,

    /// Poster / cover image URL.
    pub logo: Option<String>,

    /// Plot summary.
    pub description: Option<String>,

    /// Release year.
    pub year: Option<String>,

    /// Genre string.
    pub genre: Option<String>,

    /// Rating string (e.g. "7.5").
    pub rating: Option<String>,

    /// Director name(s).
    pub director: Option<String>,

    /// Cast members.
    pub cast: Option<String>,

    /// Duration string (e.g. "01:45:00").
    pub duration: Option<String>,

    /// TMDB ID for metadata enrichment.
    pub tmdb_id: Option<i64>,
}

/// A series item from the Stalker portal.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct StalkerSeriesItem {
    /// Portal-internal series ID.
    pub id: String,

    /// Display name.
    pub name: String,

    /// Category ID on the portal.
    pub category_id: Option<String>,

    /// Poster / cover image URL.
    pub logo: Option<String>,

    /// Plot summary.
    pub description: Option<String>,

    /// Release year.
    pub year: Option<String>,

    /// Genre string.
    pub genre: Option<String>,

    /// Rating string.
    pub rating: Option<String>,

    /// Director name(s).
    pub director: Option<String>,

    /// Cast members.
    pub cast: Option<String>,
}

/// A season within a series from the Stalker portal.
///
/// Translated from Python `fetch_season_pages` / TypeScript `getSeasons`.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct StalkerSeason {
    /// Portal-internal season ID.
    pub id: String,

    /// Display name (e.g. "Season 1").
    pub name: String,

    /// Parent movie/series ID.
    pub movie_id: String,

    /// Poster / cover image URL.
    pub logo: Option<String>,

    /// Plot summary.
    pub description: Option<String>,
}

/// An episode within a season from the Stalker portal.
///
/// Translated from Python `fetch_episode_pages` / TypeScript `getEpisodes`.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct StalkerEpisode {
    /// Portal-internal episode ID.
    pub id: String,

    /// Display name (e.g. "Episode 1").
    pub name: String,

    /// Parent movie/series ID.
    pub movie_id: String,

    /// Parent season ID.
    pub season_id: String,

    /// Episode number within the season.
    pub episode_number: Option<u32>,

    /// Raw stream command.
    pub cmd: String,

    /// Poster / cover image URL.
    pub logo: Option<String>,

    /// Plot summary.
    pub description: Option<String>,

    /// Duration string.
    pub duration: Option<String>,
}

/// An EPG (Electronic Programme Guide) entry from the Stalker portal.
///
/// Translated from Python `Epg.py` normalization logic.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct StalkerEpgEntry {
    /// Programme name.
    pub name: String,

    /// Start timestamp (epoch seconds).
    pub start_timestamp: Option<i64>,

    /// End timestamp (epoch seconds).
    pub end_timestamp: Option<i64>,

    /// Programme description.
    pub description: Option<String>,

    /// Category / genre.
    pub category: Option<String>,

    /// Duration in seconds.
    pub duration: Option<i64>,
}

/// A content category from the Stalker portal.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct StalkerCategory {
    /// Category ID.
    pub id: String,

    /// Display title.
    pub title: String,

    /// Whether this category contains adult content.
    #[serde(default)]
    pub is_adult: bool,
}

/// A page of results from a paginated Stalker API endpoint.
#[derive(Debug, Clone)]
pub struct PaginatedResult<T> {
    /// Items on this page.
    pub items: Vec<T>,

    /// Total number of items across all pages.
    pub total_items: u32,

    /// Maximum items per page (server-determined).
    pub max_page_items: u32,
}

impl<T> PaginatedResult<T> {
    /// Total number of pages.
    pub fn total_pages(&self) -> u32 {
        if self.max_page_items == 0 {
            return 1;
        }
        self.total_items.div_ceil(self.max_page_items)
    }
}

/// Account information returned by `get_account_info`.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct StalkerAccountInfo {
    /// Login identifier.
    pub login: Option<String>,

    /// MAC address on the account.
    pub mac: Option<String>,

    /// Account status (active, blocked, etc.).
    pub status: Option<String>,

    /// Subscription expiration date string.
    pub expiration: Option<String>,

    /// Subscription end date from `subscribed_till` field.
    pub subscribed_till: Option<String>,
}

/// Full series detail: the series metadata plus all seasons and episodes.
///
/// Returned by [`StalkerClient::get_series_info`](crate::StalkerClient::get_series_info).
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct StalkerSeriesDetail {
    /// The series item metadata.
    pub series: StalkerSeriesItem,

    /// All seasons for the series.
    pub seasons: Vec<StalkerSeason>,

    /// Episodes keyed by season ID.
    pub episodes: std::collections::HashMap<String, Vec<StalkerEpisode>>,
}

/// Profile information returned by `get_profile`.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct StalkerProfile {
    /// Timezone setting.
    pub timezone: Option<String>,

    /// Locale / language.
    pub locale: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn credentials_debug_redacts_mac() {
        let creds = StalkerCredentials {
            base_url: "http://example.com".into(),
            mac_address: "00:1A:79:AB:CD:EF".into(),
            timezone: None,
        };
        let debug = format!("{creds:?}");
        assert!(debug.contains("[REDACTED]"));
        assert!(!debug.contains("00:1A:79"));
    }

    #[test]
    fn paginated_result_total_pages() {
        let result: PaginatedResult<()> = PaginatedResult {
            items: vec![],
            total_items: 25,
            max_page_items: 10,
        };
        assert_eq!(result.total_pages(), 3);
    }

    #[test]
    fn paginated_result_exact_division() {
        let result: PaginatedResult<()> = PaginatedResult {
            items: vec![],
            total_items: 20,
            max_page_items: 10,
        };
        assert_eq!(result.total_pages(), 2);
    }

    #[test]
    fn paginated_result_zero_max_page_items() {
        let result: PaginatedResult<()> = PaginatedResult {
            items: vec![],
            total_items: 5,
            max_page_items: 0,
        };
        assert_eq!(result.total_pages(), 1);
    }
}
