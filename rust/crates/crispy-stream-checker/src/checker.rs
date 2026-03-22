//! Core stream checking logic with bounded concurrency.

use std::sync::Arc;
use std::time::Instant;

use tokio::sync::Semaphore;
use tracing::{debug, warn};

use crate::error::summarize_error;
use crate::status::{categorize_status, meets_data_threshold};
use crate::types::{BulkCheckReport, CheckOptions, CheckResult, StreamCategory, StreamInfo};

/// Build a `reqwest::Client` configured from [`CheckOptions`].
fn build_client(opts: &CheckOptions) -> Result<reqwest::Client, reqwest::Error> {
    let timeout = std::time::Duration::from_millis(opts.timeout_ms);

    let mut builder = reqwest::Client::builder()
        .timeout(timeout)
        .connect_timeout(std::time::Duration::from_millis(opts.timeout_ms.min(5_000)))
        .redirect(if opts.follow_redirects {
            reqwest::redirect::Policy::limited(5)
        } else {
            reqwest::redirect::Policy::none()
        })
        .danger_accept_invalid_certs(opts.accept_invalid_certs);

    if let Some(ref ua) = opts.user_agent {
        builder = builder.user_agent(ua);
    }

    builder.build()
}

/// Check a single stream URL with retry and backoff support.
///
/// Convenience wrapper around [`check_stream_named`] with no channel name.
pub async fn check_stream(url: &str, opts: &CheckOptions) -> CheckResult {
    check_stream_named(url, None, opts).await
}

/// Check a single stream URL with retry, backoff, media probe, and mismatch detection.
///
/// Performs an HTTP HEAD request first (minimal bandwidth). If the server
/// returns 405 Method Not Allowed, falls back to a GET request. When falling
/// back to GET, enforces `opts.min_bytes_direct` as a data threshold on
/// `content_length` — streams below this threshold are marked Dead with
/// reason "Insufficient data".
///
/// When the stream is categorized as `Alive` and `opts.skip_media_probe` is
/// false, runs `crispy_media_probe::probe_stream` and populates
/// `CheckResult.media_info`. Probe failure is logged but does not change
/// the stream category (probe failure != stream failure).
///
/// If `name` is provided and media probe succeeds with video info,
/// runs `crispy_media_probe::check_label_mismatch` to detect resolution
/// mismatches between the channel label and actual stream resolution.
///
/// Uses `categorize_status()` from the `status` module for HTTP status
/// classification, and applies the configured `BackoffStrategy` on
/// retryable failures.
pub async fn check_stream_named(url: &str, name: Option<&str>, opts: &CheckOptions) -> CheckResult {
    let start = Instant::now();
    let checked_at = chrono::Utc::now();

    // Validate URL before attempting connection.
    if url.is_empty() || reqwest::Url::parse(url).is_err() {
        return CheckResult {
            url: url.to_string(),
            info: StreamInfo {
                available: false,
                status_code: None,
                response_time_ms: start.elapsed().as_millis() as u64,
                content_type: None,
                content_length: None,
                error: Some(format!("invalid URL: {url}")),
            },
            checked_at,
            media_info: None,
            category: StreamCategory::Dead,
            error_reason: Some(format!("invalid URL: {url}")),
            mismatch_warnings: Vec::new(),
        };
    }

    let client = match build_client(opts) {
        Ok(c) => c,
        Err(e) => {
            return CheckResult {
                url: url.to_string(),
                info: StreamInfo {
                    available: false,
                    status_code: None,
                    response_time_ms: start.elapsed().as_millis() as u64,
                    content_type: None,
                    content_length: None,
                    error: Some(format!("failed to build HTTP client: {e}")),
                },
                checked_at,
                media_info: None,
                category: StreamCategory::Dead,
                error_reason: Some(format!("failed to build HTTP client: {e}")),
                mismatch_warnings: Vec::new(),
            };
        }
    };

    let total_attempts = opts.retries.max(1);
    let mut last_error_reason: Option<String> = None;

    for attempt in 0..total_attempts {
        let attempt_start = Instant::now();

        // Try HEAD first (fast, minimal bandwidth).
        let head_result = client.head(url).send().await;

        // Track whether we fell back to GET (for data threshold enforcement).
        let (response, used_get_fallback) = match head_result {
            Ok(resp) if resp.status().as_u16() == 405 => {
                // Server doesn't support HEAD — fall back to GET.
                debug!(url, "HEAD returned 405, falling back to GET");
                (client.get(url).send().await, true)
            }
            other => (other, false),
        };

        let elapsed_ms = attempt_start.elapsed().as_millis() as u64;

        match response {
            Ok(resp) => {
                let status = resp.status().as_u16();
                let content_type = resp
                    .headers()
                    .get(reqwest::header::CONTENT_TYPE)
                    .and_then(|v| v.to_str().ok())
                    .map(String::from);
                let content_length = resp
                    .headers()
                    .get(reqwest::header::CONTENT_LENGTH)
                    .and_then(|v| v.to_str().ok())
                    .and_then(|v| v.parse::<u64>().ok());

                let category = categorize_status(status);

                match category {
                    StreamCategory::Retry => {
                        last_error_reason = Some(format!("HTTP {status}"));
                        debug!(
                            url,
                            status,
                            attempt = attempt + 1,
                            max_attempts = total_attempts,
                            "retryable HTTP status, will retry"
                        );
                        if attempt + 1 < total_attempts {
                            let delay = opts.backoff.delay(attempt);
                            if !delay.is_zero() {
                                tokio::time::sleep(delay).await;
                            }
                        }
                        continue;
                    }
                    StreamCategory::Geoblocked => {
                        return CheckResult {
                            url: url.to_string(),
                            info: StreamInfo {
                                available: false,
                                status_code: Some(status),
                                response_time_ms: elapsed_ms,
                                content_type,
                                content_length,
                                error: Some(format!("HTTP {status}")),
                            },
                            checked_at,
                            media_info: None,
                            category: StreamCategory::Geoblocked,
                            error_reason: None,
                            mismatch_warnings: Vec::new(),
                        };
                    }
                    StreamCategory::Dead => {
                        return CheckResult {
                            url: url.to_string(),
                            info: StreamInfo {
                                available: false,
                                status_code: Some(status),
                                response_time_ms: elapsed_ms,
                                content_type,
                                content_length,
                                error: Some(format!("HTTP {status}")),
                            },
                            checked_at,
                            media_info: None,
                            category: StreamCategory::Dead,
                            error_reason: Some(format!("HTTP {status}")),
                            mismatch_warnings: Vec::new(),
                        };
                    }
                    StreamCategory::Alive => {
                        // Enforce data threshold on GET fallback responses.
                        // Translated from IPTVChecker-Python verify() which checks
                        // bytes_read >= min_data_threshold on direct stream reads.
                        // When HEAD returned 405 and we fell back to GET,
                        // content_length is reliable — check against threshold.
                        if used_get_fallback
                            && let Some(len) = content_length
                            && !meets_data_threshold(len, opts.min_bytes_direct)
                        {
                            return CheckResult {
                                url: url.to_string(),
                                info: StreamInfo {
                                    available: false,
                                    status_code: Some(status),
                                    response_time_ms: elapsed_ms,
                                    content_type,
                                    content_length: Some(len),
                                    error: Some("Insufficient data".to_string()),
                                },
                                checked_at,
                                media_info: None,
                                category: StreamCategory::Dead,
                                error_reason: Some("Insufficient data".to_string()),
                                mismatch_warnings: Vec::new(),
                            };
                        }

                        // Run media probe if enabled.
                        let (media_info, mismatch_warnings) =
                            run_media_probe_if_enabled(url, name, opts).await;

                        return CheckResult {
                            url: url.to_string(),
                            info: StreamInfo {
                                available: true,
                                status_code: Some(status),
                                response_time_ms: elapsed_ms,
                                content_type,
                                content_length,
                                error: None,
                            },
                            checked_at,
                            media_info,
                            category: StreamCategory::Alive,
                            error_reason: None,
                            mismatch_warnings,
                        };
                    }
                }
            }
            Err(e) => {
                let error_summary = summarize_error(&e);
                warn!(url, error = %e, "stream check failed");

                // Connection errors and timeouts are retryable.
                if e.is_timeout() || e.is_connect() {
                    last_error_reason = Some(error_summary);
                    if attempt + 1 < total_attempts {
                        let delay = opts.backoff.delay(attempt);
                        if !delay.is_zero() {
                            tokio::time::sleep(delay).await;
                        }
                    }
                    continue;
                }

                // Non-retryable error.
                return CheckResult {
                    url: url.to_string(),
                    info: StreamInfo {
                        available: false,
                        status_code: None,
                        response_time_ms: elapsed_ms,
                        content_type: None,
                        content_length: None,
                        error: Some(error_summary.clone()),
                    },
                    checked_at,
                    media_info: None,
                    category: StreamCategory::Dead,
                    error_reason: Some(error_summary),
                    mismatch_warnings: Vec::new(),
                };
            }
        }
    }

    // All retries exhausted.
    let elapsed_ms = start.elapsed().as_millis() as u64;
    CheckResult {
        url: url.to_string(),
        info: StreamInfo {
            available: false,
            status_code: None,
            response_time_ms: elapsed_ms,
            content_type: None,
            content_length: None,
            error: last_error_reason.clone(),
        },
        checked_at,
        media_info: None,
        category: StreamCategory::Dead,
        error_reason: last_error_reason,
        mismatch_warnings: Vec::new(),
    }
}

/// Run media probe and label mismatch checks if enabled.
///
/// On probe failure, logs a warning and returns `(None, Vec::new())` — probe
/// failure does not change stream category. This matches the Python source's
/// behavior where ffprobe errors are logged but the stream stays Alive.
async fn run_media_probe_if_enabled(
    url: &str,
    name: Option<&str>,
    opts: &CheckOptions,
) -> (Option<crispy_media_probe::MediaInfo>, Vec<String>) {
    if opts.skip_media_probe {
        return (None, Vec::new());
    }

    let timeout_secs = (opts.timeout_ms / 1_000).max(5);
    match crispy_media_probe::probe_stream(url, timeout_secs).await {
        Ok(media_info) => {
            // Run label mismatch check if channel name is provided and
            // we have video resolution data.
            let mismatch_warnings = match (name, &media_info.video) {
                (Some(channel_name), Some(video)) => {
                    crispy_media_probe::check_label_mismatch(channel_name, &video.resolution)
                }
                _ => Vec::new(),
            };
            (Some(media_info), mismatch_warnings)
        }
        Err(e) => {
            warn!(url, error = %e, "media probe failed, keeping stream as Alive");
            (None, Vec::new())
        }
    }
}

/// Check multiple streams concurrently with bounded concurrency.
///
/// Uses a [`Semaphore`] to limit the number of simultaneous connections
/// to `opts.max_concurrent`. Results are collected as they complete.
pub async fn check_bulk(urls: &[String], opts: &CheckOptions) -> BulkCheckReport {
    check_bulk_with_progress(urls, opts, |_, _, _| {}).await
}

/// Check multiple streams with a progress callback.
///
/// The callback receives `(completed_count, total_count, &latest_result)`
/// after each stream check completes. Useful for UI progress indicators.
///
/// Results are split into alive/dead/geoblocked lists, translated from
/// IPTVChecker-Python's split output feature.
pub async fn check_bulk_with_progress(
    urls: &[String],
    opts: &CheckOptions,
    on_progress: impl Fn(usize, usize, &CheckResult) + Send + Sync,
) -> BulkCheckReport {
    let wall_start = Instant::now();
    let total = urls.len();

    if total == 0 {
        return BulkCheckReport {
            total: 0,
            available: 0,
            unavailable: 0,
            errors: 0,
            geoblocked: 0,
            results: Vec::new(),
            duration_ms: 0,
            alive_results: Vec::new(),
            dead_results: Vec::new(),
            geoblocked_results: Vec::new(),
        };
    }

    let semaphore = Arc::new(Semaphore::new(opts.max_concurrent));
    let opts = opts.clone();

    // Spawn all tasks, each acquiring a semaphore permit.
    let mut handles = Vec::with_capacity(total);
    for url in urls {
        let sem = Arc::clone(&semaphore);
        let url = url.clone();
        let task_opts = opts.clone();

        let handle = tokio::spawn(async move {
            let _permit = sem.acquire().await.expect("semaphore closed unexpectedly");
            check_stream(&url, &task_opts).await
        });
        handles.push(handle);
    }

    // Collect results in order, invoking progress callback.
    let mut results = Vec::with_capacity(total);
    let mut available = 0usize;
    let mut unavailable = 0usize;
    let mut errors = 0usize;
    let mut geoblocked_count = 0usize;
    let mut alive_results = Vec::new();
    let mut dead_results = Vec::new();
    let mut geoblocked_results = Vec::new();

    for (i, handle) in handles.into_iter().enumerate() {
        let result = handle.await.expect("stream check task panicked");

        match result.category {
            StreamCategory::Geoblocked => {
                geoblocked_count += 1;
                geoblocked_results.push(result.clone());
            }
            StreamCategory::Alive => {
                available += 1;
                alive_results.push(result.clone());
            }
            StreamCategory::Dead | StreamCategory::Retry => {
                if result.info.error.is_some() && result.info.status_code.is_none() {
                    errors += 1;
                } else {
                    unavailable += 1;
                }
                dead_results.push(result.clone());
            }
        }

        on_progress(i + 1, total, &result);
        results.push(result);
    }

    BulkCheckReport {
        total,
        available,
        unavailable,
        errors,
        geoblocked: geoblocked_count,
        results,
        duration_ms: wall_start.elapsed().as_millis() as u64,
        alive_results,
        dead_results,
        geoblocked_results,
    }
}
