use std::collections::BTreeSet;

use crate::models::VodItem;

use super::VodCategoryMap;

/// Group VOD items by category, separating movie vs
/// series categories.
///
/// Input: JSON array of `VodItem`.
/// Output: JSON `VodCategoryMap`.
pub fn build_vod_category_map(items_json: &str) -> String {
    let items: Vec<VodItem> = match serde_json::from_str(items_json) {
        Ok(v) => v,
        Err(_) => {
            return serde_json::to_string(&VodCategoryMap {
                categories: vec![],
                movie_categories: vec![],
                series_categories: vec![],
            })
            .unwrap();
        }
    };

    let mut all_cats = BTreeSet::new();
    let mut movie_cats = BTreeSet::new();
    let mut series_cats = BTreeSet::new();

    for item in &items {
        if let Some(cat) = item.category.as_deref()
            && !cat.is_empty()
        {
            all_cats.insert(cat.to_string());
            match item.item_type.as_str() {
                "movie" => {
                    movie_cats.insert(cat.to_string());
                }
                "series" => {
                    series_cats.insert(cat.to_string());
                }
                _ => {}
            }
        }
    }

    let result = VodCategoryMap {
        categories: all_cats.into_iter().collect(),
        movie_categories: movie_cats.into_iter().collect(),
        series_categories: series_cats.into_iter().collect(),
    };

    serde_json::to_string(&result).unwrap_or_else(|_| "{}".to_string())
}
