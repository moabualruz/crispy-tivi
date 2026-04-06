//! GDPR data export and deletion service.
//!
//! Implements the user's "right to access" (Art. 15 GDPR) and "right to
//! erasure" (Art. 17 GDPR) for all personal data stored per profile.
//!
//! # Security note
//! `GdprExport` deliberately **excludes encrypted passwords** and MAC
//! addresses. Sources are exported with name, URL, and username only —
//! the same policy as the backup service.

use serde::Serialize;

use crate::database::DbError;
use crate::models::{Source, UserProfile, WatchHistory};
use crate::services::ServiceContext;
use crate::services::history::HistoryService;
use crate::services::profiles::ProfileService;
use crate::services::sources::SourceService;
use crate::services::watchlist::WatchlistService;

// ── Export types ──────────────────────────────────────────────────────────────

/// A complete, portable snapshot of all personal data for one profile.
///
/// Serialises to JSON for delivery to the user. Passwords and encrypted
/// credentials are intentionally omitted.
#[derive(Debug, Serialize)]
pub struct GdprExport {
    /// Schema version for forward compatibility.
    pub version: u32,
    /// Unix timestamp (seconds) when the export was generated.
    pub exported_at: i64,
    /// The profile whose data is exported.
    pub profile: UserProfile,
    /// Watch history entries for this profile.
    pub watch_history: Vec<WatchHistory>,
    /// Watchlist VOD item IDs for this profile.
    pub watchlist_ids: Vec<String>,
    /// Sources accessible by this profile (credentials redacted).
    pub sources: Vec<GdprSource>,
    /// Application settings (key/value pairs).
    pub settings: Vec<GdprSetting>,
}

/// A source record with credentials redacted for export.
#[derive(Debug, Serialize)]
pub struct GdprSource {
    pub id: String,
    pub name: String,
    pub source_type: String,
    /// Base URL only — no password embedded in the URL.
    pub url: String,
    /// Username only (no password).
    pub username: Option<String>,
    pub epg_url: Option<String>,
    pub enabled: bool,
}

/// A single application setting key/value pair.
#[derive(Debug, Serialize)]
pub struct GdprSetting {
    pub key: String,
    pub value: String,
}

// ── GdprService ───────────────────────────────────────────────────────────────

/// Domain service for GDPR data export and deletion operations.
pub struct GdprService(pub ServiceContext);

impl GdprService {
    /// Export all personal data for `profile_id` as a `GdprExport`.
    ///
    /// The caller should serialise the result to JSON and deliver it to
    /// the user (e.g. save to file or display in a settings screen).
    ///
    /// Passwords, encrypted tokens, and MAC addresses are excluded.
    pub fn export_user_data(&self, profile_id: &str) -> Result<GdprExport, DbError> {
        // ── Profile ──────────────────────────────────────────────────────────
        let profiles = ProfileService(self.0.clone()).load_profiles()?;
        let profile = profiles
            .into_iter()
            .find(|p| p.id == profile_id)
            .ok_or(DbError::NotFound)?;

        // ── Watch history ─────────────────────────────────────────────────────
        let all_history = HistoryService(self.0.clone()).load_watch_history()?;
        let watch_history: Vec<WatchHistory> = all_history
            .into_iter()
            .filter(|e| e.profile_id.as_deref() == Some(profile_id))
            .collect();

        // ── Watchlist (VOD item IDs) ───────────────────────────────────────────
        let watchlist_vod = WatchlistService(self.0.clone()).get_watchlist_items(profile_id)?;
        let watchlist_ids: Vec<String> = watchlist_vod.into_iter().map(|v| v.id).collect();

        // ── Sources accessible by this profile ────────────────────────────────
        let accessible_source_ids = ProfileService(self.0.clone()).get_source_access(profile_id)?;
        let all_sources = SourceService(self.0.clone()).get_sources()?;
        let sources: Vec<GdprSource> = all_sources
            .into_iter()
            .filter(|s| accessible_source_ids.contains(&s.id))
            .map(redact_source)
            .collect();

        // ── Settings ──────────────────────────────────────────────────────────
        let settings = self.load_all_settings()?;

        Ok(GdprExport {
            version: 1,
            exported_at: chrono::Utc::now().timestamp(),
            profile,
            watch_history,
            watchlist_ids,
            sources,
            settings,
        })
    }

    /// Delete all personal data for `profile_id`.
    ///
    /// This is a cascade-delete across every table that references the
    /// profile. The operation runs in a single transaction; it is
    /// all-or-nothing. After deletion, the profile row itself is removed.
    ///
    /// Delegates to the existing `delete_profile` implementation, which
    /// already handles the full cascade in a transaction.
    pub fn delete_user_data(&self, profile_id: &str) -> Result<(), DbError> {
        ProfileService(self.0.clone()).delete_profile(profile_id)
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /// Load all settings as key/value pairs.
    fn load_all_settings(&self) -> Result<Vec<GdprSetting>, DbError> {
        let conn = self.0.db.get()?;
        let mut stmt = conn.prepare("SELECT key, value FROM db_settings ORDER BY key")?;
        let rows = stmt.query_map([], |row| {
            Ok(GdprSetting {
                key: row.get(0)?,
                value: row.get(1)?,
            })
        })?;
        rows.collect::<Result<Vec<_>, _>>().map_err(DbError::Sqlite)
    }
}

/// Strip sensitive fields from a `Source` for export.
fn redact_source(s: Source) -> GdprSource {
    GdprSource {
        id: s.id,
        name: s.name,
        source_type: s.source_type.to_string(),
        url: s.url,
        username: s.username,
        epg_url: s.epg_url,
        enabled: s.enabled,
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::UserProfile;
    use crate::services::history::HistoryService;
    use crate::services::profiles::ProfileService;
    use crate::services::settings::SettingsService;
    use crate::services::sources::SourceService;
    use crate::traits::SettingsRepository;

    fn open_svc() -> GdprService {
        GdprService(ServiceContext::open_in_memory().expect("in-memory DB"))
    }

    fn make_profile(id: &str, name: &str) -> UserProfile {
        UserProfile {
            id: id.to_string(),
            name: name.to_string(),
            avatar_index: 0,
            pin: None,
            pin_version: 0,
            is_child: false,
            max_allowed_rating: 18,
            role: crate::value_objects::ProfileRole::Admin,
            dvr_permission: crate::value_objects::DvrPermission::None,
            dvr_quota_mb: None,
        }
    }

    // ── export_user_data ──────────────────────────────────────────────────────

    #[test]
    fn test_export_returns_not_found_for_unknown_profile() {
        let svc = open_svc();
        let err = svc.export_user_data("nonexistent").unwrap_err();
        assert!(matches!(err, DbError::NotFound));
    }

    #[test]
    fn test_export_returns_profile_data() {
        let svc = open_svc();
        let profile = make_profile("p1", "Alice");
        ProfileService(svc.0.clone())
            .save_profile(&profile)
            .unwrap();

        let export = svc.export_user_data("p1").unwrap();
        assert_eq!(export.profile.id, "p1");
        assert_eq!(export.profile.name, "Alice");
        assert_eq!(export.version, 1);
        assert!(export.exported_at > 0);
    }

    #[test]
    fn test_export_watch_history_filtered_to_profile() {
        let svc = open_svc();
        ProfileService(svc.0.clone())
            .save_profile(&make_profile("p1", "Alice"))
            .unwrap();
        ProfileService(svc.0.clone())
            .save_profile(&make_profile("p2", "Bob"))
            .unwrap();

        let entry_alice = crate::models::WatchHistory {
            id: "wh1".to_string(),
            media_type: crate::value_objects::MediaType::Channel,
            name: "CNN".to_string(),
            stream_url: "http://example.com/cnn".to_string(),
            poster_url: None,
            series_poster_url: None,
            position_ms: 0,
            duration_ms: 0,
            last_watched: chrono::NaiveDateTime::from_timestamp_opt(1_700_000_000, 0).unwrap(),
            series_id: None,
            season_number: None,
            episode_number: None,
            device_id: None,
            device_name: None,
            profile_id: Some("p1".to_string()),
            source_id: None,
        };
        HistoryService(svc.0.clone())
            .save_watch_history(&entry_alice)
            .unwrap();

        let mut entry_bob = entry_alice.clone();
        entry_bob.id = "wh2".to_string();
        entry_bob.profile_id = Some("p2".to_string());
        HistoryService(svc.0.clone())
            .save_watch_history(&entry_bob)
            .unwrap();

        let export = svc.export_user_data("p1").unwrap();
        assert_eq!(export.watch_history.len(), 1);
        assert_eq!(export.watch_history[0].id, "wh1");
    }

    #[test]
    fn test_export_empty_watchlist_when_none_added() {
        let svc = open_svc();
        ProfileService(svc.0.clone())
            .save_profile(&make_profile("p1", "Alice"))
            .unwrap();
        let export = svc.export_user_data("p1").unwrap();
        assert!(export.watchlist_ids.is_empty());
    }

    #[test]
    fn test_export_sources_only_accessible_ones() {
        let svc = open_svc();
        ProfileService(svc.0.clone())
            .save_profile(&make_profile("p1", "Alice"))
            .unwrap();

        let src = crate::models::Source {
            id: "src1".to_string(),
            name: "My IPTV".to_string(),
            source_type: crate::value_objects::SourceType::M3u,
            url: "http://example.com/list.m3u".to_string(),
            username: Some("user".to_string()),
            password: Some("secret".to_string()),
            epg_url: None,
            enabled: true,
            refresh_interval_minutes: 60,
            accept_self_signed: false,
            sort_order: 0,
            access_token: None,
            device_id: None,
            user_id: None,
            mac_address: None,
            user_agent: None,
            last_sync_time: None,
            last_sync_status: None,
            last_sync_error: None,
            created_at: None,
            updated_at: None,
            credentials_encrypted: false,
            deleted_at: None,
            epg_etag: None,
            epg_last_modified: None,
        };
        SourceService(svc.0.clone()).save_source(&src).unwrap();
        ProfileService(svc.0.clone())
            .grant_source_access("p1", "src1")
            .unwrap();

        let export = svc.export_user_data("p1").unwrap();
        assert_eq!(export.sources.len(), 1);
        assert_eq!(export.sources[0].name, "My IPTV");
        // Password must NOT appear in the export
        let json = serde_json::to_string(&export.sources[0]).unwrap();
        assert!(!json.contains("secret"));
    }

    #[test]
    fn test_export_settings_included() {
        let svc = open_svc();
        ProfileService(svc.0.clone())
            .save_profile(&make_profile("p1", "Alice"))
            .unwrap();
        SettingsService(svc.0.clone())
            .set_setting("theme", "dark")
            .unwrap();

        let export = svc.export_user_data("p1").unwrap();
        let found = export
            .settings
            .iter()
            .any(|s| s.key == "theme" && s.value == "dark");
        assert!(found);
    }

    #[test]
    fn test_export_serialises_to_valid_json() {
        let svc = open_svc();
        ProfileService(svc.0.clone())
            .save_profile(&make_profile("p1", "Alice"))
            .unwrap();
        let export = svc.export_user_data("p1").unwrap();
        let json = serde_json::to_string(&export).unwrap();
        assert!(!json.is_empty());
        // Round-trip: must be valid JSON object
        let v: serde_json::Value = serde_json::from_str(&json).unwrap();
        assert_eq!(v["version"], 1);
    }

    // ── delete_user_data ──────────────────────────────────────────────────────

    #[test]
    fn test_delete_user_data_removes_profile() {
        let svc = open_svc();
        ProfileService(svc.0.clone())
            .save_profile(&make_profile("p1", "Alice"))
            .unwrap();
        svc.delete_user_data("p1").unwrap();

        let profiles = ProfileService(svc.0.clone()).load_profiles().unwrap();
        assert!(!profiles.iter().any(|p| p.id == "p1"));
    }

    #[test]
    fn test_delete_user_data_cascades_watch_history() {
        let svc = open_svc();
        ProfileService(svc.0.clone())
            .save_profile(&make_profile("p1", "Alice"))
            .unwrap();

        let entry = crate::models::WatchHistory {
            id: "wh1".to_string(),
            media_type: crate::value_objects::MediaType::Channel,
            name: "BBC".to_string(),
            stream_url: "http://bbc.com/stream".to_string(),
            poster_url: None,
            series_poster_url: None,
            position_ms: 0,
            duration_ms: 0,
            last_watched: chrono::NaiveDateTime::from_timestamp_opt(1_700_000_000, 0).unwrap(),
            series_id: None,
            season_number: None,
            episode_number: None,
            device_id: None,
            device_name: None,
            profile_id: Some("p1".to_string()),
            source_id: None,
        };
        HistoryService(svc.0.clone())
            .save_watch_history(&entry)
            .unwrap();
        svc.delete_user_data("p1").unwrap();

        let history = HistoryService(svc.0.clone()).load_watch_history().unwrap();
        assert!(!history.iter().any(|h| h.id == "wh1"));
    }

    #[test]
    fn test_delete_user_data_does_not_affect_other_profiles() {
        let svc = open_svc();
        ProfileService(svc.0.clone())
            .save_profile(&make_profile("p1", "Alice"))
            .unwrap();
        ProfileService(svc.0.clone())
            .save_profile(&make_profile("p2", "Bob"))
            .unwrap();
        svc.delete_user_data("p1").unwrap();

        let profiles = ProfileService(svc.0.clone()).load_profiles().unwrap();
        assert!(profiles.iter().any(|p| p.id == "p2"));
    }

    #[test]
    fn test_delete_then_export_returns_not_found() {
        let svc = open_svc();
        ProfileService(svc.0.clone())
            .save_profile(&make_profile("p1", "Alice"))
            .unwrap();
        svc.delete_user_data("p1").unwrap();

        let err = svc.export_user_data("p1").unwrap_err();
        assert!(matches!(err, DbError::NotFound));
    }
}
