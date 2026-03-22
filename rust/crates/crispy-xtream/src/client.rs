//! Async Xtream Codes API client.
//!
//! `XtreamClient` is the primary entry point. It wraps a connection-pooled
//! `reqwest::Client` and provides typed methods for every Xtream endpoint.

use std::sync::Arc;
use std::time::Duration;

use reqwest::StatusCode;
use tokio::sync::RwLock;
use tracing::{debug, warn};

use crate::error::XtreamError;
use crate::parse::decode_epg_field;
use crate::types::{
    StreamFormat, StreamType, XtreamCategory, XtreamChannel, XtreamEpisode, XtreamFullEpg,
    XtreamMovie, XtreamMovieListing, XtreamProfile, XtreamShortEpg, XtreamShow, XtreamShowListing,
    XtreamUserProfile,
};
use crate::url::{
    build_api_url, build_stream_url, build_timeshift_url, build_xmltv_url,
    effective_channel_extension,
};

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/// Client configuration with timeouts and TLS settings.
#[derive(Debug, Clone)]
pub struct XtreamClientConfig {
    /// TCP connect timeout (default: 15 s).
    pub connect_timeout: Duration,
    /// Total request timeout (default: 120 s).
    pub request_timeout: Duration,
    /// Accept invalid / self-signed TLS certificates.
    pub accept_invalid_certs: bool,
    /// Preferred stream format (default: TS).
    pub preferred_format: StreamFormat,
}

impl Default for XtreamClientConfig {
    fn default() -> Self {
        Self {
            connect_timeout: Duration::from_secs(15),
            request_timeout: Duration::from_secs(120),
            accept_invalid_certs: false,
            preferred_format: StreamFormat::Ts,
        }
    }
}

// ---------------------------------------------------------------------------
// Credentials
// ---------------------------------------------------------------------------

/// Xtream server credentials. `Debug` is intentionally redacted.
#[derive(Clone)]
pub struct XtreamCredentials {
    pub base_url: String,
    pub username: String,
    pub password: String,
}

impl XtreamCredentials {
    pub fn new(
        base_url: impl Into<String>,
        username: impl Into<String>,
        password: impl Into<String>,
    ) -> Self {
        let mut base = base_url.into();
        // Strip trailing slash for consistent URL building.
        while base.ends_with('/') {
            base.pop();
        }
        Self {
            base_url: base,
            username: username.into(),
            password: password.into(),
        }
    }
}

impl std::fmt::Debug for XtreamCredentials {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("XtreamCredentials")
            .field("base_url", &self.base_url)
            .field("username", &"***")
            .field("password", &"***")
            .finish()
    }
}

// ---------------------------------------------------------------------------
// Client
// ---------------------------------------------------------------------------

/// Async client for the Xtream Codes API.
///
/// Wraps a `reqwest::Client` (connection pooled) and caches the user profile
/// after the first authentication call.
#[derive(Clone)]
pub struct XtreamClient {
    http: reqwest::Client,
    creds: XtreamCredentials,
    config: XtreamClientConfig,
    /// Cached profile after `authenticate()`.
    profile: Arc<RwLock<Option<XtreamUserProfile>>>,
}

impl std::fmt::Debug for XtreamClient {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("XtreamClient")
            .field("creds", &self.creds)
            .field("config", &self.config)
            .finish()
    }
}

impl XtreamClient {
    /// Create a new client with the given credentials and default configuration.
    pub fn new(creds: XtreamCredentials) -> Result<Self, XtreamError> {
        Self::with_config(creds, XtreamClientConfig::default())
    }

    /// Create a new client with explicit configuration.
    pub fn with_config(
        creds: XtreamCredentials,
        config: XtreamClientConfig,
    ) -> Result<Self, XtreamError> {
        let http = reqwest::Client::builder()
            .connect_timeout(config.connect_timeout)
            .timeout(config.request_timeout)
            .danger_accept_invalid_certs(config.accept_invalid_certs)
            .build()
            .map_err(|e| XtreamError::Network(format!("failed to build HTTP client: {e}")))?;

        Ok(Self {
            http,
            creds,
            config,
            profile: Arc::new(RwLock::new(None)),
        })
    }

    /// Create a client from an existing `reqwest::Client` (useful for sharing
    /// a connection pool across multiple crates).
    pub fn with_http_client(
        http: reqwest::Client,
        creds: XtreamCredentials,
        config: XtreamClientConfig,
    ) -> Self {
        Self {
            http,
            creds,
            config,
            profile: Arc::new(RwLock::new(None)),
        }
    }

    // -- Accessors ----------------------------------------------------------

    /// The base URL of the Xtream server.
    pub fn base_url(&self) -> &str {
        &self.creds.base_url
    }

    /// The username used for authentication.
    pub fn username(&self) -> &str {
        &self.creds.username
    }

    /// The configured preferred stream format.
    pub fn preferred_format(&self) -> StreamFormat {
        self.config.preferred_format
    }

    // -- API methods --------------------------------------------------------

    /// Authenticate with the server and cache the profile.
    ///
    /// This is called implicitly by methods that need the user profile
    /// (channel/VOD listings), but you can call it explicitly to verify
    /// credentials early.
    pub async fn authenticate(&self) -> Result<XtreamProfile, XtreamError> {
        let url = build_api_url(
            &self.creds.base_url,
            &self.creds.username,
            &self.creds.password,
            "get_profile",
        );

        debug!(url = %url, "authenticating with Xtream server");
        let profile: XtreamProfile = self.get_json(&url).await?;

        if profile.user_info.auth != 1 {
            return Err(XtreamError::Auth(format!(
                "authentication failed: status={}",
                profile.user_info.status
            )));
        }

        // Cache the profile.
        let mut cached = self.profile.write().await;
        *cached = Some(profile.user_info.clone());

        Ok(profile)
    }

    /// Get the cached user profile, authenticating first if needed.
    pub async fn get_user_profile(&self) -> Result<XtreamUserProfile, XtreamError> {
        {
            let cached = self.profile.read().await;
            if let Some(ref p) = *cached {
                return Ok(p.clone());
            }
        }
        let profile = self.authenticate().await?;
        Ok(profile.user_info)
    }

    // -- Categories ---------------------------------------------------------

    /// Fetch live channel categories.
    pub async fn get_live_categories(&self) -> Result<Vec<XtreamCategory>, XtreamError> {
        let url = build_api_url(
            &self.creds.base_url,
            &self.creds.username,
            &self.creds.password,
            "get_live_categories",
        );
        self.get_json(&url).await
    }

    /// Fetch VOD (movie) categories.
    pub async fn get_vod_categories(&self) -> Result<Vec<XtreamCategory>, XtreamError> {
        let url = build_api_url(
            &self.creds.base_url,
            &self.creds.username,
            &self.creds.password,
            "get_vod_categories",
        );
        self.get_json(&url).await
    }

    /// Fetch series categories.
    pub async fn get_series_categories(&self) -> Result<Vec<XtreamCategory>, XtreamError> {
        let url = build_api_url(
            &self.creds.base_url,
            &self.creds.username,
            &self.creds.password,
            "get_series_categories",
        );
        self.get_json(&url).await
    }

    // -- Live Streams -------------------------------------------------------

    /// Fetch live channels, optionally filtered by category.
    ///
    /// Stream URLs are automatically generated and attached to each channel.
    pub async fn get_live_streams(
        &self,
        category_id: Option<&str>,
    ) -> Result<Vec<XtreamChannel>, XtreamError> {
        // Ensure profile is cached for format resolution.
        let user = self.get_user_profile().await?;

        let action = match category_id {
            Some(cid) => format!("get_live_streams&category_id={cid}"),
            None => "get_live_streams".to_string(),
        };

        let url = build_api_url(
            &self.creds.base_url,
            &self.creds.username,
            &self.creds.password,
            &action,
        );

        let mut channels: Vec<XtreamChannel> = self.get_json(&url).await?;

        // Attach stream URLs.
        let ext =
            effective_channel_extension(self.config.preferred_format, &user.allowed_output_formats);
        for ch in &mut channels {
            ch.url = Some(build_stream_url(
                &self.creds.base_url,
                &self.creds.username,
                &self.creds.password,
                StreamType::Channel,
                ch.stream_id,
                &ext,
            ));
        }

        Ok(channels)
    }

    // -- VOD ----------------------------------------------------------------

    /// Fetch VOD (movie) listings, optionally filtered by category.
    ///
    /// Stream URLs are automatically generated and attached.
    pub async fn get_vod_streams(
        &self,
        category_id: Option<&str>,
    ) -> Result<Vec<XtreamMovieListing>, XtreamError> {
        // Ensure profile is cached.
        let _user = self.get_user_profile().await?;

        let action = match category_id {
            Some(cid) => format!("get_vod_streams&category_id={cid}"),
            None => "get_vod_streams".to_string(),
        };

        let url = build_api_url(
            &self.creds.base_url,
            &self.creds.username,
            &self.creds.password,
            &action,
        );

        let mut movies: Vec<XtreamMovieListing> = self.get_json(&url).await?;

        for movie in &mut movies {
            let ext = movie.container_extension.as_deref().unwrap_or("mp4");
            movie.url = Some(build_stream_url(
                &self.creds.base_url,
                &self.creds.username,
                &self.creds.password,
                StreamType::Movie,
                movie.stream_id,
                ext,
            ));
        }

        Ok(movies)
    }

    /// Fetch detailed information about a specific movie.
    pub async fn get_vod_info(&self, vod_id: i64) -> Result<XtreamMovie, XtreamError> {
        // Ensure profile is cached.
        let _user = self.get_user_profile().await?;

        let action = format!("get_vod_info&vod_id={vod_id}");
        let url = build_api_url(
            &self.creds.base_url,
            &self.creds.username,
            &self.creds.password,
            &action,
        );

        let mut movie: XtreamMovie = self.get_json(&url).await?;

        // Check for "not found" — the API returns `info: []` (empty array)
        // instead of a proper error.
        if movie.info.is_none() {
            return Err(XtreamError::NotFound(format!("movie {vod_id} not found")));
        }

        // Attach stream URL.
        if let Some(ref data) = movie.movie_data {
            let ext = data.container_extension.as_deref().unwrap_or("mp4");
            movie.url = Some(build_stream_url(
                &self.creds.base_url,
                &self.creds.username,
                &self.creds.password,
                StreamType::Movie,
                data.stream_id,
                ext,
            ));
        }

        Ok(movie)
    }

    // -- Series -------------------------------------------------------------

    /// Fetch series listings, optionally filtered by category.
    pub async fn get_series(
        &self,
        category_id: Option<&str>,
    ) -> Result<Vec<XtreamShowListing>, XtreamError> {
        let action = match category_id {
            Some(cid) => format!("get_series&category_id={cid}"),
            None => "get_series".to_string(),
        };

        let url = build_api_url(
            &self.creds.base_url,
            &self.creds.username,
            &self.creds.password,
            &action,
        );

        self.get_json(&url).await
    }

    /// Fetch detailed information about a specific series, including seasons
    /// and episodes. Episode stream URLs are automatically attached.
    pub async fn get_series_info(&self, series_id: i64) -> Result<XtreamShow, XtreamError> {
        let action = format!("get_series_info&series_id={series_id}");
        let url = build_api_url(
            &self.creds.base_url,
            &self.creds.username,
            &self.creds.password,
            &action,
        );

        let mut show: XtreamShow = self.get_json(&url).await?;

        // Check for "not found".
        if show.info.as_ref().is_none_or(|i| i.name.is_none()) {
            return Err(XtreamError::NotFound(format!(
                "series {series_id} not found"
            )));
        }

        // Inject series_id into info (upstream TS library does this).
        if let Some(ref mut info) = show.info {
            info.series_id = Some(series_id);
        }

        // Attach episode stream URLs.
        for episodes in show.episodes.values_mut() {
            for ep in episodes.iter_mut() {
                let ep_id = ep_id_as_i64(ep);
                let ext = ep.container_extension.as_deref().unwrap_or("mp4");
                if let Some(id) = ep_id {
                    ep.url = Some(build_stream_url(
                        &self.creds.base_url,
                        &self.creds.username,
                        &self.creds.password,
                        StreamType::Episode,
                        id,
                        ext,
                    ));
                }
            }
        }

        Ok(show)
    }

    // -- EPG ----------------------------------------------------------------

    /// Fetch short EPG for a channel, with an optional entry limit.
    ///
    /// Base64-encoded titles and descriptions are decoded transparently.
    pub async fn get_short_epg(
        &self,
        stream_id: i64,
        limit: Option<u32>,
    ) -> Result<XtreamShortEpg, XtreamError> {
        let action = match limit {
            Some(l) => format!("get_short_epg&stream_id={stream_id}&limit={l}"),
            None => format!("get_short_epg&stream_id={stream_id}"),
        };

        let url = build_api_url(
            &self.creds.base_url,
            &self.creds.username,
            &self.creds.password,
            &action,
        );

        let mut epg: XtreamShortEpg = self.get_json(&url).await?;

        // Decode base64 fields.
        for listing in &mut epg.epg_listings {
            listing.title = decode_epg_field(&listing.title);
            listing.description = decode_epg_field(&listing.description);
        }

        Ok(epg)
    }

    /// Fetch full EPG for a channel.
    ///
    /// Base64-encoded titles and descriptions are decoded transparently.
    pub async fn get_full_epg(&self, stream_id: i64) -> Result<XtreamFullEpg, XtreamError> {
        let action = format!("get_simple_data_table&stream_id={stream_id}");
        let url = build_api_url(
            &self.creds.base_url,
            &self.creds.username,
            &self.creds.password,
            &action,
        );

        let mut epg: XtreamFullEpg = self.get_json(&url).await?;

        // Decode base64 fields.
        for listing in &mut epg.epg_listings {
            listing.title = decode_epg_field(&listing.title);
            listing.description = decode_epg_field(&listing.description);
        }

        Ok(epg)
    }

    // -- URL helpers (synchronous) ------------------------------------------

    /// Build a stream URL for a given content type and ID.
    pub fn stream_url(&self, stream_type: StreamType, stream_id: i64, extension: &str) -> String {
        build_stream_url(
            &self.creds.base_url,
            &self.creds.username,
            &self.creds.password,
            stream_type,
            stream_id,
            extension,
        )
    }

    /// Build the XMLTV EPG URL.
    pub fn xmltv_url(&self) -> String {
        build_xmltv_url(
            &self.creds.base_url,
            &self.creds.username,
            &self.creds.password,
        )
    }

    /// Build a timeshift/catchup URL.
    pub fn timeshift_url(&self, stream_id: i64, duration_minutes: u32, start: &str) -> String {
        build_timeshift_url(
            &self.creds.base_url,
            &self.creds.username,
            &self.creds.password,
            stream_id,
            duration_minutes,
            start,
        )
    }

    // -- Internal -----------------------------------------------------------

    /// Send a GET request and deserialize the JSON response.
    async fn get_json<T: serde::de::DeserializeOwned>(&self, url: &str) -> Result<T, XtreamError> {
        let response = self
            .http
            .get(url)
            .header("Content-Type", "application/json")
            .send()
            .await?;

        let status = response.status();

        match status {
            StatusCode::UNAUTHORIZED | StatusCode::FORBIDDEN => {
                return Err(XtreamError::Auth(format!("server returned {status}")));
            }
            StatusCode::TOO_MANY_REQUESTS => {
                let retry_after = response
                    .headers()
                    .get("retry-after")
                    .and_then(|v| v.to_str().ok())
                    .and_then(|v| v.parse::<u64>().ok())
                    .unwrap_or(60);
                return Err(XtreamError::RateLimited {
                    retry_after_secs: retry_after,
                });
            }
            s if s.is_server_error() => {
                let body = response.text().await.unwrap_or_default();
                return Err(XtreamError::Network(format!("server error {s}: {body}")));
            }
            _ => {}
        }

        if !status.is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(XtreamError::UnexpectedResponse(format!(
                "unexpected status {status}: {body}"
            )));
        }

        let text = response.text().await?;

        // Some servers return empty responses or `{"info":[]}` for not-found.
        if text.is_empty() {
            return Err(XtreamError::UnexpectedResponse(
                "empty response body".into(),
            ));
        }

        serde_json::from_str(&text).map_err(|e| {
            warn!(
                error = %e,
                body_preview = &text[..text.len().min(200)],
                "failed to parse Xtream response"
            );
            XtreamError::UnexpectedResponse(format!("json parse error: {e}"))
        })
    }
}

/// Extract episode ID as i64 from the polymorphic `id` field.
fn ep_id_as_i64(ep: &XtreamEpisode) -> Option<i64> {
    ep.id.as_ref().and_then(|v| match v {
        serde_json::Value::Number(n) => n.as_i64(),
        serde_json::Value::String(s) => s.parse::<i64>().ok(),
        _ => None,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn credentials_debug_redacts_secrets() {
        let creds = XtreamCredentials::new("http://example.com", "admin", "secret123");
        let debug = format!("{creds:?}");
        assert!(!debug.contains("admin"));
        assert!(!debug.contains("secret123"));
        assert!(debug.contains("***"));
    }

    #[test]
    fn credentials_strip_trailing_slash() {
        let creds = XtreamCredentials::new("http://example.com///", "u", "p");
        assert_eq!(creds.base_url, "http://example.com");
    }

    #[test]
    fn stream_url_via_client() {
        let client =
            XtreamClient::new(XtreamCredentials::new("http://example.com", "user", "pass"))
                .unwrap();

        let url = client.stream_url(StreamType::Channel, 42, "ts");
        assert_eq!(url, "http://example.com/live/user/pass/42.ts");
    }

    #[test]
    fn xmltv_url_via_client() {
        let client =
            XtreamClient::new(XtreamCredentials::new("http://example.com", "user", "pass"))
                .unwrap();

        let url = client.xmltv_url();
        assert_eq!(
            url,
            "http://example.com/xmltv.php?username=user&password=pass"
        );
    }

    #[test]
    fn timeshift_url_via_client() {
        let client =
            XtreamClient::new(XtreamCredentials::new("http://example.com", "user", "pass"))
                .unwrap();

        let url = client.timeshift_url(42, 120, "2024-01-01:10-00");
        assert_eq!(
            url,
            "http://example.com/timeshift/user/pass/120/2024-01-01:10-00/42.ts"
        );
    }

    #[test]
    fn default_config_values() {
        let config = XtreamClientConfig::default();
        assert_eq!(config.connect_timeout, Duration::from_secs(15));
        assert_eq!(config.request_timeout, Duration::from_secs(120));
        assert!(!config.accept_invalid_certs);
        assert_eq!(config.preferred_format, StreamFormat::Ts);
    }

    #[test]
    fn ep_id_from_number() {
        let ep = XtreamEpisode {
            id: Some(serde_json::Value::Number(serde_json::Number::from(42))),
            ..default_episode()
        };
        assert_eq!(ep_id_as_i64(&ep), Some(42));
    }

    #[test]
    fn ep_id_from_string() {
        let ep = XtreamEpisode {
            id: Some(serde_json::Value::String("99".into())),
            ..default_episode()
        };
        assert_eq!(ep_id_as_i64(&ep), Some(99));
    }

    #[test]
    fn ep_id_none() {
        let ep = XtreamEpisode {
            id: None,
            ..default_episode()
        };
        assert_eq!(ep_id_as_i64(&ep), None);
    }

    fn default_episode() -> XtreamEpisode {
        XtreamEpisode {
            id: None,
            episode_num: None,
            title: None,
            container_extension: None,
            info: None,
            custom_sid: None,
            added: None,
            season: None,
            direct_source: None,
            subtitles: None,
            url: None,
        }
    }
}
