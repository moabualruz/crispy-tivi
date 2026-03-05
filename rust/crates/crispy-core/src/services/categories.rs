use std::collections::HashMap;

use rusqlite::params;

use super::CrispyService;
use crate::database::DbError;
use crate::events::DataChangeEvent;

impl CrispyService {
    // ── Categories ──────────────────────────────────

    /// Save categories as type -> [names].
    /// Transactional replace: deletes all existing,
    /// then inserts new.
    pub fn save_categories(
        &self,
        categories: &HashMap<String, Vec<String>>,
    ) -> Result<(), DbError> {
        let conn = self.db.get()?;
        let tx = conn.unchecked_transaction()?;
        tx.execute("DELETE FROM db_categories", [])?;
        for (cat_type, names) in categories {
            for name in names {
                tx.execute(
                    "INSERT INTO db_categories
                     (category_type, name)
                     VALUES (?1, ?2)",
                    params![cat_type, name],
                )?;
            }
        }
        tx.commit()?;
        self.emit(DataChangeEvent::BulkDataRefresh);
        Ok(())
    }

    /// Load all categories grouped by type.
    pub fn load_categories(&self) -> Result<HashMap<String, Vec<String>>, DbError> {
        let conn = self.db.get()?;
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
        let conn = self.db.get()?;
        let placeholders: Vec<String> = (1..=source_ids.len()).map(|i| format!("?{i}")).collect();
        let sql = format!(
            "SELECT category_type, name
             FROM db_categories
             WHERE source_id IN ({})
             ORDER BY category_type, name",
            placeholders.join(", ")
        );
        let mut stmt = conn.prepare(&sql)?;
        let params: Vec<&dyn rusqlite::types::ToSql> = source_ids
            .iter()
            .map(|s| s as &dyn rusqlite::types::ToSql)
            .collect();
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
        let conn = self.db.get()?;
        let now = chrono::Utc::now().timestamp();
        conn.execute(
            "INSERT OR REPLACE INTO
             db_favorite_categories (
                 profile_id, category_type,
                 category_name, added_at
             ) VALUES (?1, ?2, ?3, ?4)",
            params![profile_id, category_type, category_name, now,],
        )?;
        self.emit(DataChangeEvent::FavoriteCategoryToggled {
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
        let conn = self.db.get()?;
        conn.execute(
            "DELETE FROM db_favorite_categories
             WHERE profile_id = ?1
             AND category_type = ?2
             AND category_name = ?3",
            params![profile_id, category_type, category_name,],
        )?;
        self.emit(DataChangeEvent::FavoriteCategoryToggled {
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
        let conn = self.db.get()?;
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

    #[test]
    fn categories_crud() {
        let svc = make_service();
        let mut cats = HashMap::new();
        cats.insert(
            "live".to_string(),
            vec!["News".to_string(), "Sports".to_string()],
        );
        cats.insert("vod".to_string(), vec!["Action".to_string()]);
        svc.save_categories(&cats).unwrap();

        let loaded = svc.load_categories().unwrap();
        assert_eq!(loaded["live"].len(), 2);
        assert_eq!(loaded["vod"].len(), 1);
    }

    #[test]
    fn favorite_categories_crud() {
        let svc = make_service();
        svc.save_profile(&make_profile("p1", "Alice")).unwrap();

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
