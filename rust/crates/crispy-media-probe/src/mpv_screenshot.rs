//! Screenshot capture via libmpv.
//!
//! Uses the mpv client API loaded at runtime to capture a video frame
//! as a screenshot. This is an alternative to the ffmpeg-based capture
//! in `screenshot.rs`.

use std::time::{Duration, Instant};

use tracing::{debug, warn};

use crate::error::ProbeError;
use crate::mpv_ffi::{MpvEventId, MpvHandle};

/// Capture a screenshot from a stream URL using libmpv.
///
/// Opens the URL in a headless mpv instance, optionally seeks to a
/// position, then captures a frame to the output path.
///
/// # Arguments
/// * `url` - The stream URL to capture from.
/// * `output_path` - Where to save the screenshot (e.g. `/tmp/shot.png`).
///   The format is inferred from the extension by mpv.
/// * `seek_secs` - Optional position to seek to before capturing. If `None`,
///   captures the first decoded frame.
/// * `timeout_secs` - Maximum time to wait for the capture to complete.
///
/// # Errors
/// Returns [`ProbeError::MpvUnavailable`] if libmpv cannot be loaded,
/// [`ProbeError::Timeout`] if capture doesn't complete in time, or
/// [`ProbeError::MpvCommandFailed`] if any mpv command fails.
pub async fn capture_screenshot_mpv(
    url: &str,
    output_path: &str,
    seek_secs: Option<f64>,
    timeout_secs: u64,
) -> Result<(), ProbeError> {
    let url = url.to_string();
    let output_path = output_path.to_string();

    tokio::task::spawn_blocking(move || {
        capture_screenshot_mpv_blocking(&url, &output_path, seek_secs, timeout_secs)
    })
    .await
    .map_err(|e| ProbeError::MpvCommandFailed {
        command: "spawn_blocking".to_string(),
        detail: e.to_string(),
    })?
}

/// Blocking implementation of mpv-based screenshot capture.
fn capture_screenshot_mpv_blocking(
    url: &str,
    output_path: &str,
    seek_secs: Option<f64>,
    timeout_secs: u64,
) -> Result<(), ProbeError> {
    debug!(
        url,
        output_path,
        ?seek_secs,
        "capturing screenshot via libmpv"
    );

    let handle = MpvHandle::new_for_screenshot()?;

    // Load the file.
    handle.command(&["loadfile", url])?;

    // Wait for the file to be loaded.
    let deadline = Instant::now() + Duration::from_secs(timeout_secs);
    wait_for_file_loaded(&handle, url, &deadline)?;

    // Optionally seek to a position.
    if let Some(secs) = seek_secs {
        let seek_str = format!("{secs:.1}");
        handle.command(&["seek", &seek_str, "absolute"])?;

        // Brief wait for seek to complete.
        std::thread::sleep(Duration::from_millis(500));
    }

    // Unpause briefly to decode a frame.
    handle.command(&["set", "pause", "no"])?;
    std::thread::sleep(Duration::from_millis(200));
    handle.command(&["set", "pause", "yes"])?;

    // Capture the screenshot.
    handle.command(&["screenshot-to-file", output_path, "video"])?;

    debug!(output_path, "mpv screenshot saved");
    Ok(())
}

/// Wait for the `FileLoaded` event or an error.
fn wait_for_file_loaded(
    handle: &MpvHandle,
    url: &str,
    deadline: &Instant,
) -> Result<(), ProbeError> {
    loop {
        let remaining = deadline
            .checked_duration_since(Instant::now())
            .unwrap_or(Duration::ZERO);

        if remaining.is_zero() {
            return Err(ProbeError::Timeout {
                url: url.to_string(),
                timeout_secs: 0, // already past deadline
            });
        }

        let wait_secs = remaining.as_secs_f64().min(1.0);
        let (event_id, error) = handle.wait_event(wait_secs);

        match event_id {
            MpvEventId::FileLoaded => {
                debug!(url, "mpv: file loaded for screenshot");
                return Ok(());
            }
            MpvEventId::EndFile => {
                if error != 0 {
                    return Err(ProbeError::MpvCommandFailed {
                        command: format!("loadfile {url}"),
                        detail: format!("end-file with error code {error}"),
                    });
                }
                warn!(url, "mpv: end-file without file-loaded during screenshot");
                return Err(ProbeError::NoStreams(url.to_string()));
            }
            MpvEventId::Shutdown => {
                return Err(ProbeError::MpvCommandFailed {
                    command: format!("loadfile {url}"),
                    detail: "mpv shutdown during load".to_string(),
                });
            }
            _ => {
                // Continue waiting.
            }
        }
    }
}

/// Check whether libmpv-based screenshot capture is available.
pub fn is_mpv_screenshot_available() -> bool {
    crate::mpv_ffi::is_mpv_available()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn is_mpv_screenshot_available_does_not_panic() {
        let _available = is_mpv_screenshot_available();
    }

    #[tokio::test]
    async fn capture_screenshot_mpv_returns_error_when_no_libmpv() {
        let result =
            capture_screenshot_mpv("http://invalid.test/stream", "/tmp/test.png", None, 2).await;
        match result {
            Ok(_) => {}
            Err(ProbeError::MpvUnavailable(_)) => {}
            Err(ProbeError::Timeout { .. }) => {}
            Err(ProbeError::MpvCommandFailed { .. }) => {}
            Err(ProbeError::MpvInitFailed(_)) => {}
            Err(ProbeError::NoStreams(_)) => {}
            Err(other) => panic!("unexpected error variant: {other:?}"),
        }
    }
}
