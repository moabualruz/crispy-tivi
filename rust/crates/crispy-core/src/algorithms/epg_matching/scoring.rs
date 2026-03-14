//! Confidence-scored EPG matching with corroboration.

use std::collections::{HashMap, HashSet};

use crate::algorithms::epg_fuzzy::fuzzy_name_score;
use crate::algorithms::normalize::normalize_name;
use crate::models::{Channel, EpgEntry};

use super::types::{
    AUTO_APPLY_THRESHOLD, CORROBORATION_BOOST, EpgMatchCandidate, MatchStrategy, SUGGEST_THRESHOLD,
    scripts_compatible,
};

/// Match EPG entries to channels with confidence scoring.
///
/// Unlike `match_epg_to_channels()` which uses first-match-wins,
/// this function tries ALL strategies for each unique XMLTV
/// channel, collects matches with confidence scores, and applies
/// corroboration boost when multiple strategies agree.
///
/// Returns candidates sorted by confidence descending.
/// Only candidates with confidence >= 0.40 are included.
pub fn match_epg_with_confidence(
    entries: &[EpgEntry],
    channels: &[Channel],
    xmltv_display_names: &HashMap<String, String>,
) -> Vec<EpgMatchCandidate> {
    // Build lookup maps from channels.
    let mut tvg_id_exact_map: HashMap<&str, &str> = HashMap::new();
    let mut tvg_id_lower_map: HashMap<String, &str> = HashMap::new();
    let mut direct_ids: HashSet<&str> = HashSet::new();
    let mut name_exact_map: HashMap<String, &str> = HashMap::new();
    let mut name_norm_map: HashMap<String, &str> = HashMap::new();

    for ch in channels {
        if let Some(ref tvg) = ch.tvg_id {
            let tvg_trimmed = tvg.trim();
            if !tvg_trimmed.is_empty() {
                tvg_id_exact_map
                    .entry(tvg_trimmed)
                    .or_insert(ch.id.as_str());
                tvg_id_lower_map
                    .entry(tvg_trimmed.to_lowercase())
                    .or_insert(ch.id.as_str());
            }
        }
        direct_ids.insert(ch.id.as_str());
        let display = ch
            .tvg_name
            .as_deref()
            .filter(|n| !n.is_empty())
            .unwrap_or(ch.name.as_str());
        name_exact_map
            .entry(display.to_lowercase())
            .or_insert(ch.id.as_str());
        let norm = normalize_name(display);
        if !norm.is_empty() {
            name_norm_map.entry(norm).or_insert(ch.id.as_str());
        }
    }

    // Channel name lookup for CJK script guard.
    let channel_names: HashMap<&str, &str> = channels
        .iter()
        .map(|c| {
            let display = c
                .tvg_name
                .as_deref()
                .filter(|n| !n.is_empty())
                .unwrap_or(c.name.as_str());
            (c.id.as_str(), display)
        })
        .collect();

    // Channel display names for fuzzy matching.
    let channel_displays: Vec<(&str, &str)> = channels
        .iter()
        .map(|c| {
            let display = c
                .tvg_name
                .as_deref()
                .filter(|n| !n.is_empty())
                .unwrap_or(c.name.as_str());
            (c.id.as_str(), display)
        })
        .collect();

    // Collect unique XMLTV channel IDs with original forms
    // and sample titles for CJK check.
    let mut xmltv_info: HashMap<String, (String, String)> = HashMap::new();
    for entry in entries {
        let trimmed = entry.channel_id.trim().to_string();
        xmltv_info
            .entry(trimmed)
            .or_insert_with(|| (entry.channel_id.clone(), entry.title.clone()));
    }

    let mut candidates: Vec<EpgMatchCandidate> = Vec::new();

    for (xmltv_id, (xmltv_original, sample_title)) in &xmltv_info {
        // Track matches: internal_ch_id → Vec<(strategy, confidence)>.
        let mut matches: HashMap<String, Vec<(MatchStrategy, f64)>> = HashMap::new();

        // Look up XMLTV display name (used by strategies 4, 5, 7).
        let dn = xmltv_display_names
            .get(xmltv_original)
            .or_else(|| xmltv_display_names.get(xmltv_id));

        // Strategy 1: exact tvg_id.
        if let Some(&ch_id) = tvg_id_exact_map.get(xmltv_id.as_str()) {
            matches.entry(ch_id.to_string()).or_default().push((
                MatchStrategy::TvgIdExact,
                MatchStrategy::TvgIdExact.confidence(),
            ));
        }

        // Strategy 2: case-insensitive tvg_id.
        let lower = xmltv_id.to_lowercase();
        if let Some(&ch_id) = tvg_id_lower_map.get(&lower) {
            let strats = matches.entry(ch_id.to_string()).or_default();
            if !strats.iter().any(|(s, _)| *s == MatchStrategy::TvgIdLower) {
                strats.push((
                    MatchStrategy::TvgIdLower,
                    MatchStrategy::TvgIdLower.confidence(),
                ));
            }
        }

        // Strategy 3: direct channel.id match.
        if direct_ids.contains(xmltv_id.as_str()) {
            matches.entry(xmltv_id.clone()).or_default().push((
                MatchStrategy::DirectId,
                MatchStrategy::DirectId.confidence(),
            ));
        }

        // Strategy 4: XMLTV display-name → channel name.
        if let Some(display_name) = dn {
            let dn_lower = display_name.trim().to_lowercase();
            if let Some(&ch_id) = name_exact_map.get(&dn_lower) {
                matches.entry(ch_id.to_string()).or_default().push((
                    MatchStrategy::XmltvName,
                    MatchStrategy::XmltvName.confidence(),
                ));
            }
        }

        // Strategy 5: normalized display-name.
        if let Some(display_name) = dn {
            let dn_norm = normalize_name(display_name);
            if !dn_norm.is_empty()
                && let Some(&ch_id) = name_norm_map.get(&dn_norm)
            {
                let strats = matches.entry(ch_id.to_string()).or_default();
                if !strats.iter().any(|(s, _)| *s == MatchStrategy::NormName) {
                    strats.push((
                        MatchStrategy::NormName,
                        MatchStrategy::NormName.confidence(),
                    ));
                }
            }
        }

        // Strategy 6: XMLTV channel ID used as name.
        let id_lower = xmltv_id.to_lowercase();
        if let Some(&ch_id) = name_exact_map.get(&id_lower) {
            let strats = matches.entry(ch_id.to_string()).or_default();
            if !strats.iter().any(|(s, _)| *s == MatchStrategy::NameAsId) {
                strats.push((
                    MatchStrategy::NameAsId,
                    MatchStrategy::NameAsId.confidence(),
                ));
            }
        } else {
            let id_norm = normalize_name(xmltv_id);
            if !id_norm.is_empty()
                && let Some(&ch_id) = name_norm_map.get(&id_norm)
            {
                let strats = matches.entry(ch_id.to_string()).or_default();
                if !strats.iter().any(|(s, _)| *s == MatchStrategy::NameAsId) {
                    strats.push((
                        MatchStrategy::NameAsId,
                        MatchStrategy::NameAsId.confidence(),
                    ));
                }
            }
        }

        // Strategy 7: fuzzy matching.
        // Only run when no high-confidence match found (optimization).
        let best_so_far = matches
            .values()
            .flat_map(|v| v.iter().map(|(_, c)| *c))
            .fold(0.0_f64, f64::max);

        if best_so_far < MatchStrategy::NormName.confidence() {
            let query = dn.map(String::as_str).unwrap_or(xmltv_id.as_str());
            for &(ch_id, ch_display) in &channel_displays {
                let score = fuzzy_name_score(query, ch_display);
                if score >= SUGGEST_THRESHOLD {
                    matches
                        .entry(ch_id.to_string())
                        .or_default()
                        .push((MatchStrategy::Fuzzy, score));
                }
            }
        }

        // Build candidates from matches.
        for (ch_id, strats) in &matches {
            let best_conf = strats.iter().map(|(_, c)| *c).fold(0.0_f64, f64::max);

            // Corroboration: +0.05 per additional strategy.
            let boost = ((strats.len() as f64 - 1.0) * CORROBORATION_BOOST).max(0.0);
            let confidence = (best_conf + boost).min(1.0);

            if confidence < SUGGEST_THRESHOLD {
                continue;
            }

            // CJK script guard.
            if let Some(&ch_name) = channel_names.get(ch_id.as_str())
                && !scripts_compatible(ch_name, sample_title)
            {
                continue;
            }

            candidates.push(EpgMatchCandidate {
                channel_id: ch_id.clone(),
                epg_channel_id: xmltv_id.clone(),
                confidence,
                strategies: strats.iter().map(|(s, _)| *s).collect(),
                auto_apply: confidence >= AUTO_APPLY_THRESHOLD,
            });
        }
    }

    // Sort by confidence descending.
    candidates.sort_by(|a, b| {
        b.confidence
            .partial_cmp(&a.confidence)
            .unwrap_or(std::cmp::Ordering::Equal)
    });

    candidates
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::algorithms::epg_matching::tests::{make_channel, make_epg};

    #[test]
    fn confidence_exact_tvg_id_returns_high() {
        let channels = vec![make_channel("c1", "BBC One", Some("bbc1"), None)];
        let entries = vec![make_epg("bbc1", "News")];
        let display = HashMap::new();

        let candidates = match_epg_with_confidence(&entries, &channels, &display);

        assert_eq!(candidates.len(), 1);
        assert_eq!(candidates[0].channel_id, "c1");
        assert!(candidates[0].confidence >= 0.95);
        assert!(candidates[0].auto_apply);
        assert!(
            candidates[0]
                .strategies
                .contains(&MatchStrategy::TvgIdExact)
        );
    }

    #[test]
    fn confidence_corroboration_boosts_score() {
        let channels = vec![make_channel("c1", "CNN", Some("cnn"), None)];
        let entries = vec![make_epg("cnn", "News")];
        let mut display = HashMap::new();
        display.insert("cnn".to_string(), "CNN".to_string());

        let candidates = match_epg_with_confidence(&entries, &channels, &display);

        assert_eq!(candidates.len(), 1);
        assert!(candidates[0].strategies.len() > 1);
        assert_eq!(candidates[0].confidence, 1.0);
    }

    #[test]
    fn confidence_unmatched_returns_empty() {
        let channels = vec![make_channel("c1", "BBC One", Some("bbc1"), None)];
        let entries = vec![make_epg("totally_unknown", "Mystery")];
        let display = HashMap::new();

        let candidates = match_epg_with_confidence(&entries, &channels, &display);

        assert!(candidates.is_empty());
    }

    #[test]
    fn confidence_cjk_guard_rejects_mismatch() {
        let channels = vec![make_channel("c1", "Be inSPORTS 2 4K", Some("365941"), None)];
        let entries = vec![make_epg("365941", "アルペンスキーFIS W杯25/26")];
        let display = HashMap::new();

        let candidates = match_epg_with_confidence(&entries, &channels, &display);

        assert!(candidates.is_empty());
    }

    #[test]
    fn confidence_sorted_descending() {
        let channels = vec![
            make_channel("c1", "BBC One", Some("bbc1"), None),
            make_channel("c2", "CNN", None, None),
        ];
        let entries = vec![make_epg("bbc1", "News"), make_epg("CNN", "Report")];
        let display = HashMap::new();

        let candidates = match_epg_with_confidence(&entries, &channels, &display);

        for i in 1..candidates.len() {
            assert!(candidates[i - 1].confidence >= candidates[i].confidence);
        }
    }

    #[test]
    fn confidence_below_suggest_excluded() {
        let channels = vec![make_channel("c1", "XYZ Very Unique Name", None, None)];
        let entries = vec![make_epg("abc123", "Completely Different")];
        let display = HashMap::new();

        let candidates = match_epg_with_confidence(&entries, &channels, &display);

        assert!(candidates.is_empty());
    }

    #[test]
    fn confidence_name_as_id_auto_apply() {
        let channels = vec![make_channel("c1", "Sky Sports", None, None)];
        let entries = vec![make_epg("Sky Sports", "Football")];
        let display = HashMap::new();

        let candidates = match_epg_with_confidence(&entries, &channels, &display);

        assert!(!candidates.is_empty());
        assert!(candidates[0].auto_apply);
    }

    #[test]
    fn confidence_display_name_match() {
        let channels = vec![make_channel("c1", "National Geographic", None, None)];
        let entries = vec![make_epg("natgeo.xml", "Wild")];
        let mut display = HashMap::new();
        display.insert("natgeo.xml".to_string(), "National Geographic".to_string());

        let candidates = match_epg_with_confidence(&entries, &channels, &display);

        assert!(!candidates.is_empty());
        assert_eq!(candidates[0].channel_id, "c1");
        assert!(candidates[0].strategies.contains(&MatchStrategy::XmltvName));
    }

    #[test]
    fn confidence_multiple_xmltv_channels_independent() {
        let channels = vec![
            make_channel("c1", "BBC", Some("bbc1"), None),
            make_channel("c2", "CNN", Some("cnn1"), None),
        ];
        let entries = vec![make_epg("bbc1", "News"), make_epg("cnn1", "Report")];
        let display = HashMap::new();

        let candidates = match_epg_with_confidence(&entries, &channels, &display);

        assert_eq!(candidates.len(), 2);
        let ch_ids: HashSet<&str> = candidates.iter().map(|c| c.channel_id.as_str()).collect();
        assert!(ch_ids.contains("c1"));
        assert!(ch_ids.contains("c2"));
    }

    #[test]
    fn confidence_empty_entries_returns_empty() {
        let channels = vec![make_channel("c1", "BBC", Some("bbc1"), None)];
        let entries: Vec<EpgEntry> = vec![];
        let display = HashMap::new();

        let candidates = match_epg_with_confidence(&entries, &channels, &display);

        assert!(candidates.is_empty());
    }
}
