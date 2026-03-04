use std::collections::HashMap;

use rusqlite::params;

use super::{CrispyService, dt_to_ts, ts_to_dt};
use crate::database::DbError;
use crate::events::DataChangeEvent;
use crate::models::EpgEntry;

impl CrispyService {
    // ── EPG ─────────────────────────────────────────

    /// Batch upsert EPG entries grouped by channel.
    /// Returns total count inserted.
    pub fn save_epg_entries(
        &self,
        entries: &HashMap<String, Vec<EpgEntry>>,
    ) -> Result<usize, DbError> {
        let conn = self.db.get()?;
        let tx = conn.unchecked_transaction()?;
        let mut count = 0usize;
        for (matched_channel_id, epgs) in entries.iter() {
            for e in epgs {
                tx.execute(
                    "INSERT OR REPLACE INTO
                     db_epg_entries (
                         channel_id, title,
                         start_time, end_time,
                         description, category,
                         icon_url
                     ) VALUES (
                         ?1, ?2, ?3, ?4, ?5, ?6, ?7
                     )",
                    params![
                        matched_channel_id,
                        e.title,
                        dt_to_ts(&e.start_time),
                        dt_to_ts(&e.end_time),
                        e.description,
                        e.category,
                        e.icon_url,
                    ],
                )?;
                count += 1;
            }
        }
        tx.commit()?;
        // Emit one EpgUpdated event per distinct channel so that
        // each channel's subscribers are notified deterministically.
        // Using sorted keys avoids non-deterministic HashMap iteration.
        let mut channel_ids: Vec<&String> = entries.keys().collect();
        channel_ids.sort();
        for channel_id in channel_ids {
            self.emit(DataChangeEvent::EpgUpdated {
                source_id: channel_id.clone(),
            });
        }
        if entries.is_empty() {
            self.emit(DataChangeEvent::EpgUpdated {
                source_id: String::new(),
            });
        }
        #[cfg(debug_assertions)]
        eprintln!("[debug] Inserted {} EPG entries", count);
        Ok(count)
    }

    /// Load all EPG entries grouped by channel_id.
    pub fn load_epg_entries(&self) -> Result<HashMap<String, Vec<EpgEntry>>, DbError> {
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT
                channel_id, title, start_time,
                end_time, description, category,
                icon_url
            FROM db_epg_entries
            ORDER BY channel_id, start_time",
        )?;
        let rows = stmt.query_map([], |row| {
            Ok(EpgEntry {
                channel_id: row.get(0)?,
                title: row.get(1)?,
                start_time: ts_to_dt(row.get(2)?),
                end_time: ts_to_dt(row.get(3)?),
                description: row.get(4)?,
                category: row.get(5)?,
                icon_url: row.get(6)?,
            })
        })?;
        let mut map: HashMap<String, Vec<EpgEntry>> = HashMap::new();
        for r in rows {
            let entry = r?;
            map.entry(entry.channel_id.clone()).or_default().push(entry);
        }
        Ok(map)
    }

    /// Load EPG entries for a specific set of channels within a time window.
    pub fn get_epgs_for_channels(
        &self,
        channel_ids: &[String],
        start_time: i64,
        end_time: i64,
    ) -> Result<HashMap<String, Vec<EpgEntry>>, DbError> {
        let conn = self.db.get()?;
        if channel_ids.is_empty() {
            return Ok(HashMap::new());
        }

        let placeholders: Vec<String> = (1..=channel_ids.len()).map(|i| format!("?{i}")).collect();
        let query = format!(
            "SELECT
                channel_id, title, start_time,
                end_time, description, category,
                icon_url
            FROM db_epg_entries
            WHERE channel_id IN ({})
              AND end_time > ?{}
              AND start_time < ?{}
            ORDER BY channel_id, start_time",
            placeholders.join(", "),
            channel_ids.len() + 1,
            channel_ids.len() + 2
        );

        let mut stmt = conn.prepare(&query)?;

        let mut params: Vec<&dyn rusqlite::types::ToSql> =
            Vec::with_capacity(channel_ids.len() + 2);
        for id in channel_ids {
            params.push(id as &dyn rusqlite::types::ToSql);
        }
        params.push(&start_time as &dyn rusqlite::types::ToSql);
        params.push(&end_time as &dyn rusqlite::types::ToSql);

        let rows = stmt.query_map(params.as_slice(), |row| {
            Ok(EpgEntry {
                channel_id: row.get(0)?,
                title: row.get(1)?,
                start_time: ts_to_dt(row.get(2)?),
                end_time: ts_to_dt(row.get(3)?),
                description: row.get(4)?,
                category: row.get(5)?,
                icon_url: row.get(6)?,
            })
        })?;

        let mut map: HashMap<String, Vec<EpgEntry>> = HashMap::new();
        for r in rows {
            let entry = r?;
            map.entry(entry.channel_id.clone()).or_default().push(entry);
        }
        Ok(map)
    }

    /// Delete EPG entries older than `days` days.
    /// Returns count deleted.
    pub fn evict_stale_epg(&self, days: i64) -> Result<usize, DbError> {
        let conn = self.db.get()?;
        let cutoff = chrono::Utc::now().timestamp() - (days * 86400);
        let deleted = conn.execute(
            "DELETE FROM db_epg_entries
             WHERE end_time < ?1",
            params![cutoff],
        )?;
        Ok(deleted)
    }

    /// Delete all EPG entries.
    pub fn clear_epg_entries(&self) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute("DELETE FROM db_epg_entries", [])?;
        self.emit(DataChangeEvent::BulkDataRefresh);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::services::test_helpers::*;

    #[test]
    fn save_and_load_epg_entries() {
        let svc = make_service();
        let dt = parse_dt("2025-01-15 10:00:00");
        let dt_end = parse_dt("2025-01-15 11:00:00");
        let entry = EpgEntry {
            channel_id: "ch1".to_string(),
            title: "News".to_string(),
            start_time: dt,
            end_time: dt_end,
            description: None,
            category: None,
            icon_url: None,
        };
        let mut map = HashMap::new();
        map.insert("ch1".to_string(), vec![entry]);
        let count = svc.save_epg_entries(&map).unwrap();
        assert_eq!(count, 1);

        let loaded = svc.load_epg_entries().unwrap();
        assert_eq!(loaded["ch1"].len(), 1);
        assert_eq!(loaded["ch1"][0].title, "News");
    }

    #[test]
    fn get_epgs_for_channels_filters_by_window() {
        let svc = make_service();
        let dt = parse_dt("2025-01-15 10:00:00");
        let dt_end = parse_dt("2025-01-15 11:00:00");
        let entry = EpgEntry {
            channel_id: "ch1".to_string(),
            title: "News".to_string(),
            start_time: dt,
            end_time: dt_end,
            description: None,
            category: None,
            icon_url: None,
        };
        let mut map = HashMap::new();
        map.insert("ch1".to_string(), vec![entry]);
        svc.save_epg_entries(&map).unwrap();

        // Window that includes the entry.
        let in_window = svc
            .get_epgs_for_channels(
                &["ch1".to_string()],
                dt.and_utc().timestamp() - 1,
                dt_end.and_utc().timestamp() + 1,
            )
            .unwrap();
        assert_eq!(in_window["ch1"].len(), 1);

        // Window before the entry.
        let before = svc
            .get_epgs_for_channels(&["ch1".to_string()], 0, dt.and_utc().timestamp() - 1)
            .unwrap();
        assert!(before.is_empty() || before.get("ch1").map(|v| v.is_empty()).unwrap_or(true));
    }

    #[test]
    fn evict_stale_epg_removes_old_entries() {
        let svc = make_service();
        // Insert an old entry (far in the past).
        let old_dt = parse_dt("2020-01-01 00:00:00");
        let old_end = parse_dt("2020-01-01 01:00:00");
        let entry = EpgEntry {
            channel_id: "ch1".to_string(),
            title: "Old Show".to_string(),
            start_time: old_dt,
            end_time: old_end,
            description: None,
            category: None,
            icon_url: None,
        };
        let mut map = HashMap::new();
        map.insert("ch1".to_string(), vec![entry]);
        svc.save_epg_entries(&map).unwrap();

        // Evict entries older than 1 day — the 2020 entry should be removed.
        let deleted = svc.evict_stale_epg(1).unwrap();
        assert!(deleted >= 1);

        let loaded = svc.load_epg_entries().unwrap();
        assert!(loaded.is_empty() || loaded.get("ch1").map(|v| v.is_empty()).unwrap_or(true));
    }

    #[test]
    fn clear_epg_entries_removes_all() {
        let svc = make_service();
        let dt = parse_dt("2025-01-15 10:00:00");
        let dt_end = parse_dt("2025-01-15 11:00:00");
        let entry = EpgEntry {
            channel_id: "ch1".to_string(),
            title: "News".to_string(),
            start_time: dt,
            end_time: dt_end,
            description: None,
            category: None,
            icon_url: None,
        };
        let mut map = HashMap::new();
        map.insert("ch1".to_string(), vec![entry]);
        svc.save_epg_entries(&map).unwrap();

        svc.clear_epg_entries().unwrap();
        let loaded = svc.load_epg_entries().unwrap();
        assert!(loaded.is_empty());
    }

    #[test]
    fn save_epg_emits_per_channel() {
        use crate::events::serialize_event;
        use std::collections::HashSet;
        use std::sync::{Arc, Mutex};
        let svc = make_service();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        svc.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
        let dt = parse_dt("2025-01-15 10:00:00");
        let dt_end = parse_dt("2025-01-15 11:00:00");
        let make_entry = |channel_id: &str| EpgEntry {
            channel_id: channel_id.to_string(),
            title: "Show".to_string(),
            start_time: dt,
            end_time: dt_end,
            description: None,
            category: None,
            icon_url: None,
        };
        let mut map = HashMap::new();
        map.insert("ch1".to_string(), vec![make_entry("ch1")]);
        map.insert("ch2".to_string(), vec![make_entry("ch2")]);
        svc.save_epg_entries(&map).unwrap();
        let recorded = log.lock().unwrap();
        let sources: HashSet<String> = recorded
            .iter()
            .filter(|s| s.contains("EpgUpdated"))
            .filter_map(|s| {
                let start = s.find("\"source_id\":\"")? + 13;
                let rest = &s[start..];
                let end = rest.find('"')?;
                Some(rest[..end].to_string())
            })
            .collect();
        assert!(sources.contains("ch1"), "{sources:?}");
        assert!(sources.contains("ch2"), "{sources:?}");
    }
}
