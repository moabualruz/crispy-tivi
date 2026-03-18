//! Backup and restore service.
//!
//! Serialises a `BackupData` snapshot to JSON, then encrypts with
//! AES-256-GCM.  The encryption key is derived from a user-supplied
//! passphrase using Argon2id so the file is safe to store anywhere.
//!
//! # Wire format
//! ```text
//! [16-byte Argon2 salt][12-byte GCM nonce][ciphertext+16-byte GCM tag]
//! ```

use aes_gcm::aead::{Aead, KeyInit};
use aes_gcm::{Aes256Gcm, Key, Nonce};
use argon2::{Algorithm, Argon2, Params, Version};
use rand_core::{OsRng, RngCore};
use serde::{Deserialize, Serialize};

use crate::errors::CrispyError;

// ── Wire-format constants ─────────────────────────────────────────────────────

const SALT_LEN: usize = 16;
const NONCE_LEN: usize = 12;
/// Argon2id parameters: m=64 MiB, t=3, p=1  (conservative for embedded HW)
const ARGON2_MEM_KIB: u32 = 65_536;
const ARGON2_ITER: u32 = 3;
const ARGON2_PARA: u32 = 1;

// ── Merge policy ─────────────────────────────────────────────────────────────

/// Conflict resolution when restoring over an existing database.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum MergePolicy {
    /// Erase all local data before importing.
    ReplaceAll,
    /// Backup data wins on conflict.
    MergeBackupWins,
    /// Local data wins on conflict.
    MergeLocalWins,
}

// ── BackupData ────────────────────────────────────────────────────────────────

/// Everything needed to reconstruct the user's library on a new device.
///
/// Deliberately excludes plaintext credentials — sources carry only
/// non-secret fields (URL, username).  Passwords are never backed up.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct BackupData {
    /// Schema version for forward-compat checks.
    pub version: u32,
    /// Unix timestamp (seconds) when the backup was created.
    pub created_at: i64,

    // ── Per-profile config ───────────────────────
    pub profiles: Vec<ProfileBackup>,

    // ── Sources (no passwords) ───────────────────
    pub sources: Vec<SourceBackup>,

    // ── Channel ordering and favourites ──────────
    pub channel_order: Vec<ChannelOrderEntry>,
    pub favorites: Vec<FavoriteEntry>,

    // ── Watch history ─────────────────────────────
    pub watch_history: Vec<WatchHistoryEntry>,

    // ── DVR schedules ────────────────────────────
    pub dvr_schedules: Vec<DvrScheduleEntry>,

    // ── Smart groups ─────────────────────────────
    pub smart_groups: Vec<SmartGroupEntry>,

    // ── EPG mappings ─────────────────────────────
    pub epg_mappings: Vec<EpgMappingEntry>,

    // ── Bookmarks ────────────────────────────────
    pub bookmarks: Vec<BookmarkEntry>,

    // ── Search history ───────────────────────────
    pub search_history: Vec<SearchHistoryEntry>,

    // ── App settings (flat KV) ───────────────────
    pub settings: Vec<SettingEntry>,

    // ── Parental control config ───────────────────
    pub parental_config: Option<ParentalConfig>,

    // ── Notification preferences ─────────────────
    pub notification_prefs: Vec<NotificationPrefEntry>,
}

// ── Sub-structs ───────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProfileBackup {
    pub id: String,
    pub name: String,
    pub avatar_index: i32,
    pub is_child: bool,
    pub max_allowed_rating: i32,
    pub role: i32,
}

/// Source record stripped of credentials.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SourceBackup {
    pub id: String,
    pub name: String,
    pub source_type: String,
    /// Base URL / portal URL — never the password.
    pub url: String,
    /// Username only (no password).
    pub username: Option<String>,
    pub epg_url: Option<String>,
    pub refresh_interval_minutes: i32,
    pub enabled: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChannelOrderEntry {
    pub profile_id: String,
    pub group_name: String,
    pub channel_ids: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FavoriteEntry {
    pub profile_id: String,
    pub channel_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WatchHistoryEntry {
    pub id: String,
    pub profile_id: Option<String>,
    pub media_type: String,
    pub name: String,
    pub stream_url: String,
    pub position_ms: i64,
    pub duration_ms: i64,
    pub last_watched: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DvrScheduleEntry {
    pub id: String,
    pub profile_id: Option<String>,
    pub channel_id: String,
    pub start_ts: i64,
    pub end_ts: i64,
    pub title: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SmartGroupEntry {
    pub id: String,
    pub profile_id: Option<String>,
    pub name: String,
    pub filter_json: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EpgMappingEntry {
    pub channel_id: String,
    pub epg_channel_id: String,
    pub locked: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BookmarkEntry {
    pub id: String,
    pub profile_id: Option<String>,
    pub stream_url: String,
    pub position_ms: i64,
    pub label: Option<String>,
    pub created_at: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchHistoryEntry {
    pub profile_id: String,
    pub query: String,
    pub searched_at: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SettingEntry {
    pub key: String,
    pub value: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParentalConfig {
    pub pin_hash: String,
    pub default_max_rating: i32,
    pub block_unrated: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NotificationPrefEntry {
    pub profile_id: String,
    pub category: String,
    pub enabled: bool,
}

// ── Crypto helpers ────────────────────────────────────────────────────────────

/// Derive a 32-byte AES key from `passphrase` and `salt` using Argon2id.
fn derive_key(passphrase: &str, salt: &[u8]) -> Result<[u8; 32], CrispyError> {
    let params = Params::new(ARGON2_MEM_KIB, ARGON2_ITER, ARGON2_PARA, Some(32)).map_err(|e| {
        CrispyError::Security {
            message: e.to_string(),
        }
    })?;
    let argon2 = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);
    let mut key = [0u8; 32];
    argon2
        .hash_password_into(passphrase.as_bytes(), salt, &mut key)
        .map_err(|e| CrispyError::Security {
            message: e.to_string(),
        })?;
    Ok(key)
}

// ── Public API ────────────────────────────────────────────────────────────────

/// Encrypt `data` into the portable backup wire format.
///
/// Returns `[salt(16)][nonce(12)][ciphertext+tag]`.
pub fn create_backup(data: &BackupData, passphrase: &str) -> Result<Vec<u8>, CrispyError> {
    let json = serde_json::to_vec(data)?;

    let mut salt = [0u8; SALT_LEN];
    let mut nonce_bytes = [0u8; NONCE_LEN];
    OsRng.fill_bytes(&mut salt);
    OsRng.fill_bytes(&mut nonce_bytes);

    let key_bytes = derive_key(passphrase, &salt)?;
    let key = Key::<Aes256Gcm>::from_slice(&key_bytes);
    let cipher = Aes256Gcm::new(key);
    let nonce = Nonce::from_slice(&nonce_bytes);

    let ciphertext = cipher
        .encrypt(nonce, json.as_ref())
        .map_err(|e| CrispyError::Security {
            message: e.to_string(),
        })?;

    let mut out = Vec::with_capacity(SALT_LEN + NONCE_LEN + ciphertext.len());
    out.extend_from_slice(&salt);
    out.extend_from_slice(&nonce_bytes);
    out.extend_from_slice(&ciphertext);
    Ok(out)
}

/// Decrypt and deserialise a backup blob.
pub fn restore_backup(data: &[u8], passphrase: &str) -> Result<BackupData, CrispyError> {
    if data.len() < SALT_LEN + NONCE_LEN + 16 {
        return Err(CrispyError::Security {
            message: "Backup blob too short".to_string(),
        });
    }
    let salt = &data[..SALT_LEN];
    let nonce_bytes = &data[SALT_LEN..SALT_LEN + NONCE_LEN];
    let ciphertext = &data[SALT_LEN + NONCE_LEN..];

    let key_bytes = derive_key(passphrase, salt)?;
    let key = Key::<Aes256Gcm>::from_slice(&key_bytes);
    let cipher = Aes256Gcm::new(key);
    let nonce = Nonce::from_slice(nonce_bytes);

    let plaintext = cipher
        .decrypt(nonce, ciphertext)
        .map_err(|_| CrispyError::Security {
            message: "Decryption failed — wrong passphrase or corrupted backup".to_string(),
        })?;

    let backup: BackupData = serde_json::from_slice(&plaintext)?;
    Ok(backup)
}

/// Same as `restore_backup` but strips all credential-adjacent fields
/// (sources, parental PIN hash) before returning.
pub fn restore_without_credentials(
    data: &[u8],
    passphrase: &str,
) -> Result<BackupData, CrispyError> {
    let mut backup = restore_backup(data, passphrase)?;
    // Redact source entries — keep metadata, drop URL/username.
    for s in &mut backup.sources {
        s.url = String::new();
        s.username = None;
    }
    // Redact parental PIN hash.
    if let Some(ref mut pc) = backup.parental_config {
        pc.pin_hash = String::new();
    }
    Ok(backup)
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_data() -> BackupData {
        BackupData {
            version: 1,
            created_at: 1_700_000_000,
            profiles: vec![ProfileBackup {
                id: "p1".to_string(),
                name: "Alice".to_string(),
                avatar_index: 0,
                is_child: false,
                max_allowed_rating: 4,
                role: 1,
            }],
            sources: vec![SourceBackup {
                id: "s1".to_string(),
                name: "My IPTV".to_string(),
                source_type: "m3u".to_string(),
                url: "http://example.com/playlist.m3u".to_string(),
                username: Some("user1".to_string()),
                epg_url: None,
                refresh_interval_minutes: 60,
                enabled: true,
            }],
            settings: vec![SettingEntry {
                key: "theme".to_string(),
                value: "dark".to_string(),
            }],
            ..Default::default()
        }
    }

    #[test]
    fn test_encrypt_decrypt_round_trip() {
        let data = sample_data();
        let blob = create_backup(&data, "correct-horse-battery-staple").unwrap();
        let restored = restore_backup(&blob, "correct-horse-battery-staple").unwrap();
        assert_eq!(restored.version, 1);
        assert_eq!(restored.profiles.len(), 1);
        assert_eq!(restored.profiles[0].name, "Alice");
        assert_eq!(restored.sources[0].url, "http://example.com/playlist.m3u");
        assert_eq!(restored.settings[0].value, "dark");
    }

    #[test]
    fn test_wrong_passphrase_rejected() {
        let data = sample_data();
        let blob = create_backup(&data, "secret").unwrap();
        let result = restore_backup(&blob, "wrong-passphrase");
        assert!(result.is_err(), "Should reject wrong passphrase");
        let err = result.unwrap_err().to_string();
        assert!(
            err.contains("Decryption failed") || err.contains("wrong"),
            "{err}"
        );
    }

    #[test]
    fn test_truncated_blob_rejected() {
        let result = restore_backup(&[0u8; 10], "pass");
        assert!(result.is_err());
    }

    #[test]
    fn test_restore_without_credentials_strips_url_and_username() {
        let data = sample_data();
        let blob = create_backup(&data, "pass").unwrap();
        let restored = restore_without_credentials(&blob, "pass").unwrap();
        assert_eq!(restored.profiles[0].name, "Alice", "profiles preserved");
        assert!(restored.sources[0].url.is_empty(), "url stripped");
        assert!(restored.sources[0].username.is_none(), "username stripped");
        // Non-credential data survives.
        assert_eq!(restored.settings[0].value, "dark");
    }

    #[test]
    fn test_two_backups_produce_different_blobs() {
        let data = sample_data();
        let b1 = create_backup(&data, "pass").unwrap();
        let b2 = create_backup(&data, "pass").unwrap();
        // Different random salt/nonce each time.
        assert_ne!(b1, b2);
    }

    #[test]
    fn test_merge_policy_variants_are_serialisable() {
        for policy in [
            MergePolicy::ReplaceAll,
            MergePolicy::MergeBackupWins,
            MergePolicy::MergeLocalWins,
        ] {
            let s = serde_json::to_string(&policy).unwrap();
            let back: MergePolicy = serde_json::from_str(&s).unwrap();
            assert_eq!(back, policy);
        }
    }
}
