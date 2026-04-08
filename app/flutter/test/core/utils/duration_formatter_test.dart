import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/core/utils/duration_formatter.dart';

void main() {
  group('DurationFormatter', () {
    test('clock formats duration correctly', () {
      expect(DurationFormatter.clock(const Duration(seconds: 45)), '0:45');
      expect(
        DurationFormatter.clock(const Duration(minutes: 5, seconds: 5)),
        '5:05',
      );
      expect(
        DurationFormatter.clock(
          const Duration(hours: 1, minutes: 23, seconds: 45),
        ),
        '1:23:45',
      );
    });

    test('humanShort formats duration correctly', () {
      expect(DurationFormatter.humanShort(const Duration(minutes: 45)), '45m');
      expect(
        DurationFormatter.humanShort(const Duration(hours: 2, minutes: 15)),
        '2h 15m',
      );
      expect(
        DurationFormatter.humanShort(const Duration(hours: 1, minutes: 0)),
        '1h 0m',
      ); // as per implementation logic `1h 0m`
    });

    test('humanShortMs handles null and milliseconds correctly', () {
      expect(DurationFormatter.humanShortMs(null), isNull);

      // 45 minutes = 45 * 60 * 1000 = 2700000
      expect(DurationFormatter.humanShortMs(2700000), '45m');
    });

    test('sleepTimer formats duration correctly', () {
      expect(
        DurationFormatter.sleepTimer(const Duration(minutes: 2, seconds: 30)),
        '2m 30s',
      );
      expect(
        DurationFormatter.sleepTimer(
          const Duration(hours: 1, minutes: 2, seconds: 30),
        ),
        '1h 02m 30s',
      );
    });
  });
}
