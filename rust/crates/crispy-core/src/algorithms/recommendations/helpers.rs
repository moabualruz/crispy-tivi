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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::VodItem;

    fn make_vod(id: &str, name: &str, item_type: &str) -> VodItem {
        VodItem {
            id: id.to_string(),
            name: name.to_string(),
            stream_url: "http://stream".to_string(),
            item_type: item_type.to_string(),
            poster_url: None,
            backdrop_url: None,
            description: None,
            rating: None,
            year: None,
            duration: None,
            category: None,
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

    // ── title_case ──────────────────────────────────

    #[test]
    fn test_title_case_capitalizes_each_word() {
        assert_eq!(title_case("action comedy"), "Action Comedy");
    }

    #[test]
    fn test_title_case_already_capitalized_is_unchanged() {
        assert_eq!(title_case("Horror"), "Horror");
    }

    #[test]
    fn test_title_case_empty_string_returns_empty() {
        assert_eq!(title_case(""), "");
    }

    #[test]
    fn test_title_case_single_word() {
        assert_eq!(title_case("drama"), "Drama");
    }

    #[test]
    fn test_title_case_preserves_non_first_chars() {
        assert_eq!(title_case("sci-fi thriller"), "Sci-fi Thriller");
    }

    // ── naive_from_epoch_ms ─────────────────────────

    #[test]
    fn test_naive_from_epoch_ms_zero_returns_epoch() {
        let dt = naive_from_epoch_ms(0);
        assert_eq!(dt.and_utc().timestamp(), 0);
    }

    #[test]
    fn test_naive_from_epoch_ms_positive_value() {
        // 1_000 ms = 1 second past epoch
        let dt = naive_from_epoch_ms(1_000);
        assert_eq!(dt.and_utc().timestamp(), 1);
    }

    #[test]
    fn test_naive_from_epoch_ms_sub_second_precision() {
        // 1_500 ms = 1s + 500ms
        let dt = naive_from_epoch_ms(1_500);
        assert_eq!(dt.and_utc().timestamp(), 1);
        assert_eq!(dt.and_utc().timestamp_subsec_millis(), 500);
    }

    // ── top_n_by_score ──────────────────────────────

    #[test]
    fn test_top_n_by_score_returns_highest_scores() {
        let vod = make_vod("v1", "Film", "movie");
        let mut items = vec![
            vod_to_recommendation(&vod, "r", 0.3),
            vod_to_recommendation(&vod, "r", 0.9),
            vod_to_recommendation(&vod, "r", 0.1),
            vod_to_recommendation(&vod, "r", 0.7),
        ];
        top_n_by_score(&mut items, 2);
        assert_eq!(items.len(), 2);
        assert_eq!(items[0].score, 0.9);
        assert_eq!(items[1].score, 0.7);
    }

    #[test]
    fn test_top_n_by_score_empty_input_stays_empty() {
        let mut items: Vec<Recommendation> = vec![];
        top_n_by_score(&mut items, 5);
        assert!(items.is_empty());
    }

    #[test]
    fn test_top_n_by_score_n_larger_than_list_keeps_all() {
        let vod = make_vod("v1", "Film", "movie");
        let mut items = vec![
            vod_to_recommendation(&vod, "r", 0.5),
            vod_to_recommendation(&vod, "r", 0.8),
        ];
        top_n_by_score(&mut items, 10);
        assert_eq!(items.len(), 2);
        assert_eq!(items[0].score, 0.8);
    }

    // ── vod_to_recommendation ───────────────────────

    #[test]
    fn test_vod_to_recommendation_movie_type_maps_to_movie() {
        let vod = make_vod("v1", "Inception", "movie");
        let rec = vod_to_recommendation(&vod, "topPick", 0.9);
        assert_eq!(rec.media_type, "movie");
        assert_eq!(rec.reason, "topPick");
        assert_eq!(rec.score, 0.9);
        assert_eq!(rec.id, "v1");
        assert_eq!(rec.title, "Inception");
    }

    #[test]
    fn test_vod_to_recommendation_series_type_maps_to_series() {
        let vod = make_vod("s1", "Breaking Bad", "series");
        let rec = vod_to_recommendation(&vod, "trending", 0.5);
        assert_eq!(rec.media_type, "series");
    }

    #[test]
    fn test_vod_to_recommendation_episode_maps_to_movie() {
        // episodes are not series at top-level; media_type branch is series vs other
        let vod = make_vod("e1", "Ep1", "episode");
        let rec = vod_to_recommendation(&vod, "r", 0.1);
        assert_eq!(rec.media_type, "movie");
    }

    #[test]
    fn test_vod_to_recommendation_rating_parsed_from_string() {
        let mut vod = make_vod("v1", "Film", "movie");
        vod.rating = Some("7.5".to_string());
        let rec = vod_to_recommendation(&vod, "r", 0.5);
        assert_eq!(rec.rating, Some(7.5));
    }

    #[test]
    fn test_vod_to_recommendation_invalid_rating_becomes_none() {
        let mut vod = make_vod("v1", "Film", "movie");
        vod.rating = Some("not-a-number".to_string());
        let rec = vod_to_recommendation(&vod, "r", 0.5);
        assert!(rec.rating.is_none());
    }

    #[test]
    fn test_vod_to_recommendation_stream_url_always_set() {
        let vod = make_vod("v1", "Film", "movie");
        let rec = vod_to_recommendation(&vod, "r", 0.5);
        assert_eq!(rec.stream_url.as_deref(), Some("http://stream"));
    }
}
