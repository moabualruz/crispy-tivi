import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native AirPlay implementation for iOS and macOS.
///
/// Uses platform channel to communicate with native Swift code that
/// manages AVPlayer and AVRoutePickerView for AirPlay streaming.
///
/// On non-Apple platforms, this class reports [isSupported] as false
/// and all operations are no-ops.
class AirPlayHelper {
  static const _channel = MethodChannel('crispy_tivi/airplay');

  bool _isConnected = false;
  void Function(bool)? _onConnectionChanged;

  /// Creates an AirPlay helper and sets up the method call handler.
  AirPlayHelper() {
    if (isSupported) {
      _channel.setMethodCallHandler(_handleMethodCall);
    }
  }

  /// Whether AirPlay is supported on this platform.
  ///
  /// Returns true only on iOS and macOS.
  bool get isSupported => Platform.isIOS || Platform.isMacOS;

  /// Whether currently connected to an AirPlay device.
  bool get isConnected => _isConnected;

  /// Sets the callback for connection state changes.
  // ignore: use_setters_to_change_properties
  void setOnConnectionChanged(void Function(bool)? callback) {
    _onConnectionChanged = callback;
  }

  /// Handles method calls from native code.
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onConnected':
        _isConnected = true;
        _onConnectionChanged?.call(true);
        debugPrint('AirPlay: Connected to device');
      case 'onDisconnected':
        _isConnected = false;
        _onConnectionChanged?.call(false);
        debugPrint('AirPlay: Disconnected from device');
      case 'onPlaybackStateChanged':
        final isPlaying = call.arguments as bool?;
        debugPrint('AirPlay: Playback state changed: $isPlaying');
      case 'onError':
        final error = call.arguments as String?;
        debugPrint('AirPlay: Error: $error');
    }
  }

  /// Shows the native AirPlay device picker.
  ///
  /// On iOS/macOS, this presents the system AVRoutePickerView which
  /// allows the user to select an AirPlay target (Apple TV, HomePod, etc).
  Future<void> showPicker() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('showPicker');
    } on PlatformException catch (e) {
      debugPrint('AirPlay: Failed to show picker: ${e.message}');
    }
  }

  /// Plays a media URL on the connected AirPlay device.
  ///
  /// Returns true if playback started successfully, false otherwise.
  /// The [title] is used for Now Playing metadata on the device.
  Future<bool> playUrl(String url, {String? title}) async {
    if (!isSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>('playUrl', {
        'url': url,
        'title': title ?? 'CrispyTivi',
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('AirPlay: Failed to play URL: ${e.message}');
      return false;
    }
  }

  /// Pauses playback on the AirPlay device.
  void pause() {
    if (!isSupported) return;
    _channel.invokeMethod<void>('pause').catchError((e) {
      debugPrint('AirPlay: Failed to pause: $e');
    });
  }

  /// Resumes playback on the AirPlay device.
  void resume() {
    if (!isSupported) return;
    _channel.invokeMethod<void>('resume').catchError((e) {
      debugPrint('AirPlay: Failed to resume: $e');
    });
  }

  /// Stops playback on the AirPlay device.
  void stop() {
    if (!isSupported) return;
    _channel.invokeMethod<void>('stop').catchError((e) {
      debugPrint('AirPlay: Failed to stop: $e');
    });
  }

  /// Disconnects from the AirPlay device.
  void disconnect() {
    if (!isSupported) return;
    _channel.invokeMethod<void>('disconnect').catchError((e) {
      debugPrint('AirPlay: Failed to disconnect: $e');
    });
    _isConnected = false;
    _onConnectionChanged?.call(false);
  }

  /// Cleans up resources.
  void dispose() {
    _onConnectionChanged = null;
    if (isSupported) {
      _channel.setMethodCallHandler(null);
    }
  }
}
