use rusqlite::params;

use crate::insert_or_replace;
use super::{ServiceContext, vod::vod_item_from_row};
use crate::database::DbError;
use crate::events::DataChangeEvent;
use crate::models::VodItem;

/// Domain service for watchlist operations.
pub struct WatchlistService(pub ServiceContext);

impl WatchlistService {
    // ── Watchlist ──────────────────────────────────────────

    /// Get all full VOD items in a profile's watchlist, ordered by added_at (oldest first).
    pub fn get_watchlist_items(&self, profile_id: &str) -> Result<Vec<VodItem>, DbError> {
        use crate::models::columns::VOD_COLUMNS_V;
        let conn = self.0.db.get()?;
        let mut stmt = conn.prepare(&format!(
            "SELECT {VOD_COLUMNS_V}
             FROM db_movies v
             INNER JOIN db_watchlist w ON v.id = w.content_id
             WHERE w.profile_id = ?1
             ORDER BY w.added_at ASC",
        ))?;
        let rows = stmt.query_map(params![profile_id], vod_item_from_row)?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Add a VOD item to the watchlist.
    pub fn add_watchlist_item(&self, profile_id: &str, vod_item_id: &str) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        let now = chrono::Utc::now().timestamp();
        insert_or_replace!(
            conn,
            "db_watchlist",
            ["profile_id", "content_id", "content_type", "added_at"],
            params![profile_id, vod_item_id, "movie", now],
        )?;
        self.0.emit(DataChangeEvent::WatchlistUpdated {
            profile_id: profile_id.to_string(),
        });
        Ok(())
    }

    /// Remove a VOD item from the watchlist.
    pub fn remove_watchlist_item(
        &self,
        profile_id: &str,
        vod_item_id: &str,
    ) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        conn.execute(
            "DELETE FROM db_watchlist
             WHERE profile_id = ?1 AND content_id = ?2",
            params![profile_id, vod_item_id],
        )?;
        self.0.emit(DataChangeEvent::WatchlistUpdated {
            profile_id: profile_id.to_string(),
        });
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use super::WatchlistService;
    use crate::services::test_helpers::{make_profile, make_service, make_source, make_vod_item};

    /// Create a service with profile and source pre-seeded.
    /// Call `seed_vod` to add individual VOD items.
    fn make_watchlist_service() -> WatchlistService {
        let svc = make_service();
        crate::services::ProfileService(svc.clone())
            .save_profile(&make_profile("prof1", "Tester"))
            .unwrap();
        crate::services::SourceService(svc.clone())
            .save_source(&make_source("src1", "TestSrc", "m3u"))
            .unwrap();
        WatchlistService(svc)
    }

    /// Insert a single movie referencing the pre-seeded source.
    fn seed_vod(svc: &WatchlistService, vod_id: &str) {
        let mut movie = make_vod_item(vod_id, &format!("Movie {vod_id}"));
        movie.source_id = Some("src1".to_string());
        crate::services::VodService(svc.0.clone())
            .save_vod_items(&[movie])
            .unwrap();
    }

    // ── Basic CRUD ────────────────────────────────────

    #[test]
    fn add_and_retrieve_watchlist_item() {
        let svc = make_watchlist_service();
        seed_vod(&svc, "v1");

        svc.add_watchlist_item("prof1", "v1").unwrap();

        let items = svc.get_watchlist_items("prof1").unwrap();
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].id, "v1");
    }

    #[test]
    fn remove_watchlist_item() {
        let svc = make_watchlist_service();
        seed_vod(&svc, "v1");
        seed_vod(&svc, "v2");

        svc.add_watchlist_item("prof1", "v1").unwrap();
        svc.add_watchlist_item("prof1", "v2").unwrap();

        // Remove v1 — only v2 should remain.
        svc.remove_watchlist_item("prof1", "v1").unwrap();

        let items = svc.get_watchlist_items("prof1").unwrap();
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].id, "v2");
    }

    #[test]
    fn empty_watchlist_returns_empty_vec() {
        let svc = WatchlistService(make_service());

        let items = svc.get_watchlist_items("prof1").unwrap();
        assert!(items.is_empty());
    }

    #[test]
    fn add_duplicate_item_is_idempotent() {
        // INSERT OR REPLACE: adding the same vod_id twice
        // should not create a duplicate entry.
        let svc = make_watchlist_service();
        seed_vod(&svc, "v1");

        svc.add_watchlist_item("prof1", "v1").unwrap();
        svc.add_watchlist_item("prof1", "v1").unwrap();

        let items = svc.get_watchlist_items("prof1").unwrap();
        assert_eq!(items.len(), 1);
    }

    #[test]
    fn remove_nonexistent_item_is_no_error() {
        let svc = WatchlistService(make_service());

        // No items inserted — should not error.
        let result = svc.remove_watchlist_item("prof1", "nonexistent");
        assert!(result.is_ok());
    }

    #[test]
    fn watchlist_is_profile_scoped() {
        // Items added to prof1 must not appear for prof2.
        let svc = make_watchlist_service();
        seed_vod(&svc, "v1");

        svc.add_watchlist_item("prof1", "v1").unwrap();

        let items_prof2 = svc.get_watchlist_items("prof2").unwrap();
        assert!(
            items_prof2.is_empty(),
            "prof2 should have no watchlist items",
        );
        let items_prof1 = svc.get_watchlist_items("prof1").unwrap();
        assert_eq!(items_prof1.len(), 1);
    }

    #[test]
    fn multiple_items_ordered_by_added_at_asc() {
        let svc = make_watchlist_service();
        seed_vod(&svc, "v1");
        seed_vod(&svc, "v2");
        seed_vod(&svc, "v3");

        svc.add_watchlist_item("prof1", "v1").unwrap();
        // Small sleep between inserts to ensure distinct
        // timestamps on platforms where timestamp
        // resolution is 1-second.
        std::thread::sleep(std::time::Duration::from_millis(10));
        svc.add_watchlist_item("prof1", "v2").unwrap();
        std::thread::sleep(std::time::Duration::from_millis(10));
        svc.add_watchlist_item("prof1", "v3").unwrap();

        let items = svc.get_watchlist_items("prof1").unwrap();
        // Order: added_at ASC → v1 first, v3 last.
        assert_eq!(items[0].id, "v1");
        assert_eq!(items[2].id, "v3");
    }
}
