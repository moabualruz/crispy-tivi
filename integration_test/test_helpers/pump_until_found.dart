import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

/// Extension on [WidgetTester] to pump the UI until a specific finder finds at least one widget.
/// Essential for media_kit tests where the player ticks frames asynchronously and `pumpAndSettle` times out.
extension PumpUntilFoundExtension on WidgetTester {
  Future<void> pumpUntilFound(
    Finder finder, {
    Duration timeout = const Duration(seconds: 15),
    Duration step = const Duration(milliseconds: 50),
  }) async {
    bool timerDone = false;
    final timer = Timer(
      timeout,
      () =>
          throw TimeoutException('Pump until found timed out after $timeout.'),
    );

    try {
      while (timerDone != true) {
        await pump(step);
        final found = any(finder);
        if (found) {
          timerDone = true;
        }
      }
    } finally {
      timer.cancel();
    }
  }

  /// Pumps until the given condition evaluates to true.
  Future<void> pumpUntilCondition(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 15),
    Duration step = const Duration(milliseconds: 50),
  }) async {
    bool timerDone = false;
    final timer = Timer(
      timeout,
      () =>
          throw TimeoutException(
            'Pump until condition timed out after $timeout.',
          ),
    );

    try {
      while (timerDone != true) {
        await pump(step);
        if (condition()) {
          timerDone = true;
        }
      }
    } finally {
      timer.cancel();
    }
  }
}
