import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/profiles/domain/utils/profile_stats.dart';
import 'package:crispy_tivi/features/player/domain/entities/watch_history_entry.dart';

WatchHistoryEntry _entry({
  required String id,
  required String name,
  required String mediaType,
  int positionMs = 0,
  DateTime? lastWatched,
  String? seriesId,
}) {
  return WatchHistoryEntry(
    id: id,
    mediaType: mediaType,
    name: name,
    streamUrl: 'http://example.com/$id',
    positionMs: positionMs,
    lastWatched: lastWatched ?? DateTime(2024, 1, 1),
    seriesId: seriesId,
  );
}

void main() {
  group('ProfileViewingStats.compute', () {
    test('empty entries returns zero stats', () {
      final stats = ProfileViewingStats.compute([]);

      expect(stats.totalHoursWatched, 0.0);
      expect(stats.topGenres, isEmpty);
      expect(stats.topChannels, isEmpty);
      expect(stats.watchStreakDays, 0);
    });

    test('totalHoursWatched sums positionMs across entries', () {
      final entries = [
        _entry(id: '1', name: 'A', mediaType: 'movie', positionMs: 3600000),
        _entry(id: '2', name: 'B', mediaType: 'movie', positionMs: 1800000),
      ];

      final stats = ProfileViewingStats.compute(entries);

      expect(stats.totalHoursWatched, closeTo(1.5, 0.001));
    });

    test('topChannels returns top 3 by frequency', () {
      final entries = [
        _entry(id: '1', name: 'CNN', mediaType: 'channel'),
        _entry(id: '2', name: 'CNN', mediaType: 'channel'),
        _entry(id: '3', name: 'CNN', mediaType: 'channel'),
        _entry(id: '4', name: 'BBC', mediaType: 'channel'),
        _entry(id: '5', name: 'BBC', mediaType: 'channel'),
        _entry(id: '6', name: 'Fox', mediaType: 'channel'),
        _entry(id: '7', name: 'HBO', mediaType: 'channel'),
      ];

      final stats = ProfileViewingStats.compute(entries);

      expect(stats.topChannels, hasLength(3));
      expect(stats.topChannels.first, 'CNN');
      expect(stats.topChannels[1], 'BBC');
    });

    test('series entries group by series name prefix', () {
      final entries = [
        _entry(
          id: '1',
          name: 'Breaking Bad - S01E01',
          mediaType: 'episode',
          seriesId: 'bb',
        ),
        _entry(
          id: '2',
          name: 'Breaking Bad - S01E02',
          mediaType: 'episode',
          seriesId: 'bb',
        ),
      ];

      final stats = ProfileViewingStats.compute(entries);

      expect(stats.topChannels, ['Breaking Bad']);
    });

    test('topChannels capped at 3', () {
      final entries = List.generate(
        10,
        (i) => _entry(id: '$i', name: 'Channel$i', mediaType: 'channel'),
      );

      final stats = ProfileViewingStats.compute(entries);

      expect(stats.topChannels, hasLength(3));
    });

    test('topGenres aggregates by mediaType label', () {
      final entries = [
        _entry(id: '1', name: 'A', mediaType: 'movie'),
        _entry(id: '2', name: 'B', mediaType: 'movie'),
        _entry(id: '3', name: 'C', mediaType: 'channel'),
      ];

      final stats = ProfileViewingStats.compute(entries);

      expect(stats.topGenres.first, 'Movies');
      expect(stats.topGenres, contains('Live TV'));
    });

    test('topGenres capped at 3', () {
      final entries = [
        _entry(id: '1', name: 'A', mediaType: 'movie'),
        _entry(id: '2', name: 'B', mediaType: 'episode'),
        _entry(id: '3', name: 'C', mediaType: 'channel'),
        _entry(id: '4', name: 'D', mediaType: 'other_type'),
      ];

      final stats = ProfileViewingStats.compute(entries);

      expect(stats.topGenres, hasLength(lessThanOrEqualTo(3)));
    });
  });

  group('ProfileViewingStats.mediaTypeToGenreLabel', () {
    test('movie maps to Movies', () {
      expect(ProfileViewingStats.mediaTypeToGenreLabel('movie'), 'Movies');
    });

    test('episode maps to Series', () {
      expect(ProfileViewingStats.mediaTypeToGenreLabel('episode'), 'Series');
    });

    test('channel maps to Live TV', () {
      expect(ProfileViewingStats.mediaTypeToGenreLabel('channel'), 'Live TV');
    });

    test('unknown type maps to Other', () {
      expect(ProfileViewingStats.mediaTypeToGenreLabel('unknown'), 'Other');
      expect(ProfileViewingStats.mediaTypeToGenreLabel(''), 'Other');
    });
  });
}
