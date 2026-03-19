//! Typed deserialization for recommendation sections.

use serde::{Deserialize, Serialize};

use super::types::RecommendationSection;

// ── Typed deserialization ────────────────────────────

/// The recommendation section type as an enum.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub enum RecommendationSectionType {
    TopPicks,
    BecauseYouWatched,
    PopularInGenre,
    Trending,
    NewForYou,
    HighlyRated,
    RecentlyAdded,
}

/// A single recommended item with its reason.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecommendationItem {
    pub id: String,
    pub name: String,
    pub media_type: String,
    pub score: f64,
    pub reason_type: RecommendationSectionType,
    pub reason_text: String,
    pub genre: Option<String>,
    pub source_title: Option<String>,
}

/// A typed recommendation section.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TypedRecommendationSection {
    pub section_type: RecommendationSectionType,
    pub title: String,
    pub items: Vec<RecommendationItem>,
}

/// Parse recommendation sections from
/// `compute_recommendations()` output into typed structs.
///
/// Converts the string-based `RecommendationSection` vec
/// into strongly-typed `TypedRecommendationSection` vec.
pub fn parse_recommendation_sections(
    sections: &[RecommendationSection],
) -> Result<Vec<TypedRecommendationSection>, String> {
    sections.iter().map(parse_section).collect()
}

pub(super) fn parse_section_type(s: &str) -> Result<RecommendationSectionType, String> {
    match s {
        "topPicks" | "topPick" => Ok(RecommendationSectionType::TopPicks),
        "becauseYouWatched" => Ok(RecommendationSectionType::BecauseYouWatched),
        "popularInGenre" => Ok(RecommendationSectionType::PopularInGenre),
        "trending" => Ok(RecommendationSectionType::Trending),
        "newForYou" => Ok(RecommendationSectionType::NewForYou),
        "highlyRated" => Ok(RecommendationSectionType::HighlyRated),
        "recentlyAdded" => Ok(RecommendationSectionType::RecentlyAdded),
        other => Err(format!("unknown section type: {other}")),
    }
}

/// A fully-merged recommendation item with typed enums
/// and all supplementary fields (poster, category, etc.).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FullRecommendationItem {
    pub id: String,
    pub name: String,
    pub media_type: String,
    pub score: f64,
    pub reason_type: RecommendationSectionType,
    pub source_title: Option<String>,
    pub genre: Option<String>,
    pub poster_url: Option<String>,
    pub category: Option<String>,
    pub stream_url: Option<String>,
    pub rating: Option<String>,
    pub year: Option<i32>,
    pub series_id: Option<String>,
}

/// A fully-merged recommendation section.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FullRecommendationSection {
    pub title: String,
    pub section_type: RecommendationSectionType,
    pub items: Vec<FullRecommendationItem>,
}

/// Deserialize recommendation sections into fully-merged
/// structs with typed enums and all item fields.
///
/// Combines `parse_recommendation_sections` + raw field
/// merge into a single pass, eliminating the double-parse
/// and extra round-trip previously done in Dart.
pub fn deserialize_full_sections(
    sections: &[RecommendationSection],
) -> Result<Vec<FullRecommendationSection>, String> {
    sections
        .iter()
        .map(|section| {
            let section_type = parse_section_type(&section.section_type)?;
            let items: Result<Vec<FullRecommendationItem>, String> = section
                .items
                .iter()
                .map(|r| {
                    let reason_type = parse_section_type(&r.reason)?;
                    let rating_str = r.rating.map(|v| format!("{v}"));
                    Ok(FullRecommendationItem {
                        id: r.id.clone(),
                        name: r.title.clone(),
                        media_type: r.media_type.clone(),
                        score: r.score,
                        reason_type,
                        source_title: None,
                        genre: r.category.clone(),
                        poster_url: r.poster_url.clone(),
                        category: r.category.clone(),
                        stream_url: r.stream_url.clone(),
                        rating: rating_str,
                        year: r.year,
                        series_id: r.series_id.clone(),
                    })
                })
                .collect();
            Ok(FullRecommendationSection {
                title: section.title.clone(),
                section_type,
                items: items?,
            })
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::algorithms::recommendations::types::{Recommendation, RecommendationSection};

    fn make_section(section_type: &str, item_reason: &str) -> RecommendationSection {
        RecommendationSection {
            title: "Test Section".to_string(),
            section_type: section_type.to_string(),
            items: vec![Recommendation {
                id: "v1".to_string(),
                title: "Film".to_string(),
                poster_url: None,
                backdrop_url: None,
                rating: Some(8.0),
                year: Some(2020),
                media_type: "movie".to_string(),
                reason: item_reason.to_string(),
                score: 0.75,
                category: Some("Action".to_string()),
                stream_url: Some("http://stream".to_string()),
                series_id: None,
            }],
        }
    }

    // ── parse_section_type ──────────────────────────

    #[test]
    fn test_parse_section_type_top_picks_canonical() {
        let result = parse_section_type("topPicks");
        assert_eq!(result, Ok(RecommendationSectionType::TopPicks));
    }

    #[test]
    fn test_parse_section_type_top_pick_alias() {
        let result = parse_section_type("topPick");
        assert_eq!(result, Ok(RecommendationSectionType::TopPicks));
    }

    #[test]
    fn test_parse_section_type_all_known_variants() {
        let cases = [
            (
                "becauseYouWatched",
                RecommendationSectionType::BecauseYouWatched,
            ),
            ("popularInGenre", RecommendationSectionType::PopularInGenre),
            ("trending", RecommendationSectionType::Trending),
            ("newForYou", RecommendationSectionType::NewForYou),
            ("highlyRated", RecommendationSectionType::HighlyRated),
            ("recentlyAdded", RecommendationSectionType::RecentlyAdded),
        ];
        for (s, expected) in cases {
            assert_eq!(parse_section_type(s), Ok(expected), "failed for {s}");
        }
    }

    #[test]
    fn test_parse_section_type_unknown_returns_err() {
        let result = parse_section_type("unknownType");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("unknownType"));
    }

    #[test]
    fn test_parse_section_type_empty_string_returns_err() {
        let result = parse_section_type("");
        assert!(result.is_err());
    }

    // ── parse_recommendation_sections ───────────────

    #[test]
    fn test_parse_recommendation_sections_empty_input() {
        let result = parse_recommendation_sections(&[]);
        assert!(result.is_ok());
        assert!(result.unwrap().is_empty());
    }

    #[test]
    fn test_parse_recommendation_sections_valid_section() {
        let sections = vec![make_section("trending", "trending")];
        let result = parse_recommendation_sections(&sections);
        assert!(result.is_ok());
        let typed = result.unwrap();
        assert_eq!(typed.len(), 1);
        assert_eq!(typed[0].section_type, RecommendationSectionType::Trending);
        assert_eq!(typed[0].title, "Test Section");
        assert_eq!(typed[0].items.len(), 1);
        assert_eq!(typed[0].items[0].id, "v1");
        assert_eq!(typed[0].items[0].score, 0.75);
    }

    #[test]
    fn test_parse_recommendation_sections_invalid_type_returns_err() {
        let sections = vec![make_section("badType", "trending")];
        let result = parse_recommendation_sections(&sections);
        assert!(result.is_err());
    }

    // ── deserialize_full_sections ───────────────────

    #[test]
    fn test_deserialize_full_sections_empty_input() {
        let result = deserialize_full_sections(&[]);
        assert_eq!(result.unwrap().len(), 0);
    }

    #[test]
    fn test_deserialize_full_sections_preserves_item_fields() {
        let sections = vec![make_section("highlyRated", "highlyRated")];
        let result = deserialize_full_sections(&sections);
        assert!(result.is_ok());
        let full = result.unwrap();
        assert_eq!(full[0].section_type, RecommendationSectionType::HighlyRated);
        let item = &full[0].items[0];
        assert_eq!(item.id, "v1");
        assert_eq!(item.name, "Film");
        assert_eq!(item.score, 0.75);
        assert_eq!(item.genre.as_deref(), Some("Action"));
        assert_eq!(item.stream_url.as_deref(), Some("http://stream"));
        assert_eq!(item.year, Some(2020));
        assert_eq!(item.rating.as_deref(), Some("8"));
    }

    #[test]
    fn test_deserialize_full_sections_invalid_section_type_returns_err() {
        let sections = vec![make_section("notReal", "trending")];
        let result = deserialize_full_sections(&sections);
        assert!(result.is_err());
    }
}

fn parse_section(section: &RecommendationSection) -> Result<TypedRecommendationSection, String> {
    let section_type = parse_section_type(&section.section_type)?;

    let items: Result<Vec<RecommendationItem>, String> = section
        .items
        .iter()
        .map(|r| {
            let reason_type = parse_section_type(&r.reason)?;
            Ok(RecommendationItem {
                id: r.id.clone(),
                name: r.title.clone(),
                media_type: r.media_type.clone(),
                score: r.score,
                reason_type,
                reason_text: section.title.clone(),
                genre: None,
                source_title: None,
            })
        })
        .collect();

    Ok(TypedRecommendationSection {
        section_type,
        title: section.title.clone(),
        items: items?,
    })
}
