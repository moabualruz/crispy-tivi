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
