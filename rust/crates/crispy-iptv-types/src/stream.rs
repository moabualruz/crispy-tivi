//! Stream URL types and validation.

use serde::{Deserialize, Serialize};

/// A validated stream URL with detected protocol.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StreamUrl {
    /// The raw URL string.
    pub url: String,
    /// Detected protocol.
    pub protocol: StreamProtocol,
}

impl StreamUrl {
    /// Parse a URL string and detect its streaming protocol.
    pub fn parse(url: &str) -> Self {
        let protocol = StreamProtocol::detect(url);
        Self {
            url: url.to_string(),
            protocol,
        }
    }
}

/// Detected streaming protocol.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum StreamProtocol {
    Http,
    Https,
    Hls,
    Dash,
    Rtmp,
    Rtsp,
    Udp,
    Rtp,
    Mms,
    #[default]
    Unknown,
}

impl StreamProtocol {
    /// Detect protocol from a URL string.
    pub fn detect(url: &str) -> Self {
        let lower = url.to_ascii_lowercase();
        if lower.starts_with("rtmp://") || lower.starts_with("rtmps://") {
            return Self::Rtmp;
        }
        if lower.starts_with("rtsp://") {
            return Self::Rtsp;
        }
        if lower.starts_with("udp://") {
            return Self::Udp;
        }
        if lower.starts_with("rtp://") {
            return Self::Rtp;
        }
        if lower.starts_with("mms://") || lower.starts_with("mmsh://") {
            return Self::Mms;
        }
        // HLS / DASH detection by extension.
        if lower.contains(".m3u8") || lower.contains("/hls/") {
            return Self::Hls;
        }
        if lower.contains(".mpd") || lower.contains("/dash/") {
            return Self::Dash;
        }
        if lower.starts_with("https://") {
            return Self::Https;
        }
        if lower.starts_with("http://") {
            return Self::Http;
        }
        Self::Unknown
    }
}

/// Result of checking a stream's availability.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StreamStatus {
    /// Whether the stream is reachable.
    pub available: bool,
    /// HTTP status code (if applicable).
    pub status_code: Option<u16>,
    /// Response time in milliseconds.
    pub response_time_ms: Option<u64>,
    /// Detected content type.
    pub content_type: Option<String>,
    /// Error message if unavailable.
    pub error: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn detect_hls() {
        assert_eq!(
            StreamProtocol::detect("http://example.com/live/stream.m3u8"),
            StreamProtocol::Hls,
        );
    }

    #[test]
    fn detect_rtmp() {
        assert_eq!(
            StreamProtocol::detect("rtmp://cdn.example.com/live/key"),
            StreamProtocol::Rtmp,
        );
    }

    #[test]
    fn detect_http() {
        assert_eq!(
            StreamProtocol::detect("http://example.com/stream.ts"),
            StreamProtocol::Http,
        );
    }

    #[test]
    fn detect_udp() {
        assert_eq!(
            StreamProtocol::detect("udp://239.0.0.1:5000"),
            StreamProtocol::Udp,
        );
    }

    #[test]
    fn detect_dash() {
        assert_eq!(
            StreamProtocol::detect("https://cdn.example.com/manifest.mpd"),
            StreamProtocol::Dash,
        );
    }

    #[test]
    fn detect_unknown() {
        assert_eq!(
            StreamProtocol::detect("ftp://example.com/file"),
            StreamProtocol::Unknown,
        );
    }

    #[test]
    fn stream_url_parse() {
        let s = StreamUrl::parse("https://cdn.example.com/live/stream.m3u8");
        assert_eq!(s.protocol, StreamProtocol::Hls);
    }
}
