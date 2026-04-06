//! EPG cache staleness management for CrispyTivi.
//!
//! Queries the `db_epg_entries` table to determine freshness
//! and drives pruning of entries older than 14 days.

use crate::database::{Database, DbError, optional};

/// Maximum age (hours) before EPG data is considered stale.
const STALE_THRESHOLD_HOURS: i64 = 24;

/// How many days of EPG entries to retain.
const RETENTION_DAYS: i64 = 14;

// ── CacheStatus ──────────────────────────────────────────

/// Staleness classification for a source's EPG cache.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CacheStatus {
    /// Data was refreshed within the last 24 hours.
    Fresh,
    /// Data was last refreshed `hours_old` hours ago.
    Stale { hours_old: i64 },
    /// No EPG entries exist for this source.
    Empty,
}

// ── EpgCache ─────────────────────────────────────────────

/// EPG cache metadata service.
///
/// All methods require a `&Database` obtained from
/// `CrispyService` (or an in-memory test DB).
pub struct EpgCache;

impl EpgCache {
    /// Returns `true` if the EPG for `source_id` has not been
    /// refreshed within the last 24 hours, or if no entries
    /// exist at all.
    pub fn is_stale(db: &Database, source_id: &str) -> Result<bool, DbError> {
        Ok(!matches!(
            Self::get_staleness_info(db, source_id)?,
            CacheStatus::Fresh
        ))
    }

    /// How many calendar days of EPG data are available for
    /// `source_id`. Returns 0 when no entries exist.
    pub fn days_cached(db: &Database, source_id: &str) -> Result<i64, DbError> {
        let conn = db.get()?;
        // MIN/MAX return NULL on an empty result set; use Option<i64>.
        let result: rusqlite::Result<(Option<i64>, Option<i64>)> = conn.query_row(
            "SELECT MIN(start_time), MAX(end_time) \
             FROM db_epg_entries \
             WHERE source_id = ?1",
            rusqlite::params![source_id],
            |row| Ok((row.get::<_, Option<i64>>(0)?, row.get::<_, Option<i64>>(1)?)),
        );

        match result {
            Ok((Some(min_ts), Some(max_ts))) => {
                let diff_secs = max_ts.saturating_sub(min_ts);
                Ok(diff_secs / 86_400)
            }
            Ok(_) => Ok(0), // no entries — MIN/MAX both NULL
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(0),
            Err(e) => Err(DbError::Sqlite(e)),
        }
    }

    /// Delete EPG entries whose `end_time` is older than 14 days
    /// ago (Unix timestamp). Returns the number of rows deleted.
    pub fn prune_old_entries(db: &Database) -> Result<usize, DbError> {
        let cutoff = chrono::Utc::now().timestamp() - (RETENTION_DAYS * 86_400);
        let conn = db.get()?;
        let deleted = conn.execute(
            "DELETE FROM db_epg_entries WHERE end_time < ?1",
            rusqlite::params![cutoff],
        )?;
        Ok(deleted)
    }

    /// Classify the staleness of the EPG cache for `source_id`.
    ///
    /// Uses `db_sources.last_sync_time` to determine when the
    /// EPG for this source was last refreshed. Falls back to
    /// checking whether any entries exist at all.
    pub fn get_staleness_info(db: &Database, source_id: &str) -> Result<CacheStatus, DbError> {
        let conn = db.get()?;

        // Read last_sync_time from db_sources (db_sync_meta removed, D-5 cleanup).
        let sync_result: rusqlite::Result<Option<i64>> = conn.query_row(
            "SELECT last_sync_time FROM db_sources WHERE id = ?1",
            rusqlite::params![source_id],
            |row| row.get(0),
        );

        // Treat QueryReturnedNoRows (source not found) same as NULL sync time.
        match optional(sync_result)? {
            Some(Some(last_sync_ts)) => {
                let now = chrono::Utc::now().timestamp();
                let hours_old = (now - last_sync_ts) / 3600;
                if hours_old < STALE_THRESHOLD_HOURS {
                    Ok(CacheStatus::Fresh)
                } else {
                    Ok(CacheStatus::Stale { hours_old })
                }
            }
            // Source row exists but last_sync_time is NULL, or source row not found —
            // fall back to checking whether EPG entries exist.
            Some(None) | None => {
                let count: i64 = conn.query_row(
                    "SELECT COUNT(*) FROM db_epg_entries WHERE source_id = ?1",
                    rusqlite::params![source_id],
                    |row| row.get(0),
                )?;
                if count == 0 {
                    Ok(CacheStatus::Empty)
                } else {
                    // Entries exist but no sync timestamp → treat as stale.
                    Ok(CacheStatus::Stale {
                        hours_old: STALE_THRESHOLD_HOURS,
                    })
                }
            }
        }
    }
}

// ── Tests ─────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::database::Database;

    fn fresh_db() -> Database {
        Database::open_in_memory().expect("open_in_memory")
    }

    /// Seed a source row so FK constraints on db_epg_entries are satisfied.
    fn seed_source(db: &Database, id: &str) {
        db.get()
            .unwrap()
            .execute(
                "INSERT OR IGNORE INTO db_sources (id, name, source_type, url) \
                 VALUES (?1, ?1, 'm3u', 'http://test')",
                rusqlite::params![id],
            )
            .unwrap();
    }

    #[test]
    fn test_get_staleness_info_returns_empty_when_no_data() {
        let db = fresh_db();
        let status = EpgCache::get_staleness_info(&db, "source-1").unwrap();
        assert_eq!(status, CacheStatus::Empty);
    }

    #[test]
    fn test_is_stale_returns_true_when_empty() {
        let db = fresh_db();
        assert!(EpgCache::is_stale(&db, "source-1").unwrap());
    }

    #[test]
    fn test_get_staleness_info_fresh_when_recent_sync() {
        let db = fresh_db();
        let now = chrono::Utc::now().timestamp();
        seed_source(&db, "src-fresh");
        db.get()
            .unwrap()
            .execute(
                "UPDATE db_sources SET last_sync_time = ?1 WHERE id = ?2",
                rusqlite::params![now, "src-fresh"],
            )
            .unwrap();

        let status = EpgCache::get_staleness_info(&db, "src-fresh").unwrap();
        assert_eq!(status, CacheStatus::Fresh);
    }

    #[test]
    fn test_get_staleness_info_stale_when_old_sync() {
        let db = fresh_db();
        // 30 hours ago
        let old_ts = chrono::Utc::now().timestamp() - (30 * 3600);
        seed_source(&db, "src-old");
        db.get()
            .unwrap()
            .execute(
                "UPDATE db_sources SET last_sync_time = ?1 WHERE id = ?2",
                rusqlite::params![old_ts, "src-old"],
            )
            .unwrap();

        let status = EpgCache::get_staleness_info(&db, "src-old").unwrap();
        assert!(matches!(status, CacheStatus::Stale { hours_old } if hours_old >= 24));
    }

    #[test]
    fn test_is_stale_false_when_fresh() {
        let db = fresh_db();
        let now = chrono::Utc::now().timestamp();
        seed_source(&db, "src-now");
        db.get()
            .unwrap()
            .execute(
                "UPDATE db_sources SET last_sync_time = ?1 WHERE id = ?2",
                rusqlite::params![now, "src-now"],
            )
            .unwrap();

        assert!(!EpgCache::is_stale(&db, "src-now").unwrap());
    }

    #[test]
    fn test_days_cached_returns_zero_when_no_entries() {
        let db = fresh_db();
        let days = EpgCache::days_cached(&db, "source-x").unwrap();
        assert_eq!(days, 0);
    }

    #[test]
    fn test_days_cached_returns_correct_span() {
        let db = fresh_db();
        let now = chrono::Utc::now().timestamp();
        seed_source(&db, "src-days");
        let conn = db.get().unwrap();

        // Insert entries spanning ~3 days.
        conn.execute(
            "INSERT INTO db_epg_entries \
             (epg_channel_id, title, start_time, end_time, source_id) \
             VALUES ('ch1', 'Show A', ?1, ?2, 'src-days')",
            rusqlite::params![now - 3 * 86_400, now],
        )
        .unwrap();

        drop(conn);
        let days = EpgCache::days_cached(&db, "src-days").unwrap();
        assert_eq!(days, 3);
    }

    #[test]
    fn test_prune_old_entries_removes_stale_rows() {
        let db = fresh_db();
        let now = chrono::Utc::now().timestamp();
        seed_source(&db, "src-prune");
        let conn = db.get().unwrap();

        // Old entry (20 days ago).
        conn.execute(
            "INSERT INTO db_epg_entries \
             (epg_channel_id, title, start_time, end_time, source_id) \
             VALUES ('ch1', 'Old Show', ?1, ?2, 'src-prune')",
            rusqlite::params![now - 25 * 86_400, now - 20 * 86_400],
        )
        .unwrap();

        // Recent entry.
        conn.execute(
            "INSERT INTO db_epg_entries \
             (epg_channel_id, title, start_time, end_time, source_id) \
             VALUES ('ch2', 'New Show', ?1, ?2, 'src-prune')",
            rusqlite::params![now - 86_400, now + 86_400],
        )
        .unwrap();

        drop(conn);

        let deleted = EpgCache::prune_old_entries(&db).unwrap();
        assert_eq!(deleted, 1, "should delete exactly the old entry");

        let remaining: i64 = db
            .get()
            .unwrap()
            .query_row(
                "SELECT COUNT(*) FROM db_epg_entries WHERE source_id = 'src-prune'",
                [],
                |r| r.get(0),
            )
            .unwrap();
        assert_eq!(remaining, 1);
    }
}
