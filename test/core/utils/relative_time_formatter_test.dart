import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/core/utils/relative_time_formatter.dart';

void main() {
  group('RelativeTimeFormatter', () {
    test('formatRelativeTime formats times correctly', () {
      final now = DateTime(2026, 3, 2, 12, 0); // Reference time for the test

      // < 1 minute ago
      expect(
        formatRelativeTime(now.subtract(const Duration(seconds: 30)), now: now),
        'Just now',
      );

      // < 60 minutes ago
      expect(
        formatRelativeTime(now.subtract(const Duration(minutes: 5)), now: now),
        '5m ago',
      );

      // < 24 hours ago
      expect(
        formatRelativeTime(now.subtract(const Duration(hours: 2)), now: now),
        '2h ago',
      );

      // 1 day ago
      expect(
        formatRelativeTime(now.subtract(const Duration(days: 1)), now: now),
        'Yesterday',
      );

      // < 7 days ago
      expect(
        formatRelativeTime(now.subtract(const Duration(days: 3)), now: now),
        '3d ago',
      );

      // >= 7 days ago
      expect(
        formatRelativeTime(now.subtract(const Duration(days: 10)), now: now),
        '2/20/2026',
      );
    });
  });
}
