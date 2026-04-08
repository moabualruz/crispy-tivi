part of 'player_service.dart';

/// Sleep timer that stops playback after a duration.
///
/// While active, the remaining time is emitted every
/// second via [stateStream] so the OSD can show a
/// countdown.
mixin PlayerSleepTimerMixin on PlayerServiceBase {
  Timer? _sleepTimer;
  DateTime? _sleepTimerEndTime;

  /// How often the sleep-timer countdown ticks.
  static const _sleepTickInterval = Duration(seconds: 1);

  /// Returns the time when the sleep timer will fire,
  /// or `null` if no timer is active.
  DateTime? get sleepTimerEndTime => _sleepTimerEndTime;

  /// Sets a sleep timer that stops playback after
  /// [duration]. Passing [Duration.zero] cancels any
  /// active timer.
  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndTime = null;

    if (duration > Duration.zero) {
      _sleepTimerEndTime = _clock().add(duration);
      debugPrint('PlayerService: Sleep timer set for $duration');

      // Emit the initial remaining value immediately.
      _updateState(sleepTimerRemaining: duration);

      // Tick every second to update the countdown and
      // stop playback when it expires.
      _sleepTimer = Timer.periodic(
        _sleepTickInterval,
        (_) => _sleepTimerTick(),
      );
    } else {
      debugPrint('PlayerService: Sleep timer cancelled.');
      _updateState(clearSleepTimer: true);
    }
  }

  /// Cancels any active sleep timer and clears the
  /// countdown from the playback state.
  void cancelSleepTimer() {
    setSleepTimer(Duration.zero);
  }

  /// Periodic callback that updates the countdown and
  /// stops playback when the timer expires.
  void _sleepTimerTick() {
    final end = _sleepTimerEndTime;
    if (end == null) return;

    final remaining = end.difference(_clock());
    if (remaining <= Duration.zero) {
      debugPrint(
        'PlayerService: Sleep timer triggered. '
        'Stopping playback.',
      );
      _sleepTimer?.cancel();
      _sleepTimer = null;
      _sleepTimerEndTime = null;
      stop();
    } else {
      _updateState(sleepTimerRemaining: remaining);
    }
  }
}
