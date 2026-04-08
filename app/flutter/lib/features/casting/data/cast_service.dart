import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cast_helper.dart';

/// Duration before cast discovery times out.
const _kDiscoveryTimeout = Duration(seconds: 10);

/// Google Cast / Chromecast integration service.
///
/// Provides device discovery, session management, and
/// media control for casting stream URLs to external
/// devices.
/// Uses [CastHelper] for platform-specific Cast protocol
/// implementation.
class CastService extends Notifier<CastState> {
  final CastHelper _helper = CastHelper();
  Timer? _timeoutTimer;

  @override
  CastState build() {
    ref.onDispose(() {
      _timeoutTimer?.cancel();
      _timeoutTimer = null;
      _helper.stopDiscovery();
    });
    return const CastState();
  }

  /// Starts scanning for Cast devices on the local
  /// network.
  ///
  /// Uses mDNS discovery via dart_chromecast on native
  /// platforms. On web, reports no devices (Cast not
  /// supported). After [_kDiscoveryTimeout] with no
  /// devices, sets [CastState.timedOut] to true.
  void startDiscovery() {
    _timeoutTimer?.cancel();
    state = state.copyWith(
      isScanning: true,
      devices: [],
      scanStartedAt: DateTime.now(),
      clearError: true,
      timedOut: false,
    );

    _timeoutTimer = Timer(_kDiscoveryTimeout, () {
      try {
        if (state.isScanning && state.devices.isEmpty) {
          state = state.copyWith(isScanning: false, timedOut: true);
        }
      } catch (_) {
        // Notifier was disposed — ignore.
      }
    });

    _helper
        .startDiscovery((devices) {
          // Guard against disposed notifier.
          try {
            // If we already timed out, ignore late
            // callbacks.
            if (!state.isScanning && state.timedOut) return;

            _timeoutTimer?.cancel();
            state = state.copyWith(
              isScanning: devices.isEmpty,
              timedOut: false,
              devices:
                  devices
                      .map(
                        (d) => CastDevice(
                          id: '${d.host}:${d.port}',
                          name: d.name,
                          model: 'Chromecast',
                          host: d.host,
                          port: d.port,
                        ),
                      )
                      .toList(),
            );
          } catch (_) {
            // Notifier was disposed — ignore.
          }
        })
        .catchError((Object error) {
          _timeoutTimer?.cancel();
          try {
            state = state.copyWith(
              isScanning: false,
              errorMessage: _friendlyError(error),
            );
          } catch (_) {
            // Notifier was disposed — ignore.
          }
        });
  }

  /// Stops scanning for devices.
  void stopDiscovery() {
    _timeoutTimer?.cancel();
    _helper.stopDiscovery();
    state = state.copyWith(isScanning: false);
  }

  /// Retries device discovery from scratch.
  void retryDiscovery() {
    stopDiscovery();
    startDiscovery();
  }

  /// Connects to a Cast device by its ID.
  ///
  /// Returns true if connection was successful.
  Future<bool> connectToDevice(String deviceId, {int retries = 1}) async {
    final device = state.devices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => throw StateError('Device not found'),
    );

    state = state.copyWith(sessionState: CastSessionState.connecting);

    for (var attempt = 0; attempt <= retries; attempt++) {
      final success = await _helper.connect(device.host, device.port);
      if (success) {
        state = state.copyWith(
          connectedDevice: device,
          sessionState: CastSessionState.connected,
        );
        return true;
      }
      // Wait briefly before retry.
      if (attempt < retries) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }

    state = state.copyWith(sessionState: CastSessionState.idle);
    return false;
  }

  /// Disconnects from the current device.
  void disconnect() {
    _helper.disconnect();
    state = state.copyWith(
      connectedDevice: null,
      sessionState: CastSessionState.idle,
      clearDevice: true,
    );
  }

  /// Sends a media URL to the connected device.
  ///
  /// The [streamUrl] must be accessible from the Cast
  /// device (not a local file path).
  Future<void> castMedia({
    required String streamUrl,
    required String title,
    String? thumbnailUrl,
  }) async {
    if (state.connectedDevice == null || !_helper.isConnected) {
      return;
    }

    final success = await _helper.loadMedia(streamUrl, title);
    if (success) {
      state = state.copyWith(
        currentMedia: CastMedia(
          streamUrl: streamUrl,
          title: title,
          thumbnailUrl: thumbnailUrl,
        ),
        sessionState: CastSessionState.playing,
      );
    }
  }

  /// Pauses playback on the Cast device.
  void pauseCast() {
    _helper.pause();
    state = state.copyWith(sessionState: CastSessionState.paused);
  }

  /// Resumes playback on the Cast device.
  void resumeCast() {
    _helper.resume();
    state = state.copyWith(sessionState: CastSessionState.playing);
  }

  /// Stops playback but keeps the connection.
  void stopCast() {
    _helper.stop();
    state = state.copyWith(
      currentMedia: null,
      sessionState: CastSessionState.connected,
      clearMedia: true,
    );
  }

  /// Maps raw errors to user-friendly messages.
  String _friendlyError(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('permission') || msg.contains('denied')) {
      return 'Network permission denied. '
          'Check your firewall settings.';
    }
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('unreachable')) {
      return 'Network error. '
          'Check your Wi-Fi connection.';
    }
    return 'Cast discovery failed: $error';
  }
}

/// Cast device discovered on the network.
class CastDevice {
  /// Creates a [CastDevice].
  const CastDevice({
    required this.id,
    required this.name,
    this.model,
    required this.host,
    required this.port,
  });

  /// Unique identifier (host:port).
  final String id;

  /// Display name of the device.
  final String name;

  /// Device model (e.g., "Chromecast",
  /// "Chromecast Ultra").
  final String? model;

  /// IP address or hostname.
  final String host;

  /// Port number for Cast protocol.
  final int port;
}

/// Media being cast.
class CastMedia {
  /// Creates a [CastMedia].
  const CastMedia({
    required this.streamUrl,
    required this.title,
    this.thumbnailUrl,
  });

  /// Stream URL of the media.
  final String streamUrl;

  /// Display title of the media.
  final String title;

  /// Optional thumbnail URL.
  final String? thumbnailUrl;
}

/// Session state for a Cast connection.
enum CastSessionState {
  /// No active session.
  idle,

  /// Currently connecting to a device.
  connecting,

  /// Connected but not playing.
  connected,

  /// Currently playing media.
  playing,

  /// Playback paused.
  paused,
}

/// Immutable state for [CastService].
class CastState {
  /// Creates a [CastState].
  const CastState({
    this.devices = const [],
    this.isScanning = false,
    this.connectedDevice,
    this.currentMedia,
    this.sessionState = CastSessionState.idle,
    this.scanStartedAt,
    this.errorMessage,
    this.timedOut = false,
  });

  /// Discovered devices on the network.
  final List<CastDevice> devices;

  /// Whether discovery is actively scanning.
  final bool isScanning;

  /// Currently connected device, if any.
  final CastDevice? connectedDevice;

  /// Media currently being cast, if any.
  final CastMedia? currentMedia;

  /// Session state.
  final CastSessionState sessionState;

  /// When the current scan started (for elapsed time).
  final DateTime? scanStartedAt;

  /// Error message from last discovery attempt.
  final String? errorMessage;

  /// Whether the last scan timed out with no devices.
  final bool timedOut;

  /// Whether the Cast session is active.
  bool get isConnected =>
      sessionState != CastSessionState.idle &&
      sessionState != CastSessionState.connecting;

  /// Creates a copy with the given fields replaced.
  CastState copyWith({
    List<CastDevice>? devices,
    bool? isScanning,
    CastDevice? connectedDevice,
    CastMedia? currentMedia,
    CastSessionState? sessionState,
    DateTime? scanStartedAt,
    String? errorMessage,
    bool? timedOut,
    bool clearDevice = false,
    bool clearMedia = false,
    bool clearError = false,
  }) {
    return CastState(
      devices: devices ?? this.devices,
      isScanning: isScanning ?? this.isScanning,
      connectedDevice:
          clearDevice ? null : (connectedDevice ?? this.connectedDevice),
      currentMedia: clearMedia ? null : (currentMedia ?? this.currentMedia),
      sessionState: sessionState ?? this.sessionState,
      scanStartedAt: scanStartedAt ?? this.scanStartedAt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      timedOut: timedOut ?? this.timedOut,
    );
  }
}

/// Provider for the [CastService].
final castServiceProvider = NotifierProvider<CastService, CastState>(
  CastService.new,
);
