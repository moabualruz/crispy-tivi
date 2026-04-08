/// Stub implementation for platforms that don't support AirPlay.
///
/// Used on Web and as fallback. All methods are no-ops that return
/// appropriate defaults indicating AirPlay is unavailable.
class AirPlayHelper {
  /// AirPlay is not supported on this platform.
  bool get isSupported => false;

  /// Always returns false on unsupported platforms.
  bool get isConnected => false;

  /// Callback for connection state changes (never called on stub).
  // ignore: use_setters_to_change_properties
  void setOnConnectionChanged(void Function(bool)? callback) {}

  /// No-op on unsupported platforms.
  Future<void> showPicker() async {}

  /// Always returns false on unsupported platforms.
  Future<bool> playUrl(String url, {String? title}) async => false;

  /// No-op on unsupported platforms.
  void pause() {}

  /// No-op on unsupported platforms.
  void resume() {}

  /// No-op on unsupported platforms.
  void stop() {}

  /// No-op on unsupported platforms.
  void disconnect() {}

  /// No-op cleanup.
  void dispose() {}
}
