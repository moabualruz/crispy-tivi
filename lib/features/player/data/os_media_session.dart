import 'dart:async';

import 'os_media_session_web.dart'
    if (dart.library.io) 'os_media_session_native.dart';

/// Actions received from OS media transport controls.
enum MediaAction { play, pause, stop, next, previous }

/// Platform-specific OS media session backend.
///
/// Implemented by [_NativeMediaSession] (native) and
/// [_WebMediaSession] (web no-op).
abstract class OsMediaSessionPlatform {
  bool get isInitialized;

  Future<void> init(StreamController<MediaAction> actions);

  Future<void> activate({
    required String title,
    String? artist,
    String? artUrl,
    Duration? duration,
  });

  Future<void> updatePlaybackState(bool isPlaying, Duration position);

  Future<void> deactivate();

  Future<void> dispose();
}

/// Manages OS-level media session for system transport
/// controls.
///
/// Integrates with platform-specific APIs:
/// - **Windows**: SMTC via `smtc_windows`
/// - **Android/iOS/macOS/Linux**: via `audio_service`
/// - **Web**: no-op
///
/// Call [activate] when playback starts, [updatePlaybackState]
/// on play/pause/position changes, and [deactivate] when
/// playback stops.
class OsMediaSession {
  OsMediaSession();

  final _actionsController = StreamController<MediaAction>.broadcast();
  late final OsMediaSessionPlatform _platform = createPlatformSession();

  /// Stream of transport actions from OS media controls.
  Stream<MediaAction> get actions => _actionsController.stream;

  /// Register or update the OS media session with metadata.
  Future<void> activate({
    required String title,
    String? artist,
    String? artUrl,
    Duration? duration,
  }) async {
    if (!_platform.isInitialized) {
      await _platform.init(_actionsController);
    }
    await _platform.activate(
      title: title,
      artist: artist,
      artUrl: artUrl,
      duration: duration,
    );
  }

  /// Sync playback state with OS media controls.
  Future<void> updatePlaybackState(bool isPlaying, Duration position) async {
    await _platform.updatePlaybackState(isPlaying, position);
  }

  /// Release the OS media session.
  Future<void> deactivate() async {
    await _platform.deactivate();
  }

  /// Clean up all resources.
  Future<void> dispose() async {
    await _platform.dispose();
    await _actionsController.close();
  }
}
