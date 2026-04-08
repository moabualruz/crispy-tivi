/// Stub PiP implementation for platforms without
/// conditional import resolution.
class PipImpl {
  /// Whether PiP is supported on this platform.
  bool get isSupported => false;

  /// Enter PiP mode. Returns (success, error).
  Future<(bool, String?)> enterPiP({int? width, int? height}) async => (
    false,
    null,
  );

  /// Exit PiP mode.
  Future<void> exitPiP() async {}

  /// Arm/disarm native auto-PiP for background entry.
  Future<void> setAutoPipReady({
    required bool ready,
    int? width,
    int? height,
  }) async {}

  /// Save PiP window bounds for restoration.
  Future<void> savePipBounds() async {}

  /// Called when native PiP state changes externally.
  void Function(bool isInPip)? onNativePipChanged;
}
