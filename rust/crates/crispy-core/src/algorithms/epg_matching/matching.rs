//! Core EPG-to-channel matching using 6 strategies with
//! script-mismatch filtering.

use std::collections::{HashMap, HashSet};

use crate::models::{Channel, EpgEntry};

use super::types::{EpgMatchResult, EpgMatchStats, MatchStrategy, scripts_compatible};
use crate::algorithms::normalize::normalize_name;

/// Match EPG entries to internal channels using 6
/// strategies tried in priority order.
///
/// # Arguments
///
/// * `entries` - EPG entries to match (each has a
///   `channel_id` from the XMLTV source).
/// * `channels` - Internal channels to match against.
/// * `xmltv_display_names` - Map of XMLTV channel ID to
///   its display name.
pub fn match_epg_to_channels(
    entries: &[EpgEntry],
    channels: &[Channel],
    xmltv_display_names: &HashMap<String, String>,
) -> EpgMatchResult {
    // Build lookup maps from channels.
    let mut tvg_id_exact: HashMap<&str, &str> = HashMap::new();
    let mut tvg_id_lower: HashMap<String, &str> = HashMap::new();
    let mut direct_ids: HashSet<&str> = HashSet::new();
    let mut name_exact: HashMap<String, &str> = HashMap::new();
    let mut name_norm: HashMap<String, &str> = HashMap::new();

    for ch in channels {
        // tvg_id maps (exact and lowercase).
        if let Some(ref tvg) = ch.tvg_id {
            let tvg_trimmed = tvg.trim();
            if !tvg_trimmed.is_empty() {
                tvg_id_exact.entry(tvg_trimmed).or_insert(ch.id.as_str());
                tvg_id_lower
                    .entry(tvg_trimmed.to_lowercase())
                    .or_insert(ch.id.as_str());
            }
        }

        // Direct ID set.
        direct_ids.insert(ch.id.as_str());

        // Name maps: prefer tvg_name, fall back to name.
        let display = ch
            .tvg_name
            .as_deref()
            .filter(|n| !n.is_empty())
            .unwrap_or(ch.name.as_str());

        name_exact
            .entry(display.to_lowercase())
            .or_insert(ch.id.as_str());

        let norm = normalize_name(display);
        if !norm.is_empty() {
            name_norm.entry(norm).or_insert(ch.id.as_str());
        }
    }

    // Channel name lookup for script-mismatch guard.
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

    let mut result_entries: HashMap<String, Vec<EpgEntry>> = HashMap::new();
    let mut stats = EpgMatchStats::default();

    for entry in entries {
        let xmltv_id_original = &entry.epg_channel_id;
        let xmltv_id = xmltv_id_original.trim();

        // Try strategies 1-6 in priority order.
        // Each strategy resolves to (ch_id, stat_field).
        let matched_ch: Option<(&str, MatchStrategy)> = None
            // Strategy 1: exact tvg_id.
            .or_else(|| {
                tvg_id_exact
                    .get(xmltv_id)
                    .map(|&id| (id, MatchStrategy::TvgIdExact))
            })
            // Strategy 2: case-insensitive tvg_id.
            .or_else(|| {
                let lower = xmltv_id.to_lowercase();
                tvg_id_lower
                    .get(&lower)
                    .map(|&id| (id, MatchStrategy::TvgIdLower))
            })
            // Strategy 3: direct channel.id match.
            .or_else(|| {
                direct_ids
                    .contains(xmltv_id)
                    .then_some((xmltv_id, MatchStrategy::DirectId))
            })
            // Strategy 4: XMLTV display-name -> channel name.
            .or_else(|| {
                xmltv_display_names.get(xmltv_id_original).and_then(|dn| {
                    let dn_lower = dn.trim().to_lowercase();
                    name_exact
                        .get(&dn_lower)
                        .map(|&id| (id, MatchStrategy::XmltvName))
                })
            })
            // Strategy 5: normalized display-name.
            .or_else(|| {
                xmltv_display_names.get(xmltv_id_original).and_then(|dn| {
                    let dn_norm = normalize_name(dn);
                    if dn_norm.is_empty() {
                        return None;
                    }
                    name_norm
                        .get(&dn_norm)
                        .map(|&id| (id, MatchStrategy::NormName))
                })
            })
            // Strategy 6: XMLTV channel ID as name.
            .or_else(|| {
                let id_lower = xmltv_id.to_lowercase();
                name_exact
                    .get(&id_lower)
                    .map(|&id| (id, MatchStrategy::NameAsId))
                    .or_else(|| {
                        let id_norm = normalize_name(xmltv_id);
                        if id_norm.is_empty() {
                            return None;
                        }
                        name_norm
                            .get(&id_norm)
                            .map(|&id| (id, MatchStrategy::NameAsId))
                    })
            });

        if let Some((ch_id, strategy)) = matched_ch {
            // Script-mismatch guard: reject CJK titles on
            // non-CJK channels (and vice versa).
            if let Some(&ch_name) = channel_names.get(ch_id)
                && !scripts_compatible(ch_name, &entry.title)
            {
                stats.unmatched += 1;
                continue;
            }

            result_entries
                .entry(ch_id.to_string())
                .or_default()
                .push(entry.clone());
            match strategy {
                MatchStrategy::TvgIdExact => stats.tvg_id_exact += 1,
                MatchStrategy::TvgIdLower => stats.tvg_id_lower += 1,
                MatchStrategy::DirectId => stats.direct_id += 1,
                MatchStrategy::XmltvName => stats.xmltv_name += 1,
                MatchStrategy::NormName => stats.norm_name += 1,
                MatchStrategy::NameAsId => stats.name_as_id += 1,
                MatchStrategy::Fuzzy => stats.fuzzy_name += 1,
            }
            continue;
        }

        // No match found.
        stats.unmatched += 1;
    }

    EpgMatchResult {
        entries: result_entries,
        stats,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::algorithms::epg_matching::tests::{make_channel, make_epg};

    #[test]
    fn matches_by_exact_tvg_id() {
        let channels = vec![make_channel("c1", "BBC One", Some("bbc1"), None)];
        let entries = vec![make_epg("bbc1", "News")];
        let display = HashMap::new();

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.tvg_id_exact, 1);
        assert!(result.entries.contains_key("c1"));
    }

    #[test]
    fn matches_by_lowercase_tvg_id() {
        let channels = vec![make_channel("c1", "BBC One", Some("BBC1"), None)];
        let entries = vec![make_epg("bbc1", "News")];
        let display = HashMap::new();

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.tvg_id_lower, 1);
    }

    #[test]
    fn matches_by_direct_id() {
        let channels = vec![make_channel("xmltv_ch1", "CNN", None, None)];
        let entries = vec![make_epg("xmltv_ch1", "Breaking")];
        let display = HashMap::new();

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.direct_id, 1);
    }

    #[test]
    fn matches_by_xmltv_display_name() {
        let channels = vec![make_channel("c1", "CNN International", None, None)];
        let entries = vec![make_epg("cnn.us", "Report")];
        let mut display = HashMap::new();
        display.insert("cnn.us".to_string(), "CNN International".to_string());

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.xmltv_name, 1);
    }

    #[test]
    fn matches_by_normalized_name() {
        let channels = vec![make_channel("c1", "HBO (HD)", None, None)];
        let entries = vec![make_epg("hbo.hd", "Movie")];
        let mut display = HashMap::new();
        display.insert("hbo.hd".to_string(), "HBO  HD".to_string());

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.norm_name, 1);
    }

    #[test]
    fn tracks_unmatched() {
        let channels = vec![make_channel("c1", "BBC", Some("bbc1"), None)];
        let entries = vec![make_epg("unknown_id", "Mystery")];
        let display = HashMap::new();

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.unmatched, 1);
        assert!(result.entries.is_empty());
    }

    #[test]
    fn matches_xmltv_id_as_channel_name() {
        let channels = vec![make_channel("c1", "Sky Sports", None, None)];
        let entries = vec![make_epg("Sky Sports", "Football")];
        let display = HashMap::new();

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.name_as_id, 1);
    }

    #[test]
    fn match_by_tvg_id_exact() {
        let channels = vec![make_channel("ch1", "ESPN", Some("espn.us"), None)];
        let entries = vec![make_epg("espn.us", "SportsCenter")];
        let display = HashMap::new();

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.tvg_id_exact, 1);
        assert_eq!(result.stats.unmatched, 0);
        let matched = result.entries.get("ch1").unwrap();
        assert_eq!(matched.len(), 1);
        assert_eq!(matched[0].title, "SportsCenter");
    }

    #[test]
    fn match_by_tvg_id_case_insensitive() {
        let channels = vec![make_channel("ch1", "BBC One", Some("BBC.One"), None)];
        let entries = vec![make_epg("bbc.one", "EastEnders")];
        let display = HashMap::new();

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.tvg_id_exact, 0);
        assert_eq!(result.stats.tvg_id_lower, 1);
        assert!(result.entries.contains_key("ch1"));
    }

    #[test]
    fn match_by_channel_id_direct() {
        let channels = vec![make_channel("epg_ch_42", "Discovery", None, None)];
        let entries = vec![make_epg("epg_ch_42", "Planet Earth")];
        let display = HashMap::new();

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.direct_id, 1);
        let matched = result.entries.get("epg_ch_42").unwrap();
        assert_eq!(matched[0].title, "Planet Earth");
    }

    #[test]
    fn match_by_display_name() {
        let channels = vec![make_channel("c5", "National Geographic", None, None)];
        let entries = vec![make_epg("natgeo.xml", "Wild")];
        let mut display = HashMap::new();
        display.insert("natgeo.xml".to_string(), "National Geographic".to_string());

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.xmltv_name, 1);
        assert!(result.entries.contains_key("c5"));
    }

    #[test]
    fn match_by_normalized_name() {
        let channels = vec![make_channel("c7", "Fox News (US)", None, None)];
        let entries = vec![make_epg("fox.xml", "Alert")];
        let mut display = HashMap::new();
        display.insert("fox.xml".to_string(), "FOX  NEWS - US".to_string());

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.norm_name, 1);
        assert!(result.entries.contains_key("c7"));
    }

    #[test]
    fn no_match_returns_empty() {
        let channels = vec![make_channel("c1", "Obscure TV", Some("obs.tv"), None)];
        let entries = vec![make_epg("totally_different", "Show")];
        let display = HashMap::new();

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.unmatched, 1);
        assert!(result.entries.is_empty());
        assert!(!result.entries.contains_key("c1"));
    }

    #[test]
    fn multiple_channels_independent() {
        let channels = vec![
            make_channel("c1", "BBC", Some("bbc1"), None),
            make_channel("c2", "CNN", Some("cnn1"), None),
            make_channel("c3", "Fox", Some("fox1"), None),
        ];
        let entries = vec![
            make_epg("bbc1", "News at Ten"),
            make_epg("cnn1", "Anderson Cooper"),
            make_epg("fox1", "Hannity"),
        ];
        let display = HashMap::new();

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.tvg_id_exact, 3);
        assert_eq!(result.stats.unmatched, 0);
        assert_eq!(result.entries.len(), 3);
        assert!(result.entries.contains_key("c1"));
        assert!(result.entries.contains_key("c2"));
        assert!(result.entries.contains_key("c3"));
    }

    #[test]
    fn empty_entries_empty_result() {
        let channels = vec![make_channel("c1", "BBC", Some("bbc1"), None)];
        let entries: Vec<EpgEntry> = vec![];
        let display = HashMap::new();

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert!(result.entries.is_empty());
        assert_eq!(result.stats.tvg_id_exact, 0);
        assert_eq!(result.stats.unmatched, 0);
    }

    // ── Script-mismatch guard tests ─────────────────

    #[test]
    fn rejects_cjk_title_on_latin_channel_via_tvg_id() {
        let channels = vec![make_channel("c1", "Be inSPORTS 2 4K", Some("365941"), None)];
        let entries = vec![make_epg("365941", "アルペンスキーFIS W杯25/26")];
        let display = HashMap::new();

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.unmatched, 1);
        assert!(!result.entries.contains_key("c1"));
    }

    #[test]
    fn accepts_latin_title_on_latin_channel() {
        let channels = vec![make_channel("c1", "Be inSPORTS 2 4K", Some("365941"), None)];
        let entries = vec![make_epg("365941", "UEFA Champions League")];
        let display = HashMap::new();

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.tvg_id_exact, 1);
        assert!(result.entries.contains_key("c1"));
    }

    #[test]
    fn accepts_cjk_title_on_cjk_channel() {
        let channels = vec![make_channel("c1", "J SPORTS 2 テレビ", Some("js2"), None)];
        let entries = vec![make_epg("js2", "アルペンスキーFIS W杯")];
        let display = HashMap::new();

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.tvg_id_exact, 1);
        assert!(result.entries.contains_key("c1"));
    }

    #[test]
    fn accepts_latin_title_on_cjk_channel() {
        let channels = vec![make_channel("c1", "NHK 総合テレビ", Some("nhk1"), None)];
        let entries = vec![make_epg("nhk1", "SUPER GT FESTIVAL 2026")];
        let display = HashMap::new();

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.tvg_id_exact, 1);
        assert!(result.entries.contains_key("c1"));
    }

    #[test]
    fn rejects_cjk_on_latin_via_display_name_strategy() {
        let channels = vec![make_channel("c1", "Al Jazeera Sports", None, None)];
        let entries = vec![make_epg("aj.xml", "ダーツ The Perfect 9")];
        let mut display = HashMap::new();
        display.insert("aj.xml".to_string(), "Al Jazeera Sports".to_string());

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.unmatched, 1);
    }

    #[test]
    fn fuzzy_matching_removed() {
        let channels = vec![make_channel("c1", "Al Jazeera English", None, None)];
        let entries = vec![make_epg("random_id_xyz", "News Today")];
        let display = HashMap::new();

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.unmatched, 1);
        assert_eq!(result.stats.fuzzy_name, 0);
    }

    #[test]
    fn fuzzy_name_stat_always_zero() {
        let channels = vec![make_channel("c1", "BBC One", Some("bbc1"), None)];
        let entries = vec![make_epg("bbc1", "News")];
        let display = HashMap::new();

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.fuzzy_name, 0);
    }
}
