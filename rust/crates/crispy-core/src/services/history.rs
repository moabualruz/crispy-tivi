use rusqlite::{Row, params};

use super::{CrispyService, dt_to_ts, ts_to_dt};
use crate::database::DbError;
use crate::errors::DomainError;
use crate::events::DataChangeEvent;
use crate::models::{EpisodeProgress, WatchHistory};
use crate::insert_or_replace;
use crate::traits::HistoryRepository;

fn watch_history_from_row(row: &Row) -> rusqlite::Result<WatchHistory> {
    Ok(WatchHistory {
        id: row.get(0)?,
        media_type: row
            .get::<_, String>(1)
            .map(|s| s.as_str().try_into().unwrap_or_default())
            .unwrap_or_default(),
        name: row.get(2)?,
        stream_url: row.get(3)?,
        poster_url: row.get(4)?,
        position_ms: row.get(5)?,
        duration_ms: row.get(6)?,
        last_watched: ts_to_dt(row.get(7)?),
        series_id: row.get(8)?,
        season_number: row.get(9)?,
        episode_number: row.get(10)?,
        device_id: row.get(11)?,
        device_name: row.get(12)?,
        series_poster_url: row.get(13)?,
        profile_id: row.get(14)?,
        source_id: row.get(15)?,
    })
}

impl CrispyService {
    // ── Watch History ───────────────────────────────

    /// Upsert a watch history entry.
    pub fn save_watch_history(&self, entry: &WatchHistory) -> Result<(), DbError> {
        let conn = self.db.get()?;
        insert_or_replace!(
            conn,
            "db_watch_history",
            [
                "id",
                "content_id",
                "media_type",
                "name",
                "stream_url",
                "poster_url",
                "position_ms",
                "duration_ms",
                "last_watched",
                "series_id",
                "season_number",
                "episode_number",
                "device_id",
                "device_name",
                "series_poster_url",
                "profile_id",
                "source_id",
            ],
            params![
                entry.id,
                entry.id, // content_id = id for backward compat
                entry.media_type.as_str(),
                entry.name,
                entry.stream_url,
                entry.poster_url,
                entry.position_ms,
                entry.duration_ms,
                dt_to_ts(&entry.last_watched),
                entry.series_id,
                entry.season_number,
                entry.episode_number,
                entry.device_id,
                entry.device_name,
                entry.series_poster_url,
                entry.profile_id,
                entry.source_id,
            ],
        )?;
        self.emit(DataChangeEvent::WatchHistoryUpdated {
            channel_id: entry.id.clone(),
        });
        Ok(())
    }

    /// Load all watch history ordered by last_watched
    /// descending.
    pub fn load_watch_history(&self) -> Result<Vec<WatchHistory>, DbError> {
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT
                id, media_type, name, stream_url,
                poster_url, position_ms, duration_ms,
                last_watched, series_id,
                season_number, episode_number,
                device_id, device_name, series_poster_url,
                profile_id, source_id
            FROM db_watch_history
            ORDER BY last_watched DESC",
        )?;
        let rows = stmt.query_map([], watch_history_from_row)?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Compute episode progress for a series by
    /// querying DB directly. Returns JSON:
    /// `{"progress_map": {"url": pct}, "last_watched_url": "..."}`
    pub fn compute_episode_progress_from_db(&self, series_id: &str) -> Result<String, DbError> {
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT stream_url, position_ms,
                    duration_ms, last_watched
             FROM db_watch_history
             WHERE series_id = ?1
             AND duration_ms > 0",
        )?;
        let rows = stmt.query_map(params![series_id], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, i64>(1)?,
                row.get::<_, i64>(2)?,
                row.get::<_, i64>(3)?,
            ))
        })?;

        let mut entries = Vec::new();
        for r in rows {
            entries.push(r?);
        }
        Ok(EpisodeProgress::compute(entries).to_json())
    }

    /// Delete a watch history entry by ID.
    pub fn delete_watch_history(&self, id: &str) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute(
            "DELETE FROM db_watch_history
             WHERE id = ?1",
            params![id],
        )?;
        self.emit(DataChangeEvent::WatchHistoryUpdated {
            channel_id: id.to_string(),
        });
        Ok(())
    }

    // clear_all_watch_history lives in bulk.rs (single canonical location)

    /// Load watch history filtered by profile, ordered by last_watched descending.
    pub fn load_watch_history_for_profile(
        &self,
        profile_id: &str,
    ) -> Result<Vec<WatchHistory>, DbError> {
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT
                id, media_type, name, stream_url,
                poster_url, position_ms, duration_ms,
                last_watched, series_id,
                season_number, episode_number,
                device_id, device_name, series_poster_url,
                profile_id, source_id
            FROM db_watch_history
            WHERE profile_id = ?1
            ORDER BY last_watched DESC
            LIMIT 100",
        )?;
        let rows = stmt.query_map(params![profile_id], watch_history_from_row)?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }
}

impl HistoryRepository for CrispyService {
    fn save_watch_history(&self, entry: &WatchHistory) -> Result<(), DomainError> {
        Ok(self.save_watch_history(entry)?)
    }

    fn load_watch_history(&self) -> Result<Vec<WatchHistory>, DomainError> {
        Ok(self.load_watch_history()?)
    }

    fn load_watch_history_for_profile(
        &self,
        profile_id: &str,
    ) -> Result<Vec<WatchHistory>, DomainError> {
        Ok(self.load_watch_history_for_profile(profile_id)?)
    }

    fn compute_episode_progress_from_db(
        &self,
        series_id: &str,
    ) -> Result<String, DomainError> {
        Ok(self.compute_episode_progress_from_db(series_id)?)
    }

    fn delete_watch_history(&self, id: &str) -> Result<(), DomainError> {
        Ok(self.delete_watch_history(id)?)
    }
}

#[cfg(test)]
mod tests {
    use crate::services::test_helpers::*;

    #[test]
    fn save_and_load_watch_history() {
        let svc = make_service();
        svc.save_watch_history(&make_watch_entry("w1", "Movie 1"))
            .unwrap();
        svc.save_watch_history(&make_watch_entry("w2", "Movie 2"))
            .unwrap();

        let loaded = svc.load_watch_history().unwrap();
        assert_eq!(loaded.len(), 2);
    }

    #[test]
    fn delete_watch_history_entry() {
        let svc = make_service();
        svc.save_watch_history(&make_watch_entry("w1", "Movie 1"))
            .unwrap();
        svc.save_watch_history(&make_watch_entry("w2", "Movie 2"))
            .unwrap();

        svc.delete_watch_history("w1").unwrap();
        let loaded = svc.load_watch_history().unwrap();
        assert_eq!(loaded.len(), 1);
        assert_eq!(loaded[0].id, "w2");
    }

    #[test]
    fn emit_watch_history_updated_on_save() {
        use crate::events::serialize_event;
        use std::sync::{Arc, Mutex};
        let svc = make_service();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        svc.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
        svc.save_watch_history(&make_watch_entry("w1", "Movie 1"))
            .unwrap();
        let recorded = log.lock().unwrap();
        let last = recorded.last().unwrap();
        assert!(last.contains("WatchHistoryUpdated"), "{last}");
        assert!(last.contains("\"channel_id\":\"w1\""), "{last}");
    }

    #[test]
    fn compute_episode_progress_from_db_basic() {
        let svc = make_service();
        svc.save_watch_history(&make_episode_entry(
            "w1",
            "http://stream1",
            "s1",
            5000,
            10000,
            "2024-01-01 00:00:00",
        ))
        .unwrap();
        svc.save_watch_history(&make_episode_entry(
            "w2",
            "http://stream2",
            "s1",
            8000,
            10000,
            "2024-01-02 00:00:00",
        ))
        .unwrap();
        svc.save_watch_history(&make_episode_entry(
            "w3",
            "http://other",
            "s2",
            3000,
            10000,
            "2024-01-03 00:00:00",
        ))
        .unwrap();

        let result = svc.compute_episode_progress_from_db("s1").unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&result).unwrap();

        let map = parsed["progress_map"].as_object().unwrap();
        assert_eq!(map.len(), 2);
        assert!((map["http://stream1"].as_f64().unwrap() - 0.5).abs() < 0.001);
        assert!((map["http://stream2"].as_f64().unwrap() - 0.8).abs() < 0.001);
        assert_eq!(parsed["last_watched_url"].as_str(), Some("http://stream2"),);
    }

    #[test]
    fn compute_episode_progress_from_db_empty() {
        let svc = make_service();
        let result = svc.compute_episode_progress_from_db("nonexistent").unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert!(parsed["progress_map"].as_object().unwrap().is_empty());
        assert!(parsed["last_watched_url"].is_null());
    }

    #[test]
    fn compute_episode_progress_excludes_zero_dur() {
        let svc = make_service();
        svc.save_watch_history(&make_episode_entry(
            "w1",
            "http://stream1",
            "s1",
            5000,
            0, // zero duration
            "2024-01-01 00:00:00",
        ))
        .unwrap();

        let result = svc.compute_episode_progress_from_db("s1").unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert!(parsed["progress_map"].as_object().unwrap().is_empty());
    }

    #[test]
    fn clear_all_watch_history_returns_count() {
        let svc = make_service();
        svc.save_watch_history(&make_watch_entry("w1", "Movie 1"))
            .unwrap();
        svc.save_watch_history(&make_watch_entry("w2", "Movie 2"))
            .unwrap();
        svc.save_watch_history(&make_watch_entry("w3", "Movie 3"))
            .unwrap();

        let deleted = svc.clear_all_watch_history().unwrap();
        assert_eq!(deleted, 3);

        let history = svc.load_watch_history().unwrap();
        assert!(history.is_empty());
    }

    #[test]
    fn clear_all_watch_history_empty_table() {
        let svc = make_service();
        let deleted = svc.clear_all_watch_history().unwrap();
        assert_eq!(deleted, 0);
    }

    #[test]
    fn emit_watch_history_cleared_on_clear_all() {
        use crate::events::serialize_event;
        use std::sync::{Arc, Mutex};
        let svc = make_service();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        svc.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
        svc.save_watch_history(&make_watch_entry("w1", "Movie 1"))
            .unwrap();
        svc.clear_all_watch_history().unwrap();
        let recorded = log.lock().unwrap();
        let last = recorded.last().unwrap();
        assert!(last.contains("WatchHistoryCleared"), "{last}");
    }

    #[test]
    fn save_and_load_watch_history_with_source_id() {
        let svc = make_service_with_fixtures();
        let mut entry = make_watch_entry("w1", "Movie With Source");
        entry.source_id = Some("src_a".to_string());
        svc.save_watch_history(&entry).unwrap();

        let loaded = svc.load_watch_history().unwrap();
        assert_eq!(loaded.len(), 1);
        assert_eq!(
            loaded[0].source_id,
            Some("src_a".to_string()),
            "source_id must be preserved after save/load round-trip"
        );
    }
}
