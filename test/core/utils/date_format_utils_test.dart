import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/core/utils/date_format_utils.dart';

void main() {
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
}
