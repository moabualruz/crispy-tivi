//! Type definitions for EPG matching.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

use crate::models::EpgEntry;

/// Statistics for each matching strategy.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct EpgMatchStats {
    /// Strategy 1: exact tvg_id match.
    pub tvg_id_exact: i32,
    /// Strategy 2: case-insensitive tvg_id.
    pub tvg_id_lower: i32,
    /// Strategy 3: direct channel.id match.
    pub direct_id: i32,
    /// Strategy 4: XMLTV display-name lookup.
    pub xmltv_name: i32,
    /// Strategy 5: normalized name.
    pub norm_name: i32,
    /// Strategy 6: channel ID used as name.
    pub name_as_id: i32,
    /// Deprecated: was fuzzy substring matching (removed).
    /// Kept for JSON backwards compatibility; always 0.
    pub fuzzy_name: i32,
    /// No match found.
    pub unmatched: i32,
}

/// Result of EPG matching: entries grouped by internal
/// channel ID, plus match statistics.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EpgMatchResult {
    /// `internal_channel_id` -> matched EPG entries.
    pub entries: HashMap<String, Vec<EpgEntry>>,
    /// Per-strategy hit counts.
    pub stats: EpgMatchStats,
}

/// Enum for tracking which strategy matched.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MatchStrategy {
    TvgIdExact,
    TvgIdLower,
    DirectId,
    XmltvName,
    NormName,
    NameAsId,
    Fuzzy,
}

impl MatchStrategy {
    /// Base confidence score for this strategy.
    pub fn confidence(self) -> f64 {
        match self {
            Self::TvgIdExact => 1.0,
            Self::TvgIdLower => 0.95,
            Self::DirectId => 0.90,
            Self::XmltvName => 0.85,
            Self::NormName => 0.80,
            Self::NameAsId => 0.70,
            Self::Fuzzy => 0.0, // variable — set per match
        }
    }
}

/// Corroboration boost per additional matching strategy.
pub const CORROBORATION_BOOST: f64 = 0.05;

/// Auto-apply threshold: matches >= this are applied
/// without user review.
pub const AUTO_APPLY_THRESHOLD: f64 = 0.70;

/// Suggestion threshold: matches >= this (but below
/// auto-apply) are saved for user review.
pub const SUGGEST_THRESHOLD: f64 = 0.40;

/// A candidate EPG match with confidence scoring.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EpgMatchCandidate {
    /// Internal channel ID.
    pub channel_id: String,
    /// XMLTV EPG channel ID.
    pub epg_channel_id: String,
    /// Confidence score (0.0 - 1.0).
    pub confidence: f64,
    /// Strategies that matched this pair.
    pub strategies: Vec<MatchStrategy>,
    /// Whether to auto-apply (confidence >= 0.70).
    pub auto_apply: bool,
}

/// Check if text contains CJK characters (Chinese/Japanese/Korean).
pub(crate) fn contains_cjk(text: &str) -> bool {
    text.chars().any(|c| {
        matches!(c,
            '\u{2E80}'..='\u{9FFF}'  // CJK radicals, Kangxi, Hiragana, Katakana, unified ideographs
            | '\u{F900}'..='\u{FAFF}' // CJK compatibility ideographs
            | '\u{FE30}'..='\u{FE4F}' // CJK compatibility forms
        )
    })
}

/// Check if a channel name and EPG entry title have compatible scripts.
///
/// Returns `false` when a non-CJK channel name is paired with a CJK
/// programme title, which indicates a cross-language mapping collision
/// (e.g. Japanese J SPORTS content matched to Arabic beIN SPORTS via
/// a numeric tvg_id collision).
pub(crate) fn scripts_compatible(channel_name: &str, title: &str) -> bool {
    let ch_cjk = contains_cjk(channel_name);
    let title_cjk = contains_cjk(title);

    // Non-CJK channel + CJK title → mismatch.
    if !ch_cjk && title_cjk {
        return false;
    }
    // CJK channel + non-CJK title is OK — CJK channels often
    // have English/romanized programme titles.
    true
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── contains_cjk unit tests ─────────────────────

    #[test]
    fn contains_cjk_detects_kanji() {
        assert!(contains_cjk("アルペンスキー"));
        assert!(contains_cjk("NHK ニュース"));
        assert!(contains_cjk("テレビ朝日"));
    }

    #[test]
    fn contains_cjk_rejects_latin() {
        assert!(!contains_cjk("BBC One HD"));
        assert!(!contains_cjk("Be inSPORTS 2 4K"));
        assert!(!contains_cjk("Al Jazeera"));
    }

    #[test]
    fn contains_cjk_detects_chinese() {
        assert!(contains_cjk("中央电视台"));
        assert!(contains_cjk("CCTV 新闻"));
    }

    #[test]
    fn contains_cjk_detects_mixed() {
        // Mixed Latin + CJK should be detected.
        assert!(contains_cjk("SUPER GT FESTIVAL テスト"));
    }

    #[test]
    fn scripts_compatible_rejects_cjk_on_latin() {
        assert!(!scripts_compatible(
            "Be inSPORTS 2 4K",
            "アルペンスキーFIS W杯"
        ));
    }

    #[test]
    fn scripts_compatible_accepts_latin_on_latin() {
        assert!(scripts_compatible("BBC One", "EastEnders"));
    }

    #[test]
    fn scripts_compatible_accepts_cjk_on_cjk() {
        assert!(scripts_compatible("NHK 総合テレビ", "ニュース7"));
    }

    #[test]
    fn scripts_compatible_accepts_latin_on_cjk() {
        assert!(scripts_compatible("テレビ朝日", "SUPER GT FESTIVAL 2026"));
    }
}
