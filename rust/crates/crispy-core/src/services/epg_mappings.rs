use rusqlite::{Row, params};

use super::{ServiceContext, bool_to_int, int_to_bool};
use crate::database::DbError;
use crate::models::EpgMapping;
use crate::insert_or_replace;

fn epg_mapping_from_row(row: &Row) -> rusqlite::Result<EpgMapping> {
    Ok(EpgMapping {
        channel_id: row.get(0)?,
        epg_channel_id: row.get(1)?,
        confidence: row.get(2)?,
        match_method: row
            .get::<_, String>(3)
            .map(|s| s.as_str().try_into().unwrap_or_default())
            .unwrap_or_default(),
        epg_source_id: row.get(4)?,
        locked: int_to_bool(row.get(5)?),
        created_at: row.get(6)?,
    })
}

/// Domain service for EPG mapping operations.
pub struct EpgMappingService(pub ServiceContext);

impl EpgMappingService {
    /// Save or update an EPG mapping.
    pub fn save_epg_mapping(&self, mapping: &EpgMapping) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        insert_or_replace!(
            conn,
            "db_epg_mappings",
            [
                "channel_id",
                "epg_channel_id",
                "confidence",
                "match_method",
                "epg_source_id",
                "locked",
                "created_at",
            ],
            params![
                mapping.channel_id,
                mapping.epg_channel_id,
                mapping.confidence,
                mapping.match_method.as_str(),
                mapping.epg_source_id,
                bool_to_int(mapping.locked),
                mapping.created_at,
            ],
        )?;
        Ok(())
    }

    /// Get all EPG mappings.
    pub fn get_epg_mappings(&self) -> Result<Vec<EpgMapping>, DbError> {
        let conn = self.0.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT channel_id, epg_channel_id, confidence, match_method, epg_source_id, locked, created_at \
             FROM db_epg_mappings ORDER BY confidence DESC",
        )?;
        let rows = stmt
            .query_map([], epg_mapping_from_row)?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(rows)
    }

    /// Lock an EPG mapping so it won't be overridden.
    pub fn lock_epg_mapping(&self, channel_id: &str) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        conn.execute(
            "UPDATE db_epg_mappings SET locked = 1 WHERE channel_id = ?1",
            params![channel_id],
        )?;
        Ok(())
    }

    /// Delete an EPG mapping.
    pub fn delete_epg_mapping(&self, channel_id: &str) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
        conn.execute(
            "DELETE FROM db_epg_mappings WHERE channel_id = ?1",
            params![channel_id],
        )?;
        Ok(())
    }

    /// Get pending EPG suggestions (confidence 0.40-0.69, not locked).
    pub fn get_pending_epg_suggestions(&self) -> Result<Vec<EpgMapping>, DbError> {
        let conn = self.0.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT channel_id, epg_channel_id, confidence, match_method, epg_source_id, locked, created_at \
             FROM db_epg_mappings \
             WHERE confidence >= 0.40 AND confidence < 0.70 AND locked = 0 \
             ORDER BY confidence DESC",
        )?;
        let rows = stmt
            .query_map([], epg_mapping_from_row)?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(rows)
    }

    /// Mark a channel as 24/7.
    pub fn set_channel_247(&self, channel_id: &str, is_247: bool) -> Result<(), DbError> {
        let conn = self.0.db.get()?;
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
    use crate::value_objects::MatchMethod;
    use super::EpgMappingService;

    #[test]
    fn save_and_get_mapping() {
        let svc = EpgMappingService(make_service());
        let mapping = EpgMapping {
            channel_id: "ch1".to_string(),
            epg_channel_id: "epg1".to_string(),
            confidence: 0.85,
            match_method: MatchMethod::TvgIdExact,
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
        let svc = EpgMappingService(make_service());
        svc.save_epg_mapping(&EpgMapping {
            channel_id: "ch1".to_string(),
            epg_channel_id: "epg1".to_string(),
            confidence: 0.90,
            match_method: MatchMethod::TvgIdExact,
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
        let svc = EpgMappingService(make_service());
        svc.save_epg_mapping(&EpgMapping {
            channel_id: "ch1".to_string(),
            epg_channel_id: "epg1".to_string(),
            confidence: 0.90,
            match_method: MatchMethod::TvgIdExact,
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
        let svc = EpgMappingService(make_service());
        // Auto-applied (>= 0.70) — NOT pending
        svc.save_epg_mapping(&EpgMapping {
            channel_id: "ch1".to_string(),
            epg_channel_id: "epg1".to_string(),
            confidence: 0.85,
            match_method: MatchMethod::TvgIdExact,
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
            match_method: MatchMethod::Fuzzy,
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
            match_method: MatchMethod::Fuzzy,
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
            match_method: MatchMethod::Fuzzy,
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
        use crate::services::channels::ChannelService;
        let base = make_service();
        let ch = make_channel("ch1", "Movies 24/7");
        ChannelService(base.clone()).save_channels(&[ch]).unwrap();
        let svc = EpgMappingService(base);

        svc.set_channel_247("ch1", true).unwrap();

        let channels = ChannelService(svc.0.clone()).load_channels().unwrap();
        assert!(channels[0].is_247);
    }

    #[test]
    fn upsert_mapping_overwrites() {
        let svc = EpgMappingService(make_service());
        svc.save_epg_mapping(&EpgMapping {
            channel_id: "ch1".to_string(),
            epg_channel_id: "epg1".to_string(),
            confidence: 0.50,
            match_method: MatchMethod::Fuzzy,
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
            match_method: MatchMethod::TvgIdExact,
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
