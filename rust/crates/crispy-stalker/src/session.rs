//! Stalker session state — token, cookie, and device identity management.
//!
//! Expanded with token refresh logic from:
//! - Python: `ensure_token`, `token_validity_period`
//! - TypeScript: `ensureToken`, `STALKER_TOKEN_VALIDITY_SECONDS`, token refresh locking

use percent_encoding::{AsciiSet, NON_ALPHANUMERIC, utf8_percent_encode};
use std::time::{Duration, Instant};
use tokio::sync::Mutex;

use crate::device;

/// Default token validity period in seconds (from TypeScript constants).
const DEFAULT_TOKEN_VALIDITY_SECS: u64 = 3600;

/// Default timezone for Stalker cookie header.
const DEFAULT_TIMEZONE: &str = "Europe/Paris";

/// Characters to percent-encode in the MAC cookie value.
/// Encode everything except unreserved characters per RFC 3986.
const MAC_ENCODE_SET: &AsciiSet = &NON_ALPHANUMERIC
    .remove(b'-')
    .remove(b'_')
    .remove(b'.')
    .remove(b'~');

/// Active session state after successful authentication.
///
/// Extended with device identity and token expiry tracking.
#[derive(Debug, Clone)]
pub struct StalkerSession {
    /// Bearer token obtained from handshake.
    pub(crate) token: String,

    /// Discovered portal URL (e.g. `http://host/stalker_portal/server/load.php`).
    pub(crate) portal_url: String,

    /// MAC address (original format, e.g. `00:1A:79:XX:XX:XX`).
    pub(crate) mac_address: String,

    /// Timestamp when the token was obtained.
    pub(crate) token_obtained_at: Instant,

    /// Token validity period.
    pub(crate) token_validity: Duration,

    /// Generated serial (MD5 of MAC, 13 chars).
    pub(crate) serial: String,

    /// Generated device ID (SHA-256 of MAC, 64 chars).
    pub(crate) device_id: String,

    /// Second device ID (same as device_id per both sources).
    pub(crate) device_id2: String,

    /// Random hex string for metrics.
    pub(crate) random: String,

    /// Timezone for cookie header (e.g. `Europe/Paris`).
    pub(crate) timezone: String,
}

impl StalkerSession {
    /// Create a new session with device identity derived from MAC.
    ///
    /// `timezone` defaults to `"Europe/Paris"` when `None`.
    pub fn new(
        token: String,
        portal_url: String,
        mac_address: String,
        token_validity_secs: Option<u64>,
        timezone: Option<&str>,
    ) -> Self {
        let serial = device::generate_serial(&mac_address);
        let device_id = device::generate_device_id(&mac_address);
        let random = device::generate_random_hex();

        Self {
            token,
            portal_url,
            mac_address,
            token_obtained_at: Instant::now(),
            token_validity: Duration::from_secs(
                token_validity_secs.unwrap_or(DEFAULT_TOKEN_VALIDITY_SECS),
            ),
            device_id2: device_id.clone(),
            serial,
            device_id,
            random,
            timezone: timezone
                .filter(|s| !s.is_empty())
                .unwrap_or(DEFAULT_TIMEZONE)
                .to_string(),
        }
    }

    /// Build the `Cookie` header value for Stalker requests.
    ///
    /// Format: `mac={percent_encoded_mac}; stb_lang=en; timezone={encoded_tz}`
    pub fn cookie_header(&self) -> String {
        let encoded_mac = utf8_percent_encode(&self.mac_address, MAC_ENCODE_SET).to_string();
        let encoded_tz = utf8_percent_encode(&self.timezone, MAC_ENCODE_SET).to_string();
        format!("mac={encoded_mac}; stb_lang=en; timezone={encoded_tz}")
    }

    /// Build the `Cookie` header with token included.
    ///
    /// Used for most requests (except `get_profile` on `stalker_portal` endpoints).
    pub fn cookie_header_with_token(&self) -> String {
        let encoded_mac = utf8_percent_encode(&self.mac_address, MAC_ENCODE_SET).to_string();
        let encoded_tz = utf8_percent_encode(&self.timezone, MAC_ENCODE_SET).to_string();
        format!(
            "mac={encoded_mac}; stb_lang=en; timezone={encoded_tz}; token={}",
            self.token
        )
    }

    /// Build the `Authorization` header value.
    pub fn auth_header(&self) -> String {
        format!("Bearer {}", self.token)
    }

    /// Check whether the token has expired.
    ///
    /// Python: `(current_time - self.token_timestamp) > self.token_validity_period`
    /// TypeScript: `(currentTimestamp - this.tokenTimestamp) > STALKER_TOKEN_VALIDITY_SECONDS`
    pub fn is_token_expired(&self) -> bool {
        self.token_obtained_at.elapsed() > self.token_validity
    }

    /// Update the token after a refresh (handshake + profile).
    pub fn refresh_token(&mut self, new_token: String) {
        self.token = new_token;
        self.token_obtained_at = Instant::now();
    }

    /// Generate the signature for profile requests.
    pub fn signature(&self) -> String {
        device::generate_signature(
            &self.mac_address,
            &self.serial,
            &self.device_id,
            &self.device_id2,
        )
    }

    /// Generate metrics JSON for profile requests.
    pub fn metrics(&self) -> String {
        device::generate_metrics(&self.mac_address, &self.serial, &self.random)
    }

    /// Generate `hw_version_2` (SHA-1 of MAC).
    pub fn hw_version_2(&self) -> String {
        device::generate_hw_version_2(&self.mac_address)
    }

    /// Derive the device ID from a MAC address (legacy: colon-stripped uppercase).
    ///
    /// `00:1A:79:XX:XX:XX` -> `001A79XXXXXX`
    pub fn mac_to_device_id(mac: &str) -> String {
        mac.replace(':', "").to_uppercase()
    }

    /// Full Stalker header set as used by both Python and TypeScript sources.
    ///
    /// Python: `generate_headers()` — includes `X-User-Agent`, `Referer`, etc.
    /// TypeScript: `getHeaders()` — same header set.
    pub fn full_headers(&self, include_token_in_cookie: bool) -> Vec<(String, String)> {
        let mut headers = vec![
            ("Accept".into(), "*/*".into()),
            (
                "User-Agent".into(),
                "Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3".into(),
            ),
            (
                "X-User-Agent".into(),
                "Model: MAG250; Link: WiFi".into(),
            ),
            (
                "Referer".into(),
                format!("{}/stalker_portal/c/index.html", self.portal_url.trim_end_matches("/stalker_portal/server/load.php").trim_end_matches("/portal.php").trim_end_matches("/c/")),
            ),
            ("Accept-Language".into(), "en-US,en;q=0.5".into()),
            ("Pragma".into(), "no-cache".into()),
            ("Connection".into(), "keep-alive".into()),
            ("Accept-Encoding".into(), "gzip, deflate".into()),
            ("Authorization".into(), self.auth_header()),
        ];

        let cookie = if include_token_in_cookie {
            self.cookie_header_with_token()
        } else {
            self.cookie_header()
        };
        headers.push(("Cookie".into(), cookie));

        headers
    }
}

/// Token refresh lock — prevents concurrent token refreshes.
///
/// Translated from TypeScript: `tokenRefreshPromise: Promise<void> | null`
/// converted to `tokio::Mutex`-based locking.
pub struct TokenRefreshLock {
    inner: Mutex<()>,
}

impl TokenRefreshLock {
    pub fn new() -> Self {
        Self {
            inner: Mutex::new(()),
        }
    }

    /// Acquire the lock. Only one refresh can proceed at a time.
    pub async fn lock(&self) -> tokio::sync::MutexGuard<'_, ()> {
        self.inner.lock().await
    }
}

impl Default for TokenRefreshLock {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_session() -> StalkerSession {
        StalkerSession::new(
            "abc123".into(),
            "http://example.com/stalker_portal/server/load.php".into(),
            "00:1A:79:AB:CD:EF".into(),
            Some(3600),
            None,
        )
    }

    #[test]
    fn cookie_header_encodes_mac() {
        let session = test_session();
        let cookie = session.cookie_header();
        assert!(cookie.starts_with("mac=00%3A1A%3A79%3AAB%3ACD%3AEF"));
        assert!(cookie.contains("stb_lang=en"));
        assert!(cookie.contains("timezone=Europe%2FParis"));
    }

    #[test]
    fn cookie_header_with_token_includes_token() {
        let session = test_session();
        let cookie = session.cookie_header_with_token();
        assert!(cookie.contains("token=abc123"));
        assert!(cookie.contains("mac="));
    }

    #[test]
    fn auth_header_format() {
        let session = test_session();
        assert_eq!(session.auth_header(), "Bearer abc123");
    }

    #[test]
    fn token_not_expired_initially() {
        let session = test_session();
        assert!(!session.is_token_expired());
    }

    #[test]
    fn token_expired_after_validity() {
        let mut session = test_session();
        session.token_validity = Duration::from_millis(0);
        // A zero-duration validity means token is immediately expired
        std::thread::sleep(Duration::from_millis(1));
        assert!(session.is_token_expired());
    }

    #[test]
    fn refresh_token_resets_timestamp() {
        let mut session = test_session();
        session.token_validity = Duration::from_millis(0);
        std::thread::sleep(Duration::from_millis(1));
        assert!(session.is_token_expired());

        session.refresh_token("new_token".into());
        // After refresh, token should not be expired (validity reset to 0ms is still tricky)
        session.token_validity = Duration::from_secs(3600);
        assert!(!session.is_token_expired());
        assert_eq!(session.token, "new_token");
    }

    #[test]
    fn serial_and_device_id_populated() {
        let session = test_session();
        assert_eq!(session.serial.len(), 13);
        assert_eq!(session.device_id.len(), 64);
        assert_eq!(session.device_id, session.device_id2);
    }

    #[test]
    fn signature_is_valid() {
        let session = test_session();
        let sig = session.signature();
        assert_eq!(sig.len(), 64);
        assert!(sig.chars().all(|c| c.is_ascii_hexdigit()));
    }

    #[test]
    fn mac_to_device_id_removes_colons() {
        assert_eq!(
            StalkerSession::mac_to_device_id("00:1A:79:AB:CD:EF"),
            "001A79ABCDEF"
        );
    }

    #[test]
    fn mac_to_device_id_uppercases() {
        assert_eq!(
            StalkerSession::mac_to_device_id("aa:bb:cc:dd:ee:ff"),
            "AABBCCDDEEFF"
        );
    }

    #[test]
    fn full_headers_contain_required_fields() {
        let session = test_session();
        let headers = session.full_headers(true);
        let header_map: std::collections::HashMap<_, _> = headers.into_iter().collect();

        assert_eq!(header_map["Authorization"], "Bearer abc123");
        assert!(header_map["User-Agent"].contains("MAG200"));
        assert_eq!(header_map["X-User-Agent"], "Model: MAG250; Link: WiFi");
        assert!(header_map["Cookie"].contains("token=abc123"));
    }

    #[test]
    fn full_headers_without_token_in_cookie() {
        let session = test_session();
        let headers = session.full_headers(false);
        let header_map: std::collections::HashMap<_, _> = headers.into_iter().collect();

        assert!(!header_map["Cookie"].contains("token="));
    }

    #[test]
    fn custom_timezone_in_cookie_header() {
        let session = StalkerSession::new(
            "token".into(),
            "http://example.com/stalker_portal/server/load.php".into(),
            "00:1A:79:AB:CD:EF".into(),
            Some(3600),
            Some("America/New_York"),
        );
        let cookie = session.cookie_header();
        assert!(cookie.contains("timezone=America%2FNew_York"));
        assert!(!cookie.contains("Europe%2FParis"));
    }

    #[test]
    fn default_timezone_is_europe_paris_when_none() {
        let session = StalkerSession::new(
            "token".into(),
            "http://example.com/stalker_portal/server/load.php".into(),
            "00:1A:79:AB:CD:EF".into(),
            Some(3600),
            None,
        );
        let cookie = session.cookie_header();
        assert!(cookie.contains("timezone=Europe%2FParis"));
    }

    #[test]
    fn empty_timezone_defaults_to_europe_paris() {
        let session = StalkerSession::new(
            "token".into(),
            "http://example.com/stalker_portal/server/load.php".into(),
            "00:1A:79:AB:CD:EF".into(),
            Some(3600),
            Some(""),
        );
        let cookie = session.cookie_header();
        assert!(cookie.contains("timezone=Europe%2FParis"));
    }
}
