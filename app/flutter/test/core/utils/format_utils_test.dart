import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/core/utils/duration_formatter.dart';
import 'package:crispy_tivi/core/utils/format_utils.dart';

void main() {
  group('formatBytes', () {
    test('formats KB correctly', () {
      expect(formatBytes(1500), '1.5 KB');
      expect(formatBytes(500), '0.5 KB');
    });

    test('formats MB correctly', () {
      expect(formatBytes(1500000), '1.4 MB');
    });

    test('formats GB correctly', () {
      expect(formatBytes(1500000000), '1.4 GB');
    });
  });

  group('DurationFormatter.humanShortMs', () {
    test('returns null for null input', () {
      expect(DurationFormatter.humanShortMs(null), isNull);
    });

    test('formats minutes only for < 1 hour', () {
      expect(DurationFormatter.humanShortMs(60000 * 42), '42m');
      expect(DurationFormatter.humanShortMs(60000 * 59), '59m');
      expect(
        DurationFormatter.humanShortMs((60000 * 42) + 30000),
        '42m',
      ); // Truncates seconds
    });

    test('formats hours and minutes for >= 1 hour', () {
      expect(DurationFormatter.humanShortMs(3600000), '1h 0m');
      expect(DurationFormatter.humanShortMs(3600000 + (60000 * 5)), '1h 5m');
      expect(
        DurationFormatter.humanShortMs(3600000 * 2 + (60000 * 15)),
        '2h 15m',
      );
    });
  });
}
