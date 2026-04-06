use rusqlite::params;
use serde_json::{Value, json};

use super::ServiceContext;
use crate::algorithms::stream_alternatives::normalize_for_matching;
use crate::database::DbError;
use crate::events::DataChangeEvent;
use crate::insert_or_replace;

/// Domain service for smart channel group operations.
pub struct SmartGroupService(pub ServiceContext);

impl SmartGroupService {
    // ── Smart Channel Groups ────────────────────────────

    /// Create a new smart channel group. Returns its UUID.
    pub fn create_smart_group(&self, name: &str) -> Result<String, DbError> {
        let id = uuid::Uuid::new_v4().to_string();
        let now = chrono::Utc::now().timestamp();
        let conn = self.0.db.get()?;
        conn.execute(
            "INSERT INTO db_smart_groups (id, name, created_at)
             VALUES (?1, ?2, ?3)",
            params![id, name, now],
        )?;
        self.0.emit(DataChangeEvent::SmartGroupChanged);
        Ok(id)
    }

    /// Delete a smart group and all its members (CASCADE).
    pub fn delete_smart_group(&self, group_id: &str) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        conn.execute(
            "DELETE FROM db_smart_groups WHERE id = ?1",
            params![group_id],
        )?;
        self.0.emit(DataChangeEvent::SmartGroupChanged);
        Ok(())
    }

    /// Rename a smart group.
    pub fn rename_smart_group(&self, group_id: &str, name: &str) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        conn.execute(
            "UPDATE db_smart_groups SET name = ?2 WHERE id = ?1",
            params![group_id, name],
        )?;
        self.0.emit(DataChangeEvent::SmartGroupChanged);
        Ok(())
    }

    /// Add a channel to a smart group with a given priority.
    pub fn add_smart_group_member(
        &self,
        group_id: &str,
        channel_id: &str,
        source_id: &str,
        priority: i32,
    ) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        insert_or_replace!(
            conn,
            "db_smart_group_members",
            ["group_id", "channel_id", "source_id", "priority"],
            params![group_id, channel_id, source_id, priority],
        )?;
        self.0.emit(DataChangeEvent::SmartGroupChanged);
        Ok(())
    }

    /// Remove a channel from a smart group.
    pub fn remove_smart_group_member(
        &self,
        group_id: &str,
        channel_id: &str,
    ) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        conn.execute(
            "DELETE FROM db_smart_group_members
             WHERE group_id = ?1 AND channel_id = ?2",
            params![group_id, channel_id],
        )?;
        self.0.emit(DataChangeEvent::SmartGroupChanged);
        Ok(())
    }

    /// Reorder members of a smart group.
    /// `ordered_channel_ids_json` is a JSON array of channel IDs
    /// in the desired priority order.
    pub fn reorder_smart_group_members(
        &self,
        group_id: &str,
        ordered_channel_ids_json: &str,
    ) -> Result<(), DbError> {
        let ids: Vec<String> = serde_json::from_str(ordered_channel_ids_json)
            .map_err(|e| DbError::Migration(e.to_string()))?;
        let conn = self.0.db.get()?;
        for (i, id) in ids.iter().enumerate() {
            conn.execute(
                "UPDATE db_smart_group_members
                 SET priority = ?3
                 WHERE group_id = ?1 AND channel_id = ?2",
                params![group_id, id, i as i32],
            )?;
        }
        self.0.emit(DataChangeEvent::SmartGroupChanged);
        Ok(())
    }

    /// Load all smart groups with their members as JSON.
    ///
    /// Returns a JSON array:
    /// ```json
    /// [
    ///   {
    ///     "id": "uuid",
    ///     "name": "ESPN",
    ///     "created_at": 1234567890,
    ///     "members": [
    ///       { "channel_id": "ch1", "source_id": "s1", "priority": 0 },
    ///       { "channel_id": "ch2", "source_id": "s2", "priority": 1 }
    ///     ]
    ///   }
    /// ]
    /// ```
    pub fn get_smart_groups_json(&self) -> Result<String, DbError> {
        let conn = self.0.db.get()?;
        let mut group_stmt =
            conn.prepare("SELECT id, name, created_at FROM db_smart_groups ORDER BY name")?;
        let mut member_stmt = conn.prepare(
            "SELECT channel_id, source_id, priority
             FROM db_smart_group_members
             WHERE group_id = ?1
             ORDER BY priority ASC",
        )?;

        let mut groups = Vec::new();
        let group_rows = group_stmt.query_map([], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, i64>(2)?,
            ))
        })?;

        for row in group_rows {
            let (id, name, created_at) = row?;
            let mut members = Vec::new();
            let member_rows = member_stmt.query_map(params![&id], |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, i32>(2)?,
                ))
            })?;
            for m in member_rows {
                let (channel_id, source_id, priority) = m?;
                members.push(json!({
                    "channel_id": channel_id,
                    "source_id": source_id,
                    "priority": priority,
                }));
            }
            groups.push(json!({
                "id": id,
                "name": name,
                "created_at": created_at,
                "members": members,
            }));
        }

        Ok(serde_json::to_string(&groups).unwrap_or_else(|_| "[]".to_string()))
    }

    /// Get the smart group (if any) that a channel belongs to.
    /// Returns the group JSON or None.
    pub fn get_smart_group_for_channel(&self, channel_id: &str) -> Result<Option<String>, DbError> {
        let conn = self.0.db.get()?;
        let group_id: Option<String> = conn
            .query_row(
                "SELECT group_id FROM db_smart_group_members
                 WHERE channel_id = ?1 LIMIT 1",
                params![channel_id],
                |row| row.get(0),
            )
            .ok();

        match group_id {
            Some(gid) => {
                // Fetch full group with members.
                let name: String = conn.query_row(
                    "SELECT name FROM db_smart_groups WHERE id = ?1",
                    params![gid],
                    |row| row.get(0),
                )?;
                let mut stmt = conn.prepare(
                    "SELECT channel_id, source_id, priority
                     FROM db_smart_group_members
                     WHERE group_id = ?1
                     ORDER BY priority ASC",
                )?;
                let mut members = Vec::new();
                let rows = stmt.query_map(params![gid], |row| {
                    Ok((
                        row.get::<_, String>(0)?,
                        row.get::<_, String>(1)?,
                        row.get::<_, i32>(2)?,
                    ))
                })?;
                for r in rows {
                    let (cid, sid, pri) = r?;
                    members.push(json!({
                        "channel_id": cid,
                        "source_id": sid,
                        "priority": pri,
                    }));
                }
                Ok(Some(
                    serde_json::to_string(&json!({
                        "id": gid,
                        "name": name,
                        "members": members,
                    }))
                    .unwrap_or_default(),
                ))
            }
            None => Ok(None),
        }
    }

    /// Get smart group alternatives for a channel, excluding
    /// same-source channels. Returns JSON array of
    /// `{ channel_id, source_id, priority }` sorted by priority.
    pub fn get_smart_group_alternatives(&self, channel_id: &str) -> Result<String, DbError> {
        let conn = self.0.db.get()?;

        // Find this channel's group and source.
        let member: Option<(String, String)> = conn
            .query_row(
                "SELECT group_id, source_id
                 FROM db_smart_group_members
                 WHERE channel_id = ?1 LIMIT 1",
                params![channel_id],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )
            .ok();

        let (group_id, current_source) = match member {
            Some(m) => m,
            None => return Ok("[]".to_string()),
        };

        let mut stmt = conn.prepare(
            "SELECT channel_id, source_id, priority
             FROM db_smart_group_members
             WHERE group_id = ?1
               AND channel_id != ?2
               AND source_id != ?3
             ORDER BY priority ASC",
        )?;
        let mut alts = Vec::new();
        let rows = stmt.query_map(params![group_id, channel_id, current_source], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, i32>(2)?,
            ))
        })?;
        for r in rows {
            let (cid, sid, pri) = r?;
            alts.push(json!({
                "channel_id": cid,
                "source_id": sid,
                "priority": pri,
            }));
        }

        Ok(serde_json::to_string(&alts).unwrap_or_else(|_| "[]".to_string()))
    }

    /// Auto-detect potential smart group candidates by finding
    /// channels with the same normalized name across different
    /// sources. Excludes channels already in existing groups.
    ///
    /// Returns JSON array:
    /// ```json
    /// [
    ///   {
    ///     "suggested_name": "ESPN",
    ///     "members": [
    ///       { "channel_id": "ch1", "source_id": "s1", "channel_name": "ESPN HD" },
    ///       { "channel_id": "ch2", "source_id": "s2", "channel_name": "US: ESPN" }
    ///     ]
    ///   }
    /// ]
    /// ```
    pub fn detect_smart_group_candidates(&self) -> Result<String, DbError> {
        let conn = self.0.db.get()?;

        // Get channel IDs already in smart groups.
        let mut existing_stmt = conn.prepare("SELECT channel_id FROM db_smart_group_members")?;
        let existing: std::collections::HashSet<String> = existing_stmt
            .query_map([], |row| row.get(0))?
            .filter_map(|r| r.ok())
            .collect();

        // Load all channels.
        let mut ch_stmt = conn.prepare("SELECT id, name, source_id FROM db_channels")?;

        struct ChRef {
            channel_id: String,
            source_id: String,
            channel_name: String,
        }

        let mut groups: std::collections::HashMap<String, Vec<ChRef>> =
            std::collections::HashMap::new();

        let rows = ch_stmt.query_map([], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, String>(2)?,
            ))
        })?;

        for row in rows {
            let (id, name, source_id) = row?;
            if existing.contains(&id) {
                continue;
            }
            let norm = normalize_for_matching(&name);
            if norm.is_empty() {
                continue;
            }
            groups.entry(norm).or_default().push(ChRef {
                channel_id: id,
                source_id,
                channel_name: name,
            });
        }

        // Filter: keep only groups with 2+ channels from different sources.
        let mut candidates: Vec<Value> = Vec::new();
        let mut sorted_keys: Vec<String> = groups.keys().cloned().collect();
        sorted_keys.sort();

        for key in sorted_keys {
            let members = &groups[&key];
            if members.len() < 2 {
                continue;
            }
            // Check multiple sources.
            let mut source_set = std::collections::HashSet::new();
            for m in members {
                source_set.insert(&m.source_id);
            }
            if source_set.len() < 2 {
                continue;
            }

            let member_vals: Vec<Value> = members
                .iter()
                .map(|m| {
                    json!({
                        "channel_id": m.channel_id,
                        "source_id": m.source_id,
                        "channel_name": m.channel_name,
                    })
                })
                .collect();

            // Use the shortest original name as suggested name.
            let suggested = members
                .iter()
                .min_by_key(|m| m.channel_name.len())
                .map(|m| m.channel_name.clone())
                .unwrap_or(key);

            candidates.push(json!({
                "suggested_name": suggested,
                "members": member_vals,
            }));
        }

        Ok(serde_json::to_string(&candidates).unwrap_or_else(|_| "[]".to_string()))
    }
}

#[cfg(test)]
mod tests {
    use super::SmartGroupService;
    use crate::insert_or_replace;
    use crate::services::channels::ChannelService;
    use crate::services::test_helpers::*;

    #[test]
    fn smart_group_crud() {
        let base = make_service_with_fixtures();
        ChannelService(base.clone())
            .save_channels(&[make_channel("ch1", "Ch1"), make_channel("ch2", "Ch2")])
            .unwrap();
        let svc = SmartGroupService(base);

        // Create a group.
        let gid = svc.create_smart_group("ESPN").unwrap();
        assert!(!gid.is_empty());

        // Add members.
        svc.add_smart_group_member(&gid, "ch1", "src1", 0).unwrap();
        svc.add_smart_group_member(&gid, "ch2", "src2", 1).unwrap();

        // Load groups.
        let json = svc.get_smart_groups_json().unwrap();
        let groups: Vec<serde_json::Value> = serde_json::from_str(&json).unwrap();
        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0]["name"], "ESPN");
        assert_eq!(groups[0]["members"].as_array().unwrap().len(), 2);

        // Rename.
        svc.rename_smart_group(&gid, "ESPN Group").unwrap();
        let json = svc.get_smart_groups_json().unwrap();
        let groups: Vec<serde_json::Value> = serde_json::from_str(&json).unwrap();
        assert_eq!(groups[0]["name"], "ESPN Group");

        // Remove member.
        svc.remove_smart_group_member(&gid, "ch1").unwrap();
        let json = svc.get_smart_groups_json().unwrap();
        let groups: Vec<serde_json::Value> = serde_json::from_str(&json).unwrap();
        assert_eq!(groups[0]["members"].as_array().unwrap().len(), 1);

        // Delete group.
        svc.delete_smart_group(&gid).unwrap();
        let json = svc.get_smart_groups_json().unwrap();
        let groups: Vec<serde_json::Value> = serde_json::from_str(&json).unwrap();
        assert!(groups.is_empty());
    }

    #[test]
    fn smart_group_member_priority_ordering() {
        let base = make_service_with_fixtures();
        ChannelService(base.clone())
            .save_channels(&[
                make_channel("ch_a", "ChA"),
                make_channel("ch_b", "ChB"),
                make_channel("ch_c", "ChC"),
            ])
            .unwrap();
        let svc = SmartGroupService(base);
        let gid = svc.create_smart_group("Fox News").unwrap();

        svc.add_smart_group_member(&gid, "ch_a", "s1", 2).unwrap();
        svc.add_smart_group_member(&gid, "ch_b", "s2", 0).unwrap();
        svc.add_smart_group_member(&gid, "ch_c", "s3", 1).unwrap();

        let json = svc.get_smart_groups_json().unwrap();
        let groups: Vec<serde_json::Value> = serde_json::from_str(&json).unwrap();
        let members = groups[0]["members"].as_array().unwrap();
        assert_eq!(members[0]["channel_id"], "ch_b"); // priority 0
        assert_eq!(members[1]["channel_id"], "ch_c"); // priority 1
        assert_eq!(members[2]["channel_id"], "ch_a"); // priority 2
    }

    #[test]
    fn smart_group_reorder() {
        let base = make_service_with_fixtures();
        ChannelService(base.clone())
            .save_channels(&[
                make_channel("ch1", "Ch1"),
                make_channel("ch2", "Ch2"),
                make_channel("ch3", "Ch3"),
            ])
            .unwrap();
        let svc = SmartGroupService(base);
        let gid = svc.create_smart_group("CNN").unwrap();

        svc.add_smart_group_member(&gid, "ch1", "s1", 0).unwrap();
        svc.add_smart_group_member(&gid, "ch2", "s2", 1).unwrap();
        svc.add_smart_group_member(&gid, "ch3", "s3", 2).unwrap();

        // Reorder: ch3 first, ch1 second, ch2 third.
        svc.reorder_smart_group_members(&gid, r#"["ch3","ch1","ch2"]"#)
            .unwrap();

        let json = svc.get_smart_groups_json().unwrap();
        let groups: Vec<serde_json::Value> = serde_json::from_str(&json).unwrap();
        let members = groups[0]["members"].as_array().unwrap();
        assert_eq!(members[0]["channel_id"], "ch3");
        assert_eq!(members[1]["channel_id"], "ch1");
        assert_eq!(members[2]["channel_id"], "ch2");
    }

    #[test]
    fn get_smart_group_for_channel() {
        let base = make_service_with_fixtures();
        ChannelService(base.clone())
            .save_channels(&[make_channel("ch1", "Ch1"), make_channel("ch2", "Ch2")])
            .unwrap();
        let svc = SmartGroupService(base);
        let gid = svc.create_smart_group("BBC").unwrap();
        svc.add_smart_group_member(&gid, "ch1", "s1", 0).unwrap();
        svc.add_smart_group_member(&gid, "ch2", "s2", 1).unwrap();

        // Channel in a group.
        let result = svc.get_smart_group_for_channel("ch1").unwrap();
        assert!(result.is_some());
        let group: serde_json::Value = serde_json::from_str(&result.unwrap()).unwrap();
        assert_eq!(group["name"], "BBC");
        assert_eq!(group["members"].as_array().unwrap().len(), 2);

        // Channel not in any group.
        let result = svc.get_smart_group_for_channel("ch_unknown").unwrap();
        assert!(result.is_none());
    }

    #[test]
    fn get_smart_group_alternatives_excludes_same_source() {
        let base = make_service_with_fixtures();
        ChannelService(base.clone())
            .save_channels(&[
                make_channel("ch1", "Ch1"),
                make_channel("ch2", "Ch2"),
                make_channel("ch3", "Ch3"),
                make_channel("ch4", "Ch4"),
            ])
            .unwrap();
        let svc = SmartGroupService(base);
        let gid = svc.create_smart_group("ESPN").unwrap();
        svc.add_smart_group_member(&gid, "ch1", "src_a", 0).unwrap();
        svc.add_smart_group_member(&gid, "ch2", "src_b", 1).unwrap();
        svc.add_smart_group_member(&gid, "ch3", "src_a", 2).unwrap(); // same source as ch1
        svc.add_smart_group_member(&gid, "ch4", "src_c", 3).unwrap();

        let json = svc.get_smart_group_alternatives("ch1").unwrap();
        let alts: Vec<serde_json::Value> = serde_json::from_str(&json).unwrap();

        // ch3 is excluded (same source as ch1), ch1 excluded (self).
        assert_eq!(alts.len(), 2);
        assert_eq!(alts[0]["channel_id"], "ch2");
        assert_eq!(alts[1]["channel_id"], "ch4");
    }

    #[test]
    fn get_alternatives_for_ungrouped_channel() {
        let svc = SmartGroupService(make_service_with_fixtures());
        let json = svc.get_smart_group_alternatives("ch_nowhere").unwrap();
        assert_eq!(json, "[]");
    }

    #[test]
    fn detect_candidates_finds_same_name_across_sources() {
        let svc = SmartGroupService(make_service_with_fixtures());
        // Insert channels with same normalized name across sources.
        insert_channel(&svc, "ch1", "ESPN HD", "http://a.m3u8", "src1");
        insert_channel(&svc, "ch2", "US: ESPN", "http://b.m3u8", "src2");
        insert_channel(&svc, "ch3", "Fox News", "http://c.m3u8", "src1");
        insert_channel(&svc, "ch4", "Unique Channel", "http://d.m3u8", "src1");

        let json = svc.detect_smart_group_candidates().unwrap();
        let candidates: Vec<serde_json::Value> = serde_json::from_str(&json).unwrap();

        // Only ESPN should be a candidate (2 channels from different sources).
        // Fox News has only 1 channel. Unique Channel has only 1.
        assert_eq!(candidates.len(), 1);
        assert_eq!(candidates[0]["members"].as_array().unwrap().len(), 2);
    }

    #[test]
    fn detect_candidates_excludes_already_grouped() {
        let svc = SmartGroupService(make_service_with_fixtures());
        insert_channel(&svc, "ch1", "ESPN HD", "http://a.m3u8", "src1");
        insert_channel(&svc, "ch2", "ESPN", "http://b.m3u8", "src2");

        // Put ch1 in a group already.
        let gid = svc.create_smart_group("ESPN Manual").unwrap();
        svc.add_smart_group_member(&gid, "ch1", "src1", 0).unwrap();

        let json = svc.detect_smart_group_candidates().unwrap();
        let candidates: Vec<serde_json::Value> = serde_json::from_str(&json).unwrap();

        // ch1 is excluded → only ch2 remains → no candidate (need 2+).
        assert!(candidates.is_empty());
    }

    #[test]
    fn detect_candidates_ignores_same_source_duplicates() {
        let svc = SmartGroupService(make_service_with_fixtures());
        insert_channel(&svc, "ch1", "ESPN", "http://a.m3u8", "src1");
        insert_channel(&svc, "ch2", "ESPN", "http://b.m3u8", "src1"); // same source

        let json = svc.detect_smart_group_candidates().unwrap();
        let candidates: Vec<serde_json::Value> = serde_json::from_str(&json).unwrap();

        // Both from same source → not a cross-provider group.
        assert!(candidates.is_empty());
    }

    #[test]
    fn delete_group_cascades_members() {
        let base = make_service_with_fixtures();
        ChannelService(base.clone())
            .save_channels(&[make_channel("ch1", "Ch1"), make_channel("ch2", "Ch2")])
            .unwrap();
        let svc = SmartGroupService(base);
        let gid = svc.create_smart_group("Test").unwrap();
        svc.add_smart_group_member(&gid, "ch1", "s1", 0).unwrap();
        svc.add_smart_group_member(&gid, "ch2", "s2", 1).unwrap();

        svc.delete_smart_group(&gid).unwrap();

        // Channel should no longer be in any group.
        let result = svc.get_smart_group_for_channel("ch1").unwrap();
        assert!(result.is_none());
    }

    /// Helper to insert a channel for testing.
    fn insert_channel(svc: &SmartGroupService, id: &str, name: &str, url: &str, source_id: &str) {
        let conn = svc.0.db.get().unwrap();
        insert_or_replace!(
            conn,
            "db_channels",
            ["id", "native_id", "name", "stream_url", "source_id"],
            rusqlite::params![id, id, name, url, source_id],
        )
        .unwrap();
    }
}
