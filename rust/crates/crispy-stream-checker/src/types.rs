//! Domain types for stream check configuration and results.

use serde::{Deserialize, Serialize};

use crate::backoff::BackoffStrategy;

/// Stream categorization based on HTTP status and data validation.
///
/// Translated from IPTVChecker-Python status strings: 'Alive', 'Dead',
/// 'Geoblocked', 'Retry'.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum StreamCategory {
    /// Stream responded with 2xx and met data threshold.
    Alive,
    /// Stream is unreachable or returned a fatal HTTP status.
    Dead,
    /// Stream returned a geoblock-indicating HTTP status (403, 426, 451, 401, 423).
    Geoblocked,
    /// Stream returned a retryable HTTP status (408, 425, 429, 500, 502-504).
    Retry,
}

/// Configuration for stream checking behavior.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CheckOptions {
    /// Per-stream timeout in milliseconds.
    pub timeout_ms: u64,
    /// Maximum number of concurrent checks.
    pub max_concurrent: usize,
    /// Whether to follow HTTP redirects.
    pub follow_redirects: bool,
    /// Custom User-Agent header value.
    pub user_agent: Option<String>,
    /// Whether to accept invalid/self-signed TLS certificates.
    pub accept_invalid_certs: bool,
    /// Backoff strategy for retries.
    pub backoff: BackoffStrategy,
    /// Maximum number of retry attempts (default: 6).
    pub retries: u32,
    /// Proxy list for geoblock confirmation testing.
    pub proxy_list: Option<Vec<String>>,
    /// Whether to test geoblocked streams via proxies.
    pub test_geoblock: bool,
    /// Minimum bytes for direct streams at depth 0 (default: 500 KB).
    pub min_bytes_direct: u64,
    /// Minimum bytes for nested/segment streams (default: 128 KB).
    pub min_bytes_nested: u64,
    /// Skip ffprobe/ffmpeg media analysis on alive streams.
    pub skip_media_probe: bool,
    /// Skip screenshot capture.
    pub skip_screenshots: bool,
    /// Directory for screenshot output.
    pub screenshot_dir: Option<String>,
}

impl Default for CheckOptions {
    fn default() -> Self {
        Self {
            timeout_ms: 10_000,
            max_concurrent: 10,
            follow_redirects: true,
            user_agent: Some("VLC/3.0.14 LibVLC/3.0.14".to_string()),
            accept_invalid_certs: false,
            backoff: BackoffStrategy::default(),
            retries: 6,
            proxy_list: None,
            test_geoblock: false,
            min_bytes_direct: 512_000, // 500 KB
            min_bytes_nested: 131_072, // 128 KB
            skip_media_probe: false,
            skip_screenshots: false,
            screenshot_dir: None,
        }
    }
}

/// Information about a single stream's availability.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StreamInfo {
    /// Whether the stream responded successfully (2xx status).
    pub available: bool,
    /// HTTP status code returned, if any.
    pub status_code: Option<u16>,
    /// Time from request start to first byte, in milliseconds.
    pub response_time_ms: u64,
    /// Content-Type header value, if present.
    pub content_type: Option<String>,
    /// Content-Length header value, if present.
    pub content_length: Option<u64>,
    /// Error description, if the check failed.
    pub error: Option<String>,
}

/// Result of checking a single stream URL.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CheckResult {
    /// The URL that was checked.
    pub url: String,
    /// Stream availability information.
    pub info: StreamInfo,
    /// Timestamp when the check was performed.
    pub checked_at: chrono::DateTime<chrono::Utc>,
    /// Media probe information (codec, resolution, FPS) if available.
    pub media_info: Option<crispy_media_probe::MediaInfo>,
    /// Categorization of the stream status.
    pub category: StreamCategory,
    /// Human-readable error reason (from `summarize_error`).
    pub error_reason: Option<String>,
    /// Label mismatch warnings (e.g., "Expected 4K, got 1080p").
    pub mismatch_warnings: Vec<String>,
}

/// Aggregated report from a bulk stream check.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BulkCheckReport {
    /// Total number of URLs checked.
    pub total: usize,
    /// Number of available streams (2xx responses).
    pub available: usize,
    /// Number of unavailable streams (non-2xx responses).
    pub unavailable: usize,
    /// Number of streams that produced errors (connection/timeout failures).
    pub errors: usize,
    /// Number of geoblocked streams.
    pub geoblocked: usize,
    /// Individual results for each URL.
    pub results: Vec<CheckResult>,
    /// Total wall-clock time for the bulk check, in milliseconds.
    pub duration_ms: u64,
    /// Results categorized as Alive.
    pub alive_results: Vec<CheckResult>,
    /// Results categorized as Dead.
    pub dead_results: Vec<CheckResult>,
    /// Results categorized as Geoblocked.
    pub geoblocked_results: Vec<CheckResult>,
}
