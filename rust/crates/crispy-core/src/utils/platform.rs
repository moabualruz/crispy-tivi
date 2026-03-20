//! Platform detection utilities.
//!
//! All detection is resolved at compile time via `#[cfg(target_os)]`
//! and `#[cfg(target_arch)]` — zero runtime overhead.

// ── Platform ──────────────────────────────────────────────────────────────────

/// The operating system / execution environment.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Platform {
    Windows,
    Linux,
    MacOS,
    Android,
    Ios,
    Web,
    Unknown,
}

/// Return the current platform, resolved at compile time.
pub const fn current_platform() -> Platform {
    #[cfg(target_os = "windows")]
    {
        return Platform::Windows;
    }
    #[cfg(target_os = "linux")]
    {
        return Platform::Linux;
    }
    #[cfg(target_os = "macos")]
    {
        return Platform::MacOS;
    }
    #[cfg(target_os = "android")]
    {
        return Platform::Android;
    }
    #[cfg(target_os = "ios")]
    {
        return Platform::Ios;
    }
    #[cfg(target_arch = "wasm32")]
    {
        return Platform::Web;
    }
    #[allow(unreachable_code)]
    Platform::Unknown
}

/// Return `true` when running on a desktop OS (Windows, Linux, macOS).
pub const fn is_desktop() -> bool {
    matches!(
        current_platform(),
        Platform::Windows | Platform::Linux | Platform::MacOS
    )
}

/// Return `true` when running on a mobile OS (Android, iOS).
pub const fn is_mobile() -> bool {
    matches!(current_platform(), Platform::Android | Platform::Ios)
}

/// Return `true` when running on a TV platform.
///
/// Android TV / Google TV share the Android target_os, so detection
/// requires a runtime check (not available here). This returns `false`
/// by default; the UI layer overrides it with a runtime capability flag
/// if the Android build detects `PackageManager.FEATURE_LEANBACK`.
pub const fn is_tv() -> bool {
    false
}

// ── FormFactor ────────────────────────────────────────────────────────────────

/// The physical form factor of the device.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum FormFactor {
    Desktop,
    Tablet,
    Phone,
    TV,
    Web,
}

/// Return the default form factor inferred from the platform.
///
/// Tablet vs Phone distinction requires runtime screen-size checks;
/// this returns `Phone` for mobile platforms as the safe default.
pub const fn default_form_factor() -> FormFactor {
    match current_platform() {
        Platform::Windows | Platform::Linux | Platform::MacOS => FormFactor::Desktop,
        Platform::Android | Platform::Ios => FormFactor::Phone,
        Platform::Web => FormFactor::Web,
        Platform::Unknown => FormFactor::Desktop,
    }
}

// ── Platform capabilities ─────────────────────────────────────────────────────

/// Whether Picture-in-Picture is natively supported on this platform.
pub const fn supports_pip() -> bool {
    matches!(
        current_platform(),
        Platform::Windows | Platform::MacOS | Platform::Android | Platform::Ios
    )
}

/// Whether background audio playback is supported on this platform.
pub const fn supports_background_audio() -> bool {
    matches!(
        current_platform(),
        Platform::Windows | Platform::Linux | Platform::MacOS | Platform::Android | Platform::Ios
    )
}

/// Whether local file downloads are supported on this platform.
pub const fn supports_downloads() -> bool {
    matches!(
        current_platform(),
        Platform::Windows | Platform::Linux | Platform::MacOS | Platform::Android | Platform::Ios
    )
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn current_platform_is_not_unknown_on_ci() {
        // On any supported CI host this should resolve to a known platform.
        let p = current_platform();
        assert_ne!(p, Platform::Unknown, "platform should be known on CI hosts");
    }

    #[test]
    fn desktop_and_mobile_are_mutually_exclusive() {
        // Cannot be both desktop and mobile at the same time.
        assert!(!(is_desktop() && is_mobile()));
    }

    #[test]
    fn is_tv_returns_false_at_compile_time() {
        assert!(!is_tv());
    }

    #[test]
    fn platform_equality() {
        assert_eq!(Platform::Windows, Platform::Windows);
        assert_ne!(Platform::Windows, Platform::Linux);
    }

    #[test]
    fn form_factor_equality() {
        assert_eq!(FormFactor::Desktop, FormFactor::Desktop);
        assert_ne!(FormFactor::Desktop, FormFactor::TV);
    }

    #[test]
    fn default_form_factor_is_consistent_with_platform() {
        let ff = default_form_factor();
        let p = current_platform();
        match p {
            Platform::Windows | Platform::Linux | Platform::MacOS => {
                assert_eq!(ff, FormFactor::Desktop);
            }
            Platform::Android | Platform::Ios => {
                assert_eq!(ff, FormFactor::Phone);
            }
            Platform::Web => {
                assert_eq!(ff, FormFactor::Web);
            }
            Platform::Unknown => {
                assert_eq!(ff, FormFactor::Desktop);
            }
        }
    }

    #[test]
    fn supports_pip_is_bool() {
        let _ = supports_pip();
    }

    #[test]
    fn supports_background_audio_is_bool() {
        let _ = supports_background_audio();
    }

    #[test]
    fn supports_downloads_is_bool() {
        let _ = supports_downloads();
    }

    #[cfg(target_os = "windows")]
    #[test]
    fn windows_is_desktop() {
        assert!(is_desktop());
        assert!(!is_mobile());
        assert!(supports_pip());
        assert!(supports_background_audio());
        assert!(supports_downloads());
    }

    #[cfg(target_os = "linux")]
    #[test]
    fn linux_is_desktop() {
        assert!(is_desktop());
        assert!(!is_mobile());
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn macos_is_desktop() {
        assert!(is_desktop());
        assert!(!is_mobile());
        assert!(supports_pip());
    }
}
