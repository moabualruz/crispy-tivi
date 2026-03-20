//! Three-tier duplicate detection for VOD movies.
//!
//! Tier 1: Exact external-ID match              → confidence ≥ 0.99 (auto-merge)
//! Tier 2: Exact title + year after normalise   → confidence 0.90–0.95 (auto-merge)
//! Tier 3: Jaro-Winkler > 0.92 on normalised    → confidence < 0.92 (flag for review)
//! Below 0.85                                   → no match

use std::collections::HashMap;

use serde::{Deserialize, Serialize};
use strsim::jaro_winkler;

use crate::models::VodItem;

use super::title_normalize::normalize_title;

// ── Confidence thresholds ─────────────────────────────────

const TIER1_CONFIDENCE: f64 = 0.99;
const TIER2_CONFIDENCE_MAX: f64 = 0.95;
const TIER2_CONFIDENCE_MIN: f64 = 0.90;
const TIER3_THRESHOLD: f64 = 0.92;
const NO_MATCH_THRESHOLD: f64 = 0.85;

// ── Public types ──────────────────────────────────────────

/// Which deduplication method produced this result.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum DedupMethod {
    /// Tier 1: identical external IDs.
    ExternalIdExact,
    /// Tier 2: identical normalised title + year.
    TitleYearExact,
    /// Tier 3: Jaro-Winkler fuzzy title match above threshold.
    FuzzyTitle,
}

/// A single deduplication result grouping one or more matched items.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DedupResult {
    /// ID of the canonical (kept) item.
    pub canonical_id: String,
    /// IDs of the items considered duplicates of the canonical.
    pub matched_ids: Vec<String>,
    /// Similarity confidence in [0.0, 1.0].
    pub confidence: f64,
    /// Which tier produced this match.
    pub method: DedupMethod,
}

// ── Internal helpers ──────────────────────────────────────

/// Key for title-year grouping.
#[derive(Hash, PartialEq, Eq)]
struct TitleYearKey {
    norm_title: String,
    year: Option<i32>,
}

impl TitleYearKey {
    fn from(item: &VodItem) -> Self {
        Self {
            norm_title: normalize_title(&item.name),
            year: item.year,
        }
    }
}

// ── Public API ────────────────────────────────────────────

/// Scan `items` for duplicates using the three-tier strategy.
///
/// Returns one [`DedupResult`] per duplicate group found.
/// Items with no match are not included in the output.
pub fn find_duplicates(items: &[VodItem]) -> Vec<DedupResult> {
    let mut results: Vec<DedupResult> = Vec::new();
    // Track which items have already been placed in a group.
    let mut claimed: Vec<bool> = vec![false; items.len()];

    // ── Tier 1: Exact external-ID match ──────────────────
    // external_id = source_id combined with name as a proxy (no explicit
    // external_id field on VodItem — use (source_id, name) composite key
    // when source_id is Some, otherwise skip tier 1 for that item).
    let mut ext_id_map: HashMap<String, Vec<usize>> = HashMap::new();
    for (i, item) in items.iter().enumerate() {
        if let (Some(src), id) = (item.source_id.as_deref(), &item.id) {
            let key = format!("{src}:{id}");
            ext_id_map.entry(key).or_default().push(i);
        }
    }
    for indices in ext_id_map.values() {
        if indices.len() < 2 {
            continue;
        }
        let canonical_idx = indices[0];
        let matched: Vec<String> = indices[1..].iter().map(|&i| items[i].id.clone()).collect();
        for &i in indices {
            claimed[i] = true;
        }
        results.push(DedupResult {
            canonical_id: items[canonical_idx].id.clone(),
            matched_ids: matched,
            confidence: TIER1_CONFIDENCE,
            method: DedupMethod::ExternalIdExact,
        });
    }

    // ── Tier 2: Exact normalised title + year ─────────────
    let mut title_year_map: HashMap<TitleYearKey, Vec<usize>> = HashMap::new();
    for (i, item) in items.iter().enumerate() {
        if claimed[i] {
            continue;
        }
        let key = TitleYearKey::from(item);
        if !key.norm_title.is_empty() {
            title_year_map.entry(key).or_default().push(i);
        }
    }
    for indices in title_year_map.values() {
        if indices.len() < 2 {
            continue;
        }
        let canonical_idx = indices[0];
        let matched: Vec<String> = indices[1..].iter().map(|&i| items[i].id.clone()).collect();
        // Confidence scales with number of fields matching.
        let confidence = if items[canonical_idx].year.is_some() {
            TIER2_CONFIDENCE_MAX
        } else {
            TIER2_CONFIDENCE_MIN
        };
        for &i in indices {
            claimed[i] = true;
        }
        results.push(DedupResult {
            canonical_id: items[canonical_idx].id.clone(),
            matched_ids: matched,
            confidence,
            method: DedupMethod::TitleYearExact,
        });
    }

    // ── Tier 3: Jaro-Winkler fuzzy match ──────────────────
    // O(n²) over unclaimed items — acceptable for batch dedup.
    let unclaimed: Vec<usize> = (0..items.len()).filter(|&i| !claimed[i]).collect();
    let mut tier3_claimed: Vec<bool> = vec![false; unclaimed.len()];

    for (a_pos, &a_idx) in unclaimed.iter().enumerate() {
        if tier3_claimed[a_pos] {
            continue;
        }
        let norm_a = normalize_title(&items[a_idx].name);
        if norm_a.is_empty() {
            continue;
        }
        let mut group: Vec<usize> = vec![a_idx];
        let mut group_conf = 0.0f64;

        for (b_pos, &b_idx) in unclaimed.iter().enumerate().skip(a_pos + 1) {
            if tier3_claimed[b_pos] {
                continue;
            }
            let norm_b = normalize_title(&items[b_idx].name);
            let score = jaro_winkler(&norm_a, &norm_b);
            if score > TIER3_THRESHOLD {
                group.push(b_idx);
                tier3_claimed[b_pos] = true;
                group_conf = group_conf.max(score);
            }
        }

        if group.len() > 1 && group_conf >= NO_MATCH_THRESHOLD {
            tier3_claimed[a_pos] = true;
            let matched: Vec<String> = group[1..].iter().map(|&i| items[i].id.clone()).collect();
            results.push(DedupResult {
                canonical_id: items[group[0]].id.clone(),
                matched_ids: matched,
                confidence: group_conf,
                method: DedupMethod::FuzzyTitle,
            });
        }
    }

    results
}

// ── Tests ─────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn vod(id: &str, name: &str, year: Option<i32>, source_id: Option<&str>) -> VodItem {
        VodItem {
            id: id.to_string(),
            name: name.to_string(),
            stream_url: format!("http://example.com/{id}"),
            item_type: "movie".to_string(),
            poster_url: None,
            backdrop_url: None,
            description: None,
            rating: None,
            year,
            duration: None,
            category: None,
            series_id: None,
            season_number: None,
            episode_number: None,
            ext: None,
            is_favorite: false,
            added_at: None,
            updated_at: None,
            source_id: source_id.map(|s| s.to_string()),
        }
    }

    // ── Tier 1 ────────────────────────────────────────────

    #[test]
    fn test_tier1_exact_external_id() {
        let items = vec![
            vod("same-id", "Movie A", Some(2020), Some("src1")),
            vod("same-id", "Movie A", Some(2020), Some("src1")),
        ];
        let results = find_duplicates(&items);
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].method, DedupMethod::ExternalIdExact);
        assert!((results[0].confidence - 0.99).abs() < f64::EPSILON);
    }

    #[test]
    fn test_tier1_different_ids_no_match() {
        let items = vec![
            vod("id-1", "Movie A", Some(2020), Some("src1")),
            vod("id-2", "Movie B", Some(2021), Some("src1")),
        ];
        let results = find_duplicates(&items);
        assert!(results.is_empty());
    }

    // ── Tier 2 ────────────────────────────────────────────

    #[test]
    fn test_tier2_title_year_exact() {
        let items = vec![
            vod("a", "The Matrix", Some(1999), None),
            vod("b", "matrix, the", Some(1999), None),
        ];
        let results = find_duplicates(&items);
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].method, DedupMethod::TitleYearExact);
        assert!(results[0].confidence >= 0.90);
    }

    #[test]
    fn test_tier2_same_title_different_year_no_match() {
        let items = vec![
            vod("a", "Total Recall", Some(1990), None),
            vod("b", "Total Recall", Some(2012), None),
        ];
        let results = find_duplicates(&items);
        // Different year → NOT tier2. May fall through to tier3 if name is similar.
        // Assert no tier2 result.
        assert!(
            results
                .iter()
                .all(|r| r.method != DedupMethod::TitleYearExact)
        );
    }

    #[test]
    fn test_tier2_confidence_higher_with_year() {
        let items = vec![
            vod("a", "Inception", Some(2010), None),
            vod("b", "Inception", Some(2010), None),
        ];
        let results = find_duplicates(&items);
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].confidence, 0.95);
    }

    // ── Tier 3 ────────────────────────────────────────────

    #[test]
    fn test_tier3_fuzzy_match() {
        let items = vec![
            vod("a", "Spiderman Homecoming", None, None),
            vod("b", "Spider-Man: Homecoming", None, None),
        ];
        let results = find_duplicates(&items);
        // Should find a fuzzy match.
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].method, DedupMethod::FuzzyTitle);
    }

    #[test]
    fn test_tier3_no_match_below_threshold() {
        let items = vec![
            vod("a", "Alien", None, None),
            vod("b", "Predator", None, None),
        ];
        let results = find_duplicates(&items);
        assert!(results.is_empty());
    }

    // ── Edge cases ────────────────────────────────────────

    #[test]
    fn test_empty_input() {
        let results = find_duplicates(&[]);
        assert!(results.is_empty());
    }

    #[test]
    fn test_single_item_no_duplicates() {
        let items = vec![vod("a", "Avengers", Some(2012), None)];
        let results = find_duplicates(&items);
        assert!(results.is_empty());
    }

    #[test]
    fn test_empty_title_skipped() {
        let items = vec![vod("a", "", None, None), vod("b", "", None, None)];
        let results = find_duplicates(&items);
        // Empty normalised title — tier2 and tier3 skip them.
        assert!(
            results
                .iter()
                .all(|r| r.method != DedupMethod::TitleYearExact)
        );
    }

    #[test]
    fn test_unicode_titles_deduped() {
        let items = vec![
            vod("a", "東京物語", Some(1953), None),
            vod("b", "東京物語", Some(1953), None),
        ];
        let results = find_duplicates(&items);
        assert_eq!(results.len(), 1);
    }

    #[test]
    fn test_arabic_titles_deduped() {
        let items = vec![
            vod("a", "الرسالة", Some(1976), None),
            vod("b", "الرسالة", Some(1976), None),
        ];
        let results = find_duplicates(&items);
        assert_eq!(results.len(), 1);
    }

    // ── Proptest fuzzing ──────────────────────────────────

    use proptest::prelude::*;

    proptest! {
        /// Two items with identical title + year always land in the same group.
        #[test]
        fn prop_identical_title_year_always_groups(
            title in "[A-Za-z]{1,5}[A-Za-z ]{0,25}",
            year in 1900i32..2030,
        ) {
            let items = vec![
                vod("x", &title, Some(year), None),
                vod("y", &title, Some(year), None),
            ];
            let results = find_duplicates(&items);
            prop_assert!(!results.is_empty(), "identical title+year must produce at least one group");
            let total_matched: usize = results.iter().map(|r| r.matched_ids.len() + 1).sum();
            prop_assert_eq!(total_matched, 2);
        }

        /// Items with titles drawn from disjoint character sets rarely group.
        /// We only assert that the low-alpha group and the high-alpha group are not
        /// merged when the normalised titles are long enough to be distinct.
        #[test]
        fn prop_very_different_titles_dont_group(
            title_a in "[a-f]{10,15}",
            title_b in "[s-z]{10,15}",
        ) {
            let items = vec![
                vod("a", &title_a, None, None),
                vod("b", &title_b, None, None),
            ];
            let results = find_duplicates(&items);
            // If any group claims both ids, the test fails.
            for r in &results {
                let has_a = r.canonical_id == "a" || r.matched_ids.contains(&"a".to_string());
                let has_b = r.canonical_id == "b" || r.matched_ids.contains(&"b".to_string());
                prop_assert!(
                    !(has_a && has_b),
                    "title_a={title_a:?} and title_b={title_b:?} must not be grouped"
                );
            }
        }

        /// Dedup never loses items: total channels across all groups == input count
        /// (only when every item has a twin, but at minimum no item is dropped).
        #[test]
        fn prop_dedup_output_ids_are_subset_of_input(count in 1usize..15) {
            // Build `count` items each with a unique id and unique title.
            let items: Vec<VodItem> = (0..count)
                .map(|i| vod(&format!("id-{i}"), &format!("UniqueFilmTitle{i:04}"), Some(2000 + i as i32), None))
                .collect();
            let input_ids: std::collections::HashSet<String> =
                items.iter().map(|v| v.id.clone()).collect();
            let results = find_duplicates(&items);
            for r in &results {
                prop_assert!(input_ids.contains(&r.canonical_id));
                for mid in &r.matched_ids {
                    prop_assert!(input_ids.contains(mid));
                }
            }
        }
    }
}
