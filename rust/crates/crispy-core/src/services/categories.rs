use std::collections::HashMap;

use rusqlite::params;

use super::{CrispyService, str_params};
use crate::database::DbError;
use crate::events::DataChangeEvent;
use crate::insert_or_replace;

/// Domain service for category operations.
pub struct CategoryService(pub(super) CrispyService);

impl CategoryService {
    // ── Categories ──────────────────────────────────

    /// Save categories for a specific source as type -> [names].
    /// Transactional replace: deletes existing categories for the
    /// source, then inserts new ones.
    pub fn save_categories(
        &self,
        source_id: &str,
        categories: &HashMap<String, Vec<String>>,
    ) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        let tx = conn.unchecked_transaction()?;
        tx.execute(
            "DELETE FROM db_categories WHERE source_id = ?1",
            params![source_id],
        )?;
        for (cat_type, names) in categories {
            for name in names {
                // Deterministic ID from (type, name, source_id).
                let id = format!("{cat_type}:{name}:{source_id}");
                tx.execute(
                    "INSERT INTO db_categories
                     (id, category_type, name, source_id)
                     VALUES (?1, ?2, ?3, ?4)",
                    params![id, cat_type, name, source_id],
                )?;
            }
        }
        tx.commit()?;
        self.0.emit(DataChangeEvent::BulkDataRefresh);
        Ok(())
    }

    /// Load all categories grouped by type.
    pub fn load_categories(&self) -> Result<HashMap<String, Vec<String>>, DbError> {
        let conn = self.0.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT category_type, name
             FROM db_categories
             ORDER BY category_type, name",
        )?;
        let rows = stmt.query_map([], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
        })?;
        let mut map: HashMap<String, Vec<String>> = HashMap::new();
        for r in rows {
            let (cat_type, name) = r?;
            map.entry(cat_type).or_default().push(name);
        }
        Ok(map)
    }

    /// Load categories filtered by source IDs, grouped by type.
    ///
    /// If `source_ids` is empty, all categories are returned
    /// (same behaviour as `load_categories()`). Otherwise only
    /// categories whose `source_id` is in the list are returned.
    pub fn get_categories_by_sources(
        &self,
        source_ids: &[String],
    ) -> Result<HashMap<String, Vec<String>>, DbError> {
        if source_ids.is_empty() {
            return self.load_categories();
        }
        let conn = self.0.db.get()?;
        let placeholders: Vec<String> = (1..=source_ids.len()).map(|i| format!("?{i}")).collect();
        let sql = format!(
            "SELECT category_type, name
             FROM db_categories
             WHERE source_id IN ({})
             ORDER BY category_type, name",
            placeholders.join(", ")
        );
        let mut stmt = conn.prepare(&sql)?;
        let params = str_params(source_ids);
        let rows = stmt.query_map(params.as_slice(), |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
        })?;
        let mut map: HashMap<String, Vec<String>> = HashMap::new();
        for r in rows {
            let (cat_type, name) = r?;
            map.entry(cat_type).or_default().push(name);
        }
        Ok(map)
    }

    // ── Favorite Categories ─────────────────────────

    /// Add a category to a profile's favourites.
    pub fn add_favorite_category(
        &self,
        profile_id: &str,
        category_type: &str,
        category_name: &str,
    ) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        let now = chrono::Utc::now().timestamp();
        insert_or_replace!(
            conn,
            "db_favorite_categories",
            ["profile_id", "category_type", "category_name", "added_at"],
            params![profile_id, category_type, category_name, now],
        )?;
        self.0.emit(DataChangeEvent::FavoriteCategoryToggled {
            category_type: category_type.to_string(),
            category_name: category_name.to_string(),
        });
        Ok(())
    }

    /// Remove a category from a profile's favourites.
    pub fn remove_favorite_category(
        &self,
        profile_id: &str,
        category_type: &str,
        category_name: &str,
    ) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        conn.execute(
            "DELETE FROM db_favorite_categories
             WHERE profile_id = ?1
             AND category_type = ?2
             AND category_name = ?3",
            params![profile_id, category_type, category_name,],
        )?;
        self.0.emit(DataChangeEvent::FavoriteCategoryToggled {
            category_type: category_type.to_string(),
            category_name: category_name.to_string(),
        });
        Ok(())
    }

    /// Get favourite category names for a profile
    /// and type.
    pub fn get_favorite_categories(
        &self,
        profile_id: &str,
        category_type: &str,
    ) -> Result<Vec<String>, DbError> {
        let conn = self.0.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT category_name
             FROM db_favorite_categories
             WHERE profile_id = ?1
             AND category_type = ?2",
        )?;
        let rows = stmt.query_map(params![profile_id, category_type], |row| row.get(0))?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }
}

#[cfg(test)]
mod tests {
    use std::collections::HashMap;

    use crate::services::test_helpers::*;
    use super::CategoryService;

    #[test]
    fn categories_crud() {
        let base = make_service();
        let src = make_source("s1", "S1", "m3u");
        base.save_source(&src).unwrap();
        let svc = CategoryService(base);

        let mut cats = HashMap::new();
        cats.insert(
            "live".to_string(),
            vec!["News".to_string(), "Sports".to_string()],
        );
        cats.insert("vod".to_string(), vec!["Action".to_string()]);
        svc.save_categories("s1", &cats).unwrap();

        let loaded = svc.load_categories().unwrap();
        assert_eq!(loaded["live"].len(), 2);
        assert_eq!(loaded["vod"].len(), 1);
    }

    #[test]
    fn favorite_categories_crud() {
        let base = make_service();
        base.save_profile(&make_profile("p1", "Alice")).unwrap();
        let svc = CategoryService(base);

        svc.add_favorite_category("p1", "live", "News").unwrap();
        svc.add_favorite_category("p1", "live", "Sports").unwrap();

        let favs = svc.get_favorite_categories("p1", "live").unwrap();
        assert_eq!(favs.len(), 2);
        assert!(favs.contains(&"News".to_string()));

        svc.remove_favorite_category("p1", "live", "News").unwrap();
        let favs = svc.get_favorite_categories("p1", "live").unwrap();
        assert_eq!(favs.len(), 1);
        assert_eq!(favs[0], "Sports");
    }
}
