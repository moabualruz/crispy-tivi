//! Application metadata and store URL helpers.
//!
//! `AppMetadata` is populated from compile-time environment variables
//! and Cargo manifest constants. Use `get_app_metadata()` to obtain
//! a snapshot at runtime.

use crate::utils::platform::{Platform, current_platform};

// Cargo injects these at compile time.
const CARGO_PKG_VERSION: &str = env!("CARGO_PKG_VERSION");
const CARGO_PKG_NAME: &str = env!("CARGO_PKG_NAME");

// Optional build-time overrides injected via build.rs or CI.
// Fall back to sensible defaults when absent.
const BUILD_NUMBER: &str = match option_env!("CRISPY_BUILD_NUMBER") {
    Some(v) => v,
    None => "0",
};
const PACKAGE_ID: &str = match option_env!("CRISPY_PACKAGE_ID") {
    Some(v) => v,
    None => "com.crispytivi.app",
};

/// Snapshot of application identity metadata.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AppMetadata {
    pub name: String,
    pub version: String,
    pub build_number: String,
    pub platform: Platform,
    pub package_id: String,
}

/// Return the current application metadata, resolved at compile time.
pub fn get_app_metadata() -> AppMetadata {
    AppMetadata {
        name: CARGO_PKG_NAME.to_string(),
        version: CARGO_PKG_VERSION.to_string(),
        build_number: BUILD_NUMBER.to_string(),
        platform: current_platform(),
        package_id: PACKAGE_ID.to_string(),
    }
}

/// Return the platform-appropriate store URL, if applicable.
///
/// Returns `None` for platforms that have no public store listing
/// (Linux desktop, Web, Unknown).
pub fn get_store_url() -> Option<String> {
    match current_platform() {
        Platform::Windows => {
            Some("https://apps.microsoft.com/store/detail/crispytivi/PLACEHOLDER".to_string())
        }
        Platform::MacOS => Some("https://apps.apple.com/app/crispytivi/PLACEHOLDER".to_string()),
        Platform::Android => {
            Some("https://play.google.com/store/apps/details?id=com.crispytivi.app".to_string())
        }
        Platform::Ios => Some("https://apps.apple.com/app/crispytivi/PLACEHOLDER".to_string()),
        Platform::Linux | Platform::Web | Platform::Unknown => None,
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn get_app_metadata_returns_non_empty_version() {
        let meta = get_app_metadata();
        assert!(!meta.version.is_empty(), "version should not be empty");
    }

    #[test]
    fn get_app_metadata_name_is_crispy_core() {
        let meta = get_app_metadata();
        assert_eq!(meta.name, "crispy-core");
    }

    #[test]
    fn get_app_metadata_package_id_is_set() {
        let meta = get_app_metadata();
        assert!(!meta.package_id.is_empty());
    }

    #[test]
    fn get_app_metadata_build_number_is_set() {
        let meta = get_app_metadata();
        assert!(!meta.build_number.is_empty());
    }

    #[test]
    fn get_app_metadata_platform_matches_current() {
        let meta = get_app_metadata();
        assert_eq!(meta.platform, current_platform());
    }

    #[test]
    fn get_store_url_returns_option() {
        // Just verify it doesn't panic and returns Some or None.
        let _ = get_store_url();
    }

    #[cfg(target_os = "windows")]
    #[test]
    fn windows_store_url_is_microsoft_store() {
        let url = get_store_url().expect("Windows should have a store URL");
        assert!(
            url.contains("microsoft.com"),
            "expected Microsoft Store URL"
        );
    }

    #[cfg(target_os = "linux")]
    #[test]
    fn linux_has_no_store_url() {
        assert!(get_store_url().is_none());
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn macos_store_url_is_app_store() {
        let url = get_store_url().expect("macOS should have a store URL");
        assert!(url.contains("apple.com"));
    }

    #[test]
    fn app_metadata_equality() {
        let a = get_app_metadata();
        let b = get_app_metadata();
        assert_eq!(a, b);
    }
}
