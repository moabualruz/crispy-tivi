//! FFI wrappers for app update checking.
//!
//! Exposes version check and platform asset URL matching
//! to Flutter via FRB.

use anyhow::Result;

/// Check for a newer app version via GitHub Releases API.
///
/// Returns JSON with `has_update`, `latest_version`, `changelog`,
/// `download_url`, `published_at`, `assets_json`, and optional `error`.
pub async fn check_for_update(current_version: String, repo_url: String) -> Result<String> {
    crispy_core::services::app_update::check_for_update(&current_version, &repo_url).await
}

/// Find a platform-specific download URL from release assets JSON.
///
/// `platform`: `android`, `windows`, `linux`, `macos`.
/// Returns the first matching asset URL, or `None`.
#[flutter_rust_bridge::frb(sync)]
pub fn get_platform_asset_url(assets_json: String, platform: String) -> Option<String> {
    crispy_core::services::app_update::get_platform_asset_url(&assets_json, &platform)
}
