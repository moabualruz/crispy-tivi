//! Shared HTTP client singletons for IPTV source operations.
//!
//! Provides connection-pooled `reqwest::Client` instances configured
//! for IPTV use cases. Two clients with different timeout profiles:
//! - `shared_client()` — general fetching (playlists, EPG, streams)
//! - `fast_client()` — credential verification, URL checks
//!
//! Each profile also has an insecure variant that accepts self-signed
//! TLS certificates, accessible via `get_shared_client(true)` and
//! `get_fast_client(true)`.

use std::sync::OnceLock;
use std::time::Duration;

use reqwest::Client;

/// General-purpose HTTP client for playlist/EPG fetching.
///
/// Connection-pooled, gzip-enabled, 15s connect / 120s total timeout.
static HTTP_CLIENT: OnceLock<Client> = OnceLock::new();

/// Fast HTTP client for credential verification and URL checks.
///
/// Shorter timeouts (5s connect / 10s total) for quick pass/fail.
static FAST_CLIENT: OnceLock<Client> = OnceLock::new();

/// Insecure general-purpose client (self-signed certs accepted).
static INSECURE_HTTP_CLIENT: OnceLock<Client> = OnceLock::new();

/// Insecure fast client (self-signed certs accepted).
static INSECURE_FAST_CLIENT: OnceLock<Client> = OnceLock::new();

/// Returns the shared general-purpose HTTP client.
pub fn shared_client() -> &'static Client {
    HTTP_CLIENT.get_or_init(|| {
        Client::builder()
            .pool_max_idle_per_host(4)
            .pool_idle_timeout(Duration::from_secs(90))
            .tcp_keepalive(Duration::from_secs(60))
            .connect_timeout(Duration::from_secs(15))
            .timeout(Duration::from_secs(120))
            .user_agent("CrispyTivi/1.0")
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
            .user_agent("CrispyTivi/1.0")
            .redirect(reqwest::redirect::Policy::limited(3))
            .gzip(true)
            .build()
            .expect("Fast HTTP client build failed")
    })
}

/// Returns the insecure shared client (accepts invalid certs).
fn insecure_shared_client() -> &'static Client {
    INSECURE_HTTP_CLIENT.get_or_init(|| {
        Client::builder()
            .danger_accept_invalid_certs(true)
            .pool_max_idle_per_host(4)
            .pool_idle_timeout(Duration::from_secs(90))
            .tcp_keepalive(Duration::from_secs(60))
            .connect_timeout(Duration::from_secs(15))
            .timeout(Duration::from_secs(120))
            .user_agent("CrispyTivi/1.0")
            .redirect(reqwest::redirect::Policy::limited(5))
            .gzip(true)
            .build()
            .expect("Insecure HTTP client build failed")
    })
}

/// Returns the insecure fast client (accepts invalid certs).
fn insecure_fast_client() -> &'static Client {
    INSECURE_FAST_CLIENT.get_or_init(|| {
        Client::builder()
            .danger_accept_invalid_certs(true)
            .connect_timeout(Duration::from_secs(5))
            .timeout(Duration::from_secs(10))
            .user_agent("CrispyTivi/1.0")
            .redirect(reqwest::redirect::Policy::limited(3))
            .gzip(true)
            .build()
            .expect("Insecure fast client build failed")
    })
}

/// Returns the appropriate general-purpose client based on TLS policy.
pub fn get_shared_client(accept_invalid_certs: bool) -> &'static Client {
    if accept_invalid_certs {
        insecure_shared_client()
    } else {
        shared_client()
    }
}

/// Returns the appropriate fast client based on TLS policy.
pub fn get_fast_client(accept_invalid_certs: bool) -> &'static Client {
    if accept_invalid_certs {
        insecure_fast_client()
    } else {
        fast_client()
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
    let client = get_shared_client(accept_invalid_certs);
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
        std::thread::sleep(delay);
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
    fn insecure_clients_are_singletons() {
        let a = get_shared_client(true) as *const Client;
        let b = get_shared_client(true) as *const Client;
        assert!(std::ptr::eq(a, b));

        let c = get_fast_client(true) as *const Client;
        let d = get_fast_client(true) as *const Client;
        assert!(std::ptr::eq(c, d));
    }

    #[test]
    fn secure_and_insecure_are_distinct() {
        let secure = get_shared_client(false) as *const Client;
        let insecure = get_shared_client(true) as *const Client;
        assert!(!std::ptr::eq(secure, insecure));
    }
}
