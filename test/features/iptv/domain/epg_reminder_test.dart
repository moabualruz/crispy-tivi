import 'package:crispy_tivi/features/iptv/domain/entities/epg_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates an [EpgReminder] with [startTime] and dummy fields.
EpgReminder reminder(DateTime startTime) => EpgReminder(
  channelId: 'ch1',
  programId: 'ch1_${startTime.millisecondsSinceEpoch}',
  startTime: startTime,
  title: 'Test Programme',
  channelName: 'Test Channel',
);

void main() {
  // Base reference point (UTC, fixed — no DateTime.now() in tests).
  final base = DateTime.utc(2024, 6, 15, 12, 0, 0); // noon

  // ── isDue ────────────────────────────────────────────────────
  group('EpgReminder.isDue', () {
    test('returns true when start is exactly 5 min away', () {
      final r = reminder(base.add(const Duration(minutes: 5)));
      // now is 1 second before the 5-min mark → remaining = 5 min - 1 s
      // Actually we want remaining == 5 min exactly → start IS base+5m,
      // so now == base means remaining = 5 min (inMinutes == 5, inSeconds > 0)
      expect(r.isDue(base), isTrue);
    });

    test('returns true when start is 3 min away', () {
      final r = reminder(base.add(const Duration(minutes: 3)));
      expect(r.isDue(base), isTrue);
    });

    test('returns false when start is more than 5 min away', () {
      final r = reminder(base.add(const Duration(minutes: 10)));
      expect(r.isDue(base), isFalse);
    });

    test('returns false when start is exactly 6 min away', () {
      final r = reminder(base.add(const Duration(minutes: 6)));
      expect(r.isDue(base), isFalse);
    });

    test(
      'returns false when programme has already started (remaining <= 0)',
      () {
        // start is 1 min in the past — remaining is negative
        final r = reminder(base.subtract(const Duration(minutes: 1)));
        expect(r.isDue(base), isFalse);
      },
    );

    test('returns false when start == now (remaining = 0 seconds)', () {
      // inSeconds == 0, guard `remaining.inSeconds > 0` fails
      final r = reminder(base);
      expect(r.isDue(base), isFalse);
    });
  });

  // ── isPast ───────────────────────────────────────────────────
  group('EpgReminder.isPast', () {
    test('returns true when now is after startTime', () {
      final r = reminder(base);
      final now = base.add(const Duration(seconds: 1));
      expect(r.isPast(now), isTrue);
    });

    test('returns true when now is well after startTime', () {
      final r = reminder(base);
      final now = base.add(const Duration(hours: 2));
      expect(r.isPast(now), isTrue);
    });

    test('returns false when now is before startTime', () {
      final r = reminder(base.add(const Duration(hours: 1)));
      expect(r.isPast(base), isFalse);
    });

    test('returns false when now == startTime exactly', () {
      // isAfter is strict; equal timestamps are not "after"
      final r = reminder(base);
      expect(r.isPast(base), isFalse);
    });
  });

  // ── Equality & hashCode ──────────────────────────────────────
  group('EpgReminder equality', () {
    test('two reminders with same channelId and programId are equal', () {
      final r1 = reminder(base);
      final r2 = EpgReminder(
        channelId: r1.channelId,
        programId: r1.programId,
        startTime: base.add(const Duration(hours: 1)), // different time
        title: 'Different Title',
        channelName: 'Different Channel',
      );
      expect(r1, equals(r2));
      expect(r1.hashCode, equals(r2.hashCode));
    });

    test('reminders with different programId are not equal', () {
      final r1 = reminder(base);
      final r2 = reminder(base.add(const Duration(hours: 1)));
      expect(r1, isNot(equals(r2)));
    });
  });
}
