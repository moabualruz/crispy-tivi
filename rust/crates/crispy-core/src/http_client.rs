//! Shared HTTP client singletons for IPTV source operations.
//!
//! Provides connection-pooled `reqwest::Client` instances configured
//! for IPTV use cases. Two clients with different timeout profiles:
//! - `shared_client()` — general fetching (playlists, EPG, streams)
//! - `fast_client()` — credential verification, URL checks
//!
//! # TLS policy
//!
//! The default shared clients ALWAYS verify TLS certificates. Per-source
//! insecure clients are constructed on demand (non-static, owned) so that
//! a single source's `accept_self_signed=true` flag cannot bleed into
//! requests for other sources. See [`build_insecure_shared_client`] and
//! [`build_insecure_fast_client`].
//!
//! # Security audit
//!
//! Any construction of an insecure client is logged at `WARN` level via
//! [`tracing`] so that every TLS bypass leaves an audit trail.

use std::sync::OnceLock;
use std::time::Duration;

use reqwest::Client;

/// General-purpose HTTP client for playlist/EPG fetching.
///
/// Connection-pooled, gzip-enabled, 15s connect / 120s total timeout.
/// Certificate verification is ALWAYS enabled on this static instance.
static HTTP_CLIENT: OnceLock<Client> = OnceLock::new();

/// Fast HTTP client for credential verification and URL checks.
///
/// Shorter timeouts (5s connect / 10s total) for quick pass/fail.
/// Certificate verification is ALWAYS enabled on this static instance.
static FAST_CLIENT: OnceLock<Client> = OnceLock::new();

/// Returns the shared general-purpose HTTP client.
pub fn shared_client() -> &'static Client {
    HTTP_CLIENT.get_or_init(|| {
        Client::builder()
            .pool_max_idle_per_host(4)
            .pool_idle_timeout(Duration::from_secs(90))
            .tcp_keepalive(Duration::from_secs(60))
            .connect_timeout(Duration::from_secs(15))
            .timeout(Duration::from_secs(120))
            .user_agent("Mozilla/5.0 (X11; Linux x86_64; rv:149.0) Gecko/20100101 Firefox/149.0 CrispyTivi/1.0")
            .redirect(reqwest::redirect::Policy::limited(5))
            .gzip(true)
            .build()
            .expect("HTTP client build failed")
    })
}

/// Returns the fast HTTP client for quick checks.
pub fn fast_client() -> &'static Client {
    FAST_CLIENT.get_or_init(|| {
        Client::builder()
            .connect_timeout(Duration::from_secs(5))
            .timeout(Duration::from_secs(10))
            .user_agent("Mozilla/5.0 (X11; Linux x86_64; rv:149.0) Gecko/20100101 Firefox/149.0 CrispyTivi/1.0")
            .redirect(reqwest::redirect::Policy::limited(3))
            .gzip(true)
            .build()
            .expect("Fast HTTP client build failed")
    })
}

/// Builds a **new, owned** general-purpose client that accepts invalid TLS certs.
///
/// # Security
///
/// This intentionally returns an owned `Client` (not a static reference) so
/// that the insecure configuration is scoped to a single source. It cannot
/// persist beyond the caller's lifetime or leak into requests for other sources.
///
/// Call sites must emit a `WARN` log before using this (enforced by
/// [`get_shared_client`] and [`fetch_with_retry`]).
fn build_insecure_shared_client() -> Client {
    Client::builder()
        // SECURITY: accept_self_signed is a per-source opt-in. This client is
        // intentionally non-static so the insecure config cannot bleed into
        // other sources' requests (C-026 fix).
        .danger_accept_invalid_certs(true)
        .pool_max_idle_per_host(4)
        .pool_idle_timeout(Duration::from_secs(90))
        .tcp_keepalive(Duration::from_secs(60))
        .connect_timeout(Duration::from_secs(15))
        .timeout(Duration::from_secs(120))
        .user_agent("Mozilla/5.0 (X11; Linux x86_64; rv:149.0) Gecko/20100101 Firefox/149.0 CrispyTivi/1.0")
        .redirect(reqwest::redirect::Policy::limited(5))
        .gzip(true)
        .build()
        .expect("Insecure HTTP client build failed")
}

/// Builds a **new, owned** fast client that accepts invalid TLS certs.
///
/// # Security
///
/// Returns an owned `Client` for the same isolation reason as
/// [`build_insecure_shared_client`] — insecure config is per-source only.
fn build_insecure_fast_client() -> Client {
    Client::builder()
        // SECURITY: intentionally non-static — scoped to one source (C-026 fix).
        .danger_accept_invalid_certs(true)
        .connect_timeout(Duration::from_secs(5))
        .timeout(Duration::from_secs(10))
        .user_agent("Mozilla/5.0 (X11; Linux x86_64; rv:149.0) Gecko/20100101 Firefox/149.0 CrispyTivi/1.0")
        .redirect(reqwest::redirect::Policy::limited(3))
        .gzip(true)
        .build()
        .expect("Insecure fast client build failed")
}

/// Returns the appropriate general-purpose client based on TLS policy.
///
/// - `accept_invalid_certs = false` → returns the shared static client (cert
///   verification always on).
/// - `accept_invalid_certs = true` → builds and returns a **new owned** client
///   with cert verification disabled, emitting a `WARN` log for the audit trail.
///   The owned client is scoped to the caller so insecure config cannot bleed
///   into other sources (C-026 fix).
pub fn get_shared_client(accept_invalid_certs: bool) -> std::borrow::Cow<'static, Client> {
    if accept_invalid_certs {
        tracing::warn!(
            security = "tls_bypass",
            client = "shared",
            "Per-source insecure HTTP client constructed: TLS certificate verification disabled"
        );
        std::borrow::Cow::Owned(build_insecure_shared_client())
    } else {
        std::borrow::Cow::Borrowed(shared_client())
    }
}

/// Returns the appropriate fast client based on TLS policy.
///
/// - `accept_invalid_certs = false` → returns the shared static client.
/// - `accept_invalid_certs = true` → builds and returns a **new owned** client,
///   emitting a `WARN` log (C-026 fix).
pub fn get_fast_client(accept_invalid_certs: bool) -> std::borrow::Cow<'static, Client> {
    if accept_invalid_certs {
        tracing::warn!(
            security = "tls_bypass",
            client = "fast",
            "Per-source insecure fast HTTP client constructed: TLS certificate verification disabled"
        );
        std::borrow::Cow::Owned(build_insecure_fast_client())
    } else {
        std::borrow::Cow::Borrowed(fast_client())
    }
}

/// Maximum number of retry attempts for transient failures.
const MAX_RETRIES: u32 = 3;

/// Base delay for exponential backoff (doubled each retry).
const BASE_DELAY_MS: u64 = 500;

/// Fetches a URL with automatic retry on transient failures.
///
/// Retries up to [`MAX_RETRIES`] times with exponential backoff
/// for connection errors, timeouts, and 5xx server errors.
/// Non-retryable errors (4xx, parse errors) fail immediately.
///
/// When `accept_invalid_certs` is `true`, TLS certificate verification
/// is skipped, allowing self-signed server certificates.
pub async fn fetch_with_retry(
    url: &str,
    accept_invalid_certs: bool,
) -> anyhow::Result<reqwest::Response> {
    // Hold the Cow for the entire retry loop so an insecure owned client is
    // constructed once per fetch call, not once globally (C-026 fix).
    let cow = get_shared_client(accept_invalid_certs);
    let client: &Client = &cow;
    let mut last_err = None;

    for attempt in 0..=MAX_RETRIES {
        match client.get(url).send().await {
            Ok(resp) => {
                let status = resp.status();
                if status.is_success() || status.is_redirection() {
                    return Ok(resp);
                }
                if status.is_server_error() && attempt < MAX_RETRIES {
                    // 5xx — transient, retry.
                    last_err = Some(anyhow::anyhow!("HTTP {status} from {url}"));
                } else {
                    // 4xx or final attempt — fail.
                    anyhow::bail!("HTTP {status} from {url}");
                }
            }
            Err(e) => {
                if attempt < MAX_RETRIES && is_transient(&e) {
                    last_err = Some(anyhow::anyhow!("{e}"));
                } else {
                    return Err(e.into());
                }
            }
        }

        // Exponential backoff: 500ms, 1000ms, 2000ms.
        let delay = Duration::from_millis(BASE_DELAY_MS * 2u64.pow(attempt));
        tokio::time::sleep(delay).await;
    }

    Err(last_err.unwrap_or_else(|| anyhow::anyhow!("fetch failed after retries")))
}

/// Returns `true` for errors that are likely transient and
/// worth retrying (connection reset, timeout, DNS).
fn is_transient(e: &reqwest::Error) -> bool {
    e.is_connect() || e.is_timeout() || e.is_request()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn shared_client_is_singleton() {
        let a = shared_client() as *const Client;
        let b = shared_client() as *const Client;
        assert!(std::ptr::eq(a, b));
    }

    #[test]
    fn fast_client_is_singleton() {
        let a = fast_client() as *const Client;
        let b = fast_client() as *const Client;
        assert!(std::ptr::eq(a, b));
    }

    #[test]
    fn clients_are_distinct() {
        let shared = shared_client() as *const Client;
        let fast = fast_client() as *const Client;
        assert!(!std::ptr::eq(shared, fast));
    }

    #[test]
    fn insecure_clients_are_owned_not_static() {
        // C-026: insecure clients must be per-call owned values, not singletons.
        // Each call produces a distinct allocation — addresses must NOT be equal.
        let a = get_shared_client(true);
        let b = get_shared_client(true);
        let a_ptr = &*a as *const Client;
        let b_ptr = &*b as *const Client;
        assert!(
            !std::ptr::eq(a_ptr, b_ptr),
            "insecure clients must not share a static allocation"
        );

        let c = get_fast_client(true);
        let d = get_fast_client(true);
        let c_ptr = &*c as *const Client;
        let d_ptr = &*d as *const Client;
        assert!(
            !std::ptr::eq(c_ptr, d_ptr),
            "insecure fast clients must not share a static allocation"
        );
    }

    #[test]
    fn secure_client_is_static_and_insecure_is_owned() {
        // Secure path returns the static reference; insecure returns a new owned value.
        let secure_a = get_shared_client(false);
        let secure_b = get_shared_client(false);
        assert!(
            std::ptr::eq(&*secure_a as *const Client, &*secure_b as *const Client),
            "secure clients must be the same static instance"
        );

        let insecure = get_shared_client(true);
        assert!(
            !std::ptr::eq(&*secure_a as *const Client, &*insecure as *const Client),
            "secure and insecure must be distinct"
        );
    }
}
