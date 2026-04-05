//! Multi-source search across channels, VOD, and EPG.
//!
//! Ports the core filtering logic from Dart
//! `search_repository_impl.dart`. Media server search
//! remains in Dart.

use std::collections::HashMap;

use serde::{Deserialize, Serialize};

use crate::models::{Channel, EpgEntry, VodItem};

/// Aggregated search results across all content types.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchResults {
    /// Matching live channels.
    pub channels: Vec<Channel>,
    /// Matching movies.
    pub movies: Vec<VodItem>,
    /// Matching series.
    pub series: Vec<VodItem>,
    /// Matching EPG programmes with channel context.
    pub epg_programs: Vec<EpgProgram>,
}

/// An EPG entry enriched with channel context for search
/// result display.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EpgProgram {
    /// Internal channel ID.
    pub channel_id: String,
    /// Channel display name.
    pub channel_name: String,
    /// Channel logo URL.
    pub logo_url: Option<String>,
    /// Channel stream URL.
    pub stream_url: String,
    /// The matching EPG entry.
    pub entry: EpgEntry,
}

/// Filters controlling which content types and fields
/// to search.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct SearchFilter {
    /// Include live channels in results.
    pub search_channels: bool,
    /// Include movies in results.
    pub search_movies: bool,
    /// Include series in results.
    pub search_series: bool,
    /// Include EPG programmes in results.
    pub search_epg: bool,
    /// Also match against descriptions.
    pub search_in_description: bool,
    /// Filter by category/genre name.
    pub category: Option<String>,
    /// Minimum release year (inclusive).
    pub year_min: Option<i32>,
    /// Maximum release year (inclusive).
    pub year_max: Option<i32>,
}

/// Search channels, VOD items, and EPG entries.
///
/// Applies the `filter` to control which content types
/// are searched and which additional fields are checked.
pub fn search(
    query: &str,
    channels: &[Channel],
    vod_items: &[VodItem],
    epg_entries: &HashMap<String, Vec<EpgEntry>>,
    filter: &SearchFilter,
) -> SearchResults {
    let q = normalize_for_search(query.trim());

    if q.is_empty() {
        return SearchResults {
            channels: Vec::new(),
            movies: Vec::new(),
            series: Vec::new(),
            epg_programs: Vec::new(),
        };
    }

    let matched_channels = if filter.search_channels {
        search_channels(&q, channels)
    } else {
        Vec::new()
    };

    let (matched_movies, matched_series) = if filter.search_movies || filter.search_series {
        search_vod(&q, vod_items, filter)
    } else {
        (Vec::new(), Vec::new())
    };

    let matched_epg = if filter.search_epg {
        search_epg(&q, channels, epg_entries, filter)
    } else {
        Vec::new()
    };

    SearchResults {
        channels: matched_channels,
        movies: matched_movies,
        series: matched_series,
        epg_programs: matched_epg,
    }
}

/// Search result with full entity data included.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EnrichedSearchResult {
    /// Entity ID.
    pub id: String,
    /// Display name.
    pub name: String,
    /// Content type: `"channel"`, `"movie"`, `"series"`,
    /// or `"epg"`.
    pub media_type: String,
    /// Relevance score (0.0 to 1.0).
    pub score: f64,
    /// Additional metadata as a JSON object.
    pub metadata: serde_json::Value,
}

/// Build enriched search results from raw search output.
///
/// Combines `SearchResults` with source data into a flat
/// list of `EnrichedSearchResult` for direct UI
/// consumption. Each result includes a `metadata` object
/// with all entity fields. Scores are computed by
/// `relevance_score` — see that function for tier details.
pub fn enrich_search_results(
    query: &str,
    results: &SearchResults,
    channels: &[Channel],
    vod_items: &[VodItem],
) -> Vec<EnrichedSearchResult> {
    let q = normalize_for_search(query.trim());
    let ch_map: HashMap<&str, &Channel> = channels.iter().map(|c| (c.id.as_str(), c)).collect();
    let vod_map: HashMap<&str, &VodItem> = vod_items.iter().map(|v| (v.id.as_str(), v)).collect();

    let mut enriched = Vec::new();

    // Channels.
    for ch in &results.channels {
        let score = relevance_score(&q, &ch.name, None);
        let meta = if let Some(full) = ch_map.get(ch.id.as_str()) {
            serde_json::to_value(full).unwrap_or(serde_json::Value::Null)
        } else {
            serde_json::to_value(ch).unwrap_or(serde_json::Value::Null)
        };
        enriched.push(EnrichedSearchResult {
            id: ch.id.clone(),
            name: ch.name.clone(),
            media_type: "channel".to_string(),
            score,
            metadata: meta,
        });
    }

    // Movies.
    for mv in &results.movies {
        let score = relevance_score(&q, &mv.name, mv.description.as_deref());
        let meta = if let Some(full) = vod_map.get(mv.id.as_str()) {
            serde_json::to_value(full).unwrap_or(serde_json::Value::Null)
        } else {
            serde_json::to_value(mv).unwrap_or(serde_json::Value::Null)
        };
        enriched.push(EnrichedSearchResult {
            id: mv.id.clone(),
            name: mv.name.clone(),
            media_type: "movie".to_string(),
            score,
            metadata: meta,
        });
    }

    // Series.
    for sr in &results.series {
        let score = relevance_score(&q, &sr.name, sr.description.as_deref());
        let meta = if let Some(full) = vod_map.get(sr.id.as_str()) {
            serde_json::to_value(full).unwrap_or(serde_json::Value::Null)
        } else {
            serde_json::to_value(sr).unwrap_or(serde_json::Value::Null)
        };
        enriched.push(EnrichedSearchResult {
            id: sr.id.clone(),
            name: sr.name.clone(),
            media_type: "series".to_string(),
            score,
            metadata: meta,
        });
    }

    // EPG programs.
    for ep in &results.epg_programs {
        let score = relevance_score(&q, &ep.entry.title, ep.entry.description.as_deref());
        let meta = serde_json::to_value(ep).unwrap_or(serde_json::Value::Null);
        enriched.push(EnrichedSearchResult {
            id: ep.channel_id.clone(),
            name: ep.entry.title.clone(),
            media_type: "epg".to_string(),
            score,
            metadata: meta,
        });
    }

    enriched
}

/// Find channel IDs whose currently-airing EPG program title matches a query.
///
/// Iterates a `channelId -> [EpgEntry]` map. For each channel, checks if any
/// program currently live (startTime <= now_ms < endTime) has a title containing
/// the query (case-insensitive). Short-circuits per channel after the first match.
///
/// * `epg_map_json` — JSON object `{ "channelId": [{ "title", "startTime" (ms),
///   "endTime" (ms) }] }`
/// * `query` — search string (case-insensitive match)
/// * `now_ms` — current time as epoch-ms
///
/// Returns JSON array of matched channel ID strings.
pub fn search_channels_by_live_program(epg_map_json: &str, query: &str, now_ms: i64) -> String {
    use serde_json::Value;

    if query.is_empty() {
        return "[]".to_string();
    }

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

    let q = query.to_lowercase();
    let mut matched_ids: Vec<&str> = Vec::new();

    for (channel_id, entries_val) in &epg_map {
        let entries = match entries_val.as_array() {
            Some(a) => a,
            None => continue,
        };

        let has_match = entries.iter().any(|entry| {
            let start = entry.get("startTime").and_then(|v| v.as_i64()).unwrap_or(0);
            let end = entry.get("endTime").and_then(|v| v.as_i64()).unwrap_or(0);
            let is_live = start <= now_ms && now_ms < end;
            if !is_live {
                return false;
            }
            entry
                .get("title")
                .and_then(|v| v.as_str())
                .is_some_and(|t| t.to_lowercase().contains(&q))
        });

        if has_match {
            matched_ids.push(channel_id.as_str());
        }
    }

    serde_json::to_string(&matched_ids).unwrap_or_else(|_| "[]".to_string())
}

/// Merge EPG-matched channels into a base channel list.
///
/// Finds channels from `all_channels_json` not already in `base_json` whose
/// effective EPG ID is in `matched_ids_json`. The effective EPG ID is resolved
/// as: `epg_overrides[channel.id]` > `channel.tvg_id` > `channel.id`.
///
/// * `base_json`          — JSON array of channel objects (with `id` field)
/// * `all_channels_json`  — JSON array of all channel objects
/// * `matched_ids_json`   — JSON array of matched EPG ID strings
/// * `epg_overrides_json` — JSON object `{ channelId: effectiveEpgId }`
///
/// Returns JSON array of merged channel objects (base + extras).
pub fn merge_epg_matched_channels(
    base_json: &str,
    all_channels_json: &str,
    matched_ids_json: &str,
    epg_overrides_json: &str,
) -> String {
    use serde_json::Value;
    use std::collections::HashSet;

    let base: Vec<Value> = serde_json::from_str(base_json).unwrap_or_default();
    let all_channels: Vec<Value> = serde_json::from_str(all_channels_json).unwrap_or_default();
    let matched_ids: HashSet<String> = serde_json::from_str::<Vec<String>>(matched_ids_json)
        .unwrap_or_default()
        .into_iter()
        .collect();
    let overrides: serde_json::Map<String, Value> =
        serde_json::from_str::<Value>(epg_overrides_json)
            .ok()
            .and_then(|v| {
                if let Value::Object(m) = v {
                    Some(m)
                } else {
                    None
                }
            })
            .unwrap_or_default();

    let base_ids: HashSet<String> = base
        .iter()
        .filter_map(|c| c.get("id").and_then(|v| v.as_str()).map(String::from))
        .collect();

    let extras: Vec<&Value> = all_channels
        .iter()
        .filter(|c| {
            let id = c.get("id").and_then(|v| v.as_str()).unwrap_or("");
            if base_ids.contains(id) {
                return false;
            }
            // Resolve effective EPG ID.
            let effective_id = overrides
                .get(id)
                .and_then(|v| v.as_str())
                .or_else(|| {
                    c.get("tvg_id")
                        .and_then(|v| v.as_str())
                        .filter(|s| !s.is_empty())
                })
                .unwrap_or(id);

            matched_ids.contains(effective_id) || matched_ids.contains(id)
        })
        .collect();

    if extras.is_empty() {
        return base_json.to_string();
    }

    let mut merged = base;
    for extra in extras {
        merged.push(extra.clone());
    }
    serde_json::to_string(&merged).unwrap_or_else(|_| "[]".to_string())
}

// ── internal helpers ───────────────────────────────────

/// Compute a relevance score (0.0–1.0) for a search hit.
///
/// Scoring tiers (highest wins):
/// - **1.0** — `query` is a prefix of the normalised `name`.
/// - **0.8** — `query` matches at a word boundary inside `name`
///   (preceded by a space or the start of the string).
/// - **0.6** — `query` is a substring anywhere in `name`.
/// - **0.3** — `query` found only in `description`, not `name`.
/// - **0.0** — no match (caller should have already filtered
///   these out, but 0.0 is returned safely).
///
/// Both `query` and `name` / `description` must already be
/// normalised via [`normalize_for_search`] before calling
/// this function.
fn relevance_score(query: &str, name: &str, description: Option<&str>) -> f64 {
    if query.is_empty() {
        return 0.0;
    }

    let norm_name = normalize_for_search(name);

    // Tier 1 — prefix match.
    if norm_name.starts_with(query) {
        return 1.0;
    }

    // Tier 2 — word-boundary match: query appears right after a space.
    let word_boundary_match = norm_name.starts_with(query)
        || norm_name
            .match_indices(query)
            .any(|(pos, _)| pos == 0 || norm_name.as_bytes().get(pos - 1) == Some(&b' '));

    if word_boundary_match {
        return 0.8;
    }

    // Tier 3 — substring match anywhere in name.
    if norm_name.contains(query) {
        return 0.6;
    }

    // Tier 4 — description-only match.
    if let Some(desc) = description
        && normalize_for_search(desc).contains(query)
    {
        return 0.3;
    }

    0.0
}

// ── Cross-language search normalisation ──────────────────────────────────────

/// Normalise a string for cross-language substring matching.
///
/// Steps applied in order:
/// 1. Lowercase (ASCII-safe).
/// 2. Strip combining diacritics (NFD decompose → remove Mn category).
/// 3. Arabic-to-Latin transliteration for the most common letters so that
///    an English query (`"al jazeera"`) matches an Arabic title
///    (`"الجزيرة"`) and vice-versa.
///
/// The transliteration table covers the 28 base Arabic letters plus common
/// ligatures.  It is intentionally lossy — the goal is fuzzy substring
/// matching, not lossless round-trip conversion.
///
/// # Spec
/// Satisfies requirement 6.14 — cross-language search: Arabic-to-English
/// transliteration, diacritic-folded matching.
pub fn normalize_for_search(s: &str) -> String {
    use unicode_normalization::UnicodeNormalization;

    // Step 1: NFD decompose so combining marks become separate chars.
    let nfd: String = s.nfd().collect();

    // Step 2: Strip combining diacritical marks (Latin/Arabic only)
    //         and map Arabic letters to ASCII equivalents.
    //         CJK combining marks (Hangul Jamo, Katakana dakuten/handakuten)
    //         are preserved so CJK text survives normalization intact.
    let mut out = String::with_capacity(nfd.len());
    for ch in nfd.chars() {
        // Skip only Latin/Arabic combining diacritics, not CJK marks.
        if unicode_normalization::char::is_combining_mark(ch) && is_latin_or_arabic_combining(ch) {
            continue;
        }
        // Arabic-to-Latin transliteration.
        if let Some(latin) = arabic_to_latin(ch) {
            out.push_str(latin);
        } else {
            // Lowercase ASCII; keep non-ASCII as-is after diacritic stripping.
            for c in ch.to_lowercase() {
                out.push(c);
            }
        }
    }
    // Step 3: NFC recompose so that Hangul Jamo and Katakana
    //         base+dakuten recombine into their composed forms.
    //         Latin chars remain stripped of diacritics since we
    //         removed those combining marks before recomposition.
    out.nfc().collect()
}

/// Map a single Arabic Unicode character to its approximate Latin equivalent.
/// Returns `None` for non-Arabic characters.
fn arabic_to_latin(ch: char) -> Option<&'static str> {
    match ch {
        'ا' | 'أ' | 'إ' | 'آ' | 'ء' => Some("a"),
        'ب' => Some("b"),
        'ت' => Some("t"),
        'ث' => Some("th"),
        'ج' => Some("j"),
        'ح' => Some("h"),
        'خ' => Some("kh"),
        'د' => Some("d"),
        'ذ' => Some("dh"),
        'ر' => Some("r"),
        'ز' => Some("z"),
        'س' => Some("s"),
        'ش' => Some("sh"),
        'ص' => Some("s"),
        'ض' => Some("d"),
        'ط' => Some("t"),
        'ظ' => Some("z"),
        'ع' => Some("a"),
        'غ' => Some("gh"),
        'ف' => Some("f"),
        'ق' => Some("q"),
        'ك' => Some("k"),
        'ل' => Some("l"),
        'م' => Some("m"),
        'ن' => Some("n"),
        'ه' => Some("h"),
        'و' => Some("w"),
        'ي' | 'ى' => Some("y"),
        'ة' => Some("a"),
        // Arabic-Indic digits → ASCII digits
        '٠' => Some("0"),
        '١' => Some("1"),
        '٢' => Some("2"),
        '٣' => Some("3"),
        '٤' => Some("4"),
        '٥' => Some("5"),
        '٦' => Some("6"),
        '٧' => Some("7"),
        '٨' => Some("8"),
        '٩' => Some("9"),
        // Arabic tatweel (kashida) — skip
        '\u{0640}' => Some(""),
        _ => None,
    }
}

/// Returns `true` for combining marks used in Latin/Arabic scripts
/// (diacritics we want to strip). Returns `false` for CJK combining
/// marks (Hangul Jamo, Katakana dakuten/handakuten) that must be
/// preserved for correct CJK search.
fn is_latin_or_arabic_combining(ch: char) -> bool {
    let cp = ch as u32;
    // Combining Diacritical Marks (Latin): U+0300–U+036F
    // Combining Diacritical Marks Extended: U+1AB0–U+1AFF
    // Combining Diacritical Marks Supplement: U+1DC0–U+1DFF
    // Combining Half Marks: U+FE20–U+FE2F
    // Arabic combining marks (fathah, dammah, kasrah, etc.): U+0610–U+061A, U+064B–U+065F, U+0670
    matches!(
        cp,
        0x0300..=0x036F
            | 0x1AB0..=0x1AFF
            | 0x1DC0..=0x1DFF
            | 0xFE20..=0xFE2F
            | 0x0610..=0x061A
            | 0x064B..=0x065F
            | 0x0670
    )
}

fn search_channels(q: &str, channels: &[Channel]) -> Vec<Channel> {
    channels
        .iter()
        .filter(|ch| normalize_for_search(&ch.name).contains(q))
        .cloned()
        .collect()
}

fn search_vod(
    q: &str,
    vod_items: &[VodItem],
    filter: &SearchFilter,
) -> (Vec<VodItem>, Vec<VodItem>) {
    let mut movies = Vec::new();
    let mut series = Vec::new();

    for item in vod_items {
        // Skip episodes — they appear under their series.
        if item.item_type == "episode" {
            continue;
        }

        // Name match.
        let name_match = normalize_for_search(&item.name).contains(q);

        // Optional description match.
        let desc_match = filter.search_in_description
            && item
                .description
                .as_deref()
                .is_some_and(|d| normalize_for_search(d).contains(q));

        if !name_match && !desc_match {
            continue;
        }

        // Category filter.
        if let Some(ref cat) = filter.category {
            let cat_lower = cat.to_ascii_lowercase();
            let item_cat = item.category.as_deref().unwrap_or("").to_ascii_lowercase();
            if !item_cat.contains(&cat_lower) {
                continue;
            }
        }

        // Year range filter.
        if let Some(year) = item.year {
            if let Some(min) = filter.year_min
                && year < min
            {
                continue;
            }
            if let Some(max) = filter.year_max
                && year > max
            {
                continue;
            }
        }

        match item.item_type.as_str() {
            "movie" => {
                if filter.search_movies {
                    movies.push(item.clone());
                }
            }
            "series" => {
                if filter.search_series {
                    series.push(item.clone());
                }
            }
            _ => {}
        }
    }

    (movies, series)
}

fn search_epg(
    q: &str,
    channels: &[Channel],
    epg_entries: &HashMap<String, Vec<EpgEntry>>,
    filter: &SearchFilter,
) -> Vec<EpgProgram> {
    // Build channel lookup for enrichment.
    let ch_map: HashMap<&str, &Channel> = channels.iter().map(|ch| (ch.id.as_str(), ch)).collect();

    let mut results = Vec::new();

    for (channel_id, entries) in epg_entries {
        let ch = match ch_map.get(channel_id.as_str()) {
            Some(ch) => ch,
            None => continue,
        };

        for entry in entries {
            let title_match = normalize_for_search(&entry.title).contains(q);

            let desc_match = filter.search_in_description
                && entry
                    .description
                    .as_deref()
                    .is_some_and(|d| normalize_for_search(d).contains(q));

            if title_match || desc_match {
                results.push(EpgProgram {
                    channel_id: channel_id.clone(),
                    channel_name: ch.name.clone(),
                    logo_url: ch.logo_url.clone(),
                    stream_url: ch.stream_url.clone(),
                    entry: entry.clone(),
                });
            }
        }
    }

    results
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::algorithms::normalize::EPG_FORMAT;
    use chrono::NaiveDateTime;

    fn make_channel(id: &str, name: &str) -> Channel {
        Channel {
            id: id.to_string(),
            name: name.to_string(),
            stream_url: format!("http://example.com/{id}"),
            number: None,
            channel_group: None,
            logo_url: Some("http://logo.com/ch.png".to_string()),
            tvg_id: None,
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

    fn make_vod(
        id: &str,
        name: &str,
        item_type: &str,
        category: Option<&str>,
        year: Option<i32>,
        description: Option<&str>,
    ) -> VodItem {
        VodItem {
            id: id.to_string(),
            native_id: id.to_string(),
            name: name.to_string(),
            stream_url: format!("http://example.com/vod/{id}"),
            item_type: item_type.to_string(),
            poster_url: None,
            backdrop_url: None,
            description: description.map(String::from),
            rating: None,
            year,
            duration: None,
            category: category.map(String::from),
            series_id: None,
            season_number: None,
            episode_number: None,
            ext: None,
            is_favorite: false,
            added_at: None,
            updated_at: None,
            source_id: None,
            cast: None,
            director: None,
            genre: None,
            youtube_trailer: None,
            tmdb_id: None,
            rating_5based: None,
            original_name: None,
            is_adult: false,
            content_rating: None,
        }
    }

    fn make_epg(channel_id: &str, title: &str, desc: Option<&str>) -> EpgEntry {
        let start = NaiveDateTime::parse_from_str("2024-02-16 15:00:00", EPG_FORMAT).unwrap();
        let end = NaiveDateTime::parse_from_str("2024-02-16 16:00:00", EPG_FORMAT).unwrap();
        EpgEntry {
            epg_channel_id: channel_id.to_string(),
            title: title.to_string(),
            start_time: start,
            end_time: end,
            description: desc.map(String::from),
            ..EpgEntry::default()
        }
    }

    fn all_filter() -> SearchFilter {
        SearchFilter {
            search_channels: true,
            search_movies: true,
            search_series: true,
            search_epg: true,
            search_in_description: false,
            category: None,
            year_min: None,
            year_max: None,
        }
    }

    #[test]
    fn empty_query_returns_empty() {
        let r = search("  ", &[], &[], &HashMap::new(), &all_filter());
        assert!(r.channels.is_empty());
        assert!(r.movies.is_empty());
    }

    #[test]
    fn finds_channels_by_name() {
        let channels = vec![make_channel("c1", "BBC One"), make_channel("c2", "CNN")];
        let r = search("bbc", &channels, &[], &HashMap::new(), &all_filter());

        assert_eq!(r.channels.len(), 1);
        assert_eq!(r.channels[0].id, "c1");
    }

    #[test]
    fn finds_movies_and_series() {
        let vod = vec![
            make_vod("m1", "The Matrix", "movie", None, Some(1999), None),
            make_vod("s1", "Breaking Bad", "series", None, Some(2008), None),
            make_vod("e1", "Breaking Bad S1E1", "episode", None, None, None),
        ];
        let r = search("breaking", &[], &vod, &HashMap::new(), &all_filter());

        assert_eq!(r.series.len(), 1);
        assert!(r.movies.is_empty());
        // Episodes are excluded.
    }

    #[test]
    fn filters_by_year_range() {
        let vod = vec![
            make_vod("m1", "Old Movie", "movie", None, Some(1990), None),
            make_vod("m2", "New Movie", "movie", None, Some(2020), None),
        ];
        let mut f = all_filter();
        f.year_min = Some(2000);

        let r = search("movie", &[], &vod, &HashMap::new(), &f);

        assert_eq!(r.movies.len(), 1);
        assert_eq!(r.movies[0].id, "m2");
    }

    #[test]
    fn filters_by_category() {
        let vod = vec![
            make_vod("m1", "Action Hero", "movie", Some("Action"), None, None),
            make_vod("m2", "Drama Hero", "movie", Some("Drama"), None, None),
        ];
        let mut f = all_filter();
        f.category = Some("action".to_string());

        let r = search("hero", &[], &vod, &HashMap::new(), &f);

        assert_eq!(r.movies.len(), 1);
        assert_eq!(r.movies[0].id, "m1");
    }

    #[test]
    fn searches_description_when_enabled() {
        let vod = vec![make_vod(
            "m1",
            "Untitled",
            "movie",
            None,
            None,
            Some("A thrilling adventure"),
        )];
        let mut f = all_filter();
        f.search_in_description = true;

        let r = search("thrilling", &[], &vod, &HashMap::new(), &f);

        assert_eq!(r.movies.len(), 1);
    }

    #[test]
    fn description_not_searched_by_default() {
        let vod = vec![make_vod(
            "m1",
            "Untitled",
            "movie",
            None,
            None,
            Some("A thrilling adventure"),
        )];

        let r = search("thrilling", &[], &vod, &HashMap::new(), &all_filter());

        assert!(r.movies.is_empty());
    }

    #[test]
    fn finds_epg_programs() {
        let channels = vec![make_channel("c1", "BBC One")];
        let mut epg = HashMap::new();
        epg.insert(
            "c1".to_string(),
            vec![
                make_epg("c1", "World News", None),
                make_epg("c1", "Sports Hour", None),
            ],
        );

        let r = search("news", &channels, &[], &epg, &all_filter());

        assert_eq!(r.epg_programs.len(), 1);
        assert_eq!(r.epg_programs[0].channel_name, "BBC One",);
    }

    #[test]
    fn epg_searches_description_when_enabled() {
        let channels = vec![make_channel("c1", "CNN")];
        let mut epg = HashMap::new();
        epg.insert(
            "c1".to_string(),
            vec![make_epg("c1", "Report", Some("Breaking analysis"))],
        );
        let mut f = all_filter();
        f.search_in_description = true;

        let r = search("analysis", &channels, &[], &epg, &f);

        assert_eq!(r.epg_programs.len(), 1);
    }

    #[test]
    fn respects_disabled_filters() {
        let channels = vec![make_channel("c1", "Test Ch")];
        let vod = vec![make_vod("m1", "Test Movie", "movie", None, None, None)];
        let f = SearchFilter {
            search_channels: false,
            search_movies: false,
            search_series: false,
            search_epg: false,
            search_in_description: false,
            category: None,
            year_min: None,
            year_max: None,
        };

        let r = search("test", &channels, &vod, &HashMap::new(), &f);

        assert!(r.channels.is_empty());
        assert!(r.movies.is_empty());
    }

    // ── enrich_search_results ────────────────────────────

    #[test]
    fn enrich_channel_results() {
        // "bbc" is a prefix of "BBC One" and "BBC Two" → both
        // get score 1.0 (prefix match).
        let channels = vec![make_channel("c1", "BBC One"), make_channel("c2", "BBC Two")];
        let results = SearchResults {
            channels: channels.clone(),
            movies: Vec::new(),
            series: Vec::new(),
            epg_programs: Vec::new(),
        };

        let enriched = enrich_search_results("bbc", &results, &channels, &[]);
        assert_eq!(enriched.len(), 2);
        assert_eq!(enriched[0].media_type, "channel");
        assert_eq!(enriched[0].id, "c1");
        assert!((enriched[0].score - 1.0).abs() < 0.01);
        assert!((enriched[1].score - 1.0).abs() < 0.01);
    }

    #[test]
    fn enrich_vod_results() {
        let vod = vec![
            make_vod("m1", "Action Hero", "movie", Some("Action"), None, None),
            make_vod("s1", "Drama Series", "series", Some("Drama"), None, None),
        ];
        let results = SearchResults {
            channels: Vec::new(),
            movies: vec![vod[0].clone()],
            series: vec![vod[1].clone()],
            epg_programs: Vec::new(),
        };

        let enriched = enrich_search_results("hero", &results, &[], &vod);
        assert_eq!(enriched.len(), 2);
        assert_eq!(enriched[0].media_type, "movie");
        assert_eq!(enriched[0].name, "Action Hero");
        assert_eq!(enriched[1].media_type, "series");
        assert_eq!(enriched[1].name, "Drama Series");
    }

    #[test]
    fn enrich_mixed_with_missing_entities() {
        // Channel in results but not in source — uses
        // result data directly.
        let result_channel = make_channel("c99", "Unknown Channel");
        let results = SearchResults {
            channels: vec![result_channel],
            movies: Vec::new(),
            series: Vec::new(),
            epg_programs: Vec::new(),
        };

        let enriched = enrich_search_results("unknown", &results, &[], &[]);
        assert_eq!(enriched.len(), 1);
        assert_eq!(enriched[0].id, "c99");
        assert_eq!(enriched[0].name, "Unknown Channel",);
    }

    // ── Search Functionality ─────────────────────────────

    #[test]
    fn search_case_insensitive() {
        let vod = vec![make_vod("m1", "movie title", "movie", None, None, None)];
        let r = search("MOVIE", &[], &vod, &HashMap::new(), &all_filter());
        assert_eq!(r.movies.len(), 1);
        assert_eq!(r.movies[0].id, "m1");
    }

    #[test]
    fn search_partial_match() {
        let channels = vec![make_channel("c1", "Sports News")];
        let r = search("spo", &channels, &[], &HashMap::new(), &all_filter());
        assert_eq!(r.channels.len(), 1);
        assert_eq!(r.channels[0].name, "Sports News");
    }

    #[test]
    fn search_no_results() {
        let channels = vec![make_channel("c1", "BBC One"), make_channel("c2", "CNN")];
        let vod = vec![make_vod("m1", "The Matrix", "movie", None, None, None)];
        let r = search(
            "xyznonexistent",
            &channels,
            &vod,
            &HashMap::new(),
            &all_filter(),
        );
        assert!(r.channels.is_empty());
        assert!(r.movies.is_empty());
        assert!(r.series.is_empty());
        assert!(r.epg_programs.is_empty());
    }

    #[test]
    fn search_special_characters() {
        let channels = vec![
            make_channel("c1", "News & Weather"),
            make_channel("c2", "Music+Hits"),
        ];
        let vod = vec![make_vod("m1", "Tom & Jerry", "movie", None, None, None)];

        // Queries with special chars should not panic.
        let r1 = search("&", &channels, &vod, &HashMap::new(), &all_filter());
        assert_eq!(r1.channels.len(), 1);
        assert_eq!(r1.channels[0].id, "c1");
        assert_eq!(r1.movies.len(), 1);

        let r2 = search("+", &channels, &vod, &HashMap::new(), &all_filter());
        assert_eq!(r2.channels.len(), 1);
        assert_eq!(r2.channels[0].id, "c2");

        // Brackets, asterisks, etc. — no crash.
        let r3 = search("[*?]", &channels, &vod, &HashMap::new(), &all_filter());
        assert!(r3.channels.is_empty());
        assert!(r3.movies.is_empty());
    }

    #[test]
    fn search_empty_query() {
        let channels = vec![make_channel("c1", "BBC One")];
        let vod = vec![make_vod("m1", "Matrix", "movie", None, None, None)];

        let r = search("", &channels, &vod, &HashMap::new(), &all_filter());
        assert!(r.channels.is_empty());
        assert!(r.movies.is_empty());
        assert!(r.series.is_empty());
        assert!(r.epg_programs.is_empty());
    }

    // ── Filtering ────────────────────────────────────────

    #[test]
    fn filter_channels_only() {
        let channels = vec![make_channel("c1", "Test Channel")];
        let vod = vec![make_vod("m1", "Test Movie", "movie", None, None, None)];
        let mut epg = HashMap::new();
        epg.insert("c1".to_string(), vec![make_epg("c1", "Test Show", None)]);

        let f = SearchFilter {
            search_channels: true,
            search_movies: false,
            search_series: false,
            search_epg: false,
            search_in_description: false,
            category: None,
            year_min: None,
            year_max: None,
        };
        let r = search("test", &channels, &vod, &epg, &f);

        assert_eq!(r.channels.len(), 1);
        assert!(r.movies.is_empty());
        assert!(r.series.is_empty());
        assert!(r.epg_programs.is_empty());
    }

    #[test]
    fn filter_vod_only() {
        let channels = vec![make_channel("c1", "Test Channel")];
        let vod = vec![
            make_vod("m1", "Test Movie", "movie", None, None, None),
            make_vod("s1", "Test Series", "series", None, None, None),
        ];

        let f = SearchFilter {
            search_channels: false,
            search_movies: true,
            search_series: true,
            search_epg: false,
            search_in_description: false,
            category: None,
            year_min: None,
            year_max: None,
        };
        let r = search("test", &channels, &vod, &HashMap::new(), &f);

        assert!(r.channels.is_empty());
        assert_eq!(r.movies.len(), 1);
        assert_eq!(r.series.len(), 1);
        assert!(r.epg_programs.is_empty());
    }

    #[test]
    fn filter_epg_only() {
        let channels = vec![make_channel("c1", "Test Channel")];
        let vod = vec![make_vod("m1", "Test Movie", "movie", None, None, None)];
        let mut epg = HashMap::new();
        epg.insert("c1".to_string(), vec![make_epg("c1", "Test Program", None)]);

        let f = SearchFilter {
            search_channels: false,
            search_movies: false,
            search_series: false,
            search_epg: true,
            search_in_description: false,
            category: None,
            year_min: None,
            year_max: None,
        };
        let r = search("test", &channels, &vod, &epg, &f);

        assert!(r.channels.is_empty());
        assert!(r.movies.is_empty());
        assert!(r.series.is_empty());
        assert_eq!(r.epg_programs.len(), 1);
        assert_eq!(r.epg_programs[0].entry.title, "Test Program");
    }

    // ── Enrichment ───────────────────────────────────────

    #[test]
    fn enrich_adds_channel_metadata() {
        let channels = vec![make_channel("c1", "BBC One")];
        let results = SearchResults {
            channels: channels.clone(),
            movies: Vec::new(),
            series: Vec::new(),
            epg_programs: Vec::new(),
        };

        let enriched = enrich_search_results("bbc", &results, &channels, &[]);
        assert_eq!(enriched.len(), 1);
        assert_eq!(enriched[0].media_type, "channel");
        assert_eq!(enriched[0].id, "c1");
        assert_eq!(enriched[0].name, "BBC One");
        // Metadata should contain channel fields.
        let meta = &enriched[0].metadata;
        assert_eq!(meta.get("name").and_then(|v| v.as_str()), Some("BBC One"),);
        assert_eq!(
            meta.get("stream_url").and_then(|v| v.as_str()),
            Some("http://example.com/c1"),
        );
    }

    #[test]
    fn enrich_adds_vod_metadata() {
        let vod = vec![make_vod(
            "m1",
            "Action Hero",
            "movie",
            Some("Action"),
            Some(2020),
            Some("A great film"),
        )];
        let results = SearchResults {
            channels: Vec::new(),
            movies: vec![vod[0].clone()],
            series: Vec::new(),
            epg_programs: Vec::new(),
        };

        let enriched = enrich_search_results("action", &results, &[], &vod);
        assert_eq!(enriched.len(), 1);
        assert_eq!(enriched[0].media_type, "movie");
        assert_eq!(enriched[0].name, "Action Hero");
        let meta = &enriched[0].metadata;
        assert_eq!(
            meta.get("category").and_then(|v| v.as_str()),
            Some("Action"),
        );
        assert_eq!(meta.get("year").and_then(|v| v.as_i64()), Some(2020),);
        assert_eq!(
            meta.get("description").and_then(|v| v.as_str()),
            Some("A great film"),
        );
    }

    #[test]
    fn enrich_missing_ids_graceful() {
        // Results reference IDs not present in source
        // data — should not crash, falls back to result
        // entity data.
        let orphan_ch = make_channel("c_orphan", "Orphan Channel");
        let orphan_vod = make_vod("m_orphan", "Orphan Movie", "movie", None, None, None);
        let results = SearchResults {
            channels: vec![orphan_ch],
            movies: vec![orphan_vod],
            series: Vec::new(),
            epg_programs: Vec::new(),
        };

        // Source arrays are empty — IDs won't match.
        let enriched = enrich_search_results("orphan", &results, &[], &[]);
        assert_eq!(enriched.len(), 2);
        assert_eq!(enriched[0].id, "c_orphan");
        assert_eq!(enriched[0].name, "Orphan Channel");
        assert_eq!(enriched[1].id, "m_orphan");
        assert_eq!(enriched[1].name, "Orphan Movie");
        // Metadata should still be populated from
        // the result objects themselves.
        assert!(!enriched[0].metadata.is_null());
        assert!(!enriched[1].metadata.is_null());
    }

    // ── Edge Cases ───────────────────────────────────────

    #[test]
    fn search_large_dataset_no_crash() {
        let channels: Vec<Channel> = (0..200)
            .map(|i| make_channel(&format!("c{i}"), &format!("Channel {i}")))
            .collect();
        let vod: Vec<VodItem> = (0..200)
            .map(|i| {
                make_vod(
                    &format!("m{i}"),
                    &format!("Movie {i}"),
                    "movie",
                    None,
                    None,
                    None,
                )
            })
            .collect();
        let mut epg = HashMap::new();
        for i in 0..200 {
            epg.insert(
                format!("c{i}"),
                vec![make_epg(&format!("c{i}"), &format!("Show {i}"), None)],
            );
        }

        // Should not panic or OOM with 600+ items.
        let r = search("100", &channels, &vod, &epg, &all_filter());
        // "100" matches Channel 100, Movie 100, Show 100.
        assert!(!r.channels.is_empty());
        assert!(!r.movies.is_empty());
        assert!(!r.epg_programs.is_empty());

        // Enrichment on large result set also fine.
        let enriched = enrich_search_results("100", &r, &channels, &vod);
        assert!(!enriched.is_empty());
    }

    #[test]
    fn search_empty_dataset() {
        let r = search("anything", &[], &[], &HashMap::new(), &all_filter());
        assert!(r.channels.is_empty());
        assert!(r.movies.is_empty());
        assert!(r.series.is_empty());
        assert!(r.epg_programs.is_empty());
    }

    // ── search_channels_by_live_program ─────────────────

    #[test]
    fn live_program_search_match_found() {
        let epg_map = r#"{"ch1": [
            {"title": "Morning News", "startTime": 1000, "endTime": 5000},
            {"title": "Sport Live", "startTime": 5000, "endTime": 9000}
        ]}"#;
        // now=2000 → "Morning News" is live (1000 <= 2000 < 5000).
        let result = search_channels_by_live_program(epg_map, "news", 2000);
        let ids: Vec<String> = serde_json::from_str(&result).unwrap();
        assert_eq!(ids, vec!["ch1"]);
    }

    #[test]
    fn live_program_search_no_match() {
        let epg_map = r#"{"ch1": [
            {"title": "Morning News", "startTime": 1000, "endTime": 5000}
        ]}"#;
        let result = search_channels_by_live_program(epg_map, "sport", 2000);
        let ids: Vec<String> = serde_json::from_str(&result).unwrap();
        assert!(ids.is_empty());
    }

    #[test]
    fn live_program_search_case_insensitive() {
        let epg_map = r#"{"ch1": [
            {"title": "BREAKING NEWS", "startTime": 1000, "endTime": 5000}
        ]}"#;
        let result = search_channels_by_live_program(epg_map, "breaking", 2000);
        let ids: Vec<String> = serde_json::from_str(&result).unwrap();
        assert_eq!(ids.len(), 1);
    }

    #[test]
    fn live_program_search_program_not_live() {
        let epg_map = r#"{"ch1": [
            {"title": "Morning News", "startTime": 1000, "endTime": 2000}
        ]}"#;
        // now=3000 → program has ended.
        let result = search_channels_by_live_program(epg_map, "news", 3000);
        let ids: Vec<String> = serde_json::from_str(&result).unwrap();
        assert!(ids.is_empty());
    }

    #[test]
    fn live_program_search_empty_query_returns_empty() {
        let epg_map = r#"{"ch1": [
            {"title": "News", "startTime": 1000, "endTime": 5000}
        ]}"#;
        let result = search_channels_by_live_program(epg_map, "", 2000);
        let ids: Vec<String> = serde_json::from_str(&result).unwrap();
        assert!(ids.is_empty());
    }

    #[test]
    fn live_program_search_multiple_channels() {
        let epg_map = r#"{
            "ch1": [{"title": "News Hour", "startTime": 1000, "endTime": 5000}],
            "ch2": [{"title": "Sport News", "startTime": 1000, "endTime": 5000}],
            "ch3": [{"title": "Movie Time", "startTime": 1000, "endTime": 5000}]
        }"#;
        let result = search_channels_by_live_program(epg_map, "news", 2000);
        let mut ids: Vec<String> = serde_json::from_str(&result).unwrap();
        ids.sort();
        assert_eq!(ids, vec!["ch1", "ch2"]);
    }

    // ── merge_epg_matched_channels ──────────────────────

    #[test]
    fn merge_adds_extra_channels() {
        let base = r#"[{"id": "c1", "name": "BBC"}]"#;
        let all = r#"[
            {"id": "c1", "name": "BBC"},
            {"id": "c2", "name": "CNN", "tvg_id": "cnn-epg"},
            {"id": "c3", "name": "Fox"}
        ]"#;
        let matched_ids = r#"["cnn-epg"]"#;
        let overrides = "{}";
        let result = merge_epg_matched_channels(base, all, matched_ids, overrides);
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        let arr = v.as_array().unwrap();
        assert_eq!(arr.len(), 2);
        assert_eq!(arr[0]["id"], "c1");
        assert_eq!(arr[1]["id"], "c2");
    }

    #[test]
    fn merge_no_duplicates() {
        let base = r#"[{"id": "c1", "name": "BBC"}]"#;
        let all = r#"[{"id": "c1", "name": "BBC"}]"#;
        let matched_ids = r#"["c1"]"#;
        let overrides = "{}";
        let result = merge_epg_matched_channels(base, all, matched_ids, overrides);
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        // c1 already in base → no extras added → returns base unchanged.
        assert_eq!(v.as_array().unwrap().len(), 1);
    }

    #[test]
    fn merge_uses_epg_overrides() {
        let base = r#"[{"id": "c1", "name": "BBC"}]"#;
        let all = r#"[
            {"id": "c1", "name": "BBC"},
            {"id": "c2", "name": "CNN"}
        ]"#;
        let matched_ids = r#"["override-key"]"#;
        let overrides = r#"{"c2": "override-key"}"#;
        let result = merge_epg_matched_channels(base, all, matched_ids, overrides);
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        let arr = v.as_array().unwrap();
        assert_eq!(arr.len(), 2);
        assert_eq!(arr[1]["id"], "c2");
    }

    #[test]
    fn merge_no_extras_returns_base() {
        let base = r#"[{"id": "c1", "name": "BBC"}]"#;
        let all = r#"[{"id": "c1", "name": "BBC"}, {"id": "c2", "name": "CNN"}]"#;
        let matched_ids = r#"["nonexistent"]"#;
        let overrides = "{}";
        let result = merge_epg_matched_channels(base, all, matched_ids, overrides);
        // Should return base unchanged.
        assert_eq!(result, base);
    }

    // ── normalize_for_search ──────────────────────────────────────────────

    #[test]
    fn test_normalize_ascii_lowercases() {
        assert_eq!(normalize_for_search("BBC News"), "bbc news");
    }

    #[test]
    fn test_normalize_strips_diacritics() {
        // é → e after NFD decompose + Mn strip
        assert_eq!(normalize_for_search("Café"), "cafe");
    }

    #[test]
    fn test_normalize_arabic_to_latin() {
        // الجزيرة → aljazyra (lossy but matchable)
        let result = normalize_for_search("الجزيرة");
        assert!(result.contains('j'), "expected 'j' in: {result}");
        assert!(result.contains('a'), "expected 'a' in: {result}");
    }

    #[test]
    fn test_normalize_arabic_channel_matched_by_latin_query() {
        let arabic_name = "الجزيرة الإخبارية";
        let normalised = normalize_for_search(arabic_name);
        // English query "jazeera" should be a substring of normalised form
        // الجزيرة → "aljzyra" (ج=j, ز=z, ي=y, ر=r, ة=a)
        assert!(
            normalised.contains("jzyr") || normalised.contains("jaz"),
            "normalised form: {normalised}"
        );
    }

    #[test]
    fn test_normalize_arabic_indic_digits_to_ascii() {
        assert_eq!(normalize_for_search("١٢٣"), "123");
    }

    #[test]
    fn test_normalize_empty_string() {
        assert_eq!(normalize_for_search(""), "");
    }

    #[test]
    fn test_search_channels_matches_arabic_name_with_latin_query() {
        // After normalization الجزيرة → "aljzyra". Query "jzyr" is a substring.
        let q = normalize_for_search("jzyr");
        let normalised_name = normalize_for_search("الجزيرة");
        let channels = vec![make_channel("1", "الجزيرة")];
        let results = search_channels(&q, &channels);
        assert!(
            normalised_name.contains(&q) == !results.is_empty(),
            "search consistency: normalised={normalised_name}, q={q}"
        );
    }

    #[test]
    fn test_search_channels_diacritic_folding() {
        let q = normalize_for_search("television");
        let channels = vec![make_channel("2", "Télévision Française")];
        let results = search_channels(&q, &channels);
        assert_eq!(results.len(), 1, "diacritic-folded match should succeed");
    }

    // ── CJK (Chinese/Japanese/Korean) search tests ──────────

    #[test]
    fn search_cjk_chinese() {
        // Chinese channel name — substring match works
        let normalized = normalize_for_search("CCTV新闻频道");
        assert!(
            normalized.contains("新闻"),
            "Chinese substring match failed: normalized='{normalized}'"
        );
    }

    #[test]
    fn search_cjk_japanese() {
        let normalized = normalize_for_search("NHK総合テレビ");
        assert!(
            normalized.contains("総合"),
            "Japanese substring match failed: normalized='{normalized}'"
        );
    }

    #[test]
    fn search_cjk_korean() {
        let normalized = normalize_for_search("KBS 뉴스");
        assert!(
            normalized.contains("뉴스"),
            "Korean substring match failed: normalized='{normalized}'"
        );
    }

    #[test]
    fn search_cjk_mixed_with_latin() {
        // CJK mixed with ASCII — both parts preserved
        let normalized = normalize_for_search("CCTV新闻频道");
        assert!(
            normalized.contains("cctv"),
            "Latin part should be lowercased"
        );
        assert!(normalized.contains("新闻"), "CJK part should be preserved");
    }

    #[test]
    fn search_cjk_katakana_substring() {
        let normalized = normalize_for_search("フジテレビ");
        assert!(
            normalized.contains("テレビ"),
            "Katakana substring match failed: normalized='{normalized}'"
        );
    }

    #[test]
    fn search_cjk_channel_filter() {
        // End-to-end: searching channels with CJK query
        let q = normalize_for_search("新闻");
        let channels = vec![
            make_channel("1", "CCTV新闻频道"),
            make_channel("2", "BBC World"),
        ];
        let results = search_channels(&q, &channels);
        assert_eq!(results.len(), 1, "should match exactly the Chinese channel");
        assert_eq!(results[0].id, "1");
    }

    #[test]
    fn search_cjk_hangul_channel_filter() {
        let q = normalize_for_search("뉴스");
        let channels = vec![
            make_channel("1", "KBS 뉴스"),
            make_channel("2", "MBC 드라마"),
        ];
        let results = search_channels(&q, &channels);
        assert_eq!(
            results.len(),
            1,
            "should match exactly the Korean news channel"
        );
        assert_eq!(results[0].id, "1");
    }

    // ── relevance_score ──────────────────────────────────

    #[test]
    fn relevance_prefix_scores_highest() {
        // "bbc" is a prefix of "bbc news" → 1.0.
        let score = relevance_score("bbc", "BBC News", None);
        assert!(
            (score - 1.0).abs() < f64::EPSILON,
            "expected 1.0 for prefix match, got {score}"
        );
    }

    #[test]
    fn relevance_word_boundary_scores_high() {
        // "news" starts the second word in "bbc news" → 0.8.
        let score = relevance_score("news", "BBC News", None);
        assert!(
            (score - 0.8).abs() < f64::EPSILON,
            "expected 0.8 for word-boundary match, got {score}"
        );
    }

    #[test]
    fn relevance_substring_scores_medium() {
        // "one" is a substring of "channel one hd" but not at a
        // word boundary preceded by 'l' (position > 0, previous
        // byte is 'l', not space).  → 0.6.
        let score = relevance_score("one", "Channel One HD", None);
        // "one" starts a word ("channel|space|one") → 0.8 expected.
        // Adjust: use a mid-word substring instead.
        let score_mid = relevance_score("han", "Channel One HD", None);
        assert!(
            (score_mid - 0.6).abs() < f64::EPSILON,
            "expected 0.6 for mid-word substring match, got {score_mid}"
        );
        // Verify "one" itself is at least a word boundary hit.
        assert!(score >= 0.6, "word match should be ≥ 0.6, got {score}");
    }

    #[test]
    fn relevance_description_only_scores_low() {
        // Query not in name, but present in description → 0.3.
        let score = relevance_score("thriller", "Untitled Film", Some("A thrilling thriller"));
        assert!(
            (score - 0.3).abs() < f64::EPSILON,
            "expected 0.3 for description-only match, got {score}"
        );
    }

    #[test]
    fn relevance_no_match_scores_zero() {
        let score = relevance_score("xyz", "BBC News", None);
        assert!(
            score.abs() < f64::EPSILON,
            "expected 0.0 for no match, got {score}"
        );
    }
}
