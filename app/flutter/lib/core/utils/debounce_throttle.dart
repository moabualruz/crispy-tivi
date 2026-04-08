import 'dart:async';

/// Timer-based debouncer that delays execution until
/// a quiet period has elapsed.
///
/// Usage:
/// ```dart
/// final debouncer = Debouncer(duration: Duration(milliseconds: 300));
/// debouncer.run(() => search(query));
/// ```
class Debouncer {
  Debouncer({this.duration = const Duration(milliseconds: 300)});

  final Duration duration;
  Timer? _timer;

  /// Schedules [action] to run after [duration] of
  /// inactivity. Cancels any previously scheduled call.
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// Whether a call is currently pending.
  bool get isPending => _timer?.isActive ?? false;

  /// Cancels any pending call.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Cancels the timer and releases resources.
  void dispose() {
    cancel();
  }
}

/// Timestamp-based throttler that limits execution
/// frequency to at most once per [interval].
///
/// Usage:
/// ```dart
/// final throttler = Throttler(interval: Duration(milliseconds: 100));
/// // Called many times per frame, but executes at most 10x/sec:
/// throttler.run(() => updateOsd());
/// ```
class Throttler {
  Throttler({this.interval = const Duration(milliseconds: 100)});

  final Duration interval;
  DateTime _lastRun = DateTime(0);

  /// Executes [action] if at least [interval] has
  /// elapsed since the last execution.
  /// Returns true if the action was executed.
  bool run(void Function() action) {
    final now = DateTime.now();
    if (now.difference(_lastRun) >= interval) {
      _lastRun = now;
      action();
      return true;
    }
    return false;
  }

  /// Resets the throttler so the next call always runs.
  void reset() {
    _lastRun = DateTime(0);
  }
}
