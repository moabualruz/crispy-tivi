//! Per-screen color button semantics following ETSI EN 300 468 conventions.
//!
//! Maps each app screen (and player mode) to the four color buttons
//! (Red, Green, Yellow, Blue) found on TV remotes and CEC-capable devices.
//! `None` means the button has no function on that screen and should not
//! be rendered in the button legend bar.

// ── Types ──────────────────────────────────────────────────────────────────

/// Context flags that influence button mappings within the same screen.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub(crate) struct ButtonContext {
    /// Whether the player is currently playing or paused (not idle/stopped).
    pub is_playing: bool,
    /// Whether the active stream is live (as opposed to VOD / time-shifted).
    pub is_live: bool,
    /// Whether the backend supports DVR recording for this stream.
    pub has_recording_support: bool,
}

/// Color button labels for one screen context.
///
/// Each field is `None` when that color button is unused on the given screen,
/// and `Some(&str)` with a short localisable action label when active.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct ColorButtonMapping {
    /// Red button action label, or `None` if unused.
    pub red: Option<&'static str>,
    /// Green button action label, or `None` if unused.
    pub green: Option<&'static str>,
    /// Yellow button action label, or `None` if unused.
    pub yellow: Option<&'static str>,
    /// Blue button action label, or `None` if unused.
    pub blue: Option<&'static str>,
}

impl ColorButtonMapping {
    /// Returns `true` when every button is `None` (screen has no color actions).
    pub(crate) fn is_empty(&self) -> bool {
        self.red.is_none() && self.green.is_none() && self.yellow.is_none() && self.blue.is_none()
    }
}

// ── Screen index constants ─────────────────────────────────────────────────

/// Sentinel index used when the player overlay is active with a live stream.
pub(crate) const SCREEN_PLAYER_LIVE: i32 = 100;
/// Sentinel index used when the player overlay is active with a VOD stream.
pub(crate) const SCREEN_PLAYER_VOD: i32 = 101;

// ── Mapping function ───────────────────────────────────────────────────────

/// Return color button labels for the given screen index and player context.
///
/// `screen_index` values 0-7 correspond to the `Screen` enum in `events.rs`.
/// The sentinel values `SCREEN_PLAYER_LIVE` and `SCREEN_PLAYER_VOD` represent
/// the player overlay modes.
///
/// When `context.is_playing` is `true` and the player is in the foreground,
/// callers should pass the appropriate player sentinel instead of the content
/// screen index.
pub(crate) fn get_color_buttons(screen_index: i32, context: &ButtonContext) -> ColorButtonMapping {
    match screen_index {
        // ── Home ──────────────────────────────────────────────────────────
        0 => ColorButtonMapping {
            red: None,
            green: None,
            yellow: None,
            blue: None,
        },

        // ── Live TV ───────────────────────────────────────────────────────
        1 => ColorButtonMapping {
            red: if context.has_recording_support {
                Some("Record")
            } else {
                None
            },
            green: Some("Favorite"),
            yellow: Some("Sort/Filter"),
            blue: Some("EPG"),
        },

        // ── EPG ───────────────────────────────────────────────────────────
        2 => ColorButtonMapping {
            red: if context.has_recording_support {
                Some("Record")
            } else {
                None
            },
            green: Some("Remind"),
            yellow: Some("Day -1"),
            blue: Some("Day +1"),
        },

        // ── Movies ────────────────────────────────────────────────────────
        3 => ColorButtonMapping {
            red: None,
            green: Some("Favorite"),
            yellow: Some("Sort"),
            blue: Some("Filter"),
        },

        // ── Series ────────────────────────────────────────────────────────
        4 => ColorButtonMapping {
            red: None,
            green: Some("Favorite"),
            yellow: Some("Sort"),
            blue: Some("Filter"),
        },

        // ── Search ────────────────────────────────────────────────────────
        5 => ColorButtonMapping {
            red: None,
            green: None,
            yellow: None,
            blue: None,
        },

        // ── Library ───────────────────────────────────────────────────────
        6 => ColorButtonMapping {
            red: Some("Remove"),
            green: None,
            yellow: Some("Sort"),
            blue: Some("Filter"),
        },

        // ── Settings ──────────────────────────────────────────────────────
        7 => ColorButtonMapping {
            red: None,
            green: None,
            yellow: None,
            blue: None,
        },

        // ── Player — Live stream ───────────────────────────────────────────
        SCREEN_PLAYER_LIVE => ColorButtonMapping {
            red: if context.has_recording_support {
                Some("Record")
            } else {
                None
            },
            green: Some("Audio/Subs"),
            yellow: Some("Guide"),
            blue: Some("Info"),
        },

        // ── Player — VOD stream ───────────────────────────────────────────
        SCREEN_PLAYER_VOD => ColorButtonMapping {
            red: None,
            green: Some("Audio/Subs"),
            yellow: Some("Skip -10s"),
            blue: Some("Skip +10s"),
        },

        // ── Unknown screen ────────────────────────────────────────────────
        _ => ColorButtonMapping {
            red: None,
            green: None,
            yellow: None,
            blue: None,
        },
    }
}

// ── Tests ──────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn ctx_default() -> ButtonContext {
        ButtonContext::default()
    }

    fn ctx_with_recording() -> ButtonContext {
        ButtonContext {
            is_playing: true,
            is_live: true,
            has_recording_support: true,
        }
    }

    fn ctx_vod() -> ButtonContext {
        ButtonContext {
            is_playing: true,
            is_live: false,
            has_recording_support: false,
        }
    }

    // ── Home ──────────────────────────────────────────────────────────────

    #[test]
    fn test_home_screen_has_no_buttons() {
        let mapping = get_color_buttons(0, &ctx_default());
        assert!(mapping.is_empty(), "Home screen must have no color buttons");
    }

    // ── Live TV ───────────────────────────────────────────────────────────

    #[test]
    fn test_live_tv_has_record_favorite_sort_epg() {
        let mapping = get_color_buttons(1, &ctx_with_recording());
        assert_eq!(mapping.red, Some("Record"));
        assert_eq!(mapping.green, Some("Favorite"));
        assert_eq!(mapping.yellow, Some("Sort/Filter"));
        assert_eq!(mapping.blue, Some("EPG"));
    }

    #[test]
    fn test_live_tv_no_record_when_not_supported() {
        let mapping = get_color_buttons(1, &ctx_default());
        assert_eq!(
            mapping.red, None,
            "Record must be absent without recording support"
        );
        assert_eq!(mapping.green, Some("Favorite"));
        assert_eq!(mapping.yellow, Some("Sort/Filter"));
        assert_eq!(mapping.blue, Some("EPG"));
    }

    // ── EPG ───────────────────────────────────────────────────────────────

    #[test]
    fn test_epg_has_record_remind_day_nav() {
        let mapping = get_color_buttons(2, &ctx_with_recording());
        assert_eq!(mapping.red, Some("Record"));
        assert_eq!(mapping.green, Some("Remind"));
        assert_eq!(mapping.yellow, Some("Day -1"));
        assert_eq!(mapping.blue, Some("Day +1"));
    }

    // ── Movies ────────────────────────────────────────────────────────────

    #[test]
    fn test_movies_has_favorite_sort_filter() {
        let mapping = get_color_buttons(3, &ctx_default());
        assert_eq!(mapping.red, None);
        assert_eq!(mapping.green, Some("Favorite"));
        assert_eq!(mapping.yellow, Some("Sort"));
        assert_eq!(mapping.blue, Some("Filter"));
    }

    // ── Series ────────────────────────────────────────────────────────────

    #[test]
    fn test_series_has_favorite_sort_filter() {
        let mapping = get_color_buttons(4, &ctx_default());
        assert_eq!(mapping.red, None);
        assert_eq!(mapping.green, Some("Favorite"));
        assert_eq!(mapping.yellow, Some("Sort"));
        assert_eq!(mapping.blue, Some("Filter"));
    }

    // ── Search ────────────────────────────────────────────────────────────

    #[test]
    fn test_search_has_no_buttons() {
        let mapping = get_color_buttons(5, &ctx_default());
        assert!(
            mapping.is_empty(),
            "Search screen must have no color buttons"
        );
    }

    // ── Library ───────────────────────────────────────────────────────────

    #[test]
    fn test_library_has_remove_sort_filter() {
        let mapping = get_color_buttons(6, &ctx_default());
        assert_eq!(mapping.red, Some("Remove"));
        assert_eq!(mapping.green, None);
        assert_eq!(mapping.yellow, Some("Sort"));
        assert_eq!(mapping.blue, Some("Filter"));
    }

    // ── Settings ──────────────────────────────────────────────────────────

    #[test]
    fn test_settings_has_no_buttons() {
        let mapping = get_color_buttons(7, &ctx_default());
        assert!(
            mapping.is_empty(),
            "Settings screen must have no color buttons"
        );
    }

    // ── Player — Live ─────────────────────────────────────────────────────

    #[test]
    fn test_player_live_has_record_audio_guide_info() {
        let mapping = get_color_buttons(SCREEN_PLAYER_LIVE, &ctx_with_recording());
        assert_eq!(mapping.red, Some("Record"));
        assert_eq!(mapping.green, Some("Audio/Subs"));
        assert_eq!(mapping.yellow, Some("Guide"));
        assert_eq!(mapping.blue, Some("Info"));
    }

    #[test]
    fn test_player_live_no_record_when_not_supported() {
        let ctx = ButtonContext {
            is_playing: true,
            is_live: true,
            has_recording_support: false,
        };
        let mapping = get_color_buttons(SCREEN_PLAYER_LIVE, &ctx);
        assert_eq!(mapping.red, None);
        assert_eq!(mapping.green, Some("Audio/Subs"));
        assert_eq!(mapping.yellow, Some("Guide"));
        assert_eq!(mapping.blue, Some("Info"));
    }

    // ── Player — VOD ──────────────────────────────────────────────────────

    #[test]
    fn test_player_vod_has_audio_skip() {
        let mapping = get_color_buttons(SCREEN_PLAYER_VOD, &ctx_vod());
        assert_eq!(mapping.red, None);
        assert_eq!(mapping.green, Some("Audio/Subs"));
        assert_eq!(mapping.yellow, Some("Skip -10s"));
        assert_eq!(mapping.blue, Some("Skip +10s"));
    }

    // ── Unknown screen ────────────────────────────────────────────────────

    #[test]
    fn test_unknown_screen_has_no_buttons() {
        let mapping = get_color_buttons(99, &ctx_default());
        assert!(
            mapping.is_empty(),
            "Unknown screen must produce empty mapping"
        );
    }

    // ── is_empty helper ───────────────────────────────────────────────────

    #[test]
    fn test_is_empty_returns_false_when_any_button_present() {
        let mapping = ColorButtonMapping {
            red: Some("X"),
            green: None,
            yellow: None,
            blue: None,
        };
        assert!(!mapping.is_empty());
    }
}
