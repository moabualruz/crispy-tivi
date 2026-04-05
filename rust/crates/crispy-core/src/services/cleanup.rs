use anyhow::Result;

use super::CrispyService;

// ── TTL constants ────────────────────────────────────

/// Hard-delete soft-deleted sources older than this many seconds (30 days).
const SOURCE_SOFT_DELETE_TTL_SECS: i64 = 30 * 24 * 3600;

/// Hard-delete bookmarks older than this many seconds (90 days).
const BOOKMARK_TTL_SECS: i64 = 90 * 24 * 3600;

/// Hard-delete stream health entries older than this many seconds (7 days).
const STREAM_HEALTH_TTL_SECS: i64 = 7 * 24 * 3600;

/// Hard-delete EPG entries whose end_time is older than this many seconds (24 hours).
const EPG_PAST_TTL_SECS: i64 = 24 * 3600;

/// Minimum total rows deleted before VACUUM is triggered (avoids unnecessary I/O).
const VACUUM_THRESHOLD: usize = 1000;

/// Run all startup maintenance cleanup tasks.
///
/// Performs four TTL-based purges in sequence:
///
/// 1. **Expired soft-deleted sources** — hard-deletes `db_sources` rows
///    where `deleted_at` is set and older than 30 days. `ON DELETE CASCADE`
///    propagates to channels, EPG, VOD, bookmarks, etc.
///
/// 2. **Stale bookmarks** — deletes `db_bookmarks` rows created more than
///    90 days ago. Bookmarks have no FK parent so TTL is the only cleanup
///    mechanism.
///
/// 3. **Stale stream health entries** — deletes `db_stream_health` rows
///    whose `last_seen` timestamp is older than 7 days.
///
/// 4. **Past EPG entries** — deletes `db_epg_entries` whose `end_time` is
///    more than 24 hours in the past to keep the EPG table lean.
///
/// 5. **VACUUM** — compacts the SQLite file if the total rows deleted across
///    all steps exceeded [`VACUUM_THRESHOLD`] (1 000 rows).
///
/// Failures are returned as errors; the caller in `lifecycle.rs` logs a
/// warning and continues — a cleanup failure must never block app startup.
pub fn run_startup_cleanup(service: &CrispyService) -> Result<()> {
    let now = chrono::Utc::now().timestamp();
    let conn = service.db.get()?; // ONE connection for all cleanup
    let mut total_deleted: usize = 0;

    // ── 1. Expired soft-deleted sources (30-day retention) ──────────────
    {
        let cutoff = now - SOURCE_SOFT_DELETE_TTL_SECS;
        let deleted = conn.execute(
            "DELETE FROM db_sources
             WHERE deleted_at IS NOT NULL
               AND deleted_at < ?1",
            rusqlite::params![cutoff],
        )?;
        if deleted > 0 {
            eprintln!(
                "[cleanup] hard-deleted {deleted} expired soft-deleted source(s)"
            );
        }
        total_deleted += deleted;
    }

    // ── 2. Expired bookmarks (90-day TTL) ────────────────────────────────
    {
        let cutoff = now - BOOKMARK_TTL_SECS;
        let deleted = conn.execute(
            "DELETE FROM db_bookmarks
             WHERE created_at < ?1",
            rusqlite::params![cutoff],
        )?;
        if deleted > 0 {
            eprintln!("[cleanup] deleted {deleted} expired bookmark(s)");
        }
        total_deleted += deleted;
    }

    // ── 3. Stale stream health entries (7-day TTL) ───────────────────────
    {
        let cutoff = now - STREAM_HEALTH_TTL_SECS;
        let deleted = conn.execute(
            "DELETE FROM db_stream_health
             WHERE last_seen < ?1",
            rusqlite::params![cutoff],
        )?;
        if deleted > 0 {
            eprintln!("[cleanup] deleted {deleted} stale stream_health entry/entries");
        }
        total_deleted += deleted;
    }

    // ── 4. Past EPG entries (>24 h in the past) ──────────────────────────
    {
        let cutoff = now - EPG_PAST_TTL_SECS;
        let deleted = conn.execute(
            "DELETE FROM db_epg_entries
             WHERE end_time < ?1",
            rusqlite::params![cutoff],
        )?;
        if deleted > 0 {
            eprintln!("[cleanup] deleted {deleted} stale EPG entry/entries");
        }
        total_deleted += deleted;
    }

    // Drop the main connection before VACUUM (VACUUM needs exclusive access)
    drop(conn);

    // ── 5. VACUUM if significant rows were removed ────────────────────────
    if total_deleted >= VACUUM_THRESHOLD {
        eprintln!("[cleanup] {total_deleted} rows deleted — running VACUUM to compact DB");
        let vconn = service.db.get()?;
        vconn.execute_batch("VACUUM")?;
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::services::test_helpers::*;

    // ── helpers ──────────────────────────────────────────────────────────

    fn insert_source_deleted_at(svc: &CrispyService, id: &str, deleted_at: i64) {
        let conn = svc.db.get().unwrap();
        // Insert a minimal source row then mark it soft-deleted.
        conn.execute(
            "INSERT OR REPLACE INTO db_sources
             (id, name, source_type, url, enabled, sort_order,
              refresh_interval_minutes, accept_self_signed,
              credentials_encrypted, deleted_at)
             VALUES (?1, ?2, 'm3u', 'http://example.com', 1, 0, 60, 0, 0, ?3)",
            rusqlite::params![id, id, deleted_at],
        )
        .unwrap();
    }

    fn insert_bookmark_created_at(svc: &CrispyService, id: &str, created_at: i64) {
        let conn = svc.db.get().unwrap();
        conn.execute(
            "INSERT OR REPLACE INTO db_bookmarks
             (id, content_id, content_type, position_ms, created_at)
             VALUES (?1, 'c1', 'vod', 0, ?2)",
            rusqlite::params![id, created_at],
        )
        .unwrap();
    }

    fn insert_stream_health_last_seen(svc: &CrispyService, hash: &str, last_seen: i64) {
        let conn = svc.db.get().unwrap();
        conn.execute(
            "INSERT OR REPLACE INTO db_stream_health
             (url_hash, stall_count, buffer_sum, buffer_samples, ttff_ms, last_seen)
             VALUES (?1, 0, 0, 0, 0, ?2)",
            rusqlite::params![hash, last_seen],
        )
        .unwrap();
    }

    fn insert_epg_entry_end_time(svc: &CrispyService, _id: &str, end_time: i64) {
        let conn = svc.db.get().unwrap();
        // start_time must be < end_time per CHECK constraint.
        let start_time = end_time - 3600;
        // source_id is NULL to avoid a FK constraint against db_sources.
        conn.execute(
            "INSERT OR REPLACE INTO db_epg_entries
             (source_id, epg_channel_id, start_time, end_time, title, is_placeholder)
             VALUES (NULL, 'ch1', ?1, ?2, 'Test', 0)",
            rusqlite::params![start_time, end_time],
        )
        .unwrap();
    }

    fn count_rows(svc: &CrispyService, table: &str) -> i64 {
        let conn = svc.db.get().unwrap();
        conn.query_row(&format!("SELECT COUNT(*) FROM {table}"), [], |row| {
            row.get(0)
        })
        .unwrap()
    }

    // ── tests ─────────────────────────────────────────────────────────────

    #[test]
    fn cleanup_noop_on_empty_db() {
        let svc = make_service();
        run_startup_cleanup(&svc).unwrap();
        // No rows — should complete without error.
    }

    #[test]
    fn cleanup_hard_deletes_expired_sources() {
        let svc = make_service();
        let now = chrono::Utc::now().timestamp();
        // 31 days ago — past the 30-day cutoff.
        let expired = now - 31 * 24 * 3600;
        // 29 days ago — within retention window.
        let recent = now - 29 * 24 * 3600;

        insert_source_deleted_at(&svc, "src_expired", expired);
        insert_source_deleted_at(&svc, "src_recent", recent);

        run_startup_cleanup(&svc).unwrap();

        // Only the expired source should be gone.
        let conn = svc.db.get().unwrap();
        let remaining: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM db_sources WHERE deleted_at IS NOT NULL",
                [],
                |r| r.get(0),
            )
            .unwrap();
        assert_eq!(remaining, 1, "only the recent soft-delete should survive");
    }

    #[test]
    fn cleanup_preserves_active_sources() {
        let svc = make_service();
        svc.save_source(&make_source("active_src", "Active", "m3u"))
            .unwrap();
        run_startup_cleanup(&svc).unwrap();
        assert!(svc.get_source("active_src").unwrap().is_some());
    }

    #[test]
    fn cleanup_deletes_expired_bookmarks() {
        let svc = make_service();
        let now = chrono::Utc::now().timestamp();
        // 91 days ago — past 90-day TTL.
        insert_bookmark_created_at(&svc, "bm_old", now - 91 * 24 * 3600);
        // 89 days ago — within TTL.
        insert_bookmark_created_at(&svc, "bm_new", now - 89 * 24 * 3600);

        run_startup_cleanup(&svc).unwrap();

        assert_eq!(count_rows(&svc, "db_bookmarks"), 1);
    }

    #[test]
    fn cleanup_deletes_stale_stream_health() {
        let svc = make_service();
        let now = chrono::Utc::now().timestamp();
        // 8 days ago — past 7-day TTL.
        insert_stream_health_last_seen(&svc, "stale_hash", now - 8 * 24 * 3600);
        // 6 days ago — within TTL.
        insert_stream_health_last_seen(&svc, "fresh_hash", now - 6 * 24 * 3600);

        run_startup_cleanup(&svc).unwrap();

        assert_eq!(count_rows(&svc, "db_stream_health"), 1);
    }

    #[test]
    fn cleanup_deletes_past_epg_entries() {
        let svc = make_service();
        let now = chrono::Utc::now().timestamp();
        // Ended 25 hours ago — past the 24-hour cutoff.
        insert_epg_entry_end_time(&svc, "epg_old", now - 25 * 3600);
        // Ended 23 hours ago — still within window.
        insert_epg_entry_end_time(&svc, "epg_new", now - 23 * 3600);

        run_startup_cleanup(&svc).unwrap();

        assert_eq!(count_rows(&svc, "db_epg_entries"), 1);
    }

    #[test]
    fn cleanup_is_idempotent() {
        let svc = make_service();
        let now = chrono::Utc::now().timestamp();
        insert_bookmark_created_at(&svc, "bm_old", now - 91 * 24 * 3600);

        run_startup_cleanup(&svc).unwrap();
        run_startup_cleanup(&svc).unwrap(); // second run should be a no-op
        assert_eq!(count_rows(&svc, "db_bookmarks"), 0);
    }
}
