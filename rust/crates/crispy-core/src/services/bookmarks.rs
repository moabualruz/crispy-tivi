use rusqlite::params;

use super::{CrispyService, dt_to_ts, ts_to_dt};
use crate::database::DbError;
use crate::events::DataChangeEvent;
use crate::models::Bookmark;

impl CrispyService {
    // ── Bookmarks ─────────────────────────────────────

    /// Load all bookmarks for a content item, ordered
    /// by position ascending.
    pub fn load_bookmarks(&self, content_id: &str) -> Result<Vec<Bookmark>, DbError> {
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT
                id, content_id, content_type,
                position_ms, label, created_at
            FROM db_bookmarks
            WHERE content_id = ?1
            ORDER BY position_ms ASC",
        )?;
        let rows = stmt.query_map(params![content_id], |row| {
            Ok(Bookmark {
                id: row.get(0)?,
                content_id: row.get(1)?,
                content_type: row.get(2)?,
                position_ms: row.get(3)?,
                label: row.get(4)?,
                created_at: ts_to_dt(row.get(5)?),
            })
        })?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Save (upsert) a bookmark.
    pub fn save_bookmark(&self, bookmark: &Bookmark) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute(
            "INSERT OR REPLACE INTO db_bookmarks (
                id, content_id, content_type,
                position_ms, label, created_at
            ) VALUES (
                ?1, ?2, ?3, ?4, ?5, ?6
            )",
            params![
                bookmark.id,
                bookmark.content_id,
                bookmark.content_type,
                bookmark.position_ms,
                bookmark.label,
                dt_to_ts(&bookmark.created_at),
            ],
        )?;
        self.emit(DataChangeEvent::BookmarkChanged);
        Ok(())
    }

    /// Delete a bookmark by ID.
    pub fn delete_bookmark(&self, id: &str) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute(
            "DELETE FROM db_bookmarks
             WHERE id = ?1",
            params![id],
        )?;
        self.emit(DataChangeEvent::BookmarkChanged);
        Ok(())
    }

    /// Delete all bookmarks for a content item.
    pub fn clear_bookmarks(&self, content_id: &str) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute(
            "DELETE FROM db_bookmarks
             WHERE content_id = ?1",
            params![content_id],
        )?;
        self.emit(DataChangeEvent::BookmarkChanged);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use crate::services::test_helpers::*;

    fn make_bookmark(id: &str, content_id: &str, position_ms: i64) -> crate::models::Bookmark {
        let dt = parse_dt("2025-01-15 12:00:00");
        crate::models::Bookmark {
            id: id.to_string(),
            content_id: content_id.to_string(),
            content_type: "vod".to_string(),
            position_ms,
            label: None,
            created_at: dt,
        }
    }

    #[test]
    fn bookmarks_crud() {
        let svc = make_service();

        let bookmarks = svc.load_bookmarks("movie1").unwrap();
        assert!(bookmarks.is_empty());

        svc.save_bookmark(&make_bookmark("b1", "movie1", 5000))
            .unwrap();
        svc.save_bookmark(&make_bookmark("b2", "movie1", 15000))
            .unwrap();

        let bookmarks = svc.load_bookmarks("movie1").unwrap();
        assert_eq!(bookmarks.len(), 2);
        assert_eq!(bookmarks[0].position_ms, 5000);
        assert_eq!(bookmarks[1].position_ms, 15000);

        svc.delete_bookmark("b1").unwrap();
        let bookmarks = svc.load_bookmarks("movie1").unwrap();
        assert_eq!(bookmarks.len(), 1);
        assert_eq!(bookmarks[0].id, "b2");
    }

    #[test]
    fn bookmarks_upsert() {
        let svc = make_service();
        let mut bm = make_bookmark("b1", "movie1", 5000);
        svc.save_bookmark(&bm).unwrap();

        bm.label = Some("Great scene".to_string());
        svc.save_bookmark(&bm).unwrap();

        let bookmarks = svc.load_bookmarks("movie1").unwrap();
        assert_eq!(bookmarks.len(), 1);
        assert_eq!(bookmarks[0].label.as_deref(), Some("Great scene"));
    }

    #[test]
    fn bookmarks_ordered_by_position() {
        let svc = make_service();
        svc.save_bookmark(&make_bookmark("b3", "movie1", 30000))
            .unwrap();
        svc.save_bookmark(&make_bookmark("b1", "movie1", 10000))
            .unwrap();
        svc.save_bookmark(&make_bookmark("b2", "movie1", 20000))
            .unwrap();

        let bookmarks = svc.load_bookmarks("movie1").unwrap();
        assert_eq!(bookmarks[0].id, "b1");
        assert_eq!(bookmarks[1].id, "b2");
        assert_eq!(bookmarks[2].id, "b3");
    }

    #[test]
    fn bookmarks_isolated_by_content() {
        let svc = make_service();
        svc.save_bookmark(&make_bookmark("b1", "movie1", 5000))
            .unwrap();
        svc.save_bookmark(&make_bookmark("b2", "movie2", 8000))
            .unwrap();

        let m1 = svc.load_bookmarks("movie1").unwrap();
        let m2 = svc.load_bookmarks("movie2").unwrap();
        assert_eq!(m1.len(), 1);
        assert_eq!(m2.len(), 1);
        assert_eq!(m1[0].id, "b1");
        assert_eq!(m2[0].id, "b2");
    }

    #[test]
    fn clear_bookmarks() {
        let svc = make_service();
        svc.save_bookmark(&make_bookmark("b1", "movie1", 5000))
            .unwrap();
        svc.save_bookmark(&make_bookmark("b2", "movie1", 10000))
            .unwrap();
        svc.save_bookmark(&make_bookmark("b3", "movie2", 3000))
            .unwrap();

        svc.clear_bookmarks("movie1").unwrap();

        assert!(svc.load_bookmarks("movie1").unwrap().is_empty());
        assert_eq!(svc.load_bookmarks("movie2").unwrap().len(), 1);
    }

    #[test]
    fn delete_nonexistent_bookmark() {
        let svc = make_service();
        svc.delete_bookmark("nonexistent").unwrap();
    }

    #[test]
    fn bookmark_with_label() {
        let svc = make_service();
        let mut bm = make_bookmark("b1", "movie1", 5000);
        bm.label = Some("Best fight scene".to_string());
        svc.save_bookmark(&bm).unwrap();

        let bookmarks = svc.load_bookmarks("movie1").unwrap();
        assert_eq!(bookmarks[0].label.as_deref(), Some("Best fight scene"));
    }

    #[test]
    fn bookmark_channel_type() {
        let svc = make_service();
        let mut bm = make_bookmark("b1", "ch1", 0);
        bm.content_type = "channel".to_string();
        svc.save_bookmark(&bm).unwrap();

        let bookmarks = svc.load_bookmarks("ch1").unwrap();
        assert_eq!(bookmarks[0].content_type, "channel");
    }
}
