part of 'player_service.dart';

/// Player stream subscriptions and error handling.
///
/// Subscribes to [CrispyPlayer] stream events and maps
/// them to [PlaybackState] updates via [_updateState].
mixin PlayerSubscriptionsMixin on PlayerServiceBase {
  Timer? _bufferingDebounce;
  static const _bufferingWindow = Duration(milliseconds: 200);

  /// Subscribes to all [CrispyPlayer] streams.
  void initSubscriptions() {
    // XP-02: Configure audio session on all native
    // platforms (iOS, Android, macOS). Fire-and-forget.
    if (!kIsWeb) {
      unawaited(_initAudioSession());
    }

    // On web, state comes entirely from WebVideoBridge.
    // CrispyPlayer is never opened, so its streams
    // emit idle/false values that corrupt web state.
    if (kIsWeb) return;

    _subs.add(
      _player.playingStream.listen((playing) {
        if (playing) {
          _retryCount = 0;
          _bufferingDebounce?.cancel();
          _bufferingDebounce = null;
          _updateState(status: app.PlaybackStatus.playing);
        } else {
          _updateState(status: app.PlaybackStatus.paused);
        }
        // Sync play/pause state to OS media controls.
        unawaited(_mediaSession.updatePlaybackState(playing, _state.position));
      }),
    );

    // Listen for OS media transport actions.
    _subs.add(
      _mediaSession.actions.listen((action) {
        switch (action) {
          case MediaAction.play:
            resume();
          case MediaAction.pause:
            pause();
          case MediaAction.stop:
            stop();
          case MediaAction.next:
          case MediaAction.previous:
            // Channel zap not wired here — the player
            // screen handles next/prev via its own
            // callbacks.
            break;
        }
      }),
    );

    _subs.add(
      _player.positionStream.listen((pos) {
        _updateState(position: pos);
      }),
    );

    _subs.add(
      _player.durationStream.listen((dur) {
        _updateState(duration: dur);
      }),
    );

    _subs.add(
      _player.bufferStream.listen((buf) {
        _updateState(bufferedPosition: buf);
      }),
    );

    _subs.add(
      _player.bufferingStream.listen((isBuffering) {
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
          if (_player.isPlaying) {
            _updateState(status: app.PlaybackStatus.playing);
          }
        }
      }),
    );

    _subs.add(
      _player.volumeStream.listen((vol) {
        _updateState(volume: vol);
      }),
    );

    _subs.add(
      _player.rateStream.listen((rate) {
        _updateState(speed: rate);
      }),
    );

    _subs.add(
      _player.errorStream.listen((error) {
        if (error != null) _handleError(error);
      }),
    );

    // Populate PlaybackState.audioTracks /
    // subtitleTracks from CrispyPlayer on native.
    // Web tracks come via _onWebVideoState instead.
    // Also triggers upscale re-evaluation on media
    // load (replaces the former width stream).
    _subs.add(
      _player.tracksStream.listen((trackList) {
        if (_webBridge != null) return;

        final audio =
            trackList.audio
                .map(
                  (t) => app.AudioTrack(
                    id: t.index,
                    title: t.title,
                    language: t.language,
                  ),
                )
                .toList();

        final subs =
            trackList.subtitle
                .map(
                  (t) => app.SubtitleTrack(
                    id: t.index,
                    title: t.title,
                    language: t.language,
                  ),
                )
                .toList();

        _updateState(audioTracks: audio, subtitleTracks: subs);
        applyUpscale();
      }),
    );
  }

  /// Schedules an audio track detection check 3 seconds after
  /// playback starts.
  ///
  /// If no real audio tracks are detected and the URL hasn't been
  /// proxy-retried, triggers a retry through the local ffmpeg proxy
  /// (codec repair for non-standard EAC-3 tags).
  void _scheduleAudioCheck(String originalUrl) {
    _audioCheckTimer?.cancel();
    if (kIsWeb) return;

    _audioCheckTimer = Timer(const Duration(seconds: 3), () {
      if (_proxyActive || _lastUrl != originalUrl) return;
      if (_proxyRetriedUrls.contains(originalUrl)) return;

      final tracks = _state.audioTracks;
      if (tracks.isNotEmpty) return;

      if (kDebugMode) {
        debugPrint(
          '[Player] No audio tracks after 3s, '
          'trying ffmpeg proxy for $originalUrl',
        );
      }
      _retryWithProxy(originalUrl);
    });
  }

  /// Re-opens the stream through the local ffmpeg proxy.
  Future<void> _retryWithProxy(String originalUrl) async {
    if (_proxyActive) return;
    _proxyRetriedUrls.add(originalUrl);

    final proxyUrl = await _streamProxy.start(originalUrl);
    if (proxyUrl == null) {
      if (kDebugMode) {
        debugPrint(
          '[Player] ffmpeg proxy unavailable, '
          'keeping direct playback',
        );
      }
      return;
    }

    _proxyActive = true;
    if (kDebugMode) {
      debugPrint('[Player] Switching to proxied stream: $proxyUrl');
    }
    await openMedia(proxyUrl, isLive: _lastIsLive);
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
