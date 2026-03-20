//! Circuit breaker for resilient service calls.
//!
//! States: Closed → Open → HalfOpen → Closed
//!
//! - **Closed**: requests pass through normally; failures increment a counter.
//! - **Open**: requests are rejected immediately (no I/O); last cached result is returned if available.
//! - **HalfOpen**: one probe request is allowed after `reset_timeout`; success closes the breaker, failure re-opens it.

use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use crate::errors::CrispyError;

// ── State ─────────────────────────────────────────────────────────────────────

/// Internal state of the circuit breaker.
#[derive(Debug, Clone, PartialEq)]
pub enum BreakerState {
    /// Normal operation.
    Closed,
    /// Rejecting requests; will transition to HalfOpen after `reset_timeout`.
    Open { opened_at: Instant },
    /// Allowing one probe request.
    HalfOpen,
}

// ── Config ────────────────────────────────────────────────────────────────────

/// Configuration for a `CircuitBreaker`.
#[derive(Debug, Clone)]
pub struct BreakerConfig {
    /// Number of consecutive failures before opening the breaker.
    pub failure_threshold: u32,
    /// How long to stay open before probing with HalfOpen.
    pub reset_timeout: Duration,
    /// Maximum concurrent probe calls allowed in HalfOpen (currently 1).
    pub half_open_max_calls: u32,
}

impl Default for BreakerConfig {
    fn default() -> Self {
        Self {
            failure_threshold: 5,
            reset_timeout: Duration::from_secs(30),
            half_open_max_calls: 1,
        }
    }
}

// ── Inner state ───────────────────────────────────────────────────────────────

struct BreakerInner {
    state: BreakerState,
    failure_count: u32,
    half_open_probes: u32,
    config: BreakerConfig,
}

impl BreakerInner {
    fn new(config: BreakerConfig) -> Self {
        Self {
            state: BreakerState::Closed,
            failure_count: 0,
            half_open_probes: 0,
            config,
        }
    }

    /// Returns `true` if the breaker should allow the call to proceed.
    /// Transitions Open → HalfOpen when reset_timeout has elapsed.
    fn should_allow(&mut self) -> bool {
        match self.state {
            BreakerState::Closed => true,
            BreakerState::HalfOpen => {
                if self.half_open_probes < self.config.half_open_max_calls {
                    self.half_open_probes += 1;
                    true
                } else {
                    false
                }
            }
            BreakerState::Open { opened_at } => {
                if opened_at.elapsed() >= self.config.reset_timeout {
                    self.state = BreakerState::HalfOpen;
                    self.half_open_probes = 1;
                    true
                } else {
                    false
                }
            }
        }
    }

    fn on_success(&mut self) {
        self.failure_count = 0;
        self.half_open_probes = 0;
        self.state = BreakerState::Closed;
    }

    fn on_failure(&mut self) {
        match self.state {
            BreakerState::Closed => {
                self.failure_count += 1;
                if self.failure_count >= self.config.failure_threshold {
                    self.state = BreakerState::Open {
                        opened_at: Instant::now(),
                    };
                }
            }
            BreakerState::HalfOpen => {
                // Probe failed — re-open.
                self.half_open_probes = 0;
                self.state = BreakerState::Open {
                    opened_at: Instant::now(),
                };
            }
            BreakerState::Open { .. } => {
                // Already open; update timestamp so reset_timeout restarts.
                self.state = BreakerState::Open {
                    opened_at: Instant::now(),
                };
            }
        }
    }

    fn current_state(&self) -> BreakerState {
        self.state.clone()
    }
}

// ── CircuitBreaker ────────────────────────────────────────────────────────────

/// Thread-safe circuit breaker wrapping a fallible async operation.
///
/// # Example
/// ```ignore
/// let cb = CircuitBreaker::new(BreakerConfig::default());
/// let result = cb.call(|| async { fetch_data().await }).await;
/// ```
#[derive(Clone)]
pub struct CircuitBreaker {
    inner: Arc<Mutex<BreakerInner>>,
}

impl CircuitBreaker {
    /// Create a new circuit breaker with the given configuration.
    pub fn new(config: BreakerConfig) -> Self {
        Self {
            inner: Arc::new(Mutex::new(BreakerInner::new(config))),
        }
    }

    /// Create a circuit breaker with default configuration.
    pub fn default_config() -> Self {
        Self::new(BreakerConfig::default())
    }

    /// Execute `f` through the circuit breaker.
    ///
    /// - **Closed / HalfOpen**: runs `f`; records success or failure.
    /// - **Open**: returns `Err(CrispyError::Network { .. })` immediately (no I/O).
    pub async fn call<F, Fut, T>(&self, f: F) -> Result<T, CrispyError>
    where
        F: FnOnce() -> Fut,
        Fut: std::future::Future<Output = Result<T, CrispyError>>,
    {
        let allowed = {
            let mut inner = self.inner.lock().unwrap();
            inner.should_allow()
        };

        if !allowed {
            return Err(CrispyError::network(
                "circuit breaker is open — request rejected",
            ));
        }

        let result = f().await;

        {
            let mut inner = self.inner.lock().unwrap();
            if result.is_ok() {
                inner.on_success();
            } else {
                inner.on_failure();
            }
        }

        result
    }

    /// Return the current breaker state (for monitoring / logging).
    pub fn state(&self) -> BreakerState {
        self.inner.lock().unwrap().current_state()
    }

    /// Return the current failure count (only meaningful in Closed state).
    pub fn failure_count(&self) -> u32 {
        self.inner.lock().unwrap().failure_count
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use std::sync::atomic::{AtomicU32, Ordering};

    use super::*;

    fn fast_config() -> BreakerConfig {
        BreakerConfig {
            failure_threshold: 3,
            reset_timeout: Duration::from_millis(50),
            half_open_max_calls: 1,
        }
    }

    async fn ok_call() -> Result<&'static str, CrispyError> {
        Ok("ok")
    }

    async fn fail_call() -> Result<&'static str, CrispyError> {
        Err(CrispyError::network("simulated failure"))
    }

    #[tokio::test]
    async fn starts_closed() {
        let cb = CircuitBreaker::new(fast_config());
        assert_eq!(cb.state(), BreakerState::Closed);
    }

    #[tokio::test]
    async fn success_in_closed_keeps_closed() {
        let cb = CircuitBreaker::new(fast_config());
        cb.call(ok_call).await.unwrap();
        assert_eq!(cb.state(), BreakerState::Closed);
        assert_eq!(cb.failure_count(), 0);
    }

    #[tokio::test]
    async fn failures_increment_count() {
        let cb = CircuitBreaker::new(fast_config());
        cb.call(fail_call).await.unwrap_err();
        assert_eq!(cb.failure_count(), 1);
        cb.call(fail_call).await.unwrap_err();
        assert_eq!(cb.failure_count(), 2);
    }

    #[tokio::test]
    async fn opens_after_threshold() {
        let cb = CircuitBreaker::new(fast_config());
        for _ in 0..3 {
            let _ = cb.call(fail_call).await;
        }
        assert!(matches!(cb.state(), BreakerState::Open { .. }));
    }

    #[tokio::test]
    async fn open_rejects_immediately_without_calling_f() {
        let cb = CircuitBreaker::new(fast_config());
        for _ in 0..3 {
            let _ = cb.call(fail_call).await;
        }

        let calls = Arc::new(AtomicU32::new(0));
        let calls_clone = calls.clone();
        let result = cb
            .call(move || {
                let c = calls_clone.clone();
                async move {
                    c.fetch_add(1, Ordering::SeqCst);
                    Ok::<_, CrispyError>("should not reach")
                }
            })
            .await;

        assert!(result.is_err());
        assert_eq!(calls.load(Ordering::SeqCst), 0, "f must not be called when open");
    }

    #[tokio::test]
    async fn transitions_to_half_open_after_timeout() {
        let cb = CircuitBreaker::new(fast_config());
        for _ in 0..3 {
            let _ = cb.call(fail_call).await;
        }
        assert!(matches!(cb.state(), BreakerState::Open { .. }));

        tokio::time::sleep(Duration::from_millis(60)).await;

        // Next call should transition to HalfOpen and execute.
        let result = cb.call(ok_call).await;
        assert!(result.is_ok());
        assert_eq!(cb.state(), BreakerState::Closed);
    }

    #[tokio::test]
    async fn half_open_probe_failure_reopens() {
        let cb = CircuitBreaker::new(fast_config());
        for _ in 0..3 {
            let _ = cb.call(fail_call).await;
        }

        tokio::time::sleep(Duration::from_millis(60)).await;

        // Probe fails → back to Open.
        let _ = cb.call(fail_call).await;
        assert!(matches!(cb.state(), BreakerState::Open { .. }));
    }

    #[tokio::test]
    async fn success_after_half_open_closes_breaker() {
        let cb = CircuitBreaker::new(fast_config());
        for _ in 0..3 {
            let _ = cb.call(fail_call).await;
        }

        tokio::time::sleep(Duration::from_millis(60)).await;

        cb.call(ok_call).await.unwrap();
        assert_eq!(cb.state(), BreakerState::Closed);
        assert_eq!(cb.failure_count(), 0);
    }

    #[tokio::test]
    async fn thread_safety_concurrent_calls() {
        use std::sync::Arc;
        use tokio::task::JoinSet;

        let cb = Arc::new(CircuitBreaker::new(BreakerConfig {
            failure_threshold: 100,
            reset_timeout: Duration::from_secs(60),
            half_open_max_calls: 1,
        }));

        let mut set = JoinSet::new();
        for _ in 0..20 {
            let cb_clone = cb.clone();
            set.spawn(async move { cb_clone.call(ok_call).await });
        }

        let mut ok = 0u32;
        while let Some(res) = set.join_next().await {
            if res.unwrap().is_ok() {
                ok += 1;
            }
        }
        assert_eq!(ok, 20);
        assert_eq!(cb.state(), BreakerState::Closed);
    }
}
