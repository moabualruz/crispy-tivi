use chrono::{DateTime, Utc};

use crate::algorithms::json_utils::parse_json_vec;
use crate::models::VodItem;

use super::parse_rating;

/// Returns `true` if `url` is non-empty and starts with
/// "http" (case-insensitive), matching the Dart
/// `hasValidPoster` predicate in `top10Vod`.
fn has_http_poster(url: Option<&str>) -> bool {
    url.is_some_and(|u| {
        let trimmed = u.trim();
        !trimmed.is_empty() && trimmed.to_ascii_lowercase().starts_with("http")
    })
}

/// Filter and rank top VOD items by rating.
///
/// Keeps items with a non-empty rating AND a valid HTTP
/// poster URL (starts with "http", case-insensitive).
/// Sorts by rating descending and caps at `limit`.
///
/// Falls back to newest items by year descending if
/// fewer than `limit` rated items exist. Fallback items
/// must also have a valid HTTP poster URL.
///
/// Input/output: JSON arrays of `VodItem`.
pub fn filter_top_vod(items_json: &str, limit: usize) -> String {
    let Some(items) = parse_json_vec::<VodItem>(items_json) else {
        return "[]".to_string();
    };

    // Primary: items with rating + HTTP poster URL.
    let mut with_rating: Vec<&VodItem> = items
        .iter()
        .filter(|i| {
            let has_rating = i.rating.as_deref().is_some_and(|r| !r.is_empty());
            let has_poster = has_http_poster(i.poster_url.as_deref());
            has_rating && has_poster
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
    // excluding items already in with_rating, and
    // requiring a valid HTTP poster URL.
    let rated_ids: std::collections::HashSet<&str> =
        with_rating.iter().map(|i| i.id.as_str()).collect();
    let mut by_year: Vec<&VodItem> = items
        .iter()
        .filter(|i| {
            i.year.is_some()
                && !rated_ids.contains(i.id.as_str())
                && has_http_poster(i.poster_url.as_deref())
        })
        .collect();
    by_year.sort_by(|a, b| b.year.unwrap_or(0).cmp(&a.year.unwrap_or(0)));
    let remaining = limit.saturating_sub(with_rating.len());
    let mut combined = with_rating;
    combined.extend(by_year.into_iter().take(remaining));

    serde_json::to_string(&combined).unwrap_or_else(|_| "[]".to_string())
}

/// Filter VOD items to those added within the last
/// `cutoff_days` days, then sort newest-first.
///
/// - `items_json`: JSON array of `VodItem`.
/// - `cutoff_days`: number of days to look back.
/// - `now_ms`: current Unix time in milliseconds (UTC).
///
/// Items without `added_at` are excluded. Items whose
/// `added_at` is on or before the cutoff are excluded.
/// Returns a JSON array sorted by `added_at` descending
/// (newest first).
pub fn filter_recently_added(items_json: &str, cutoff_days: u32, now_ms: i64) -> String {
    let Some(items) = parse_json_vec::<VodItem>(items_json) else {
        return "[]".to_string();
    };

    // Cutoff = now - cutoff_days * 86_400_000 ms.
    let cutoff_ms = now_ms.saturating_sub(cutoff_days as i64 * 86_400_000);
    // Convert cutoff ms to NaiveDateTime for comparison.
    let cutoff_secs = cutoff_ms / 1000;
    let cutoff_nanos = ((cutoff_ms % 1000) * 1_000_000) as u32;
    let Some(cutoff_dt) =
        DateTime::from_timestamp(cutoff_secs, cutoff_nanos).map(|dt: DateTime<Utc>| dt.naive_utc())
    else {
        return "[]".to_string();
    };

    let mut recent: Vec<&VodItem> = items
        .iter()
        .filter(|i| i.added_at.as_ref().is_some_and(|dt| dt > &cutoff_dt))
        .collect();

    // Sort newest-first.
    recent.sort_by(|a, b| b.added_at.cmp(&a.added_at));

    serde_json::to_string(&recent).unwrap_or_else(|_| "[]".to_string())
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
    let Some(items) = parse_json_vec::<VodItem>(items_json) else {
        return "[]".to_string();
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
