//! Stream quality selection data model for CrispyTivi.
//!
//! Defines quality levels, user preferences, and the
//! `select_best_stream` function that chooses the optimal
//! stream variant from a list of available `StreamInfo` items.

use serde::{Deserialize, Serialize};

// ── Resolution ───────────────────────────────────────────

/// Vertical resolution in pixels.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub enum Resolution {
    /// 480p standard definition.
    SD,
    /// 720p high definition.
    HD,
    /// 1080p full HD.
    FullHD,
    /// 1440p quad HD.
    QHD,
    /// 2160p 4K ultra HD.
    UHD4K,
}

impl Resolution {
    /// Pixel height of this resolution tier.
    pub fn pixel_height(self) -> u32 {
        match self {
            Self::SD => 480,
            Self::HD => 720,
            Self::FullHD => 1080,
            Self::QHD => 1440,
            Self::UHD4K => 2160,
        }
    }

    /// Best-effort parse from a height value.
    pub fn from_height(height: u32) -> Self {
        if height >= 2160 {
            Self::UHD4K
        } else if height >= 1440 {
            Self::QHD
        } else if height >= 1080 {
            Self::FullHD
        } else if height >= 720 {
            Self::HD
        } else {
            Self::SD
        }
    }
}

// ── StreamQuality ────────────────────────────────────────

/// Requested quality mode.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum StreamQuality {
    /// Player picks the best quality automatically.
    Auto,
    /// Exactly this resolution tier.
    Specific(Resolution),
}

// ── QualityPreference ────────────────────────────────────

/// Per-profile quality preference.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QualityPreference {
    /// Quality selection mode.
    pub mode: StreamQuality,
    /// Optional cap — never select a stream above this resolution
    /// even in `Auto` mode. `None` means uncapped.
    pub max_quality: Option<Resolution>,
    /// When `true`, prefer the lowest available quality to
    /// save mobile data.
    pub data_saver: bool,
}

impl Default for QualityPreference {
    fn default() -> Self {
        Self {
            mode: StreamQuality::Auto,
            max_quality: None,
            data_saver: false,
        }
    }
}

// ── StreamInfo ───────────────────────────────────────────

/// Metadata for a single stream variant.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StreamInfo {
    /// Playback URL for this variant.
    pub url: String,
    /// Detected or declared resolution.
    pub resolution: Resolution,
    /// Approximate bitrate in kbps (0 = unknown).
    pub bitrate_kbps: u32,
    /// Human-readable label (e.g. "HD", "4K").
    pub label: Option<String>,
}

// ── Quality selection ────────────────────────────────────

/// Choose the best stream from `available` given `preference`.
///
/// Rules (applied in order):
/// 1. If `data_saver` is set, return the lowest available.
/// 2. Apply `max_quality` cap to filter out streams above it.
/// 3. If `mode` is `Specific(r)`, pick the exact match or the
///    closest below.
/// 4. If `mode` is `Auto`, return the highest remaining.
/// 5. Falls back to the first entry if no filtered match.
///
/// Returns `None` only when `available` is empty.
pub fn select_best_stream<'a>(
    available: &'a [StreamInfo],
    preference: &QualityPreference,
) -> Option<&'a StreamInfo> {
    if available.is_empty() {
        return None;
    }

    // 1. Data-saver: return lowest.
    if preference.data_saver {
        return available.iter().min_by_key(|s| s.resolution);
    }

    // 2. Apply max_quality cap.
    let candidates: Vec<&StreamInfo> = match preference.max_quality {
        Some(cap) => available.iter().filter(|s| s.resolution <= cap).collect(),
        None => available.iter().collect(),
    };

    let candidates = if candidates.is_empty() {
        // If cap filters everything, relax and use all.
        available.iter().collect::<Vec<_>>()
    } else {
        candidates
    };

    match &preference.mode {
        // 3. Specific: exact match first, then closest below.
        StreamQuality::Specific(target) => {
            // Exact match.
            if let Some(exact) = candidates.iter().find(|s| s.resolution == *target) {
                return Some(exact);
            }
            // Closest below target (highest that is still ≤ target).
            candidates
                .iter()
                .filter(|s| s.resolution <= *target)
                .max_by_key(|s| s.resolution)
                .or_else(|| candidates.iter().max_by_key(|s| s.resolution))
                .copied()
        }
        // 4. Auto: highest available.
        StreamQuality::Auto => candidates.iter().max_by_key(|s| s.resolution).copied(),
    }
}

// ── Tests ─────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn stream(url: &str, res: Resolution, kbps: u32) -> StreamInfo {
        StreamInfo {
            url: url.to_string(),
            resolution: res,
            bitrate_kbps: kbps,
            label: None,
        }
    }

    #[test]
    fn test_select_best_auto_returns_highest() {
        let streams = vec![
            stream("sd", Resolution::SD, 500),
            stream("hd", Resolution::HD, 2000),
            stream("fhd", Resolution::FullHD, 4000),
        ];
        let pref = QualityPreference::default();
        let best = select_best_stream(&streams, &pref).unwrap();
        assert_eq!(best.url, "fhd");
    }

    #[test]
    fn test_select_best_data_saver_returns_lowest() {
        let streams = vec![
            stream("sd", Resolution::SD, 500),
            stream("hd", Resolution::HD, 2000),
            stream("fhd", Resolution::FullHD, 4000),
        ];
        let pref = QualityPreference {
            data_saver: true,
            ..Default::default()
        };
        let best = select_best_stream(&streams, &pref).unwrap();
        assert_eq!(best.url, "sd");
    }

    #[test]
    fn test_select_best_with_max_quality_cap() {
        let streams = vec![
            stream("sd", Resolution::SD, 500),
            stream("hd", Resolution::HD, 2000),
            stream("4k", Resolution::UHD4K, 20000),
        ];
        let pref = QualityPreference {
            max_quality: Some(Resolution::HD),
            ..Default::default()
        };
        let best = select_best_stream(&streams, &pref).unwrap();
        assert_eq!(best.url, "hd");
    }

    #[test]
    fn test_select_best_specific_exact_match() {
        let streams = vec![
            stream("sd", Resolution::SD, 500),
            stream("hd", Resolution::HD, 2000),
            stream("fhd", Resolution::FullHD, 4000),
        ];
        let pref = QualityPreference {
            mode: StreamQuality::Specific(Resolution::HD),
            ..Default::default()
        };
        let best = select_best_stream(&streams, &pref).unwrap();
        assert_eq!(best.url, "hd");
    }

    #[test]
    fn test_select_best_specific_fallback_below() {
        let streams = vec![
            stream("sd", Resolution::SD, 500),
            stream("fhd", Resolution::FullHD, 4000),
        ];
        // Request HD but no HD stream; should fall back to SD.
        let pref = QualityPreference {
            mode: StreamQuality::Specific(Resolution::HD),
            ..Default::default()
        };
        let best = select_best_stream(&streams, &pref).unwrap();
        assert_eq!(best.url, "sd");
    }

    #[test]
    fn test_select_best_empty_returns_none() {
        let streams: Vec<StreamInfo> = vec![];
        let pref = QualityPreference::default();
        assert!(select_best_stream(&streams, &pref).is_none());
    }

    #[test]
    fn test_resolution_ordering() {
        assert!(Resolution::SD < Resolution::HD);
        assert!(Resolution::HD < Resolution::FullHD);
        assert!(Resolution::FullHD < Resolution::QHD);
        assert!(Resolution::QHD < Resolution::UHD4K);
    }

    #[test]
    fn test_resolution_pixel_height() {
        assert_eq!(Resolution::SD.pixel_height(), 480);
        assert_eq!(Resolution::HD.pixel_height(), 720);
        assert_eq!(Resolution::FullHD.pixel_height(), 1080);
        assert_eq!(Resolution::QHD.pixel_height(), 1440);
        assert_eq!(Resolution::UHD4K.pixel_height(), 2160);
    }

    #[test]
    fn test_resolution_from_height() {
        assert_eq!(Resolution::from_height(480), Resolution::SD);
        assert_eq!(Resolution::from_height(720), Resolution::HD);
        assert_eq!(Resolution::from_height(1080), Resolution::FullHD);
        assert_eq!(Resolution::from_height(1440), Resolution::QHD);
        assert_eq!(Resolution::from_height(2160), Resolution::UHD4K);
        assert_eq!(Resolution::from_height(300), Resolution::SD);
    }

    #[test]
    fn test_cap_relaxed_when_all_exceed_cap() {
        // If cap filters all streams, return best available.
        let streams = vec![
            stream("fhd", Resolution::FullHD, 4000),
            stream("4k", Resolution::UHD4K, 20000),
        ];
        let pref = QualityPreference {
            max_quality: Some(Resolution::SD), // nothing matches cap
            ..Default::default()
        };
        // Should not return None — falls back to all.
        let best = select_best_stream(&streams, &pref).unwrap();
        assert_eq!(best.url, "4k"); // highest after relaxation
    }
}
