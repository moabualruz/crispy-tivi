//! In-app notification service.
//!
//! Notifications are stored in `db_notifications` (created by the schema
//! migration).  Each notification belongs to a profile and has a category.
//!
//! # Retention
//! Notifications older than 30 days are pruned automatically when
//! `add_notification` is called.
//!
//! # Kids-profile restriction
//! Kid profiles (`is_child = true`) only receive `Content` and `Reminder`
//! category notifications.
//!
//! # Category grouping
//! `group_notifications` collapses multiple same-category notifications
//! from the same sync cycle (within 60 s) into one summary entry.

use rusqlite::params;
use serde::{Deserialize, Serialize};

use super::CrispyService;
use crate::database::DbError;

// ── Types ─────────────────────────────────────────────────────────────────────

/// Broad category for an in-app notification.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum NotifCategory {
    /// New content (channel, VOD, series episode) available.
    Content,
    /// User-set EPG reminder.
    Reminder,
    /// App system message (update, error, sync status).
    System,
    /// Social / watch-party invite.
    Social,
    /// DVR recording status.
    Recording,
}

impl NotifCategory {
    /// String tag used as the DB column value.
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Content => "content",
            Self::Reminder => "reminder",
            Self::System => "system",
            Self::Social => "social",
            Self::Recording => "recording",
        }
    }

    fn from_str(s: &str) -> Self {
        match s {
            "reminder" => Self::Reminder,
            "system" => Self::System,
            "social" => Self::Social,
            "recording" => Self::Recording,
            _ => Self::Content,
        }
    }

    /// Returns `true` when this category is allowed for kids profiles.
    pub fn allowed_for_kids(&self) -> bool {
        matches!(self, Self::Content | Self::Reminder)
    }
}

/// A single in-app notification record.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Notification {
    pub id: String,
    pub profile_id: String,
    pub category: NotifCategory,
    pub title: String,
    pub body: String,
    pub deep_link: Option<String>,
    /// Unix timestamp (seconds) when the notification was created.
    pub created_at: i64,
    pub read: bool,
}

// ── Per-category preferences ──────────────────────────────────────────────────

fn notif_pref_key(profile_id: &str, category: &NotifCategory) -> String {
    format!("notif_pref::{profile_id}::{}", category.as_str())
}

// ── Service impl ──────────────────────────────────────────────────────────────

/// How long notifications are retained (30 days in seconds).
const RETENTION_SECS: i64 = 30 * 24 * 60 * 60;

impl CrispyService {
    // ── Schema bootstrap ─────────────────────────

    /// Ensure the `db_notifications` table exists.
    ///
    /// Called automatically by `add_notification`; safe to call multiple times.
    fn ensure_notifications_table(&self) -> Result<(), DbError> {
        let conn = self.db.get()?;
        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS db_notifications (
                id          TEXT PRIMARY KEY,
                profile_id  TEXT NOT NULL,
                category    TEXT NOT NULL,
                title       TEXT NOT NULL,
                body        TEXT NOT NULL DEFAULT '',
                deep_link   TEXT,
                created_at  INTEGER NOT NULL,
                read        INTEGER NOT NULL DEFAULT 0
            );
            CREATE INDEX IF NOT EXISTS idx_notif_profile
                ON db_notifications (profile_id, created_at DESC);",
        )?;
        Ok(())
    }

    // ── Category preferences ─────────────────────

    /// Return whether notifications for `category` are enabled for `profile_id`.
    ///
    /// Defaults to `true` when no preference has been saved.
    pub fn is_notif_category_enabled(
        &self,
        profile_id: &str,
        category: &NotifCategory,
    ) -> Result<bool, DbError> {
        let key = notif_pref_key(profile_id, category);
        Ok(self.get_setting(&key)?.map(|v| v != "0").unwrap_or(true))
    }

    /// Enable or disable a notification category for a profile.
    pub fn set_notif_category_enabled(
        &self,
        profile_id: &str,
        category: &NotifCategory,
        enabled: bool,
    ) -> Result<(), DbError> {
        let key = notif_pref_key(profile_id, category);
        self.set_setting(&key, if enabled { "1" } else { "0" })
    }

    // ── Mutations ────────────────────────────────

    /// Persist a notification.
    ///
    /// Silently drops the notification when:
    /// - The profile has disabled the category.
    /// - The profile is a kids profile and the category is not allowed.
    ///
    /// Prunes notifications older than 30 days after inserting.
    pub fn add_notification(&self, notif: Notification) -> Result<(), DbError> {
        self.ensure_notifications_table()?;

        // Kids-profile category gate.
        if !notif.category.allowed_for_kids() {
            // Check if profile is child.
            let conn = self.db.get()?;
            let is_child: Option<i32> = conn
                .query_row(
                    "SELECT is_child FROM db_profiles WHERE id = ?1",
                    params![notif.profile_id],
                    |r| r.get(0),
                )
                .ok();
            if is_child == Some(1) {
                return Ok(()); // silently discard
            }
        }

        // Per-category preference gate.
        if !self.is_notif_category_enabled(&notif.profile_id, &notif.category)? {
            return Ok(());
        }

        let conn = self.db.get()?;
        conn.execute(
            "INSERT OR REPLACE INTO db_notifications
             (id, profile_id, category, title, body, deep_link, created_at, read)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
            params![
                notif.id,
                notif.profile_id,
                notif.category.as_str(),
                notif.title,
                notif.body,
                notif.deep_link,
                notif.created_at,
                if notif.read { 1i32 } else { 0i32 },
            ],
        )?;

        // Prune stale notifications.
        let cutoff = notif.created_at - RETENTION_SECS;
        conn.execute(
            "DELETE FROM db_notifications WHERE created_at < ?1",
            params![cutoff],
        )?;

        Ok(())
    }

    /// Return all notifications for `profile_id`, newest first.
    pub fn get_notifications(&self, profile_id: &str) -> Result<Vec<Notification>, DbError> {
        self.ensure_notifications_table()?;
        let conn = self.db.get()?;
        let mut stmt = conn.prepare(
            "SELECT id, profile_id, category, title, body, deep_link, created_at, read
             FROM db_notifications
             WHERE profile_id = ?1
             ORDER BY created_at DESC",
        )?;
        let rows = stmt.query_map(params![profile_id], |row| {
            let cat_str: String = row.get(2)?;
            Ok(Notification {
                id: row.get(0)?,
                profile_id: row.get(1)?,
                category: NotifCategory::from_str(&cat_str),
                title: row.get(3)?,
                body: row.get(4)?,
                deep_link: row.get(5)?,
                created_at: row.get(6)?,
                read: row.get::<_, i32>(7)? != 0,
            })
        })?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    /// Mark a single notification as read.
    pub fn mark_notification_read(&self, id: &str) -> Result<(), DbError> {
        self.ensure_notifications_table()?;
        let conn = self.db.get()?;
        conn.execute(
            "UPDATE db_notifications SET read = 1 WHERE id = ?1",
            params![id],
        )?;
        Ok(())
    }

    /// Delete a notification.
    pub fn dismiss_notification(&self, id: &str) -> Result<(), DbError> {
        self.ensure_notifications_table()?;
        let conn = self.db.get()?;
        conn.execute("DELETE FROM db_notifications WHERE id = ?1", params![id])?;
        Ok(())
    }

    /// Return the number of unread notifications for `profile_id`.
    pub fn get_unread_count(&self, profile_id: &str) -> Result<u32, DbError> {
        self.ensure_notifications_table()?;
        let conn = self.db.get()?;
        let count: i64 = conn.query_row(
            "SELECT COUNT(*) FROM db_notifications
             WHERE profile_id = ?1 AND read = 0",
            params![profile_id],
            |r| r.get(0),
        )?;
        Ok(count as u32)
    }

    /// Collapse notifications from within a `window_secs` window that share
    /// the same `profile_id` and `category` into a single summary entry.
    ///
    /// The summary notification takes the `id` of the first entry, replaces
    /// `body` with a count summary, and removes the collapsed entries.
    pub fn group_notifications(
        &self,
        profile_id: &str,
        category: &NotifCategory,
        window_secs: i64,
    ) -> Result<(), DbError> {
        self.ensure_notifications_table()?;
        let conn = self.db.get()?;

        // Collect IDs and timestamps within the window.
        let now = chrono::Utc::now().timestamp();
        let since = now - window_secs;
        let mut stmt = conn.prepare(
            "SELECT id, title FROM db_notifications
             WHERE profile_id = ?1 AND category = ?2 AND created_at >= ?3
             ORDER BY created_at ASC",
        )?;
        let entries: Vec<(String, String)> = stmt
            .query_map(params![profile_id, category.as_str(), since], |r| {
                Ok((r.get::<_, String>(0)?, r.get::<_, String>(1)?))
            })?
            .collect::<Result<Vec<_>, _>>()?;

        if entries.len() < 2 {
            return Ok(());
        }

        let count = entries.len();
        let (first_id, first_title) = &entries[0];
        let summary_body = format!("{count} {cat} notifications", cat = category.as_str());

        // Update the first entry to be the summary.
        conn.execute(
            "UPDATE db_notifications SET title = ?1, body = ?2 WHERE id = ?3",
            params![first_title, summary_body, first_id],
        )?;

        // Remove the rest.
        for (id, _) in &entries[1..] {
            conn.execute("DELETE FROM db_notifications WHERE id = ?1", params![id])?;
        }

        Ok(())
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::services::test_helpers::{make_profile, make_service};

    fn notif(id: &str, profile_id: &str, cat: NotifCategory) -> Notification {
        Notification {
            id: id.to_string(),
            profile_id: profile_id.to_string(),
            category: cat,
            title: format!("Title {id}"),
            body: "Body".to_string(),
            deep_link: None,
            created_at: chrono::Utc::now().timestamp(),
            read: false,
        }
    }

    #[test]
    fn test_add_and_get_notification() {
        let svc = make_service();
        svc.add_notification(notif("n1", "p1", NotifCategory::Content))
            .unwrap();
        let list = svc.get_notifications("p1").unwrap();
        assert_eq!(list.len(), 1);
        assert_eq!(list[0].id, "n1");
    }

    #[test]
    fn test_unread_count() {
        let svc = make_service();
        svc.add_notification(notif("n1", "p1", NotifCategory::Content))
            .unwrap();
        svc.add_notification(notif("n2", "p1", NotifCategory::Reminder))
            .unwrap();
        assert_eq!(svc.get_unread_count("p1").unwrap(), 2);
        svc.mark_notification_read("n1").unwrap();
        assert_eq!(svc.get_unread_count("p1").unwrap(), 1);
    }

    #[test]
    fn test_dismiss_notification() {
        let svc = make_service();
        svc.add_notification(notif("n1", "p1", NotifCategory::System))
            .unwrap();
        svc.dismiss_notification("n1").unwrap();
        let list = svc.get_notifications("p1").unwrap();
        assert!(list.is_empty());
    }

    #[test]
    fn test_category_toggle_prevents_insertion() {
        let svc = make_service();
        svc.set_notif_category_enabled("p1", &NotifCategory::System, false)
            .unwrap();
        svc.add_notification(notif("n1", "p1", NotifCategory::System))
            .unwrap();
        assert!(svc.get_notifications("p1").unwrap().is_empty());
    }

    #[test]
    fn test_kids_profile_blocks_non_allowed_category() {
        let svc = make_service();
        let mut profile = make_profile("kid1", "Kid");
        profile.is_child = true;
        svc.save_profile(&profile).unwrap();

        // Social not allowed for kids.
        svc.add_notification(notif("n1", "kid1", NotifCategory::Social))
            .unwrap();
        assert!(svc.get_notifications("kid1").unwrap().is_empty());

        // Content IS allowed for kids.
        svc.add_notification(notif("n2", "kid1", NotifCategory::Content))
            .unwrap();
        assert_eq!(svc.get_notifications("kid1").unwrap().len(), 1);
    }

    #[test]
    fn test_notifications_are_per_profile() {
        let svc = make_service();
        svc.add_notification(notif("n1", "p1", NotifCategory::Content))
            .unwrap();
        assert!(svc.get_notifications("p2").unwrap().is_empty());
    }

    #[test]
    fn test_group_notifications_collapses_entries() {
        let svc = make_service();
        for i in 0..3u32 {
            svc.add_notification(notif(&format!("n{i}"), "p1", NotifCategory::Content))
                .unwrap();
        }
        svc.group_notifications("p1", &NotifCategory::Content, 120)
            .unwrap();
        let list = svc.get_notifications("p1").unwrap();
        assert_eq!(list.len(), 1, "should collapse to 1 summary");
        assert!(list[0].body.contains("3"), "summary should mention count");
    }
}
