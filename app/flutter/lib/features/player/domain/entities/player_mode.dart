/// Player display mode in the player-first architecture.
///
/// The app treats the video player as the foundation layer.
/// All screens are overlays on top of the always-present
/// video surface — like VLC with widgets.
enum PlayerMode {
  /// No video playing. App shows screens normally.
  idle,

  /// Video plays (audio continues) but screen content
  /// covers it. Used when navigating to non-video screens.
  background,

  /// Video visible in a screen-specific area (e.g. EPG
  /// top-left 16:9 preview, channel list PiP corner).
  preview,

  /// Video fills the entire screen edge-to-edge, escaping
  /// AppShell side navigation bounds. OSD overlay on top.
  fullscreen,
}
