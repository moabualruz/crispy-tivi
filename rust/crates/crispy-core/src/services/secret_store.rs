//! Secret credential wrappers using `secrecy`.
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

pub use secrecy::ExposeSecret;
pub use secrecy::SecretString;
use zeroize::ZeroizeOnDrop;

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
}
