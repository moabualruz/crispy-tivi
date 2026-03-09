import 'dart:io';

/// Policy for when to hand off to the iOS PiP native player.
///
/// Unlike HDR (which is automatic based on content), PiP handoff
/// is always user-initiated (PiP button on OSD). This policy only
/// checks whether the platform supports PiP takeover.
///
/// Desktop PiP (Windows/Linux/macOS) uses window_manager-based PiP,
/// not this native player handoff. Android PiP uses the existing
/// `crispy/pip` MethodChannel in MainActivity.
class PipHandoffPolicy {
  /// Whether native PiP takeover is available on this device.
  ///
  /// Returns `true` only on iOS. The actual PiP support check
  /// (`AVPictureInPictureController.isPictureInPictureSupported()`)
  /// happens on the native side.
  bool get isAvailable => Platform.isIOS;
}
