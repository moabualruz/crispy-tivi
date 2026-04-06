//! Per-profile theme configuration.
//!
//! Theme settings are stored as plain key-value entries in `db_settings`
//! under the key `"theme::{profile_id}"`.  This avoids a dedicated table
//! and reuses the existing settings infrastructure.

use serde::{Deserialize, Serialize};

use super::CrispyService;
use crate::database::DbError;

// ── Types ─────────────────────────────────────────────────────────────────────

/// Light/dark/system theme selector.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum ThemeMode {
    #[default]
    Dark,
    Light,
    /// Follow the OS / system preference.
    System,
}

/// Full theme configuration for one profile.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct ThemeConfig {
    pub mode: ThemeMode,
    /// Optional hex colour string for the accent, e.g. `"#FF4B2B"`.
    pub accent_color: Option<String>,
}

// ── Storage key helper ────────────────────────────────────────────────────────

fn theme_key(profile_id: &str) -> String {
    format!("theme::{profile_id}")
}

// ── Service impl ──────────────────────────────────────────────────────────────

/// Domain service for theme configuration operations.
pub struct ThemeService(pub(super) CrispyService);

impl ThemeService {
    /// Return the theme config for `profile_id`.
    ///
    /// Returns `ThemeConfig::default()` (Dark, no custom accent) when no
    /// preference has been saved yet.
    pub fn get_theme(&self, profile_id: &str) -> Result<ThemeConfig, DbError> {
        let key = theme_key(profile_id);
        match self.0.get_setting(&key)? {
            Some(json) => {
                let cfg: ThemeConfig = serde_json::from_str(&json).unwrap_or_default();
                Ok(cfg)
            }
            None => Ok(ThemeConfig::default()),
        }
    }

    /// Persist the theme config for `profile_id`.
    pub fn set_theme(&self, profile_id: &str, config: ThemeConfig) -> Result<(), DbError> {
        let key = theme_key(profile_id);
        let json = serde_json::to_string(&config)
            .map_err(|e| DbError::Migration(format!("theme serialisation: {e}")))?;
        self.0.set_setting(&key, &json)
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::services::test_helpers::make_service;

    fn make_theme_service() -> ThemeService {
        ThemeService(make_service())
    }

    #[test]
    fn test_get_theme_defaults_to_dark_when_unset() {
        let svc = make_theme_service();
        let cfg = svc.get_theme("p1").unwrap();
        assert_eq!(cfg.mode, ThemeMode::Dark);
        assert_eq!(cfg.accent_color, None);
    }

    #[test]
    fn test_set_and_get_theme_round_trips() {
        let svc = make_theme_service();
        let want = ThemeConfig {
            mode: ThemeMode::Light,
            accent_color: Some("#FF4B2B".to_string()),
        };
        svc.set_theme("p1", want.clone()).unwrap();
        let got = svc.get_theme("p1").unwrap();
        assert_eq!(got, want);
    }

    #[test]
    fn test_themes_are_per_profile() {
        let svc = make_theme_service();
        svc.set_theme(
            "p1",
            ThemeConfig {
                mode: ThemeMode::Dark,
                accent_color: None,
            },
        )
        .unwrap();
        svc.set_theme(
            "p2",
            ThemeConfig {
                mode: ThemeMode::Light,
                accent_color: Some("#AABBCC".to_string()),
            },
        )
        .unwrap();
        assert_eq!(svc.get_theme("p1").unwrap().mode, ThemeMode::Dark);
        assert_eq!(svc.get_theme("p2").unwrap().mode, ThemeMode::Light);
    }

    #[test]
    fn test_overwrite_theme() {
        let svc = make_theme_service();
        svc.set_theme(
            "p1",
            ThemeConfig {
                mode: ThemeMode::System,
                accent_color: None,
            },
        )
        .unwrap();
        svc.set_theme(
            "p1",
            ThemeConfig {
                mode: ThemeMode::Light,
                accent_color: Some("#123456".to_string()),
            },
        )
        .unwrap();
        let got = svc.get_theme("p1").unwrap();
        assert_eq!(got.mode, ThemeMode::Light);
        assert_eq!(got.accent_color.as_deref(), Some("#123456"));
    }

    #[test]
    fn test_theme_mode_serialisation() {
        for mode in [ThemeMode::Dark, ThemeMode::Light, ThemeMode::System] {
            let s = serde_json::to_string(&mode).unwrap();
            let back: ThemeMode = serde_json::from_str(&s).unwrap();
            assert_eq!(back, mode);
        }
    }
}
