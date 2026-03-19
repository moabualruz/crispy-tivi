//! Caption and subtitle format support.
//!
//! CrispyTivi uses libmpv as the sole video backend. mpv handles all
//! subtitle and caption formats natively via its built-in demuxers and
//! renderers — no additional parsing code is required in this crate.
//!
//! # Supported formats (mpv native)
//!
//! | Format | mpv support | Notes |
//! |--------|-------------|-------|
//! | CEA-608 | Yes | Embedded in MPEG-2/H.264 video streams |
//! | CEA-708 | Yes | Digital TV closed captions |
//! | WebVTT  | Yes | `.vtt` sidecar or in-stream (HLS) |
//! | SRT     | Yes | `.srt` sidecar files |
//! | TTML    | Yes | `.ttml` / `.xml`, also in-stream (DASH) |
//! | SSA/ASS | Yes | `.ssa` / `.ass` with full style rendering |
//! | DVB subtitles | Yes | Bitmap subtitles via `dvbsub` codec |
//! | DVDSUB  | Yes | Bitmap subtitles via `dvdsub` codec |
//! | PGS     | Yes | Blu-ray bitmap subtitles |
//! | MOV_TEXT | Yes | MP4-muxed QuickTime text |
//!
//! # Usage
//!
//! Subtitle tracks are exposed through the `PlayerBackend::get_subtitle_tracks()`
//! method. Selecting a sidecar file is done via `PlayerBackend::load_subtitle_file()`.
//! mpv automatically detects and renders the format.

use std::path::Path;

/// Caption/subtitle format identifiers.
///
/// These mirror the mpv codec strings where applicable. Use
/// [`CaptionFormat::from_extension`] or [`CaptionFormat::from_codec`]
/// to map user-visible file types and stream codec identifiers.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum CaptionFormat {
    /// SubRip text (`.srt`).
    Srt,
    /// WebVTT (`.vtt`) — also used in HLS streams.
    WebVtt,
    /// Sub Station Alpha (`.ssa`).
    Ssa,
    /// Advanced Sub Station Alpha (`.ass`).
    Ass,
    /// Timed Text Markup Language (`.ttml`, `.xml`).
    Ttml,
    /// CEA-608 closed captions embedded in video.
    Cea608,
    /// CEA-708 digital television closed captions.
    Cea708,
    /// DVB bitmap subtitles.
    Dvb,
    /// DVD bitmap subtitles (`dvdsub`).
    DvdSub,
    /// Blu-ray Presentation Graphic Stream (`hdmv_pgs_subtitle`).
    Pgs,
    /// QuickTime / MP4 text track (`mov_text`).
    MovText,
    /// Unknown / not detected.
    Unknown,
}

impl CaptionFormat {
    /// Detect the caption format from a sidecar file extension.
    ///
    /// The extension should be provided without a leading dot and is
    /// matched case-insensitively.
    ///
    /// ```
    /// use crispy_player::caption_formats::CaptionFormat;
    /// assert_eq!(CaptionFormat::from_extension("srt"), CaptionFormat::Srt);
    /// assert_eq!(CaptionFormat::from_extension("VTT"), CaptionFormat::WebVtt);
    /// assert_eq!(CaptionFormat::from_extension("xyz"), CaptionFormat::Unknown);
    /// ```
    pub fn from_extension(ext: &str) -> Self {
        match ext.to_ascii_lowercase().as_str() {
            "srt" => Self::Srt,
            "vtt" => Self::WebVtt,
            "ssa" => Self::Ssa,
            "ass" => Self::Ass,
            "ttml" | "xml" => Self::Ttml,
            _ => Self::Unknown,
        }
    }

    /// Detect the caption format from a file path.
    ///
    /// Extracts the extension and delegates to [`from_extension`].
    pub fn from_path(path: &Path) -> Self {
        path.extension()
            .and_then(|e| e.to_str())
            .map(Self::from_extension)
            .unwrap_or(Self::Unknown)
    }

    /// Map an mpv codec identifier string to the corresponding format.
    ///
    /// The codec string is as reported by mpv's `track-list` property
    /// (e.g. obtained via `TrackInfo::codec`).
    ///
    /// ```
    /// use crispy_player::caption_formats::CaptionFormat;
    /// assert_eq!(CaptionFormat::from_codec("subrip"), CaptionFormat::Srt);
    /// assert_eq!(CaptionFormat::from_codec("webvtt"), CaptionFormat::WebVtt);
    /// assert_eq!(CaptionFormat::from_codec("hdmv_pgs_subtitle"), CaptionFormat::Pgs);
    /// ```
    pub fn from_codec(codec: &str) -> Self {
        match codec.to_ascii_lowercase().as_str() {
            "subrip" | "srt" => Self::Srt,
            "webvtt" => Self::WebVtt,
            "ssa" => Self::Ssa,
            "ass" => Self::Ass,
            "ttml" => Self::Ttml,
            "eia_608" | "cea_608" | "cc_dec" => Self::Cea608,
            "eia_708" | "cea_708" => Self::Cea708,
            "dvb_subtitle" | "dvbsub" => Self::Dvb,
            "dvd_subtitle" | "dvdsub" => Self::DvdSub,
            "hdmv_pgs_subtitle" | "pgssub" => Self::Pgs,
            "mov_text" => Self::MovText,
            _ => Self::Unknown,
        }
    }

    /// Returns `true` if the format is a text-based subtitle (as opposed
    /// to a bitmap/image-based format).
    pub fn is_text_based(self) -> bool {
        matches!(
            self,
            Self::Srt | Self::WebVtt | Self::Ssa | Self::Ass | Self::Ttml | Self::MovText
        )
    }

    /// Returns `true` if the format is an over-the-air broadcast caption
    /// standard (CEA-608 or CEA-708).
    pub fn is_broadcast_caption(self) -> bool {
        matches!(self, Self::Cea608 | Self::Cea708)
    }

    /// Returns a human-readable display name for UI presentation.
    pub fn display_name(self) -> &'static str {
        match self {
            Self::Srt => "SubRip (SRT)",
            Self::WebVtt => "WebVTT",
            Self::Ssa => "Sub Station Alpha (SSA)",
            Self::Ass => "Advanced SSA (ASS)",
            Self::Ttml => "Timed Text (TTML)",
            Self::Cea608 => "CEA-608",
            Self::Cea708 => "CEA-708",
            Self::Dvb => "DVB Subtitles",
            Self::DvdSub => "DVD Subtitles",
            Self::Pgs => "Blu-ray PGS",
            Self::MovText => "MOV Text",
            Self::Unknown => "Unknown",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    // ── from_extension ──────────────────────────────────────────────────────

    #[test]
    fn test_from_extension_returns_srt_for_srt() {
        assert_eq!(CaptionFormat::from_extension("srt"), CaptionFormat::Srt);
    }

    #[test]
    fn test_from_extension_case_insensitive() {
        assert_eq!(CaptionFormat::from_extension("VTT"), CaptionFormat::WebVtt);
        assert_eq!(CaptionFormat::from_extension("SRT"), CaptionFormat::Srt);
        assert_eq!(CaptionFormat::from_extension("ASS"), CaptionFormat::Ass);
    }

    #[test]
    fn test_from_extension_returns_unknown_for_unrecognised() {
        assert_eq!(CaptionFormat::from_extension("mkv"), CaptionFormat::Unknown);
        assert_eq!(CaptionFormat::from_extension("mp4"), CaptionFormat::Unknown);
        assert_eq!(CaptionFormat::from_extension("xyz"), CaptionFormat::Unknown);
        assert_eq!(CaptionFormat::from_extension(""), CaptionFormat::Unknown);
    }

    #[test]
    fn test_from_extension_ttml_and_xml() {
        assert_eq!(CaptionFormat::from_extension("ttml"), CaptionFormat::Ttml);
        assert_eq!(CaptionFormat::from_extension("xml"), CaptionFormat::Ttml);
    }

    #[test]
    fn test_from_extension_ssa_and_ass() {
        assert_eq!(CaptionFormat::from_extension("ssa"), CaptionFormat::Ssa);
        assert_eq!(CaptionFormat::from_extension("ass"), CaptionFormat::Ass);
    }

    // ── from_path ───────────────────────────────────────────────────────────

    #[test]
    fn test_from_path_detects_srt() {
        let p = PathBuf::from("/media/subs/episode.srt");
        assert_eq!(CaptionFormat::from_path(&p), CaptionFormat::Srt);
    }

    #[test]
    fn test_from_path_no_extension_returns_unknown() {
        let p = PathBuf::from("/media/noext");
        assert_eq!(CaptionFormat::from_path(&p), CaptionFormat::Unknown);
    }

    // ── from_codec ──────────────────────────────────────────────────────────

    #[test]
    fn test_from_codec_subrip() {
        assert_eq!(CaptionFormat::from_codec("subrip"), CaptionFormat::Srt);
        assert_eq!(CaptionFormat::from_codec("srt"), CaptionFormat::Srt);
    }

    #[test]
    fn test_from_codec_webvtt() {
        assert_eq!(CaptionFormat::from_codec("webvtt"), CaptionFormat::WebVtt);
    }

    #[test]
    fn test_from_codec_pgs() {
        assert_eq!(
            CaptionFormat::from_codec("hdmv_pgs_subtitle"),
            CaptionFormat::Pgs
        );
    }

    #[test]
    fn test_from_codec_cea608_variants() {
        assert_eq!(CaptionFormat::from_codec("eia_608"), CaptionFormat::Cea608);
        assert_eq!(CaptionFormat::from_codec("cea_608"), CaptionFormat::Cea608);
        assert_eq!(CaptionFormat::from_codec("cc_dec"), CaptionFormat::Cea608);
    }

    #[test]
    fn test_from_codec_cea708_variants() {
        assert_eq!(CaptionFormat::from_codec("eia_708"), CaptionFormat::Cea708);
        assert_eq!(CaptionFormat::from_codec("cea_708"), CaptionFormat::Cea708);
    }

    #[test]
    fn test_from_codec_dvb_variants() {
        assert_eq!(
            CaptionFormat::from_codec("dvb_subtitle"),
            CaptionFormat::Dvb
        );
        assert_eq!(CaptionFormat::from_codec("dvbsub"), CaptionFormat::Dvb);
    }

    #[test]
    fn test_from_codec_dvdsub_variants() {
        assert_eq!(
            CaptionFormat::from_codec("dvd_subtitle"),
            CaptionFormat::DvdSub
        );
        assert_eq!(CaptionFormat::from_codec("dvdsub"), CaptionFormat::DvdSub);
    }

    #[test]
    fn test_from_codec_unknown_returns_unknown() {
        assert_eq!(CaptionFormat::from_codec("h264"), CaptionFormat::Unknown);
        assert_eq!(CaptionFormat::from_codec(""), CaptionFormat::Unknown);
    }

    // ── predicates ──────────────────────────────────────────────────────────

    #[test]
    fn test_is_text_based_true_for_text_formats() {
        for fmt in [
            CaptionFormat::Srt,
            CaptionFormat::WebVtt,
            CaptionFormat::Ssa,
            CaptionFormat::Ass,
            CaptionFormat::Ttml,
            CaptionFormat::MovText,
        ] {
            assert!(fmt.is_text_based(), "{fmt:?} should be text-based");
        }
    }

    #[test]
    fn test_is_text_based_false_for_bitmap_formats() {
        for fmt in [
            CaptionFormat::Dvb,
            CaptionFormat::DvdSub,
            CaptionFormat::Pgs,
            CaptionFormat::Cea608,
            CaptionFormat::Cea708,
        ] {
            assert!(!fmt.is_text_based(), "{fmt:?} should not be text-based");
        }
    }

    #[test]
    fn test_is_broadcast_caption() {
        assert!(CaptionFormat::Cea608.is_broadcast_caption());
        assert!(CaptionFormat::Cea708.is_broadcast_caption());
        assert!(!CaptionFormat::Srt.is_broadcast_caption());
        assert!(!CaptionFormat::WebVtt.is_broadcast_caption());
    }

    // ── display_name ────────────────────────────────────────────────────────

    #[test]
    fn test_display_name_non_empty_for_all_variants() {
        let all = [
            CaptionFormat::Srt,
            CaptionFormat::WebVtt,
            CaptionFormat::Ssa,
            CaptionFormat::Ass,
            CaptionFormat::Ttml,
            CaptionFormat::Cea608,
            CaptionFormat::Cea708,
            CaptionFormat::Dvb,
            CaptionFormat::DvdSub,
            CaptionFormat::Pgs,
            CaptionFormat::MovText,
            CaptionFormat::Unknown,
        ];
        for fmt in all {
            assert!(
                !fmt.display_name().is_empty(),
                "{fmt:?} has empty display_name"
            );
        }
    }
}
