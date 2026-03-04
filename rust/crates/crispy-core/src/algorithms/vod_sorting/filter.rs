use crate::models::VodItem;

use super::parse_rating;

/// Filter and rank top VOD items by rating.
///
/// Keeps items with a non-empty rating AND at least one
/// image (poster_url or backdrop_url). Sorts by rating
/// descending and caps at `limit`.
///
/// Falls back to newest items by year descending if
/// fewer than `limit` rated items exist.
///
/// Input/output: JSON arrays of `VodItem`.
pub fn filter_top_vod(items_json: &str, limit: usize) -> String {
    let items: Vec<VodItem> = match serde_json::from_str(items_json) {
        Ok(v) => v,
        Err(_) => return "[]".to_string(),
    };

    // Primary: items with rating + image.
    let mut with_rating: Vec<&VodItem> = items
        .iter()
        .filter(|i| {
            let has_rating = i.rating.as_deref().is_some_and(|r| !r.is_empty());
            let has_image = i.poster_url.as_deref().is_some_and(|u| !u.is_empty())
                || i.backdrop_url.as_deref().is_some_and(|u| !u.is_empty());
            has_rating && has_image
        })
        .collect();

    with_rating.sort_by(|a, b| {
        let ra = parse_rating(a.rating.as_deref());
        let rb = parse_rating(b.rating.as_deref());
        // NaN sorts last (after all real values).
        rb.total_cmp(&ra)
    });

    if with_rating.len() >= limit {
        let top: Vec<&VodItem> = with_rating.into_iter().take(limit).collect();
        return serde_json::to_string(&top).unwrap_or_else(|_| "[]".to_string());
    }

    // Fallback: newest items by year descending,
    // excluding items already in with_rating.
    let rated_ids: std::collections::HashSet<&str> =
        with_rating.iter().map(|i| i.id.as_str()).collect();
    let mut by_year: Vec<&VodItem> = items
        .iter()
        .filter(|i| i.year.is_some() && !rated_ids.contains(i.id.as_str()))
        .collect();
    by_year.sort_by(|a, b| b.year.unwrap_or(0).cmp(&a.year.unwrap_or(0)));
    let remaining = limit.saturating_sub(with_rating.len());
    let mut combined = with_rating;
    combined.extend(by_year.into_iter().take(remaining));

    serde_json::to_string(&combined).unwrap_or_else(|_| "[]".to_string())
}

/// MPAA/TV content rating levels.
/// 0=G, 1=PG, 2=PG-13, 3=R, 4=NC-17, 5=Unrated
pub fn parse_content_rating(rating: Option<&str>) -> i32 {
    let rating = match rating {
        Some(r) if !r.is_empty() => r,
        _ => return 5, // unrated
    };
    let s = rating.to_uppercase();
    let s = s.trim();

    // NC-17 / TV-MA (most restrictive rated)
    if s.contains("NC-17") || s == "NC17" {
        return 4;
    }
    if s.contains("TV-MA") || s == "TVMA" {
        return 4;
    }

    // R rated
    if s == "R" || s == "RATED R" {
        return 3;
    }

    // PG-13 / TV-14
    if s.contains("PG-13") || s == "PG13" {
        return 2;
    }
    if s.contains("TV-14") || s == "TV14" {
        return 2;
    }

    // PG / TV-PG
    if s == "PG" || s == "RATED PG" {
        return 1;
    }
    if s.contains("TV-PG") || s == "TVPG" {
        return 1;
    }

    // G / TV-G / TV-Y (most permissive)
    if s == "G" || s == "RATED G" {
        return 0;
    }
    if s.contains("TV-G") || s == "TVG" {
        return 0;
    }
    if s.contains("TV-Y") {
        return 0;
    }

    5 // unrated
}

/// Filter VOD items by content rating.
///
/// Items with rating level <= `max_rating_value` pass.
/// Unrated items (level 5) always pass.
///
/// Rating levels: 0=G, 1=PG, 2=PG-13, 3=R, 4=NC-17,
/// 5=Unrated
pub fn filter_vod_by_content_rating(items_json: &str, max_rating_value: i32) -> String {
    let items: Vec<VodItem> = match serde_json::from_str(items_json) {
        Ok(v) => v,
        Err(_) => return "[]".to_string(),
    };

    let filtered: Vec<&VodItem> = items
        .iter()
        .filter(|item| {
            let level = parse_content_rating(item.rating.as_deref());
            // Unrated always passes; otherwise check level
            level == 5 || level <= max_rating_value
        })
        .collect();

    serde_json::to_string(&filtered).unwrap_or_else(|_| "[]".to_string())
}
