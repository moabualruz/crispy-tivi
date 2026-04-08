//! App update checking via GitHub Releases API.
//!
//! Standalone async functions (no `CrispyService` dependency)
//! that fetch the latest release, compare versions using semver,
//! and extract platform-specific asset URLs.

use anyhow::Result;
use serde::{Deserialize, Serialize};

use crate::http_client::fast_client;

/// Result of checking for a newer app version.
#[derive(Debug, Serialize)]
pub struct UpdateCheckResult {
    pub has_update: bool,
    pub latest_version: String,
    pub download_url: String,
    pub changelog: String,
    pub published_at: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
    /// JSON array of release assets for platform-specific download.
    pub assets_json: String,
}

/// GitHub Release API response (partial).
#[derive(Debug, Deserialize)]
struct GitHubRelease {
    tag_name: String,
    body: Option<String>,
    html_url: Option<String>,
    published_at: Option<String>,
    assets: Vec<GitHubAsset>,
}

/// A single release asset from GitHub API.
#[derive(Debug, Deserialize, Serialize)]
struct GitHubAsset {
    name: String,
    browser_download_url: String,
}

/// Check for a newer app version via the GitHub Releases API.
///
/// Fetches the latest release from `repo_url` (either `owner/repo`
/// or a full GitHub URL), compares the tag version against
/// `current_version` using semver, and returns a JSON-serialized
/// [`UpdateCheckResult`].
///
/// On network or API errors, returns a result with
/// `has_update: false` and the error message — never panics.
pub async fn check_for_update(current_version: &str, repo_url: &str) -> Result<String> {
    let repo = extract_repo(repo_url);
    let api_url = format!("https://api.github.com/repos/{repo}/releases/latest");

    let client = fast_client();
    let response = match client
        .get(&api_url)
        .header("Accept", "application/vnd.github.v3+json")
        .send()
        .await
    {
        Ok(resp) => resp,
        Err(e) => return error_result(&format!("Network error: {e}")),
    };

    if !response.status().is_success() {
        return error_result(&format!("HTTP {}", response.status()));
    }

    let release: GitHubRelease = match response.json().await {
        Ok(r) => r,
        Err(e) => return error_result(&format!("Parse error: {e}")),
    };

    let tag = &release.tag_name;
    let version_str = tag.strip_prefix('v').unwrap_or(tag);

    let has_update = match (
        semver::Version::parse(version_str),
        semver::Version::parse(current_version),
    ) {
        (Ok(latest), Ok(current)) => latest > current,
        _ => false,
    };

    let assets_json = serde_json::to_string(&release.assets).unwrap_or_else(|_| "[]".to_string());

    Ok(serde_json::to_string(&UpdateCheckResult {
        has_update,
        latest_version: version_str.to_string(),
        download_url: release.html_url.unwrap_or_default(),
        changelog: release.body.unwrap_or_default(),
        published_at: release.published_at.unwrap_or_default(),
        error: None,
        assets_json,
    })?)
}

/// Find a platform-specific download URL from a JSON array of
/// GitHub release assets.
///
/// `platform` should be one of: `android`, `windows`, `linux`,
/// `macos`. Returns the first matching asset's download URL.
pub fn get_platform_asset_url(assets_json: &str, platform: &str) -> Option<String> {
    let assets: Vec<GitHubAsset> = serde_json::from_str(assets_json).ok()?;

    let extensions: &[&str] = match platform {
        "android" => &[".apk"],
        "windows" => &[".msix", ".exe"],
        "linux" => &[".deb", ".appimage", ".tar.gz"],
        "macos" => &[".dmg"],
        _ => return None,
    };

    for asset in &assets {
        let name = asset.name.to_lowercase();
        for ext in extensions {
            if name.ends_with(ext) {
                return Some(asset.browser_download_url.clone());
            }
        }
    }
    None
}

/// Extract `owner/repo` from a GitHub URL or pass through as-is.
fn extract_repo(repo_url: &str) -> String {
    if let Some(rest) = repo_url
        .strip_prefix("https://github.com/")
        .or_else(|| repo_url.strip_prefix("http://github.com/"))
    {
        return rest.trim_end_matches('/').to_string();
    }
    repo_url.to_string()
}

/// Build a JSON result with `has_update: false` and an error message.
fn error_result(msg: &str) -> Result<String> {
    Ok(serde_json::to_string(&UpdateCheckResult {
        has_update: false,
        latest_version: String::new(),
        download_url: String::new(),
        changelog: String::new(),
        published_at: String::new(),
        error: Some(msg.to_string()),
        assets_json: String::new(),
    })?)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extract_repo_from_full_url() {
        assert_eq!(extract_repo("https://github.com/user/repo"), "user/repo");
    }

    #[test]
    fn extract_repo_trailing_slash() {
        assert_eq!(extract_repo("https://github.com/user/repo/"), "user/repo");
    }

    #[test]
    fn extract_repo_http() {
        assert_eq!(extract_repo("http://github.com/user/repo"), "user/repo");
    }

    #[test]
    fn extract_repo_short_form() {
        assert_eq!(extract_repo("user/repo"), "user/repo");
    }

    #[test]
    fn platform_asset_android() {
        let assets = r#"[
            {"name": "app-release.apk", "browser_download_url": "https://dl.example.com/app.apk"},
            {"name": "app-setup.exe", "browser_download_url": "https://dl.example.com/app.exe"}
        ]"#;
        assert_eq!(
            get_platform_asset_url(assets, "android"),
            Some("https://dl.example.com/app.apk".to_string()),
        );
    }

    #[test]
    fn platform_asset_windows_exe() {
        let assets = r#"[
            {"name": "CrispyTivi-Setup.exe", "browser_download_url": "https://dl.example.com/setup.exe"}
        ]"#;
        assert_eq!(
            get_platform_asset_url(assets, "windows"),
            Some("https://dl.example.com/setup.exe".to_string()),
        );
    }

    #[test]
    fn platform_asset_windows_msix_preferred() {
        let assets = r#"[
            {"name": "CrispyTivi.msix", "browser_download_url": "https://dl.example.com/app.msix"},
            {"name": "CrispyTivi-Setup.exe", "browser_download_url": "https://dl.example.com/setup.exe"}
        ]"#;
        assert_eq!(
            get_platform_asset_url(assets, "windows"),
            Some("https://dl.example.com/app.msix".to_string()),
        );
    }

    #[test]
    fn platform_asset_linux() {
        let assets = r#"[
            {"name": "crispy-tivi_0.2.0_amd64.deb", "browser_download_url": "https://dl.example.com/app.deb"}
        ]"#;
        assert_eq!(
            get_platform_asset_url(assets, "linux"),
            Some("https://dl.example.com/app.deb".to_string()),
        );
    }

    #[test]
    fn platform_asset_macos() {
        let assets = r#"[
            {"name": "CrispyTivi-0.2.0.dmg", "browser_download_url": "https://dl.example.com/app.dmg"}
        ]"#;
        assert_eq!(
            get_platform_asset_url(assets, "macos"),
            Some("https://dl.example.com/app.dmg".to_string()),
        );
    }

    #[test]
    fn platform_asset_unknown_platform() {
        let assets =
            r#"[{"name": "app.apk", "browser_download_url": "https://dl.example.com/app.apk"}]"#;
        assert_eq!(get_platform_asset_url(assets, "ios"), None);
    }

    #[test]
    fn platform_asset_no_match() {
        let assets =
            r#"[{"name": "source.zip", "browser_download_url": "https://dl.example.com/src.zip"}]"#;
        assert_eq!(get_platform_asset_url(assets, "android"), None);
    }

    #[test]
    fn platform_asset_invalid_json() {
        assert_eq!(get_platform_asset_url("not json", "android"), None);
    }

    #[test]
    fn platform_asset_empty_array() {
        assert_eq!(get_platform_asset_url("[]", "android"), None);
    }

    #[test]
    fn semver_older_has_update() {
        let current = semver::Version::parse("0.1.0").unwrap();
        let latest = semver::Version::parse("0.2.0").unwrap();
        assert!(latest > current);
    }

    #[test]
    fn semver_same_no_update() {
        let current = semver::Version::parse("0.1.1").unwrap();
        let latest = semver::Version::parse("0.1.1").unwrap();
        assert!(latest <= current);
    }

    #[test]
    fn semver_newer_no_update() {
        let current = semver::Version::parse("0.3.0").unwrap();
        let latest = semver::Version::parse("0.2.0").unwrap();
        assert!(latest <= current);
    }

    #[test]
    fn semver_patch_update() {
        let current = semver::Version::parse("0.1.0").unwrap();
        let latest = semver::Version::parse("0.1.1").unwrap();
        assert!(latest > current);
    }

    #[test]
    fn v_prefix_stripped() {
        let tag = "v0.2.0";
        let version = tag.strip_prefix('v').unwrap_or(tag);
        assert_eq!(version, "0.2.0");
        assert!(semver::Version::parse(version).is_ok());
    }

    #[test]
    fn no_v_prefix_works() {
        let tag = "0.2.0";
        let version = tag.strip_prefix('v').unwrap_or(tag);
        assert_eq!(version, "0.2.0");
    }

    #[test]
    fn error_result_format() {
        let result = error_result("test error").unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert!(!parsed["has_update"].as_bool().unwrap());
        assert_eq!(parsed["error"], "test error");
        assert_eq!(parsed["latest_version"], "");
    }

    #[test]
    fn invalid_semver_no_update() {
        let current = "not-a-version";
        let latest = "also-not-a-version";
        let has_update = match (
            semver::Version::parse(latest),
            semver::Version::parse(current),
        ) {
            (Ok(l), Ok(c)) => l > c,
            _ => false,
        };
        assert!(!has_update);
    }
}
