//! Public types and constants for the recommendation
//! engine.

use serde::{Deserialize, Serialize};

// ── Constants ────────────────────────────────────────

/// Minimum history entries before personalised
/// recommendations kick in.
pub(crate) const COLD_START_THRESHOLD: usize = 3;

/// Maximum "Because you watched X" sections.
pub(crate) const MAX_BECAUSE_SECTIONS: usize = 3;

/// Default items per section.
pub(crate) const SECTION_SIZE: usize = 15;

/// Items in the Top Picks section.
pub(crate) const TOP_PICKS_SIZE: usize = 20;

/// Scoring weights for Top Picks.
pub(crate) mod weights {
    pub const GENRE_AFFINITY: f64 = 0.30;
    pub const FAVORITE_BOOST: f64 = 0.20;
    pub const FRESHNESS: f64 = 0.20;
    pub const CONTENT_RATING: f64 = 0.15;
    pub const TRENDING_BOOST: f64 = 0.15;
}

// ── Public types ─────────────────────────────────────

/// A single recommendation item.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Recommendation {
    pub id: String,
    pub title: String,
    pub poster_url: Option<String>,
    pub backdrop_url: Option<String>,
    pub rating: Option<f64>,
    pub year: Option<i32>,
    pub media_type: String,
    pub reason: String,
    pub score: f64,
    pub category: Option<String>,
    pub stream_url: Option<String>,
    pub series_id: Option<String>,
}

/// A recommendation section with title and items.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecommendationSection {
    pub title: String,
    pub section_type: String,
    pub items: Vec<Recommendation>,
}

/// Watch signal from history.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WatchSignal {
    pub item_id: String,
    pub media_type: String,
    pub watched_percent: f64,
    pub last_watched_ms: i64,
}
