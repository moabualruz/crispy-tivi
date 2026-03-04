use rusqlite::params;

use super::{CrispyService, int_to_bool, opt_ts_to_dt};
use crate::database::DbError;
use crate::events::DataChangeEvent;
use crate::models::VodItem;

impl CrispyService {
    // ── Watchlist ──────────────────────────────────────────

    /// Get all full VOD items in a profile's watchlist, ordered by added_at (oldest first).
    pub fn get_watchlist_items(&self, profile_id: &str) -> Result<Vec<VodItem>, DbError> {
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT v.id, v.name, v.stream_url, v.type,
                    v.poster_url, v.backdrop_url,
                    v.description, v.rating, v.year,
                    v.duration, v.category, v.series_id,
                    v.season_number, v.episode_number,
                    v.ext, v.is_favorite, v.added_at,
                    v.updated_at, v.source_id
             FROM db_vod_items v
             INNER JOIN db_watchlist w ON v.id = w.vod_item_id
             WHERE w.profile_id = ?1
             ORDER BY w.added_at ASC",
        )?;
        let rows = stmt.query_map(params![profile_id], |row| {
            Ok(VodItem {
                id: row.get(0)?,
                name: row.get(1)?,
                stream_url: row.get(2)?,
                item_type: row.get(3)?,
                poster_url: row.get(4)?,
                backdrop_url: row.get(5)?,
                description: row.get(6)?,
                rating: row.get(7)?,
                year: row.get(8)?,
                duration: row.get(9)?,
                category: row.get(10)?,
                series_id: row.get(11)?,
                season_number: row.get(12)?,
                episode_number: row.get(13)?,
                ext: row.get(14)?,
                is_favorite: int_to_bool(row.get(15)?),
                added_at: opt_ts_to_dt(row.get(16)?),
                updated_at: opt_ts_to_dt(row.get(17)?),
                source_id: row.get(18)?,
            })
        })?;
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
