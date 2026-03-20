//! Audio output device abstraction.
//!
//! Allows listing, querying, and switching audio output devices.
//! `StubAudioOutput` is used when the platform provides no device API.

use crate::errors::CrispyError;

/// An audio output device available on the system.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AudioDevice {
    pub id: String,
    pub name: String,
    pub is_default: bool,
}

/// Platform audio-output service.
pub trait AudioOutputService: Send + Sync {
    /// Return all available audio output devices.
    fn list_devices(&self) -> Vec<AudioDevice>;

    /// Return the currently active device, if any.
    fn get_current(&self) -> Option<AudioDevice>;

    /// Switch output to the device with the given `id`.
    fn set_device(&self, id: &str) -> Result<(), CrispyError>;

    /// Register a callback invoked when the device list changes.
    fn on_device_change(&self, callback: Box<dyn Fn() + Send + Sync>);
}

// ── Stub impl ────────────────────────────────────────────────────────────────

/// Stub implementation used on unsupported platforms.
///
/// Returns an empty device list and ignores all mutations.
#[derive(Debug, Default)]
pub struct StubAudioOutput;

impl AudioOutputService for StubAudioOutput {
    fn list_devices(&self) -> Vec<AudioDevice> {
        vec![]
    }

    fn get_current(&self) -> Option<AudioDevice> {
        None
    }

    fn set_device(&self, _id: &str) -> Result<(), CrispyError> {
        Ok(())
    }

    fn on_device_change(&self, _callback: Box<dyn Fn() + Send + Sync>) {}
}

// ── Tests ────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn audio_device_fields() {
        let dev = AudioDevice {
            id: "dev-1".to_string(),
            name: "Speakers".to_string(),
            is_default: true,
        };
        assert_eq!(dev.id, "dev-1");
        assert_eq!(dev.name, "Speakers");
        assert!(dev.is_default);
    }

    #[test]
    fn audio_device_equality() {
        let a = AudioDevice {
            id: "x".to_string(),
            name: "A".to_string(),
            is_default: false,
        };
        let b = a.clone();
        assert_eq!(a, b);
    }

    #[test]
    fn stub_list_devices_returns_empty() {
        let svc = StubAudioOutput;
        assert!(svc.list_devices().is_empty());
    }

    #[test]
    fn stub_get_current_returns_none() {
        let svc = StubAudioOutput;
        assert!(svc.get_current().is_none());
    }

    #[test]
    fn stub_set_device_returns_ok() {
        let svc = StubAudioOutput;
        assert!(svc.set_device("any-id").is_ok());
    }

    #[test]
    fn stub_on_device_change_does_not_panic() {
        let svc = StubAudioOutput;
        svc.on_device_change(Box::new(|| {}));
    }

    // ── Edge-case / spec-coverage tests ──────────────────────────────────────

    #[test]
    fn audio_device_non_default_flag() {
        let dev = AudioDevice {
            id: "dev-2".to_string(),
            name: "Headphones".to_string(),
            is_default: false,
        };
        assert!(!dev.is_default);
    }

    #[test]
    fn stub_set_device_empty_id_returns_ok() {
        // The stub must accept any id including empty string without error.
        let svc = StubAudioOutput;
        assert!(svc.set_device("").is_ok());
    }

    #[test]
    fn stub_set_device_unknown_id_returns_ok() {
        // Stub is a no-op: unknown ids are silently accepted.
        let svc = StubAudioOutput;
        assert!(svc.set_device("nonexistent-device-id").is_ok());
    }

    #[test]
    fn audio_device_inequality() {
        let a = AudioDevice {
            id: "a".to_string(),
            name: "A".to_string(),
            is_default: true,
        };
        let b = AudioDevice {
            id: "b".to_string(),
            name: "B".to_string(),
            is_default: false,
        };
        assert_ne!(a, b);
    }
}
