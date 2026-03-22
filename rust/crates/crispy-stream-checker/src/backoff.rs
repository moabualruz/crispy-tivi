//! Backoff strategies for stream check retries.
//!
//! Translated from IPTVChecker-Python `get_retry_delay()` inside
//! `check_channel_status()`:
//!
//! ```python
//! def get_retry_delay(attempt_index):
//!     if backoff_mode == 'none':
//!         return 0
//!     if backoff_mode == 'exponential':
//!         return min(2 ** attempt_index, 30)
//!     return min(attempt_index + 1, 10)  # linear
//! ```

use std::time::Duration;

use serde::{Deserialize, Serialize};

/// Backoff strategy for retrying failed stream checks.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "lowercase")]
pub enum BackoffStrategy {
    /// No delay between retries.
    None,
    /// Linear backoff: delay = min(attempt + 1, 10) seconds.
    #[default]
    Linear,
    /// Exponential backoff: delay = min(2^attempt, 30) seconds.
    Exponential,
}

impl BackoffStrategy {
    /// Compute the delay for a given zero-based attempt index.
    ///
    /// Faithful translation of IPTVChecker-Python `get_retry_delay()`:
    /// - None: always 0
    /// - Linear: `min(attempt_index + 1, 10)` seconds
    /// - Exponential: `min(2^attempt_index, 30)` seconds
    pub fn delay(&self, attempt_index: u32) -> Duration {
        match self {
            BackoffStrategy::None => Duration::ZERO,
            BackoffStrategy::Linear => {
                let secs = (attempt_index + 1).min(10);
                Duration::from_secs(u64::from(secs))
            }
            BackoffStrategy::Exponential => {
                let secs = 2u64.saturating_pow(attempt_index).min(30);
                Duration::from_secs(secs)
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn no_backoff_always_zero() {
        for attempt in 0..10 {
            assert_eq!(BackoffStrategy::None.delay(attempt), Duration::ZERO);
        }
    }

    #[test]
    fn linear_backoff_increments_by_one() {
        assert_eq!(BackoffStrategy::Linear.delay(0), Duration::from_secs(1));
        assert_eq!(BackoffStrategy::Linear.delay(1), Duration::from_secs(2));
        assert_eq!(BackoffStrategy::Linear.delay(2), Duration::from_secs(3));
    }

    #[test]
    fn linear_backoff_caps_at_10() {
        assert_eq!(BackoffStrategy::Linear.delay(9), Duration::from_secs(10));
        assert_eq!(BackoffStrategy::Linear.delay(15), Duration::from_secs(10));
        assert_eq!(BackoffStrategy::Linear.delay(100), Duration::from_secs(10));
    }

    #[test]
    fn exponential_backoff_doubles() {
        assert_eq!(
            BackoffStrategy::Exponential.delay(0),
            Duration::from_secs(1)
        );
        assert_eq!(
            BackoffStrategy::Exponential.delay(1),
            Duration::from_secs(2)
        );
        assert_eq!(
            BackoffStrategy::Exponential.delay(2),
            Duration::from_secs(4)
        );
        assert_eq!(
            BackoffStrategy::Exponential.delay(3),
            Duration::from_secs(8)
        );
    }

    #[test]
    fn exponential_backoff_caps_at_30() {
        // 2^5 = 32, capped to 30
        assert_eq!(
            BackoffStrategy::Exponential.delay(5),
            Duration::from_secs(30)
        );
        assert_eq!(
            BackoffStrategy::Exponential.delay(10),
            Duration::from_secs(30)
        );
    }
}
