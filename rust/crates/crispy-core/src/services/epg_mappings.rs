use rusqlite::params;

use super::{CrispyService, bool_to_int, int_to_bool};
use crate::database::DbError;
use crate::models::EpgMapping;

impl CrispyService {
    /// Save or update an EPG mapping.
    pub fn save_epg_mapping(&self, mapping: &EpgMapping) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute(
            "INSERT OR REPLACE INTO db_epg_mappings \
             (channel_id, epg_channel_id, confidence, match_method, epg_source_id, locked, created_at) \
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![
                mapping.channel_id,
                mapping.epg_channel_id,
                mapping.confidence,
                mapping.match_method,
                mapping.epg_source_id,
                bool_to_int(mapping.locked),
                mapping.created_at,
            ],
        )?;
        Ok(())
    }

    /// Get all EPG mappings.
    pub fn get_epg_mappings(&self) -> Result<Vec<EpgMapping>, DbError> {
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT channel_id, epg_channel_id, confidence, match_method, epg_source_id, locked, created_at \
             FROM db_epg_mappings ORDER BY confidence DESC",
        )?;
        let rows = stmt
            .query_map([], |row| {
                Ok(EpgMapping {
                    channel_id: row.get(0)?,
                    epg_channel_id: row.get(1)?,
                    confidence: row.get(2)?,
                    match_method: row.get(3)?,
                    epg_source_id: row.get(4)?,
                    locked: int_to_bool(row.get(5)?),
                    created_at: row.get(6)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(rows)
    }

    /// Lock an EPG mapping so it won't be overridden.
    pub fn lock_epg_mapping(&self, channel_id: &str) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute(
            "UPDATE db_epg_mappings SET locked = 1 WHERE channel_id = ?1",
            params![channel_id],
        )?;
        Ok(())
    }

    /// Delete an EPG mapping.
    pub fn delete_epg_mapping(&self, channel_id: &str) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute(
            "DELETE FROM db_epg_mappings WHERE channel_id = ?1",
            params![channel_id],
        )?;
        Ok(())
    }

    /// Get pending EPG suggestions (confidence 0.40-0.69, not locked).
    pub fn get_pending_epg_suggestions(&self) -> Result<Vec<EpgMapping>, DbError> {
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT channel_id, epg_channel_id, confidence, match_method, epg_source_id, locked, created_at \
             FROM db_epg_mappings \
             WHERE confidence >= 0.40 AND confidence < 0.70 AND locked = 0 \
             ORDER BY confidence DESC",
        )?;
        let rows = stmt
            .query_map([], |row| {
                Ok(EpgMapping {
                    channel_id: row.get(0)?,
                    epg_channel_id: row.get(1)?,
                    confidence: row.get(2)?,
                    match_method: row.get(3)?,
                    epg_source_id: row.get(4)?,
                    locked: int_to_bool(row.get(5)?),
                    created_at: row.get(6)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(rows)
    }

    /// Mark a channel as 24/7.
    pub fn set_channel_247(&self, channel_id: &str, is_247: bool) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute(
            "UPDATE db_channels SET is_247 = ?1 WHERE id = ?2",
            params![bool_to_int(is_247), channel_id],
        )?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::services::test_helpers::*;

    #[test]
    fn save_and_get_mapping() {
        let svc = make_service();
        let mapping = EpgMapping {
            channel_id: "ch1".to_string(),
            epg_channel_id: "epg1".to_string(),
            confidence: 0.85,
            match_method: "tvg_id_exact".to_string(),
            epg_source_id: None,
            locked: false,
            created_at: 1000,
        };
        svc.save_epg_mapping(&mapping).unwrap();

        let all = svc.get_epg_mappings().unwrap();
        assert_eq!(all.len(), 1);
        assert_eq!(all[0].channel_id, "ch1");
        assert_eq!(all[0].epg_channel_id, "epg1");
        assert!((all[0].confidence - 0.85).abs() < 0.001);
        assert!(!all[0].locked);
    }

    #[test]
    fn lock_mapping() {
        let svc = make_service();
        svc.save_epg_mapping(&EpgMapping {
            channel_id: "ch1".to_string(),
            epg_channel_id: "epg1".to_string(),
            confidence: 0.90,
            match_method: "tvg_id_exact".to_string(),
            epg_source_id: None,
            locked: false,
            created_at: 1000,
        })
        .unwrap();

        svc.lock_epg_mapping("ch1").unwrap();

        let all = svc.get_epg_mappings().unwrap();
        assert!(all[0].locked);
    }

    #[test]
    fn delete_mapping() {
        let svc = make_service();
        svc.save_epg_mapping(&EpgMapping {
            channel_id: "ch1".to_string(),
            epg_channel_id: "epg1".to_string(),
            confidence: 0.90,
            match_method: "tvg_id_exact".to_string(),
            epg_source_id: None,
            locked: false,
            created_at: 1000,
        })
        .unwrap();

        svc.delete_epg_mapping("ch1").unwrap();

        let all = svc.get_epg_mappings().unwrap();
        assert!(all.is_empty());
    }

    #[test]
    fn pending_suggestions_filters_correctly() {
        let svc = make_service();
        // Auto-applied (>= 0.70) — NOT pending
        svc.save_epg_mapping(&EpgMapping {
            channel_id: "ch1".to_string(),
            epg_channel_id: "epg1".to_string(),
            confidence: 0.85,
            match_method: "tvg_id_exact".to_string(),
            epg_source_id: None,
            locked: false,
            created_at: 1000,
        })
        .unwrap();
        // Suggestion (0.40-0.69) — IS pending
        svc.save_epg_mapping(&EpgMapping {
            channel_id: "ch2".to_string(),
            epg_channel_id: "epg2".to_string(),
            confidence: 0.55,
            match_method: "fuzzy".to_string(),
            epg_source_id: None,
            locked: false,
            created_at: 1000,
        })
        .unwrap();
        // Below threshold (< 0.40) — NOT pending
        svc.save_epg_mapping(&EpgMapping {
            channel_id: "ch3".to_string(),
            epg_channel_id: "epg3".to_string(),
            confidence: 0.30,
            match_method: "fuzzy".to_string(),
            epg_source_id: None,
            locked: false,
            created_at: 1000,
        })
        .unwrap();
        // Locked suggestion — NOT pending
        svc.save_epg_mapping(&EpgMapping {
            channel_id: "ch4".to_string(),
            epg_channel_id: "epg4".to_string(),
            confidence: 0.50,
            match_method: "fuzzy".to_string(),
            epg_source_id: None,
            locked: true,
            created_at: 1000,
        })
        .unwrap();

        let pending = svc.get_pending_epg_suggestions().unwrap();
        assert_eq!(pending.len(), 1);
        assert_eq!(pending[0].channel_id, "ch2");
    }

    #[test]
    fn set_channel_247_flag() {
        let svc = make_service();
        let ch = make_channel("ch1", "Movies 24/7");
        svc.save_channels(&[ch]).unwrap();

        svc.set_channel_247("ch1", true).unwrap();

        let channels = svc.load_channels().unwrap();
        assert!(channels[0].is_247);
    }

    #[test]
    fn upsert_mapping_overwrites() {
        let svc = make_service();
        svc.save_epg_mapping(&EpgMapping {
            channel_id: "ch1".to_string(),
            epg_channel_id: "epg1".to_string(),
            confidence: 0.50,
            match_method: "fuzzy".to_string(),
            epg_source_id: None,
            locked: false,
            created_at: 1000,
        })
        .unwrap();

        // Upsert with higher confidence
        svc.save_epg_mapping(&EpgMapping {
            channel_id: "ch1".to_string(),
            epg_channel_id: "epg2".to_string(),
            confidence: 0.90,
            match_method: "tvg_id_exact".to_string(),
            epg_source_id: None,
            locked: false,
            created_at: 2000,
        })
        .unwrap();

        let all = svc.get_epg_mappings().unwrap();
        assert_eq!(all.len(), 1);
        assert_eq!(all[0].epg_channel_id, "epg2");
        assert!((all[0].confidence - 0.90).abs() < 0.001);
    }
}
