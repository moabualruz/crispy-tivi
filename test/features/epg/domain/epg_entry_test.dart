import 'package:crispy_tivi/features/iptv/'
    'domain/entities/epg_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── Helpers ─────────────────────────────────────

  /// UTC time factory for concise test setup.
  DateTime utc(int y, int m, int d, [int h = 0, int min = 0]) =>
      DateTime.utc(y, m, d, h, min);

  EpgEntry makeEntry({
    String channelId = 'ch1',
    String title = 'News',
    DateTime? start,
    DateTime? end,
    String? description,
    String? category,
    String? iconUrl,
  }) {
    return EpgEntry(
      channelId: channelId,
      title: title,
      startTime: start ?? utc(2026, 2, 22, 10, 0),
      endTime: end ?? utc(2026, 2, 22, 11, 0),
      description: description,
      category: category,
      iconUrl: iconUrl,
    );
  }

  // ── Construction ────────────────────────────────

  group('EpgEntry construction', () {
    test('stores all fields', () {
      final e = makeEntry(
        channelId: 'abc',
        title: 'Movie',
        start: utc(2026, 1, 1, 20),
        end: utc(2026, 1, 1, 22),
        description: 'A film',
        category: 'Drama',
        iconUrl: 'http://img.png',
      );
      expect(e.channelId, 'abc');
      expect(e.title, 'Movie');
      expect(e.startTime, utc(2026, 1, 1, 20));
      expect(e.endTime, utc(2026, 1, 1, 22));
      expect(e.description, 'A film');
      expect(e.category, 'Drama');
      expect(e.iconUrl, 'http://img.png');
    });

    test('optional fields default to null', () {
      final e = makeEntry();
      expect(e.description, isNull);
      expect(e.category, isNull);
      expect(e.iconUrl, isNull);
    });
  });

  // ── Duration ────────────────────────────────────

  group('duration', () {
    test('returns end minus start', () {
      final e = makeEntry(
        start: utc(2026, 2, 22, 10, 0),
        end: utc(2026, 2, 22, 11, 30),
      );
      expect(e.duration, const Duration(hours: 1, minutes: 30));
    });

    test('zero-length entry has zero duration', () {
      final t = utc(2026, 2, 22, 10);
      final e = makeEntry(start: t, end: t);
      expect(e.duration, Duration.zero);
    });
  });

  // ── isLiveAt ────────────────────────────────────

  group('isLiveAt', () {
    test('true when now is within range', () {
      final e = makeEntry(
        start: utc(2026, 2, 22, 10, 0),
        end: utc(2026, 2, 22, 11, 0),
      );
      expect(e.isLiveAt(utc(2026, 2, 22, 10, 30)), isTrue);
    });

    test('true when now equals start (boundary, inclusive)', () {
      final e = makeEntry(
        start: utc(2026, 2, 22, 10, 0),
        end: utc(2026, 2, 22, 11, 0),
      );
      // BUG-23: start boundary is inclusive (>= start)
      expect(e.isLiveAt(utc(2026, 2, 22, 10, 0)), isTrue);
    });

    test('false when now equals end (boundary)', () {
      final e = makeEntry(
        start: utc(2026, 2, 22, 10, 0),
        end: utc(2026, 2, 22, 11, 0),
      );
      expect(e.isLiveAt(utc(2026, 2, 22, 11, 0)), isFalse);
    });

    test('false when now is before start', () {
      final e = makeEntry(
        start: utc(2026, 2, 22, 10, 0),
        end: utc(2026, 2, 22, 11, 0),
      );
      expect(e.isLiveAt(utc(2026, 2, 22, 9, 0)), isFalse);
    });

    test('false when now is after end', () {
      final e = makeEntry(
        start: utc(2026, 2, 22, 10, 0),
        end: utc(2026, 2, 22, 11, 0),
      );
      expect(e.isLiveAt(utc(2026, 2, 22, 12, 0)), isFalse);
    });

    test('handles local DateTime by converting to UTC', () {
      // Entry is in UTC. Pass a local time that
      // falls within range once converted.
      final e = EpgEntry(
        channelId: 'ch1',
        title: 'Show',
        startTime: DateTime.utc(2026, 2, 22, 10),
        endTime: DateTime.utc(2026, 2, 22, 11),
      );
      // Create a local time equivalent to 10:30 UTC
      final local = DateTime.utc(2026, 2, 22, 10, 30);
      expect(e.isLiveAt(local), isTrue);
    });
  });

  // ── progressAt ──────────────────────────────────

  group('progressAt', () {
    test('returns 0.0 when not live', () {
      final e = makeEntry(
        start: utc(2026, 2, 22, 10, 0),
        end: utc(2026, 2, 22, 11, 0),
      );
      expect(e.progressAt(utc(2026, 2, 22, 9, 0)), 0.0);
    });

    test('returns ~0.5 at midpoint', () {
      final e = makeEntry(
        start: utc(2026, 2, 22, 10, 0),
        end: utc(2026, 2, 22, 11, 0),
      );
      final progress = e.progressAt(utc(2026, 2, 22, 10, 30));
      expect(progress, closeTo(0.5, 0.01));
    });

    test('returns ~0.25 at quarter point', () {
      final e = makeEntry(
        start: utc(2026, 2, 22, 10, 0),
        end: utc(2026, 2, 22, 11, 0),
      );
      final progress = e.progressAt(utc(2026, 2, 22, 10, 15));
      expect(progress, closeTo(0.25, 0.01));
    });

    test('clamps to 1.0 near end', () {
      final e = makeEntry(
        start: utc(2026, 2, 22, 10, 0),
        end: utc(2026, 2, 22, 11, 0),
      );
      // 1 second before end
      final nearEnd = utc(2026, 2, 22, 10, 59);
      final progress = e.progressAt(nearEnd);
      expect(progress, lessThanOrEqualTo(1.0));
      expect(progress, greaterThan(0.9));
    });

    test('returns 0.0 for zero-duration entry', () {
      final t = utc(2026, 2, 22, 10);
      final e = makeEntry(start: t, end: t);
      expect(e.progressAt(t), 0.0);
    });
  });

  // ── isPastAt ────────────────────────────────────

  group('isPastAt', () {
    test('true when now is after end', () {
      final e = makeEntry(
        start: utc(2026, 2, 22, 10, 0),
        end: utc(2026, 2, 22, 11, 0),
      );
      expect(e.isPastAt(utc(2026, 2, 22, 12, 0)), isTrue);
    });

    test('false when now equals end', () {
      final e = makeEntry(
        start: utc(2026, 2, 22, 10, 0),
        end: utc(2026, 2, 22, 11, 0),
      );
      expect(e.isPastAt(utc(2026, 2, 22, 11, 0)), isFalse);
    });

    test('false when now is before end', () {
      final e = makeEntry(
        start: utc(2026, 2, 22, 10, 0),
        end: utc(2026, 2, 22, 11, 0),
      );
      expect(e.isPastAt(utc(2026, 2, 22, 10, 30)), isFalse);
    });
  });

  // ── Equality ────────────────────────────────────

  group('equality', () {
    test('equal when same channelId + startTime', () {
      final a = makeEntry(
        channelId: 'ch1',
        title: 'A',
        start: utc(2026, 2, 22, 10),
      );
      final b = makeEntry(
        channelId: 'ch1',
        title: 'B',
        start: utc(2026, 2, 22, 10),
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('not equal when different channelId', () {
      final a = makeEntry(channelId: 'ch1', start: utc(2026, 2, 22, 10));
      final b = makeEntry(channelId: 'ch2', start: utc(2026, 2, 22, 10));
      expect(a, isNot(equals(b)));
    });

    test('not equal when different startTime', () {
      final a = makeEntry(channelId: 'ch1', start: utc(2026, 2, 22, 10));
      final b = makeEntry(channelId: 'ch1', start: utc(2026, 2, 22, 11));
      expect(a, isNot(equals(b)));
    });
  });

  // ── toString ────────────────────────────────────

  test('toString includes title and time range', () {
    final e = makeEntry(
      title: 'News',
      start: utc(2026, 2, 22, 10),
      end: utc(2026, 2, 22, 11),
    );
    final s = e.toString();
    expect(s, contains('News'));
    expect(s, contains('EpgEntry'));
  });
}
