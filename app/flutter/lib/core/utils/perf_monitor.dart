import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Lightweight performance monitor for CPU, RAM, and frame timing.
///
/// Runs a periodic timer that logs process memory usage and
/// frame statistics. Enabled only in debug/profile modes.
class PerfMonitor {
  PerfMonitor._();
  static final instance = PerfMonitor._();

  Timer? _timer;
  int _frameCount = 0;
  int _jankFrames = 0;
  Duration _worstFrame = Duration.zero;

  /// Start periodic monitoring (every [intervalSeconds] seconds).
  void start({int intervalSeconds = 10}) {
    if (kReleaseMode) return; // No-op in release
    stop();

    // Track frame timing
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);

    _timer = Timer.periodic(Duration(seconds: intervalSeconds), (_) {
      _logStats();
    });

    debugPrint('[PERF] Monitor started (${intervalSeconds}s interval)');
  }

  /// Stop monitoring.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _frameCount++;
      final total = t.totalSpan;
      if (total > const Duration(milliseconds: 16)) {
        _jankFrames++;
      }
      if (total > _worstFrame) {
        _worstFrame = total;
      }
    }
  }

  void _logStats() {
    final rss = ProcessInfo.currentRss / (1024 * 1024);
    final maxRss = ProcessInfo.maxRss / (1024 * 1024);

    debugPrint(
      '[PERF] RSS=${rss.toStringAsFixed(1)}MB '
      'maxRSS=${maxRss.toStringAsFixed(1)}MB '
      'frames=$_frameCount '
      'jank=$_jankFrames '
      'worstFrame=${_worstFrame.inMilliseconds}ms',
    );

    // Reset counters
    _frameCount = 0;
    _jankFrames = 0;
    _worstFrame = Duration.zero;
  }
}
