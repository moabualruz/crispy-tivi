//! Stream probing via libmpv.
//!
//! Uses the mpv client API loaded at runtime to probe media streams.
//! This is an alternative to the ffprobe-based probing in `probe.rs`,
//! useful when mpv is bundled (e.g. via media_kit) but ffprobe is not
//! installed.

use std::time::{Duration, Instant};

use tracing::{debug, warn};

use crate::error::ProbeError;
use crate::mpv_ffi::{MpvEventId, MpvHandle};
use crate::types::{AudioInfo, MediaInfo, VideoInfo, classify_resolution};

/// Probe a media stream URL using libmpv and return full [`MediaInfo`].
///
/// Creates a headless mpv instance, loads the URL, waits for metadata to
/// become available, then reads video/audio properties.
///
/// # Arguments
/// * `url` - The stream URL to probe.
/// * `timeout_secs` - Maximum time to wait for metadata.
///
/// # Errors
/// Returns [`ProbeError::MpvUnavailable`] if libmpv cannot be loaded,
/// [`ProbeError::Timeout`] if metadata is not available within the timeout,
/// or [`ProbeError::MpvCommandFailed`] if the loadfile command fails.
pub async fn probe_stream_mpv(url: &str, timeout_secs: u64) -> Result<MediaInfo, ProbeError> {
    let url = url.to_string();
    tokio::task::spawn_blocking(move || probe_stream_mpv_blocking(&url, timeout_secs))
        .await
        .map_err(|e| ProbeError::MpvCommandFailed {
            command: "spawn_blocking".to_string(),
            detail: e.to_string(),
        })?
}

/// Blocking implementation of mpv-based stream probing.
fn probe_stream_mpv_blocking(url: &str, timeout_secs: u64) -> Result<MediaInfo, ProbeError> {
    debug!(url, "probing stream via libmpv");

    let handle = MpvHandle::new_for_probing()?;

    // Load the file.
    handle.command(&["loadfile", url])?;

    // Wait for FileLoaded or EndFile event.
    let deadline = Instant::now() + Duration::from_secs(timeout_secs);
    let mut file_loaded = false;

    loop {
        let remaining = deadline
            .checked_duration_since(Instant::now())
            .unwrap_or(Duration::ZERO);

        if remaining.is_zero() {
            return Err(ProbeError::Timeout {
                url: url.to_string(),
                timeout_secs,
            });
        }

        let wait_secs = remaining.as_secs_f64().min(1.0);
        let (event_id, error) = handle.wait_event(wait_secs);

        match event_id {
            MpvEventId::FileLoaded => {
                debug!(url, "mpv: file loaded");
                file_loaded = true;
                break;
            }
            MpvEventId::EndFile => {
                if error != 0 {
                    return Err(ProbeError::MpvCommandFailed {
                        command: format!("loadfile {url}"),
                        detail: format!("end-file with error code {error}"),
                    });
                }
                // End without error but also without load — stream is empty
                // or instantly finished. Try to read what we have.
                break;
            }
            MpvEventId::Shutdown => {
                return Err(ProbeError::MpvCommandFailed {
                    command: format!("loadfile {url}"),
                    detail: "mpv shutdown during load".to_string(),
                });
            }
            MpvEventId::None => {
                // Timeout on this wait_event call — loop will check deadline.
            }
            _ => {
                // Ignore other events.
            }
        }
    }

    if !file_loaded {
        warn!(
            url,
            "mpv: file not loaded, attempting to read properties anyway"
        );
    }

    // Read properties.
    let video = read_video_info(&handle);
    let audio = read_audio_info(&handle);
    let format_name = handle.get_property_string("file-format");
    let duration_secs = handle.get_property_double("duration").filter(|d| *d > 0.0);
    let overall_bitrate = handle
        .get_property_i64("file-size")
        .and_then(|size| {
            duration_secs.map(|dur| {
                if dur > 0.0 {
                    ((size as f64 * 8.0) / dur) as u64
                } else {
                    0
                }
            })
        })
        .filter(|b| *b > 0);

    let info = MediaInfo {
        video,
        audio,
        format_name,
        duration_secs,
        overall_bitrate,
    };

    debug!(url, ?info, "mpv probe complete");
    Ok(info)
}

/// Read video stream information from mpv properties.
fn read_video_info(handle: &MpvHandle) -> Option<VideoInfo> {
    let codec = handle.get_property_string("video-codec")?;

    // mpv returns the full codec description; extract the short name.
    // e.g. "h264 (High)" -> "h264"
    let codec_short = codec
        .split_whitespace()
        .next()
        .unwrap_or(&codec)
        .to_string();

    let width = handle.get_property_i64("width").unwrap_or(0) as u32;
    let height = handle.get_property_i64("height").unwrap_or(0) as u32;

    // Container FPS (preferred) or estimated FPS.
    let fps = handle
        .get_property_double("container-fps")
        .or_else(|| handle.get_property_double("estimated-vf-fps"))
        .unwrap_or(0.0);

    let bitrate = handle
        .get_property_i64("video-bitrate")
        .filter(|b| *b > 0)
        .map(|b| b as u64);

    let resolution = classify_resolution(width, height);

    Some(VideoInfo {
        codec: codec_short,
        width,
        height,
        fps,
        bitrate,
        resolution,
    })
}

/// Read audio stream information from mpv properties.
fn read_audio_info(handle: &MpvHandle) -> Option<AudioInfo> {
    let codec = handle.get_property_string("audio-codec")?;

    let codec_short = codec
        .split_whitespace()
        .next()
        .unwrap_or(&codec)
        .to_string();

    let bitrate = handle
        .get_property_i64("audio-bitrate")
        .filter(|b| *b > 0)
        .map(|b| b as u64);

    let channels = handle
        .get_property_i64("audio-params/channel-count")
        .filter(|c| *c > 0)
        .map(|c| c as u32);

    let sample_rate = handle
        .get_property_i64("audio-params/samplerate")
        .filter(|r| *r > 0)
        .map(|r| r as u32);

    Some(AudioInfo {
        codec: codec_short,
        bitrate,
        channels,
        sample_rate,
    })
}

/// Check whether libmpv-based probing is available.
///
/// Returns `true` if the libmpv library can be loaded and initialized.
pub fn is_mpv_probe_available() -> bool {
    crate::mpv_ffi::is_mpv_available()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn is_mpv_probe_available_does_not_panic() {
        let _available = is_mpv_probe_available();
    }

    #[tokio::test]
    async fn probe_stream_mpv_returns_error_when_no_libmpv() {
        // If libmpv is not installed, this should return MpvUnavailable.
        // If it IS installed, it will fail with Timeout or similar — both are OK.
        let result = probe_stream_mpv("http://invalid.test/stream", 2).await;
        // We just verify it doesn't panic.
        match result {
            Ok(_) => {}                                    // unlikely but acceptable
            Err(ProbeError::MpvUnavailable(_)) => {}       // expected on CI
            Err(ProbeError::Timeout { .. }) => {}          // mpv loaded but URL failed
            Err(ProbeError::MpvCommandFailed { .. }) => {} // mpv loaded but URL failed
            Err(ProbeError::MpvInitFailed(_)) => {}        // mpv loaded but init failed
            Err(other) => panic!("unexpected error variant: {other:?}"),
        }
    }
}
