//! Update checker — polls GitHub Releases API once per 24 h.
//!
//! - Non-blocking: `spawn_background_check` fires a tokio task.
//! - "Skip this version" tracked in-memory (callers should persist
//!   the skipped version to settings for cross-restart persistence).
//! - Forced update: minimum version gate via `min_version` in
//!   `UpdateInfo`.
//! - Interval is configurable; defaults to 24 h.

use std::{
    sync::{Arc, Mutex},
    time::{Duration, Instant},
};

use serde::{Deserialize, Serialize};

use crate::http_client::fast_client;

// ── UpdateInfo ────────────────────────────────────────────────────────────────

/// Information about an available app update.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateInfo {
    /// New version string (without `v` prefix).
    pub version: String,
    /// Release notes / changelog text.
    pub changelog: String,
    /// Platform-agnostic download page URL.
    pub download_url: String,
    /// If `true`, the app must update before continuing.
    pub is_forced: bool,
}

// ── GitHub release DTOs ───────────────────────────────────────────────────────

#[derive(Debug, Deserialize)]
struct GhRelease {
    tag_name: String,
    body: Option<String>,
    html_url: Option<String>,
}

// ── UpdateChecker ─────────────────────────────────────────────────────────────

/// Check for app updates from a GitHub Releases API endpoint.
///
/// Caches results for `check_interval` (default 24 h) and
/// supports "skip this version" tracking.
#[derive(Clone)]
pub struct UpdateChecker {
    inner: Arc<Mutex<CheckerInner>>,
}

struct CheckerInner {
    repo: String,
    current_version: String,
    /// Minimum required version (forced update gate).
    min_version: Option<semver::Version>,
    check_interval: Duration,
    last_checked: Option<Instant>,
    last_result: Option<UpdateInfo>,
    skipped_version: Option<String>,
}

impl UpdateChecker {
    /// Create an update checker for `owner/repo` with the running
    /// `current_version` and a configurable polling interval.
    pub fn new(
        repo: impl Into<String>,
        current_version: impl Into<String>,
        interval: Duration,
    ) -> Self {
        Self {
            inner: Arc::new(Mutex::new(CheckerInner {
                repo: repo.into(),
                current_version: current_version.into(),
                min_version: None,
                check_interval: interval,
                last_checked: None,
                last_result: None,
                skipped_version: None,
            })),
        }
    }

    /// Create with a default 24-hour polling interval.
    pub fn with_defaults(repo: impl Into<String>, current_version: impl Into<String>) -> Self {
        Self::new(repo, current_version, Duration::from_secs(86_400))
    }

    /// Set the minimum required version (forces update if current < min).
    pub fn set_min_version(&self, version: &str) {
        let mut g = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        g.min_version = semver::Version::parse(version).ok();
    }

    // ── Skip tracking ────────────────────────────────────────────────────────

    /// Mark a version as skipped (user chose "remind me later").
    pub fn skip_version(&self, version: impl Into<String>) {
        self.inner
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .skipped_version = Some(version.into());
    }

    /// Clear any previously skipped version.
    pub fn clear_skipped(&self) {
        self.inner
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .skipped_version = None;
    }

    /// Returns the currently skipped version string, if any.
    pub fn skipped_version(&self) -> Option<String> {
        self.inner
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .skipped_version
            .clone()
    }

    // ── Polling ──────────────────────────────────────────────────────────────

    /// Check if the polling interval has elapsed.
    pub fn should_check(&self) -> bool {
        let g = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        match g.last_checked {
            None => true,
            Some(t) => t.elapsed() >= g.check_interval,
        }
    }

    /// Fetch the latest release from GitHub and return `Some(UpdateInfo)`
    /// when a newer version exists and it has not been skipped.
    ///
    /// Returns `None` when up to date, skipped, or on any error.
    /// Always non-panicking.
    pub async fn check_for_update(&self) -> Option<UpdateInfo> {
        let (repo, current_version, min_version) = {
            let g = self.inner.lock().unwrap_or_else(|e| e.into_inner());
            (
                g.repo.clone(),
                g.current_version.clone(),
                g.min_version.clone(),
            )
        };

        let api_url = format!("https://api.github.com/repos/{repo}/releases/latest");
        let response = fast_client()
            .get(&api_url)
            .header("Accept", "application/vnd.github.v3+json")
            .send()
            .await
            .ok()?;

        if !response.status().is_success() {
            return None;
        }

        let release: GhRelease = response.json().await.ok()?;

        let tag = &release.tag_name;
        let version_str = tag.strip_prefix('v').unwrap_or(tag).to_string();

        let current = semver::Version::parse(&current_version).ok()?;
        let latest = semver::Version::parse(&version_str).ok()?;

        // Forced update check: current < min_version.
        let is_forced = min_version
            .as_ref()
            .map(|min| current < *min)
            .unwrap_or(false);

        if latest <= current && !is_forced {
            self.record_checked(None);
            return None;
        }

        // Check if user skipped this version (forced updates always show).
        let skipped = self
            .inner
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .skipped_version
            .clone();

        if !is_forced {
            if let Some(skip) = &skipped {
                if *skip == version_str {
                    self.record_checked(None);
                    return None;
                }
            }
        }

        let info = UpdateInfo {
            version: version_str,
            changelog: release.body.unwrap_or_default(),
            download_url: release.html_url.unwrap_or_default(),
            is_forced,
        };

        self.record_checked(Some(info.clone()));
        Some(info)
    }

    /// Spawn a background tokio task; calls `on_update` if a new version
    /// is found. The task respects `should_check()` — no-ops when
    /// interval hasn't elapsed.
    pub fn spawn_background_check<F>(&self, on_update: F)
    where
        F: Fn(UpdateInfo) + Send + 'static,
    {
        if !self.should_check() {
            return;
        }
        let checker = self.clone();
        tokio::spawn(async move {
            if let Some(info) = checker.check_for_update().await {
                on_update(info);
            }
        });
    }

    /// Return the last cached `UpdateInfo` from a previous check.
    pub fn last_result(&self) -> Option<UpdateInfo> {
        self.inner
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .last_result
            .clone()
    }

    fn record_checked(&self, result: Option<UpdateInfo>) {
        let mut g = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        g.last_checked = Some(Instant::now());
        g.last_result = result;
    }
}

// ── Helper used only in tests ─────────────────────────────────────────────────

/// Compare two semver strings: returns `true` if `latest > current`.
pub fn is_newer(current: &str, latest: &str) -> bool {
    match (
        semver::Version::parse(current),
        semver::Version::parse(latest),
    ) {
        (Ok(c), Ok(l)) => l > c,
        _ => false,
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn checker(current: &str) -> UpdateChecker {
        UpdateChecker::with_defaults("owner/repo", current)
    }

    #[test]
    fn test_is_newer_true() {
        assert!(is_newer("1.0.0", "1.1.0"));
    }

    #[test]
    fn test_is_newer_false_same() {
        assert!(!is_newer("1.0.0", "1.0.0"));
    }

    #[test]
    fn test_is_newer_false_older() {
        assert!(!is_newer("2.0.0", "1.9.9"));
    }

    #[test]
    fn test_is_newer_invalid_semver() {
        assert!(!is_newer("not-a-version", "1.0.0"));
    }

    #[test]
    fn test_skip_version_stored() {
        let c = checker("1.0.0");
        c.skip_version("1.1.0");
        assert_eq!(c.skipped_version(), Some("1.1.0".to_string()));
    }

    #[test]
    fn test_clear_skipped() {
        let c = checker("1.0.0");
        c.skip_version("1.1.0");
        c.clear_skipped();
        assert_eq!(c.skipped_version(), None);
    }

    #[test]
    fn test_should_check_true_on_fresh() {
        let c = checker("1.0.0");
        assert!(c.should_check());
    }

    #[test]
    fn test_should_check_false_after_recent_check() {
        let c = checker("1.0.0");
        // Simulate a very recent check.
        {
            let mut g = c.inner.lock().unwrap();
            g.last_checked = Some(Instant::now());
        }
        assert!(!c.should_check());
    }

    #[test]
    fn test_set_min_version_parses() {
        let c = checker("1.0.0");
        c.set_min_version("1.2.0");
        let g = c.inner.lock().unwrap();
        assert_eq!(g.min_version, Some(semver::Version::new(1, 2, 0)));
    }

    #[test]
    fn test_set_min_version_invalid_ignored() {
        let c = checker("1.0.0");
        c.set_min_version("not-a-version");
        let g = c.inner.lock().unwrap();
        assert!(g.min_version.is_none());
    }

    #[test]
    fn test_last_result_none_initially() {
        let c = checker("1.0.0");
        assert!(c.last_result().is_none());
    }

    #[test]
    fn test_update_info_is_forced_false_by_default() {
        let info = UpdateInfo {
            version: "1.1.0".into(),
            changelog: "".into(),
            download_url: "".into(),
            is_forced: false,
        };
        assert!(!info.is_forced);
    }
}
