//! Domain types for media probe results.

use crispy_iptv_types::Resolution;
use serde::{Deserialize, Serialize};

/// Complete media information from ffprobe analysis.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct MediaInfo {
    /// Video stream information (absent for audio-only streams).
    pub video: Option<VideoInfo>,
    /// Audio stream information (absent for video-only streams).
    pub audio: Option<AudioInfo>,
    /// Container format name (e.g. "mpegts", "hls").
    pub format_name: Option<String>,
    /// Duration in seconds, if known.
    pub duration_secs: Option<f64>,
    /// Overall bitrate in bits/s, if known.
    pub overall_bitrate: Option<u64>,
}

/// Video stream details extracted from ffprobe.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VideoInfo {
    /// Codec name (e.g. "h264", "hevc", "vp9").
    pub codec: String,
    /// Frame width in pixels.
    pub width: u32,
    /// Frame height in pixels.
    pub height: u32,
    /// Frames per second.
    pub fps: f64,
    /// Video bitrate in bits/s, if known.
    pub bitrate: Option<u64>,
    /// Classified resolution tier.
    pub resolution: Resolution,
}

/// Audio stream details extracted from ffprobe.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AudioInfo {
    /// Codec name (e.g. "aac", "mp3", "ac3").
    pub codec: String,
    /// Audio bitrate in bits/s, if known.
    pub bitrate: Option<u64>,
    /// Number of audio channels.
    pub channels: Option<u32>,
    /// Sample rate in Hz.
    pub sample_rate: Option<u32>,
}

/// An HLS variant stream entry parsed from a master playlist.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HlsVariant {
    /// Resolved URL of this variant.
    pub url: String,
    /// Declared bandwidth in bits/s.
    pub bandwidth: u64,
    /// Average bandwidth in bits/s, if declared.
    pub average_bandwidth: Option<u64>,
    /// Resolution width in pixels, if declared.
    pub width: Option<u32>,
    /// Resolution height in pixels, if declared.
    pub height: Option<u32>,
    /// Codecs string, if declared.
    pub codecs: Option<String>,
}

impl HlsVariant {
    /// Quality score used for selecting the best variant.
    ///
    /// Scoring logic translated from IPTVChecker-Python `extract_next_url`:
    /// priority tuple of (has_resolution, pixel_count, average_bandwidth, bandwidth).
    pub fn quality_score(&self) -> (u8, u64, u64, u64) {
        let pixels = match (self.width, self.height) {
            (Some(w), Some(h)) if w > 0 && h > 0 => u64::from(w) * u64::from(h),
            _ => 0,
        };
        let has_res = u8::from(pixels > 0);
        (
            has_res,
            pixels,
            self.average_bandwidth.unwrap_or(0),
            self.bandwidth,
        )
    }
}

/// Classify pixel height into a [`Resolution`] tier.
///
/// Translated from iptvtools `height_to_resolution` + IPTVChecker-Python
/// `get_detailed_stream_info` resolution logic.
pub fn classify_resolution(width: u32, height: u32) -> Resolution {
    if width >= 3840 && height >= 2160 {
        Resolution::UHD
    } else if width >= 1920 && height >= 1080 {
        Resolution::FHD
    } else if width >= 1280 && height >= 720 {
        Resolution::HD
    } else if width > 0 && height > 0 {
        Resolution::SD
    } else {
        Resolution::Unknown
    }
}

/// Convert pixel height to a human-readable resolution label.
///
/// Translated from iptvtools `height_to_resolution`.
pub fn height_to_label(height: u32) -> &'static str {
    if height == 0 {
        "Unknown"
    } else if height >= 4320 {
        "8K"
    } else if height >= 2160 {
        "4K"
    } else if height >= 1080 {
        "1080p"
    } else if height >= 720 {
        "720p"
    } else {
        "SD"
    }
}

/// Parse a fractional frame-rate string (e.g. "30000/1001") into an f64.
///
/// Translated from IPTVChecker-Python `get_detailed_stream_info` FPS parsing.
pub fn parse_frame_rate(fps_str: &str) -> Option<f64> {
    let trimmed = fps_str.trim();
    if trimmed.is_empty() {
        return None;
    }

    if let Some((num_str, den_str)) = trimmed.split_once('/') {
        let num: f64 = num_str.trim().parse().ok()?;
        let den: f64 = den_str.trim().parse().ok()?;
        if den > 0.0 {
            let fps = num / den;
            if fps > 0.0 {
                return Some(fps);
            }
        }
        None
    } else {
        let fps: f64 = trimmed.parse().ok()?;
        if fps > 0.0 { Some(fps) } else { None }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn classify_resolution_from_dimensions() {
        assert_eq!(classify_resolution(3840, 2160), Resolution::UHD);
        assert_eq!(classify_resolution(1920, 1080), Resolution::FHD);
        assert_eq!(classify_resolution(1280, 720), Resolution::HD);
        assert_eq!(classify_resolution(720, 576), Resolution::SD);
        assert_eq!(classify_resolution(640, 480), Resolution::SD);
        assert_eq!(classify_resolution(0, 0), Resolution::Unknown);
    }

    #[test]
    fn height_to_label_covers_all_tiers() {
        assert_eq!(height_to_label(0), "Unknown");
        assert_eq!(height_to_label(480), "SD");
        assert_eq!(height_to_label(720), "720p");
        assert_eq!(height_to_label(1080), "1080p");
        assert_eq!(height_to_label(2160), "4K");
        assert_eq!(height_to_label(4320), "8K");
    }

    #[test]
    fn parse_fractional_frame_rate() {
        let fps = parse_frame_rate("30000/1001").unwrap();
        assert!((fps - 29.97).abs() < 0.01);
    }

    #[test]
    fn parse_integer_frame_rate() {
        let fps = parse_frame_rate("25").unwrap();
        assert!((fps - 25.0).abs() < f64::EPSILON);
    }

    #[test]
    fn parse_frame_rate_zero_denominator() {
        assert!(parse_frame_rate("30/0").is_none());
    }

    #[test]
    fn parse_frame_rate_empty() {
        assert!(parse_frame_rate("").is_none());
    }

    #[test]
    fn parse_frame_rate_negative() {
        assert!(parse_frame_rate("-25").is_none());
    }

    #[test]
    fn hls_variant_quality_score_ordering() {
        let low = HlsVariant {
            url: "low.m3u8".into(),
            bandwidth: 500_000,
            average_bandwidth: None,
            width: Some(640),
            height: Some(360),
            codecs: None,
        };
        let high = HlsVariant {
            url: "high.m3u8".into(),
            bandwidth: 5_000_000,
            average_bandwidth: Some(4_500_000),
            width: Some(1920),
            height: Some(1080),
            codecs: None,
        };
        assert!(high.quality_score() > low.quality_score());
    }

    #[test]
    fn hls_variant_no_resolution_scores_lower() {
        let with_res = HlsVariant {
            url: "a.m3u8".into(),
            bandwidth: 1_000_000,
            average_bandwidth: None,
            width: Some(1280),
            height: Some(720),
            codecs: None,
        };
        let without_res = HlsVariant {
            url: "b.m3u8".into(),
            bandwidth: 10_000_000,
            average_bandwidth: None,
            width: None,
            height: None,
            codecs: None,
        };
        assert!(with_res.quality_score() > without_res.quality_score());
    }
}
