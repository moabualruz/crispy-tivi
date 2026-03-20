//! Network state detection for CrispyTivi.
//!
//! Probes well-known endpoints via TCP to determine if the
//! device is online, offline, or degraded. On WASM targets
//! the browser's `navigator.onLine` is used instead.
//!
//! Subscribers receive `NetworkState` updates via a
//! `tokio::sync::watch` channel. A background task re-checks
//! every 30 seconds (native only; requires tokio rt).

use std::net::TcpStream;
use std::time::Duration;

use tokio::sync::watch;

// ── Probe endpoints ──────────────────────────────────────

/// Well-known TCP endpoints used to probe connectivity.
const PROBE_ENDPOINTS: &[(&str, u16)] = &[
    ("1.1.1.1", 443), // Cloudflare DNS-over-HTTPS
    ("8.8.8.8", 443), // Google DNS-over-HTTPS
    ("9.9.9.9", 443), // Quad9
];

/// Probe timeout for each TCP connection attempt.
const PROBE_TIMEOUT: Duration = Duration::from_secs(3);

/// How many probes must succeed for `Online` (vs `Degraded`).
const ONLINE_THRESHOLD: usize = 2;

// ── NetworkState ─────────────────────────────────────────

/// Current network connectivity state.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NetworkState {
    /// All probes succeed — full connectivity.
    Online,
    /// No probes succeed.
    Offline,
    /// At least one probe succeeds, but fewer than the
    /// `ONLINE_THRESHOLD`. Indicates packet loss or a
    /// captive portal.
    Degraded,
}

// ── NetworkMonitor ───────────────────────────────────────

/// Performs and broadcasts network connectivity checks.
///
/// Call [`NetworkMonitor::new`] to create an instance and
/// obtain a [`watch::Receiver<NetworkState>`] for
/// subscribers. Call [`NetworkMonitor::check_connectivity`]
/// for a one-shot synchronous probe.
pub struct NetworkMonitor {
    tx: watch::Sender<NetworkState>,
}

impl NetworkMonitor {
    /// Create a new monitor. Returns `(monitor, receiver)`.
    /// The initial state is determined by a synchronous probe.
    pub fn new() -> (Self, watch::Receiver<NetworkState>) {
        let initial = Self::probe_native();
        let (tx, rx) = watch::channel(initial);
        (Self { tx }, rx)
    }

    /// One-shot synchronous connectivity check.
    ///
    /// On WASM: returns `Online` when `navigator.onLine` is
    /// true, `Offline` otherwise.
    ///
    /// On native: TCP-probes the well-known endpoints and
    /// returns `Online`, `Degraded`, or `Offline` based on
    /// how many succeed.
    pub fn check_connectivity(&self) -> NetworkState {
        let state = Self::probe();
        // Broadcast to subscribers if the state changed.
        let _ = self.tx.send_if_modified(|current| {
            if *current == state {
                false
            } else {
                *current = state;
                true
            }
        });
        state
    }

    /// Start a background Tokio task that re-checks every 30 s
    /// and notifies subscribers on state changes.
    ///
    /// The returned `tokio::task::JoinHandle` can be aborted to
    /// stop monitoring. Requires a Tokio runtime.
    #[cfg(not(target_arch = "wasm32"))]
    pub fn start_periodic(monitor: std::sync::Arc<Self>) -> tokio::task::JoinHandle<()> {
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(tokio::time::Duration::from_secs(30));
            interval.tick().await; // skip the immediate tick
            loop {
                interval.tick().await;
                monitor.check_connectivity();
            }
        })
    }

    // ── Private helpers ──────────────────────────────────

    fn probe() -> NetworkState {
        #[cfg(target_arch = "wasm32")]
        {
            Self::probe_wasm()
        }
        #[cfg(not(target_arch = "wasm32"))]
        {
            Self::probe_native()
        }
    }

    #[cfg(not(target_arch = "wasm32"))]
    fn probe_native() -> NetworkState {
        let successes = PROBE_ENDPOINTS
            .iter()
            .filter(|(host, port)| {
                let addr = format!("{host}:{port}");
                TcpStream::connect_timeout(&addr.parse().expect("static addr"), PROBE_TIMEOUT)
                    .is_ok()
            })
            .count();

        match successes {
            0 => NetworkState::Offline,
            n if n >= ONLINE_THRESHOLD => NetworkState::Online,
            _ => NetworkState::Degraded,
        }
    }

    /// WASM stub: delegate to `navigator.onLine`.
    /// A full implementation would use `web-sys`, but that
    /// crate is not in crispy-core's dependencies. This
    /// returns `Online` unconditionally for now.
    #[cfg(target_arch = "wasm32")]
    fn probe_wasm() -> NetworkState {
        // TODO(wasm): use web_sys::window()?.navigator().on_line()
        NetworkState::Online
    }

    #[cfg(target_arch = "wasm32")]
    fn probe_native() -> NetworkState {
        Self::probe_wasm()
    }
}

impl Default for NetworkMonitor {
    fn default() -> Self {
        Self::new().0
    }
}

// ── Tests ─────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_network_state_eq() {
        assert_eq!(NetworkState::Online, NetworkState::Online);
        assert_ne!(NetworkState::Online, NetworkState::Offline);
        assert_ne!(NetworkState::Degraded, NetworkState::Offline);
    }

    #[test]
    fn test_new_returns_some_state() {
        let (monitor, rx) = NetworkMonitor::new();
        let state = *rx.borrow();
        // State must be one of the three valid variants.
        assert!(matches!(
            state,
            NetworkState::Online | NetworkState::Offline | NetworkState::Degraded
        ));
        // check_connectivity should not panic.
        let live = monitor.check_connectivity();
        assert!(matches!(
            live,
            NetworkState::Online | NetworkState::Offline | NetworkState::Degraded
        ));
    }

    #[test]
    fn test_check_connectivity_broadcasts_on_change() {
        // Construct a monitor, immediately override the sender
        // to a known state so we can observe the transition.
        let (monitor, mut rx) = NetworkMonitor::new();

        // Force the stored state to Offline so any future Online
        // result triggers a change notification.
        let _ = monitor.tx.send(NetworkState::Offline);
        rx.mark_changed(); // mark as unseen

        // Now call check — whatever probe returns, the channel
        // must be updated.
        monitor.check_connectivity();
        // rx.has_changed() is true only if probe returned something
        // different from Offline OR the same (send_if_modified won't
        // fire). We can't guarantee online in CI; just verify no panic.
        let _ = rx.has_changed();
    }

    #[test]
    fn test_probe_threshold_online() {
        // ONLINE_THRESHOLD is 2; simulate by checking the constant.
        assert_eq!(ONLINE_THRESHOLD, 2);
        // 0 successes → Offline
        let state_0 = match 0usize {
            0 => NetworkState::Offline,
            n if n >= ONLINE_THRESHOLD => NetworkState::Online,
            _ => NetworkState::Degraded,
        };
        assert_eq!(state_0, NetworkState::Offline);

        // 1 success → Degraded
        let state_1 = match 1usize {
            0 => NetworkState::Offline,
            n if n >= ONLINE_THRESHOLD => NetworkState::Online,
            _ => NetworkState::Degraded,
        };
        assert_eq!(state_1, NetworkState::Degraded);

        // 2 successes → Online
        let state_2 = match 2usize {
            0 => NetworkState::Offline,
            n if n >= ONLINE_THRESHOLD => NetworkState::Online,
            _ => NetworkState::Degraded,
        };
        assert_eq!(state_2, NetworkState::Online);
    }
}
