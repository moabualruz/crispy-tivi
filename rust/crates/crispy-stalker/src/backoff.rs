//! Exponential backoff strategy for HTTP retries.
//!
//! Faithfully translated from:
//! - Python: `sleep_time = backoff_factor * (2 ** (attempt - 1))`
//! - TypeScript: `STALKER_RETRY_BACKOFF_BASE_MS * Math.pow(2, attempt - 1)`

use std::time::Duration;

/// Configuration for exponential backoff retries.
#[derive(Debug, Clone)]
pub struct BackoffConfig {
    /// Maximum number of retry attempts.
    pub max_retries: u32,

    /// Base backoff duration (multiplied by `2^(attempt-1)`).
    pub backoff_factor: Duration,

    /// Maximum backoff duration (cap).
    pub max_backoff: Duration,
}

impl Default for BackoffConfig {
    fn default() -> Self {
        Self {
            max_retries: 3,
            backoff_factor: Duration::from_secs(1),
            max_backoff: Duration::from_secs(30),
        }
    }
}

impl BackoffConfig {
    /// Calculate the sleep duration for a given attempt (1-indexed).
    ///
    /// Formula: `backoff_factor * 2^(attempt - 1)`, capped at `max_backoff`.
    ///
    /// Python: `sleep_time = self.backoff_factor * (2 ** (attempt - 1))`
    /// TypeScript: `STALKER_RETRY_BACKOFF_BASE_MS * Math.pow(2, attempt - 1)`
    pub fn delay_for_attempt(&self, attempt: u32) -> Duration {
        if attempt == 0 {
            return Duration::ZERO;
        }
        let multiplier = 2u64.saturating_pow(attempt - 1);
        #[allow(clippy::cast_possible_truncation)]
        let capped = multiplier.min(u64::from(u32::MAX)) as u32;
        let delay = self.backoff_factor.saturating_mul(capped);
        delay.min(self.max_backoff)
    }

    /// Whether the given attempt (1-indexed) should be retried.
    pub fn should_retry(&self, attempt: u32) -> bool {
        attempt < self.max_retries
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn delay_doubles_each_attempt() {
        let config = BackoffConfig {
            max_retries: 5,
            backoff_factor: Duration::from_secs(1),
            max_backoff: Duration::from_secs(60),
        };

        assert_eq!(config.delay_for_attempt(1), Duration::from_secs(1));
        assert_eq!(config.delay_for_attempt(2), Duration::from_secs(2));
        assert_eq!(config.delay_for_attempt(3), Duration::from_secs(4));
        assert_eq!(config.delay_for_attempt(4), Duration::from_secs(8));
        assert_eq!(config.delay_for_attempt(5), Duration::from_secs(16));
    }

    #[test]
    fn delay_capped_at_max_backoff() {
        let config = BackoffConfig {
            max_retries: 10,
            backoff_factor: Duration::from_secs(1),
            max_backoff: Duration::from_secs(10),
        };

        // 2^4 = 16, but capped at 10
        assert_eq!(config.delay_for_attempt(5), Duration::from_secs(10));
        assert_eq!(config.delay_for_attempt(10), Duration::from_secs(10));
    }

    #[test]
    fn delay_zero_for_attempt_zero() {
        let config = BackoffConfig::default();
        assert_eq!(config.delay_for_attempt(0), Duration::ZERO);
    }

    #[test]
    fn fractional_backoff_factor() {
        let config = BackoffConfig {
            max_retries: 3,
            backoff_factor: Duration::from_millis(500),
            max_backoff: Duration::from_secs(30),
        };

        assert_eq!(config.delay_for_attempt(1), Duration::from_millis(500));
        assert_eq!(config.delay_for_attempt(2), Duration::from_millis(1000));
        assert_eq!(config.delay_for_attempt(3), Duration::from_millis(2000));
    }

    #[test]
    fn should_retry_within_limit() {
        let config = BackoffConfig {
            max_retries: 3,
            ..Default::default()
        };

        assert!(config.should_retry(1));
        assert!(config.should_retry(2));
        assert!(!config.should_retry(3));
        assert!(!config.should_retry(4));
    }

    #[test]
    fn default_config_values() {
        let config = BackoffConfig::default();
        assert_eq!(config.max_retries, 3);
        assert_eq!(config.backoff_factor, Duration::from_secs(1));
        assert_eq!(config.max_backoff, Duration::from_secs(30));
    }
}
