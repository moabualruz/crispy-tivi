//! ffprobe/ffmpeg stream analysis and screenshot capture.
//!
//! This crate provides async functions for probing IPTV streams using
//! ffprobe and ffmpeg. It is a Rust translation of logic from:
//!
//! - [IPTVChecker-Python](https://github.com/kristofferR/IPTVChecker-Python)
//! - [iptv-checker-module](https://github.com/detroitenglish/iptv-checker-module)
//! - [iptvtools](https://github.com/huxuan/iptvtools)
//!
//! # Optional: libmpv backend
//!
//! When the `libmpv-backend` feature is enabled, this crate also provides
//! stream probing and screenshot capture via libmpv (loaded at runtime via
//! `dlopen`/`LoadLibrary`). This is useful when mpv is bundled by the
//! application (e.g. via Flutter's media_kit) but ffprobe is not installed.
//!
//! Set the `CRISPY_LIBMPV_PATH` environment variable to point to a specific
//! libmpv shared library. If not set, the system default is tried.

pub mod bitrate;
pub mod error;
pub mod hls;
pub mod mismatch;
pub mod probe;
pub mod screenshot;
pub mod types;

// libmpv backend modules (optional feature).
#[cfg(feature = "libmpv-backend")]
pub mod mpv_ffi;
#[cfg(feature = "libmpv-backend")]
pub mod mpv_probe;
#[cfg(feature = "libmpv-backend")]
pub mod mpv_screenshot;

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

// Re-export libmpv backend public API.
#[cfg(feature = "libmpv-backend")]
pub use mpv_ffi::is_mpv_available;
#[cfg(feature = "libmpv-backend")]
pub use mpv_probe::{is_mpv_probe_available, probe_stream_mpv};
#[cfg(feature = "libmpv-backend")]
pub use mpv_screenshot::{capture_screenshot_mpv, is_mpv_screenshot_available};
