import 'package:crispy_tivi/features/player/presentation/widgets/player_osd/osd_bottom_bar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatFinishTime', () {
    test('24h format shows zero-padded HH:MM', () {
      final time = DateTime(2026, 3, 9, 14, 5);
      expect(formatFinishTime(time, true), '14:05');
    });

    test('24h format shows midnight as 00:00', () {
      final time = DateTime(2026, 3, 9, 0, 0);
      expect(formatFinishTime(time, true), '00:00');
    });

    test('12h format shows AM for morning', () {
      final time = DateTime(2026, 3, 9, 9, 30);
      expect(formatFinishTime(time, false), '9:30 AM');
    });

    test('12h format shows PM for afternoon', () {
      final time = DateTime(2026, 3, 9, 15, 45);
      expect(formatFinishTime(time, false), '3:45 PM');
    });

    test('12h format shows 12 PM for noon', () {
      final time = DateTime(2026, 3, 9, 12, 0);
      expect(formatFinishTime(time, false), '12:00 PM');
    });

    test('12h format shows 12 AM for midnight', () {
      final time = DateTime(2026, 3, 9, 0, 0);
      expect(formatFinishTime(time, false), '12:00 AM');
    });
  });

  group('speed-adjusted finish time calculation', () {
    test('30min remaining at 2x speed finishes in 15min', () {
      final remaining = const Duration(minutes: 30);
      const speed = 2.0;
      final adjustedMs = (remaining.inMilliseconds / speed).round();
      final adjusted = Duration(milliseconds: adjustedMs);
      expect(adjusted.inMinutes, 15);
    });

    test('1hr remaining at 0.5x speed finishes in 2hr', () {
      final remaining = const Duration(hours: 1);
      const speed = 0.5;
      final adjustedMs = (remaining.inMilliseconds / speed).round();
      final adjusted = Duration(milliseconds: adjustedMs);
      expect(adjusted.inHours, 2);
    });

    test('normal speed (1x) does not change remaining', () {
      final remaining = const Duration(minutes: 45);
      const speed = 1.0;
      final adjustedMs = (remaining.inMilliseconds / speed).round();
      final adjusted = Duration(milliseconds: adjustedMs);
      expect(adjusted.inMinutes, 45);
    });
  });
}
