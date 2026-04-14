import 'dart:async';

import 'package:crispy_tivi/features/shell/data/playback_session_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/playback_target.dart';
import 'package:crispy_tivi/features/shell/domain/player_session.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

typedef PlayerPlaybackProgressCallback =
    void Function({required Duration position, Duration? duration});

class PlayerPlaybackController extends ChangeNotifier {
  PlayerPlaybackController({
    PlayerPlaybackProgressCallback? onPlaybackProgress,
    PlaybackSessionRuntimeRepository? playbackSessionRuntimeRepository,
  }) : _onPlaybackProgress = onPlaybackProgress ?? _noopProgress,
       _playbackSessionRuntimeRepository =
           playbackSessionRuntimeRepository ??
           const RustPlaybackSessionRuntimeRepository();

  final PlayerPlaybackProgressCallback _onPlaybackProgress;
  final PlaybackSessionRuntimeRepository _playbackSessionRuntimeRepository;

  Player? _player;
  VideoController? _videoController;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  PlayerSession? _session;
  Duration? _latestDuration;
  String? _loadedUri;
  bool _backendReady = false;

  bool get backendReady => _backendReady;
  VideoController? get videoController => _videoController;
  String? get loadedUri => _loadedUri;

  Future<void> syncSession(PlayerSession? session) async {
    _session = session;
    final String? uri =
        session == null
            ? null
            : _playbackSessionRuntimeRepository.resolvedPlaybackUriForSession(
              session,
            );
    if (uri == null || uri.isEmpty) {
      await clear();
      return;
    }
    if (_player == null || _videoController == null) {
      await _bootstrap(uri);
      return;
    }
    if (_loadedUri != uri) {
      await _load(uri);
      return;
    }
    await _applyTrackSelections();
  }

  Future<void> clear() async {
    final Player? player = _player;
    _session = null;
    _loadedUri = null;
    _latestDuration = null;
    _player = null;
    _videoController = null;
    final bool changed = _backendReady;
    _backendReady = false;
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    _positionSubscription = null;
    _durationSubscription = null;
    if (player != null) {
      await player.dispose();
    }
    if (changed) {
      notifyListeners();
    }
  }

  Future<void> _bootstrap(String uri) async {
    if (!_isHttpPlaybackUri(uri)) {
      final PlayerSession? session = _session;
      await clear();
      _session = session;
      _loadedUri = uri;
      _backendReady = true;
      notifyListeners();
      return;
    }
    await clear();
    try {
      MediaKit.ensureInitialized();
      final Player player = Player();
      final VideoController controller = VideoController(player);
      _player = player;
      _videoController = controller;
      _positionSubscription = player.stream.position.listen((Duration value) {
        _onPlaybackProgress(position: value, duration: _latestDuration);
      });
      _durationSubscription = player.stream.duration.listen((Duration value) {
        _latestDuration = value;
      });
      _backendReady = true;
      notifyListeners();
      await _load(uri);
    } catch (_) {
      await clear();
    }
  }

  bool _isHttpPlaybackUri(String uri) {
    final Uri? parsed = Uri.tryParse(uri);
    if (parsed == null) {
      return false;
    }
    return parsed.scheme == 'http' || parsed.scheme == 'https';
  }

  Future<void> _load(String uri) async {
    final Player? player = _player;
    if (player == null) {
      return;
    }
    _loadedUri = uri;
    try {
      await player.open(Media(uri), play: true);
      await _applyTrackSelections();
    } catch (_) {
      // Keep the player chrome usable even if backend playback fails.
    }
    notifyListeners();
  }

  Future<void> _applyTrackSelections() async {
    final Player? player = _player;
    final PlayerSession? session = _session;
    if (player == null || session == null) {
      return;
    }
    final PlaybackTrackOptionSnapshot? audio = _playbackSessionRuntimeRepository
        .selectedTrackOptionForSession(session, PlayerChooserKind.audio);
    final PlaybackTrackOptionSnapshot? subtitles =
        _playbackSessionRuntimeRepository.selectedTrackOptionForSession(
          session,
          PlayerChooserKind.subtitles,
        );
    try {
      if (audio != null) {
        await player.setAudioTrack(_audioTrackForOption(audio));
      }
      if (subtitles != null) {
        await player.setSubtitleTrack(_subtitleTrackForOption(subtitles));
      }
    } catch (_) {
      // Track switching can fail per-stream; keep playback alive.
    }
  }

  AudioTrack _audioTrackForOption(PlaybackTrackOptionSnapshot option) {
    return switch (option.id) {
      'auto' => AudioTrack.auto(),
      'off' => AudioTrack.no(),
      _ when option.uri.isNotEmpty => AudioTrack.uri(
        option.uri,
        title: option.label,
        language: option.language,
      ),
      _ => AudioTrack(option.id, option.label, option.language),
    };
  }

  SubtitleTrack _subtitleTrackForOption(PlaybackTrackOptionSnapshot option) {
    return switch (option.id) {
      'auto' => SubtitleTrack.auto(),
      'off' => SubtitleTrack.no(),
      _ when option.uri.isNotEmpty => SubtitleTrack.uri(
        option.uri,
        title: option.label,
        language: option.language,
      ),
      _ => SubtitleTrack(option.id, option.label, option.language),
    };
  }

  @override
  void dispose() {
    final Player? player = _player;
    _session = null;
    _loadedUri = null;
    _latestDuration = null;
    _player = null;
    _videoController = null;
    _backendReady = false;
    final StreamSubscription<Duration>? positionSubscription =
        _positionSubscription;
    final StreamSubscription<Duration>? durationSubscription =
        _durationSubscription;
    _positionSubscription = null;
    _durationSubscription = null;
    unawaited(positionSubscription?.cancel());
    unawaited(durationSubscription?.cancel());
    if (player != null) {
      unawaited(player.dispose());
    }
    super.dispose();
  }
}

void _noopProgress({required Duration position, Duration? duration}) {}
