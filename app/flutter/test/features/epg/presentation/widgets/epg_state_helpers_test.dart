import 'package:crispy_tivi/features/epg/'
    'presentation/providers/epg_providers.dart';
import 'package:crispy_tivi/features/epg/'
    'presentation/widgets/epg_state_helpers.dart';
import 'package:crispy_tivi/features/iptv/'
    'domain/entities/channel.dart';
import 'package:crispy_tivi/features/iptv/'
    'domain/entities/epg_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── Helpers ─────────────────────────────────────

  DateTime utc(int y, int m, int d, [int h = 0, int min = 0]) =>
      DateTime.utc(y, m, d, h, min);

  EpgEntry entry(
    String channelId,
    String title,
    DateTime start,
    DateTime end,
  ) => EpgEntry(
    channelId: channelId,
    title: title,
    startTime: start,
    endTime: end,
  );

  // ── getEpgPixelsPerMinute ───────────────────────

  group('getEpgPixelsPerMinute', () {
    test('day mode returns 4.0', () {
      expect(getEpgPixelsPerMinute(EpgViewMode.day), epgPixelsPerMinuteDay);
      expect(getEpgPixelsPerMinute(EpgViewMode.day), 4.0);
    });

    test('week mode returns 0.57', () {
      expect(getEpgPixelsPerMinute(EpgViewMode.week), epgPixelsPerMinuteWeek);
      expect(getEpgPixelsPerMinute(EpgViewMode.week), 0.57);
    });
  });

  // ── getEpgWeekStart ─────────────────────────────

  group('getEpgWeekStart', () {
    test('Monday returns same Monday', () {
      // 2026-02-23 is a Monday.
      final monday = DateTime(2026, 2, 23);
      final result = getEpgWeekStart(monday);
      expect(result.weekday, DateTime.monday);
      expect(result, DateTime(2026, 2, 23));
    });

    test('Wednesday returns preceding Monday', () {
      // 2026-02-25 is a Wednesday.
      final wed = DateTime(2026, 2, 25);
      final result = getEpgWeekStart(wed);
      expect(result.weekday, DateTime.monday);
      expect(result, DateTime(2026, 2, 23));
    });

    test('Sunday returns preceding Monday', () {
      // 2026-03-01 is a Sunday.
      final sun = DateTime(2026, 3, 1);
      final result = getEpgWeekStart(sun);
      expect(result.weekday, DateTime.monday);
      expect(result, DateTime(2026, 2, 23));
    });

    test('strips time component', () {
      final dateWithTime = DateTime(2026, 2, 25, 14, 30);
      final result = getEpgWeekStart(dateWithTime);
      expect(result.hour, 0);
      expect(result.minute, 0);
      expect(result.second, 0);
    });
  });

  // ── getEpgDateRange ─────────────────────────────

  group('getEpgDateRange', () {
    test('day mode returns 24-hour range', () {
      final date = DateTime(2026, 2, 22, 14, 30);
      final (start, end) = getEpgDateRange(EpgViewMode.day, date);
      expect(start, DateTime(2026, 2, 22));
      expect(end, DateTime(2026, 2, 23));
      expect(end.difference(start), const Duration(hours: 24));
    });

    test('week mode returns 7-day range', () {
      // 2026-02-25 Wed → Mon 2026-02-23
      final date = DateTime(2026, 2, 25);
      final (start, end) = getEpgDateRange(EpgViewMode.week, date);
      expect(start.weekday, DateTime.monday);
      expect(end.difference(start), const Duration(days: 7));
    });

    test('day mode strips time', () {
      final date = DateTime(2026, 2, 22, 23, 59);
      final (start, _) = getEpgDateRange(EpgViewMode.day, date);
      expect(start.hour, 0);
      expect(start.minute, 0);
    });
  });

  // ── isSameDay ───────────────────────────────────

  group('isSameDay', () {
    test('same date different time returns true', () {
      final a = DateTime(2026, 2, 22, 10, 30);
      final b = DateTime(2026, 2, 22, 23, 59);
      expect(isSameDay(a, b), isTrue);
    });

    test('different dates returns false', () {
      final a = DateTime(2026, 2, 22);
      final b = DateTime(2026, 2, 23);
      expect(isSameDay(a, b), isFalse);
    });

    test('same date midnight returns true', () {
      final a = DateTime(2026, 2, 22);
      final b = DateTime(2026, 2, 22);
      expect(isSameDay(a, b), isTrue);
    });

    test('different months same day number', () {
      final a = DateTime(2026, 1, 22);
      final b = DateTime(2026, 2, 22);
      expect(isSameDay(a, b), isFalse);
    });
  });

  // ── epgTodayLabel ───────────────────────────────

  group('epgTodayLabel', () {
    test('formats Jan 1 correctly', () {
      expect(epgTodayLabel(DateTime(2026, 1, 1)), 'Jan 1');
    });

    test('formats Feb 22 correctly', () {
      expect(epgTodayLabel(DateTime(2026, 2, 22)), 'Feb 22');
    });

    test('formats Dec 31 correctly', () {
      expect(epgTodayLabel(DateTime(2026, 12, 31)), 'Dec 31');
    });

    test('all months are covered', () {
      final expected = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      for (var i = 0; i < 12; i++) {
        final label = epgTodayLabel(DateTime(2026, i + 1, 15));
        expect(label, startsWith(expected[i]));
      }
    });
  });

  // ── getNowPlaying ───────────────────────────────

  group('getNowPlaying', () {
    test('returns live entry for channel', () {
      final live = entry(
        'ch1',
        'Live Show',
        utc(2026, 2, 22, 10),
        utc(2026, 2, 22, 11),
      );
      final s = EpgState(
        channels: [Channel(id: 'ch1', name: 'Ch1', streamUrl: 'http://s/1')],
        entries: {
          'ch1': [live],
        },
      );
      final result = getNowPlaying(s, 'ch1', now: utc(2026, 2, 22, 10, 30));
      expect(result, live);
    });

    test('returns null when no live entry', () {
      final past = entry(
        'ch1',
        'Old Show',
        utc(2026, 2, 22, 8),
        utc(2026, 2, 22, 9),
      );
      final s = EpgState(
        entries: {
          'ch1': [past],
        },
      );
      final result = getNowPlaying(s, 'ch1', now: utc(2026, 2, 22, 10));
      expect(result, isNull);
    });

    test('returns null for unknown channel', () {
      const s = EpgState();
      final result = getNowPlaying(s, 'unknown', now: utc(2026, 2, 22, 10));
      expect(result, isNull);
    });

    test('follows epgOverrides', () {
      final live = entry(
        'target',
        'Mapped Live',
        utc(2026, 2, 22, 10),
        utc(2026, 2, 22, 11),
      );
      final s = EpgState(
        entries: {
          'target': [live],
        },
        epgOverrides: {'ch2': 'target'},
      );
      final result = getNowPlaying(s, 'ch2', now: utc(2026, 2, 22, 10, 30));
      expect(result, live);
    });

    test('picks first live from multiple entries', () {
      final e1 = entry(
        'ch1',
        'Morning',
        utc(2026, 2, 22, 9),
        utc(2026, 2, 22, 10),
      );
      final e2 = entry(
        'ch1',
        'Noon',
        utc(2026, 2, 22, 10),
        utc(2026, 2, 22, 11),
      );
      final e3 = entry(
        'ch1',
        'Afternoon',
        utc(2026, 2, 22, 11),
        utc(2026, 2, 22, 12),
      );
      final s = EpgState(
        entries: {
          'ch1': [e1, e2, e3],
        },
      );
      final result = getNowPlaying(s, 'ch1', now: utc(2026, 2, 22, 10, 30));
      expect(result?.title, 'Noon');
    });
  });
}
