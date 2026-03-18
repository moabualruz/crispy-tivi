//! Stream quality ranking and best-source selection.
//!
//! 8 quality tiers (highest first):
//!   8 — 4K + Dolby Vision + Atmos
//!   7 — 4K + HDR
//!   6 — 4K (UHD)
//!   5 — 1080p + Atmos
//!   4 — 1080p (Full HD)
//!   3 — 720p (HD)
//!   2 — 480p (SD)
//!   1 — Unknown / below 480p

use serde::{Deserialize, Serialize};

use crate::models::stream_quality::{Resolution, StreamInfo};

// ── Quality tier ──────────────────────────────────────────

/// Quality tier score (1 = worst, 8 = best).
pub type QualityTier = u8;

/// Extended stream metadata needed for ranking.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SourceStream {
    /// Base stream info (URL, resolution, bitrate).
    pub info: StreamInfo,
    /// True if stream has Dolby Vision.
    pub has_dolby_vision: bool,
    /// True if stream has HDR (HDR10, HDR10+, HLG …).
    pub has_hdr: bool,
    /// True if stream has Dolby Atmos audio.
    pub has_atmos: bool,
    /// Source-level health score in [0.0, 1.0].
    pub health_score: f64,
    /// Measured or estimated latency in milliseconds.
    pub latency_ms: u32,
    /// Position of the originating source in the user's source list (0 = first).
    pub source_order: u32,
}

/// User preference for source selection.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct SelectionPreference {
    /// If `Some`, always prefer this stream URL over all others.
    pub sticky_url: Option<String>,
    /// Desired quality tier (1-8). `None` = highest available.
    pub preferred_tier: Option<QualityTier>,
    /// Weight given to health score vs quality (0.0 = quality only, 1.0 = health only).
    pub health_weight: f64,
}

// ── Ranking ───────────────────────────────────────────────

/// Compute the quality tier for a single stream.
///
/// Tier assignment:
/// - 8: UHD4K + Dolby Vision + Atmos
/// - 7: UHD4K + HDR (any)
/// - 6: UHD4K (no HDR/DV)
/// - 5: FullHD + Atmos
/// - 4: FullHD
/// - 3: HD (720p)
/// - 2: SD (480p)
/// - 1: below SD / unknown
pub fn rank_stream(info: &StreamInfo, has_dv: bool, has_hdr: bool, has_atmos: bool) -> QualityTier {
    use Resolution::*;
    match info.resolution {
        UHD4K => {
            if has_dv && has_atmos {
                8
            } else if has_hdr || has_dv {
                7
            } else {
                6
            }
        }
        FullHD | QHD => {
            if has_atmos {
                5
            } else {
                4
            }
        }
        HD => 3,
        SD => 2,
    }
}

/// Select the best source from `sources` given `preference`.
///
/// Selection order:
/// 1. User sticky URL (if set and present in sources) — returned immediately.
/// 2. Preferred quality tier (if set) — candidates limited to that tier.
/// 3. Within candidates: score = quality_tier * (1 - health_weight) + health_score * health_weight.
/// 4. Ties broken by latency (lower is better), then source_order (lower is better).
pub fn select_best_source<'a>(
    sources: &'a [SourceStream],
    preference: &SelectionPreference,
) -> Option<&'a SourceStream> {
    if sources.is_empty() {
        return None;
    }

    // 1. Sticky URL.
    if let Some(ref sticky) = preference.sticky_url
        && let Some(s) = sources.iter().find(|s| &s.info.url == sticky)
    {
        return Some(s);
    }

    // 2. Build candidate list filtered by preferred tier.
    let candidates: Vec<&SourceStream> = if let Some(tier) = preference.preferred_tier {
        let filtered: Vec<&SourceStream> = sources
            .iter()
            .filter(|s| rank_stream(&s.info, s.has_dolby_vision, s.has_hdr, s.has_atmos) == tier)
            .collect();
        if filtered.is_empty() {
            sources.iter().collect()
        } else {
            filtered
        }
    } else {
        sources.iter().collect()
    };

    // 3. Score each candidate.
    let hw = preference.health_weight.clamp(0.0, 1.0);
    candidates.iter().copied().max_by(|a, b| {
        let tier_a = rank_stream(&a.info, a.has_dolby_vision, a.has_hdr, a.has_atmos) as f64;
        let tier_b = rank_stream(&b.info, b.has_dolby_vision, b.has_hdr, b.has_atmos) as f64;
        let score_a = tier_a / 8.0 * (1.0 - hw) + a.health_score * hw;
        let score_b = tier_b / 8.0 * (1.0 - hw) + b.health_score * hw;
        score_a
            .partial_cmp(&score_b)
            .unwrap_or(std::cmp::Ordering::Equal)
            // 4. Tie-break by latency (lower better), then source_order (lower better).
            .then(b.latency_ms.cmp(&a.latency_ms))
            .then(b.source_order.cmp(&a.source_order))
    })
}

// ── Tests ─────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::stream_quality::Resolution;

    fn si(res: Resolution, kbps: u32) -> StreamInfo {
        StreamInfo {
            url: format!("{res:?}_{kbps}"),
            resolution: res,
            bitrate_kbps: kbps,
            label: None,
        }
    }

    fn src(
        res: Resolution,
        kbps: u32,
        dv: bool,
        hdr: bool,
        atmos: bool,
        health: f64,
        latency: u32,
        order: u32,
    ) -> SourceStream {
        SourceStream {
            info: si(res, kbps),
            has_dolby_vision: dv,
            has_hdr: hdr,
            has_atmos: atmos,
            health_score: health,
            latency_ms: latency,
            source_order: order,
        }
    }

    // ── rank_stream ───────────────────────────────────────

    #[test]
    fn test_tier8_4k_dv_atmos() {
        assert_eq!(rank_stream(&si(Resolution::UHD4K, 0), true, false, true), 8);
    }

    #[test]
    fn test_tier7_4k_hdr() {
        assert_eq!(
            rank_stream(&si(Resolution::UHD4K, 0), false, true, false),
            7
        );
    }

    #[test]
    fn test_tier7_4k_dv_no_atmos() {
        assert_eq!(
            rank_stream(&si(Resolution::UHD4K, 0), true, false, false),
            7
        );
    }

    #[test]
    fn test_tier6_4k_plain() {
        assert_eq!(
            rank_stream(&si(Resolution::UHD4K, 0), false, false, false),
            6
        );
    }

    #[test]
    fn test_tier5_fhd_atmos() {
        assert_eq!(
            rank_stream(&si(Resolution::FullHD, 0), false, false, true),
            5
        );
    }

    #[test]
    fn test_tier4_fhd() {
        assert_eq!(
            rank_stream(&si(Resolution::FullHD, 0), false, false, false),
            4
        );
    }

    #[test]
    fn test_tier3_hd() {
        assert_eq!(rank_stream(&si(Resolution::HD, 0), false, false, false), 3);
    }

    #[test]
    fn test_tier2_sd() {
        assert_eq!(rank_stream(&si(Resolution::SD, 0), false, false, false), 2);
    }

    // ── select_best_source ────────────────────────────────

    #[test]
    fn test_select_best_quality_wins() {
        let sources = vec![
            src(Resolution::HD, 2000, false, false, false, 1.0, 50, 0),
            src(Resolution::FullHD, 4000, false, false, false, 0.8, 80, 1),
            src(Resolution::UHD4K, 20000, false, false, false, 0.6, 100, 2),
        ];
        let pref = SelectionPreference::default();
        let best = select_best_source(&sources, &pref).unwrap();
        assert_eq!(best.info.resolution, Resolution::UHD4K);
    }

    #[test]
    fn test_select_sticky_url_wins() {
        let sources = vec![
            src(Resolution::HD, 2000, false, false, false, 1.0, 10, 0),
            src(Resolution::UHD4K, 20000, false, false, false, 0.5, 200, 1),
        ];
        let sticky = sources[0].info.url.clone();
        let pref = SelectionPreference {
            sticky_url: Some(sticky.clone()),
            ..Default::default()
        };
        let best = select_best_source(&sources, &pref).unwrap();
        assert_eq!(best.info.url, sticky);
    }

    #[test]
    fn test_select_health_weight_prefers_healthy() {
        let sources = vec![
            src(Resolution::UHD4K, 20000, false, false, false, 0.1, 100, 0),
            src(Resolution::HD, 2000, false, false, false, 1.0, 10, 1),
        ];
        let pref = SelectionPreference {
            health_weight: 1.0, // pure health
            ..Default::default()
        };
        let best = select_best_source(&sources, &pref).unwrap();
        assert_eq!(best.info.resolution, Resolution::HD); // healthy HD wins
    }

    #[test]
    fn test_select_latency_tiebreak() {
        let sources = vec![
            src(Resolution::FullHD, 4000, false, false, false, 0.9, 200, 0),
            src(Resolution::FullHD, 4000, false, false, false, 0.9, 50, 1),
        ];
        let pref = SelectionPreference::default();
        let best = select_best_source(&sources, &pref).unwrap();
        // Lower latency wins on tie.
        assert_eq!(best.latency_ms, 50);
    }

    #[test]
    fn test_select_empty_returns_none() {
        let pref = SelectionPreference::default();
        assert!(select_best_source(&[], &pref).is_none());
    }

    #[test]
    fn test_select_preferred_tier_filtered() {
        let sources = vec![
            src(Resolution::SD, 500, false, false, false, 1.0, 10, 0),
            src(Resolution::FullHD, 4000, false, false, false, 0.5, 100, 1),
        ];
        let pref = SelectionPreference {
            preferred_tier: Some(4), // FullHD
            ..Default::default()
        };
        let best = select_best_source(&sources, &pref).unwrap();
        assert_eq!(best.info.resolution, Resolution::FullHD);
    }

    #[test]
    fn test_select_preferred_tier_fallback_when_none_match() {
        let sources = vec![
            src(Resolution::SD, 500, false, false, false, 0.8, 10, 0),
            src(Resolution::HD, 2000, false, false, false, 0.7, 50, 1),
        ];
        let pref = SelectionPreference {
            preferred_tier: Some(8), // no 4K+DV+Atmos available
            ..Default::default()
        };
        // Falls back to best available.
        let best = select_best_source(&sources, &pref).unwrap();
        assert_eq!(best.info.resolution, Resolution::HD);
    }
}
