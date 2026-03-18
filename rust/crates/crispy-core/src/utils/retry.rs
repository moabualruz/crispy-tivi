//! Exponential backoff retry utility.
//!
//! `retry_with_backoff` retries a fallible async operation up to
//! `max_retries` times using the formula:
//!
//! ```text
//! delay = min(initial_delay * 2^attempt, max_delay)
//! if jitter: delay += rand(0..delay * 0.25)
//! ```

use std::future::Future;
use std::time::Duration;

/// Configuration for retry-with-backoff behaviour.
#[derive(Debug, Clone)]
pub struct RetryConfig {
    /// Maximum number of retry attempts (0 = try once, no retries).
    pub max_retries: u32,
    /// Delay before the first retry.
    pub initial_delay: Duration,
    /// Cap on computed delay (prevents unbounded waits).
    pub max_delay: Duration,
    /// Add up to 25 % random jitter to each delay.
    pub jitter: bool,
}

impl Default for RetryConfig {
    fn default() -> Self {
        Self {
            max_retries: 3,
            initial_delay: Duration::from_millis(500),
            max_delay: Duration::from_secs(30),
            jitter: true,
        }
    }
}

impl RetryConfig {
    /// Compute the sleep duration for a given attempt index (0-based).
    ///
    /// Uses integer arithmetic to avoid floating-point imprecision.
    /// Jitter is deterministic in tests when seeded externally — here
    /// we use a simple LCG based on the current time so it doesn't
    /// require a `rand` dependency.
    pub fn delay_for(&self, attempt: u32) -> Duration {
        // Saturating shift: cap at 63 bits to avoid u64 overflow.
        let shift = attempt.min(62);
        let multiplier = 1u64.checked_shl(shift).unwrap_or(u64::MAX);
        let base_ms = self
            .initial_delay
            .as_millis()
            .saturating_mul(multiplier as u128) as u64;
        let max_ms = self.max_delay.as_millis() as u64;
        let capped_ms = base_ms.min(max_ms);

        let final_ms = if self.jitter && capped_ms > 0 {
            // LCG jitter — up to 25 % of capped_ms.
            let seed = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .subsec_nanos() as u64;
            let pseudo = seed.wrapping_mul(6_364_136_223_846_793_005).wrapping_add(1);
            let jitter_ms = (pseudo % (capped_ms / 4 + 1)) as u64;
            capped_ms + jitter_ms
        } else {
            capped_ms
        };

        Duration::from_millis(final_ms)
    }
}

/// Retry `f` up to `config.max_retries` times with exponential backoff.
///
/// The future factory `f` is called for each attempt. If all attempts fail,
/// the last error is returned.
pub async fn retry_with_backoff<F, Fut, T, E>(config: &RetryConfig, mut f: F) -> Result<T, E>
where
    F: FnMut() -> Fut,
    Fut: std::future::Future<Output = Result<T, E>>,
{
    let mut last_err = None;

    for attempt in 0..=config.max_retries {
        match f().await {
            Ok(value) => return Ok(value),
            Err(e) => {
                last_err = Some(e);
                if attempt < config.max_retries {
                    let delay = config.delay_for(attempt);
                    tokio::time::sleep(delay).await;
                }
            }
        }
    }

    // Safety: the loop runs at least once (max_retries >= 0).
    Err(last_err.unwrap())
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use std::sync::Arc;
    use std::sync::atomic::{AtomicU32, Ordering};

    use super::*;

    fn no_jitter_config(max_retries: u32, initial_ms: u64) -> RetryConfig {
        RetryConfig {
            max_retries,
            initial_delay: Duration::from_millis(initial_ms),
            max_delay: Duration::from_secs(60),
            jitter: false,
        }
    }

    #[test]
    fn delay_doubles_each_attempt() {
        let cfg = no_jitter_config(4, 100);
        assert_eq!(cfg.delay_for(0), Duration::from_millis(100));
        assert_eq!(cfg.delay_for(1), Duration::from_millis(200));
        assert_eq!(cfg.delay_for(2), Duration::from_millis(400));
        assert_eq!(cfg.delay_for(3), Duration::from_millis(800));
    }

    #[test]
    fn delay_capped_at_max() {
        let cfg = RetryConfig {
            max_retries: 10,
            initial_delay: Duration::from_millis(500),
            max_delay: Duration::from_millis(2000),
            jitter: false,
        };
        for attempt in 3..10 {
            assert!(cfg.delay_for(attempt) <= Duration::from_millis(2000));
        }
    }

    #[test]
    fn delay_jitter_within_bounds() {
        let cfg = RetryConfig {
            max_retries: 3,
            initial_delay: Duration::from_millis(100),
            max_delay: Duration::from_secs(10),
            jitter: true,
        };
        let base = Duration::from_millis(100);
        let upper = Duration::from_millis(125); // 100 + 25 % = 125
        // Run a few times to ensure jitter stays in range.
        for _ in 0..20 {
            let d = cfg.delay_for(0);
            assert!(d >= base, "jitter must not reduce delay: {d:?}");
            assert!(d <= upper, "jitter exceeds 25 %: {d:?}");
        }
    }

    #[tokio::test]
    async fn succeeds_on_first_try() {
        let cfg = no_jitter_config(3, 1);
        let result = retry_with_backoff(&cfg, || async { Ok::<i32, &str>(42) }).await;
        assert_eq!(result.unwrap(), 42);
    }

    #[tokio::test]
    async fn retries_and_succeeds_on_third_attempt() {
        let cfg = no_jitter_config(5, 1);
        let counter = Arc::new(AtomicU32::new(0));

        let c = counter.clone();
        let result = retry_with_backoff(&cfg, move || {
            let c = c.clone();
            async move {
                let n = c.fetch_add(1, Ordering::SeqCst);
                if n < 2 { Err("not yet") } else { Ok("done") }
            }
        })
        .await;

        assert_eq!(result.unwrap(), "done");
        assert_eq!(counter.load(Ordering::SeqCst), 3);
    }

    #[tokio::test]
    async fn exhausts_retries_and_returns_last_error() {
        let cfg = no_jitter_config(2, 1);
        let counter = Arc::new(AtomicU32::new(0));

        let c = counter.clone();
        let result = retry_with_backoff(&cfg, move || {
            let c = c.clone();
            async move {
                c.fetch_add(1, Ordering::SeqCst);
                Err::<(), &str>("always fails")
            }
        })
        .await;

        assert_eq!(result.unwrap_err(), "always fails");
        // 1 initial + 2 retries = 3 total calls
        assert_eq!(counter.load(Ordering::SeqCst), 3);
    }

    #[tokio::test]
    async fn zero_retries_calls_exactly_once() {
        let cfg = no_jitter_config(0, 100);
        let counter = Arc::new(AtomicU32::new(0));

        let c = counter.clone();
        let _ = retry_with_backoff(&cfg, move || {
            let c = c.clone();
            async move {
                c.fetch_add(1, Ordering::SeqCst);
                Err::<(), &str>("fail")
            }
        })
        .await;

        assert_eq!(counter.load(Ordering::SeqCst), 1);
    }
}
