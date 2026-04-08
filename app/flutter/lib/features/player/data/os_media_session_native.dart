import 'dart:async';

import 'package:audio_service/audio_service.dart' hide MediaAction;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:smtc_windows/smtc_windows.dart';
import 'package:universal_io/io.dart';

import 'os_media_session.dart';

/// Native implementation of [OsMediaSessionPlatform].
OsMediaSessionPlatform createPlatformSession() => _NativeMediaSession();

class _NativeMediaSession implements OsMediaSessionPlatform {
  _CrispyAudioHandler? _audioHandler;
  SMTCWindows? _smtc;
  StreamSubscription<PressedButton>? _smtcSub;
  bool _initialized = false;

  bool get _isWindows => Platform.isWindows;

  @override
  Future<void> init(StreamController<MediaAction> actions) async {
    try {
      if (_isWindows) {
        await _initSmtc(actions);
      } else {
        await _initAudioService(actions);
      }
      _initialized = true;
    } catch (e) {
      debugPrint('OsMediaSession: init failed: $e');
    }
  }

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> activate({
    required String title,
    String? artist,
    String? artUrl,
    Duration? duration,
  }) async {
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

  @override
  Future<void> updatePlaybackState(bool isPlaying, Duration position) async {
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

  @override
  Future<void> deactivate() async {
    if (_isWindows) {
      await _smtc?.clearMetadata();
      await _smtc?.disableSmtc();
    } else if (_audioHandler != null) {
      _audioHandler!.playbackState.add(PlaybackState());
      _audioHandler!.mediaItem.add(null);
    }
  }

  @override
  Future<void> dispose() async {
    await deactivate();
    await _smtcSub?.cancel();
    await _smtc?.dispose();
  }

  Future<void> _initSmtc(StreamController<MediaAction> actions) async {
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
          actions.add(MediaAction.play);
        case PressedButton.pause:
          actions.add(MediaAction.pause);
        case PressedButton.stop:
          actions.add(MediaAction.stop);
        case PressedButton.next:
          actions.add(MediaAction.next);
        case PressedButton.previous:
          actions.add(MediaAction.previous);
        default:
          break;
      }
    });
  }

  Future<void> _initAudioService(StreamController<MediaAction> actions) async {
    _audioHandler = _CrispyAudioHandler(actions);
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
