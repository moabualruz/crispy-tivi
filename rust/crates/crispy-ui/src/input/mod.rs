//! Input abstraction layer.
//!
//! Raw key codes (from Slint keyboard events) are mapped to device-agnostic
//! [`LogicalAction`]s so the rest of the app never deals in raw keys.
//!
//! # Modules
//! - [`number_entry`] — accumulates digit presses for direct channel tuning

pub mod number_entry;

use std::collections::HashMap;

// ── LogicalAction ─────────────────────────────────────────────────────────────

/// Device-agnostic user intent derived from a raw input event.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum LogicalAction {
    // Navigation
    NavUp,
    NavDown,
    NavLeft,
    NavRight,
    NavSelect,
    NavBack,

    // Player
    PlayerPlay,
    PlayerPause,
    PlayerStop,
    PlayerSeekForward,
    PlayerSeekBackward,
    PlayerNextTrack,
    PlayerPrevTrack,
    PlayerVolumeUp,
    PlayerVolumeDown,

    // Content
    ContentFavorite,
    ContentInfo,
    ContentShare,

    // Colour function keys (found on TV remotes)
    ColorRed,
    ColorGreen,
    ColorYellow,
    ColorBlue,

    /// Direct number entry (0–9).
    NumberKey(u8),
}

// ── InputDevice ───────────────────────────────────────────────────────────────

/// The physical input device that generated an event.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InputDevice {
    DPad,
    Keyboard,
    Gamepad,
    Mouse,
    Touch,
}

// ── KeyCode ───────────────────────────────────────────────────────────────────

/// Normalised key codes — a thin wrapper over Slint's `SharedString` key names.
///
/// Using a plain `String` avoids importing Slint types in this module.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct KeyCode(pub String);

impl KeyCode {
    pub fn new(s: impl Into<String>) -> Self {
        Self(s.into())
    }
}

// ── KeyEvent ──────────────────────────────────────────────────────────────────

/// A raw key-press event carrying both the key code and the originating device.
#[derive(Debug, Clone)]
pub struct KeyEvent {
    pub key_code: KeyCode,
    pub device: InputDevice,
}

impl KeyEvent {
    pub fn new(key_code: KeyCode, device: InputDevice) -> Self {
        Self { key_code, device }
    }
}

// ── InputManager ─────────────────────────────────────────────────────────────

/// Maps raw key codes to logical actions and tracks the active input device.
pub struct InputManager {
    active_device: InputDevice,
    key_mappings: HashMap<KeyCode, LogicalAction>,
}

impl InputManager {
    /// Build a manager with the default keyboard mappings.
    pub fn new() -> Self {
        let mut mgr = Self {
            active_device: InputDevice::Keyboard,
            key_mappings: HashMap::new(),
        };
        mgr.load_defaults();
        mgr
    }

    /// Register or override a single key→action mapping.
    pub fn bind(&mut self, key: KeyCode, action: LogicalAction) {
        self.key_mappings.insert(key, action);
    }

    /// Translate a raw key code to a logical action.
    pub fn map_key(&self, key_code: &KeyCode) -> Option<LogicalAction> {
        self.key_mappings.get(key_code).cloned()
    }

    /// Detect the input device from a key event and update `active_device`.
    pub fn detect_device(&mut self, key_event: &KeyEvent) -> InputDevice {
        self.active_device = key_event.device;
        self.active_device
    }

    /// The last observed active device.
    pub fn active_device(&self) -> InputDevice {
        self.active_device
    }

    // ── Default keyboard mappings ─────────────────────────────────────────

    fn load_defaults(&mut self) {
        let defaults: &[(&str, LogicalAction)] = &[
            // Navigation
            ("ArrowUp", LogicalAction::NavUp),
            ("ArrowDown", LogicalAction::NavDown),
            ("ArrowLeft", LogicalAction::NavLeft),
            ("ArrowRight", LogicalAction::NavRight),
            ("Return", LogicalAction::NavSelect),
            ("Enter", LogicalAction::NavSelect),
            ("Escape", LogicalAction::NavBack),
            ("Backspace", LogicalAction::NavBack),
            // Player
            (" ", LogicalAction::PlayerPlay), // Space = play/pause toggle
            ("MediaPlay", LogicalAction::PlayerPlay),
            ("MediaPause", LogicalAction::PlayerPause),
            ("MediaStop", LogicalAction::PlayerStop),
            ("MediaFastForward", LogicalAction::PlayerSeekForward),
            ("MediaRewind", LogicalAction::PlayerSeekBackward),
            ("MediaNextTrack", LogicalAction::PlayerNextTrack),
            ("MediaPreviousTrack", LogicalAction::PlayerPrevTrack),
            ("AudioVolumeUp", LogicalAction::PlayerVolumeUp),
            ("AudioVolumeDown", LogicalAction::PlayerVolumeDown),
            // Content
            ("f", LogicalAction::ContentFavorite),
            ("i", LogicalAction::ContentInfo),
            // Colour keys (common TV remote layout)
            ("F1", LogicalAction::ColorRed),
            ("F2", LogicalAction::ColorGreen),
            ("F3", LogicalAction::ColorYellow),
            ("F4", LogicalAction::ColorBlue),
            // Number row
            ("0", LogicalAction::NumberKey(0)),
            ("1", LogicalAction::NumberKey(1)),
            ("2", LogicalAction::NumberKey(2)),
            ("3", LogicalAction::NumberKey(3)),
            ("4", LogicalAction::NumberKey(4)),
            ("5", LogicalAction::NumberKey(5)),
            ("6", LogicalAction::NumberKey(6)),
            ("7", LogicalAction::NumberKey(7)),
            ("8", LogicalAction::NumberKey(8)),
            ("9", LogicalAction::NumberKey(9)),
        ];

        for (key, action) in defaults {
            self.key_mappings.insert(KeyCode::new(*key), action.clone());
        }
    }
}

impl Default for InputManager {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_map_key_arrow_up_returns_nav_up() {
        let mgr = InputManager::new();
        assert_eq!(
            mgr.map_key(&KeyCode::new("ArrowUp")),
            Some(LogicalAction::NavUp)
        );
    }

    #[test]
    fn test_map_key_enter_returns_nav_select() {
        let mgr = InputManager::new();
        assert_eq!(
            mgr.map_key(&KeyCode::new("Enter")),
            Some(LogicalAction::NavSelect)
        );
    }

    #[test]
    fn test_map_key_escape_returns_nav_back() {
        let mgr = InputManager::new();
        assert_eq!(
            mgr.map_key(&KeyCode::new("Escape")),
            Some(LogicalAction::NavBack)
        );
    }

    #[test]
    fn test_map_key_space_returns_player_play() {
        let mgr = InputManager::new();
        assert_eq!(
            mgr.map_key(&KeyCode::new(" ")),
            Some(LogicalAction::PlayerPlay)
        );
    }

    #[test]
    fn test_map_key_digit_returns_number_key() {
        let mgr = InputManager::new();
        assert_eq!(
            mgr.map_key(&KeyCode::new("5")),
            Some(LogicalAction::NumberKey(5))
        );
    }

    #[test]
    fn test_map_key_unknown_returns_none() {
        let mgr = InputManager::new();
        assert!(mgr.map_key(&KeyCode::new("XUnknown")).is_none());
    }

    #[test]
    fn test_detect_device_updates_active() {
        let mut mgr = InputManager::new();
        let ev = KeyEvent::new(KeyCode::new("ArrowUp"), InputDevice::DPad);
        let detected = mgr.detect_device(&ev);
        assert_eq!(detected, InputDevice::DPad);
        assert_eq!(mgr.active_device(), InputDevice::DPad);
    }

    #[test]
    fn test_bind_overrides_mapping() {
        let mut mgr = InputManager::new();
        mgr.bind(KeyCode::new("ArrowUp"), LogicalAction::ContentInfo);
        assert_eq!(
            mgr.map_key(&KeyCode::new("ArrowUp")),
            Some(LogicalAction::ContentInfo)
        );
    }

    #[test]
    fn test_colour_keys_map_correctly() {
        let mgr = InputManager::new();
        assert_eq!(
            mgr.map_key(&KeyCode::new("F1")),
            Some(LogicalAction::ColorRed)
        );
        assert_eq!(
            mgr.map_key(&KeyCode::new("F4")),
            Some(LogicalAction::ColorBlue)
        );
    }
}
