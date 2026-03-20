//! Secret credential wrappers using `secrecy` + platform OS keyring.
//!
//! Re-exports `secrecy::SecretString` as `SecretString` for use across the
//! codebase. Any struct that holds credentials derives `ZeroizeOnDrop` to
//! ensure sensitive memory is wiped on drop.
//!
//! # Design
//! - `Debug` impls via `secrecy::ExposeSecret` redact values automatically.
//! - Credentials are passed as `SecretString`; only the service layer may
//!   call `.expose_secret()` when constructing HTTP requests.
//! - Never store plaintext alongside an encrypted value.
//!
//! # Platform secure storage (spec 7.5)
//! [`PlatformKeyring`] stores and retrieves secrets via the OS credential
//! manager: DPAPI/Credential Store on Windows, Keychain on macOS/iOS,
//! libsecret/kwallet on Linux. Uses the `keyring` crate.

pub use secrecy::ExposeSecret;
pub use secrecy::SecretString;
use zeroize::ZeroizeOnDrop;

use crate::errors::CrispyError;

// ── SourceCredentials ─────────────────────────────────────────────────────────

/// Plaintext credentials for an IPTV source, zeroized on drop.
///
/// Constructed only when credentials are needed for an HTTP request.
/// The `Debug` output redacts all sensitive fields via `secrecy`.
#[derive(ZeroizeOnDrop)]
pub struct SourceCredentials {
    /// Username / account identifier.
    #[zeroize(skip)] // String with SecretString wrapper — see note below
    pub username: SecretString,
    /// Password / access token.
    #[zeroize(skip)]
    pub password: SecretString,
}

// `SecretString` is internally a `Box<str>` that zeroizes on drop by itself
// (secrecy 0.8+ uses zeroize internally). The struct-level ZeroizeOnDrop
// drops fields in order, which triggers SecretString's own drop.

impl std::fmt::Debug for SourceCredentials {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("SourceCredentials")
            .field("username", &"[REDACTED]")
            .field("password", &"[REDACTED]")
            .finish()
    }
}

impl SourceCredentials {
    /// Construct from raw strings.
    pub fn new(username: impl Into<String>, password: impl Into<String>) -> Self {
        Self {
            username: SecretString::from(username.into()),
            password: SecretString::from(password.into()),
        }
    }
}

// ── StalkerCredentials ────────────────────────────────────────────────────────

/// Credentials for a Stalker Portal source.
#[derive(ZeroizeOnDrop)]
pub struct StalkerCredentials {
    /// Portal MAC address.
    #[zeroize(skip)]
    pub mac_address: SecretString,
    /// Optional device serial / token.
    #[zeroize(skip)]
    pub device_id: Option<SecretString>,
}

impl std::fmt::Debug for StalkerCredentials {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("StalkerCredentials")
            .field("mac_address", &"[REDACTED]")
            .field("device_id", &"[REDACTED]")
            .finish()
    }
}

impl StalkerCredentials {
    pub fn new(mac_address: impl Into<String>, device_id: Option<String>) -> Self {
        Self {
            mac_address: SecretString::from(mac_address.into()),
            device_id: device_id.map(SecretString::from),
        }
    }
}

// ── PlatformKeyring ───────────────────────────────────────────────────────────

/// Platform OS credential store (spec 7.5).
///
/// Uses DPAPI on Windows, Keychain on macOS/iOS, libsecret on Linux.
/// All operations are synchronous (the `keyring` crate handles threading).
///
/// # Service name
/// All entries are namespaced under `service` to avoid collisions with other
/// apps. Recommended value: `"crispy-tivi"`.
pub struct PlatformKeyring {
    service: String,
}

impl PlatformKeyring {
    /// Create a keyring scoped to `service` (e.g. `"crispy-tivi"`).
    pub fn new(service: impl Into<String>) -> Self {
        Self {
            service: service.into(),
        }
    }

    /// Store `secret` under `key` in the OS credential manager.
    ///
    /// Overwrites any existing entry for the same `(service, key)` pair.
    pub fn set(&self, key: &str, secret: &SecretString) -> Result<(), CrispyError> {
        let entry = keyring::Entry::new(&self.service, key)
            .map_err(|e| CrispyError::security(format!("Keyring entry error: {e}")))?;
        entry
            .set_password(secret.expose_secret())
            .map_err(|e| CrispyError::security(format!("Keyring set failed for '{key}': {e}")))
    }

    /// Retrieve the secret stored under `key`, or `None` if not present.
    pub fn get(&self, key: &str) -> Result<Option<SecretString>, CrispyError> {
        let entry = keyring::Entry::new(&self.service, key)
            .map_err(|e| CrispyError::security(format!("Keyring entry error: {e}")))?;
        match entry.get_password() {
            Ok(pw) => Ok(Some(SecretString::from(pw))),
            Err(keyring::Error::NoEntry) => Ok(None),
            Err(e) => Err(CrispyError::security(format!(
                "Keyring get failed for '{key}': {e}"
            ))),
        }
    }

    /// Delete the entry stored under `key`.
    ///
    /// Returns `Ok(())` even if the entry did not exist.
    pub fn delete(&self, key: &str) -> Result<(), CrispyError> {
        let entry = keyring::Entry::new(&self.service, key)
            .map_err(|e| CrispyError::security(format!("Keyring entry error: {e}")))?;
        match entry.delete_credential() {
            Ok(()) => Ok(()),
            Err(keyring::Error::NoEntry) => Ok(()),
            Err(e) => Err(CrispyError::security(format!(
                "Keyring delete failed for '{key}': {e}"
            ))),
        }
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_source_credentials_debug_redacts() {
        let creds = SourceCredentials::new("admin", "s3cr3t");
        let debug_str = format!("{creds:?}");
        assert!(!debug_str.contains("admin"), "username leaked in Debug");
        assert!(!debug_str.contains("s3cr3t"), "password leaked in Debug");
        assert!(debug_str.contains("[REDACTED]"));
    }

    #[test]
    fn test_source_credentials_expose_secret_works() {
        let creds = SourceCredentials::new("myuser", "mypass");
        assert_eq!(creds.username.expose_secret(), "myuser");
        assert_eq!(creds.password.expose_secret(), "mypass");
    }

    #[test]
    fn test_stalker_credentials_debug_redacts() {
        let creds = StalkerCredentials::new("AA:BB:CC:DD:EE:FF", Some("dev123".to_string()));
        let debug_str = format!("{creds:?}");
        assert!(!debug_str.contains("AA:BB"), "mac leaked in Debug");
        assert!(!debug_str.contains("dev123"), "device_id leaked in Debug");
    }

    #[test]
    fn test_stalker_credentials_no_device_id() {
        let creds = StalkerCredentials::new("00:11:22:33:44:55", None);
        assert!(creds.device_id.is_none());
    }

    #[test]
    fn test_secret_string_type_alias_is_secrecy() {
        let s: SecretString = SecretString::from("hello".to_string());
        assert_eq!(s.expose_secret(), "hello");
    }

    // ── PlatformKeyring tests ─────────────────────────────────────────────────
    // These tests use the real OS keyring. They are integration-style but
    // fast (no network IO). Each test uses a unique key to avoid collisions.

    #[test]
    fn test_keyring_set_and_get_roundtrip() {
        let kr = PlatformKeyring::new("crispy-tivi-test");
        let key = "test_roundtrip_key";
        let secret = SecretString::from("super-secret-value".to_string());

        kr.set(key, &secret).expect("set failed");
        let retrieved = kr.get(key).expect("get failed").expect("entry missing");
        assert_eq!(retrieved.expose_secret(), "super-secret-value");

        // cleanup
        kr.delete(key).ok();
    }

    #[test]
    fn test_keyring_get_missing_returns_none() {
        let kr = PlatformKeyring::new("crispy-tivi-test");
        let result = kr.get("__definitely_not_present__").expect("get error");
        assert!(result.is_none());
    }

    #[test]
    fn test_keyring_delete_missing_is_ok() {
        let kr = PlatformKeyring::new("crispy-tivi-test");
        // Should not error even if the key does not exist
        kr.delete("__nonexistent_delete_key__")
            .expect("delete error");
    }

    #[test]
    fn test_keyring_overwrite_updates_value() {
        let kr = PlatformKeyring::new("crispy-tivi-test");
        let key = "test_overwrite_key";

        kr.set(key, &SecretString::from("first".to_string()))
            .expect("set 1 failed");
        kr.set(key, &SecretString::from("second".to_string()))
            .expect("set 2 failed");

        let val = kr.get(key).expect("get failed").expect("missing");
        assert_eq!(val.expose_secret(), "second");

        kr.delete(key).ok();
    }

    #[test]
    fn test_keyring_delete_removes_entry() {
        let kr = PlatformKeyring::new("crispy-tivi-test");
        let key = "test_delete_removes_key";

        kr.set(key, &SecretString::from("to-be-deleted".to_string()))
            .expect("set failed");
        kr.delete(key).expect("delete failed");

        let result = kr.get(key).expect("get error");
        assert!(result.is_none(), "entry should be gone after delete");
    }
}
