import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/core/utils/date_format_utils.dart';

void main() {
  group('toNaiveDateTime', () {
    test('strips timezone suffix and fractional seconds', () {
      final dt = DateTime.utc(2024, 1, 1, 15, 0, 0);
      expect(toNaiveDateTime(dt), '2024-01-01T15:00:00');
    });

    test('pads single-digit month, day, hour, minute, second', () {
      final dt = DateTime.utc(2024, 3, 5, 9, 7, 3);
      expect(toNaiveDateTime(dt), '2024-03-05T09:07:03');
    });

    test('converts local time to UTC before formatting', () {
      // A local DateTime that differs from UTC.
      final local = DateTime(2024, 6, 15, 12, 0, 0);
      final result = toNaiveDateTime(local);
      final expected = toNaiveDateTime(local.toUtc());
      expect(result, expected);
    });

    test('round-trips through parseNaiveUtc', () {
      final original = DateTime.utc(2025, 12, 31, 23, 59, 58);
      final encoded = toNaiveDateTime(original);
      final decoded = parseNaiveUtc(encoded);
      expect(decoded, original);
    });
  });

  group('parseNaiveUtc', () {
    test('parses T-separator format as UTC', () {
      final dt = parseNaiveUtc('2024-01-01T15:00:00');
      expect(dt.isUtc, isTrue);
      expect(dt.year, 2024);
      expect(dt.month, 1);
      expect(dt.day, 1);
      expect(dt.hour, 15);
      expect(dt.minute, 0);
      expect(dt.second, 0);
    });

    test('preserves already-UTC datetime', () {
      final dt = parseNaiveUtc('2024-06-15T08:30:00Z');
      expect(dt.isUtc, isTrue);
      expect(dt.hour, 8);
      expect(dt.minute, 30);
    });
  });

  group('DateFormatUtils', () {
    test('formatHHmm formats 24-hour time correctly', () {
      expect(formatHHmm(DateTime(2026, 3, 2, 8, 5)), '08:05');
      expect(formatHHmm(DateTime(2026, 3, 2, 23, 45)), '23:45');
    });

    test('formatDMY formats date correctly', () {
      expect(formatDMY(DateTime(2026, 3, 2)), '2/3/2026');
      expect(formatDMY(DateTime(2026, 12, 25)), '25/12/2026');
    });

    test('formatYMD formats date to ISO style without passing time', () {
      expect(formatYMD(DateTime(2026, 3, 2)), '2026-03-02');
      expect(formatYMD(DateTime(2026, 12, 25)), '2026-12-25');
    });

    test('formatDMYHHmm formats full layout', () {
      expect(formatDMYHHmm(DateTime(2026, 3, 2, 14, 30)), '2/3/2026 14:30');
    });
  });

  group('formatTimeRemaining', () {
    test('returns empty string for zero duration', () {
      expect(formatTimeRemaining(Duration.zero), '');
    });

    test('returns empty string for negative duration', () {
      expect(formatTimeRemaining(const Duration(minutes: -5)), '');
    });

    test('returns minutes only for durations under one hour', () {
      expect(formatTimeRemaining(const Duration(minutes: 1)), '1m left');
      expect(formatTimeRemaining(const Duration(minutes: 45)), '45m left');
      expect(formatTimeRemaining(const Duration(minutes: 59)), '59m left');
    });

    test('returns hours only for exact-hour durations', () {
      expect(formatTimeRemaining(const Duration(hours: 1)), '1h left');
      expect(formatTimeRemaining(const Duration(hours: 2)), '2h left');
    });

    test('returns hours and minutes for mixed durations', () {
      expect(
        formatTimeRemaining(const Duration(hours: 1, minutes: 30)),
        '1h 30m left',
      );
      expect(
        formatTimeRemaining(const Duration(hours: 2, minutes: 5)),
        '2h 5m left',
      );
    });

    test('ignores seconds when computing minutes', () {
      // 90 seconds = 1 minute (inMinutes truncates)
      expect(
        formatTimeRemaining(const Duration(minutes: 10, seconds: 45)),
        '10m left',
      );
    });
  });
}
