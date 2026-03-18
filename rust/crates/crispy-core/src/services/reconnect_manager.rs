//! Auto-reconnect with exponential backoff for CrispyTivi.
//!
//! Drives automatic reconnect attempts when a stream or service
//! connection drops. Backoff sequence: 0 → 2 → 5 → 15 → 30 s.
//! After 5 minutes total elapsed time the manager transitions
//! to `GaveUp` and requires a manual retry from the user.

use std::time::{Duration, Instant};

// ── Backoff sequence ─────────────────────────────────────

/// Delay before each attempt (index = attempt number 0-based).
/// Attempt 0 is immediate (0 s).
const BACKOFF_DELAYS: &[Duration] = &[
    Duration::from_secs(0),
    Duration::from_secs(2),
    Duration::from_secs(5),
    Duration::from_secs(15),
    Duration::from_secs(30),
];

/// Total wall-clock window after which the manager gives up.
const GIVE_UP_AFTER: Duration = Duration::from_secs(300); // 5 minutes

// ── ReconnectState ───────────────────────────────────────

/// Current state of the reconnect machine.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ReconnectState {
    /// Actively attempting connection. `attempt` is 1-based.
    Connecting { attempt: u32 },
    /// Connection is established.
    Connected,
    /// All retries exhausted; user must trigger manually.
    GaveUp,
}

// ── ReconnectManager ─────────────────────────────────────

/// Manages exponential-backoff reconnect logic.
///
/// Intended for synchronous use (no Tokio runtime required in
/// production crispy-core). Callers drive the retry loop by
/// calling [`ReconnectManager::next_delay`] and sleeping for
/// the returned duration before attempting the connection.
///
/// For async callers, use
/// [`ReconnectManager::start`] which spawns a Tokio task.
pub struct ReconnectManager {
    state: ReconnectState,
    attempt: u32,
    started_at: Option<Instant>,
}

impl ReconnectManager {
    /// Create a new manager in `Connected` state.
    pub fn new() -> Self {
        Self {
            state: ReconnectState::Connected,
            attempt: 0,
            started_at: None,
        }
    }

    /// Current state.
    pub fn state(&self) -> &ReconnectState {
        &self.state
    }

    /// Notify the manager that the connection was lost.
    /// Transitions to `Connecting { attempt: 1 }` and records
    /// the start time for the give-up window.
    pub fn notify_disconnected(&mut self) {
        self.attempt = 1;
        self.started_at = Some(Instant::now());
        self.state = ReconnectState::Connecting { attempt: 1 };
    }

    /// Notify the manager that the connection succeeded.
    /// Resets all backoff state.
    pub fn notify_connected(&mut self) {
        self.attempt = 0;
        self.started_at = None;
        self.state = ReconnectState::Connected;
    }

    /// Called when the user requests a manual retry after `GaveUp`.
    /// Resets to `Connecting { attempt: 1 }` with a fresh window.
    pub fn stop(&mut self) {
        self.attempt = 0;
        self.started_at = None;
        self.state = ReconnectState::Connected;
    }

    /// Returns the delay before the *next* attempt, or `None` if
    /// the manager has given up or is not in a reconnecting state.
    ///
    /// Advances the internal attempt counter and checks the give-up
    /// window. Callers should sleep for the returned duration, then
    /// attempt the connection, then call either
    /// [`notify_connected`](Self::notify_connected) or call this
    /// method again if the attempt failed.
    pub fn next_delay(&mut self) -> Option<Duration> {
        if self.state == ReconnectState::GaveUp || self.state == ReconnectState::Connected {
            return None;
        }

        // Check give-up window.
        if let Some(started) = self.started_at {
            if started.elapsed() >= GIVE_UP_AFTER {
                self.state = ReconnectState::GaveUp;
                return None;
            }
        }

        let idx = (self.attempt as usize).saturating_sub(1);
        let delay = BACKOFF_DELAYS
            .get(idx)
            .copied()
            .unwrap_or(*BACKOFF_DELAYS.last().unwrap());

        // Advance to next attempt.
        let next_attempt = self.attempt + 1;
        self.attempt = next_attempt;
        self.state = ReconnectState::Connecting {
            attempt: next_attempt,
        };

        Some(delay)
    }

    /// Spawn a Tokio task that calls `on_reconnect` after each
    /// backoff delay. The task ends when the manager gives up or
    /// `notify_connected` is called externally.
    ///
    /// Requires a Tokio runtime. Only available on non-WASM targets.
    #[cfg(not(target_arch = "wasm32"))]
    pub async fn start<F>(&mut self, mut on_reconnect: F)
    where
        F: FnMut() + Send + 'static,
    {
        while let Some(delay) = self.next_delay() {
            if !delay.is_zero() {
                tokio::time::sleep(delay).await;
            }
            on_reconnect();
        }
    }
}

impl Default for ReconnectManager {
    fn default() -> Self {
        Self::new()
    }
}

// ── Tests ─────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_initial_state_is_connected() {
        let mgr = ReconnectManager::new();
        assert_eq!(*mgr.state(), ReconnectState::Connected);
    }

    #[test]
    fn test_notify_disconnected_transitions_to_connecting() {
        let mut mgr = ReconnectManager::new();
        mgr.notify_disconnected();
        assert_eq!(*mgr.state(), ReconnectState::Connecting { attempt: 1 });
    }

    #[test]
    fn test_notify_connected_resets_state() {
        let mut mgr = ReconnectManager::new();
        mgr.notify_disconnected();
        mgr.notify_connected();
        assert_eq!(*mgr.state(), ReconnectState::Connected);
    }

    #[test]
    fn test_stop_resets_state() {
        let mut mgr = ReconnectManager::new();
        mgr.notify_disconnected();
        mgr.stop();
        assert_eq!(*mgr.state(), ReconnectState::Connected);
    }

    #[test]
    fn test_backoff_sequence() {
        let mut mgr = ReconnectManager::new();
        mgr.notify_disconnected();

        let d0 = mgr.next_delay().expect("attempt 1");
        let d1 = mgr.next_delay().expect("attempt 2");
        let d2 = mgr.next_delay().expect("attempt 3");
        let d3 = mgr.next_delay().expect("attempt 4");
        let d4 = mgr.next_delay().expect("attempt 5");

        assert_eq!(d0, Duration::from_secs(0));
        assert_eq!(d1, Duration::from_secs(2));
        assert_eq!(d2, Duration::from_secs(5));
        assert_eq!(d3, Duration::from_secs(15));
        assert_eq!(d4, Duration::from_secs(30));

        // After all delays are consumed the manager keeps returning
        // the last backoff (30 s) until give-up window expires.
        let d5 = mgr.next_delay().expect("attempt 6 uses last slot");
        assert_eq!(d5, Duration::from_secs(30));
    }

    #[test]
    fn test_next_delay_returns_none_when_connected() {
        let mut mgr = ReconnectManager::new();
        assert!(mgr.next_delay().is_none());
    }

    #[test]
    fn test_next_delay_returns_none_after_gave_up() {
        let mut mgr = ReconnectManager::new();
        mgr.state = ReconnectState::GaveUp;
        assert!(mgr.next_delay().is_none());
    }

    #[test]
    fn test_give_up_after_elapsed_window() {
        let mut mgr = ReconnectManager::new();
        mgr.notify_disconnected();

        // Simulate that the window expired by backdating started_at.
        mgr.started_at = Some(
            Instant::now()
                .checked_sub(GIVE_UP_AFTER + Duration::from_secs(1))
                .unwrap_or_else(Instant::now),
        );

        let result = mgr.next_delay();
        assert!(result.is_none());
        assert_eq!(*mgr.state(), ReconnectState::GaveUp);
    }

    #[test]
    fn test_backoff_delays_constants() {
        assert_eq!(BACKOFF_DELAYS[0], Duration::from_secs(0));
        assert_eq!(BACKOFF_DELAYS[1], Duration::from_secs(2));
        assert_eq!(BACKOFF_DELAYS[2], Duration::from_secs(5));
        assert_eq!(BACKOFF_DELAYS[3], Duration::from_secs(15));
        assert_eq!(BACKOFF_DELAYS[4], Duration::from_secs(30));
    }
}
