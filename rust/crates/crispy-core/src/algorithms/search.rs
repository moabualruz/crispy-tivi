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
    let q = query.trim().to_ascii_lowercase();

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
/// with all entity fields.
pub fn enrich_search_results(
    results: &SearchResults,
    channels: &[Channel],
    vod_items: &[VodItem],
) -> Vec<EnrichedSearchResult> {
    let ch_map: HashMap<&str, &Channel> = channels.iter().map(|c| (c.id.as_str(), c)).collect();
    let vod_map: HashMap<&str, &VodItem> = vod_items.iter().map(|v| (v.id.as_str(), v)).collect();

    let mut enriched = Vec::new();

    // Channels: score by position (higher rank = higher
    // score).
    let ch_count = results.channels.len();
    for (i, ch) in results.channels.iter().enumerate() {
        let score = position_score(i, ch_count);
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
    let mv_count = results.movies.len();
    for (i, mv) in results.movies.iter().enumerate() {
        let score = position_score(i, mv_count);
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
    let sr_count = results.series.len();
    for (i, sr) in results.series.iter().enumerate() {
        let score = position_score(i, sr_count);
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
    let ep_count = results.epg_programs.len();
    for (i, ep) in results.epg_programs.iter().enumerate() {
        let score = position_score(i, ep_count);
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

// ── internal helpers ───────────────────────────────────

/// Score based on position: first item = 1.0, last = 0.0.
fn position_score(index: usize, total: usize) -> f64 {
    if total > 1 {
        1.0 - (index as f64 / (total - 1) as f64)
    } else {
        1.0
    }
}

fn search_channels(q: &str, channels: &[Channel]) -> Vec<Channel> {
    channels
        .iter()
        .filter(|ch| ch.name.to_ascii_lowercase().contains(q))
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
        let name_match = item.name.to_ascii_lowercase().contains(q);

        // Optional description match.
        let desc_match = filter.search_in_description
            && item
                .description
                .as_deref()
                .is_some_and(|d| d.to_ascii_lowercase().contains(q));

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
            let title_match = entry.title.to_ascii_lowercase().contains(q);

            let desc_match = filter.search_in_description
                && entry
                    .description
                    .as_deref()
                    .is_some_and(|d| d.to_ascii_lowercase().contains(q));

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
        }
    }

    fn make_epg(channel_id: &str, title: &str, desc: Option<&str>) -> EpgEntry {
        let start = NaiveDateTime::parse_from_str("2024-02-16 15:00:00", EPG_FORMAT).unwrap();
        let end = NaiveDateTime::parse_from_str("2024-02-16 16:00:00", EPG_FORMAT).unwrap();
        EpgEntry {
            channel_id: channel_id.to_string(),
            title: title.to_string(),
            start_time: start,
            end_time: end,
            description: desc.map(String::from),
            category: None,
            icon_url: None,
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
        let channels = vec![make_channel("c1", "BBC One"), make_channel("c2", "BBC Two")];
        let results = SearchResults {
            channels: channels.clone(),
            movies: Vec::new(),
            series: Vec::new(),
            epg_programs: Vec::new(),
        };

        let enriched = enrich_search_results(&results, &channels, &[]);
        assert_eq!(enriched.len(), 2);
        assert_eq!(enriched[0].media_type, "channel");
        assert_eq!(enriched[0].id, "c1");
        assert!((enriched[0].score - 1.0).abs() < 0.01);
        assert!((enriched[1].score - 0.0).abs() < 0.01);
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

        let enriched = enrich_search_results(&results, &[], &vod);
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

        let enriched = enrich_search_results(&results, &[], &[]);
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

        let enriched = enrich_search_results(&results, &channels, &[]);
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

        let enriched = enrich_search_results(&results, &[], &vod);
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
        let enriched = enrich_search_results(&results, &[], &[]);
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
        let enriched = enrich_search_results(&r, &channels, &vod);
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
}
