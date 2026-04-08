import 'dart:io';

/// Policy for when to hand off to the iOS PiP native player.
///
/// Unlike HDR (which is automatic based on content), PiP handoff
/// is always user-initiated (PiP button on OSD). This policy only
/// checks whether the platform supports PiP takeover.
///
/// Desktop PiP (Windows/Linux/macOS) uses window_manager-based PiP,
/// not this native player handoff.
class PipHandoffPolicy {
  /// Whether native PiP takeover is available on this device.
  ///
  /// Returns `true` on iOS (AVPictureInPictureController) and
  /// Android (API 26+ activity PiP via Media3 ExoPlayer).
  /// The actual PiP support check happens on the native side.
  bool get isAvailable => Platform.isIOS || Platform.isAndroid;
}
