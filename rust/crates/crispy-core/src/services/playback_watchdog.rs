//! Playback watchdog — detects hung playback and triggers recovery.
//!
//! `Watchdog::start(on_hung)` spawns a tokio task that checks
//! whether `report_frame()` has been called within the last 5 s
//! (configurable). When it hasn't, `on_hung` is invoked once and
//! the watchdog enters a "fired" state to avoid repeated callbacks.
//!
//! `Watchdog::stop()` cancels the background task.
//! `Watchdog::reset()` re-arms the watchdog after a recovery.

use std::{
    sync::{Arc, Mutex},
    time::{Duration, Instant},
};

use tokio::task::JoinHandle;

// ── Watchdog state ────────────────────────────────────────────────────────────

#[derive(Debug, Clone, PartialEq, Eq)]
enum WatchState {
    Idle,
    Running,
    Fired,
}

struct WatchdogInner {
    last_frame: Instant,
    hung_threshold: Duration,
    state: WatchState,
}

impl WatchdogInner {
    fn new(threshold: Duration) -> Self {
        Self {
            last_frame: Instant::now(),
            hung_threshold: threshold,
            state: WatchState::Idle,
        }
    }

    fn is_hung(&self) -> bool {
        self.state == WatchState::Running && self.last_frame.elapsed() > self.hung_threshold
    }
}

// ── Watchdog ──────────────────────────────────────────────────────────────────

/// Playback watchdog.
///
/// Detects hung playback (no new frame for > `threshold`) and fires
/// `on_hung` once. Must be started via `start()`.
pub struct Watchdog {
    inner: Arc<Mutex<WatchdogInner>>,
    task: Mutex<Option<JoinHandle<()>>>,
}

impl Watchdog {
    /// Create a watchdog with the given hung-detection threshold.
    ///
    /// The watchdog is idle until `start()` is called.
    pub fn new(threshold: Duration) -> Self {
        Self {
            inner: Arc::new(Mutex::new(WatchdogInner::new(threshold))),
            task: Mutex::new(None),
        }
    }

    /// Create a watchdog with the default 5-second threshold.
    pub fn with_default_threshold() -> Self {
        Self::new(Duration::from_secs(5))
    }

    // ── Frame reporting ──────────────────────────────────────────────────────

    /// Called on every rendered frame by the player backend.
    ///
    /// Resets the hung timer and clears a previously-fired state.
    pub fn report_frame(&self) {
        let mut g = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        g.last_frame = Instant::now();
        if g.state == WatchState::Fired {
            // Re-arm automatically after a recovery produces frames again.
            g.state = WatchState::Running;
        }
    }

    // ── Lifecycle ────────────────────────────────────────────────────────────

    /// Start the watchdog. Spawns a tokio task that polls every `poll_interval`.
    ///
    /// `on_hung` is called at most once per hung episode. After firing the
    /// watchdog transitions to `Fired` state; call `reset()` to re-arm for
    /// the next playback session.
    pub fn start<F>(&self, poll_interval: Duration, on_hung: F)
    where
        F: Fn() + Send + 'static,
    {
        {
            let mut g = self.inner.lock().unwrap_or_else(|e| e.into_inner());
            g.last_frame = Instant::now();
            g.state = WatchState::Running;
        }

        let inner = Arc::clone(&self.inner);
        let handle = tokio::spawn(async move {
            loop {
                tokio::time::sleep(poll_interval).await;
                let mut g = inner.lock().unwrap_or_else(|e| e.into_inner());
                if g.state == WatchState::Fired || g.state == WatchState::Idle {
                    break;
                }
                if g.is_hung() {
                    g.state = WatchState::Fired;
                    drop(g);
                    on_hung();
                    break;
                }
            }
        });

        *self.task.lock().unwrap_or_else(|e| e.into_inner()) = Some(handle);
    }

    /// Stop the watchdog task. Safe to call multiple times.
    pub fn stop(&self) {
        {
            let mut g = self.inner.lock().unwrap_or_else(|e| e.into_inner());
            g.state = WatchState::Idle;
        }
        if let Some(handle) = self.task.lock().unwrap_or_else(|e| e.into_inner()).take() {
            handle.abort();
        }
    }

    /// Re-arm the watchdog for a new playback session after recovery.
    pub fn reset(&self) {
        let mut g = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        g.last_frame = Instant::now();
        g.state = WatchState::Running;
    }

    /// Returns `true` if the watchdog has fired (hung state detected).
    pub fn has_fired(&self) -> bool {
        self.inner.lock().unwrap_or_else(|e| e.into_inner()).state == WatchState::Fired
    }

    /// Returns the time since the last reported frame.
    pub fn time_since_last_frame(&self) -> Duration {
        self.inner
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .last_frame
            .elapsed()
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicU32, Ordering};

    #[test]
    fn test_not_fired_initially() {
        let w = Watchdog::new(Duration::from_secs(5));
        assert!(!w.has_fired());
    }

    #[test]
    fn test_report_frame_resets_timer() {
        let w = Watchdog::new(Duration::from_millis(100));
        std::thread::sleep(Duration::from_millis(50));
        w.report_frame();
        let elapsed = w.time_since_last_frame();
        assert!(elapsed < Duration::from_millis(50));
    }

    #[tokio::test]
    async fn test_watchdog_fires_on_hung() {
        let fired = Arc::new(AtomicU32::new(0));
        let fired_clone = Arc::clone(&fired);

        let w = Arc::new(Watchdog::new(Duration::from_millis(50)));
        w.start(Duration::from_millis(10), move || {
            fired_clone.fetch_add(1, Ordering::SeqCst);
        });

        // Do not report any frames — should fire.
        tokio::time::sleep(Duration::from_millis(200)).await;
        assert!(w.has_fired());
        assert_eq!(
            fired.load(Ordering::SeqCst),
            1,
            "on_hung must fire exactly once"
        );
        w.stop();
    }

    #[tokio::test]
    async fn test_watchdog_does_not_fire_with_frames() {
        let fired = Arc::new(AtomicU32::new(0));
        let fired_clone = Arc::clone(&fired);

        let w = Arc::new(Watchdog::new(Duration::from_millis(80)));
        w.start(Duration::from_millis(10), move || {
            fired_clone.fetch_add(1, Ordering::SeqCst);
        });

        // Keep reporting frames faster than the threshold.
        for _ in 0..10 {
            tokio::time::sleep(Duration::from_millis(20)).await;
            w.report_frame();
        }

        assert!(!w.has_fired());
        assert_eq!(fired.load(Ordering::SeqCst), 0);
        w.stop();
    }

    #[tokio::test]
    async fn test_on_hung_called_exactly_once() {
        let count = Arc::new(AtomicU32::new(0));
        let count_clone = Arc::clone(&count);

        let w = Arc::new(Watchdog::new(Duration::from_millis(30)));
        w.start(Duration::from_millis(5), move || {
            count_clone.fetch_add(1, Ordering::SeqCst);
        });

        tokio::time::sleep(Duration::from_millis(200)).await;
        assert_eq!(count.load(Ordering::SeqCst), 1);
        w.stop();
    }

    #[test]
    fn test_stop_sets_idle() {
        let w = Watchdog::new(Duration::from_secs(5));
        {
            let mut g = w.inner.lock().unwrap();
            g.state = WatchState::Running;
        }
        w.stop();
        let g = w.inner.lock().unwrap();
        assert_eq!(g.state, WatchState::Idle);
    }

    #[test]
    fn test_reset_re_arms() {
        let w = Watchdog::new(Duration::from_millis(50));
        {
            let mut g = w.inner.lock().unwrap();
            g.state = WatchState::Fired;
        }
        w.reset();
        assert!(!w.has_fired());
    }

    #[test]
    fn test_report_frame_after_fire_re_arms() {
        let w = Watchdog::new(Duration::from_millis(50));
        {
            let mut g = w.inner.lock().unwrap();
            g.state = WatchState::Fired;
        }
        w.report_frame();
        assert!(!w.has_fired());
    }
}
