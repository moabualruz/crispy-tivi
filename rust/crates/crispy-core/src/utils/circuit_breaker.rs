//! Circuit breaker for source connections.
//!
//! Transitions:
//! ```text
//! Closed ──(threshold failures)──► Open ──(recovery_timeout)──► HalfOpen
//!   ▲                                                               │
//!   └──────────────(success)───────────────────────────────────────┘
//!                                  ▲
//!                                  └──(failure in HalfOpen)── back to Open
//! ```

use std::sync::Mutex;
use std::time::{Duration, Instant};

/// State of a [`CircuitBreaker`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CircuitState {
    /// Normal — requests flow through.
    Closed,
    /// Failing — reject requests, serve cached data.
    Open,
    /// Testing — allow one probe request through.
    HalfOpen,
}

/// Thread-safe circuit breaker for a single upstream source.
#[allow(dead_code)] // wired when sync services adopt circuit breaker pattern (Epoch 1)
pub(crate) struct CircuitBreaker {
    state: Mutex<CircuitState>,
    failure_count: Mutex<u32>,
    last_failure: Mutex<Option<Instant>>,
    /// Number of consecutive failures that trips the breaker.
    failure_threshold: u32,
    /// Time to wait in `Open` before transitioning to `HalfOpen`.
    recovery_timeout: Duration,
}

#[allow(dead_code)]
impl CircuitBreaker {
    /// Create a new circuit breaker with custom parameters.
    pub(crate) fn new(failure_threshold: u32, recovery_timeout: Duration) -> Self {
        Self {
            state: Mutex::new(CircuitState::Closed),
            failure_count: Mutex::new(0),
            last_failure: Mutex::new(None),
            failure_threshold,
            recovery_timeout,
        }
    }

    /// Create with defaults: threshold = 3, recovery = 30 s.
    pub(crate) fn default() -> Self {
        Self::new(3, Duration::from_secs(30))
    }

    /// Current state (with automatic `Open → HalfOpen` promotion on timeout).
    pub(crate) fn state(&self) -> CircuitState {
        let mut state = self.state.lock().unwrap();
        if *state == CircuitState::Open {
            let last = *self.last_failure.lock().unwrap();
            if let Some(t) = last
                && t.elapsed() >= self.recovery_timeout
            {
                *state = CircuitState::HalfOpen;
            }
        }
        *state
    }

    /// Returns `true` if the breaker allows a request (`Closed` or `HalfOpen`).
    pub(crate) fn allow_request(&self) -> bool {
        matches!(self.state(), CircuitState::Closed | CircuitState::HalfOpen)
    }

    /// Record a successful response — resets to `Closed`.
    pub(crate) fn record_success(&self) {
        *self.state.lock().unwrap() = CircuitState::Closed;
        *self.failure_count.lock().unwrap() = 0;
        *self.last_failure.lock().unwrap() = None;
    }

    /// Record a failure — may trip the breaker to `Open`.
    pub(crate) fn record_failure(&self) {
        let mut count = self.failure_count.lock().unwrap();
        *count += 1;
        *self.last_failure.lock().unwrap() = Some(Instant::now());

        if *count >= self.failure_threshold {
            *self.state.lock().unwrap() = CircuitState::Open;
        }
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use std::thread;

    #[test]
    fn test_starts_closed() {
        let cb = CircuitBreaker::default();
        assert_eq!(cb.state(), CircuitState::Closed);
        assert!(cb.allow_request());
    }

    #[test]
    fn test_opens_after_threshold_failures() {
        let cb = CircuitBreaker::new(3, Duration::from_secs(60));
        cb.record_failure();
        assert_eq!(cb.state(), CircuitState::Closed);
        cb.record_failure();
        assert_eq!(cb.state(), CircuitState::Closed);
        cb.record_failure();
        assert_eq!(cb.state(), CircuitState::Open);
        assert!(!cb.allow_request());
    }

    #[test]
    fn test_transitions_to_half_open_after_timeout() {
        // Use a tiny recovery timeout so we don't have to sleep long in tests.
        let cb = CircuitBreaker::new(1, Duration::from_millis(20));
        cb.record_failure();
        assert_eq!(cb.state(), CircuitState::Open);

        thread::sleep(Duration::from_millis(30));

        assert_eq!(cb.state(), CircuitState::HalfOpen);
        assert!(cb.allow_request());
    }

    #[test]
    fn test_closes_on_success_in_half_open() {
        let cb = CircuitBreaker::new(1, Duration::from_millis(20));
        cb.record_failure();
        thread::sleep(Duration::from_millis(30));
        assert_eq!(cb.state(), CircuitState::HalfOpen);

        cb.record_success();
        assert_eq!(cb.state(), CircuitState::Closed);
        assert!(cb.allow_request());
    }

    #[test]
    fn test_reopens_on_failure_in_half_open() {
        let cb = CircuitBreaker::new(1, Duration::from_millis(20));
        cb.record_failure();
        thread::sleep(Duration::from_millis(30));
        assert_eq!(cb.state(), CircuitState::HalfOpen);

        // A second failure while HalfOpen should push count past threshold → Open.
        cb.record_failure();
        assert_eq!(cb.state(), CircuitState::Open);
        assert!(!cb.allow_request());
    }
}
