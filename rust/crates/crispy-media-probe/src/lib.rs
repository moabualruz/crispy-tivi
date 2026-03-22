//! ffprobe/ffmpeg stream analysis and screenshot capture.
//!
//! This crate provides async functions for probing IPTV streams using
//! ffprobe and ffmpeg. It is a Rust translation of logic from:
//!
//! - [IPTVChecker-Python](https://github.com/kristofferR/IPTVChecker-Python)
//! - [iptv-checker-module](https://github.com/detroitenglish/iptv-checker-module)
//! - [iptvtools](https://github.com/huxuan/iptvtools)

pub mod bitrate;
pub mod error;
pub mod hls;
pub mod mismatch;
pub mod probe;
pub mod screenshot;
pub mod types;

// Re-export public API at crate root.
pub use bitrate::profile_bitrate;
pub use error::ProbeError;
pub use hls::{parse_hls_variants, select_best_variant};
pub use mismatch::check_label_mismatch;
pub use probe::{
    ProbeOptions, is_ffprobe_available, parse_ffprobe_json, probe_audio, probe_stream,
    probe_stream_with_options,
};
pub use screenshot::{capture_screenshot, is_ffmpeg_available, sanitize_filename};
pub use types::{
    AudioInfo, HlsVariant, MediaInfo, VideoInfo, classify_resolution, height_to_label,
    parse_frame_rate,
};
