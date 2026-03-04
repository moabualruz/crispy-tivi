import 'package:flutter/foundation.dart';

/// Stub implementation for web/unsupported platforms.
///
/// Returns no-op results since casting requires native mDNS capabilities.
class CastHelper {
  /// Starts discovery for Cast devices.
  ///
  /// On unsupported platforms, this immediately calls [onDevices] with
  /// an empty list and logs a debug message.
  Future<void> startDiscovery(
    void Function(List<CastDeviceInfo>) onDevices,
  ) async {
    debugPrint('Cast: Platform not supported');
    onDevices([]);
  }

  /// Stops device discovery.
  void stopDiscovery() {}

  /// Attempts to connect to a Cast device.
  ///
  /// Returns false on unsupported platforms.
  Future<bool> connect(String host, int port) async => false;

  /// Loads media onto the connected device.
  ///
  /// Returns false on unsupported platforms.
  Future<bool> loadMedia(String url, String title) async => false;

  /// Pauses playback on the Cast device.
  void pause() {}

  /// Resumes playback on the Cast device.
  void resume() {}

  /// Stops playback on the Cast device.
  void stop() {}

  /// Disconnects from the Cast device.
  void disconnect() {}

  /// Whether currently connected to a Cast device.
  bool get isConnected => false;
}

/// Information about a discovered Cast device.
class CastDeviceInfo {
  const CastDeviceInfo({
    required this.name,
    required this.host,
    required this.port,
  });

  /// Display name of the device.
  final String name;

  /// IP address or hostname.
  final String host;

  /// Port number for Cast protocol.
  final int port;
}
