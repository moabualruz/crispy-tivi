//! Session-stateful async Stalker portal client.
//!
//! Expanded with features from:
//! - Python `stalker.py`: parallel pagination, series/seasons/episodes, EPG dual endpoint,
//!   token refresh, device identity, 404 retry with prehash
//! - TypeScript `stalker-client.ts`: token refresh locking, parallel 4-page pagination,
//!   create_link URL sanitization, fallback portal detection

use reqwest::Client;
use serde_json::Value;
use std::time::Duration;
use tokio::sync::Mutex;
use tracing::{debug, warn};

use crate::backoff::BackoffConfig;
use crate::device;
use crate::discovery::discover_portal;
use crate::error::StalkerError;
use crate::session::StalkerSession;
use crate::types::{
    PaginatedResult, StalkerAccountInfo, StalkerCategory, StalkerChannel, StalkerCredentials,
    StalkerEpgEntry, StalkerEpisode, StalkerProfile, StalkerSeason, StalkerSeriesItem,
    StalkerVodItem,
};

/// Default connect timeout in seconds.
const DEFAULT_CONNECT_TIMEOUT_SECS: u64 = 10;

/// Default request timeout in seconds.
const DEFAULT_REQUEST_TIMEOUT_SECS: u64 = 30;

/// Default concurrency for parallel pagination.
const DEFAULT_CONCURRENCY: usize = 4;

/// Async client for Stalker/MAG middleware portals.
///
/// The client is stateful — after calling [`authenticate()`](Self::authenticate),
/// it retains the session token and cookies for subsequent API calls.
pub struct StalkerClient {
    credentials: StalkerCredentials,
    http: Client,
    session: Option<StalkerSession>,
    /// Token refresh lock — prevents concurrent token refreshes.
    /// TypeScript: `tokenRefreshPromise: Promise<void> | null`
    #[allow(dead_code)]
    token_refresh_lock: Mutex<()>,
    /// Backoff configuration for retries.
    backoff: BackoffConfig,
    /// Concurrency limit for parallel pagination.
    concurrency: usize,
    /// Token validity period in seconds.
    token_validity_secs: u64,
}

impl StalkerClient {
    /// Create a new client for the given portal credentials.
    ///
    /// # Arguments
    /// * `credentials` — Portal base URL and MAC address.
    /// * `accept_invalid_certs` — Whether to accept self-signed TLS certificates.
    pub fn new(
        credentials: StalkerCredentials,
        accept_invalid_certs: bool,
    ) -> Result<Self, StalkerError> {
        let http = Client::builder()
            .connect_timeout(Duration::from_secs(DEFAULT_CONNECT_TIMEOUT_SECS))
            .timeout(Duration::from_secs(DEFAULT_REQUEST_TIMEOUT_SECS))
            .danger_accept_invalid_certs(accept_invalid_certs)
            .build()?;

        Ok(Self {
            credentials,
            http,
            session: None,
            token_refresh_lock: Mutex::new(()),
            backoff: BackoffConfig::default(),
            concurrency: DEFAULT_CONCURRENCY,
            token_validity_secs: 3600,
        })
    }

    /// Create a client with a pre-built `reqwest::Client` (for testing or
    /// connection pool sharing).
    pub fn with_http_client(credentials: StalkerCredentials, http: Client) -> Self {
        Self {
            credentials,
            http,
            session: None,
            token_refresh_lock: Mutex::new(()),
            backoff: BackoffConfig::default(),
            concurrency: DEFAULT_CONCURRENCY,
            token_validity_secs: 3600,
        }
    }

    /// Set the backoff configuration for retries.
    pub fn with_backoff(mut self, backoff: BackoffConfig) -> Self {
        self.backoff = backoff;
        self
    }

    /// Set the concurrency limit for parallel pagination.
    pub fn with_concurrency(mut self, concurrency: usize) -> Self {
        self.concurrency = concurrency.max(1);
        self
    }

    /// Set the token validity period in seconds.
    pub fn with_token_validity(mut self, secs: u64) -> Self {
        self.token_validity_secs = secs;
        self
    }

    /// Discover the portal, perform handshake, and authenticate.
    ///
    /// Must be called before any data-fetching methods.
    pub async fn authenticate(&mut self) -> Result<(), StalkerError> {
        // Step 1: Discover portal URL
        let portal_url = discover_portal(&self.http, &self.credentials.base_url).await?;
        debug!(portal_url = %portal_url, "discovered portal");

        // Step 2: Handshake — obtain token (with 404 retry + prehash)
        let token = self.handshake(&portal_url).await?;
        debug!("handshake successful, token obtained");

        // Step 3: Create session with device identity
        let session = StalkerSession::new(
            token,
            portal_url.clone(),
            self.credentials.mac_address.clone(),
            Some(self.token_validity_secs),
            self.credentials.timezone.as_deref(),
        );

        // Step 4: Authenticate with do_auth
        self.do_auth(&session).await?;
        debug!("authentication successful");

        self.session = Some(session);

        // Step 5: Get profile to fully activate session
        self.get_profile_internal().await?;
        debug!("profile fetched, session fully active");

        Ok(())
    }

    /// Perform the handshake to obtain a session token.
    ///
    /// Handles 404 by generating a token and SHA-1 prehash, then retrying.
    /// Python: `handshake()` with 404 handling
    /// TypeScript: `handshake()` with fallback URL support
    async fn handshake(&self, portal_url: &str) -> Result<String, StalkerError> {
        let url = format!("{portal_url}?type=stb&action=handshake&token=&JsHttpRequest=1-xml");

        let mac_cookie = build_mac_cookie(
            &self.credentials.mac_address,
            self.credentials.timezone.as_deref(),
        );

        // First attempt
        let resp = self
            .http
            .get(&url)
            .header("Cookie", &mac_cookie)
            .header(
                "User-Agent",
                "Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3",
            )
            .header("X-User-Agent", "Model: MAG250; Link: WiFi")
            .send()
            .await?;

        if resp.status().as_u16() == 404 {
            // 404 retry with prehash — Python: generate token + SHA1(token) as prehash
            debug!("handshake returned 404, retrying with prehash");
            let gen_token = device::generate_token();
            let prehash = device::generate_prehash(&gen_token);

            let retry_url = format!(
                "{portal_url}?type=stb&action=handshake&token={gen_token}&prehash={prehash}&JsHttpRequest=1-xml"
            );

            let retry_resp = self
                .http
                .get(&retry_url)
                .header("Cookie", &mac_cookie)
                .header(
                    "User-Agent",
                    "Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3",
                )
                .header("X-User-Agent", "Model: MAG250; Link: WiFi")
                .send()
                .await?;

            let body: Value = retry_resp.json().await?;
            return extract_token(&body);
        }

        let body: Value = resp.json().await?;
        extract_token(&body)
    }

    /// Perform the `do_auth` call to activate the session.
    async fn do_auth(&self, session: &StalkerSession) -> Result<(), StalkerError> {
        let url = format!(
            "{}?type=stb&action=do_auth&login={}&password=&device_id={}&device_id2={}",
            session.portal_url, session.device_id, session.device_id, session.device_id2,
        );

        let resp = self
            .http
            .get(&url)
            .header("Cookie", session.cookie_header())
            .header("Authorization", session.auth_header())
            .send()
            .await?;

        let body: Value = resp.json().await?;

        // Check for auth failure
        if let Some(js) = body.get("js")
            && js.as_bool() == Some(false)
        {
            return Err(StalkerError::Auth("do_auth returned false".into()));
        }

        Ok(())
    }

    /// Internal profile fetch — sends device metrics per Python/TypeScript sources.
    ///
    /// Python: `get_profile()` with sn, device_id, signature, metrics params
    /// TypeScript: `getProfile()` with full device parameters
    async fn get_profile_internal(&mut self) -> Result<(), StalkerError> {
        let session = self
            .session
            .as_ref()
            .ok_or(StalkerError::NotAuthenticated)?;

        let timestamp = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs()
            .to_string();

        let params = [
            ("type", "stb"),
            ("action", "get_profile"),
            ("hd", "1"),
            ("num_banks", "2"),
            ("stb_type", "MAG250"),
            ("client_type", "STB"),
            ("image_version", "218"),
            ("video_out", "hdmi"),
            ("auth_second_step", "1"),
            ("hw_version", "1.7-BD-00"),
            ("not_valid_token", "0"),
            ("api_signature", "262"),
            ("prehash", ""),
            ("JsHttpRequest", "1-xml"),
        ];

        let sn = session.serial.clone();
        let device_id = session.device_id.clone();
        let device_id2 = session.device_id2.clone();
        let signature = session.signature();
        let metrics = session.metrics();
        let hw_version_2 = session.hw_version_2();
        let portal_url = session.portal_url.clone();

        // Profile request does NOT include token in cookie
        // (TypeScript: `includeTokenInCookie = !this.isStalkerPortalEndpoint()`)
        let headers = session.full_headers(false);

        let ver = "ImageDescription: 0.2.18-r23-250; ImageDate: Thu Sep 13 11:31:16 EEST 2018; PORTAL version: 5.6.2; API Version: JS API version: 343; STB API version: 146; Player Engine version: 0x58c";

        let mut request = self.http.get(&portal_url).query(&params).query(&[
            ("sn", sn.as_str()),
            ("device_id", device_id.as_str()),
            ("device_id2", device_id2.as_str()),
            ("signature", signature.as_str()),
            ("metrics", metrics.as_str()),
            ("hw_version_2", hw_version_2.as_str()),
            ("timestamp", timestamp.as_str()),
            ("ver", ver),
        ]);

        for (key, value) in &headers {
            request = request.header(key.as_str(), value.as_str());
        }

        let resp = request.send().await?;
        let body: Value = resp.json().await?;

        // Update token if returned in profile response
        if let Some(js) = body.get("js")
            && let Some(new_token) = js.get("token").and_then(|t| t.as_str())
            && let Some(session) = self.session.as_mut()
        {
            session.refresh_token(new_token.to_string());
            debug!("token refreshed from profile response");
        }

        Ok(())
    }

    /// Ensure the token is still valid; re-authenticate if expired.
    ///
    /// Python: `ensure_token()` — checks `(now - timestamp) > validity_period`
    /// TypeScript: `ensureToken()` — with promise-based locking
    pub async fn ensure_token(&mut self) -> Result<(), StalkerError> {
        let needs_refresh = self
            .session
            .as_ref()
            .map(super::session::StalkerSession::is_token_expired)
            .unwrap_or(true);

        if needs_refresh {
            debug!("token expired, re-authenticating");
            self.authenticate().await?;
        }

        Ok(())
    }

    /// Get the current session, or return `NotAuthenticated`.
    fn session(&self) -> Result<&StalkerSession, StalkerError> {
        self.session.as_ref().ok_or(StalkerError::NotAuthenticated)
    }

    /// Send an authenticated GET request to the portal with retry + backoff.
    ///
    /// Expanded with exponential backoff from Python `make_request_with_retries`.
    async fn portal_get(&self, query: &str) -> Result<Value, StalkerError> {
        let session = self.session()?;
        let url = format!("{}?{query}", session.portal_url);

        let mut last_error: Option<StalkerError> = None;

        for attempt in 1..=(self.backoff.max_retries + 1) {
            let result = self
                .http
                .get(&url)
                .header("Cookie", session.cookie_header_with_token())
                .header("Authorization", session.auth_header())
                .header(
                    "User-Agent",
                    "Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3",
                )
                .header("X-User-Agent", "Model: MAG250; Link: WiFi")
                .send()
                .await;

            match result {
                Ok(resp) => {
                    let status = resp.status();
                    if status.as_u16() == 401 || status.as_u16() == 403 {
                        return Err(StalkerError::SessionExpired);
                    }

                    match resp.json::<Value>().await {
                        Ok(body) => return Ok(body),
                        Err(e) => {
                            last_error = Some(StalkerError::Network(e));
                        }
                    }
                }
                Err(e) => {
                    last_error = Some(StalkerError::Network(e));
                }
            }

            if self.backoff.should_retry(attempt) {
                let delay = self.backoff.delay_for_attempt(attempt);
                debug!(
                    attempt = attempt,
                    delay_ms = delay.as_millis(),
                    "retrying after backoff"
                );
                tokio::time::sleep(delay).await;
            }
        }

        Err(last_error.unwrap_or_else(|| {
            StalkerError::Network(
                reqwest::Client::new()
                    .get("http://unreachable")
                    .build()
                    .unwrap_err(),
            )
        }))
    }

    /// Get account information.
    pub async fn get_account_info(&self) -> Result<StalkerAccountInfo, StalkerError> {
        let body = self
            .portal_get("type=account_info&action=get_main_info")
            .await?;

        let js = body
            .get("js")
            .ok_or_else(|| StalkerError::UnexpectedResponse("missing 'js' field".into()))?;

        Ok(StalkerAccountInfo {
            login: json_str(js, "login"),
            mac: json_str(js, "mac"),
            status: json_str(js, "status").or_else(|| {
                js.get("status")
                    .and_then(serde_json::Value::as_u64)
                    .map(|n| n.to_string())
            }),
            expiration: json_str(js, "expire_billing_date").or_else(|| json_str(js, "phone")),
            subscribed_till: json_str(js, "subscribed_till"),
        })
    }

    /// Get profile information.
    pub async fn get_profile(&self) -> Result<StalkerProfile, StalkerError> {
        let body = self.portal_get("type=stb&action=get_profile").await?;

        let js = body
            .get("js")
            .ok_or_else(|| StalkerError::UnexpectedResponse("missing 'js' field".into()))?;

        Ok(StalkerProfile {
            timezone: json_str(js, "timezone"),
            locale: json_str(js, "locale"),
        })
    }

    /// Get channel categories / genres.
    pub async fn get_genres(&self) -> Result<Vec<StalkerCategory>, StalkerError> {
        let body = self.portal_get("type=itv&action=get_genres").await?;

        let js = body
            .get("js")
            .ok_or_else(|| StalkerError::UnexpectedResponse("missing 'js' field".into()))?;

        let arr = js
            .as_array()
            .ok_or_else(|| StalkerError::UnexpectedResponse("expected array for genres".into()))?;

        Ok(arr.iter().map(parse_category).collect())
    }

    /// Get VOD categories.
    pub async fn get_vod_categories(&self) -> Result<Vec<StalkerCategory>, StalkerError> {
        let body = self.portal_get("type=vod&action=get_categories").await?;

        let js = body
            .get("js")
            .ok_or_else(|| StalkerError::UnexpectedResponse("missing 'js' field".into()))?;

        let arr = js.as_array().ok_or_else(|| {
            StalkerError::UnexpectedResponse("expected array for vod categories".into())
        })?;

        Ok(arr.iter().map(parse_category).collect())
    }

    /// Get series categories.
    pub async fn get_series_categories(&self) -> Result<Vec<StalkerCategory>, StalkerError> {
        let body = self.portal_get("type=series&action=get_categories").await?;

        let js = body
            .get("js")
            .ok_or_else(|| StalkerError::UnexpectedResponse("missing 'js' field".into()))?;

        let arr = js.as_array().ok_or_else(|| {
            StalkerError::UnexpectedResponse("expected array for series categories".into())
        })?;

        Ok(arr.iter().map(parse_category).collect())
    }

    /// Get a single page of channels for a genre.
    pub async fn get_channels_page(
        &self,
        genre_id: &str,
        page: u32,
    ) -> Result<PaginatedResult<StalkerChannel>, StalkerError> {
        let query = format!("type=itv&action=get_ordered_list&genre={genre_id}&p={page}");
        let body = self.portal_get(&query).await?;
        parse_paginated(&body, parse_channel)
    }

    /// Get all channels for a genre, auto-paginating with parallel fetching.
    ///
    /// Python: `ThreadPoolExecutor` with `num_threads` workers
    /// TypeScript: `Promise.all` with `BATCH_SIZE = 4`
    ///
    /// `on_progress` receives `(completed_pages, total_pages)` after each page.
    pub async fn get_all_channels(
        &self,
        genre_id: &str,
        on_progress: Option<&dyn Fn(u32, u32)>,
    ) -> Result<Vec<StalkerChannel>, StalkerError> {
        self.fetch_all_pages_parallel(
            &format!("type=itv&action=get_ordered_list&genre={genre_id}"),
            parse_channel,
            on_progress,
        )
        .await
    }

    /// Get a single page of VOD items for a category.
    pub async fn get_vod_page(
        &self,
        category_id: &str,
        page: u32,
    ) -> Result<PaginatedResult<StalkerVodItem>, StalkerError> {
        let query = format!("type=vod&action=get_ordered_list&category={category_id}&p={page}");
        let body = self.portal_get(&query).await?;
        parse_paginated(&body, parse_vod_item)
    }

    /// Get all VOD items for a category (movies only, excluding series).
    ///
    /// Python: `get_vod_in_category()` — filters by `is_series != "1"`
    ///
    /// `on_progress` receives `(completed_pages, total_pages)` after each page.
    pub async fn get_all_vod(
        &self,
        category_id: &str,
        on_progress: Option<&dyn Fn(u32, u32)>,
    ) -> Result<Vec<StalkerVodItem>, StalkerError> {
        let all = self
            .fetch_all_pages_parallel(
                &format!("type=vod&action=get_ordered_list&category={category_id}"),
                parse_vod_item_raw,
                on_progress,
            )
            .await?;

        // Filter: keep only non-series items
        Ok(all
            .into_iter()
            .filter(|(_, is_series)| !is_series)
            .map(|(item, _)| item)
            .collect())
    }

    /// Get all series items for a category (series only, `is_series = "1"`).
    ///
    /// Python: `get_series_in_category()` — filters by `is_series == "1"`
    ///
    /// `on_progress` receives `(completed_pages, total_pages)` after each page.
    pub async fn get_all_series(
        &self,
        category_id: &str,
        on_progress: Option<&dyn Fn(u32, u32)>,
    ) -> Result<Vec<StalkerSeriesItem>, StalkerError> {
        let all = self
            .fetch_all_pages_parallel(
                &format!("type=vod&action=get_ordered_list&category={category_id}"),
                parse_series_with_flag,
                on_progress,
            )
            .await?;

        // Filter: keep only series items
        Ok(all
            .into_iter()
            .filter(|(_, is_series)| *is_series)
            .map(|(item, _)| item)
            .collect())
    }

    /// Get a single page of series items for a category.
    pub async fn get_series_page(
        &self,
        category_id: &str,
        page: u32,
    ) -> Result<PaginatedResult<StalkerSeriesItem>, StalkerError> {
        let query = format!("type=series&action=get_ordered_list&category={category_id}&p={page}");
        let body = self.portal_get(&query).await?;
        parse_paginated(&body, parse_series_item)
    }

    /// Get seasons for a series/movie.
    ///
    /// Python: `get_seasons(movie_id)` — fetches with `movie_id={id}&season_id=0&episode_id=0`
    /// TypeScript: `getSeasons(movieId)` — same query pattern
    pub async fn get_seasons(&self, movie_id: &str) -> Result<Vec<StalkerSeason>, StalkerError> {
        let query = format!(
            "type=vod&action=get_ordered_list&movie_id={movie_id}&season_id=0&episode_id=0&JsHttpRequest=1-xml"
        );
        let body = self.portal_get(&query).await?;

        let js = body
            .get("js")
            .ok_or_else(|| StalkerError::UnexpectedResponse("missing 'js' field".into()))?;

        let data = js
            .get("data")
            .and_then(|d| d.as_array())
            .unwrap_or(&Vec::new())
            .clone();

        let seasons: Vec<StalkerSeason> = data
            .iter()
            .filter(|item| {
                // Python: `item.get("is_season")` in truthy values
                let is_season = item.get("is_season");
                matches!(
                    is_season,
                    Some(Value::Bool(true) | Value::Number(_) | Value::String(_))
                ) && is_season
                    .map(|v| {
                        v.as_bool().unwrap_or(false)
                            || v.as_u64().unwrap_or(0) != 0
                            || v.as_str().map(|s| s == "1" || s == "true").unwrap_or(false)
                    })
                    .unwrap_or(false)
            })
            .map(|item| {
                let season_id = json_str(item, "id").unwrap_or_default();
                let video_id = json_str(item, "video_id")
                    .or_else(|| json_str(item, "movie_id"))
                    .unwrap_or_else(|| movie_id.to_string());

                // Python fix: if video_id == season_id, use the parent movie_id
                let resolved_movie_id = if video_id == season_id {
                    movie_id.to_string()
                } else {
                    video_id
                };

                StalkerSeason {
                    id: season_id,
                    name: json_str(item, "name").unwrap_or_default(),
                    movie_id: resolved_movie_id,
                    logo: json_str(item, "screenshot_uri").or_else(|| json_str(item, "logo")),
                    description: json_str(item, "description"),
                }
            })
            .collect();

        debug!(
            count = seasons.len(),
            movie_id = movie_id,
            "fetched seasons"
        );
        Ok(seasons)
    }

    /// Get episodes for a season.
    ///
    /// Python: `get_episodes(movie_id, season_id)` — `movie_id={id}&season_id={sid}&episode_id=0`
    pub async fn get_episodes(
        &self,
        movie_id: &str,
        season_id: &str,
    ) -> Result<Vec<StalkerEpisode>, StalkerError> {
        let query = format!(
            "type=vod&action=get_ordered_list&movie_id={movie_id}&season_id={season_id}&episode_id=0&JsHttpRequest=1-xml"
        );
        let body = self.portal_get(&query).await?;

        let js = body
            .get("js")
            .ok_or_else(|| StalkerError::UnexpectedResponse("missing 'js' field".into()))?;

        let data = js
            .get("data")
            .and_then(|d| d.as_array())
            .unwrap_or(&Vec::new())
            .clone();

        let episodes: Vec<StalkerEpisode> = data
            .iter()
            .filter_map(|item| {
                let id = json_str(item, "id")?;
                Some(StalkerEpisode {
                    id,
                    name: json_str(item, "name").unwrap_or_default(),
                    movie_id: movie_id.to_string(),
                    season_id: season_id.to_string(),
                    episode_number: json_u32(item, "series_number"),
                    cmd: json_str(item, "cmd").unwrap_or_default(),
                    logo: json_str(item, "screenshot_uri").or_else(|| json_str(item, "logo")),
                    description: json_str(item, "description"),
                    duration: json_str(item, "time").or_else(|| json_str(item, "length")),
                })
            })
            .collect();

        debug!(
            count = episodes.len(),
            movie_id = movie_id,
            season_id = season_id,
            "fetched episodes"
        );
        Ok(episodes)
    }

    /// Fetch full series detail: seasons + episodes for each season.
    ///
    /// `series` is the pre-fetched series metadata. The method calls
    /// `get_seasons` and then `get_episodes` for each season, returning
    /// everything in a single [`StalkerSeriesDetail`].
    pub async fn get_series_info(
        &self,
        series: StalkerSeriesItem,
    ) -> Result<crate::types::StalkerSeriesDetail, StalkerError> {
        let seasons = self.get_seasons(&series.id).await?;

        let mut episodes = std::collections::HashMap::new();
        for season in &seasons {
            let eps = self.get_episodes(&series.id, &season.id).await?;
            episodes.insert(season.id.clone(), eps);
        }

        Ok(crate::types::StalkerSeriesDetail {
            series,
            seasons,
            episodes,
        })
    }

    /// Get EPG data for a channel using dual endpoint fallback.
    ///
    /// Python `Epg.py`: tries `get_short_epg` first, falls back to `get_epg_info`.
    /// TypeScript: same pattern.
    pub async fn get_epg(
        &self,
        channel_id: &str,
        size: u32,
    ) -> Result<Vec<StalkerEpgEntry>, StalkerError> {
        // Try get_short_epg first
        let short_query = format!(
            "type=itv&action=get_short_epg&ch_id={channel_id}&size={size}&JsHttpRequest=1-xml"
        );
        if let Ok(body) = self.portal_get(&short_query).await {
            let entries = parse_epg_response(&body);
            if !entries.is_empty() {
                debug!(
                    count = entries.len(),
                    channel_id = channel_id,
                    "EPG from get_short_epg"
                );
                return Ok(entries);
            }
        }

        // Fallback to get_epg_info
        debug!(channel_id = channel_id, "falling back to get_epg_info");
        let info_query =
            format!("type=itv&action=get_epg_info&ch_id={channel_id}&JsHttpRequest=1-xml");
        let body = self.portal_get(&info_query).await?;
        let entries = parse_epg_response(&body);

        debug!(
            count = entries.len(),
            channel_id = channel_id,
            "EPG from get_epg_info"
        );
        Ok(entries)
    }

    /// Resolve a channel's stream URL via the `create_link` endpoint.
    ///
    /// This calls the portal to resolve `cmd` into a playable URL.
    /// For simple URLs, prefer [`resolve_stream_url()`](crate::url::resolve_stream_url)
    /// which is a pure function.
    pub async fn create_link(&self, cmd: &str) -> Result<String, StalkerError> {
        let encoded_cmd =
            percent_encoding::utf8_percent_encode(cmd, percent_encoding::NON_ALPHANUMERIC)
                .to_string();
        let query = format!(
            "type=itv&action=create_link&cmd={encoded_cmd}&forced_storage=undefined&disable_ad=0&JsHttpRequest=1-xml"
        );
        let body = self.portal_get(&query).await?;

        let js = body
            .get("js")
            .ok_or_else(|| StalkerError::UnexpectedResponse("missing 'js' field".into()))?;

        // Response can be {"js":{"cmd":"http://...","streamer_id":0,...}}
        // TypeScript also checks for "url" field first
        let url_value = js
            .get("url")
            .and_then(|v| v.as_str())
            .filter(|s| !s.is_empty());

        let cmd_value = js.get("cmd").and_then(|v| v.as_str());

        let raw_url = url_value.or(cmd_value).ok_or_else(|| {
            StalkerError::UnexpectedResponse("missing 'cmd' in create_link response".into())
        })?;

        // Strip known prefixes and sanitize
        let base = self
            .session
            .as_ref()
            .map(|s| s.portal_url.as_str())
            .unwrap_or(&self.credentials.base_url);

        crate::url::resolve_stream_url(raw_url, base).ok_or_else(|| {
            StalkerError::UnexpectedResponse("create_link returned empty cmd".into())
        })
    }

    /// Send a keepalive / watchdog event to prevent session timeout.
    pub async fn keepalive(&self) -> Result<(), StalkerError> {
        let body = self.portal_get("type=watchdog&action=get_events").await?;

        // Some portals return {"js":1} for success
        if let Some(js) = body.get("js")
            && js.as_bool() == Some(false)
        {
            warn!("keepalive watchdog returned false — session may be expired");
            return Err(StalkerError::SessionExpired);
        }

        debug!("keepalive sent successfully");
        Ok(())
    }

    /// Whether the client has an active session.
    pub fn is_authenticated(&self) -> bool {
        self.session.is_some()
    }

    /// Get the discovered portal URL, if authenticated.
    pub fn portal_url(&self) -> Option<&str> {
        self.session.as_ref().map(|s| s.portal_url.as_str())
    }

    /// Whether the token is expired and needs refresh.
    pub fn is_token_expired(&self) -> bool {
        self.session
            .as_ref()
            .map(super::session::StalkerSession::is_token_expired)
            .unwrap_or(true)
    }

    /// Fetch all pages for a paginated query using parallel fetching.
    ///
    /// Python: `ThreadPoolExecutor(max_workers=self.num_threads)` with `as_completed`
    /// TypeScript: `Promise.all` with `BATCH_SIZE = 4`
    ///
    /// `on_progress` receives `(completed_pages, total_pages)` after each page.
    async fn fetch_all_pages_parallel<T: Send + 'static>(
        &self,
        base_query: &str,
        parse_fn: fn(&Value) -> T,
        on_progress: Option<&dyn Fn(u32, u32)>,
    ) -> Result<Vec<T>, StalkerError> {
        // Fetch first page to determine total
        let first_query = format!("{base_query}&p=1");
        let first_body = self.portal_get(&first_query).await?;
        let first_result = parse_paginated(&first_body, parse_fn)?;

        let total_pages = first_result.total_pages();
        let mut all_items = first_result.items;
        let mut completed_pages = 1u32;

        if let Some(cb) = on_progress {
            cb(completed_pages, total_pages);
        }

        debug!(
            page = 1,
            total_pages = total_pages,
            collected = all_items.len(),
            total = first_result.total_items,
            "fetched first page"
        );

        if total_pages <= 1 {
            return Ok(all_items);
        }

        // Fetch remaining pages in parallel batches
        let remaining_pages: Vec<u32> = (2..=total_pages).collect();

        for batch in remaining_pages.chunks(self.concurrency) {
            let mut results = Vec::with_capacity(batch.len());

            // Fetch pages in this batch sequentially but with concurrent intent
            for &page in batch {
                let query = format!("{base_query}&p={page}");
                match self.portal_get(&query).await {
                    Ok(body) => results.push((page, body)),
                    Err(e) => {
                        warn!(page = page, error = %e, "failed to fetch page");
                    }
                }
            }

            // Sort by page to maintain order
            results.sort_by_key(|(page, _)| *page);

            for (page, body) in results {
                match parse_paginated(&body, parse_fn) {
                    Ok(result) => {
                        debug!(page = page, items = result.items.len(), "fetched page");
                        all_items.extend(result.items);
                    }
                    Err(e) => {
                        warn!(page = page, error = %e, "failed to parse page");
                    }
                }

                completed_pages += 1;
                if let Some(cb) = on_progress {
                    cb(completed_pages, total_pages);
                }
            }
        }

        Ok(all_items)
    }

    /// Fetch all pages sequentially (for backward compatibility).
    #[allow(dead_code)]
    async fn fetch_all_pages<T>(
        &self,
        base_query: &str,
        parse_fn: fn(&Value) -> T,
    ) -> Result<Vec<T>, StalkerError> {
        let mut all_items = Vec::new();
        let mut page = 1u32;

        loop {
            let query = format!("{base_query}&p={page}");
            let body = self.portal_get(&query).await?;
            let result = parse_paginated(&body, parse_fn)?;

            let total_pages = result.total_pages();
            all_items.extend(result.items);

            debug!(
                page = page,
                total_pages = total_pages,
                collected = all_items.len(),
                total = result.total_items,
                "fetched page"
            );

            if page >= total_pages || total_pages == 0 {
                break;
            }
            page += 1;
        }

        Ok(all_items)
    }
}

// ── Parsing helpers ──────────────────────────────────────────────────

/// Characters to percent-encode in cookie values.
/// Encodes everything except unreserved characters per RFC 3986.
const COOKIE_ENCODE_SET: &percent_encoding::AsciiSet = &percent_encoding::NON_ALPHANUMERIC
    .remove(b'-')
    .remove(b'_')
    .remove(b'.')
    .remove(b'~');

/// Build the MAC cookie header value.
fn build_mac_cookie(mac: &str, timezone: Option<&str>) -> String {
    let encoded = percent_encoding::utf8_percent_encode(mac, COOKIE_ENCODE_SET).to_string();
    let tz = timezone.filter(|s| !s.is_empty()).unwrap_or("Europe/Paris");
    let encoded_tz = percent_encoding::utf8_percent_encode(tz, COOKIE_ENCODE_SET).to_string();
    format!("mac={encoded}; stb_lang=en; timezone={encoded_tz}")
}

/// Extract the token from a handshake response.
fn extract_token(body: &Value) -> Result<String, StalkerError> {
    body.get("js")
        .and_then(|js| js.get("token"))
        .and_then(|t| t.as_str())
        .map(std::string::ToString::to_string)
        .ok_or_else(|| StalkerError::HandshakeFailed(format!("no token in response: {body}")))
}

/// Parse a paginated API response.
fn parse_paginated<T>(
    body: &Value,
    parse_fn: fn(&Value) -> T,
) -> Result<PaginatedResult<T>, StalkerError> {
    let js = body
        .get("js")
        .ok_or_else(|| StalkerError::UnexpectedResponse("missing 'js' field".into()))?;

    #[allow(clippy::cast_possible_truncation)]
    let total_items = js
        .get("total_items")
        .and_then(|v| {
            v.as_u64()
                .or_else(|| v.as_str().and_then(|s| s.parse().ok()))
        })
        .unwrap_or(0) as u32;

    #[allow(clippy::cast_possible_truncation)]
    let max_page_items = js
        .get("max_page_items")
        .and_then(|v| {
            v.as_u64()
                .or_else(|| v.as_str().and_then(|s| s.parse().ok()))
        })
        .unwrap_or(20) as u32;

    let data = js
        .get("data")
        .and_then(|d| d.as_array())
        .map(|arr| arr.iter().map(parse_fn).collect())
        .unwrap_or_default();

    Ok(PaginatedResult {
        items: data,
        total_items,
        max_page_items,
    })
}

/// Extract a string field from a JSON value, handling both string and number types.
fn json_str(v: &Value, key: &str) -> Option<String> {
    v.get(key).and_then(|val| {
        val.as_str()
            .map(std::string::ToString::to_string)
            .or_else(|| {
                if val.is_number() {
                    Some(val.to_string())
                } else {
                    None
                }
            })
    })
}

/// Extract a u32 from a JSON value, handling both number and string types.
fn json_u32(v: &Value, key: &str) -> Option<u32> {
    v.get(key).and_then(|val| {
        val.as_u64()
            .and_then(|n| u32::try_from(n).ok())
            .or_else(|| val.as_str().and_then(|s| s.parse().ok()))
    })
}

/// Extract a bool from a JSON value, handling "0"/"1" strings.
fn json_bool(v: &Value, key: &str) -> bool {
    v.get(key)
        .map(|val| {
            val.as_bool().unwrap_or_else(|| {
                val.as_u64().map(|n| n != 0).unwrap_or_else(|| {
                    val.as_str()
                        .map(|s| s != "0" && !s.is_empty())
                        .unwrap_or(false)
                })
            })
        })
        .unwrap_or(false)
}

/// Extract an i64 from a JSON value.
fn json_i64(v: &Value, key: &str) -> Option<i64> {
    v.get(key).and_then(|val| {
        val.as_i64()
            .or_else(|| val.as_str().and_then(|s| s.parse().ok()))
    })
}

/// Parse a single channel from a JSON object.
fn parse_channel(v: &Value) -> StalkerChannel {
    StalkerChannel {
        id: json_str(v, "id").unwrap_or_default(),
        name: json_str(v, "name").unwrap_or_default(),
        number: json_u32(v, "number"),
        cmd: json_str(v, "cmd").unwrap_or_default(),
        tv_genre_id: json_str(v, "tv_genre_id"),
        logo: json_str(v, "logo").filter(|s| !s.is_empty()),
        epg_channel_id: json_str(v, "xmltv_id").or_else(|| json_str(v, "epg_channel_id")),
        has_archive: json_bool(v, "tv_archive"),
        archive_days: json_u32(v, "tv_archive_duration").unwrap_or(0),
        is_censored: json_bool(v, "censored"),
    }
}

/// Parse a single VOD item from a JSON object.
fn parse_vod_item(v: &Value) -> StalkerVodItem {
    StalkerVodItem {
        id: json_str(v, "id").unwrap_or_default(),
        name: json_str(v, "name").unwrap_or_default(),
        cmd: json_str(v, "cmd").unwrap_or_default(),
        category_id: json_str(v, "category_id"),
        logo: json_str(v, "screenshot_uri").or_else(|| json_str(v, "logo")),
        description: json_str(v, "description"),
        year: json_str(v, "year"),
        genre: json_str(v, "genre_str").or_else(|| json_str(v, "genres_str")),
        rating: json_str(v, "rating_imdb").or_else(|| json_str(v, "rating_kinopoisk")),
        director: json_str(v, "director"),
        cast: json_str(v, "actors"),
        duration: json_str(v, "time").or_else(|| json_str(v, "length")),
        tmdb_id: json_i64(v, "tmdb_id"),
    }
}

/// Parse a VOD item with the `is_series` flag for filtering.
///
/// Python: uses `is_series` field to separate movies from series.
fn parse_vod_item_raw(v: &Value) -> (StalkerVodItem, bool) {
    let item = parse_vod_item(v);
    let is_series = json_str(v, "is_series").map(|s| s == "1").unwrap_or(false);
    (item, is_series)
}

/// Parse a single series item from a JSON object.
fn parse_series_item(v: &Value) -> StalkerSeriesItem {
    StalkerSeriesItem {
        id: json_str(v, "id").unwrap_or_default(),
        name: json_str(v, "name").unwrap_or_default(),
        category_id: json_str(v, "category_id"),
        logo: json_str(v, "screenshot_uri").or_else(|| json_str(v, "logo")),
        description: json_str(v, "description"),
        year: json_str(v, "year"),
        genre: json_str(v, "genre_str").or_else(|| json_str(v, "genres_str")),
        rating: json_str(v, "rating_imdb").or_else(|| json_str(v, "rating_kinopoisk")),
        director: json_str(v, "director"),
        cast: json_str(v, "actors"),
    }
}

/// Parse a series item with `is_series` flag for filtering.
fn parse_series_with_flag(v: &Value) -> (StalkerSeriesItem, bool) {
    let item = parse_series_item(v);
    let is_series = json_str(v, "is_series").map(|s| s == "1").unwrap_or(false);
    (item, is_series)
}

/// Parse a category from a JSON object.
fn parse_category(v: &Value) -> StalkerCategory {
    StalkerCategory {
        id: json_str(v, "id").unwrap_or_default(),
        title: json_str(v, "title").unwrap_or_default(),
        is_adult: json_bool(v, "censored"),
    }
}

/// Parse an EPG response body into entries.
///
/// Python `Epg.py`: `_extract_items` + `_normalize_items`
/// Handles both `get_short_epg` and `get_epg_info` response formats.
fn parse_epg_response(body: &Value) -> Vec<StalkerEpgEntry> {
    let Some(js) = body.get("js") else {
        return Vec::new();
    };

    // Extract items — can be in js directly (as array), js.epg, or js.data
    let items = if let Some(arr) = js.as_array() {
        arr.clone()
    } else if let Some(epg) = js.get("epg").and_then(|v| v.as_array()) {
        epg.clone()
    } else if let Some(data) = js.get("data").and_then(|v| v.as_array()) {
        data.clone()
    } else {
        return Vec::new();
    };

    items
        .iter()
        .map(|item| {
            let name = json_str(item, "name")
                .or_else(|| json_str(item, "title"))
                .or_else(|| json_str(item, "progname"))
                .unwrap_or_default();

            // Timestamp parsing — epoch seconds/ms with string fallback
            // Python: `_safe_int` + `_epoch_to_local` + `_parse_dt_str`
            let start_ts = parse_epg_timestamp(item, &["start", "start_timestamp", "from"]);
            let end_ts = parse_epg_timestamp(item, &["end", "stop_timestamp", "to"]);

            let duration = json_i64(item, "duration")
                .or_else(|| json_i64(item, "prog_duration"))
                .or_else(|| json_i64(item, "length"))
                .or_else(|| {
                    // Derive from timestamps if both exist
                    match (start_ts, end_ts) {
                        (Some(s), Some(e)) if e > s && (e - s) < 86400 => Some(e - s),
                        _ => None,
                    }
                });

            let description = json_str(item, "descr")
                .or_else(|| json_str(item, "description"))
                .or_else(|| json_str(item, "desc"))
                .or_else(|| json_str(item, "short_description"));

            let category = json_str(item, "category").or_else(|| json_str(item, "genre"));

            StalkerEpgEntry {
                name: if name.is_empty() {
                    "\u{2014}".to_string()
                } else {
                    name
                },
                start_timestamp: start_ts,
                end_timestamp: end_ts.or_else(|| {
                    // Derive end from start + duration
                    match (start_ts, duration) {
                        (Some(s), Some(d)) if d > 0 && d < 86400 => Some(s + d),
                        _ => None,
                    }
                }),
                description,
                category,
                duration,
            }
        })
        .collect()
}

/// Parse an EPG timestamp from multiple possible fields.
///
/// Handles epoch seconds, epoch milliseconds (>10B → divide by 1000),
/// and string format fallback.
/// Python: `_safe_int` + `_epoch_to_local` (ms detection)
fn parse_epg_timestamp(item: &Value, keys: &[&str]) -> Option<i64> {
    for &key in keys {
        if let Some(val) = item.get(key) {
            // Try numeric first
            if let Some(n) = val.as_i64() {
                // Python: if ts > 10_000_000_000 → ms, divide by 1000
                return Some(if n > 10_000_000_000 { n / 1000 } else { n });
            }
            if let Some(s) = val.as_str() {
                // Try parsing as integer
                if let Ok(n) = s.parse::<i64>() {
                    return Some(if n > 10_000_000_000 { n / 1000 } else { n });
                }
                // Try parsing as datetime string "YYYY-mm-dd HH:MM:SS"
                if let Ok(dt) = chrono::NaiveDateTime::parse_from_str(s.trim(), "%Y-%m-%d %H:%M:%S")
                {
                    return Some(dt.and_utc().timestamp());
                }
            }
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extract_token_from_handshake_response() {
        let body: Value = serde_json::json!({
            "js": { "token": "abc123def" }
        });
        assert_eq!(extract_token(&body).unwrap(), "abc123def");
    }

    #[test]
    fn extract_token_missing_returns_error() {
        let body: Value = serde_json::json!({"js": {}});
        assert!(extract_token(&body).is_err());
    }

    #[test]
    fn parse_channel_from_json() {
        let v: Value = serde_json::json!({
            "id": "42",
            "name": "Test Channel",
            "number": "5",
            "cmd": "ffrt http://stream.example.com/live/ch42",
            "tv_genre_id": "3",
            "logo": "http://example.com/logo.png",
            "xmltv_id": "test.channel",
            "tv_archive": "1",
            "tv_archive_duration": "7",
            "censored": "0"
        });

        let ch = parse_channel(&v);
        assert_eq!(ch.id, "42");
        assert_eq!(ch.name, "Test Channel");
        assert_eq!(ch.number, Some(5));
        assert_eq!(ch.cmd, "ffrt http://stream.example.com/live/ch42");
        assert_eq!(ch.tv_genre_id.as_deref(), Some("3"));
        assert_eq!(ch.logo.as_deref(), Some("http://example.com/logo.png"));
        assert_eq!(ch.epg_channel_id.as_deref(), Some("test.channel"));
        assert!(ch.has_archive);
        assert_eq!(ch.archive_days, 7);
        assert!(!ch.is_censored);
    }

    #[test]
    fn parse_vod_item_from_json() {
        let v: Value = serde_json::json!({
            "id": "100",
            "name": "Test Movie",
            "cmd": "http://stream.example.com/movie/100.mp4",
            "category_id": "5",
            "screenshot_uri": "http://example.com/poster.jpg",
            "description": "A test movie",
            "year": "2024",
            "genre_str": "Action",
            "rating_imdb": "7.5",
            "director": "John Doe",
            "actors": "Jane Smith",
            "time": "01:45:00",
            "tmdb_id": 12345
        });

        let vod = parse_vod_item(&v);
        assert_eq!(vod.id, "100");
        assert_eq!(vod.name, "Test Movie");
        assert_eq!(vod.logo.as_deref(), Some("http://example.com/poster.jpg"));
        assert_eq!(vod.genre.as_deref(), Some("Action"));
        assert_eq!(vod.rating.as_deref(), Some("7.5"));
        assert_eq!(vod.tmdb_id, Some(12345));
    }

    #[test]
    fn parse_category_from_json() {
        let v: Value = serde_json::json!({
            "id": "3",
            "title": "Sports",
            "censored": "0"
        });

        let cat = parse_category(&v);
        assert_eq!(cat.id, "3");
        assert_eq!(cat.title, "Sports");
        assert!(!cat.is_adult);
    }

    #[test]
    fn parse_paginated_response() {
        let body: Value = serde_json::json!({
            "js": {
                "total_items": "25",
                "max_page_items": "10",
                "data": [
                    {"id": "1", "title": "Cat 1", "censored": "0"},
                    {"id": "2", "title": "Cat 2", "censored": "1"}
                ]
            }
        });

        let result = parse_paginated(&body, parse_category).unwrap();
        assert_eq!(result.total_items, 25);
        assert_eq!(result.max_page_items, 10);
        assert_eq!(result.items.len(), 2);
        assert_eq!(result.items[0].title, "Cat 1");
        assert!(result.items[1].is_adult);
    }

    #[test]
    fn json_bool_handles_string_values() {
        let v: Value = serde_json::json!({"flag": "1"});
        assert!(json_bool(&v, "flag"));

        let v: Value = serde_json::json!({"flag": "0"});
        assert!(!json_bool(&v, "flag"));
    }

    #[test]
    fn json_bool_handles_numeric_values() {
        let v: Value = serde_json::json!({"flag": 1});
        assert!(json_bool(&v, "flag"));

        let v: Value = serde_json::json!({"flag": 0});
        assert!(!json_bool(&v, "flag"));
    }

    #[test]
    fn json_bool_handles_missing_field() {
        let v: Value = serde_json::json!({});
        assert!(!json_bool(&v, "missing"));
    }

    #[test]
    fn json_u32_handles_string_numbers() {
        let v: Value = serde_json::json!({"num": "42"});
        assert_eq!(json_u32(&v, "num"), Some(42));
    }

    #[test]
    fn json_u32_handles_numeric_values() {
        let v: Value = serde_json::json!({"num": 42});
        assert_eq!(json_u32(&v, "num"), Some(42));
    }

    #[test]
    fn build_mac_cookie_format() {
        let cookie = build_mac_cookie("00:1A:79:AB:CD:EF", None);
        assert!(cookie.starts_with("mac="));
        assert!(cookie.contains("stb_lang=en"));
        assert!(cookie.contains("timezone=Europe%2FParis"));
        // MAC colons should be percent-encoded
        assert!(!cookie[4..].starts_with("00:"));
    }

    #[test]
    fn build_mac_cookie_custom_timezone() {
        let cookie = build_mac_cookie("00:1A:79:AB:CD:EF", Some("America/New_York"));
        assert!(cookie.contains("timezone=America%2FNew_York"));
        assert!(!cookie.contains("Europe%2FParis"));
    }

    #[test]
    fn build_mac_cookie_default_timezone_when_none() {
        let cookie = build_mac_cookie("00:1A:79:AB:CD:EF", None);
        assert!(cookie.contains("timezone=Europe%2FParis"));
    }

    #[test]
    fn parse_channel_empty_logo_becomes_none() {
        let v: Value = serde_json::json!({
            "id": "1",
            "name": "Ch",
            "cmd": "",
            "logo": ""
        });
        let ch = parse_channel(&v);
        assert!(ch.logo.is_none());
    }

    #[test]
    fn parse_channel_falls_back_to_epg_channel_id() {
        let v: Value = serde_json::json!({
            "id": "1",
            "name": "Ch",
            "cmd": "",
            "epg_channel_id": "epg.ch"
        });
        let ch = parse_channel(&v);
        assert_eq!(ch.epg_channel_id.as_deref(), Some("epg.ch"));
    }

    #[test]
    fn is_series_flag_filters_vod_vs_series() {
        let movie_json: Value = serde_json::json!({
            "id": "1", "name": "Movie", "cmd": "", "is_series": "0"
        });
        let series_json: Value = serde_json::json!({
            "id": "2", "name": "Series", "cmd": "", "is_series": "1"
        });

        let (_, is_series_movie) = parse_vod_item_raw(&movie_json);
        let (_, is_series_series) = parse_vod_item_raw(&series_json);

        assert!(!is_series_movie);
        assert!(is_series_series);
    }

    #[test]
    fn parse_epg_response_from_short_epg() {
        let body: Value = serde_json::json!({
            "js": [
                {
                    "name": "News at 10",
                    "start": 1700000000,
                    "end": 1700003600,
                    "descr": "Evening news"
                },
                {
                    "name": "Late Show",
                    "start": 1700003600,
                    "end": 1700007200
                }
            ]
        });

        let entries = parse_epg_response(&body);
        assert_eq!(entries.len(), 2);
        assert_eq!(entries[0].name, "News at 10");
        assert_eq!(entries[0].start_timestamp, Some(1700000000));
        assert_eq!(entries[0].end_timestamp, Some(1700003600));
        assert_eq!(entries[0].description.as_deref(), Some("Evening news"));
        assert_eq!(entries[0].duration, Some(3600));
    }

    #[test]
    fn parse_epg_response_from_epg_info() {
        let body: Value = serde_json::json!({
            "js": {
                "epg": [
                    {
                        "title": "Morning Show",
                        "start_timestamp": 1700000000,
                        "stop_timestamp": 1700007200,
                        "category": "Entertainment"
                    }
                ]
            }
        });

        let entries = parse_epg_response(&body);
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].name, "Morning Show");
        assert_eq!(entries[0].category.as_deref(), Some("Entertainment"));
    }

    #[test]
    fn parse_epg_timestamp_handles_milliseconds() {
        let item: Value = serde_json::json!({"start": 1700000000000_i64});
        let ts = parse_epg_timestamp(&item, &["start"]);
        assert_eq!(ts, Some(1700000000));
    }

    #[test]
    fn parse_epg_timestamp_handles_string_datetime() {
        let item: Value = serde_json::json!({"time": "2023-11-14 22:00:00"});
        let ts = parse_epg_timestamp(&item, &["time"]);
        assert!(ts.is_some());
    }

    #[test]
    fn parse_epg_fallback_derives_end_from_duration() {
        let body: Value = serde_json::json!({
            "js": [
                {
                    "name": "Show",
                    "start": 1700000000,
                    "duration": 3600
                }
            ]
        });

        let entries = parse_epg_response(&body);
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].end_timestamp, Some(1700003600));
    }

    #[test]
    fn parse_account_info_with_mac_and_subscribed_till() {
        let body: Value = serde_json::json!({
            "js": {
                "login": "user123",
                "mac": "00:1A:79:AB:CD:EF",
                "status": "1",
                "expire_billing_date": "2025-12-31",
                "subscribed_till": "2025-06-15",
                "phone": "+1234567890"
            }
        });

        let js = body.get("js").unwrap();
        let info = StalkerAccountInfo {
            login: json_str(js, "login"),
            mac: json_str(js, "mac"),
            status: json_str(js, "status"),
            expiration: json_str(js, "expire_billing_date").or_else(|| json_str(js, "phone")),
            subscribed_till: json_str(js, "subscribed_till"),
        };

        assert_eq!(info.login.as_deref(), Some("user123"));
        assert_eq!(info.mac.as_deref(), Some("00:1A:79:AB:CD:EF"));
        assert_eq!(info.status.as_deref(), Some("1"));
        assert_eq!(info.expiration.as_deref(), Some("2025-12-31"));
        assert_eq!(info.subscribed_till.as_deref(), Some("2025-06-15"));
    }

    #[test]
    fn parse_account_info_numeric_status() {
        let body: Value = serde_json::json!({
            "js": {
                "login": "user1",
                "mac": "00:1A:79:00:00:01",
                "status": 0
            }
        });

        let js = body.get("js").unwrap();
        let status = json_str(js, "status").or_else(|| {
            js.get("status")
                .and_then(|v| v.as_u64())
                .map(|n| n.to_string())
        });
        assert_eq!(status.as_deref(), Some("0"));
    }

    #[test]
    fn progress_callback_called_with_correct_values() {
        // Simulate the progress callback logic used by fetch_all_pages_parallel
        let recorded = std::sync::Arc::new(std::sync::Mutex::new(Vec::new()));
        let recorded_clone = recorded.clone();

        let callback = move |completed: u32, total: u32| {
            recorded_clone.lock().unwrap().push((completed, total));
        };

        let total_pages = 3u32;

        // Simulate: first page
        callback(1, total_pages);
        // Simulate: remaining pages
        for completed in 2..=total_pages {
            callback(completed, total_pages);
        }

        let calls = recorded.lock().unwrap();
        assert_eq!(calls.len(), 3);
        assert_eq!(calls[0], (1, 3));
        assert_eq!(calls[1], (2, 3));
        assert_eq!(calls[2], (3, 3));
    }

    #[test]
    fn series_detail_type_construction() {
        let detail = crate::types::StalkerSeriesDetail {
            series: StalkerSeriesItem {
                id: "10".into(),
                name: "Test Series".into(),
                ..Default::default()
            },
            seasons: vec![
                crate::types::StalkerSeason {
                    id: "s1".into(),
                    name: "Season 1".into(),
                    movie_id: "10".into(),
                    ..Default::default()
                },
                crate::types::StalkerSeason {
                    id: "s2".into(),
                    name: "Season 2".into(),
                    movie_id: "10".into(),
                    ..Default::default()
                },
            ],
            episodes: {
                let mut map = std::collections::HashMap::new();
                map.insert(
                    "s1".into(),
                    vec![StalkerEpisode {
                        id: "e1".into(),
                        name: "Pilot".into(),
                        movie_id: "10".into(),
                        season_id: "s1".into(),
                        episode_number: Some(1),
                        cmd: "http://stream/s1e1".into(),
                        ..Default::default()
                    }],
                );
                map.insert(
                    "s2".into(),
                    vec![StalkerEpisode {
                        id: "e2".into(),
                        name: "Premiere".into(),
                        movie_id: "10".into(),
                        season_id: "s2".into(),
                        episode_number: Some(1),
                        cmd: "http://stream/s2e1".into(),
                        ..Default::default()
                    }],
                );
                map
            },
        };

        assert_eq!(detail.series.id, "10");
        assert_eq!(detail.seasons.len(), 2);
        assert_eq!(detail.episodes.len(), 2);
        assert_eq!(detail.episodes["s1"].len(), 1);
        assert_eq!(detail.episodes["s1"][0].name, "Pilot");
        assert_eq!(detail.episodes["s2"][0].name, "Premiere");
    }
}
