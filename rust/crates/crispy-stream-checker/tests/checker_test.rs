//! Integration tests for stream checker using wiremock.

use std::sync::Arc;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Duration;

use crispy_stream_checker::{
    CheckOptions, check_bulk, check_bulk_with_progress, check_stream, check_stream_named,
};
use wiremock::matchers::{method, path};
use wiremock::{Mock, MockServer, ResponseTemplate};

fn opts_for(_server: &MockServer) -> CheckOptions {
    // Use short timeouts for tests with minimal retries.
    CheckOptions {
        timeout_ms: 3_000,
        max_concurrent: 10,
        follow_redirects: true,
        user_agent: Some("crispy-test/1.0".into()),
        accept_invalid_certs: false,
        retries: 1,
        ..Default::default()
    }
}

// 1. Available stream (200 OK with content-type)
#[tokio::test]
async fn check_available_stream_returns_success() {
    let server = MockServer::start().await;

    Mock::given(method("HEAD"))
        .and(path("/live/stream.m3u8"))
        .respond_with(
            ResponseTemplate::new(200)
                .insert_header("content-type", "application/vnd.apple.mpegurl")
                .insert_header("content-length", "4096"),
        )
        .mount(&server)
        .await;

    let url = format!("{}/live/stream.m3u8", server.uri());
    let opts = opts_for(&server);
    let result = check_stream(&url, &opts).await;

    assert!(result.info.available);
    assert_eq!(result.info.status_code, Some(200));
    assert_eq!(
        result.info.content_type.as_deref(),
        Some("application/vnd.apple.mpegurl")
    );
    assert_eq!(result.info.content_length, Some(4096));
    assert!(result.info.error.is_none());
    assert_eq!(result.url, url);
}

// 2. Unavailable stream (404)
#[tokio::test]
async fn check_unavailable_stream_returns_not_found() {
    let server = MockServer::start().await;

    Mock::given(method("HEAD"))
        .and(path("/missing"))
        .respond_with(ResponseTemplate::new(404))
        .mount(&server)
        .await;

    let url = format!("{}/missing", server.uri());
    let result = check_stream(&url, &opts_for(&server)).await;

    assert!(!result.info.available);
    assert_eq!(result.info.status_code, Some(404));
    assert!(result.info.error.is_some());
    assert!(result.info.error.as_ref().unwrap().contains("404"));
}

// 3. Timeout (mock slow response)
#[tokio::test]
async fn check_timeout_returns_error() {
    let server = MockServer::start().await;

    Mock::given(method("HEAD"))
        .and(path("/slow"))
        .respond_with(
            ResponseTemplate::new(200)
                .set_body_bytes(vec![0; 10])
                .set_delay(Duration::from_secs(10)),
        )
        .mount(&server)
        .await;

    let url = format!("{}/slow", server.uri());
    let opts = CheckOptions {
        timeout_ms: 500,
        ..opts_for(&server)
    };
    let result = check_stream(&url, &opts).await;

    assert!(!result.info.available);
    assert!(result.info.error.is_some());
    let err = result.info.error.unwrap();
    assert!(
        err.contains("timed out") || err.contains("timeout"),
        "unexpected error: {err}"
    );
}

// 4. Redirect (301 -> 200)
#[tokio::test]
async fn check_redirect_follows_to_final_destination() {
    let server = MockServer::start().await;

    // Redirect target
    Mock::given(method("HEAD"))
        .and(path("/final"))
        .respond_with(ResponseTemplate::new(200).insert_header("content-type", "video/mp2t"))
        .mount(&server)
        .await;

    // Redirect source
    Mock::given(method("HEAD"))
        .and(path("/redirect"))
        .respond_with(
            ResponseTemplate::new(301).insert_header("location", format!("{}/final", server.uri())),
        )
        .mount(&server)
        .await;

    let url = format!("{}/redirect", server.uri());
    let result = check_stream(&url, &opts_for(&server)).await;

    assert!(result.info.available);
    assert_eq!(result.info.status_code, Some(200));
    assert_eq!(result.info.content_type.as_deref(), Some("video/mp2t"));
}

// 5. Bulk check — mixed results
#[tokio::test]
async fn bulk_check_reports_mixed_availability() {
    let server = MockServer::start().await;

    for i in 0..3 {
        Mock::given(method("HEAD"))
            .and(path(format!("/ok/{i}")))
            .respond_with(ResponseTemplate::new(200))
            .mount(&server)
            .await;
    }
    for i in 0..2 {
        Mock::given(method("HEAD"))
            .and(path(format!("/fail/{i}")))
            .respond_with(ResponseTemplate::new(404))
            .mount(&server)
            .await;
    }

    let urls: Vec<String> = (0..3)
        .map(|i| format!("{}/ok/{i}", server.uri()))
        .chain((0..2).map(|i| format!("{}/fail/{i}", server.uri())))
        .collect();

    let report = check_bulk(&urls, &opts_for(&server)).await;

    assert_eq!(report.total, 5);
    assert_eq!(report.available, 3);
    assert_eq!(report.unavailable, 2);
    assert_eq!(report.errors, 0);
    assert_eq!(report.results.len(), 5);
    assert!(report.duration_ms > 0 || report.total == 0);
}

// 6. Bounded concurrency — verify semaphore limits
#[tokio::test]
async fn bulk_check_respects_concurrency_limit() {
    let server = MockServer::start().await;

    // Each request takes 200ms — with concurrency=2 and 4 URLs,
    // it should take at least 400ms (2 batches).
    for i in 0..4 {
        Mock::given(method("HEAD"))
            .and(path(format!("/conc/{i}")))
            .respond_with(ResponseTemplate::new(200).set_delay(Duration::from_millis(200)))
            .mount(&server)
            .await;
    }

    let urls: Vec<String> = (0..4)
        .map(|i| format!("{}/conc/{i}", server.uri()))
        .collect();

    let opts = CheckOptions {
        max_concurrent: 2,
        timeout_ms: 5_000,
        ..opts_for(&server)
    };

    let start = std::time::Instant::now();
    let report = check_bulk(&urls, &opts).await;
    let elapsed = start.elapsed();

    assert_eq!(report.total, 4);
    assert_eq!(report.available, 4);
    // With concurrency=2 and 4 URLs each taking 200ms,
    // minimum time is 2 batches * 200ms = 400ms.
    assert!(
        elapsed >= Duration::from_millis(350),
        "expected >= 350ms with concurrency=2, got {}ms",
        elapsed.as_millis()
    );
}

// 7. Progress callback — verify called for each URL
#[tokio::test]
async fn progress_callback_called_for_each_url() {
    let server = MockServer::start().await;

    for i in 0..3 {
        Mock::given(method("HEAD"))
            .and(path(format!("/prog/{i}")))
            .respond_with(ResponseTemplate::new(200))
            .mount(&server)
            .await;
    }

    let urls: Vec<String> = (0..3)
        .map(|i| format!("{}/prog/{i}", server.uri()))
        .collect();

    let call_count = Arc::new(AtomicUsize::new(0));
    let count_clone = Arc::clone(&call_count);

    let report =
        check_bulk_with_progress(&urls, &opts_for(&server), move |done, total, _result| {
            count_clone.fetch_add(1, Ordering::Relaxed);
            assert_eq!(total, 3);
            assert!(done >= 1 && done <= 3);
        })
        .await;

    assert_eq!(call_count.load(Ordering::Relaxed), 3);
    assert_eq!(report.total, 3);
}

// 8. Connection refused — graceful error
#[tokio::test]
async fn check_connection_refused_returns_error() {
    // Use a port that's almost certainly not listening.
    let url = "http://127.0.0.1:19999/stream";
    let opts = CheckOptions {
        timeout_ms: 2_000,
        ..Default::default()
    };
    let result = check_stream(url, &opts).await;

    assert!(!result.info.available);
    assert!(result.info.status_code.is_none());
    assert!(result.info.error.is_some());
}

// 9. Invalid URL — graceful error
#[tokio::test]
async fn check_invalid_url_returns_error() {
    let opts = CheckOptions::default();

    let result = check_stream("not-a-url", &opts).await;
    assert!(!result.info.available);
    assert!(result.info.error.is_some());
    assert!(result.info.error.as_ref().unwrap().contains("invalid URL"));

    let result_empty = check_stream("", &opts).await;
    assert!(!result_empty.info.available);
    assert!(result_empty.info.error.is_some());
}

// 10. Response time is positive
#[tokio::test]
async fn check_measures_response_time() {
    let server = MockServer::start().await;

    Mock::given(method("HEAD"))
        .and(path("/timed"))
        .respond_with(ResponseTemplate::new(200).set_delay(Duration::from_millis(50)))
        .mount(&server)
        .await;

    let url = format!("{}/timed", server.uri());
    let result = check_stream(&url, &opts_for(&server)).await;

    assert!(result.info.available);
    assert!(
        result.info.response_time_ms >= 30,
        "expected >= 30ms, got {}ms",
        result.info.response_time_ms
    );
}

// HEAD 405 fallback to GET
#[tokio::test]
async fn check_falls_back_to_get_on_head_405() {
    let server = MockServer::start().await;

    Mock::given(method("HEAD"))
        .and(path("/head-denied"))
        .respond_with(ResponseTemplate::new(405))
        .mount(&server)
        .await;

    // Provide a body large enough to pass the min_bytes_direct threshold,
    // since GET fallback now enforces data threshold checks.
    let body = vec![0u8; 600_000];
    Mock::given(method("GET"))
        .and(path("/head-denied"))
        .respond_with(
            ResponseTemplate::new(200)
                .insert_header("content-type", "video/mp4")
                .set_body_bytes(body),
        )
        .mount(&server)
        .await;

    let url = format!("{}/head-denied", server.uri());
    let opts = CheckOptions {
        skip_media_probe: true,
        ..opts_for(&server)
    };
    let result = check_stream(&url, &opts).await;

    assert!(result.info.available);
    assert_eq!(result.info.status_code, Some(200));
    assert_eq!(result.info.content_type.as_deref(), Some("video/mp4"));
}

// Empty URL list returns empty report
#[tokio::test]
async fn bulk_check_empty_list_returns_zero_report() {
    let report = check_bulk(&[], &CheckOptions::default()).await;

    assert_eq!(report.total, 0);
    assert_eq!(report.available, 0);
    assert_eq!(report.unavailable, 0);
    assert_eq!(report.errors, 0);
    assert!(report.results.is_empty());
    assert_eq!(report.duration_ms, 0);
}

// ── Gap 1: Media probe wiring ──────────────────────────────────────

// When skip_media_probe=false and the stream is alive, the checker attempts
// to run ffprobe. In CI/test environments ffprobe is typically unavailable,
// so probe_stream returns an error. The checker should handle this gracefully:
// keep the stream as Alive with media_info=None.
#[tokio::test]
async fn alive_stream_with_probe_enabled_handles_probe_failure_gracefully() {
    let server = MockServer::start().await;

    Mock::given(method("HEAD"))
        .and(path("/probe-test"))
        .respond_with(
            ResponseTemplate::new(200)
                .insert_header("content-type", "video/mp2t")
                .insert_header("content-length", "1000000"),
        )
        .mount(&server)
        .await;

    let url = format!("{}/probe-test", server.uri());
    let opts = CheckOptions {
        skip_media_probe: false,
        ..opts_for(&server)
    };
    let result = check_stream(&url, &opts).await;

    // Stream is still Alive even though probe will fail (no ffprobe in test env).
    assert!(result.info.available);
    assert_eq!(
        result.category,
        crispy_stream_checker::StreamCategory::Alive
    );
    // media_info is None because ffprobe is not available in test.
    assert!(result.media_info.is_none());
}

// When skip_media_probe=true, media_info must be None regardless.
#[tokio::test]
async fn alive_stream_with_skip_media_probe_has_no_media_info() {
    let server = MockServer::start().await;

    Mock::given(method("HEAD"))
        .and(path("/no-probe"))
        .respond_with(ResponseTemplate::new(200).insert_header("content-type", "video/mp2t"))
        .mount(&server)
        .await;

    let url = format!("{}/no-probe", server.uri());
    let opts = CheckOptions {
        skip_media_probe: true,
        ..opts_for(&server)
    };
    let result = check_stream(&url, &opts).await;

    assert!(result.info.available);
    assert!(result.media_info.is_none());
    assert!(result.mismatch_warnings.is_empty());
}

// ── Gap 2: GET data threshold enforcement ───────────────────────────

// When HEAD returns 405 and GET fallback is used, content_length below
// min_bytes_direct should mark the stream as Dead with "Insufficient data".
#[tokio::test]
async fn get_fallback_below_threshold_marks_dead() {
    let server = MockServer::start().await;

    Mock::given(method("HEAD"))
        .and(path("/small-stream"))
        .respond_with(ResponseTemplate::new(405))
        .mount(&server)
        .await;

    // Wiremock overrides content-length to match the actual body size,
    // so we provide a small body (100 bytes) that's well below the 500 KB threshold.
    let small_body = vec![0u8; 100];
    Mock::given(method("GET"))
        .and(path("/small-stream"))
        .respond_with(
            ResponseTemplate::new(200)
                .insert_header("content-type", "video/mp2t")
                .set_body_bytes(small_body),
        )
        .mount(&server)
        .await;

    let url = format!("{}/small-stream", server.uri());
    let opts = CheckOptions {
        skip_media_probe: true,
        ..opts_for(&server)
    };
    let result = check_stream(&url, &opts).await;

    assert!(!result.info.available);
    assert_eq!(result.category, crispy_stream_checker::StreamCategory::Dead);
    assert_eq!(result.error_reason.as_deref(), Some("Insufficient data"),);
    assert_eq!(result.info.content_length, Some(100));
}

// When HEAD returns 405 and GET fallback has sufficient content_length,
// the stream should be Alive.
#[tokio::test]
async fn get_fallback_above_threshold_marks_alive() {
    let server = MockServer::start().await;

    Mock::given(method("HEAD"))
        .and(path("/big-stream"))
        .respond_with(ResponseTemplate::new(405))
        .mount(&server)
        .await;

    // Provide a body larger than min_bytes_direct (default 512000 = 500 KB).
    let big_body = vec![0u8; 600_000];
    Mock::given(method("GET"))
        .and(path("/big-stream"))
        .respond_with(
            ResponseTemplate::new(200)
                .insert_header("content-type", "video/mp2t")
                .set_body_bytes(big_body),
        )
        .mount(&server)
        .await;

    let url = format!("{}/big-stream", server.uri());
    let opts = CheckOptions {
        skip_media_probe: true,
        ..opts_for(&server)
    };
    let result = check_stream(&url, &opts).await;

    assert!(result.info.available);
    assert_eq!(
        result.category,
        crispy_stream_checker::StreamCategory::Alive
    );
}

// ── Gap 3: Label mismatch via check_stream_named ────────────────────

// Verify check_stream_named passes the channel name through for mismatch
// detection. Since ffprobe is unavailable in test, probe will fail and
// mismatch_warnings will be empty — but the wiring is tested by ensuring
// the function accepts name and returns a valid result.
#[tokio::test]
async fn check_stream_named_with_name_runs_without_error() {
    let server = MockServer::start().await;

    Mock::given(method("HEAD"))
        .and(path("/named-stream"))
        .respond_with(ResponseTemplate::new(200).insert_header("content-type", "video/mp2t"))
        .mount(&server)
        .await;

    let url = format!("{}/named-stream", server.uri());
    let opts = CheckOptions {
        skip_media_probe: false,
        ..opts_for(&server)
    };
    let result = check_stream_named(&url, Some("Sports 4K Channel"), &opts).await;

    assert!(result.info.available);
    assert_eq!(
        result.category,
        crispy_stream_checker::StreamCategory::Alive
    );
    // Probe fails (no ffprobe) so no mismatch warnings, but the code path
    // exercised the name parameter without errors.
    assert!(result.mismatch_warnings.is_empty());
}

// Verify check_stream_named with None name is equivalent to check_stream.
#[tokio::test]
async fn check_stream_named_without_name_matches_check_stream() {
    let server = MockServer::start().await;

    Mock::given(method("HEAD"))
        .and(path("/unnamed"))
        .respond_with(ResponseTemplate::new(200))
        .mount(&server)
        .await;

    let url = format!("{}/unnamed", server.uri());
    let opts = CheckOptions {
        skip_media_probe: true,
        ..opts_for(&server)
    };

    let result_named = check_stream_named(&url, None, &opts).await;
    let result_plain = check_stream(&url, &opts).await;

    assert_eq!(result_named.info.available, result_plain.info.available);
    assert_eq!(result_named.category, result_plain.category);
    assert_eq!(
        result_named.media_info.is_none(),
        result_plain.media_info.is_none()
    );
}
