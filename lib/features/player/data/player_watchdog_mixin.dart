part of 'player_service.dart';

/// UI heartbeat watchdog for detecting frozen UI and stalled live streams.
///
/// Detects when the Flutter UI thread is blocked (e.g.
/// by synchronous I/O, expensive rebuilds) and
/// auto-pauses playback so audio doesn't continue while
/// the app is frozen ("zombie audio").
///
/// Also detects stalled live streams: when a live stream
/// is nominally playing but its position has not advanced
/// for [_stallThresholdTicks] × 2 s, a reconnect is
/// triggered automatically.
///
/// A periodic timer ticks every [_watchdogInterval].
/// Since Dart timers run on the event loop, a blocked
/// UI thread delays the callback. When the callback
/// fires late (elapsed > [_watchdogThreshold]),
/// playback is paused.
mixin PlayerWatchdogMixin on PlayerServiceBase {
  Timer? _watchdogTimer;
  late DateTime _lastHeartbeat = _clock();
  bool _autoPausedByWatchdog = false;

  // ── Stream stall detection ───────────────────────────
  Duration _lastKnownPosition = Duration.zero;
  int _stallTicks = 0;

  /// How often the heartbeat timer fires.
  static const _watchdogInterval = Duration(seconds: 2);

  /// If a tick arrives more than this late, a freeze
  /// occurred.
  static const _watchdogThreshold = Duration(seconds: 5);

  /// Number of consecutive ticks with no position
  /// advancement before triggering a stall reconnect.
  /// 5 × 2 s = 10 s stall threshold.
  static const int _stallThresholdTicks = 5;

  /// Whether playback was auto-paused by the watchdog.
  bool get wasAutoPausedByWatchdog => _autoPausedByWatchdog;

  /// Starts the UI heartbeat watchdog.
  ///
  /// Should be called when playback begins. The watchdog
  /// is automatically stopped on [stop] or [dispose].
  void startWatchdog() {
    _watchdogTimer?.cancel();
    _lastHeartbeat = _clock();
    _autoPausedByWatchdog = false;
    _lastKnownPosition = Duration.zero;
    _stallTicks = 0;
    _watchdogTimer = Timer.periodic(_watchdogInterval, (_) => _watchdogTick());
  }

  /// Stops the UI heartbeat watchdog.
  void stopWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _autoPausedByWatchdog = false;
    _lastKnownPosition = Duration.zero;
    _stallTicks = 0;
  }

  void _watchdogTick() {
    final now = _clock();
    final elapsed = now.difference(_lastHeartbeat);
    _lastHeartbeat = now;

    if (elapsed > _watchdogThreshold &&
        _state.status == app.PlaybackStatus.playing) {
      debugPrint(
        'PlayerService: UI freeze detected '
        '(${elapsed.inSeconds}s gap). Auto-pausing.',
      );
      _autoPausedByWatchdog = true;
      pause();
    }

    _checkStreamStall();
    _checkBufferHealth();
  }

  /// Reads `demuxer-cache-duration` from mpv and feeds it
  /// to the adaptive buffer manager. On tier change, applies
  /// the new readahead value without restarting the stream.
  ///
  /// Also forwards buffer samples to the warm failover
  /// engine for threshold evaluation.
  void _checkBufferHealth() {
    if (!_lastIsLive || kIsWeb) return;
    if (_state.status != app.PlaybackStatus.playing) return;

    final raw = _player.getProperty('demuxer-cache-duration');
    if (raw == null) return;
    final cacheDuration = double.tryParse(raw);
    if (cacheDuration == null) return;

    final url = _lastUrl;
    if (url == null) return;

    if (_bufferManager != null) {
      _bufferManager.onBufferUpdate(url, cacheDuration).then((newTier) {
        if (newTier != null) {
          _player.setProperty(
            'demuxer-readahead-secs',
            newTier.readaheadSecs.toString(),
          );
        }
      });
    }

    // Forward to warm failover for threshold evaluation.
    _warmFailover?.onBufferUpdate(cacheDuration);
  }

  /// Detects a live stream that has stopped advancing (stalled).
  ///
  /// When position has not changed for [_stallThresholdTicks] × 2 s
  /// while the stream is live and nominally playing, triggers a
  /// reconnect — the same path as an mpv error event.
  void _checkStreamStall() {
    if (!_lastIsLive || _state.status != app.PlaybackStatus.playing) {
      _stallTicks = 0;
      _lastKnownPosition = Duration.zero;
      return;
    }

    final currentPos = _player.position;
    if (currentPos == _lastKnownPosition) {
      _stallTicks++;
      if (_stallTicks >= _stallThresholdTicks) {
        _stallTicks = 0;
        _lastKnownPosition = Duration.zero;
        debugPrint(
          'PlayerService: live stream stalled for '
          '${_stallThresholdTicks * _watchdogInterval.inSeconds}s — '
          'reconnecting',
        );
        _reconnectDueToStall();
      }
    } else {
      _stallTicks = 0;
      _lastKnownPosition = currentPos;
    }
  }

  /// Triggers a reconnect for a stalled live stream.
  ///
  /// First checks the warm failover engine for a pre-buffered
  /// alternative. If available, switches to it for near-instant
  /// recovery. Otherwise falls back to standard reconnection.
  void _reconnectDueToStall() {
    if (_lastUrl == null) return;

    // Check warm failover for a pre-buffered alternative.
    final wf = _warmFailover;
    if (wf != null) {
      wf.onStreamStall().then((warmUrl) {
        if (warmUrl != null) {
          debugPrint('PlayerService: warm failover → $warmUrl');
          _retryCount = 0;
          openMedia(warmUrl, isLive: true);
          return;
        }
        _coldReconnect();
      });
    } else {
      _coldReconnect();
    }
  }

  /// Standard cold reconnect with retry delay.
  void _coldReconnect() {
    _retryCount = 0;
    _updateState(status: app.PlaybackStatus.buffering, retryCount: 0);
    _retryTimer?.cancel();
    _retryTimer = Timer(PlayerServiceBase.retryDelay, () {
      if (_lastUrl != null) openMedia(_lastUrl!, isLive: true);
    });
  }

  /// Resumes playback if it was auto-paused by the
  /// watchdog after a UI freeze.
  ///
  /// Call this from lifecycle or focus callbacks when
  /// the app becomes responsive again.
  void resumeFromWatchdog() {
    if (_autoPausedByWatchdog) {
      _autoPausedByWatchdog = false;
      resume();
      debugPrint(
        'PlayerService: Resumed from watchdog '
        'auto-pause.',
      );
    }
  }
}
