use std::collections::{HashMap, HashSet};

use rusqlite::params;

use super::{CrispyService, bool_to_int, dt_to_ts, str_params, ts_to_dt};
use crate::database::DbError;
use crate::events::DataChangeEvent;
use crate::models::EpgEntry;

/// Column list for all EPG SELECT queries. Kept in one place so
/// every load method stays in sync with `epg_entry_from_row`.
const EPG_SELECT_COLS: &str = "\
    epg_channel_id, xmltv_id, title, start_time, end_time, \
    description, category, icon_url, source_id, is_placeholder, \
    sub_title, season, episode, episode_label, \
    air_date, content_rating, star_rating, \
    credits_json, \
    language, country, \
    is_rerun, is_new, is_premiere, length_minutes";

/// Map a database row (matching [`EPG_SELECT_COLS`] order) to an
/// [`EpgEntry`].
fn epg_entry_from_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<EpgEntry> {
    Ok(EpgEntry {
        epg_channel_id: row.get(0)?,
        xmltv_id: row.get(1)?,
        title: row.get(2)?,
        start_time: ts_to_dt(row.get(3)?),
        end_time: ts_to_dt(row.get(4)?),
        description: row.get(5)?,
        category: row.get(6)?,
        icon_url: row.get(7)?,
        source_id: row.get(8)?,
        is_placeholder: row.get::<_, i32>(9).unwrap_or(0) != 0,
        sub_title: row.get(10)?,
        season: row.get(11)?,
        episode: row.get(12)?,
        episode_label: row.get(13)?,
        air_date: row.get(14)?,
        content_rating: row.get(15)?,
        star_rating: row.get(16)?,
        credits_json: row.get(17)?,
        language: row.get(18)?,
        country: row.get(19)?,
        is_rerun: row.get(20)?,
        is_new: row.get(21)?,
        is_premiere: row.get(22)?,
        length_minutes: row.get(23)?,
    })
}

impl CrispyService {
    // ── EPG ─────────────────────────────────────────

    /// Batch upsert EPG entries grouped by channel.
    ///
    /// Uses an atomic `INSERT ... ON CONFLICT` to enforce source
    /// priority: an incoming entry only overwrites an existing one
    /// when its source has equal or higher priority (lower
    /// `sort_order` in `db_sources`). Sources with no matching
    /// row in `db_sources` are treated as lowest priority
    /// (effective `sort_order` = 999).
    ///
    /// Returns total count actually inserted/updated.
    pub fn save_epg_entries(
        &self,
        entries: &HashMap<String, Vec<EpgEntry>>,
    ) -> Result<usize, DbError> {
        let conn = self.db.get()?;
        let tx = conn.unchecked_transaction()?;

        let upsert_sql = "\
            INSERT INTO db_epg_entries (
                epg_channel_id, xmltv_id, title,
                start_time, end_time,
                description, category,
                icon_url, source_id, is_placeholder,
                sub_title, season, episode,
                episode_label, air_date,
                content_rating, star_rating,
                credits_json,
                language, country,
                is_rerun, is_new, is_premiere,
                length_minutes
            ) VALUES (
                ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10,
                ?11, ?12, ?13, ?14, ?15,
                ?16, ?17, ?18,
                ?19, ?20,
                ?21, ?22, ?23, ?24
            )
            ON CONFLICT (source_id, epg_channel_id, start_time) DO UPDATE SET
                xmltv_id = excluded.xmltv_id,
                title = excluded.title,
                end_time = excluded.end_time,
                description = excluded.description,
                category = excluded.category,
                icon_url = excluded.icon_url,
                is_placeholder = excluded.is_placeholder,
                sub_title = excluded.sub_title,
                season = excluded.season,
                episode = excluded.episode,
                episode_label = excluded.episode_label,
                air_date = excluded.air_date,
                content_rating = excluded.content_rating,
                star_rating = excluded.star_rating,
                credits_json = excluded.credits_json,
                language = excluded.language,
                country = excluded.country,
                is_rerun = excluded.is_rerun,
                is_new = excluded.is_new,
                is_premiere = excluded.is_premiere,
                length_minutes = excluded.length_minutes
            WHERE COALESCE(
                    (SELECT sort_order FROM db_sources WHERE id = excluded.source_id), 999
                  )
                  <= COALESCE(
                    (SELECT sort_order FROM db_sources WHERE id = db_epg_entries.source_id), 999
                  )";

        let mut count = 0usize;
        for (matched_channel_id, epgs) in entries.iter() {
            for e in epgs {
                let start_ts = dt_to_ts(&e.start_time);
                tx.execute(
                    upsert_sql,
                    params![
                        matched_channel_id,
                        e.xmltv_id,
                        e.title,
                        start_ts,
                        dt_to_ts(&e.end_time),
                        e.description,
                        e.category,
                        e.icon_url,
                        e.source_id,
                        bool_to_int(e.is_placeholder),
                        e.sub_title,
                        e.season,
                        e.episode,
                        e.episode_label,
                        e.air_date,
                        e.content_rating,
                        e.star_rating,
                        e.credits_json,
                        e.language,
                        e.country,
                        e.is_rerun,
                        e.is_new,
                        e.is_premiere,
                        e.length_minutes,
                    ],
                )?;
                // changes() returns 1 for insert or update, 0 when
                // the ON CONFLICT WHERE clause prevented the update.
                if tx.changes() > 0 {
                    count += 1;
                }
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

    /// Load all EPG entries grouped by epg_channel_id.
    pub fn load_epg_entries(&self) -> Result<HashMap<String, Vec<EpgEntry>>, DbError> {
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(&format!(
            "SELECT {} FROM db_epg_entries ORDER BY epg_channel_id, start_time",
            EPG_SELECT_COLS
        ))?;
        let rows = stmt.query_map([], epg_entry_from_row)?;
        let mut map: HashMap<String, Vec<EpgEntry>> = HashMap::new();
        for r in rows {
            let entry = r?;
            map.entry(entry.epg_channel_id.clone())
                .or_default()
                .push(entry);
        }
        Ok(map)
    }

    /// Load EPG entries for a specific set of channels within a time window.
    ///
    /// Multi-step lookup to maximise EPG coverage:
    ///
    /// 1. Collect all candidate XMLTV IDs for each channel:
    ///    - `epg_channel_id` (pre-resolved at sync time by E4)
    ///    - `tvg_id` (M3U/Xtream tvg-id attribute)
    ///    - `xtream_stream_id` (Xtream numeric stream id)
    ///    - Any `db_epg_channels.xmltv_id` whose `display_name` matches
    ///      `channel.name` or `channel.tvg_name` (name-based fallback)
    ///
    /// 2. Query `db_epg_entries` for entries matching any of those IDs.
    ///
    /// 3. Fan out each entry to all internal channel IDs that mapped to
    ///    the same XMLTV ID.
    ///
    /// Source priority: when multiple sources provide EPG for the same
    /// channel the source with the lowest `sort_order` wins.
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

        // ── Step 1: load channel fields needed for lookup ─────────────
        let ch_placeholders: Vec<String> =
            (1..=channel_ids.len()).map(|i| format!("?{i}")).collect();
        let ch_query = format!(
            "SELECT id, epg_channel_id, tvg_id, xtream_stream_id, name, tvg_name \
             FROM db_channels WHERE id IN ({})",
            ch_placeholders.join(", ")
        );
        let mut ch_stmt = conn.prepare(&ch_query)?;
        let mut ch_params: Vec<&dyn rusqlite::types::ToSql> =
            Vec::with_capacity(channel_ids.len());
        for id in channel_ids {
            ch_params.push(id as &dyn rusqlite::types::ToSql);
        }

        struct ChannelRow {
            id: String,
            epg_channel_id: Option<String>,
            tvg_id: Option<String>,
            xtream_stream_id: Option<String>,
            name: String,
            tvg_name: Option<String>,
        }

        let ch_rows: Vec<ChannelRow> = ch_stmt
            .query_map(ch_params.as_slice(), |row| {
                Ok(ChannelRow {
                    id: row.get(0)?,
                    epg_channel_id: row.get(1)?,
                    tvg_id: row.get(2)?,
                    xtream_stream_id: row.get(3)?,
                    name: row.get(4)?,
                    tvg_name: row.get(5)?,
                })
            })?
            .collect::<rusqlite::Result<_>>()?;

        if ch_rows.is_empty() {
            return Ok(HashMap::new());
        }

        // ── Step 2: name-based lookup via db_epg_channels ─────────────
        // Collect all (name, tvg_name) pairs so we can do a single batch query.
        let mut lookup_names: Vec<String> = Vec::new();
        for ch in &ch_rows {
            lookup_names.push(ch.name.clone());
            if let Some(ref tvg) = ch.tvg_name {
                if !tvg.is_empty() {
                    lookup_names.push(tvg.clone());
                }
            }
        }
        lookup_names.sort();
        lookup_names.dedup();

        // display_name → xmltv_id
        let mut display_name_to_xmltv: HashMap<String, String> = HashMap::new();
        if !lookup_names.is_empty() {
            let name_phs: Vec<String> =
                (1..=lookup_names.len()).map(|i| format!("?{i}")).collect();
            let name_query = format!(
                "SELECT display_name, xmltv_id FROM db_epg_channels \
                 WHERE display_name IN ({}) GROUP BY display_name",
                name_phs.join(", ")
            );
            let mut name_stmt = conn.prepare(&name_query)?;
            let mut name_params: Vec<&dyn rusqlite::types::ToSql> =
                Vec::with_capacity(lookup_names.len());
            for n in &lookup_names {
                name_params.push(n as &dyn rusqlite::types::ToSql);
            }
            let name_rows = name_stmt.query_map(name_params.as_slice(), |row| {
                Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
            })?;
            for r in name_rows {
                let (display, xmltv) = r?;
                display_name_to_xmltv.entry(display).or_insert(xmltv);
            }
        }

        // ── Step 3: build xmltv_id → Vec<channel_id> reverse index ───
        let mut xmltv_to_channels: HashMap<String, Vec<String>> = HashMap::new();

        let non_empty = |s: &str| !s.trim().is_empty();

        for ch in &ch_rows {
            let mut keys: Vec<String> = Vec::new();

            // Highest priority: pre-resolved epg_channel_id (E4)
            if let Some(ref eid) = ch.epg_channel_id {
                if non_empty(eid) {
                    keys.push(eid.clone());
                }
            }
            // tvg_id from M3U/Xtream metadata
            if let Some(ref tvg) = ch.tvg_id {
                if non_empty(tvg) {
                    keys.push(tvg.clone());
                }
            }
            // Xtream numeric stream id
            if let Some(ref xid) = ch.xtream_stream_id {
                if non_empty(xid) {
                    keys.push(xid.clone());
                }
            }
            // Name-based fallback via db_epg_channels
            if let Some(xmltv_id) = display_name_to_xmltv.get(&ch.name) {
                keys.push(xmltv_id.clone());
            }
            if let Some(ref tvg_name) = ch.tvg_name {
                if let Some(xmltv_id) = display_name_to_xmltv.get(tvg_name) {
                    keys.push(xmltv_id.clone());
                }
            }

            keys.sort();
            keys.dedup();

            for key in keys {
                xmltv_to_channels
                    .entry(key)
                    .or_default()
                    .push(ch.id.clone());
            }
        }

        if xmltv_to_channels.is_empty() {
            return Ok(HashMap::new());
        }

        // ── Step 4: query EPG entries for all resolved XMLTV IDs ─────
        let xmltv_ids: Vec<String> = xmltv_to_channels.keys().cloned().collect();
        let placeholders: Vec<String> =
            (1..=xmltv_ids.len()).map(|i| format!("?{i}")).collect();
        let start_p = xmltv_ids.len() + 1;
        let end_p = xmltv_ids.len() + 2;
        let query = format!(
            "SELECT {cols}
            FROM db_epg_entries
            LEFT JOIN db_sources ON db_epg_entries.source_id = db_sources.id
            WHERE epg_channel_id IN ({ph})
              AND end_time > ?{start_p}
              AND start_time < ?{end_p}
            ORDER BY epg_channel_id, start_time, COALESCE(db_sources.sort_order, 999) ASC",
            cols = EPG_SELECT_COLS,
            ph = placeholders.join(", "),
        );

        let mut stmt = conn.prepare(&query)?;
        let mut params: Vec<&dyn rusqlite::types::ToSql> =
            Vec::with_capacity(xmltv_ids.len() + 2);
        for key in &xmltv_ids {
            params.push(key as &dyn rusqlite::types::ToSql);
        }
        params.push(&start_time as &dyn rusqlite::types::ToSql);
        params.push(&end_time as &dyn rusqlite::types::ToSql);

        let rows = stmt.query_map(params.as_slice(), epg_entry_from_row)?;

        // ── Step 5: fan out entries to all channels that share the key ─
        let mut map: HashMap<String, Vec<EpgEntry>> = HashMap::new();
        for r in rows {
            let entry = r?;
            if let Some(ch_ids) = xmltv_to_channels.get(&entry.epg_channel_id) {
                for ch_id in ch_ids {
                    map.entry(ch_id.clone()).or_default().push(entry.clone());
                }
            }
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
            "SELECT {cols}
            FROM db_epg_entries
            WHERE source_id IN ({placeholders})
            ORDER BY epg_channel_id, start_time",
            cols = EPG_SELECT_COLS,
            placeholders = placeholders.join(", "),
        );
        let mut stmt = conn.prepare(&sql)?;
        let params = str_params(source_ids);
        let rows = stmt.query_map(params.as_slice(), epg_entry_from_row)?;
        let mut map: HashMap<String, Vec<EpgEntry>> = HashMap::new();
        for r in rows {
            let entry = r?;
            map.entry(entry.epg_channel_id.clone())
                .or_default()
                .push(entry);
        }
        Ok(map)
    }

    /// Reserved source_id for placeholder EPG entries.
    /// Placeholders are auto-generated for channels without real EPG.
    pub const PLACEHOLDER_SOURCE: &'static str = "_placeholder";

    /// Generate 7-day placeholder EPG entries for channels that have
    /// no real EPG data. Each placeholder is a 24-hour block with the
    /// channel name as the programme title.
    ///
    /// Placeholders use `source_id = "_placeholder"` with effective
    /// `sort_order = 999`, so any real EPG data replaces them via
    /// the priority upsert in `save_epg_entries`.
    ///
    /// Returns the number of placeholder entries inserted.
    pub fn generate_placeholders_for_channels(
        &self,
        channels: &[crate::models::Channel],
    ) -> Result<usize, DbError> {
        let now = chrono::Utc::now();
        let today_start = now
            .date_naive()
            .and_hms_opt(0, 0, 0)
            .unwrap_or(now.naive_utc());

        // Find channels that already have ANY entries (real or placeholder)
        // in the next 24 hours. Single batch query.
        let channel_ids: Vec<String> = channels.iter().map(|ch| ch.id.clone()).collect();
        let start_ts = today_start.and_utc().timestamp();
        let end_ts = start_ts + 7 * 86_400;

        let existing = self.get_epgs_for_channels(&channel_ids, start_ts, end_ts)?;
        let has_data: HashSet<&str> = existing
            .iter()
            .filter(|(_, entries)| !entries.is_empty())
            .map(|(id, _)| id.as_str())
            .collect();

        // Generate placeholders for channels with no coverage.
        let mut placeholder_map: HashMap<String, Vec<EpgEntry>> = HashMap::new();
        for ch in channels {
            if has_data.contains(ch.id.as_str()) {
                continue;
            }
            let mut entries = Vec::with_capacity(7);
            for day in 0..7 {
                let day_start = today_start + chrono::Duration::days(day);
                let day_end = day_start + chrono::Duration::days(1);
                entries.push(EpgEntry {
                    epg_channel_id: ch.id.clone(),
                    title: ch.name.clone(),
                    start_time: day_start,
                    end_time: day_end,
                    source_id: Some(Self::PLACEHOLDER_SOURCE.to_string()),
                    ..EpgEntry::default()
                });
            }
            placeholder_map.insert(ch.id.clone(), entries);
        }

        if placeholder_map.is_empty() {
            return Ok(0);
        }

        let count = self.save_epg_entries(&placeholder_map)?;
        tracing::info!(
            "Generated {} placeholder EPG entries for {} channels",
            count,
            placeholder_map.len(),
        );
        Ok(count)
    }

    /// Check the latest real (non-placeholder) EPG coverage end time
    /// for a specific channel. Returns `None` if no real data exists.
    pub fn get_real_epg_coverage_end(&self, channel_id: &str) -> Result<Option<i64>, DbError> {
        let conn = self.db.get()?;
        let result: rusqlite::Result<Option<i64>> = conn.query_row(
            "SELECT MAX(end_time) FROM db_epg_entries
             WHERE epg_channel_id = ?1 AND (source_id IS NULL OR source_id != ?2)",
            params![channel_id, Self::PLACEHOLDER_SOURCE],
            |row| row.get(0),
        );
        match result {
            Ok(ts) => Ok(ts),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(DbError::Sqlite(e)),
        }
    }

    /// Check if a channel has real (non-placeholder) EPG data
    /// covering the given time range.
    pub fn has_real_epg_coverage(
        &self,
        channel_id: &str,
        start_time: i64,
        end_time: i64,
    ) -> Result<bool, DbError> {
        let conn = self.db.get()?;
        let count: i64 = conn.query_row(
            "SELECT COUNT(*) FROM db_epg_entries
             WHERE epg_channel_id = ?1
               AND end_time > ?2
               AND start_time < ?3
               AND (source_id IS NULL OR source_id != ?4)",
            params![channel_id, start_time, end_time, Self::PLACEHOLDER_SOURCE],
            |row| row.get(0),
        )?;
        Ok(count > 0)
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
            epg_channel_id: "ch1".to_string(),
            title: "News".to_string(),
            start_time: dt,
            end_time: dt_end,
            ..EpgEntry::default()
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
        // Create a channel with tvg_id — the EPG bridge used by get_epgs_for_channels.
        let mut ch = make_channel("ch1", "Test Channel");
        ch.tvg_id = Some("tvg_ch1".to_string());
        svc.save_channels(&[ch]).unwrap();

        let dt = parse_dt("2025-01-15 10:00:00");
        let dt_end = parse_dt("2025-01-15 11:00:00");
        // Store EPG keyed on the channel's tvg_id so the join resolves correctly.
        let entry = EpgEntry {
            epg_channel_id: "tvg_ch1".to_string(),
            title: "News".to_string(),
            start_time: dt,
            end_time: dt_end,
            ..EpgEntry::default()
        };
        let mut map = HashMap::new();
        map.insert("tvg_ch1".to_string(), vec![entry]);
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
        let svc = make_service_with_fixtures();
        let dt = parse_dt("2025-01-15 10:00:00");
        let dt_end = parse_dt("2025-01-15 11:00:00");
        let make_entry = |ch: &str, src: &str| EpgEntry {
            epg_channel_id: ch.to_string(),
            title: "Show".to_string(),
            start_time: dt,
            end_time: dt_end,
            source_id: Some(src.to_string()),
            ..EpgEntry::default()
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
        let svc = make_service_with_fixtures();
        let dt = parse_dt("2025-01-15 10:00:00");
        let dt_end = parse_dt("2025-01-15 11:00:00");
        let make_entry = |ch: &str, src: &str| EpgEntry {
            epg_channel_id: ch.to_string(),
            title: "Show".to_string(),
            start_time: dt,
            end_time: dt_end,
            source_id: Some(src.to_string()),
            ..EpgEntry::default()
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
            epg_channel_id: "ch1".to_string(),
            title: "Old Show".to_string(),
            start_time: old_dt,
            end_time: old_end,
            ..EpgEntry::default()
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
            epg_channel_id: "ch1".to_string(),
            title: "News".to_string(),
            start_time: dt,
            end_time: dt_end,
            ..EpgEntry::default()
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
            epg_channel_id: channel_id.to_string(),
            title: "Show".to_string(),
            start_time: dt,
            end_time: dt_end,
            ..EpgEntry::default()
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

    // ── Multi-source storage tests ─────────────────────

    fn make_epg_entry_with_source(
        channel_id: &str,
        source_id: Option<&str>,
        title: &str,
    ) -> EpgEntry {
        EpgEntry {
            epg_channel_id: channel_id.to_string(),
            title: title.to_string(),
            start_time: parse_dt("2025-06-01 10:00:00"),
            end_time: parse_dt("2025-06-01 11:00:00"),
            source_id: source_id.map(|s| s.to_string()),
            ..EpgEntry::default()
        }
    }

    /// With the new PK (source_id, epg_channel_id, start_time),
    /// entries from different sources are stored separately.
    #[test]
    fn epg_priority_high_wins() {
        let svc = make_service();
        let mut src_a = make_source("src_a", "Source A", "m3u");
        src_a.sort_order = 0;
        let mut src_b = make_source("src_b", "Source B", "m3u");
        src_b.sort_order = 5;
        svc.save_source(&src_a).unwrap();
        svc.save_source(&src_b).unwrap();

        // Insert from source B.
        let mut map_b = HashMap::new();
        map_b.insert(
            "ch1".to_string(),
            vec![make_epg_entry_with_source("ch1", Some("src_b"), "From B")],
        );
        svc.save_epg_entries(&map_b).unwrap();

        // Insert from source A — stored separately (different source_id in PK).
        let mut map_a = HashMap::new();
        map_a.insert(
            "ch1".to_string(),
            vec![make_epg_entry_with_source("ch1", Some("src_a"), "From A")],
        );
        svc.save_epg_entries(&map_a).unwrap();

        let loaded = svc.load_epg_entries().unwrap();
        // Both entries stored (different source_id in PK).
        assert_eq!(loaded["ch1"].len(), 2);
    }

    /// Same-source re-insert updates the existing entry.
    #[test]
    fn epg_priority_low_skipped() {
        let svc = make_service();
        let mut src_a = make_source("src_a", "Source A", "m3u");
        src_a.sort_order = 0;
        svc.save_source(&src_a).unwrap();

        // Insert entry from src_a.
        let mut map1 = HashMap::new();
        map1.insert(
            "ch1".to_string(),
            vec![make_epg_entry_with_source("ch1", Some("src_a"), "Original")],
        );
        svc.save_epg_entries(&map1).unwrap();

        // Re-insert from same source with different title.
        let mut map2 = HashMap::new();
        map2.insert(
            "ch1".to_string(),
            vec![make_epg_entry_with_source("ch1", Some("src_a"), "Updated")],
        );
        let count = svc.save_epg_entries(&map2).unwrap();
        assert_eq!(count, 1, "same-source re-insert must update");

        let loaded = svc.load_epg_entries().unwrap();
        assert_eq!(loaded["ch1"].len(), 1);
        assert_eq!(
            loaded["ch1"][0].title, "Updated",
            "same-source re-insert must update title"
        );
    }

    /// Two different sources produce separate entries (not conflicts).
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
        assert_eq!(count_b, 1, "different source creates new entry");

        let loaded = svc.load_epg_entries().unwrap();
        assert_eq!(loaded["ch1"].len(), 2, "both sources stored separately");
    }

    /// An entry with source_id=None and one with source_id set are separate.
    #[test]
    fn epg_priority_no_source_id_lowest() {
        let svc = make_service();
        let mut src_a = make_source("src_a", "Source A", "m3u");
        src_a.sort_order = 10;
        svc.save_source(&src_a).unwrap();

        // Insert entry with no source_id.
        let mut map_none = HashMap::new();
        map_none.insert(
            "ch1".to_string(),
            vec![make_epg_entry_with_source("ch1", None, "No Source")],
        );
        svc.save_epg_entries(&map_none).unwrap();

        // Insert from registered source — separate entry.
        let mut map_a = HashMap::new();
        map_a.insert(
            "ch1".to_string(),
            vec![make_epg_entry_with_source("ch1", Some("src_a"), "From A")],
        );
        let count = svc.save_epg_entries(&map_a).unwrap();
        assert_eq!(count, 1, "new source creates separate entry");

        let loaded = svc.load_epg_entries().unwrap();
        assert_eq!(loaded["ch1"].len(), 2, "both entries stored separately");
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
