use rusqlite::params;

use super::{CrispyService, vod::vod_item_from_row};
use crate::database::DbError;
use crate::events::DataChangeEvent;
use crate::models::VodItem;

impl CrispyService {
    // ── Watchlist ──────────────────────────────────────────

    /// Get all full VOD items in a profile's watchlist, ordered by added_at (oldest first).
    pub fn get_watchlist_items(&self, profile_id: &str) -> Result<Vec<VodItem>, DbError> {
        use super::vod::VOD_COLUMNS_V;
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(&format!(
            "SELECT {VOD_COLUMNS_V}
             FROM db_vod_items v
             INNER JOIN db_watchlist w ON v.id = w.vod_item_id
             WHERE w.profile_id = ?1
             ORDER BY w.added_at ASC",
        ))?;
        let rows = stmt.query_map(params![profile_id], vod_item_from_row)?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Add a VOD item to the watchlist.
    pub fn add_watchlist_item(&self, profile_id: &str, vod_item_id: &str) -> Result<(), DbError> {
        let conn = self.db.get()?;
        let now = chrono::Utc::now().timestamp();
        conn.execute(
            "INSERT OR REPLACE INTO db_watchlist
             (profile_id, vod_item_id, added_at)
             VALUES (?1, ?2, ?3)",
            params![profile_id, vod_item_id, now],
        )?;
        self.emit(DataChangeEvent::WatchlistUpdated {
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
        let conn = self.db.get()?;
        conn.execute(
            "DELETE FROM db_watchlist
             WHERE profile_id = ?1 AND vod_item_id = ?2",
            params![profile_id, vod_item_id],
        )?;
        self.emit(DataChangeEvent::WatchlistUpdated {
            profile_id: profile_id.to_string(),
        });
        Ok(())
    }
}
