//! Shared helper functions for the recommendation engine.

use chrono::NaiveDateTime;

use crate::models::VodItem;

use super::types::Recommendation;

/// Sort recommendations by score descending and keep the
/// top `n`.
pub(super) fn top_n_by_score(items: &mut Vec<Recommendation>, n: usize) {
    items.sort_by(|a, b| b.score.total_cmp(&a.score));
    items.truncate(n);
}

/// Convert a `VodItem` to a `Recommendation`.
pub(super) fn vod_to_recommendation(item: &VodItem, reason: &str, score: f64) -> Recommendation {
    let parsed_rating = item.rating.as_deref().and_then(|r| r.parse::<f64>().ok());
    Recommendation {
        id: item.id.clone(),
        title: item.name.clone(),
        poster_url: item.poster_url.clone(),
        backdrop_url: item.backdrop_url.clone(),
        rating: parsed_rating,
        year: item.year,
        media_type: if item.item_type == "series" {
            "series".to_string()
        } else {
            "movie".to_string()
        },
        reason: reason.to_string(),
        score,
        category: item.category.clone(),
        stream_url: Some(item.stream_url.clone()),
        series_id: item.series_id.clone(),
    }
}

/// Convert epoch milliseconds to `NaiveDateTime`.
pub(super) fn naive_from_epoch_ms(ms: i64) -> NaiveDateTime {
    let secs = ms / 1000;
    let nsecs = ((ms % 1000) * 1_000_000) as u32;
    chrono::DateTime::from_timestamp(secs, nsecs)
        .unwrap_or_default()
        .naive_utc()
}

/// Capitalize the first letter of each word.
pub(super) fn title_case(input: &str) -> String {
    input
        .split(' ')
        .map(|w| {
            if w.is_empty() {
                w.to_string()
            } else {
                let mut chars = w.chars();
                match chars.next() {
                    None => String::new(),
                    Some(first) => {
                        let upper: String = first.to_uppercase().collect();
                        format!("{}{}", upper, chars.as_str())
                    }
                }
            }
        })
        .collect::<Vec<_>>()
        .join(" ")
}
