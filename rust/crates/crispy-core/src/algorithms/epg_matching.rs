//! EPG-to-channel matching using 6 strategies with
//! script-mismatch filtering.
//!
//! Ports the matching logic from Dart
//! `playlist_sync_service.dart` (lines 630-803).

use std::collections::{HashMap, HashSet};

use serde::{Deserialize, Serialize};

use crate::models::{Channel, EpgEntry};

use super::normalize::normalize_name;

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

/// Check if text contains CJK characters (Chinese/Japanese/Korean).
fn contains_cjk(text: &str) -> bool {
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
fn scripts_compatible(channel_name: &str, title: &str) -> bool {
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

/// Result of EPG matching: entries grouped by internal
/// channel ID, plus match statistics.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EpgMatchResult {
    /// `internal_channel_id` -> matched EPG entries.
    pub entries: HashMap<String, Vec<EpgEntry>>,
    /// Per-strategy hit counts.
    pub stats: EpgMatchStats,
}

/// Internal enum for tracking which strategy matched.
#[derive(Debug, Clone, Copy)]
enum MatchStrategy {
    TvgIdExact,
    TvgIdLower,
    DirectId,
    XmltvName,
    NormName,
    NameAsId,
}

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
        let xmltv_id_original = &entry.channel_id;
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

/// Filter upcoming programs on favorite channels within a time window.
///
/// For each favorite channel, resolves its EPG key (`tvg_id` if present, else `id`),
/// then looks up entries in `epg_map_json`. Programs whose `startTime` is strictly
/// after `now_ms` and strictly before `now_ms + window_minutes * 60_000` are included.
///
/// Results are sorted by `startTime` ascending, capped at `limit`.
///
/// * `epg_map_json`   — JSON object `{ "channelKey": [{ "title", "startTime" (ms),
///   "endTime" (ms), ... }] }`
/// * `favorites_json` — JSON array of channel objects with `id`, `tvg_id`, `name`,
///   `stream_url`, `logo_url`.
/// * `now_ms`         — current time as epoch-ms.
/// * `window_minutes` — how many minutes ahead to look (default 120).
/// * `limit`          — maximum results to return (default 20).
///
/// Returns JSON array of `{ channel_id, channel_name, logo_url, stream_url, title,
///   start_time, end_time, description, category }`.
pub fn filter_upcoming_programs(
    epg_map_json: &str,
    favorites_json: &str,
    now_ms: i64,
    window_minutes: u32,
    limit: usize,
) -> String {
    use serde_json::Value;

    let epg_map: serde_json::Map<String, Value> = serde_json::from_str::<Value>(epg_map_json)
        .ok()
        .and_then(|v| {
            if let Value::Object(m) = v {
                Some(m)
            } else {
                None
            }
        })
        .unwrap_or_default();

    let favorites: Vec<Value> = serde_json::from_str::<Value>(favorites_json)
        .ok()
        .and_then(|v| {
            if let Value::Array(a) = v {
                Some(a)
            } else {
                None
            }
        })
        .unwrap_or_default();

    let cutoff_ms = now_ms + (window_minutes as i64) * 60_000;
    let mut results: Vec<Value> = Vec::new();

    for ch in &favorites {
        let ch_id = ch.get("id").and_then(|v| v.as_str()).unwrap_or("");
        let tvg_id = ch
            .get("tvg_id")
            .and_then(|v| v.as_str())
            .filter(|s| !s.is_empty());
        let epg_key = tvg_id.unwrap_or(ch_id);

        let entries = match epg_map.get(epg_key).and_then(|v| v.as_array()) {
            Some(arr) => arr,
            None => continue,
        };

        let ch_name = ch.get("name").and_then(|v| v.as_str()).unwrap_or("");
        let logo_url = ch.get("logo_url").and_then(|v| v.as_str());
        let stream_url = ch.get("stream_url").and_then(|v| v.as_str()).unwrap_or("");

        for entry in entries {
            let start = entry.get("startTime").and_then(|v| v.as_i64()).unwrap_or(0);
            if start > now_ms && start < cutoff_ms {
                let mut result = serde_json::json!({
                    "channel_id": ch_id,
                    "channel_name": ch_name,
                    "stream_url": stream_url,
                    "title": entry.get("title").and_then(|v| v.as_str()).unwrap_or(""),
                    "start_time": start,
                    "end_time": entry.get("endTime").and_then(|v| v.as_i64()).unwrap_or(0),
                });
                if let Some(url) = logo_url {
                    result["logo_url"] = Value::String(url.to_string());
                }
                if let Some(desc) = entry.get("description").and_then(|v| v.as_str()) {
                    result["description"] = Value::String(desc.to_string());
                }
                if let Some(cat) = entry.get("category").and_then(|v| v.as_str()) {
                    result["category"] = Value::String(cat.to_string());
                }
                results.push(result);
            }
        }
    }

    // Sort by start_time ascending.
    results.sort_by_key(|r| r.get("start_time").and_then(|v| v.as_i64()).unwrap_or(0));
    results.truncate(limit);

    serde_json::to_string(&results).unwrap_or_else(|_| "[]".to_string())
}

/// Merges new EPG entries into existing entries, deduplicating by `startTime`.
///
/// Both inputs are JSON objects:
/// `{ "channelId": [ { "startTime": epochMs, ... }, ... ] }`
///
/// For each channel:
/// - Keep all existing entries.
/// - Add new entries whose `startTime` is not already present in existing.
/// - Sort merged list by `startTime` ascending.
///
/// Returns the merged JSON object. Invalid JSON inputs return `"{}"`.
pub fn merge_epg_window(existing_json: &str, new_json: &str) -> String {
    use serde_json::{Map, Value};

    let parse = |s: &str| -> Map<String, Value> {
        serde_json::from_str::<Value>(s)
            .ok()
            .and_then(|v| {
                if let Value::Object(m) = v {
                    Some(m)
                } else {
                    None
                }
            })
            .unwrap_or_default()
    };

    let existing = parse(existing_json);
    let new = parse(new_json);

    // Collect all channel keys from both maps.
    let all_keys: std::collections::BTreeSet<String> =
        existing.keys().chain(new.keys()).cloned().collect();

    let mut result = Map::new();

    for key in all_keys {
        let existing_entries = existing
            .get(&key)
            .and_then(Value::as_array)
            .map(Vec::as_slice)
            .unwrap_or(&[]);
        let new_entries = new
            .get(&key)
            .and_then(Value::as_array)
            .map(Vec::as_slice)
            .unwrap_or(&[]);

        // Collect existing startTime values as a set.
        let existing_starts: std::collections::HashSet<i64> = existing_entries
            .iter()
            .filter_map(|e| e.get("startTime").and_then(Value::as_i64))
            .collect();

        // Start with all existing entries.
        let mut merged: Vec<Value> = existing_entries.to_vec();

        // Append new entries that aren't already present.
        for entry in new_entries {
            let start = entry.get("startTime").and_then(Value::as_i64);
            let is_dup = start.is_some_and(|s| existing_starts.contains(&s));
            if !is_dup {
                merged.push(entry.clone());
            }
        }

        // Sort by startTime ascending.
        merged.sort_by_key(|e| e.get("startTime").and_then(Value::as_i64).unwrap_or(0));

        result.insert(key, Value::Array(merged));
    }

    serde_json::to_string(&Value::Object(result)).unwrap_or_else(|_| "{}".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::algorithms::normalize::EPG_FORMAT;
    use chrono::NaiveDateTime;

    fn make_channel(id: &str, name: &str, tvg_id: Option<&str>, tvg_name: Option<&str>) -> Channel {
        Channel {
            id: id.to_string(),
            name: name.to_string(),
            stream_url: format!("http://example.com/{id}"),
            number: None,
            channel_group: None,
            logo_url: None,
            tvg_id: tvg_id.map(String::from),
            tvg_name: tvg_name.map(String::from),
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
        }
    }

    fn make_epg(channel_id: &str, title: &str) -> EpgEntry {
        let start = NaiveDateTime::parse_from_str("2024-02-16 15:00:00", EPG_FORMAT).unwrap();
        let end = NaiveDateTime::parse_from_str("2024-02-16 16:00:00", EPG_FORMAT).unwrap();
        EpgEntry {
            channel_id: channel_id.to_string(),
            title: title.to_string(),
            start_time: start,
            end_time: end,
            description: None,
            category: None,
            icon_url: None,
            source_id: None,
        }
    }

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
        // Display name maps to a slightly different form
        // that normalizes the same.
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
        // XMLTV ID literally equals the channel name.
        let entries = vec![make_epg("Sky Sports", "Football")];
        let display = HashMap::new();

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.name_as_id, 1);
    }

    // ── Additional matching strategy tests ──────────

    #[test]
    fn match_by_tvg_id_exact() {
        // tvg_id matches EPG channel ID exactly.
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
        // "BBC.One" matches "bbc.one" via lowercase.
        let channels = vec![make_channel("ch1", "BBC One", Some("BBC.One"), None)];
        let entries = vec![make_epg("bbc.one", "EastEnders")];
        let display = HashMap::new();

        let result = match_epg_to_channels(&entries, &channels, &display);

        // Not exact (case differs) — hits strategy 2.
        assert_eq!(result.stats.tvg_id_exact, 0);
        assert_eq!(result.stats.tvg_id_lower, 1);
        assert!(result.entries.contains_key("ch1"));
    }

    #[test]
    fn match_by_channel_id_direct() {
        // channel.id matches EPG channel_id directly.
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
        // XMLTV display-name maps to channel name.
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
        // Normalized names match despite punctuation/spacing.
        // Channel name: "Fox News (US)" normalizes to "fox news us"
        // XMLTV display: "FOX  NEWS - US" normalizes to "fox news us"
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
        // Channel with no EPG match gets empty entries.
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
        // Each channel matched independently.
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
        // No EPG entries → empty map returned.
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
        // Japanese EPG matched by tvg_id to a Latin-named
        // channel should be rejected.
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
        // CJK channel + CJK title → compatible.
        let channels = vec![make_channel("c1", "J SPORTS 2 テレビ", Some("js2"), None)];
        let entries = vec![make_epg("js2", "アルペンスキーFIS W杯")];
        let display = HashMap::new();

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.tvg_id_exact, 1);
        assert!(result.entries.contains_key("c1"));
    }

    #[test]
    fn accepts_latin_title_on_cjk_channel() {
        // CJK channel + Latin title → compatible (common
        // for romanized sport/movie names).
        let channels = vec![make_channel("c1", "NHK 総合テレビ", Some("nhk1"), None)];
        let entries = vec![make_epg("nhk1", "SUPER GT FESTIVAL 2026")];
        let display = HashMap::new();

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.tvg_id_exact, 1);
        assert!(result.entries.contains_key("c1"));
    }

    #[test]
    fn rejects_cjk_on_latin_via_display_name_strategy() {
        // Script guard applies to ALL strategies, not just tvg_id.
        let channels = vec![make_channel("c1", "Al Jazeera Sports", None, None)];
        let entries = vec![make_epg("aj.xml", "ダーツ The Perfect 9")];
        let mut display = HashMap::new();
        display.insert("aj.xml".to_string(), "Al Jazeera Sports".to_string());

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.unmatched, 1);
    }

    #[test]
    fn fuzzy_matching_removed() {
        // Strategy 7 (fuzzy substring) is removed.
        // An entry that only matches via substring should
        // remain unmatched.
        let channels = vec![make_channel("c1", "Al Jazeera English", None, None)];
        let entries = vec![make_epg("random_id_xyz", "News Today")];
        let display = HashMap::new();

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.unmatched, 1);
        assert_eq!(result.stats.fuzzy_name, 0);
    }

    #[test]
    fn fuzzy_name_stat_always_zero() {
        // fuzzy_name field is kept for backwards compat
        // but should always be 0.
        let channels = vec![make_channel("c1", "BBC One", Some("bbc1"), None)];
        let entries = vec![make_epg("bbc1", "News")];
        let display = HashMap::new();

        let result = match_epg_to_channels(&entries, &channels, &display);

        assert_eq!(result.stats.fuzzy_name, 0);
    }

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

    // ── merge_epg_window ────────────────────────────

    #[test]
    fn merge_epg_window_empty_existing_returns_new() {
        let existing = "{}";
        let new = r#"{"ch1": [{"startTime": 1000, "title": "News"}]}"#;
        let merged = merge_epg_window(existing, new);
        let v: serde_json::Value = serde_json::from_str(&merged).unwrap();
        let ch1 = v.get("ch1").and_then(|v| v.as_array()).unwrap();
        assert_eq!(ch1.len(), 1);
        assert_eq!(ch1[0].get("startTime").and_then(|v| v.as_i64()), Some(1000),);
    }

    #[test]
    fn merge_epg_window_non_empty_existing_empty_new_returns_existing() {
        let existing = r#"{"ch1": [{"startTime": 2000, "title": "Sports"}]}"#;
        let new = "{}";
        let merged = merge_epg_window(existing, new);
        let v: serde_json::Value = serde_json::from_str(&merged).unwrap();
        let ch1 = v.get("ch1").and_then(|v| v.as_array()).unwrap();
        assert_eq!(ch1.len(), 1);
        assert_eq!(ch1[0].get("title").and_then(|v| v.as_str()), Some("Sports"),);
    }

    #[test]
    fn merge_epg_window_both_empty_returns_empty_object() {
        let merged = merge_epg_window("{}", "{}");
        let v: serde_json::Value = serde_json::from_str(&merged).unwrap();
        assert!(v.as_object().unwrap().is_empty());
    }

    #[test]
    fn merge_epg_window_same_channel_deduped_by_start_time() {
        // Overlapping entries: new has one duplicate + one new.
        let existing = r#"{"ch1": [
            {"startTime": 1000, "title": "A"},
            {"startTime": 2000, "title": "B"}
        ]}"#;
        let new = r#"{"ch1": [
            {"startTime": 2000, "title": "B_dup"},
            {"startTime": 3000, "title": "C"}
        ]}"#;
        let merged = merge_epg_window(existing, new);
        let v: serde_json::Value = serde_json::from_str(&merged).unwrap();
        let ch1 = v.get("ch1").and_then(|v| v.as_array()).unwrap();
        // startTime 2000 deduplicated → 3 entries total.
        assert_eq!(ch1.len(), 3);
        // Existing "B" kept (not replaced by "B_dup").
        let titles: Vec<&str> = ch1
            .iter()
            .filter_map(|e| e.get("title").and_then(|v| v.as_str()))
            .collect();
        assert!(titles.contains(&"B"));
        assert!(!titles.contains(&"B_dup"));
    }

    #[test]
    fn merge_epg_window_non_overlapping_all_included_sorted() {
        // No overlap — all entries included and sorted by startTime.
        let existing = r#"{"ch1": [
            {"startTime": 3000, "title": "C"},
            {"startTime": 1000, "title": "A"}
        ]}"#;
        let new = r#"{"ch1": [
            {"startTime": 2000, "title": "B"}
        ]}"#;
        let merged = merge_epg_window(existing, new);
        let v: serde_json::Value = serde_json::from_str(&merged).unwrap();
        let ch1 = v.get("ch1").and_then(|v| v.as_array()).unwrap();
        assert_eq!(ch1.len(), 3);
        // Verify sort order.
        let starts: Vec<i64> = ch1
            .iter()
            .filter_map(|e| e.get("startTime").and_then(|v| v.as_i64()))
            .collect();
        assert_eq!(starts, vec![1000, 2000, 3000]);
    }

    #[test]
    fn merge_epg_window_multiple_channels_merged_independently() {
        let existing = r#"{"ch1": [{"startTime": 1000, "title": "A"}]}"#;
        let new = r#"{"ch2": [{"startTime": 2000, "title": "B"}]}"#;
        let merged = merge_epg_window(existing, new);
        let v: serde_json::Value = serde_json::from_str(&merged).unwrap();
        let obj = v.as_object().unwrap();
        assert!(obj.contains_key("ch1"));
        assert!(obj.contains_key("ch2"));
        assert_eq!(obj.get("ch1").and_then(|v| v.as_array()).unwrap().len(), 1,);
        assert_eq!(obj.get("ch2").and_then(|v| v.as_array()).unwrap().len(), 1,);
    }

    // ── filter_upcoming_programs ───────────────────

    #[test]
    fn upcoming_programs_within_window_returned() {
        let epg_map = r#"{"bbc1": [
            {"title": "News", "startTime": 5000, "endTime": 6000},
            {"title": "Sport", "startTime": 8000, "endTime": 9000}
        ]}"#;
        let favorites = r#"[{"id": "c1", "tvg_id": "bbc1", "name": "BBC One", "stream_url": "http://bbc.com"}]"#;
        // now=1000, window=1 min (60_000ms), so cutoff=61_000.
        // Both programs start within (1000, 61_000).
        let result = filter_upcoming_programs(epg_map, favorites, 1000, 1, 20);
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        let arr = v.as_array().unwrap();
        assert_eq!(arr.len(), 2);
        assert_eq!(arr[0]["title"], "News");
        assert_eq!(arr[0]["channel_id"], "c1");
        assert_eq!(arr[0]["channel_name"], "BBC One");
        assert_eq!(arr[1]["title"], "Sport");
    }

    #[test]
    fn upcoming_programs_outside_window_excluded() {
        let epg_map = r#"{"ch1": [
            {"title": "Early", "startTime": 500, "endTime": 1500},
            {"title": "Future", "startTime": 200000, "endTime": 300000}
        ]}"#;
        let favorites = r#"[{"id": "ch1", "name": "CH1", "stream_url": "http://ch1.com"}]"#;
        // now=1000, window=1 min → cutoff=61_000.
        // "Early" starts at 500 (before now) → excluded.
        // "Future" starts at 200_000 (after cutoff) → excluded.
        let result = filter_upcoming_programs(epg_map, favorites, 1000, 1, 20);
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert!(v.as_array().unwrap().is_empty());
    }

    #[test]
    fn upcoming_programs_uses_tvg_id_over_channel_id() {
        let epg_map = r#"{"tvg-key": [
            {"title": "Show", "startTime": 5000, "endTime": 6000}
        ]}"#;
        // tvg_id "tvg-key" should be used, not "c1".
        let favorites = r#"[{"id": "c1", "tvg_id": "tvg-key", "name": "My CH", "stream_url": ""}]"#;
        let result = filter_upcoming_programs(epg_map, favorites, 1000, 10, 20);
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert_eq!(v.as_array().unwrap().len(), 1);
    }

    #[test]
    fn upcoming_programs_falls_back_to_channel_id_when_no_tvg_id() {
        let epg_map = r#"{"c1": [
            {"title": "Show", "startTime": 5000, "endTime": 6000}
        ]}"#;
        // No tvg_id → uses "c1".
        let favorites = r#"[{"id": "c1", "name": "My CH", "stream_url": ""}]"#;
        let result = filter_upcoming_programs(epg_map, favorites, 1000, 10, 20);
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert_eq!(v.as_array().unwrap().len(), 1);
    }

    #[test]
    fn upcoming_programs_respects_limit() {
        // 5 programs in window, limit 2.
        let entries: Vec<String> = (1..=5)
            .map(|i| {
                format!(
                    r#"{{"title":"Show {i}","startTime":{},"endTime":{}}}"#,
                    1000 + i * 100,
                    1000 + i * 100 + 50
                )
            })
            .collect();
        let epg_map = format!(r#"{{"ch1":[{}]}}"#, entries.join(","));
        let favorites = r#"[{"id": "ch1", "name": "CH1", "stream_url": ""}]"#;
        let result = filter_upcoming_programs(&epg_map, favorites, 1000, 10, 2);
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert_eq!(v.as_array().unwrap().len(), 2);
    }

    #[test]
    fn upcoming_programs_sorted_by_start_time() {
        let epg_map = r#"{"ch1": [
            {"title": "Late", "startTime": 9000, "endTime": 10000},
            {"title": "Early", "startTime": 2000, "endTime": 3000}
        ]}"#;
        let favorites = r#"[{"id": "ch1", "name": "CH1", "stream_url": ""}]"#;
        let result = filter_upcoming_programs(epg_map, favorites, 1000, 10, 20);
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        let arr = v.as_array().unwrap();
        assert_eq!(arr[0]["title"], "Early");
        assert_eq!(arr[1]["title"], "Late");
    }

    #[test]
    fn upcoming_programs_empty_favorites_returns_empty() {
        let epg_map = r#"{"ch1": [{"title": "A", "startTime": 5000, "endTime": 6000}]}"#;
        let result = filter_upcoming_programs(epg_map, "[]", 1000, 10, 20);
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert!(v.as_array().unwrap().is_empty());
    }
}
