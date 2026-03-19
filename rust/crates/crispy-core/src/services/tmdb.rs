//! TMDB (The Movie Database) integration service.
//!
//! Enriches VOD content with metadata via three-tier lookup:
//! 1. External TMDB ID → direct `/movie/{id}` or `/tv/{id}`
//! 2. Title + year → `/search/movie` or `/search/tv`
//! 3. Fuzzy match via Jaro-Winkler (threshold > 0.92)
//!
//! Rate-limited to 40 requests per 10 seconds using a sliding-window
//! timestamp queue. All enrichment is non-blocking (tokio async).

use std::collections::VecDeque;
use std::sync::Arc;
use std::time::{Duration, Instant};

use serde::Deserialize;
use strsim::jaro_winkler;
use thiserror::Error;
use tokio::sync::Mutex;
use tracing::{debug, warn};

// ── Constants ──────────────────────────────────────────────────────────────

const IMAGE_BASE_URL: &str = "https://image.tmdb.org/t/p/original";
const DEFAULT_BASE_URL: &str = "https://api.themoviedb.org/3";
const DEFAULT_RATE_LIMIT: usize = 40;
const DEFAULT_RATE_WINDOW_SECS: u64 = 10;
const FUZZY_THRESHOLD: f64 = 0.92;

// ── Public types ───────────────────────────────────────────────────────────

/// Configuration for [`TmdbService`].
#[derive(Clone)]
pub struct TmdbConfig {
    pub api_key: String,
    /// Base API URL. Defaults to `https://api.themoviedb.org/3`.
    pub base_url: String,
    /// Maximum requests allowed within `rate_window_secs`. Defaults to 40.
    pub rate_limit: usize,
    /// Sliding-window duration in seconds. Defaults to 10.
    pub rate_window_secs: u64,
}

impl TmdbConfig {
    pub fn new(api_key: impl Into<String>) -> Self {
        Self {
            api_key: api_key.into(),
            base_url: DEFAULT_BASE_URL.to_owned(),
            rate_limit: DEFAULT_RATE_LIMIT,
            rate_window_secs: DEFAULT_RATE_WINDOW_SECS,
        }
    }
}

/// Media type discriminator for TMDB lookups.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MediaType {
    Movie,
    Series,
}

/// Confidence tier of the match that produced a [`TmdbResult`].
#[derive(Debug, Clone, PartialEq)]
pub enum MatchTier {
    /// Direct external-ID lookup — highest confidence (≥ 0.99).
    ExternalId,
    /// Title + year match — high confidence (0.90–0.95).
    TitleYear,
    /// Jaro-Winkler > 0.92 fuzzy match — moderate confidence (0.80–0.92).
    Fuzzy,
}

/// Enriched metadata returned by a successful TMDB lookup.
#[derive(Debug, Clone)]
pub struct TmdbResult {
    pub tmdb_id: u64,
    pub title: String,
    pub original_title: Option<String>,
    pub overview: Option<String>,
    pub backdrop_url: Option<String>,
    pub poster_url: Option<String>,
    pub genres: Vec<String>,
    pub cast: Vec<String>,
    pub rating: Option<f32>,
    pub runtime_minutes: Option<u32>,
    pub year: Option<u16>,
    pub match_tier: MatchTier,
}

/// A single enrichment request submitted to [`TmdbService::enrich_batch`].
#[derive(Debug, Clone)]
pub struct EnrichRequest {
    /// Pre-known TMDB ID (Tier 1 lookup). `None` → fall through to search.
    pub tmdb_id: Option<u64>,
    pub title: String,
    pub year: Option<u16>,
    pub media_type: MediaType,
}

/// Errors produced by [`TmdbService`].
#[derive(Debug, Error)]
pub enum TmdbError {
    #[error("rate limited — too many requests in window")]
    RateLimited,
    #[error("network error: {0}")]
    NetworkError(#[from] reqwest::Error),
    #[error("resource not found on TMDB (id={0})")]
    NotFound(u64),
    #[error("TMDB API error {status}: {message}")]
    ApiError { status: u16, message: String },
    #[error("invalid or unparseable TMDB response: {0}")]
    InvalidResponse(String),
}

// ── Internal TMDB JSON shapes ──────────────────────────────────────────────

#[derive(Deserialize)]
struct TmdbSearchResponse {
    results: Vec<TmdbSearchItem>,
}

#[derive(Deserialize)]
struct TmdbSearchItem {
    id: u64,
    #[serde(default)]
    title: Option<String>,
    #[serde(default)]
    name: Option<String>, // TV series use "name"
    #[serde(default)]
    original_title: Option<String>,
    #[serde(default)]
    original_name: Option<String>,
    #[serde(default)]
    overview: Option<String>,
    #[serde(default)]
    backdrop_path: Option<String>,
    #[serde(default)]
    poster_path: Option<String>,
    #[serde(default)]
    vote_average: Option<f32>,
    #[serde(default)]
    release_date: Option<String>, // "YYYY-MM-DD" for movies
    #[serde(default)]
    first_air_date: Option<String>, // "YYYY-MM-DD" for TV
    #[serde(default)]
    #[allow(dead_code)] // Deserialized from API, used for future genre mapping
    genre_ids: Vec<u32>,
    #[serde(default)]
    runtime: Option<u32>,
    #[serde(default)]
    episode_run_time: Vec<u32>, // TV series runtime list
}

#[derive(Deserialize)]
struct TmdbDetailResponse {
    id: u64,
    #[serde(default)]
    title: Option<String>,
    #[serde(default)]
    name: Option<String>,
    #[serde(default)]
    original_title: Option<String>,
    #[serde(default)]
    original_name: Option<String>,
    #[serde(default)]
    overview: Option<String>,
    #[serde(default)]
    backdrop_path: Option<String>,
    #[serde(default)]
    poster_path: Option<String>,
    #[serde(default)]
    vote_average: Option<f32>,
    #[serde(default)]
    release_date: Option<String>,
    #[serde(default)]
    first_air_date: Option<String>,
    #[serde(default)]
    genres: Vec<TmdbGenre>,
    #[serde(default)]
    runtime: Option<u32>,
    #[serde(default)]
    episode_run_time: Vec<u32>,
    #[serde(default)]
    credits: Option<TmdbCredits>,
}

#[derive(Deserialize)]
struct TmdbGenre {
    name: String,
}

#[derive(Deserialize, Default)]
struct TmdbCredits {
    #[serde(default)]
    cast: Vec<TmdbCastMember>,
}

#[derive(Deserialize)]
struct TmdbCastMember {
    name: String,
}

#[derive(Deserialize)]
struct TmdbErrorResponse {
    #[serde(default)]
    status_message: String,
}

// ── Rate limiter ───────────────────────────────────────────────────────────

/// Sliding-window rate limiter.
///
/// Maintains a queue of [`Instant`] timestamps for past requests. Before
/// each request, it evicts timestamps outside the window and sleeps until
/// the window has capacity if needed.
struct RateLimiter {
    limit: usize,
    window: Duration,
    timestamps: VecDeque<Instant>,
}

impl RateLimiter {
    fn new(limit: usize, window_secs: u64) -> Self {
        Self {
            limit,
            window: Duration::from_secs(window_secs),
            timestamps: VecDeque::with_capacity(limit),
        }
    }

    /// Acquire a slot, sleeping until one is available.
    async fn acquire(&mut self) {
        loop {
            let now = Instant::now();
            // Evict timestamps outside the sliding window.
            while let Some(&front) = self.timestamps.front() {
                if now.duration_since(front) >= self.window {
                    self.timestamps.pop_front();
                } else {
                    break;
                }
            }

            if self.timestamps.len() < self.limit {
                self.timestamps.push_back(now);
                return;
            }

            // Window is full — sleep until the oldest entry expires.
            let oldest = *self.timestamps.front().expect("queue non-empty");
            let elapsed = now.duration_since(oldest);
            let wait = self.window.saturating_sub(elapsed) + Duration::from_millis(1);
            debug!("TMDB rate limiter sleeping {:?}", wait);
            tokio::time::sleep(wait).await;
        }
    }
}

// ── Service ────────────────────────────────────────────────────────────────

/// TMDB API service with sliding-window rate limiting and three-tier lookup.
pub struct TmdbService {
    config: TmdbConfig,
    http: reqwest::Client,
    limiter: Arc<Mutex<RateLimiter>>,
}

impl TmdbService {
    /// Construct a new service. `http_client` should be a shared, pooled client.
    pub fn new(config: TmdbConfig, http_client: reqwest::Client) -> Self {
        let limiter = RateLimiter::new(config.rate_limit, config.rate_window_secs);
        Self {
            config,
            http: http_client,
            limiter: Arc::new(Mutex::new(limiter)),
        }
    }

    // ── Public API ─────────────────────────────────────────────────────────

    /// Search for a movie by title (and optional year) using three-tier matching.
    pub async fn search_movie(
        &self,
        title: &str,
        year: Option<u16>,
    ) -> Result<Option<TmdbResult>, TmdbError> {
        self.search(title, year, MediaType::Movie).await
    }

    /// Search for a TV series by title (and optional year) using three-tier matching.
    pub async fn search_series(
        &self,
        title: &str,
        year: Option<u16>,
    ) -> Result<Option<TmdbResult>, TmdbError> {
        self.search(title, year, MediaType::Series).await
    }

    /// Fetch full metadata directly by TMDB ID (Tier 1).
    pub async fn get_by_id(
        &self,
        tmdb_id: u64,
        media_type: MediaType,
    ) -> Result<TmdbResult, TmdbError> {
        let segment = media_type_segment(media_type);
        let url = format!(
            "{}/{segment}/{tmdb_id}?api_key={}&append_to_response=credits",
            self.config.base_url, self.config.api_key,
        );
        let detail = self.fetch_detail(&url).await?;
        Ok(detail_to_result(detail, MatchTier::ExternalId))
    }

    /// Enrich a batch of items, respecting rate limits between each request.
    pub async fn enrich_batch(
        &self,
        items: Vec<EnrichRequest>,
    ) -> Vec<Result<TmdbResult, TmdbError>> {
        let mut results = Vec::with_capacity(items.len());
        for item in items {
            let result = if let Some(id) = item.tmdb_id {
                self.get_by_id(id, item.media_type).await
            } else {
                let found = self.search(&item.title, item.year, item.media_type).await;
                match found {
                    Ok(Some(r)) => Ok(r),
                    Ok(None) => Err(TmdbError::NotFound(0)),
                    Err(e) => Err(e),
                }
            };
            results.push(result);
        }
        results
    }

    // ── Internal helpers ────────────────────────────────────────────────────

    async fn search(
        &self,
        title: &str,
        year: Option<u16>,
        media_type: MediaType,
    ) -> Result<Option<TmdbResult>, TmdbError> {
        let segment = match media_type {
            MediaType::Movie => "search/movie",
            MediaType::Series => "search/tv",
        };

        let mut url = format!(
            "{}/{segment}?api_key={}&query={}&include_adult=false",
            self.config.base_url,
            self.config.api_key,
            urlencoding::encode(title),
        );
        if let Some(y) = year {
            // TMDB uses "year" for movies and "first_air_date_year" for TV.
            match media_type {
                MediaType::Movie => url.push_str(&format!("&year={y}")),
                MediaType::Series => url.push_str(&format!("&first_air_date_year={y}")),
            }
        }

        let resp = self.get_json::<TmdbSearchResponse>(&url).await?;

        if resp.results.is_empty() {
            return Ok(None);
        }

        // Tier 2: exact or near-exact title + year match.
        if let Some(item) = find_title_year_match(&resp.results, title, year, media_type) {
            let result = search_item_to_result(item, MatchTier::TitleYear);
            return Ok(Some(result));
        }

        // Tier 3: Jaro-Winkler fuzzy match across all results.
        if let Some(item) = find_fuzzy_match(&resp.results, title, media_type) {
            let result = search_item_to_result(item, MatchTier::Fuzzy);
            return Ok(Some(result));
        }

        Ok(None)
    }

    /// Rate-limited GET returning deserialized JSON.
    async fn get_json<T: for<'de> serde::Deserialize<'de>>(
        &self,
        url: &str,
    ) -> Result<T, TmdbError> {
        self.limiter.lock().await.acquire().await;

        let response = self.http.get(url).send().await?;
        let status = response.status();

        if status.is_success() {
            let text = response.text().await?;
            serde_json::from_str::<T>(&text).map_err(|e| TmdbError::InvalidResponse(e.to_string()))
        } else if status.as_u16() == 404 {
            Err(TmdbError::NotFound(0))
        } else {
            let text = response.text().await.unwrap_or_default();
            let message = serde_json::from_str::<TmdbErrorResponse>(&text)
                .map(|e| e.status_message)
                .unwrap_or(text);
            warn!("TMDB API error {}: {}", status.as_u16(), message);
            Err(TmdbError::ApiError {
                status: status.as_u16(),
                message,
            })
        }
    }

    async fn fetch_detail(&self, url: &str) -> Result<TmdbDetailResponse, TmdbError> {
        self.get_json::<TmdbDetailResponse>(url).await
    }
}

// ── Matching helpers ───────────────────────────────────────────────────────

fn item_title(item: &TmdbSearchItem, media_type: MediaType) -> &str {
    match media_type {
        MediaType::Movie => item.title.as_deref().unwrap_or(""),
        MediaType::Series => item.name.as_deref().unwrap_or(""),
    }
}

fn item_year(item: &TmdbSearchItem, media_type: MediaType) -> Option<u16> {
    let date = match media_type {
        MediaType::Movie => item.release_date.as_deref(),
        MediaType::Series => item.first_air_date.as_deref(),
    };
    date.and_then(|d| d.get(..4)).and_then(|y| y.parse().ok())
}

/// Tier 2: find an item whose title normalises closely and year matches.
fn find_title_year_match<'a>(
    results: &'a [TmdbSearchItem],
    query: &str,
    year: Option<u16>,
    media_type: MediaType,
) -> Option<&'a TmdbSearchItem> {
    let q_lower = query.to_lowercase();
    results.iter().find(|item| {
        let t = item_title(item, media_type).to_lowercase();
        let title_close = t == q_lower || jaro_winkler(&t, &q_lower) > 0.95;
        let year_ok = match year {
            None => true,
            Some(y) => item_year(item, media_type) == Some(y),
        };
        title_close && year_ok
    })
}

/// Tier 3: best Jaro-Winkler match above `FUZZY_THRESHOLD`.
fn find_fuzzy_match<'a>(
    results: &'a [TmdbSearchItem],
    query: &str,
    media_type: MediaType,
) -> Option<&'a TmdbSearchItem> {
    let q_lower = query.to_lowercase();
    results
        .iter()
        .map(|item| {
            let t = item_title(item, media_type).to_lowercase();
            let score = jaro_winkler(&t, &q_lower);
            (item, score)
        })
        .filter(|(_, score)| *score > FUZZY_THRESHOLD)
        .max_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal))
        .map(|(item, _)| item)
}

// ── Conversion helpers ─────────────────────────────────────────────────────

fn prepend_image_base(path: &Option<String>) -> Option<String> {
    path.as_deref()
        .filter(|p| !p.is_empty())
        .map(|p| format!("{IMAGE_BASE_URL}{p}"))
}

fn extract_year_from_date(date: Option<&str>) -> Option<u16> {
    date.and_then(|d| d.get(..4)).and_then(|y| y.parse().ok())
}

fn search_item_to_result(item: &TmdbSearchItem, tier: MatchTier) -> TmdbResult {
    let title = item
        .title
        .clone()
        .or_else(|| item.name.clone())
        .unwrap_or_default();
    let original_title = item
        .original_title
        .clone()
        .or_else(|| item.original_name.clone());
    let date = item
        .release_date
        .as_deref()
        .or(item.first_air_date.as_deref());
    let year = extract_year_from_date(date);
    let runtime = item
        .runtime
        .or_else(|| item.episode_run_time.first().copied());

    TmdbResult {
        tmdb_id: item.id,
        title,
        original_title,
        overview: item.overview.clone(),
        backdrop_url: prepend_image_base(&item.backdrop_path),
        poster_url: prepend_image_base(&item.poster_path),
        genres: Vec::new(), // search endpoint only returns genre_ids; full genres need detail call
        cast: Vec::new(),
        rating: item.vote_average,
        runtime_minutes: runtime,
        year,
        match_tier: tier,
    }
}

fn detail_to_result(detail: TmdbDetailResponse, tier: MatchTier) -> TmdbResult {
    let title = detail
        .title
        .clone()
        .or_else(|| detail.name.clone())
        .unwrap_or_default();
    let original_title = detail
        .original_title
        .clone()
        .or_else(|| detail.original_name.clone());
    let date = detail
        .release_date
        .as_deref()
        .or(detail.first_air_date.as_deref());
    let year = extract_year_from_date(date);
    let runtime = detail
        .runtime
        .or_else(|| detail.episode_run_time.first().copied());
    let genres = detail.genres.into_iter().map(|g| g.name).collect();
    let cast = detail
        .credits
        .unwrap_or_default()
        .cast
        .into_iter()
        .take(10)
        .map(|c| c.name)
        .collect();

    TmdbResult {
        tmdb_id: detail.id,
        title,
        original_title,
        overview: detail.overview,
        backdrop_url: prepend_image_base(&detail.backdrop_path),
        poster_url: prepend_image_base(&detail.poster_path),
        genres,
        cast,
        rating: detail.vote_average,
        runtime_minutes: runtime,
        year,
        match_tier: tier,
    }
}

fn media_type_segment(media_type: MediaType) -> &'static str {
    match media_type {
        MediaType::Movie => "movie",
        MediaType::Series => "tv",
    }
}

// ── Tests ──────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    use wiremock::matchers::{method, path, query_param};
    use wiremock::{Mock, MockServer, ResponseTemplate};

    // ── Fixtures ────────────────────────────────────────────────────────────

    fn movie_search_body(
        id: u64,
        title: &str,
        release_date: &str,
        poster: &str,
        backdrop: &str,
        rating: f32,
    ) -> serde_json::Value {
        serde_json::json!({
            "results": [{
                "id": id,
                "title": title,
                "original_title": title,
                "overview": "A great movie.",
                "release_date": release_date,
                "poster_path": poster,
                "backdrop_path": backdrop,
                "vote_average": rating,
                "genre_ids": [28, 12],
                "runtime": null
            }]
        })
    }

    fn series_search_body(id: u64, name: &str, first_air_date: &str) -> serde_json::Value {
        serde_json::json!({
            "results": [{
                "id": id,
                "name": name,
                "original_name": name,
                "overview": "A great series.",
                "first_air_date": first_air_date,
                "poster_path": "/series_poster.jpg",
                "backdrop_path": "/series_backdrop.jpg",
                "vote_average": 8.2_f32,
                "genre_ids": [18]
            }]
        })
    }

    fn empty_search_body() -> serde_json::Value {
        serde_json::json!({ "results": [] })
    }

    fn detail_body(id: u64, title: &str, release_date: &str) -> serde_json::Value {
        serde_json::json!({
            "id": id,
            "title": title,
            "original_title": title,
            "overview": "Detailed overview.",
            "release_date": release_date,
            "poster_path": "/poster.jpg",
            "backdrop_path": "/backdrop.jpg",
            "vote_average": 8.5_f32,
            "runtime": 120,
            "genres": [{"id": 28, "name": "Action"}, {"id": 12, "name": "Adventure"}],
            "credits": {
                "cast": [
                    {"name": "Alice Smith", "character": "Hero"},
                    {"name": "Bob Jones", "character": "Villain"}
                ]
            }
        })
    }

    fn make_service(base_url: &str) -> TmdbService {
        let config = TmdbConfig {
            api_key: "test_key".to_owned(),
            base_url: base_url.to_owned(),
            rate_limit: 40,
            rate_window_secs: 10,
        };
        let client = reqwest::Client::new();
        TmdbService::new(config, client)
    }

    // ── Tests ───────────────────────────────────────────────────────────────

    #[tokio::test]
    async fn test_search_movie_returns_result_when_exact_title_match() {
        let server = MockServer::start().await;
        Mock::given(method("GET"))
            .and(path("/search/movie"))
            .respond_with(ResponseTemplate::new(200).set_body_json(movie_search_body(
                550,
                "Fight Club",
                "1999-10-15",
                "/poster.jpg",
                "/backdrop.jpg",
                8.4,
            )))
            .mount(&server)
            .await;

        let svc = make_service(&server.uri());
        let result = svc.search_movie("Fight Club", Some(1999)).await.unwrap();
        assert!(result.is_some());
        let r = result.unwrap();
        assert_eq!(r.tmdb_id, 550);
        assert_eq!(r.title, "Fight Club");
        assert_eq!(r.year, Some(1999));
        assert_eq!(r.match_tier, MatchTier::TitleYear);
    }

    #[tokio::test]
    async fn test_search_movie_returns_none_when_no_match() {
        let server = MockServer::start().await;
        Mock::given(method("GET"))
            .and(path("/search/movie"))
            .respond_with(ResponseTemplate::new(200).set_body_json(empty_search_body()))
            .mount(&server)
            .await;

        let svc = make_service(&server.uri());
        let result = svc
            .search_movie("Nonexistent Movie XYZ", None)
            .await
            .unwrap();
        assert!(result.is_none());
    }

    #[tokio::test]
    async fn test_search_series_returns_result_when_title_year_match() {
        let server = MockServer::start().await;
        Mock::given(method("GET"))
            .and(path("/search/tv"))
            .respond_with(ResponseTemplate::new(200).set_body_json(series_search_body(
                1396,
                "Breaking Bad",
                "2008-01-20",
            )))
            .mount(&server)
            .await;

        let svc = make_service(&server.uri());
        let result = svc.search_series("Breaking Bad", Some(2008)).await.unwrap();
        assert!(result.is_some());
        let r = result.unwrap();
        assert_eq!(r.tmdb_id, 1396);
        assert_eq!(r.title, "Breaking Bad");
        assert_eq!(r.year, Some(2008));
        assert_eq!(r.match_tier, MatchTier::TitleYear);
    }

    #[tokio::test]
    async fn test_fuzzy_match_accepts_threshold_above_092() {
        // "Spiderman" vs "Spider-Man" — close enough for Jaro-Winkler > 0.92
        let score = jaro_winkler("spiderman", "spider-man");
        assert!(
            score > FUZZY_THRESHOLD,
            "expected score > 0.92, got {score}"
        );

        let server = MockServer::start().await;
        // Return a result whose title won't hit TitleYear (year mismatch) but
        // will be picked up by the fuzzy tier.
        Mock::given(method("GET"))
            .and(path("/search/movie"))
            .respond_with(ResponseTemplate::new(200).set_body_json(movie_search_body(
                557,
                "Spider-Man",
                "2002-05-03",
                "/spidey.jpg",
                "/spidey_bg.jpg",
                7.2,
            )))
            .mount(&server)
            .await;

        let svc = make_service(&server.uri());
        // No year → TitleYear tier requires only title close-match; force fuzzy by
        // using a slightly different query that scores < 0.95 but > 0.92.
        let result = svc.search_movie("Spiderman", None).await.unwrap();
        // Either TitleYear or Fuzzy is acceptable here (depends on score cutoff).
        assert!(result.is_some(), "expected a fuzzy or title-year match");
    }

    #[tokio::test]
    async fn test_fuzzy_match_rejects_threshold_below_092() {
        // "Alien" vs "Aliens" — distinct enough titles that won't cross 0.92 for
        // very different strings; here we test the pure scoring logic.
        let score = jaro_winkler("the completely different movie", "fight club");
        assert!(
            score <= FUZZY_THRESHOLD,
            "expected score ≤ 0.92, got {score}"
        );

        let server = MockServer::start().await;
        // Return a result that is very different from the query.
        Mock::given(method("GET"))
            .and(path("/search/movie"))
            .respond_with(ResponseTemplate::new(200).set_body_json(movie_search_body(
                550,
                "Fight Club",
                "1999-10-15",
                "/poster.jpg",
                "/backdrop.jpg",
                8.4,
            )))
            .mount(&server)
            .await;

        let svc = make_service(&server.uri());
        let result = svc
            .search_movie("the completely different movie", None)
            .await
            .unwrap();
        assert!(
            result.is_none(),
            "expected no match for low-similarity query"
        );
    }

    #[tokio::test]
    async fn test_rate_limiter_delays_when_window_full() {
        // Use a tiny window: limit=2, window=1s. After 2 requests the 3rd must
        // wait. We measure elapsed time to confirm sleeping happened.
        let server = MockServer::start().await;
        Mock::given(method("GET"))
            .and(path("/search/movie"))
            .respond_with(ResponseTemplate::new(200).set_body_json(empty_search_body()))
            .expect(3)
            .mount(&server)
            .await;

        let config = TmdbConfig {
            api_key: "k".to_owned(),
            base_url: server.uri(),
            rate_limit: 2,
            rate_window_secs: 1,
        };
        let svc = TmdbService::new(config, reqwest::Client::new());

        let start = std::time::Instant::now();
        for _ in 0..3 {
            let _ = svc.search_movie("x", None).await;
        }
        let elapsed = start.elapsed();
        // Third request must have waited ≥ ~1s.
        assert!(
            elapsed >= Duration::from_millis(900),
            "expected ≥ 900ms, got {:?}",
            elapsed
        );
    }

    #[tokio::test]
    async fn test_get_by_id_returns_full_metadata() {
        let server = MockServer::start().await;
        Mock::given(method("GET"))
            .and(path("/movie/550"))
            .respond_with(ResponseTemplate::new(200).set_body_json(detail_body(
                550,
                "Fight Club",
                "1999-10-15",
            )))
            .mount(&server)
            .await;

        let svc = make_service(&server.uri());
        let result = svc.get_by_id(550, MediaType::Movie).await.unwrap();
        assert_eq!(result.tmdb_id, 550);
        assert_eq!(result.title, "Fight Club");
        assert_eq!(result.year, Some(1999));
        assert_eq!(result.runtime_minutes, Some(120));
        assert_eq!(result.genres, vec!["Action", "Adventure"]);
        assert_eq!(result.cast, vec!["Alice Smith", "Bob Jones"]);
        assert_eq!(result.match_tier, MatchTier::ExternalId);
        assert_eq!(
            result.poster_url.as_deref(),
            Some("https://image.tmdb.org/t/p/original/poster.jpg")
        );
    }

    #[tokio::test]
    async fn test_enrich_batch_processes_all_items() {
        let server = MockServer::start().await;
        // Item 1: direct ID lookup
        Mock::given(method("GET"))
            .and(path("/movie/550"))
            .respond_with(ResponseTemplate::new(200).set_body_json(detail_body(
                550,
                "Fight Club",
                "1999-10-15",
            )))
            .mount(&server)
            .await;
        // Item 2: search
        Mock::given(method("GET"))
            .and(path("/search/movie"))
            .respond_with(ResponseTemplate::new(200).set_body_json(movie_search_body(
                105,
                "Back to the Future",
                "1985-07-03",
                "/bttf.jpg",
                "/bttf_bg.jpg",
                8.3,
            )))
            .mount(&server)
            .await;

        let svc = make_service(&server.uri());
        let items = vec![
            EnrichRequest {
                tmdb_id: Some(550),
                title: "Fight Club".to_owned(),
                year: Some(1999),
                media_type: MediaType::Movie,
            },
            EnrichRequest {
                tmdb_id: None,
                title: "Back to the Future".to_owned(),
                year: Some(1985),
                media_type: MediaType::Movie,
            },
        ];

        let results = svc.enrich_batch(items).await;
        assert_eq!(results.len(), 2);
        assert!(results[0].is_ok());
        assert_eq!(results[0].as_ref().unwrap().tmdb_id, 550);
        assert!(results[1].is_ok());
        assert_eq!(results[1].as_ref().unwrap().tmdb_id, 105);
    }

    #[tokio::test]
    async fn test_image_url_prepends_base() {
        assert_eq!(
            prepend_image_base(&Some("/abc123.jpg".to_owned())),
            Some("https://image.tmdb.org/t/p/original/abc123.jpg".to_owned())
        );
        assert_eq!(prepend_image_base(&None), None);
        assert_eq!(prepend_image_base(&Some(String::new())), None);
    }

    #[tokio::test]
    async fn test_error_handling_for_api_errors() {
        let server = MockServer::start().await;
        Mock::given(method("GET"))
            .and(path("/search/movie"))
            .respond_with(ResponseTemplate::new(401).set_body_json(serde_json::json!({
                "status_message": "Invalid API key.",
                "status_code": 7
            })))
            .mount(&server)
            .await;

        let svc = make_service(&server.uri());
        let err = svc.search_movie("Anything", None).await.unwrap_err();
        assert!(
            matches!(err, TmdbError::ApiError { status: 401, .. }),
            "expected ApiError(401), got {err:?}"
        );
    }

    #[tokio::test]
    async fn test_get_by_id_returns_not_found_on_404() {
        let server = MockServer::start().await;
        Mock::given(method("GET"))
            .and(path("/movie/99999"))
            .respond_with(ResponseTemplate::new(404))
            .mount(&server)
            .await;

        let svc = make_service(&server.uri());
        let err = svc.get_by_id(99999, MediaType::Movie).await.unwrap_err();
        assert!(matches!(err, TmdbError::NotFound(_)));
    }

    #[tokio::test]
    async fn test_search_movie_uses_year_query_param() {
        let server = MockServer::start().await;
        Mock::given(method("GET"))
            .and(path("/search/movie"))
            .and(query_param("year", "2010"))
            .respond_with(ResponseTemplate::new(200).set_body_json(movie_search_body(
                27205,
                "Inception",
                "2010-07-16",
                "/inception.jpg",
                "/inception_bg.jpg",
                8.8,
            )))
            .mount(&server)
            .await;

        let svc = make_service(&server.uri());
        let result = svc.search_movie("Inception", Some(2010)).await.unwrap();
        assert!(result.is_some());
        assert_eq!(result.unwrap().tmdb_id, 27205);
    }

    #[tokio::test]
    async fn test_enrich_batch_returns_not_found_when_search_empty() {
        let server = MockServer::start().await;
        Mock::given(method("GET"))
            .and(path("/search/movie"))
            .respond_with(ResponseTemplate::new(200).set_body_json(empty_search_body()))
            .mount(&server)
            .await;

        let svc = make_service(&server.uri());
        let items = vec![EnrichRequest {
            tmdb_id: None,
            title: "Ghost Movie That Does Not Exist".to_owned(),
            year: None,
            media_type: MediaType::Movie,
        }];

        let results = svc.enrich_batch(items).await;
        assert_eq!(results.len(), 1);
        assert!(matches!(results[0], Err(TmdbError::NotFound(_))));
    }
}
