use crate::algorithms::json_utils::parse_json_vec;
use crate::models::VodItem;

use super::{
    SORT_ADDED_DESC, SORT_NAME_ASC, SORT_NAME_DESC, SORT_RATING_DESC, SORT_YEAR_DESC, parse_rating,
};

/// Sort VOD items by the given criterion.
///
/// Supported `sort_by` values:
/// - `"added_desc"` — most recently added first (default)
/// - `"name_asc"`   — alphabetical A-Z
/// - `"name_desc"`  — alphabetical Z-A
/// - `"year_desc"`  — newest release year first
/// - `"rating_desc"` — highest rating first
///
/// Input/output: JSON arrays of `VodItem`.
pub fn sort_vod_items(items_json: &str, sort_by: &str) -> String {
    let Some(mut items) = parse_json_vec::<VodItem>(items_json) else {
        return "[]".to_string();
    };

    match sort_by {
        SORT_ADDED_DESC => {
            items.sort_by(|a, b| {
                let a_ts = a.added_at.as_ref();
                let b_ts = b.added_at.as_ref();
                // Nulls last: items without added_at after
                // those with.
                match (b_ts, a_ts) {
                    (Some(bt), Some(at)) => bt.cmp(at),
                    (Some(_), None) => std::cmp::Ordering::Less,
                    (None, Some(_)) => std::cmp::Ordering::Greater,
                    (None, None) => std::cmp::Ordering::Equal,
                }
            });
        }
        SORT_NAME_ASC => {
            items.sort_by_cached_key(|item| item.name.to_lowercase());
        }
        SORT_NAME_DESC => {
            items.sort_by_cached_key(|item| std::cmp::Reverse(item.name.to_lowercase()));
        }
        SORT_YEAR_DESC => {
            items.sort_by(|a, b| {
                // Nulls-last: items without a year sort after
                // those with a year.
                match (a.year, b.year) {
                    (None, None) => std::cmp::Ordering::Equal,
                    (None, _) => std::cmp::Ordering::Greater,
                    (_, None) => std::cmp::Ordering::Less,
                    (Some(ay), Some(by)) => by.cmp(&ay),
                }
            });
        }
        SORT_RATING_DESC => {
            items.sort_by(|a, b| {
                let ra = parse_rating(a.rating.as_deref());
                let rb = parse_rating(b.rating.as_deref());
                // NaN sorts last (after all real values).
                rb.total_cmp(&ra)
            });
        }
        // Unknown sort_by → no-op (return as-is).
        _ => {}
    }

    serde_json::to_string(&items).unwrap_or_else(|_| "[]".to_string())
}
