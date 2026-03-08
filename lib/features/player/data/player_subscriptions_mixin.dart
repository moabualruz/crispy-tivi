part of 'player_service.dart';

/// media_kit stream subscriptions and error handling.
///
/// Subscribes to [Player.stream] events and maps them
/// to [PlaybackState] updates via [_updateState].
mixin PlayerSubscriptionsMixin on PlayerServiceBase {
  Timer? _bufferingDebounce;
  static const _bufferingWindow = Duration(milliseconds: 200);

  /// Subscribes to all media_kit player streams.
  void initSubscriptions() {
    // XP-02: Configure audio session on all native
    // platforms (iOS, Android, macOS). Fire-and-forget.
    if (!kIsWeb) {
      unawaited(_initAudioSession());
    }

    // On web, state comes entirely from WebVideoBridge.
    // media_kit Player is never opened, so its streams
    // emit idle/false values that corrupt web state.
    if (kIsWeb) return;

    _subs.add(
      _player.stream.playing.listen((playing) {
        if (playing) {
          _retryCount = 0;
          _bufferingDebounce?.cancel();
          _bufferingDebounce = null;
          _updateState(status: app.PlaybackStatus.playing);
        } else {
          _updateState(status: app.PlaybackStatus.paused);
        }
      }),
    );

    _subs.add(
      _player.stream.position.listen((pos) {
        _updateState(position: pos);
      }),
    );

    _subs.add(
      _player.stream.duration.listen((dur) {
        _updateState(duration: dur);
      }),
    );

    _subs.add(
      _player.stream.buffer.listen((buf) {
        _updateState(bufferedPosition: buf);
      }),
    );

    _subs.add(
      _player.stream.buffering.listen((isBuffering) {
        if (isBuffering) {
          // Debounce: only promote to buffering after
          // 200ms stability — sub-250ms oscillations
          // are invisible to users (VLC/Kodi pattern).
          _bufferingDebounce ??= Timer(_bufferingWindow, () {
            _bufferingDebounce = null;
            if (_state.status != app.PlaybackStatus.playing) {
              _updateState(status: app.PlaybackStatus.buffering);
            }
          });
        } else {
          _bufferingDebounce?.cancel();
          _bufferingDebounce = null;
          if (_player.state.playing) {
            _updateState(status: app.PlaybackStatus.playing);
          }
        }
      }),
    );

    _subs.add(
      _player.stream.volume.listen((vol) {
        _updateState(volume: vol / 100.0);
      }),
    );

    _subs.add(
      _player.stream.rate.listen((rate) {
        _updateState(speed: rate);
      }),
    );

    _subs.add(
      _player.stream.error.listen((error) {
        _handleError(error);
      }),
    );

    // Populate PlaybackState.audioTracks /
    // subtitleTracks from media_kit on native.
    // Web tracks come via _onWebVideoState instead.
    _subs.add(
      _player.stream.tracks.listen((tracks) {
        if (_webBridge != null) return;

        final audio =
            tracks.audio
                .where((t) => t.id != 'auto' && t.id != 'no')
                .toList()
                .asMap()
                .entries
                .map(
                  (e) => app.AudioTrack(
                    id: e.key,
                    title:
                        e.value.title ??
                        e.value.language ??
                        'Track ${e.key + 1}',
                    language: e.value.language,
                  ),
                )
                .toList();

        final subs =
            tracks.subtitle
                .where((t) => t.id != 'auto' && t.id != 'no')
                .toList()
                .asMap()
                .entries
                .map(
                  (e) => app.SubtitleTrack(
                    id: e.key,
                    title:
                        e.value.title ??
                        e.value.language ??
                        'Subtitle ${e.key + 1}',
                    language: e.value.language,
                  ),
                )
                .toList();

        _updateState(audioTracks: audio, subtitleTracks: subs);
      }),
    );

    // Video resolution change — apply upscaling when
    // video dimensions are detected or change (e.g.
    // IPTV channel switch with different resolution).
    _subs.add(
      _player.stream.width.listen((width) {
        if (width != null && width > 0) {
          applyUpscale();
        }
      }),
    );
  }

  /// Configures the platform audio session and listens
  /// for audio interruptions (phone calls, Siri, etc.).
  ///
  /// On interruption begin: pauses playback.
  /// On interruption end (type == pause): resumes.
  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionMode: AVAudioSessionMode.moviePlayback,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.movie,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        ),
      );

      _subs.add(
        session.interruptionEventStream.listen((event) {
          if (event.begin) {
            // Audio focus lost — pause if playing.
            if (_state.status == app.PlaybackStatus.playing) {
              _autoPausedByInterruption = true;
              pause();
            }
          } else {
            // Audio focus regained — resume if we auto-paused.
            if (_autoPausedByInterruption &&
                event.type == AudioInterruptionType.pause) {
              _autoPausedByInterruption = false;
              resume();
            }
          }
        }),
      );
    } catch (e) {
      // audio_session unavailable (tests, unsupported platform).
      debugPrint('PlayerService: audio session init failed: $e');
    }
  }

  /// Handles playback errors with automatic reconnection
  /// for live streams.
  void _handleError(String error) {
    debugPrint(
      'PlayerService: error on '
      '${_lastIsLive ? "live" : "vod"} stream: $error '
      '(retry $_retryCount/'
      '${PlayerServiceBase.maxRetries})',
    );

    if (_lastIsLive && _retryCount < PlayerServiceBase.maxRetries) {
      _retryCount++;
      debugPrint(
        'PlayerService: auto-retry '
        '$_retryCount/${PlayerServiceBase.maxRetries} '
        'in ${PlayerServiceBase.retryDelay.inSeconds}s',
      );
      _updateState(
        status: app.PlaybackStatus.buffering,
        retryCount: _retryCount,
      );
      _retryTimer?.cancel();
      _retryTimer = Timer(PlayerServiceBase.retryDelay, () {
        if (_lastUrl != null) {
          openMedia(_lastUrl!, isLive: true);
        }
      });
    } else {
      _updateState(status: app.PlaybackStatus.error, errorMessage: error);
    }
  }
}
