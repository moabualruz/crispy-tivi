use std::collections::HashMap;

use rusqlite::params;

use super::{CrispyService, dt_to_ts, ts_to_dt};
use crate::database::DbError;
use crate::events::DataChangeEvent;
use crate::models::EpgEntry;

impl CrispyService {
    // ── EPG ─────────────────────────────────────────

    /// Batch upsert EPG entries grouped by channel.
    ///
    /// Entries from higher-priority sources (lower `sort_order` in
    /// `db_sources`) take precedence over lower-priority ones for
    /// the same `(channel_id, start_time)` slot. Sources with no
    /// matching row in `db_sources` are treated as lowest priority
    /// (effective `sort_order` = 999).
    ///
    /// Returns total count actually inserted/replaced.
    pub fn save_epg_entries(
        &self,
        entries: &HashMap<String, Vec<EpgEntry>>,
    ) -> Result<usize, DbError> {
        let conn = self.db.get()?;
        let tx = conn.unchecked_transaction()?;

        // Pass 1: Build source_id → sort_order lookup.
        let source_priority: std::collections::HashMap<String, i32> = {
            let mut stmt = tx.prepare("SELECT id, sort_order FROM db_sources")?;
            stmt.query_map([], |row| {
                Ok((row.get::<_, String>(0)?, row.get::<_, i32>(1)?))
            })?
            .filter_map(|r| r.ok())
            .collect()
        };

        // Pass 2: Load existing (channel_id, start_time) → priority
        // for conflict check.
        let mut existing: std::collections::HashMap<(String, i64), i32> = {
            let mut stmt = tx.prepare(
                "SELECT e.channel_id, e.start_time,
                        COALESCE(s.sort_order, 999) AS prio
                 FROM db_epg_entries e
                 LEFT JOIN db_sources s ON s.id = e.source_id",
            )?;
            stmt.query_map([], |row| {
                Ok((
                    (row.get::<_, String>(0)?, row.get::<_, i64>(1)?),
                    row.get::<_, i32>(2)?,
                ))
            })?
            .filter_map(|r| r.ok())
            .collect()
        };

        let mut count = 0usize;
        for (matched_channel_id, epgs) in entries.iter() {
            for e in epgs {
                let start_ts = dt_to_ts(&e.start_time);
                let incoming_prio = e
                    .source_id
                    .as_deref()
                    .and_then(|sid| source_priority.get(sid))
                    .copied()
                    .unwrap_or(999);

                let key = (matched_channel_id.clone(), start_ts);

                // Skip if existing entry is from a higher-priority source
                // (lower sort_order = higher priority).
                if let Some(&existing_prio) = existing.get(&key)
                    && incoming_prio > existing_prio
                {
                    continue; // existing has higher priority, skip
                }

                tx.execute(
                    "INSERT OR REPLACE INTO
                     db_epg_entries (
                         channel_id, title,
                         start_time, end_time,
                         description, category,
                         icon_url, source_id
                     ) VALUES (
                         ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8
                     )",
                    params![
                        matched_channel_id,
                        e.title,
                        start_ts,
                        dt_to_ts(&e.end_time),
                        e.description,
                        e.category,
                        e.icon_url,
                        e.source_id,
                    ],
                )?;
                // Update in-memory map for subsequent iterations.
                existing.insert(key, incoming_prio);
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
                icon_url, source_id
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
                source_id: row.get(7)?,
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
                icon_url, source_id
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
                source_id: row.get(7)?,
            })
        })?;

        let mut map: HashMap<String, Vec<EpgEntry>> = HashMap::new();
        for r in rows {
            let entry = r?;
            map.entry(entry.channel_id.clone()).or_default().push(entry);
        }
        Ok(map)
    }

    /// Load EPG entries filtered by source IDs, grouped by channel_id.
    ///
    /// If `source_ids` is empty, all EPG entries are returned
    /// (same behaviour as `load_epg_entries()`). Otherwise only
    /// entries whose `source_id` is in the list are returned.
    pub fn get_epg_by_sources(
        &self,
        source_ids: &[String],
    ) -> Result<HashMap<String, Vec<EpgEntry>>, DbError> {
        if source_ids.is_empty() {
            return self.load_epg_entries();
        }
        let conn = self.db.get()?;
        let placeholders: Vec<String> = (1..=source_ids.len()).map(|i| format!("?{i}")).collect();
        let sql = format!(
            "SELECT
                channel_id, title, start_time,
                end_time, description, category,
                icon_url, source_id
            FROM db_epg_entries
            WHERE source_id IN ({})
            ORDER BY channel_id, start_time",
            placeholders.join(", ")
        );
        let mut stmt = conn.prepare(&sql)?;
        let params: Vec<&dyn rusqlite::types::ToSql> = source_ids
            .iter()
            .map(|s| s as &dyn rusqlite::types::ToSql)
            .collect();
        let rows = stmt.query_map(params.as_slice(), |row| {
            Ok(EpgEntry {
                channel_id: row.get(0)?,
                title: row.get(1)?,
                start_time: ts_to_dt(row.get(2)?),
                end_time: ts_to_dt(row.get(3)?),
                description: row.get(4)?,
                category: row.get(5)?,
                icon_url: row.get(6)?,
                source_id: row.get(7)?,
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
            source_id: None,
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
            source_id: None,
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
    fn test_get_epg_by_sources_empty_returns_all() {
        let svc = make_service();
        let dt = parse_dt("2025-01-15 10:00:00");
        let dt_end = parse_dt("2025-01-15 11:00:00");
        let make_entry = |ch: &str, src: &str| EpgEntry {
            channel_id: ch.to_string(),
            title: "Show".to_string(),
            start_time: dt,
            end_time: dt_end,
            description: None,
            category: None,
            icon_url: None,
            source_id: Some(src.to_string()),
        };
        let mut map = HashMap::new();
        map.insert("ch1".to_string(), vec![make_entry("ch1", "src_a")]);
        map.insert("ch2".to_string(), vec![make_entry("ch2", "src_b")]);
        svc.save_epg_entries(&map).unwrap();

        // Empty source_ids => all entries.
        let result = svc.get_epg_by_sources(&[]).unwrap();
        assert_eq!(result.len(), 2, "expected 2 channels");
        assert!(result.contains_key("ch1"));
        assert!(result.contains_key("ch2"));
    }

    #[test]
    fn test_get_epg_by_sources_filters() {
        let svc = make_service();
        let dt = parse_dt("2025-01-15 10:00:00");
        let dt_end = parse_dt("2025-01-15 11:00:00");
        let make_entry = |ch: &str, src: &str| EpgEntry {
            channel_id: ch.to_string(),
            title: "Show".to_string(),
            start_time: dt,
            end_time: dt_end,
            description: None,
            category: None,
            icon_url: None,
            source_id: Some(src.to_string()),
        };
        let mut map = HashMap::new();
        map.insert("ch1".to_string(), vec![make_entry("ch1", "src_a")]);
        map.insert("ch2".to_string(), vec![make_entry("ch2", "src_b")]);
        svc.save_epg_entries(&map).unwrap();

        // Filter to src_a only.
        let result = svc.get_epg_by_sources(&["src_a".to_string()]).unwrap();
        assert_eq!(result.len(), 1, "expected only ch1");
        assert!(result.contains_key("ch1"));
        assert!(!result.contains_key("ch2"));
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
            source_id: None,
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
            source_id: None,
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
            source_id: None,
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

    // ── Priority tests ────────────────────────────────

    fn make_epg_entry_with_source(
        channel_id: &str,
        source_id: Option<&str>,
        title: &str,
    ) -> EpgEntry {
        EpgEntry {
            channel_id: channel_id.to_string(),
            title: title.to_string(),
            start_time: parse_dt("2025-06-01 10:00:00"),
            end_time: parse_dt("2025-06-01 11:00:00"),
            description: None,
            category: None,
            icon_url: None,
            source_id: source_id.map(|s| s.to_string()),
        }
    }

    /// Save source A (sort_order=0, high priority) and source B
    /// (sort_order=5, low priority). Insert EPG for ch1/10:00 from B
    /// first, then from A. Final entry must have source A's title.
    #[test]
    fn epg_priority_high_wins() {
        let svc = make_service();
        let mut src_a = make_source("src_a", "Source A", "m3u");
        src_a.sort_order = 0;
        let mut src_b = make_source("src_b", "Source B", "m3u");
        src_b.sort_order = 5;
        svc.save_source(&src_a).unwrap();
        svc.save_source(&src_b).unwrap();

        // Insert from low-priority source B first.
        let mut map_b = HashMap::new();
        map_b.insert(
            "ch1".to_string(),
            vec![make_epg_entry_with_source("ch1", Some("src_b"), "From B")],
        );
        svc.save_epg_entries(&map_b).unwrap();

        // Insert from high-priority source A second.
        let mut map_a = HashMap::new();
        map_a.insert(
            "ch1".to_string(),
            vec![make_epg_entry_with_source("ch1", Some("src_a"), "From A")],
        );
        svc.save_epg_entries(&map_a).unwrap();

        let loaded = svc.load_epg_entries().unwrap();
        assert_eq!(loaded["ch1"].len(), 1);
        assert_eq!(
            loaded["ch1"][0].title, "From A",
            "high-priority source A must win"
        );
    }

    /// Insert from high-priority source A first, then try to
    /// overwrite with lower-priority source B. A's entry must
    /// be preserved and the second save must return count=0.
    #[test]
    fn epg_priority_low_skipped() {
        let svc = make_service();
        let mut src_a = make_source("src_a", "Source A", "m3u");
        src_a.sort_order = 0;
        let mut src_b = make_source("src_b", "Source B", "m3u");
        src_b.sort_order = 5;
        svc.save_source(&src_a).unwrap();
        svc.save_source(&src_b).unwrap();

        // Insert high-priority A first.
        let mut map_a = HashMap::new();
        map_a.insert(
            "ch1".to_string(),
            vec![make_epg_entry_with_source("ch1", Some("src_a"), "From A")],
        );
        svc.save_epg_entries(&map_a).unwrap();

        // Try to overwrite with lower-priority B — must be skipped.
        let mut map_b = HashMap::new();
        map_b.insert(
            "ch1".to_string(),
            vec![make_epg_entry_with_source("ch1", Some("src_b"), "From B")],
        );
        let count_b = svc.save_epg_entries(&map_b).unwrap();
        assert_eq!(count_b, 0, "lower-priority entry must be skipped");

        let loaded = svc.load_epg_entries().unwrap();
        assert_eq!(
            loaded["ch1"][0].title, "From A",
            "A's entry must remain unchanged"
        );
    }

    /// Two sources with the same sort_order. The second write should
    /// overwrite (INSERT OR REPLACE — equal priority = last writer wins).
    #[test]
    fn epg_priority_equal_last_writer() {
        let svc = make_service();
        let mut src_a = make_source("src_a", "Source A", "m3u");
        src_a.sort_order = 3;
        let mut src_b = make_source("src_b", "Source B", "m3u");
        src_b.sort_order = 3;
        svc.save_source(&src_a).unwrap();
        svc.save_source(&src_b).unwrap();

        let mut map_a = HashMap::new();
        map_a.insert(
            "ch1".to_string(),
            vec![make_epg_entry_with_source("ch1", Some("src_a"), "From A")],
        );
        svc.save_epg_entries(&map_a).unwrap();

        let mut map_b = HashMap::new();
        map_b.insert(
            "ch1".to_string(),
            vec![make_epg_entry_with_source("ch1", Some("src_b"), "From B")],
        );
        let count_b = svc.save_epg_entries(&map_b).unwrap();
        assert_eq!(count_b, 1, "equal priority allows overwrite");

        let loaded = svc.load_epg_entries().unwrap();
        assert_eq!(
            loaded["ch1"][0].title, "From B",
            "last writer wins on equal priority"
        );
    }

    /// An entry with source_id=None has effective priority 999 (lowest).
    /// A subsequent entry from any registered source must overwrite it.
    #[test]
    fn epg_priority_no_source_id_lowest() {
        let svc = make_service();
        let mut src_a = make_source("src_a", "Source A", "m3u");
        src_a.sort_order = 10;
        svc.save_source(&src_a).unwrap();

        // Insert entry with no source_id (priority 999).
        let mut map_none = HashMap::new();
        map_none.insert(
            "ch1".to_string(),
            vec![make_epg_entry_with_source("ch1", None, "No Source")],
        );
        svc.save_epg_entries(&map_none).unwrap();

        // Overwrite with registered source (sort_order=10 < 999).
        let mut map_a = HashMap::new();
        map_a.insert(
            "ch1".to_string(),
            vec![make_epg_entry_with_source("ch1", Some("src_a"), "From A")],
        );
        let count = svc.save_epg_entries(&map_a).unwrap();
        assert_eq!(count, 1, "registered source must overwrite no-source entry");

        let loaded = svc.load_epg_entries().unwrap();
        assert_eq!(
            loaded["ch1"][0].title, "From A",
            "registered source entry must replace no-source entry"
        );
    }

    /// When no existing entry exists for a (channel_id, start_time)
    /// slot, insertion must always succeed regardless of source priority.
    #[test]
    fn epg_priority_new_entry_always_inserted() {
        let svc = make_service();
        let mut src_a = make_source("src_a", "Source A", "m3u");
        src_a.sort_order = 0;
        svc.save_source(&src_a).unwrap();

        let mut map = HashMap::new();
        map.insert(
            "ch1".to_string(),
            vec![make_epg_entry_with_source(
                "ch1",
                Some("src_a"),
                "New Entry",
            )],
        );
        let count = svc.save_epg_entries(&map).unwrap();
        assert_eq!(count, 1, "new entry must always be inserted");

        let loaded = svc.load_epg_entries().unwrap();
        assert_eq!(loaded["ch1"].len(), 1);
        assert_eq!(loaded["ch1"][0].title, "New Entry");
    }
}
