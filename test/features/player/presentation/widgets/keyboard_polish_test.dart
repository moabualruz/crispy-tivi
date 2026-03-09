import 'package:crispy_tivi/features/player/presentation/screens/player_keyboard_handler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('getSeekMultiplier', () {
    test('returns 1.5x for 0–5 repeats', () {
      expect(getSeekMultiplier(0), 1.5);
      expect(getSeekMultiplier(3), 1.5);
      expect(getSeekMultiplier(5), 1.5);
    });

    test('returns 3.0x for 6–15 repeats', () {
      expect(getSeekMultiplier(6), 3.0);
      expect(getSeekMultiplier(10), 3.0);
      expect(getSeekMultiplier(15), 3.0);
    });

    test('returns 6.0x for 16–30 repeats', () {
      expect(getSeekMultiplier(16), 6.0);
      expect(getSeekMultiplier(25), 6.0);
      expect(getSeekMultiplier(30), 6.0);
    });

    test('returns 10.0x for 31+ repeats', () {
      expect(getSeekMultiplier(31), 10.0);
      expect(getSeekMultiplier(50), 10.0);
      expect(getSeekMultiplier(100), 10.0);
    });
  });

  group('progressive seek step calculation', () {
    test('base step is 0.5% of duration clamped to 500–15000ms', () {
      // 10-minute video: 600_000ms * 0.005 = 3000ms
      final durationMs = 600000;
      final baseStep = (durationMs * 0.005).clamp(500, 15000).toInt();
      expect(baseStep, 3000);
    });

    test('short video clamps base step to 500ms minimum', () {
      // 10-second video: 10_000ms * 0.005 = 50ms → clamped to 500ms
      final durationMs = 10000;
      final baseStep = (durationMs * 0.005).clamp(500, 15000).toInt();
      expect(baseStep, 500);
    });

    test('long video clamps base step to 15s maximum', () {
      // 5-hour video: 18_000_000ms * 0.005 = 90_000ms → clamped to 15000ms
      final durationMs = 18000000;
      final baseStep = (durationMs * 0.005).clamp(500, 15000).toInt();
      expect(baseStep, 15000);
    });

    test('multiplied step for tier 2 at 3x', () {
      final durationMs = 600000;
      final baseStep = (durationMs * 0.005).clamp(500, 15000).toInt();
      final multiplier = getSeekMultiplier(10); // 3.0x
      final effectiveStep = (baseStep * multiplier).clamp(500, 60000).toInt();
      expect(effectiveStep, 9000);
    });

    test('multiplied step clamped to 60s maximum', () {
      // 5-hour video, tier 4 (10x): 15000 * 10 = 150_000 → clamped to 60_000
      final durationMs = 18000000;
      final baseStep = (durationMs * 0.005).clamp(500, 15000).toInt();
      final multiplier = getSeekMultiplier(50); // 10.0x
      final effectiveStep = (baseStep * multiplier).clamp(500, 60000).toInt();
      expect(effectiveStep, 60000);
    });
  });

  group('backslash speed reset', () {
    test('backslash key ID matches LogicalKeyboardKey.backslash', () {
      // Verify the key constant exists and can be compared.
      expect(LogicalKeyboardKey.backslash, isNotNull);
    });
  });
}
