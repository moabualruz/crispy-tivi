//! Import service for TiviMate and IPTV Smarters backup files.
//!
//! Parses third-party backup formats and converts them to CrispyTivi's
//! internal `Source` model so users can migrate without re-entering credentials.

use serde::{Deserialize, Serialize};
use thiserror::Error;

use crate::models::Source;

// ── Error ─────────────────────────────────────────────────────────────────────

/// Errors produced by the import service.
#[derive(Debug, Error)]
pub enum ImportError {
    #[error("JSON parse error: {0}")]
    Json(#[from] serde_json::Error),

    #[error("Unsupported backup version: {0}")]
    UnsupportedVersion(u32),

    #[error("Missing required field: {0}")]
    MissingField(&'static str),
}

// ── Source type string constants ──────────────────────────────────────────────

const SOURCE_TYPE_M3U: &str = "m3u";
const SOURCE_TYPE_XTREAM: &str = "xtream_codes";
const SOURCE_TYPE_STALKER: &str = "stalker_portal";

// ── TiviMate backup format ────────────────────────────────────────────────────
//
// TiviMate exports a JSON object with a "playlists" array. Each playlist
// carries the provider type, URL, credentials, and group/category assignments.

/// Root object in a TiviMate backup file.
#[derive(Debug, Deserialize)]
pub struct TiviMateBackup {
    /// Backup format version (0 = pre-versioned, 1 and 2 are known versions).
    #[serde(default)]
    pub version: u32,
    /// Array of playlist configurations.
    pub playlists: Vec<TiviMatePlaylist>,
}

/// A single playlist entry in a TiviMate backup.
#[derive(Deserialize)]
pub struct TiviMatePlaylist {
    /// Human-readable playlist name.
    pub name: String,
    /// Provider type: "m3u", "xtream", or "stalker".
    #[serde(rename = "type", default)]
    pub provider_type: String,
    /// M3U URL (used when type is "m3u").
    #[serde(default)]
    pub url: String,
    /// Xtream / Stalker server URL.
    #[serde(default)]
    pub server: String,
    /// Authentication username.
    #[serde(default)]
    pub username: String,
    /// Authentication password (may be empty for M3U).
    #[serde(default)]
    pub password: String,
    /// EPG URL override, if any.
    #[serde(default)]
    pub epg_url: Option<String>,
}

impl std::fmt::Debug for TiviMatePlaylist {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("TiviMatePlaylist")
            .field("name", &self.name)
            .field("provider_type", &self.provider_type)
            .field("url", &self.url)
            .field("server", &self.server)
            .field("username", &self.username)
            .field("password", &"[REDACTED]")
            .field("epg_url", &self.epg_url)
            .finish()
    }
}

// ── IPTV Smarters backup format ───────────────────────────────────────────────
//
// IPTV Smarters Pro exports a JSON array where each element represents one
// account/profile. The "type" discriminates M3U from Xtream.

/// Root of an IPTV Smarters backup file — a direct JSON array of accounts.
pub type IptvSmartersBackup = Vec<IptvSmartersAccount>;

/// One account entry in an IPTV Smarters backup.
#[derive(Deserialize)]
pub struct IptvSmartersAccount {
    /// Display name for the account.
    #[serde(alias = "name", alias = "playlist_name")]
    pub display_name: Option<String>,
    /// Provider type: "m3u_url" or "xtream_codes".
    #[serde(rename = "type", default)]
    pub account_type: String,
    /// M3U URL (used when type is "m3u_url").
    #[serde(default)]
    pub url: String,
    /// Xtream server address.
    #[serde(default)]
    pub host: String,
    /// Authentication username.
    #[serde(default)]
    pub username: String,
    /// Authentication password.
    #[serde(default)]
    pub password: String,
    /// Optional EPG URL.
    #[serde(default)]
    pub epg_url: Option<String>,
}

impl std::fmt::Debug for IptvSmartersAccount {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("IptvSmartersAccount")
            .field("display_name", &self.display_name)
            .field("account_type", &self.account_type)
            .field("url", &self.url)
            .field("host", &self.host)
            .field("username", &self.username)
            .field("password", &"[REDACTED]")
            .field("epg_url", &self.epg_url)
            .finish()
    }
}

// ── ImportResult ──────────────────────────────────────────────────────────────

/// The output of a successful import operation.
#[derive(Debug, Default, Serialize)]
pub struct ImportResult {
    /// Sources ready to be saved with `CrispyService::save_source`.
    pub sources: Vec<Source>,
    /// Human-readable warnings collected during parsing (non-fatal).
    pub warnings: Vec<String>,
}

// ── Parse functions ───────────────────────────────────────────────────────────

/// Parse a TiviMate JSON backup and convert its playlists to `Source` records.
///
/// Each playlist becomes one `Source`. Credentials are preserved so the user
/// can start syncing immediately after import.
pub fn parse_tivimate(json: &str) -> Result<ImportResult, ImportError> {
    let backup: TiviMateBackup = serde_json::from_str(json)?;

    // TiviMate backup v0 (no explicit version field) and v1/v2 are supported.
    if backup.version > 2 {
        return Err(ImportError::UnsupportedVersion(backup.version));
    }

    let mut result = ImportResult::default();

    for (i, playlist) in backup.playlists.iter().enumerate() {
        match convert_tivimate_playlist(playlist, i) {
            Ok(source) => result.sources.push(source),
            Err(e) => result.warnings.push(format!("Playlist {i} skipped: {e}")),
        }
    }

    Ok(result)
}

fn convert_tivimate_playlist(
    playlist: &TiviMatePlaylist,
    index: usize,
) -> Result<Source, ImportError> {
    let name = if playlist.name.is_empty() {
        format!("Imported Playlist {}", index + 1)
    } else {
        playlist.name.clone()
    };

    let (source_type, url) = match playlist.provider_type.to_lowercase().as_str() {
        "xtream" | "xtream_codes" => {
            if playlist.server.is_empty() {
                return Err(ImportError::MissingField("server"));
            }
            (SOURCE_TYPE_XTREAM.to_string(), playlist.server.clone())
        }
        "stalker" | "stalker_portal" => {
            if playlist.server.is_empty() {
                return Err(ImportError::MissingField("server"));
            }
            (SOURCE_TYPE_STALKER.to_string(), playlist.server.clone())
        }
        _ => {
            // Default: M3U
            if playlist.url.is_empty() {
                return Err(ImportError::MissingField("url"));
            }
            (SOURCE_TYPE_M3U.to_string(), playlist.url.clone())
        }
    };

    Ok(make_source(
        name,
        source_type,
        url,
        non_empty(playlist.username.clone()),
        non_empty(playlist.password.clone()),
        playlist.epg_url.clone(),
    ))
}

/// Parse an IPTV Smarters JSON backup and convert accounts to `Source` records.
///
/// Each account entry becomes one `Source`.
pub fn parse_iptv_smarters(json: &str) -> Result<ImportResult, ImportError> {
    let accounts: IptvSmartersBackup = serde_json::from_str(json)?;

    let mut result = ImportResult::default();

    for (i, account) in accounts.iter().enumerate() {
        match convert_smarters_account(account, i) {
            Ok(source) => result.sources.push(source),
            Err(e) => result.warnings.push(format!("Account {i} skipped: {e}")),
        }
    }

    Ok(result)
}

fn convert_smarters_account(
    account: &IptvSmartersAccount,
    index: usize,
) -> Result<Source, ImportError> {
    let name = account
        .display_name
        .as_deref()
        .filter(|s| !s.is_empty())
        .map(str::to_string)
        .unwrap_or_else(|| format!("Imported Account {}", index + 1));

    let (source_type, url) = match account.account_type.to_lowercase().as_str() {
        "xtream_codes" | "xtream" => {
            if account.host.is_empty() {
                return Err(ImportError::MissingField("host"));
            }
            (SOURCE_TYPE_XTREAM.to_string(), account.host.clone())
        }
        _ => {
            // Default: M3U
            if account.url.is_empty() {
                return Err(ImportError::MissingField("url"));
            }
            (SOURCE_TYPE_M3U.to_string(), account.url.clone())
        }
    };

    Ok(make_source(
        name,
        source_type,
        url,
        non_empty(account.username.clone()),
        non_empty(account.password.clone()),
        account.epg_url.clone(),
    ))
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Build a `Source` with import defaults. UUID v4 is generated for the id.
fn make_source(
    name: String,
    source_type: String,
    url: String,
    username: Option<String>,
    password: Option<String>,
    epg_url: Option<String>,
) -> Source {
    Source {
        id: uuid::Uuid::new_v4().to_string(),
        name,
        source_type,
        url,
        username,
        password,
        epg_url,
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
    }
}

/// Returns `Some(s)` if `s` is non-empty, `None` otherwise.
fn non_empty(s: String) -> Option<String> {
    if s.is_empty() { None } else { Some(s) }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    // ── TiviMate ────────────────────────────────────────────────────────────

    fn tivimate_m3u_json() -> &'static str {
        r#"{
            "version": 1,
            "playlists": [
                {
                    "name": "My IPTV",
                    "type": "m3u",
                    "url": "http://example.com/playlist.m3u",
                    "username": "",
                    "password": "",
                    "epg_url": "http://example.com/epg.xml"
                }
            ]
        }"#
    }

    fn tivimate_xtream_json() -> &'static str {
        r#"{
            "version": 1,
            "playlists": [
                {
                    "name": "Premium Sports",
                    "type": "xtream",
                    "server": "http://xtream.example.com:8080",
                    "username": "user1",
                    "password": "pass1"
                }
            ]
        }"#
    }

    fn tivimate_multi_json() -> &'static str {
        r#"{
            "playlists": [
                {
                    "name": "M3U Source",
                    "type": "m3u",
                    "url": "http://example.com/list.m3u"
                },
                {
                    "name": "Xtream Source",
                    "type": "xtream",
                    "server": "http://xs.example.com:8080",
                    "username": "user",
                    "password": "pass"
                }
            ]
        }"#
    }

    #[test]
    fn test_parse_tivimate_returns_m3u_source() {
        let result = parse_tivimate(tivimate_m3u_json()).unwrap();
        assert_eq!(result.sources.len(), 1);
        let src = &result.sources[0];
        assert_eq!(src.name, "My IPTV");
        assert_eq!(src.source_type, SOURCE_TYPE_M3U);
        assert_eq!(src.url, "http://example.com/playlist.m3u");
        assert_eq!(src.epg_url.as_deref(), Some("http://example.com/epg.xml"));
        assert!(src.enabled);
    }

    #[test]
    fn test_parse_tivimate_returns_xtream_source() {
        let result = parse_tivimate(tivimate_xtream_json()).unwrap();
        assert_eq!(result.sources.len(), 1);
        let src = &result.sources[0];
        assert_eq!(src.name, "Premium Sports");
        assert_eq!(src.source_type, SOURCE_TYPE_XTREAM);
        assert_eq!(src.url, "http://xtream.example.com:8080");
        assert_eq!(src.username.as_deref(), Some("user1"));
        assert_eq!(src.password.as_deref(), Some("pass1"));
    }

    #[test]
    fn test_parse_tivimate_multiple_playlists() {
        let result = parse_tivimate(tivimate_multi_json()).unwrap();
        assert_eq!(result.sources.len(), 2);
        assert_eq!(result.warnings.len(), 0);
    }

    #[test]
    fn test_parse_tivimate_assigns_unique_ids() {
        let result = parse_tivimate(tivimate_multi_json()).unwrap();
        assert_ne!(result.sources[0].id, result.sources[1].id);
    }

    #[test]
    fn test_parse_tivimate_empty_playlists_returns_empty() {
        let json = r#"{"version": 1, "playlists": []}"#;
        let result = parse_tivimate(json).unwrap();
        assert!(result.sources.is_empty());
        assert!(result.warnings.is_empty());
    }

    #[test]
    fn test_parse_tivimate_unknown_version_returns_error() {
        let json = r#"{"version": 99, "playlists": []}"#;
        assert!(matches!(
            parse_tivimate(json),
            Err(ImportError::UnsupportedVersion(99))
        ));
    }

    #[test]
    fn test_parse_tivimate_invalid_json_returns_error() {
        assert!(matches!(
            parse_tivimate("{bad json"),
            Err(ImportError::Json(_))
        ));
    }

    #[test]
    fn test_parse_tivimate_m3u_missing_url_produces_warning() {
        let json = r#"{
            "playlists": [
                { "name": "Bad", "type": "m3u", "url": "" }
            ]
        }"#;
        let result = parse_tivimate(json).unwrap();
        assert_eq!(result.sources.len(), 0);
        assert_eq!(result.warnings.len(), 1);
    }

    #[test]
    fn test_parse_tivimate_unnamed_playlist_gets_fallback_name() {
        let json = r#"{
            "playlists": [
                { "name": "", "type": "m3u", "url": "http://example.com/list.m3u" }
            ]
        }"#;
        let result = parse_tivimate(json).unwrap();
        assert_eq!(result.sources[0].name, "Imported Playlist 1");
    }

    #[test]
    fn test_parse_tivimate_default_type_treated_as_m3u() {
        let json = r#"{
            "playlists": [
                { "name": "Fallback", "url": "http://example.com/list.m3u" }
            ]
        }"#;
        let result = parse_tivimate(json).unwrap();
        assert_eq!(result.sources[0].source_type, SOURCE_TYPE_M3U);
    }

    #[test]
    fn test_parse_tivimate_empty_username_stored_as_none() {
        let result = parse_tivimate(tivimate_m3u_json()).unwrap();
        assert!(result.sources[0].username.is_none());
    }

    // ── IPTV Smarters ───────────────────────────────────────────────────────

    fn smarters_m3u_json() -> &'static str {
        r#"[
            {
                "display_name": "Family Pack",
                "type": "m3u_url",
                "url": "http://smarters.example.com/get.php?username=u&password=p&type=m3u_plus",
                "epg_url": "http://smarters.example.com/xmltv.php?username=u&password=p"
            }
        ]"#
    }

    fn smarters_xtream_json() -> &'static str {
        r#"[
            {
                "display_name": "HD Pack",
                "type": "xtream_codes",
                "host": "http://xs.smarters.com:8080",
                "username": "hduser",
                "password": "hdpass"
            }
        ]"#
    }

    #[test]
    fn test_parse_smarters_returns_m3u_source() {
        let result = parse_iptv_smarters(smarters_m3u_json()).unwrap();
        assert_eq!(result.sources.len(), 1);
        let src = &result.sources[0];
        assert_eq!(src.name, "Family Pack");
        assert_eq!(src.source_type, SOURCE_TYPE_M3U);
        assert!(src.url.contains("smarters.example.com"));
    }

    #[test]
    fn test_parse_smarters_returns_xtream_source() {
        let result = parse_iptv_smarters(smarters_xtream_json()).unwrap();
        assert_eq!(result.sources.len(), 1);
        let src = &result.sources[0];
        assert_eq!(src.source_type, SOURCE_TYPE_XTREAM);
        assert_eq!(src.username.as_deref(), Some("hduser"));
        assert_eq!(src.password.as_deref(), Some("hdpass"));
    }

    #[test]
    fn test_parse_smarters_unnamed_account_gets_fallback_name() {
        let json = r#"[{"type": "m3u_url", "url": "http://example.com/list.m3u"}]"#;
        let result = parse_iptv_smarters(json).unwrap();
        assert_eq!(result.sources[0].name, "Imported Account 1");
    }

    #[test]
    fn test_parse_smarters_empty_array_returns_empty() {
        let result = parse_iptv_smarters("[]").unwrap();
        assert!(result.sources.is_empty());
    }

    #[test]
    fn test_parse_smarters_invalid_json_returns_error() {
        assert!(matches!(
            parse_iptv_smarters("{not an array}"),
            Err(ImportError::Json(_))
        ));
    }

    #[test]
    fn test_parse_smarters_xtream_missing_host_produces_warning() {
        let json = r#"[{"display_name": "Bad", "type": "xtream_codes", "host": ""}]"#;
        let result = parse_iptv_smarters(json).unwrap();
        assert_eq!(result.sources.len(), 0);
        assert_eq!(result.warnings.len(), 1);
    }

    #[test]
    fn test_parse_smarters_assigns_unique_ids() {
        let json = r#"[
            {"type": "m3u_url", "url": "http://a.com/1.m3u"},
            {"type": "m3u_url", "url": "http://b.com/2.m3u"}
        ]"#;
        let result = parse_iptv_smarters(json).unwrap();
        assert_ne!(result.sources[0].id, result.sources[1].id);
    }

    #[test]
    fn test_parse_smarters_empty_password_stored_as_none() {
        let json = r#"[{"type": "m3u_url", "url": "http://example.com/list.m3u", "password": ""}]"#;
        let result = parse_iptv_smarters(json).unwrap();
        assert!(result.sources[0].password.is_none());
    }
}
