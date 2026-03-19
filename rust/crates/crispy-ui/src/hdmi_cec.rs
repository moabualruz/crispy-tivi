//! HDMI-CEC integration — Linux only, behind `#[cfg(target_os = "linux")]`.
//!
//! On non-Linux platforms all public methods are no-ops that return `Ok(())`.
//! This allows the rest of the codebase to call `CecService` unconditionally
//! without any `#[cfg]` guards at call sites.
//!
//! The real implementation requires the `cec_linux` crate and will be wired
//! in a future task. This module provides the complete abstraction boundary.

use thiserror::Error;

// ── Error ──────────────────────────────────────────────────────────────────

/// Errors that can occur when initialising or communicating with HDMI-CEC.
#[derive(Debug, Error)]
pub(crate) enum CecError {
    /// The CEC adapter could not be opened.
    #[error("failed to open CEC adapter: {0}")]
    AdapterOpen(String),

    /// A CEC command could not be sent.
    #[error("failed to send CEC command: {0}")]
    Send(String),

    /// CEC is not supported on this platform.
    #[error("HDMI-CEC is not supported on this platform")]
    Unsupported,
}

// ── Command vocabulary ─────────────────────────────────────────────────────

/// Logical CEC commands received from the TV or AV receiver.
///
/// Maps directly to the CEC User Control codes defined in the HDMI
/// specification (CEC Table 30 / IEC 62455).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum CecCommand {
    // Playback
    Play,
    Pause,
    Stop,
    // Volume
    VolumeUp,
    VolumeDown,
    Mute,
    // Channel navigation
    ChannelUp,
    ChannelDown,
    // D-Pad
    Select,
    Back,
    Up,
    Down,
    Left,
    Right,
    // Color buttons
    Red,
    Green,
    Yellow,
    Blue,
    // Power
    PowerOn,
    Standby,
}

// ── Handler trait ──────────────────────────────────────────────────────────

/// Receiver of decoded CEC commands.
///
/// Implementations are expected to translate CEC commands into `InputAction`
/// events and forward them to the `InputManager`.
pub(crate) trait CecHandler: Send + Sync {
    /// Called for each decoded CEC command received from the adapter.
    fn on_cec_command(&self, command: CecCommand);
}

// ── Service ────────────────────────────────────────────────────────────────

/// HDMI-CEC service that listens for remote-control commands sent over HDMI.
///
/// Create with [`CecService::new`], then call [`CecService::start`] to begin
/// listening. On platforms where CEC is unavailable [`start`] returns `Ok(())`
/// immediately without performing any I/O.
pub(crate) struct CecService {
    enabled: bool,
}

impl CecService {
    /// Create a new, stopped `CecService`.
    pub(crate) fn new() -> Self {
        Self { enabled: false }
    }

    /// Return `true` when HDMI-CEC is potentially available on this platform.
    ///
    /// Availability is determined at compile time: `true` on Linux,
    /// `false` everywhere else.
    pub(crate) fn is_available() -> bool {
        cfg!(target_os = "linux")
    }

    /// Start listening for CEC commands and dispatch them to `handler`.
    ///
    /// # Linux
    ///
    /// Will delegate to the `cec_linux` crate when that integration is wired.
    /// For now, logs that the real CEC driver is not yet compiled in and
    /// returns `Ok(())`.
    ///
    /// # Other platforms
    ///
    /// Always returns `Ok(())` without performing any I/O.
    #[cfg(target_os = "linux")]
    pub(crate) fn start(&mut self, _handler: Box<dyn CecHandler>) -> Result<(), CecError> {
        tracing::info!(
            "HDMI-CEC support not yet compiled — \
             requires cec_linux crate to be wired in a future task"
        );
        self.enabled = true;
        Ok(())
    }

    /// No-op on non-Linux platforms.
    #[cfg(not(target_os = "linux"))]
    pub(crate) fn start(&mut self, _handler: Box<dyn CecHandler>) -> Result<(), CecError> {
        tracing::debug!("HDMI-CEC not available on this platform (non-Linux)");
        Ok(())
    }

    /// Stop listening for CEC commands.
    pub(crate) fn stop(&mut self) {
        self.enabled = false;
        tracing::debug!("HDMI-CEC stopped");
    }

    /// Return `true` when the service is actively listening.
    pub(crate) fn is_enabled(&self) -> bool {
        self.enabled
    }
}

impl Default for CecService {
    fn default() -> Self {
        Self::new()
    }
}

// ── Tests ──────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    /// Minimal no-op handler for test purposes.
    struct NoopHandler;
    impl CecHandler for NoopHandler {
        fn on_cec_command(&self, _command: CecCommand) {}
    }

    #[test]
    fn test_cec_service_new_creates_disabled() {
        let svc = CecService::new();
        assert!(!svc.is_enabled(), "new CecService must not be enabled");
    }

    #[test]
    fn test_is_available_returns_platform_correct() {
        // On Linux this must be true; on everything else false.
        // We compile-time assert so the test is always meaningful.
        #[cfg(target_os = "linux")]
        assert!(CecService::is_available());
        #[cfg(not(target_os = "linux"))]
        assert!(!CecService::is_available());
    }

    #[test]
    fn test_start_succeeds_on_any_platform() {
        let mut svc = CecService::new();
        let result = svc.start(Box::new(NoopHandler));
        assert!(
            result.is_ok(),
            "start() must not return an error: {result:?}"
        );
    }

    #[test]
    fn test_stop_disables() {
        let mut svc = CecService::new();
        // start() first so there is something to stop
        let _ = svc.start(Box::new(NoopHandler));
        svc.stop();
        assert!(!svc.is_enabled(), "stop() must mark service as disabled");
    }

    #[test]
    fn test_cec_command_equality() {
        assert_eq!(CecCommand::Play, CecCommand::Play);
        assert_ne!(CecCommand::Play, CecCommand::Pause);
    }

    #[test]
    fn test_cec_error_display_adapter_open() {
        let e = CecError::AdapterOpen("no device".to_string());
        assert!(e.to_string().contains("no device"));
    }

    #[test]
    fn test_cec_error_display_unsupported() {
        let e = CecError::Unsupported;
        assert!(e.to_string().contains("not supported"));
    }

    #[test]
    fn test_default_creates_disabled_service() {
        let svc = CecService::default();
        assert!(!svc.is_enabled());
    }
}
