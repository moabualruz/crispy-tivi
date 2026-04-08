import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/player/domain/entities/'
    'watch_history_entry.dart';

void main() {
  final base = WatchHistoryEntry(
    id: 'item-1',
    mediaType: 'movie',
    name: 'Test Movie',
    streamUrl: 'http://example.com/movie.mp4',
    lastWatched: DateTime(2026, 2, 22),
  );

  group('WatchHistoryEntry — construction', () {
    test('default positionMs and durationMs are 0', () {
      expect(base.positionMs, 0);
      expect(base.durationMs, 0);
    });

    test('optional fields default to null', () {
      expect(base.posterUrl, isNull);
      expect(base.seriesId, isNull);
      expect(base.seasonNumber, isNull);
      expect(base.episodeNumber, isNull);
      expect(base.deviceId, isNull);
      expect(base.deviceName, isNull);
    });

    test('stores all required fields', () {
      expect(base.id, 'item-1');
      expect(base.mediaType, 'movie');
      expect(base.name, 'Test Movie');
      expect(base.streamUrl, 'http://example.com/movie.mp4');
      expect(base.lastWatched, DateTime(2026, 2, 22));
    });

    test('stores episode-specific fields', () {
      final ep = WatchHistoryEntry(
        id: 'ep-1',
        mediaType: 'episode',
        name: 'Ep 5',
        streamUrl: 'http://example.com/ep5.mp4',
        lastWatched: DateTime(2026, 2, 22),
        seriesId: 'series-42',
        seasonNumber: 3,
        episodeNumber: 5,
      );
      expect(ep.seriesId, 'series-42');
      expect(ep.seasonNumber, 3);
      expect(ep.episodeNumber, 5);
    });
  });

  group('WatchHistoryEntry — progress', () {
    test('returns 0.0 when durationMs is 0', () {
      expect(base.progress, 0.0);
    });

    test('calculates fraction correctly', () {
      final entry = base.copyWith(positionMs: 50000, durationMs: 100000);
      expect(entry.progress, 0.5);
    });

    test('returns 1.0 when fully watched', () {
      final entry = base.copyWith(positionMs: 100000, durationMs: 100000);
      expect(entry.progress, 1.0);
    });

    test('handles position > duration (over 1.0)', () {
      final entry = base.copyWith(positionMs: 120000, durationMs: 100000);
      expect(entry.progress, 1.2);
    });
  });

  group('WatchHistoryEntry — isNearlyComplete', () {
    test('false when progress < 95%', () {
      final entry = base.copyWith(positionMs: 94000, durationMs: 100000);
      expect(entry.isNearlyComplete, isFalse);
    });

    test('true when progress == 95%', () {
      final entry = base.copyWith(positionMs: 95000, durationMs: 100000);
      expect(entry.isNearlyComplete, isTrue);
    });

    test('true when progress > 95%', () {
      final entry = base.copyWith(positionMs: 99000, durationMs: 100000);
      expect(entry.isNearlyComplete, isTrue);
    });

    test('false when duration is 0', () {
      expect(base.isNearlyComplete, isFalse);
    });
  });

  group('WatchHistoryEntry — copyWith', () {
    test('preserves all fields when no params', () {
      final copy = base.copyWith();
      expect(copy.id, base.id);
      expect(copy.mediaType, base.mediaType);
      expect(copy.name, base.name);
      expect(copy.streamUrl, base.streamUrl);
      expect(copy.positionMs, base.positionMs);
      expect(copy.durationMs, base.durationMs);
      expect(copy.lastWatched, base.lastWatched);
    });

    test('updates only specified fields', () {
      final copy = base.copyWith(positionMs: 42000, deviceId: 'dev-1');
      expect(copy.positionMs, 42000);
      expect(copy.deviceId, 'dev-1');
      expect(copy.name, base.name);
      expect(copy.mediaType, base.mediaType);
    });

    test('updates lastWatched independently', () {
      final newDate = DateTime(2026, 3, 1);
      final copy = base.copyWith(lastWatched: newDate);
      expect(copy.lastWatched, newDate);
      expect(copy.id, base.id);
    });
  });

  group('WatchHistoryEntry — equality', () {
    test('two entries with same id are equal', () {
      final a = base.copyWith(name: 'A');
      final b = base.copyWith(name: 'B');
      expect(a, equals(b));
    });

    test('two entries with different id are not equal', () {
      final other = WatchHistoryEntry(
        id: 'item-2',
        mediaType: 'movie',
        name: 'Test Movie',
        streamUrl: 'http://example.com/movie.mp4',
        lastWatched: DateTime(2026, 2, 22),
      );
      expect(base, isNot(equals(other)));
    });

    test('hashCode is based on id', () {
      final copy = base.copyWith(positionMs: 99999);
      expect(base.hashCode, copy.hashCode);
    });
  });

  group('WatchHistoryEntry — toString', () {
    test('includes name and mediaType', () {
      expect(base.toString(), 'WatchHistoryEntry(Test Movie, movie)');
    });
  });
}
