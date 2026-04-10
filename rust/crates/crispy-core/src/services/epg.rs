use std::collections::{HashMap, HashSet};

use rusqlite::params;

use super::{ServiceContext, bool_to_int, dt_to_ts, str_params, ts_to_dt};
use crate::database::row_helpers::RowExt;
use crate::database::{DbError, optional};
use crate::errors::DomainError;
use crate::events::DataChangeEvent;
use crate::insert_or_replace;
use crate::models::EpgEntry;
use crate::parsers::epg::EpgChannel;
use crate::traits::EpgRepository;

/// Domain service for EPG operations.
pub struct EpgService(pub ServiceContext);

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

const CHANNEL_NAME_SUFFIXES: [&str; 10] = [
    " hd", " sd", " fhd", " 4k", " uhd", " low", " mini", " hevc", " h265", " h.265",
];

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
        is_placeholder: row.get_bool(9).unwrap_or(false),
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

pub(crate) fn normalize_channel_name(name: &str) -> String {
    let mut normalized = name.trim().to_lowercase();

    loop {
        let mut stripped = false;
        for suffix in CHANNEL_NAME_SUFFIXES {
            if normalized.ends_with(suffix) {
                normalized = normalized[..normalized.len() - suffix.len()]
                    .trim()
                    .to_string();
                stripped = true;
                break;
            }
        }
        if !stripped {
            return normalized;
        }
    }
}

impl EpgService {
    fn resolve_epg_keys_for_channels(
        &self,
        conn: &rusqlite::Connection,
        channel_ids: &[String],
    ) -> Result<HashMap<String, Vec<String>>, DbError> {
        if channel_ids.is_empty() {
            return Ok(HashMap::new());
        }

        let ch_placeholders: Vec<String> =
            (1..=channel_ids.len()).map(|i| format!("?{i}")).collect();
        let ch_query = format!(
            "SELECT id, source_id, epg_channel_id, tvg_id, xtream_stream_id, name, tvg_name \
             FROM db_channels WHERE id IN ({})",
            ch_placeholders.join(", ")
        );
        let mut ch_stmt = conn.prepare(&ch_query)?;
        let mut ch_params: Vec<&dyn rusqlite::types::ToSql> = Vec::with_capacity(channel_ids.len());
        for id in channel_ids {
            ch_params.push(id as &dyn rusqlite::types::ToSql);
        }

        struct ChannelRow {
            id: String,
            source_id: Option<String>,
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
                    source_id: row.get(1)?,
                    epg_channel_id: row.get(2)?,
                    tvg_id: row.get(3)?,
                    xtream_stream_id: row.get(4)?,
                    name: row.get(5)?,
                    tvg_name: row.get(6)?,
                })
            })?
            .collect::<rusqlite::Result<_>>()?;

        if ch_rows.is_empty() {
            return Ok(HashMap::new());
        }

        let source_ids: Vec<String> = ch_rows
            .iter()
            .filter_map(|ch| ch.source_id.clone())
            .filter(|source_id| !source_id.trim().is_empty())
            .collect::<HashSet<_>>()
            .into_iter()
            .collect();

        let mut normalized_display_to_xmltv: HashMap<(String, String), String> = HashMap::new();
        if !source_ids.is_empty() {
            let source_placeholders: Vec<String> =
                (1..=source_ids.len()).map(|i| format!("?{i}")).collect();
            let bridge_query = format!(
                "SELECT source_id, display_name, xmltv_id
                 FROM db_epg_channels
                 WHERE source_id IN ({})
                   AND display_name IS NOT NULL
                   AND TRIM(display_name) != ''",
                source_placeholders.join(", ")
            );
            let mut bridge_stmt = conn.prepare(&bridge_query)?;
            let bridge_params = str_params(&source_ids);
            let bridge_rows = bridge_stmt.query_map(bridge_params.as_slice(), |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, String>(2)?,
                ))
            })?;
            for row in bridge_rows {
                let (source_id, display_name, xmltv_id) = row?;
                normalized_display_to_xmltv
                    .entry((source_id, normalize_channel_name(&display_name)))
                    .or_insert(xmltv_id);
            }
        }

        let mut xmltv_to_channels: HashMap<String, Vec<String>> = HashMap::new();
        let non_empty = |s: &str| !s.trim().is_empty();

        for ch in &ch_rows {
            let mut keys: Vec<String> = Vec::new();

            if let Some(ref eid) = ch.epg_channel_id
                && non_empty(eid)
            {
                keys.push(eid.clone());
            }
            if let Some(ref tvg) = ch.tvg_id
                && non_empty(tvg)
            {
                keys.push(tvg.clone());
            }
            if let Some(source_id) = ch.source_id.as_deref() {
                let channel_names = [Some(ch.name.as_str()), ch.tvg_name.as_deref()];
                for channel_name in channel_names.into_iter().flatten() {
                    let normalized = normalize_channel_name(channel_name);
                    if normalized.is_empty() {
                        continue;
                    }
                    if let Some(xmltv_id) =
                        normalized_display_to_xmltv.get(&(source_id.to_string(), normalized))
                    {
                        keys.push(xmltv_id.clone());
                    }
                }
            }
            if let Some(ref xid) = ch.xtream_stream_id
                && non_empty(xid)
            {
                keys.push(xid.clone());
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

        Ok(xmltv_to_channels)
    }

    // ── EPG ─────────────────────────────────────────

    /// Save XMLTV `<channel>` metadata for a source.
    pub fn save_epg_channels(
        &self,
        channels: &[EpgChannel],
        source_id: &str,
    ) -> Result<usize, DbError> {
        let source_id = source_id.trim();
        if channels.is_empty() || source_id.is_empty() {
            return Ok(0);
        }

        let conn = self.0.db.get()?;
        let tx = conn.unchecked_transaction()?;
        let mut saved = 0usize;

        for channel in channels {
            let xmltv_id = channel.xmltv_id.trim();
            let display_name = channel.display_name.trim();
            if xmltv_id.is_empty() || display_name.is_empty() {
                continue;
            }

            saved += insert_or_replace!(
                tx,
                "db_epg_channels",
                ["xmltv_id", "display_name", "icon_url", "source_id"],
                params![xmltv_id, display_name, channel.icon_url, source_id],
            )?;
        }

        tx.commit()?;
        Ok(saved)
    }

    /// Resolve `db_channels.epg_channel_id` for unmapped channels in a source.
    ///
    /// Resolution order:
    /// 1. exact `tvg_id`
    /// 2. normalized name bridge via `db_epg_channels.display_name`
    /// 3. `xtream_stream_id` fallback
    pub fn resolve_epg_channel_ids(
        &self,
        source_id: &str,
        known_xmltv_ids: &HashSet<String>,
    ) -> Result<usize, DbError> {
        let source_id = source_id.trim();
        if source_id.is_empty() || known_xmltv_ids.is_empty() {
            return Ok(0);
        }

        let conn = self.0.db.get()?;

        #[derive(Debug)]
        struct ChannelRow {
            id: String,
            name: String,
            tvg_name: Option<String>,
            tvg_id: Option<String>,
            xtream_stream_id: Option<String>,
        }

        let mut channels_stmt = conn.prepare(
            "SELECT id, name, tvg_name, tvg_id, xtream_stream_id
             FROM db_channels
             WHERE source_id = ?1
               AND (epg_channel_id IS NULL OR epg_channel_id = '')",
        )?;
        let channels: Vec<ChannelRow> = channels_stmt
            .query_map(params![source_id], |row| {
                Ok(ChannelRow {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    tvg_name: row.get(2)?,
                    tvg_id: row.get(3)?,
                    xtream_stream_id: row.get(4)?,
                })
            })?
            .collect::<rusqlite::Result<_>>()?;

        if channels.is_empty() {
            return Ok(0);
        }

        let mut bridge_stmt = conn.prepare(
            "SELECT xmltv_id, display_name
             FROM db_epg_channels
             WHERE source_id = ?1
               AND display_name IS NOT NULL
               AND TRIM(display_name) != ''",
        )?;
        let mut normalized_bridge: HashMap<String, String> = HashMap::new();
        let bridge_rows = bridge_stmt.query_map(params![source_id], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
        })?;
        for row in bridge_rows {
            let (xmltv_id, display_name) = row?;
            normalized_bridge
                .entry(normalize_channel_name(&display_name))
                .or_insert(xmltv_id);
        }

        let tx = conn.unchecked_transaction()?;
        let mut updated = 0usize;

        for channel in &channels {
            let exact_tvg = channel
                .tvg_id
                .as_deref()
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .filter(|value| known_xmltv_ids.contains(*value))
                .map(str::to_string);

            let bridged_name = exact_tvg.or_else(|| {
                [Some(channel.name.as_str()), channel.tvg_name.as_deref()]
                    .into_iter()
                    .flatten()
                    .find_map(|candidate| {
                        let normalized = normalize_channel_name(candidate);
                        if normalized.is_empty() {
                            None
                        } else {
                            normalized_bridge.get(&normalized).cloned()
                        }
                    })
            });

            let resolved = bridged_name.or_else(|| {
                channel
                    .xtream_stream_id
                    .as_deref()
                    .map(str::trim)
                    .filter(|value| !value.is_empty())
                    .filter(|value| known_xmltv_ids.contains(*value))
                    .map(str::to_string)
            });

            if let Some(epg_channel_id) = resolved {
                updated += tx.execute(
                    "UPDATE db_channels
                     SET epg_channel_id = ?1
                     WHERE id = ?2
                       AND (epg_channel_id IS NULL OR epg_channel_id = '')",
                    params![epg_channel_id, channel.id],
                )?;
            }
        }

        tx.commit()?;
        Ok(updated)
    }

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
        crate::perf_scope!("save_epg_entries");
        crate::profiling::log_memory_usage("save_epg_entries:start");
        let conn = self.0.db.get()?;
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
            self.0.emit(DataChangeEvent::EpgUpdated {
                source_id: channel_id.clone(),
            });
        }
        if entries.is_empty() {
            self.0.emit(DataChangeEvent::EpgUpdated {
                source_id: String::new(),
            });
        }
        #[cfg(debug_assertions)]
        eprintln!("[debug] Inserted {} EPG entries", count);
        Ok(count)
    }

    /// Load all EPG entries grouped by epg_channel_id.
    pub fn load_epg_entries(&self) -> Result<HashMap<String, Vec<EpgEntry>>, DbError> {
        let conn = self.0.db.get()?;
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
        crate::perf_scope!("get_epgs_for_channels");
        let conn = self.0.db.get()?;
        if channel_ids.is_empty() {
            return Ok(HashMap::new());
        }
        let xmltv_to_channels = self.resolve_epg_keys_for_channels(&conn, channel_ids)?;

        if xmltv_to_channels.is_empty() {
            return Ok(HashMap::new());
        }

        // ── Step 4: query EPG entries for all resolved XMLTV IDs ─────
        let xmltv_ids: Vec<String> = xmltv_to_channels.keys().cloned().collect();
        let placeholders: Vec<String> = (1..=xmltv_ids.len()).map(|i| format!("?{i}")).collect();
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
        let mut params: Vec<&dyn rusqlite::types::ToSql> = Vec::with_capacity(xmltv_ids.len() + 2);
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

    /// Resolve the subset of internal channel IDs that have real
    /// EPG coverage overlapping the given time window.
    pub fn get_channels_with_real_epg_coverage(
        &self,
        channel_ids: &[String],
        start_time: i64,
        end_time: i64,
    ) -> Result<Vec<String>, DbError> {
        let conn = self.0.db.get()?;
        let xmltv_to_channels = self.resolve_epg_keys_for_channels(&conn, channel_ids)?;
        if xmltv_to_channels.is_empty() {
            return Ok(Vec::new());
        }

        let xmltv_ids: Vec<String> = xmltv_to_channels.keys().cloned().collect();
        let placeholders: Vec<String> = (1..=xmltv_ids.len()).map(|i| format!("?{i}")).collect();
        let start_p = xmltv_ids.len() + 1;
        let end_p = xmltv_ids.len() + 2;
        let placeholder_p = xmltv_ids.len() + 3;
        let query = format!(
            "SELECT DISTINCT epg_channel_id
             FROM db_epg_entries
             WHERE epg_channel_id IN ({})
               AND end_time > ?{}
               AND start_time < ?{}
               AND (source_id IS NULL OR source_id != ?{})",
            placeholders.join(", "),
            start_p,
            end_p,
            placeholder_p,
        );
        let mut stmt = conn.prepare(&query)?;
        let mut params: Vec<&dyn rusqlite::types::ToSql> = Vec::with_capacity(xmltv_ids.len() + 3);
        for key in &xmltv_ids {
            params.push(key as &dyn rusqlite::types::ToSql);
        }
        params.push(&start_time as &dyn rusqlite::types::ToSql);
        params.push(&end_time as &dyn rusqlite::types::ToSql);
        params.push(&Self::PLACEHOLDER_SOURCE as &dyn rusqlite::types::ToSql);

        let rows = stmt.query_map(params.as_slice(), |row| row.get::<_, String>(0))?;
        let mut covered_ids = HashSet::new();
        for row in rows {
            let epg_channel_id = row?;
            if let Some(channel_ids) = xmltv_to_channels.get(&epg_channel_id) {
                covered_ids.extend(channel_ids.iter().cloned());
            }
        }

        Ok(channel_ids
            .iter()
            .filter(|channel_id| covered_ids.contains(*channel_id))
            .cloned()
            .collect())
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
        let conn = self.0.db.get()?;
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
        _channels: &[crate::models::Channel],
    ) -> Result<usize, DbError> {
        // Placeholder generation removed — 91K fake rows wasted DB space and memory.
        // Real EPG data comes from XMLTV parsing; channels without EPG simply show "No data".
        Ok(0)
    }

    /// Check the latest real (non-placeholder) EPG coverage end time
    /// for a specific channel. Returns `None` if no real data exists.
    pub fn get_real_epg_coverage_end(&self, channel_id: &str) -> Result<Option<i64>, DbError> {
        let conn = self.0.db.get()?;
        let result: rusqlite::Result<Option<i64>> = conn.query_row(
            "SELECT MAX(end_time) FROM db_epg_entries
             WHERE epg_channel_id = ?1 AND (source_id IS NULL OR source_id != ?2)",
            params![channel_id, Self::PLACEHOLDER_SOURCE],
            |row| row.get(0),
        );
        optional(result).map(|opt| opt.flatten())
    }

    /// Check if a channel has real (non-placeholder) EPG data
    /// covering the given time range.
    pub fn has_real_epg_coverage(
        &self,
        channel_id: &str,
        start_time: i64,
        end_time: i64,
    ) -> Result<bool, DbError> {
        let conn = self.0.db.get()?;
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
        let conn = self.0.db.get()?;
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
        let conn = self.0.db.get()?;
        conn.execute("DELETE FROM db_epg_entries", [])?;
        self.0.emit(DataChangeEvent::BulkDataRefresh);
        Ok(())
    }
}

impl EpgRepository for EpgService {
    fn save_epg_entries(
        &self,
        entries: &HashMap<String, Vec<EpgEntry>>,
    ) -> Result<usize, DomainError> {
        Ok(self.save_epg_entries(entries)?)
    }

    fn load_epg_entries(&self) -> Result<HashMap<String, Vec<EpgEntry>>, DomainError> {
        Ok(self.load_epg_entries()?)
    }

    fn get_epgs_for_channels(
        &self,
        channel_ids: &[String],
        start_time: i64,
        end_time: i64,
    ) -> Result<HashMap<String, Vec<EpgEntry>>, DomainError> {
        Ok(self.get_epgs_for_channels(channel_ids, start_time, end_time)?)
    }

    fn get_epg_by_sources(
        &self,
        source_ids: &[String],
    ) -> Result<HashMap<String, Vec<EpgEntry>>, DomainError> {
        Ok(self.get_epg_by_sources(source_ids)?)
    }

    fn generate_placeholders_for_channels(
        &self,
        channels: &[crate::models::Channel],
    ) -> Result<usize, DomainError> {
        Ok(self.generate_placeholders_for_channels(channels)?)
    }

    fn get_real_epg_coverage_end(&self, channel_id: &str) -> Result<Option<i64>, DomainError> {
        Ok(self.get_real_epg_coverage_end(channel_id)?)
    }

    fn has_real_epg_coverage(
        &self,
        channel_id: &str,
        start_time: i64,
        end_time: i64,
    ) -> Result<bool, DomainError> {
        Ok(self.has_real_epg_coverage(channel_id, start_time, end_time)?)
    }

    fn get_channels_with_real_epg_coverage(
        &self,
        channel_ids: &[String],
        start_time: i64,
        end_time: i64,
    ) -> Result<Vec<String>, DomainError> {
        Ok(self.get_channels_with_real_epg_coverage(channel_ids, start_time, end_time)?)
    }

    fn evict_stale_epg(&self, days: i64) -> Result<usize, DomainError> {
        Ok(self.evict_stale_epg(days)?)
    }

    fn clear_epg_entries(&self) -> Result<(), DomainError> {
        Ok(self.clear_epg_entries()?)
    }
}

#[cfg(test)]
mod tests {
    use super::EpgService;
    use super::*;
    use crate::parsers::epg::EpgChannel;
    use crate::services::test_helpers::*;

    #[test]
    fn normalize_channel_name_strips_known_suffixes() {
        assert_eq!(normalize_channel_name("AD Sport 1 HD"), "ad sport 1");
    }

    #[test]
    fn save_epg_channels_persists_rows() {
        let svc = EpgService(make_service_with_fixtures());
        let saved = svc
            .save_epg_channels(
                &[EpgChannel {
                    xmltv_id: "12164".to_string(),
                    display_name: "Al Arabiya".to_string(),
                    icon_url: Some("http://example.com/logo.png".to_string()),
                }],
                "src_a",
            )
            .unwrap();
        assert_eq!(saved, 1);

        let conn = svc.0.db.get().unwrap();
        let row = conn
            .query_row(
                "SELECT xmltv_id, display_name, icon_url, source_id
                 FROM db_epg_channels
                 WHERE xmltv_id = ?1 AND source_id = ?2",
                params!["12164", "src_a"],
                |row| {
                    Ok((
                        row.get::<_, String>(0)?,
                        row.get::<_, String>(1)?,
                        row.get::<_, Option<String>>(2)?,
                        row.get::<_, String>(3)?,
                    ))
                },
            )
            .unwrap();
        assert_eq!(row.0, "12164");
        assert_eq!(row.1, "Al Arabiya");
        assert_eq!(row.2.as_deref(), Some("http://example.com/logo.png"));
        assert_eq!(row.3, "src_a");
    }

    #[test]
    fn resolve_epg_channel_ids_prefers_name_bridge_before_xtream_fallback() {
        let base = make_service_with_fixtures();
        let mut channel = make_channel("ch1", "AD Sport 1 HD");
        channel.source_id = Some("src_a".to_string());
        channel.xtream_stream_id = Some("xtream_fallback".to_string());
        crate::services::ChannelService(base.clone())
            .save_channels(&[channel])
            .unwrap();

        let svc = EpgService(base);
        svc.save_epg_channels(
            &[EpgChannel {
                xmltv_id: "bridge_xmltv".to_string(),
                display_name: "AD Sport 1".to_string(),
                icon_url: None,
            }],
            "src_a",
        )
        .unwrap();

        let updated = svc
            .resolve_epg_channel_ids(
                "src_a",
                &HashSet::from(["bridge_xmltv".to_string(), "xtream_fallback".to_string()]),
            )
            .unwrap();
        assert_eq!(updated, 1);

        let resolved = svc
            .0
            .db
            .get()
            .unwrap()
            .query_row(
                "SELECT epg_channel_id FROM db_channels WHERE id = ?1",
                params!["ch1"],
                |row| row.get::<_, Option<String>>(0),
            )
            .unwrap();
        assert_eq!(resolved.as_deref(), Some("bridge_xmltv"));
    }

    #[test]
    fn save_and_load_epg_entries() {
        let svc = EpgService(make_service());
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
        let base = make_service();
        // Create a channel with tvg_id — the EPG bridge used by get_epgs_for_channels.
        let mut ch = make_channel("ch1", "Test Channel");
        ch.tvg_id = Some("tvg_ch1".to_string());
        crate::services::ChannelService(base.clone())
            .save_channels(&[ch])
            .unwrap();
        let svc = EpgService(base);

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
        let svc = EpgService(make_service_with_fixtures());
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
        let svc = EpgService(make_service_with_fixtures());
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
        let svc = EpgService(make_service());
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
        let svc = EpgService(make_service());
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
        let base = make_service();
        let log: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let log_clone = log.clone();
        base.set_event_callback(Arc::new(move |e| {
            log_clone.lock().unwrap().push(serialize_event(e));
        }));
        let svc = EpgService(base);
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
        let base = make_service();
        let mut src_a = make_source("src_a", "Source A", "m3u");
        src_a.sort_order = 0;
        let mut src_b = make_source("src_b", "Source B", "m3u");
        src_b.sort_order = 5;
        crate::services::SourceService(base.clone())
            .save_source(&src_a)
            .unwrap();
        crate::services::SourceService(base.clone())
            .save_source(&src_b)
            .unwrap();
        let svc = EpgService(base);

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
        let base = make_service();
        let mut src_a = make_source("src_a", "Source A", "m3u");
        src_a.sort_order = 0;
        crate::services::SourceService(base.clone())
            .save_source(&src_a)
            .unwrap();
        let svc = EpgService(base);

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
        let base = make_service();
        let mut src_a = make_source("src_a", "Source A", "m3u");
        src_a.sort_order = 3;
        let mut src_b = make_source("src_b", "Source B", "m3u");
        src_b.sort_order = 3;
        crate::services::SourceService(base.clone())
            .save_source(&src_a)
            .unwrap();
        crate::services::SourceService(base.clone())
            .save_source(&src_b)
            .unwrap();
        let svc = EpgService(base);

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
        let base = make_service();
        let mut src_a = make_source("src_a", "Source A", "m3u");
        src_a.sort_order = 10;
        crate::services::SourceService(base.clone())
            .save_source(&src_a)
            .unwrap();
        let svc = EpgService(base);

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
        let base = make_service();
        let mut src_a = make_source("src_a", "Source A", "m3u");
        src_a.sort_order = 0;
        crate::services::SourceService(base.clone())
            .save_source(&src_a)
            .unwrap();
        let svc = EpgService(base);

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
