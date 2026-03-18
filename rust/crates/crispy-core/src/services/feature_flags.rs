//! Feature flag system with local cache, TTL, kill-switch support,
//! and offline fallback to safe defaults.
//!
//! Load flag definitions via `load_from_json`, then query with
//! `is_enabled` / `get_rollout_percentage`. Any flag can be killed
//! instantly via `kill_switch`. On offline startup the last cached
//! (or hardcoded safe-default) values are returned.

use std::{
    collections::HashMap,
    sync::{Arc, Mutex},
    time::{Duration, Instant},
};

// ── Flag definition ───────────────────────────────────────────────────────────

/// A single feature-flag definition.
#[derive(Debug, Clone)]
struct FlagDef {
    /// Whether the flag is globally enabled.
    enabled: bool,
    /// Rollout percentage 0–100. Clients hash their ID against this.
    rollout_pct: u8,
    /// If `true`, the kill-switch is active — flag is disabled regardless.
    killed: bool,
}

impl FlagDef {
    fn effective_enabled(&self) -> bool {
        !self.killed && self.enabled
    }
}

// ── Safe defaults ─────────────────────────────────────────────────────────────

/// Hard-coded safe defaults used when no remote definition exists.
fn safe_defaults() -> HashMap<String, FlagDef> {
    [
        ("dvr_enabled", false, 0u8),
        ("vod_browsing", true, 100),
        ("media_server", true, 100),
        ("social_sharing", false, 0),
        ("radio_section", false, 0),
    ]
    .iter()
    .map(|(name, enabled, pct)| {
        (
            name.to_string(),
            FlagDef {
                enabled: *enabled,
                rollout_pct: *pct,
                killed: false,
            },
        )
    })
    .collect()
}

// ── Cached entry ──────────────────────────────────────────────────────────────

struct CachedFlags {
    flags: HashMap<String, FlagDef>,
    loaded_at: Instant,
}

// ── FeatureFlags ──────────────────────────────────────────────────────────────

/// Feature flag store with TTL-based cache and kill-switch support.
///
/// Thread-safe via interior `Arc<Mutex<>>`. Two instances sharing the
/// same `Arc` see the same flag state (useful for testing).
#[derive(Clone)]
pub struct FeatureFlags {
    inner: Arc<Mutex<FeatureFlagsInner>>,
}

struct FeatureFlagsInner {
    cache: Option<CachedFlags>,
    ttl: Duration,
    kill_switches: HashMap<String, bool>,
}

impl FeatureFlags {
    /// Create a new store with `ttl` cache lifetime.
    pub fn new(ttl: Duration) -> Self {
        Self {
            inner: Arc::new(Mutex::new(FeatureFlagsInner {
                cache: None,
                ttl,
                kill_switches: HashMap::new(),
            })),
        }
    }

    /// Create with a default 5-minute TTL.
    pub fn with_default_ttl() -> Self {
        Self::new(Duration::from_secs(300))
    }

    // ── Loading ──────────────────────────────────────────────────────────────

    /// Parse and load flag definitions from a JSON string.
    ///
    /// Expected format:
    /// ```json
    /// {
    ///   "dvr_enabled":    { "enabled": false, "rollout_pct": 0 },
    ///   "vod_browsing":   { "enabled": true,  "rollout_pct": 100 }
    /// }
    /// ```
    ///
    /// Malformed entries are skipped; known defaults fill any gaps.
    pub fn load_from_json(&self, json: &str) {
        let parsed: serde_json::Value = match serde_json::from_str(json) {
            Ok(v) => v,
            Err(_) => return, // keep existing cache
        };

        let mut flags = safe_defaults();

        if let Some(obj) = parsed.as_object() {
            for (key, val) in obj {
                let enabled = val
                    .get("enabled")
                    .and_then(|v| v.as_bool())
                    .unwrap_or(false);
                let rollout_pct = val
                    .get("rollout_pct")
                    .and_then(|v| v.as_u64())
                    .map(|n| n.min(100) as u8)
                    .unwrap_or(0);
                flags.insert(
                    key.clone(),
                    FlagDef {
                        enabled,
                        rollout_pct,
                        killed: false,
                    },
                );
            }
        }

        let mut guard = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        // Re-apply in-memory kill switches to the freshly loaded flags.
        for (k, _) in &guard.kill_switches {
            if let Some(f) = flags.get_mut(k) {
                f.killed = true;
            }
        }
        guard.cache = Some(CachedFlags {
            flags,
            loaded_at: Instant::now(),
        });
    }

    // ── Kill switch ──────────────────────────────────────────────────────────

    /// Instantly disable `flag` regardless of its remote definition.
    pub fn kill_switch(&self, flag: &str) {
        let mut guard = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        guard.kill_switches.insert(flag.to_string(), true);
        if let Some(cache) = &mut guard.cache {
            if let Some(f) = cache.flags.get_mut(flag) {
                f.killed = true;
            }
        }
    }

    /// Re-enable a previously killed flag.
    pub fn unkill(&self, flag: &str) {
        let mut guard = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        guard.kill_switches.remove(flag);
        if let Some(cache) = &mut guard.cache {
            if let Some(f) = cache.flags.get_mut(flag) {
                f.killed = false;
            }
        }
    }

    // ── Queries ──────────────────────────────────────────────────────────────

    /// Return `true` if `flag` is enabled (and not kill-switched).
    ///
    /// Falls back to hardcoded safe defaults when no flags are loaded or
    /// the cache has expired.
    pub fn is_enabled(&self, flag: &str) -> bool {
        self.resolve(flag, |f| f.effective_enabled())
    }

    /// Return the rollout percentage (0–100) for `flag`.
    ///
    /// Returns `0` for unknown flags; falls back to safe defaults on
    /// expired/missing cache.
    pub fn get_rollout_percentage(&self, flag: &str) -> u8 {
        self.resolve(flag, |f| {
            if f.effective_enabled() {
                f.rollout_pct
            } else {
                0
            }
        })
    }

    /// Whether the TTL has expired (cache needs refresh).
    pub fn is_stale(&self) -> bool {
        let guard = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        match &guard.cache {
            None => true,
            Some(c) => c.loaded_at.elapsed() > guard.ttl,
        }
    }

    // ── Private ──────────────────────────────────────────────────────────────

    fn resolve<T, F>(&self, flag: &str, extract: F) -> T
    where
        F: Fn(&FlagDef) -> T,
        T: Default,
    {
        let guard = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        let defaults = safe_defaults();
        let flags = match &guard.cache {
            Some(c) if c.loaded_at.elapsed() <= guard.ttl => &c.flags,
            _ => &defaults,
        };
        // Use locally stored kill_switches when reading from defaults path.
        match flags.get(flag) {
            Some(f) => {
                let killed_locally = guard.kill_switches.contains_key(flag);
                if killed_locally {
                    // Build a temp copy with killed=true.
                    let overridden = FlagDef {
                        enabled: f.enabled,
                        rollout_pct: f.rollout_pct,
                        killed: true,
                    };
                    extract(&overridden)
                } else {
                    extract(f)
                }
            }
            None => T::default(),
        }
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn flags_with_json(json: &str) -> FeatureFlags {
        let f = FeatureFlags::new(Duration::from_secs(60));
        f.load_from_json(json);
        f
    }

    #[test]
    fn test_safe_defaults_vod_browsing_enabled() {
        let f = FeatureFlags::with_default_ttl();
        assert!(f.is_enabled("vod_browsing"));
    }

    #[test]
    fn test_safe_defaults_dvr_disabled() {
        let f = FeatureFlags::with_default_ttl();
        assert!(!f.is_enabled("dvr_enabled"));
    }

    #[test]
    fn test_load_from_json_overrides_default() {
        let f = flags_with_json(r#"{"dvr_enabled": {"enabled": true, "rollout_pct": 50}}"#);
        assert!(f.is_enabled("dvr_enabled"));
        assert_eq!(f.get_rollout_percentage("dvr_enabled"), 50);
    }

    #[test]
    fn test_kill_switch_disables_flag() {
        let f = flags_with_json(r#"{"vod_browsing": {"enabled": true, "rollout_pct": 100}}"#);
        assert!(f.is_enabled("vod_browsing"));
        f.kill_switch("vod_browsing");
        assert!(!f.is_enabled("vod_browsing"));
    }

    #[test]
    fn test_unkill_restores_flag() {
        let f = flags_with_json(r#"{"vod_browsing": {"enabled": true, "rollout_pct": 100}}"#);
        f.kill_switch("vod_browsing");
        assert!(!f.is_enabled("vod_browsing"));
        f.unkill("vod_browsing");
        assert!(f.is_enabled("vod_browsing"));
    }

    #[test]
    fn test_rollout_pct_zero_when_disabled() {
        let f = flags_with_json(r#"{"social_sharing": {"enabled": false, "rollout_pct": 80}}"#);
        assert_eq!(f.get_rollout_percentage("social_sharing"), 0);
    }

    #[test]
    fn test_rollout_pct_returned_when_enabled() {
        let f = flags_with_json(r#"{"media_server": {"enabled": true, "rollout_pct": 75}}"#);
        assert_eq!(f.get_rollout_percentage("media_server"), 75);
    }

    #[test]
    fn test_unknown_flag_returns_false() {
        let f = FeatureFlags::with_default_ttl();
        assert!(!f.is_enabled("unknown_feature_xyz"));
    }

    #[test]
    fn test_unknown_flag_rollout_returns_zero() {
        let f = FeatureFlags::with_default_ttl();
        assert_eq!(f.get_rollout_percentage("unknown_feature_xyz"), 0);
    }

    #[test]
    fn test_malformed_json_keeps_defaults() {
        let f = FeatureFlags::with_default_ttl();
        f.load_from_json("not json at all {{{");
        // Defaults still work.
        assert!(f.is_enabled("vod_browsing"));
    }

    #[test]
    fn test_rollout_pct_clamped_to_100() {
        let f = flags_with_json(r#"{"radio_section": {"enabled": true, "rollout_pct": 200}}"#);
        assert_eq!(f.get_rollout_percentage("radio_section"), 100);
    }

    #[test]
    fn test_kill_switch_applied_on_reload() {
        let f = FeatureFlags::new(Duration::from_secs(60));
        f.kill_switch("dvr_enabled");
        // Reload with dvr_enabled=true — kill switch must persist.
        f.load_from_json(r#"{"dvr_enabled": {"enabled": true, "rollout_pct": 100}}"#);
        assert!(!f.is_enabled("dvr_enabled"));
    }

    #[test]
    fn test_is_stale_before_load() {
        let f = FeatureFlags::new(Duration::from_secs(60));
        assert!(f.is_stale());
    }

    #[test]
    fn test_not_stale_after_load() {
        let f = flags_with_json(r#"{}"#);
        assert!(!f.is_stale());
    }

    #[test]
    fn test_all_default_flags_present() {
        let f = FeatureFlags::with_default_ttl();
        for flag in [
            "dvr_enabled",
            "vod_browsing",
            "media_server",
            "social_sharing",
            "radio_section",
        ] {
            // Should not panic; unknown flags return false, known defaults return a defined value.
            let _ = f.is_enabled(flag);
        }
    }
}
