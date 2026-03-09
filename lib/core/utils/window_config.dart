/// When `true`, CrispyTivi uses a custom borderless title bar with
/// window-control buttons (minimize, maximize, close) and hides the
/// OS-native title bar.
///
/// When `false`, the OS-default title bar and window controls are used.
const bool kUseCustomTitleBar = false;

/// When `true`, window size, position, and maximized state are persisted
/// to SharedPreferences and restored on next launch.
///
/// When `false`, the window opens at the adaptive default size (1080p or
/// 1440p based on screen resolution), centered.
///
/// Works independently of [kUseCustomTitleBar] — size memory functions
/// with either the custom or OS-native title bar.
const bool kPersistWindowState = true;
