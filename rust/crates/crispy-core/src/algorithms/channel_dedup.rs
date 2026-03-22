//! Channel deduplication across IPTV sources.
//!
//! Four levels (applied in priority order):
//! Level 1 — tvg-id exact match
//! Level 2 — tvg-id normalised (lowercase + trim)
//! Level 3 — channel name fuzzy Jaro-Winkler > 85%
//! Level 4 — user manual override (caller responsibility — stored externally)

use std::collections::HashMap;

use serde::{Deserialize, Serialize};
use strsim::jaro_winkler;

use crate::models::Channel;

// ── Thresholds ────────────────────────────────────────────

const FUZZY_NAME_THRESHOLD: f64 = 0.85;

// ── Quality suffix stripping ──────────────────────────────

/// Suffixes stripped from channel names before comparison.
/// Ordered longest-first so " Ultra HD" matches before " HD".
const QUALITY_SUFFIXES: &[&str] = &[
    " ultra hd",
    " uhd",
    " 4k",
    " fhd",
    " hd",
    " sd",
    " h.265",
    " hevc",
];

/// Normalise a channel name for comparison:
/// 1. Lowercase + trim
/// 2. Strip quality suffixes (longest first)
/// 3. Strip country codes in square brackets, e.g. " [UK]"
/// 4. Remove non-alphanumeric characters
/// 5. Collapse whitespace
pub fn normalize_channel_name(name: &str) -> String {
    let mut s = name.to_lowercase();
    s = s.trim().to_string();

    // Strip quality suffixes (apply repeatedly until stable).
    loop {
        let before = s.clone();
        for &suffix in QUALITY_SUFFIXES {
            if let Some(stripped) = s.strip_suffix(suffix) {
                s = stripped.trim().to_string();
                break; // restart loop after any match
            }
        }
        if s == before {
            break;
        }
    }

    // Strip bracketed country codes: " [UK]", " [US]", etc.
    let s2: String = {
        let mut out = String::with_capacity(s.len());
        let mut depth = 0usize;
        for c in s.chars() {
            match c {
                '[' => depth += 1,
                ']' => {
                    depth = depth.saturating_sub(1);
                }
                _ if depth == 0 => out.push(c),
                _ => {}
            }
        }
        out
    };

    // Keep alphanumeric + space only, collapse whitespace.
    let filtered: String = s2
        .chars()
        .map(|c| {
            if c.is_alphanumeric() || c == ' ' {
                c
            } else {
                ' '
            }
        })
        .collect();

    filtered.split_whitespace().collect::<Vec<_>>().join(" ")
}

/// Normalise a tvg-id for level-2 matching.
pub fn normalize_tvg_id(id: &str) -> String {
    id.trim().to_lowercase()
}

// ── Result types ──────────────────────────────────────────

/// Which matching level produced this group.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum ChannelMatchLevel {
    /// Level 1: tvg-id exact match.
    TvgIdExact,
    /// Level 2: tvg-id normalised match.
    TvgIdNormalised,
    /// Level 3: channel name fuzzy match.
    NameFuzzy,
    /// Level 4: user manual override.
    ManualOverride,
}

/// A group of channels considered duplicates.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChannelDedupGroup {
    /// ID of the canonical (kept) channel.
    pub canonical_id: String,
    /// IDs of duplicate channels.
    pub duplicate_ids: Vec<String>,
    /// Which level produced this group.
    pub level: ChannelMatchLevel,
    /// Similarity score (1.0 for exact matches).
    pub score: f64,
}

// ── Public API ────────────────────────────────────────────

/// Detect duplicate channels using levels 1-3.
///
/// Returns one [`ChannelDedupGroup`] per duplicate group.
/// Channels that appear in a higher-level group are not
/// re-evaluated at lower levels.
pub fn find_channel_duplicates(channels: &[Channel]) -> Vec<ChannelDedupGroup> {
    let mut groups: Vec<ChannelDedupGroup> = Vec::new();
    let mut claimed: Vec<bool> = vec![false; channels.len()];

    // ── Level 1: tvg-id exact ─────────────────────────────
    let mut tvg_exact: HashMap<String, Vec<usize>> = HashMap::new();
    for (i, ch) in channels.iter().enumerate() {
        if let Some(ref tid) = ch.tvg_id
            && !tid.is_empty()
        {
            tvg_exact.entry(tid.clone()).or_default().push(i);
        }
    }
    for indices in tvg_exact.values() {
        if indices.len() < 2 {
            continue;
        }
        let canonical = indices[0];
        let dupes: Vec<String> = indices[1..]
            .iter()
            .map(|&i| channels[i].id.clone())
            .collect();
        for &i in indices {
            claimed[i] = true;
        }
        groups.push(ChannelDedupGroup {
            canonical_id: channels[canonical].id.clone(),
            duplicate_ids: dupes,
            level: ChannelMatchLevel::TvgIdExact,
            score: 1.0,
        });
    }

    // ── Level 2: tvg-id normalised ────────────────────────
    let mut tvg_norm: HashMap<String, Vec<usize>> = HashMap::new();
    for (i, ch) in channels.iter().enumerate() {
        if claimed[i] {
            continue;
        }
        if let Some(ref tid) = ch.tvg_id {
            let norm = normalize_tvg_id(tid);
            if !norm.is_empty() {
                tvg_norm.entry(norm).or_default().push(i);
            }
        }
    }
    for indices in tvg_norm.values() {
        if indices.len() < 2 {
            continue;
        }
        let canonical = indices[0];
        let dupes: Vec<String> = indices[1..]
            .iter()
            .map(|&i| channels[i].id.clone())
            .collect();
        for &i in indices {
            claimed[i] = true;
        }
        groups.push(ChannelDedupGroup {
            canonical_id: channels[canonical].id.clone(),
            duplicate_ids: dupes,
            level: ChannelMatchLevel::TvgIdNormalised,
            score: 1.0,
        });
    }

    // ── Level 3: channel name fuzzy ───────────────────────
    let unclaimed: Vec<usize> = (0..channels.len()).filter(|&i| !claimed[i]).collect();
    let mut l3_claimed: Vec<bool> = vec![false; unclaimed.len()];

    for (a_pos, &a_idx) in unclaimed.iter().enumerate() {
        if l3_claimed[a_pos] {
            continue;
        }
        let norm_a = normalize_channel_name(&channels[a_idx].name);
        if norm_a.is_empty() {
            continue;
        }
        let mut group_indices: Vec<usize> = vec![a_idx];
        let mut best_score = 0.0f64;

        for (b_pos, &b_idx) in unclaimed.iter().enumerate().skip(a_pos + 1) {
            if l3_claimed[b_pos] {
                continue;
            }
            let norm_b = normalize_channel_name(&channels[b_idx].name);
            let score = jaro_winkler(&norm_a, &norm_b);
            if score > FUZZY_NAME_THRESHOLD {
                group_indices.push(b_idx);
                l3_claimed[b_pos] = true;
                best_score = best_score.max(score);
            }
        }

        if group_indices.len() > 1 {
            l3_claimed[a_pos] = true;
            let dupes: Vec<String> = group_indices[1..]
                .iter()
                .map(|&i| channels[i].id.clone())
                .collect();
            groups.push(ChannelDedupGroup {
                canonical_id: channels[group_indices[0]].id.clone(),
                duplicate_ids: dupes,
                level: ChannelMatchLevel::NameFuzzy,
                score: best_score,
            });
        }
    }

    groups
}

// ── Tests ─────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn ch(id: &str, name: &str, tvg_id: Option<&str>) -> Channel {
        Channel {
            id: id.to_string(),
            name: name.to_string(),
            stream_url: format!("http://example.com/{id}"),
            number: None,
            channel_group: None,
            logo_url: None,
            tvg_id: tvg_id.map(|s| s.to_string()),
            tvg_name: None,
            is_favorite: false,
            user_agent: None,
            has_catchup: false,
            catchup_days: 0,
            catchup_type: None,
            catchup_source: None,
            resolution: None,
            source_id: None,
            added_at: None,
            updated_at: None,
            is_247: false,
            tvg_shift: None,
            tvg_language: None,
            tvg_country: None,
            parent_code: None,
            is_radio: false,
            tvg_rec: None,
            is_adult: false,
            custom_sid: None,
            direct_source: None,
            ..Default::default()
        }
    }

    // ── normalize_channel_name ────────────────────────────

    #[test]
    fn test_strip_hd_suffix() {
        assert_eq!(normalize_channel_name("BBC One HD"), "bbc one");
    }

    #[test]
    fn test_strip_fhd_suffix() {
        assert_eq!(normalize_channel_name("Sky Sports FHD"), "sky sports");
    }

    #[test]
    fn test_strip_uhd_suffix() {
        assert_eq!(normalize_channel_name("Discovery UHD"), "discovery");
    }

    #[test]
    fn test_strip_ultra_hd_suffix() {
        assert_eq!(
            normalize_channel_name("National Geographic Ultra HD"),
            "national geographic"
        );
    }

    #[test]
    fn test_strip_4k_suffix() {
        assert_eq!(normalize_channel_name("Netflix 4K"), "netflix");
    }

    #[test]
    fn test_strip_hevc_suffix() {
        assert_eq!(normalize_channel_name("Eurosport HEVC"), "eurosport");
    }

    #[test]
    fn test_strip_country_bracket() {
        assert_eq!(normalize_channel_name("BBC One [UK]"), "bbc one");
    }

    #[test]
    fn test_strip_quality_and_country() {
        // "[US]" stripped first via bracket removal, then " HD" suffix.
        // After lowercasing: "cnn [us] hd" → strip bracket → "cnn  hd" → strip hd → "cnn"
        let result = normalize_channel_name("CNN [US] HD");
        assert_eq!(result, "cnn");
    }

    #[test]
    fn test_empty_name() {
        assert_eq!(normalize_channel_name(""), "");
    }

    // ── Level 1: tvg-id exact ─────────────────────────────

    #[test]
    fn test_level1_tvg_id_exact() {
        let channels = vec![
            ch("a", "BBC One HD", Some("bbc.one.uk")),
            ch("b", "BBC One SD", Some("bbc.one.uk")),
        ];
        let groups = find_channel_duplicates(&channels);
        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].level, ChannelMatchLevel::TvgIdExact);
        assert_eq!(groups[0].canonical_id, "a");
        assert_eq!(groups[0].duplicate_ids, vec!["b"]);
    }

    // ── Level 2: tvg-id normalised ────────────────────────

    #[test]
    fn test_level2_tvg_id_normalised() {
        let channels = vec![
            ch("a", "Fox News", Some("Fox.News.US")),
            ch("b", "Fox News HD", Some("fox.news.us")),
        ];
        let groups = find_channel_duplicates(&channels);
        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].level, ChannelMatchLevel::TvgIdNormalised);
    }

    // ── Level 3: name fuzzy ───────────────────────────────

    #[test]
    fn test_level3_name_fuzzy() {
        let channels = vec![
            ch("a", "Sky Sports 1 HD", None),
            ch("b", "Sky Sports 1 FHD", None),
        ];
        let groups = find_channel_duplicates(&channels);
        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].level, ChannelMatchLevel::NameFuzzy);
        assert!(groups[0].score > FUZZY_NAME_THRESHOLD);
    }

    #[test]
    fn test_level3_no_match_dissimilar_names() {
        let channels = vec![ch("a", "CNN", None), ch("b", "ESPN", None)];
        let groups = find_channel_duplicates(&channels);
        assert!(groups.is_empty());
    }

    // ── Priority: level1 claims before level2/3 ───────────

    #[test]
    fn test_level1_claims_prevent_lower_levels() {
        let channels = vec![
            ch("a", "BBC One HD", Some("bbc.one")),
            ch("b", "BBC One SD", Some("bbc.one")),
            ch("c", "BBC One FHD", Some("bbc.one")),
        ];
        let groups = find_channel_duplicates(&channels);
        // All three share tvg-id → one group, level 1.
        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].level, ChannelMatchLevel::TvgIdExact);
        assert_eq!(groups[0].duplicate_ids.len(), 2);
    }

    // ── Edge cases ────────────────────────────────────────

    #[test]
    fn test_empty_input() {
        assert!(find_channel_duplicates(&[]).is_empty());
    }

    #[test]
    fn test_single_channel_no_duplicates() {
        let channels = vec![ch("a", "BBC One", Some("bbc.one"))];
        assert!(find_channel_duplicates(&channels).is_empty());
    }

    #[test]
    fn test_no_tvg_id_falls_to_level3() {
        let channels = vec![
            ch("a", "Eurosport HD", None),
            ch("b", "Eurosport FHD", None),
        ];
        let groups = find_channel_duplicates(&channels);
        // After stripping "HD"/"FHD", both normalise to "eurosport".
        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].level, ChannelMatchLevel::NameFuzzy);
    }

    // ── Proptest fuzzing ──────────────────────────────────

    use proptest::prelude::*;

    proptest! {
        /// Dedup never loses channels: all output ids are a subset of input ids.
        #[test]
        fn prop_dedup_output_ids_are_subset_of_input(count in 1usize..20) {
            let channels: Vec<Channel> = (0..count)
                .map(|i| ch(&format!("id-{i}"), &format!("UniqueChannel{i:04}"), None))
                .collect();
            let input_ids: std::collections::HashSet<String> =
                channels.iter().map(|c| c.id.clone()).collect();
            let groups = find_channel_duplicates(&channels);
            for g in &groups {
                prop_assert!(input_ids.contains(&g.canonical_id));
                for did in &g.duplicate_ids {
                    prop_assert!(input_ids.contains(did));
                }
            }
        }

        /// Channels with the same tvg_id always end up in the same group.
        #[test]
        fn prop_same_tvg_id_always_groups(tvg_id in "[a-z]{5,12}") {
            let channels = vec![
                ch("a", "Channel HD", Some(&tvg_id)),
                ch("b", "Channel SD", Some(&tvg_id)),
            ];
            let groups = find_channel_duplicates(&channels);
            prop_assert_eq!(groups.len(), 1, "same tvg_id must produce exactly one group");
            prop_assert_eq!(groups[0].level.clone(), ChannelMatchLevel::TvgIdExact);
        }

        /// Channels with distinct long names (no tvg_id) and disjoint character
        /// sets do not get grouped together.
        #[test]
        fn prop_distinct_names_no_tvg_id_dont_group(
            name_a in "[a-f]{10,15}",
            name_b in "[s-z]{10,15}",
        ) {
            let channels = vec![
                ch("a", &name_a, None),
                ch("b", &name_b, None),
            ];
            let groups = find_channel_duplicates(&channels);
            for g in &groups {
                let has_a = g.canonical_id == "a" || g.duplicate_ids.contains(&"a".to_string());
                let has_b = g.canonical_id == "b" || g.duplicate_ids.contains(&"b".to_string());
                prop_assert!(
                    !(has_a && has_b),
                    "name_a={name_a:?} and name_b={name_b:?} must not be grouped"
                );
            }
        }

        /// normalize_channel_name is idempotent on realistic channel names.
        #[test]
        fn prop_normalize_channel_name_is_idempotent(name in "[A-Za-z0-9 ]{1,40}") {
            let once = normalize_channel_name(&name);
            let twice = normalize_channel_name(&once);
            prop_assert_eq!(once, twice);
        }
    }
}
