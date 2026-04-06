//! Episode numbering parsers for XMLTV `<episode-num>` elements.
//!
//! Faithfully translated from pvr.iptvsimple `EpgEntry.cpp`:
//! - `ParseXmltvNsEpisodeNumberInfo()` — XMLTV-NS format ("0.4.2/3")
//! - `ParseOnScreenEpisodeNumberInfo()` — on-screen format ("S01E05", "E12")

use regex::Regex;
use std::sync::LazyLock;

/// Parsed episode information extracted from an XMLTV `<episode-num>` value.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EpisodeInfo {
    /// Season number (1-based for display).
    pub season: Option<u32>,
    /// Episode number (1-based for display).
    pub episode: Option<u32>,
    /// Part number within the episode (1-based for display).
    pub part: Option<u32>,
    /// Total number of parts (if provided, e.g. "2/3" means part 2 of 3).
    pub part_count: Option<u32>,
}

/// Parse an episode number value using the specified numbering system.
///
/// Dispatches to `parse_xmltv_ns` for `"xmltv_ns"` and `parse_onscreen`
/// for `"onscreen"`. Returns `None` for unknown systems.
pub fn parse_episode_number(value: &str, system: &str) -> Option<EpisodeInfo> {
    match system {
        "xmltv_ns" => parse_xmltv_ns(value),
        "onscreen" => parse_onscreen(value),
        _ => None,
    }
}

/// Parse XMLTV-NS episode numbering format.
///
/// Format: `"season.episode.part_number/total_parts"`
///
/// All numbers are **0-based** in the XMLTV-NS standard; this function
/// adds 1 to convert to 1-based display values.
///
/// Translated from `EpgEntry::ParseXmltvNsEpisodeNumberInfo` in pvr.iptvsimple.
///
/// # Examples
///
/// - `"0.4.2/3"` → season=1, episode=5, part=3, part_count=3
/// - `"1.0."` → season=2, episode=1
/// - `"2.5."` → season=3, episode=6
/// - `".0."` → episode=1 (no season)
pub fn parse_xmltv_ns(value: &str) -> Option<EpisodeInfo> {
    let trimmed = value.trim();

    // Must contain at least one dot to be valid xmltv_ns format.
    let first_dot = trimmed.find('.')?;

    let season_str = &trimmed[..first_dot];
    let remainder = &trimmed[first_dot + 1..];

    // Split remainder into episode and part strings.
    let (episode_str, part_str) = match remainder.find('.') {
        Some(pos) => (&remainder[..pos], &remainder[pos + 1..]),
        None => (remainder, ""),
    };

    let season = parse_int_and_increment(season_str);
    let episode = parse_int_and_increment(episode_str);

    // Parse part number: "2/3" → part=3 (0-based 2 + 1), part_count=3
    // A bare number without "/" is treated as invalid per C++ logic
    // (sets EPG_TAG_INVALID_SERIES_EPISODE).
    let (part, part_count) = if !part_str.is_empty() {
        parse_part_number(part_str)
    } else {
        (None, None)
    };

    // C++ returns `m_episodeNumber` as the success indicator.
    // We return Some if we parsed anything useful.
    if season.is_some() || episode.is_some() || part.is_some() {
        Some(EpisodeInfo {
            season,
            episode,
            part,
            part_count,
        })
    } else {
        None
    }
}

/// Parse on-screen episode numbering format.
///
/// Handles formats like `"S01E05"`, `"S 01 E 05"`, `"E12"`, `"EP12"`.
///
/// Numbers are already **1-based** in on-screen format — no adjustment needed.
///
/// Translated from `EpgEntry::ParseOnScreenEpisodeNumberInfo` in pvr.iptvsimple.
pub fn parse_onscreen(value: &str) -> Option<EpisodeInfo> {
    // C++ strips spaces, tabs, x, X, underscores, and dots.
    static UNWANTED_CHARS: LazyLock<Regex> =
        LazyLock::new(|| Regex::new(r"[ \txX_\.]").expect("invalid regex"));

    // Season + episode: S01E05, S01EP05
    static SEASON_EPISODE: LazyLock<Regex> =
        LazyLock::new(|| Regex::new(r"^[sS]([0-9]+)[eE][pP]?([0-9]+)$").expect("invalid regex"));

    // Episode only: E05, EP05
    static EPISODE_ONLY: LazyLock<Regex> =
        LazyLock::new(|| Regex::new(r"^[eE][pP]?([0-9]+)$").expect("invalid regex"));

    let cleaned = UNWANTED_CHARS.replace_all(value, "");

    if cleaned.is_empty() {
        return None;
    }

    // Try season+episode first (C++ checks StartsWithNoCase "S").
    let first_char = cleaned.as_bytes()[0];
    if first_char == b'S' || first_char == b's' {
        if let Some(caps) = SEASON_EPISODE.captures(&cleaned) {
            let season: u32 = caps[1].parse().ok()?;
            let episode: u32 = caps[2].parse().ok()?;
            return Some(EpisodeInfo {
                season: Some(season),
                episode: Some(episode),
                part: None,
                part_count: None,
            });
        }
    } else if first_char == b'E' || first_char == b'e' {
        // Try episode-only (C++ checks StartsWithNoCase "E").
        if let Some(caps) = EPISODE_ONLY.captures(&cleaned) {
            let episode: u32 = caps[1].parse().ok()?;
            return Some(EpisodeInfo {
                season: None,
                episode: Some(episode),
                part: None,
                part_count: None,
            });
        }
    }

    None
}

/// Parse a trimmed integer string and add 1 (0-based → 1-based).
/// Returns `None` for empty or non-numeric strings.
fn parse_int_and_increment(s: &str) -> Option<u32> {
    let trimmed = s.trim();
    if trimmed.is_empty() {
        return None;
    }
    let n: i32 = trimmed.parse().ok()?;
    if n < 0 {
        return None;
    }
    u32::try_from(n + 1).ok()
}

/// Parse part number string like "2/3" or bare "2".
///
/// C++ logic:
/// - If "numerator/denominator" parsed (2 elements), increment numerator by 1.
/// - If only numerator parsed (1 element), treat as invalid (return None).
fn parse_part_number(s: &str) -> (Option<u32>, Option<u32>) {
    let trimmed = s.trim();
    if trimmed.is_empty() {
        return (None, None);
    }

    if let Some(slash_pos) = trimmed.find('/') {
        let num_str = &trimmed[..slash_pos];
        let den_str = &trimmed[slash_pos + 1..];

        if let (Ok(num), Ok(den)) = (num_str.trim().parse::<i32>(), den_str.trim().parse::<i32>())
            && num >= 0
            && den > 0
        {
            return (u32::try_from(num + 1).ok(), u32::try_from(den).ok());
        }
    }

    // Bare number without denominator — C++ sets EPG_TAG_INVALID_SERIES_EPISODE,
    // which we represent as None.
    (None, None)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn xmltv_ns_full_format() {
        // "0.4.2/3" → season=1, episode=5, part=3, part_count=3
        let info = parse_xmltv_ns("0.4.2/3").unwrap();
        assert_eq!(info.season, Some(1));
        assert_eq!(info.episode, Some(5));
        assert_eq!(info.part, Some(3));
        assert_eq!(info.part_count, Some(3));
    }

    #[test]
    fn xmltv_ns_season_episode_only() {
        // "1.0." → season=2, episode=1
        let info = parse_xmltv_ns("1.0.").unwrap();
        assert_eq!(info.season, Some(2));
        assert_eq!(info.episode, Some(1));
        assert_eq!(info.part, None);
        assert_eq!(info.part_count, None);
    }

    #[test]
    fn xmltv_ns_no_season() {
        // ".0." → episode=1, no season
        let info = parse_xmltv_ns(".0.").unwrap();
        assert_eq!(info.season, None);
        assert_eq!(info.episode, Some(1));
        assert_eq!(info.part, None);
    }

    #[test]
    fn xmltv_ns_large_numbers() {
        // "2.5." → season=3, episode=6
        let info = parse_xmltv_ns("2.5.").unwrap();
        assert_eq!(info.season, Some(3));
        assert_eq!(info.episode, Some(6));
    }

    #[test]
    fn xmltv_ns_no_dot_returns_none() {
        assert!(parse_xmltv_ns("123").is_none());
    }

    #[test]
    fn xmltv_ns_empty_returns_none() {
        assert!(parse_xmltv_ns("").is_none());
        assert!(parse_xmltv_ns("  ").is_none());
    }

    #[test]
    fn xmltv_ns_all_empty_parts_returns_none() {
        // ".." — all three parts empty, nothing parseable
        assert!(parse_xmltv_ns("..").is_none());
    }

    #[test]
    fn xmltv_ns_two_parts_without_trailing_dot() {
        // "0.4" — season=1, episode=5 (no part section)
        let info = parse_xmltv_ns("0.4").unwrap();
        assert_eq!(info.season, Some(1));
        assert_eq!(info.episode, Some(5));
        assert_eq!(info.part, None);
    }

    #[test]
    fn xmltv_ns_part_without_denominator_is_none() {
        // "0.4.2" — bare part number without /total → part is None per C++ logic
        let info = parse_xmltv_ns("0.4.2").unwrap();
        assert_eq!(info.season, Some(1));
        assert_eq!(info.episode, Some(5));
        assert_eq!(info.part, None);
        assert_eq!(info.part_count, None);
    }

    #[test]
    fn onscreen_season_episode() {
        let info = parse_onscreen("S01E05").unwrap();
        assert_eq!(info.season, Some(1));
        assert_eq!(info.episode, Some(5));
    }

    #[test]
    fn onscreen_episode_only() {
        let info = parse_onscreen("E12").unwrap();
        assert_eq!(info.season, None);
        assert_eq!(info.episode, Some(12));
    }

    #[test]
    fn onscreen_episode_with_ep_prefix() {
        let info = parse_onscreen("EP07").unwrap();
        assert_eq!(info.season, None);
        assert_eq!(info.episode, Some(7));
    }

    #[test]
    fn onscreen_with_spaces() {
        // "S 01 E 05" — spaces stripped → "S01E05"
        let info = parse_onscreen("S 01 E 05").unwrap();
        assert_eq!(info.season, Some(1));
        assert_eq!(info.episode, Some(5));
    }

    #[test]
    fn onscreen_with_dots_and_underscores() {
        // "S.01.E.05" → stripped → "S01E05"
        let info = parse_onscreen("S.01.E.05").unwrap();
        assert_eq!(info.season, Some(1));
        assert_eq!(info.episode, Some(5));
    }

    #[test]
    fn onscreen_with_x_separator() {
        // "S01xE05" → x stripped → "S01E05"
        let info = parse_onscreen("S01xE05").unwrap();
        assert_eq!(info.season, Some(1));
        assert_eq!(info.episode, Some(5));
    }

    #[test]
    fn onscreen_lowercase() {
        let info = parse_onscreen("s02e10").unwrap();
        assert_eq!(info.season, Some(2));
        assert_eq!(info.episode, Some(10));
    }

    #[test]
    fn onscreen_invalid_format_returns_none() {
        assert!(parse_onscreen("Season 1 Episode 5").is_none());
        assert!(parse_onscreen("12345").is_none());
        assert!(parse_onscreen("").is_none());
    }

    #[test]
    fn parse_episode_number_dispatches_xmltv_ns() {
        let info = parse_episode_number("0.4.2/3", "xmltv_ns").unwrap();
        assert_eq!(info.season, Some(1));
        assert_eq!(info.episode, Some(5));
    }

    #[test]
    fn parse_episode_number_dispatches_onscreen() {
        let info = parse_episode_number("S01E05", "onscreen").unwrap();
        assert_eq!(info.season, Some(1));
        assert_eq!(info.episode, Some(5));
    }

    #[test]
    fn parse_episode_number_unknown_system() {
        assert!(parse_episode_number("foo", "unknown").is_none());
    }
}
