import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:smtc_windows/smtc_windows.dart';
import 'package:universal_io/io.dart';

/// Actions received from OS media transport controls.
enum MediaAction { play, pause, stop, next, previous }

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

  /// Stream of transport actions from OS media controls.
  Stream<MediaAction> get actions => _actionsController.stream;

  _CrispyAudioHandler? _audioHandler;
  SMTCWindows? _smtc;
  StreamSubscription<PressedButton>? _smtcSub;
  bool _initialized = false;

  /// Whether this session uses the Windows SMTC backend.
  bool get _isWindows => !kIsWeb && Platform.isWindows;

  /// Register or update the OS media session with metadata.
  Future<void> activate({
    required String title,
    String? artist,
    String? artUrl,
    Duration? duration,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await _init();

    if (_isWindows) {
      await _smtc?.updateMetadata(
        MusicMetadata(title: title, artist: artist ?? '', thumbnail: artUrl),
      );
      await _smtc?.enableSmtc();
      await _smtc?.setPlaybackStatus(PlaybackStatus.playing);
    } else {
      _audioHandler?.mediaItem.add(
        MediaItem(
          id: 'crispy_tivi_playback',
          title: title,
          artist: artist,
          artUri: artUrl != null ? Uri.tryParse(artUrl) : null,
          duration: duration,
        ),
      );
    }
  }

  /// Sync playback state with OS media controls.
  Future<void> updatePlaybackState(bool isPlaying, Duration position) async {
    if (kIsWeb) return;

    if (_isWindows) {
      await _smtc?.setPlaybackStatus(
        isPlaying ? PlaybackStatus.playing : PlaybackStatus.paused,
      );
    } else if (_audioHandler != null) {
      _audioHandler!.playbackState.add(
        PlaybackState(
          controls: [
            MediaControl.skipToPrevious,
            if (isPlaying) MediaControl.pause else MediaControl.play,
            MediaControl.stop,
            MediaControl.skipToNext,
          ],
          androidCompactActionIndices: const [0, 1, 3],
          processingState: AudioProcessingState.ready,
          playing: isPlaying,
          updatePosition: position,
          updateTime: DateTime.now(),
        ),
      );
    }
  }

  /// Release the OS media session.
  Future<void> deactivate() async {
    if (kIsWeb) return;

    if (_isWindows) {
      await _smtc?.clearMetadata();
      await _smtc?.disableSmtc();
    } else if (_audioHandler != null) {
      _audioHandler!.playbackState.add(PlaybackState());
      _audioHandler!.mediaItem.add(null);
    }
  }

  /// Clean up all resources.
  Future<void> dispose() async {
    await deactivate();
    await _smtcSub?.cancel();
    await _smtc?.dispose();
    await _actionsController.close();
  }

  // ── Private ────────────────────────────────────────

  Future<void> _init() async {
    try {
      if (_isWindows) {
        await _initSmtc();
      } else {
        await _initAudioService();
      }
      _initialized = true;
    } catch (e) {
      debugPrint('OsMediaSession: init failed: $e');
    }
  }

  Future<void> _initSmtc() async {
    await SMTCWindows.initialize();
    final smtc = SMTCWindows(
      config: const SMTCConfig(
        fastForwardEnabled: false,
        nextEnabled: true,
        pauseEnabled: true,
        playEnabled: true,
        rewindEnabled: false,
        prevEnabled: true,
        stopEnabled: true,
      ),
    );
    _smtc = smtc;
    _smtcSub = smtc.buttonPressStream.listen((event) {
      switch (event) {
        case PressedButton.play:
          _actionsController.add(MediaAction.play);
        case PressedButton.pause:
          _actionsController.add(MediaAction.pause);
        case PressedButton.stop:
          _actionsController.add(MediaAction.stop);
        case PressedButton.next:
          _actionsController.add(MediaAction.next);
        case PressedButton.previous:
          _actionsController.add(MediaAction.previous);
        default:
          break;
      }
    });
  }

  Future<void> _initAudioService() async {
    _audioHandler = _CrispyAudioHandler(_actionsController);
    await AudioService.init(
      builder: () => _audioHandler!,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.crispy.tivi.playback',
        androidNotificationChannelName: 'Video playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  }
}

/// Internal audio handler for `audio_service`.
///
/// Forwards OS media button events to the parent
/// [OsMediaSession] via a shared [StreamController].
class _CrispyAudioHandler extends BaseAudioHandler {
  _CrispyAudioHandler(this._actions);

  final StreamController<MediaAction> _actions;

  @override
  Future<void> play() async => _actions.add(MediaAction.play);

  @override
  Future<void> pause() async => _actions.add(MediaAction.pause);

  @override
  Future<void> stop() async {
    _actions.add(MediaAction.stop);
    await super.stop();
  }

  @override
  Future<void> skipToNext() async => _actions.add(MediaAction.next);

  @override
  Future<void> skipToPrevious() async => _actions.add(MediaAction.previous);
}
