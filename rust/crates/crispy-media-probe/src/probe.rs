//! ffprobe invocation and JSON parsing.
//!
//! Translated from:
//! - IPTVChecker-Python `get_detailed_stream_info()` — picks highest-res video stream
//! - iptv-checker-module `checkItem()` — ffprobe command construction with `-of json`
//! - iptvtools `probe()` / `check_stream()` — subprocess wrapper

use std::process::Stdio;
use std::time::Duration;

use serde::Deserialize;
use tokio::process::Command;
use tracing::{debug, warn};

use crate::error::ProbeError;
use crate::types::{AudioInfo, MediaInfo, VideoInfo, classify_resolution, parse_frame_rate};

/// Raw ffprobe JSON output structure.
#[derive(Debug, Deserialize)]
struct FfprobeOutput {
    streams: Option<Vec<FfprobeStream>>,
    format: Option<FfprobeFormat>,
}

/// A single stream entry from ffprobe JSON.
#[derive(Debug, Deserialize)]
struct FfprobeStream {
    codec_type: Option<String>,
    codec_name: Option<String>,
    width: Option<u32>,
    height: Option<u32>,
    r_frame_rate: Option<String>,
    bit_rate: Option<String>,
    channels: Option<u32>,
    sample_rate: Option<String>,
}

/// Format-level metadata from ffprobe JSON.
#[derive(Debug, Deserialize)]
struct FfprobeFormat {
    format_name: Option<String>,
    duration: Option<String>,
    bit_rate: Option<String>,
}

/// Options for stream probing.
///
/// Translated from iptv-checker-module `checkItem` which supports
/// per-item `http-user-agent` and `http-referrer` headers.
#[derive(Debug, Clone, Default)]
pub struct ProbeOptions {
    /// Custom User-Agent header for ffprobe HTTP requests.
    pub user_agent: Option<String>,
    /// Custom Referer header for ffprobe HTTP requests.
    pub referer: Option<String>,
}

/// Probe a media stream URL and return full [`MediaInfo`].
///
/// Runs ffprobe with `-show_format -show_streams -of json` and parses the
/// output. Selects the highest-resolution video stream when multiple exist
/// (translated from IPTVChecker-Python `get_detailed_stream_info`).
///
/// The `timeout_secs` parameter controls how long to wait for ffprobe.
pub async fn probe_stream(url: &str, timeout_secs: u64) -> Result<MediaInfo, ProbeError> {
    probe_stream_with_options(url, timeout_secs, &ProbeOptions::default()).await
}

/// Probe with custom HTTP headers (user-agent, referer).
///
/// Translated from iptv-checker-module `checkItem`:
/// ```js
/// if (referrer.length) { args.push('-headers', `'Referer: ${referrer}'`) }
/// if (userAgent) { args.push('-user_agent', `'${userAgent}'`) }
/// ```
pub async fn probe_stream_with_options(
    url: &str,
    timeout_secs: u64,
    opts: &ProbeOptions,
) -> Result<MediaInfo, ProbeError> {
    let mut args: Vec<&str> = vec![
        "-v",
        "error",
        "-hide_banner",
        "-analyzeduration",
        "15000000",
        "-probesize",
        "15000000",
        "-show_format",
        "-show_streams",
        "-of",
        "json",
    ];

    // Per iptv-checker-module: inject headers before the URL.
    let referer_header;
    if let Some(ref r) = opts.referer {
        referer_header = format!("Referer: {r}");
        args.push("-headers");
        args.push(&referer_header);
    }
    let ua_owned;
    if let Some(ref ua) = opts.user_agent {
        ua_owned = ua.clone();
        args.push("-user_agent");
        args.push(&ua_owned);
    }

    let output = run_ffprobe(&args, url, timeout_secs).await?;

    let probe: FfprobeOutput = serde_json::from_str(&output)?;
    let streams = probe.streams.unwrap_or_default();

    if streams.is_empty() {
        return Err(ProbeError::NoStreams(url.to_string()));
    }

    // Select the highest-resolution video stream (by pixel count).
    // Translated from IPTVChecker-Python: iterate streams, pick max width*height.
    let video = select_best_video_stream(&streams);
    let audio = select_audio_stream(&streams);

    let (format_name, duration_secs, overall_bitrate) = match &probe.format {
        Some(fmt) => (
            fmt.format_name.clone(),
            fmt.duration.as_deref().and_then(|d| d.parse::<f64>().ok()),
            fmt.bit_rate.as_deref().and_then(|b| b.parse::<u64>().ok()),
        ),
        None => (None, None, None),
    };

    Ok(MediaInfo {
        video,
        audio,
        format_name,
        duration_secs,
        overall_bitrate,
    })
}

/// Probe only audio stream information.
///
/// Translated from IPTVChecker-Python `get_audio_bitrate` — uses
/// `-select_streams a:0` to target the first audio stream.
pub async fn probe_audio(url: &str, timeout_secs: u64) -> Result<AudioInfo, ProbeError> {
    let output = run_ffprobe(
        &[
            "-v",
            "error",
            "-hide_banner",
            "-analyzeduration",
            "15000000",
            "-probesize",
            "15000000",
            "-select_streams",
            "a:0",
            "-show_entries",
            "stream=codec_name,bit_rate,channels,sample_rate",
            "-of",
            "json",
        ],
        url,
        timeout_secs,
    )
    .await?;

    let probe: FfprobeOutput = serde_json::from_str(&output)?;
    let streams = probe.streams.unwrap_or_default();

    select_audio_stream(&streams).ok_or_else(|| ProbeError::NoStreams(url.to_string()))
}

/// Select the video stream with the highest pixel count.
///
/// Translated from IPTVChecker-Python `get_detailed_stream_info`:
/// ```python
/// for stream in streams:
///     pixel_count = stream_width * stream_height
///     if pixel_count > selected_pixels:
///         selected_stream = stream
/// ```
fn select_best_video_stream(streams: &[FfprobeStream]) -> Option<VideoInfo> {
    let mut best: Option<(u64, &FfprobeStream)> = None;

    for stream in streams {
        let is_video = stream
            .codec_type
            .as_deref()
            .is_some_and(|t| t.eq_ignore_ascii_case("video"));
        if !is_video {
            continue;
        }

        let w = stream.width.unwrap_or(0);
        let h = stream.height.unwrap_or(0);
        let pixels = u64::from(w) * u64::from(h);

        match &best {
            Some((best_pixels, _)) if pixels <= *best_pixels => {}
            _ => best = Some((pixels, stream)),
        }
    }

    best.map(|(_, s)| {
        let codec = s
            .codec_name
            .clone()
            .unwrap_or_else(|| "unknown".to_string());
        let width = s.width.unwrap_or(0);
        let height = s.height.unwrap_or(0);
        let fps = s
            .r_frame_rate
            .as_deref()
            .and_then(parse_frame_rate)
            .unwrap_or(0.0);
        let bitrate = s.bit_rate.as_deref().and_then(|b| b.parse::<u64>().ok());
        let resolution = classify_resolution(width, height);

        VideoInfo {
            codec,
            width,
            height,
            fps,
            bitrate,
            resolution,
        }
    })
}

/// Select the first audio stream from ffprobe output.
///
/// Translated from IPTVChecker-Python `get_audio_bitrate`:
/// parses codec_name, bit_rate, channels, sample_rate.
fn select_audio_stream(streams: &[FfprobeStream]) -> Option<AudioInfo> {
    streams
        .iter()
        .find(|s| {
            s.codec_type
                .as_deref()
                .is_some_and(|t| t.eq_ignore_ascii_case("audio"))
        })
        .map(|s| {
            let codec = s
                .codec_name
                .clone()
                .unwrap_or_else(|| "unknown".to_string());
            let bitrate = s.bit_rate.as_deref().and_then(|b| b.parse::<u64>().ok());
            let channels = s.channels;
            let sample_rate = s.sample_rate.as_deref().and_then(|r| r.parse::<u32>().ok());

            AudioInfo {
                codec,
                bitrate,
                channels,
                sample_rate,
            }
        })
}

/// Run ffprobe with the given arguments and return stdout as a String.
///
/// Command construction translated from iptv-checker-module `checkItem`:
/// ```js
/// args = ['ffprobe', '-of json', '-v error', '-hide_banner',
///         '-show_format', '-show_streams']
/// ```
///
/// Timeout handling translated from iptv-checker-module:
/// ```js
/// return execAsync(args, { timeout })
/// ```
async fn run_ffprobe(args: &[&str], url: &str, timeout_secs: u64) -> Result<String, ProbeError> {
    let mut cmd = Command::new("ffprobe");
    cmd.args(args)
        .arg(url)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        // Prevent ffprobe from reading stdin (shell injection prevention,
        // translated from iptv-checker-module's single-quote wrapping).
        .stdin(Stdio::null());

    debug!(url, "running ffprobe");

    let child = cmd.spawn().map_err(|e| {
        if e.kind() == std::io::ErrorKind::NotFound {
            ProbeError::FfprobeNotFound
        } else {
            ProbeError::Io(e)
        }
    })?;

    let result = tokio::time::timeout(Duration::from_secs(timeout_secs), child.wait_with_output())
        .await
        .map_err(|_| ProbeError::Timeout {
            url: url.to_string(),
            timeout_secs,
        })?
        .map_err(ProbeError::Io)?;

    if !result.status.success() {
        let stderr = String::from_utf8_lossy(&result.stderr).to_string();
        warn!(url, stderr = %stderr, "ffprobe failed");
        return Err(ProbeError::ProcessFailed {
            code: result.status.code(),
            stderr,
        });
    }

    Ok(String::from_utf8_lossy(&result.stdout).to_string())
}

/// Check whether ffprobe is available in PATH.
///
/// Translated from IPTVChecker-Python `check_ffmpeg_availability`.
pub async fn is_ffprobe_available() -> bool {
    let result = Command::new("ffprobe")
        .arg("-version")
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .stdin(Stdio::null())
        .status()
        .await;

    matches!(result, Ok(status) if status.success())
}

/// Parse raw ffprobe JSON string into [`MediaInfo`].
///
/// Useful for testing with pre-recorded ffprobe output.
pub fn parse_ffprobe_json(json_str: &str) -> Result<MediaInfo, ProbeError> {
    let probe: FfprobeOutput = serde_json::from_str(json_str)?;
    let streams = probe.streams.unwrap_or_default();

    let video = select_best_video_stream(&streams);
    let audio = select_audio_stream(&streams);

    let (format_name, duration_secs, overall_bitrate) = match &probe.format {
        Some(fmt) => (
            fmt.format_name.clone(),
            fmt.duration.as_deref().and_then(|d| d.parse::<f64>().ok()),
            fmt.bit_rate.as_deref().and_then(|b| b.parse::<u64>().ok()),
        ),
        None => (None, None, None),
    };

    Ok(MediaInfo {
        video,
        audio,
        format_name,
        duration_secs,
        overall_bitrate,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crispy_iptv_types::Resolution;

    /// Sample ffprobe JSON for a typical IPTV stream with video + audio.
    const SAMPLE_VIDEO_AUDIO_JSON: &str = r#"{
        "streams": [
            {
                "codec_type": "video",
                "codec_name": "h264",
                "width": 1920,
                "height": 1080,
                "r_frame_rate": "30000/1001",
                "bit_rate": "4500000"
            },
            {
                "codec_type": "audio",
                "codec_name": "aac",
                "bit_rate": "128000",
                "channels": 2,
                "sample_rate": "44100"
            }
        ],
        "format": {
            "format_name": "mpegts",
            "duration": "3600.5",
            "bit_rate": "5000000"
        }
    }"#;

    /// Sample with multiple video streams at different resolutions.
    const MULTI_VIDEO_JSON: &str = r#"{
        "streams": [
            {
                "codec_type": "video",
                "codec_name": "h264",
                "width": 640,
                "height": 360,
                "r_frame_rate": "25/1"
            },
            {
                "codec_type": "video",
                "codec_name": "hevc",
                "width": 3840,
                "height": 2160,
                "r_frame_rate": "60/1",
                "bit_rate": "15000000"
            }
        ],
        "format": {
            "format_name": "hls"
        }
    }"#;

    /// Audio-only stream.
    const AUDIO_ONLY_JSON: &str = r#"{
        "streams": [
            {
                "codec_type": "audio",
                "codec_name": "mp3",
                "bit_rate": "192000",
                "channels": 2,
                "sample_rate": "48000"
            }
        ],
        "format": {
            "format_name": "mp3"
        }
    }"#;

    #[test]
    fn parses_video_audio_stream() {
        let info = parse_ffprobe_json(SAMPLE_VIDEO_AUDIO_JSON).unwrap();

        let video = info.video.unwrap();
        assert_eq!(video.codec, "h264");
        assert_eq!(video.width, 1920);
        assert_eq!(video.height, 1080);
        assert!((video.fps - 29.97).abs() < 0.01, "fps was {}", video.fps);
        assert_eq!(video.bitrate, Some(4_500_000));
        assert_eq!(video.resolution, Resolution::FHD);

        let audio = info.audio.unwrap();
        assert_eq!(audio.codec, "aac");
        assert_eq!(audio.bitrate, Some(128_000));
        assert_eq!(audio.channels, Some(2));
        assert_eq!(audio.sample_rate, Some(44_100));

        assert_eq!(info.format_name.as_deref(), Some("mpegts"));
        assert!((info.duration_secs.unwrap() - 3600.5).abs() < f64::EPSILON);
        assert_eq!(info.overall_bitrate, Some(5_000_000));
    }

    #[test]
    fn selects_highest_resolution_video() {
        let info = parse_ffprobe_json(MULTI_VIDEO_JSON).unwrap();
        let video = info.video.unwrap();
        assert_eq!(video.codec, "hevc");
        assert_eq!(video.width, 3840);
        assert_eq!(video.height, 2160);
        assert_eq!(video.resolution, Resolution::UHD);
        assert!((video.fps - 60.0).abs() < f64::EPSILON);
    }

    #[test]
    fn detects_audio_only_stream() {
        let info = parse_ffprobe_json(AUDIO_ONLY_JSON).unwrap();
        assert!(info.video.is_none());
        let audio = info.audio.unwrap();
        assert_eq!(audio.codec, "mp3");
        assert_eq!(audio.bitrate, Some(192_000));
    }

    #[test]
    fn empty_streams_returns_default() {
        let json = r#"{"streams": [], "format": {}}"#;
        let info = parse_ffprobe_json(json).unwrap();
        assert!(info.video.is_none());
        assert!(info.audio.is_none());
    }

    #[test]
    fn handles_missing_optional_fields() {
        let json = r#"{
            "streams": [{
                "codec_type": "video",
                "codec_name": "vp9",
                "width": 1280,
                "height": 720
            }]
        }"#;
        let info = parse_ffprobe_json(json).unwrap();
        let video = info.video.unwrap();
        assert_eq!(video.codec, "vp9");
        assert_eq!(video.resolution, Resolution::HD);
        assert!((video.fps - 0.0).abs() < f64::EPSILON);
        assert!(video.bitrate.is_none());
        assert!(info.format_name.is_none());
    }

    #[tokio::test]
    async fn ffprobe_availability_does_not_panic() {
        // This test just verifies the function doesn't panic.
        // Result depends on whether ffprobe is installed.
        let _available = is_ffprobe_available().await;
    }
}
