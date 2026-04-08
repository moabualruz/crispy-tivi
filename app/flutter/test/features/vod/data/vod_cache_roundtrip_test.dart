import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/features/vod/domain/entities/'
    'vod_item.dart';

void main() {
  group('mapToVodItem', () {
    test('converts full map to VodItem', () {
      final map = <String, dynamic>{
        'id': 'vod_1',
        'name': 'The Matrix',
        'stream_url': 'http://x.com/1.mkv',
        'type': 'movie',
        'poster_url': 'http://img.com/p.jpg',
        'backdrop_url': 'http://img.com/bg.jpg',
        'description': 'A hacker story.',
        'rating': '8.7',
        'year': 1999,
        'duration': 136,
        'category': 'Sci-Fi',
        'series_id': null,
        'season_number': null,
        'episode_number': null,
        'ext': 'mkv',
        'is_favorite': true,
        'added_at': '2025-01-15T10:00:00.000',
        'updated_at': '2025-06-01T12:00:00.000',
        'source_id': 'src_1',
      };

      final item = mapToVodItem(map);

      expect(item.id, 'vod_1');
      expect(item.name, 'The Matrix');
      expect(item.streamUrl, 'http://x.com/1.mkv');
      expect(item.type, VodType.movie);
      expect(item.posterUrl, 'http://img.com/p.jpg');
      expect(item.backdropUrl, 'http://img.com/bg.jpg');
      expect(item.description, 'A hacker story.');
      expect(item.rating, '8.7');
      expect(item.year, 1999);
      expect(item.duration, 136);
      expect(item.category, 'Sci-Fi');
      expect(item.extension, 'mkv');
      expect(item.isFavorite, true);
      expect(item.addedAt, isNotNull);
      expect(item.updatedAt, isNotNull);
      expect(item.sourceId, 'src_1');
    });

    test('converts minimal map (nulls)', () {
      final map = <String, dynamic>{
        'id': 'min_1',
        'name': 'Minimal',
        'stream_url': 'http://x.com/min.mp4',
        'type': 'movie',
      };

      final item = mapToVodItem(map);

      expect(item.id, 'min_1');
      expect(item.name, 'Minimal');
      expect(item.type, VodType.movie);
      expect(item.posterUrl, isNull);
      expect(item.backdropUrl, isNull);
      expect(item.description, isNull);
      expect(item.rating, isNull);
      expect(item.year, isNull);
      expect(item.duration, isNull);
      expect(item.category, isNull);
      expect(item.extension, isNull);
      expect(item.isFavorite, false);
      expect(item.addedAt, isNull);
      expect(item.updatedAt, isNull);
      expect(item.sourceId, isNull);
    });

    test('converts episode map', () {
      final map = <String, dynamic>{
        'id': 'ep_1_1',
        'name': 'Pilot',
        'stream_url': 'http://x.com/ep1.mkv',
        'type': 'episode',
        'series_id': 'series_1',
        'season_number': 1,
        'episode_number': 1,
        'duration': 45,
      };

      final item = mapToVodItem(map);

      expect(item.type, VodType.episode);
      expect(item.seriesId, 'series_1');
      expect(item.seasonNumber, 1);
      expect(item.episodeNumber, 1);
    });

    test('converts series map', () {
      final map = <String, dynamic>{
        'id': 'series_50',
        'name': 'Breaking Bad',
        'stream_url': '',
        'type': 'series',
        'year': 2008,
      };

      final item = mapToVodItem(map);

      expect(item.type, VodType.series);
      expect(item.year, 2008);
      expect(item.streamUrl, '');
    });

    test('isFavorite defaults to false if missing', () {
      final map = <String, dynamic>{
        'id': 'x',
        'name': 'X',
        'stream_url': 'u',
        'type': 'movie',
      };
      final item = mapToVodItem(map);
      expect(item.isFavorite, false);
    });
  });

  group('vodItemToMap', () {
    test('converts full VodItem to map', () {
      final now = DateTime(2025, 1, 15, 10, 0, 0);
      const item = VodItem(
        id: 'vod_1',
        name: 'The Matrix',
        streamUrl: 'http://x.com/1.mkv',
        type: VodType.movie,
        posterUrl: 'http://img.com/p.jpg',
        backdropUrl: 'http://img.com/bg.jpg',
        description: 'A hacker story.',
        rating: '8.7',
        year: 1999,
        duration: 136,
        category: 'Sci-Fi',
        extension: 'mkv',
        isFavorite: true,
        sourceId: 'src_1',
      );
      final withDates = item.copyWith(addedAt: now, updatedAt: now);

      final map = vodItemToMap(withDates);

      expect(map['id'], 'vod_1');
      expect(map['name'], 'The Matrix');
      expect(map['stream_url'], 'http://x.com/1.mkv');
      expect(map['type'], 'movie');
      expect(map['poster_url'], 'http://img.com/p.jpg');
      expect(map['backdrop_url'], 'http://img.com/bg.jpg');
      expect(map['description'], 'A hacker story.');
      expect(map['rating'], '8.7');
      expect(map['year'], 1999);
      expect(map['duration'], 136);
      expect(map['category'], 'Sci-Fi');
      expect(map['ext'], 'mkv');
      expect(map['is_favorite'], true);
      expect(map['added_at'], isNotNull);
      expect(map['updated_at'], isNotNull);
      expect(map['source_id'], 'src_1');
    });

    test('null fields produce null map values', () {
      const item = VodItem(
        id: 'min',
        name: 'Min',
        streamUrl: 'u',
        type: VodType.movie,
      );
      final map = vodItemToMap(item);

      expect(map['poster_url'], isNull);
      expect(map['backdrop_url'], isNull);
      expect(map['description'], isNull);
      expect(map['rating'], isNull);
      expect(map['year'], isNull);
      expect(map['duration'], isNull);
      expect(map['category'], isNull);
      expect(map['series_id'], isNull);
      expect(map['season_number'], isNull);
      expect(map['episode_number'], isNull);
      expect(map['ext'], isNull);
      expect(map['added_at'], isNull);
      expect(map['updated_at'], isNull);
      expect(map['source_id'], isNull);
    });
  });

  group('mapToVodItem ↔ vodItemToMap round-trip', () {
    test('movie round-trips through map', () {
      const original = VodItem(
        id: 'rt_1',
        name: 'Round Trip Movie',
        streamUrl: 'http://x.com/rt.mkv',
        type: VodType.movie,
        posterUrl: 'http://img/p.jpg',
        backdropUrl: 'http://img/bg.jpg',
        description: 'Test round-trip.',
        rating: '7.5',
        year: 2020,
        duration: 120,
        category: 'Action',
        extension: 'mkv',
        isFavorite: true,
        sourceId: 'src_rt',
      );

      final map = vodItemToMap(original);
      final restored = mapToVodItem(map);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.streamUrl, original.streamUrl);
      expect(restored.type, original.type);
      expect(restored.posterUrl, original.posterUrl);
      expect(restored.backdropUrl, original.backdropUrl);
      expect(restored.description, original.description);
      expect(restored.rating, original.rating);
      expect(restored.year, original.year);
      expect(restored.duration, original.duration);
      expect(restored.category, original.category);
      expect(restored.extension, original.extension);
      expect(restored.isFavorite, original.isFavorite);
      expect(restored.sourceId, original.sourceId);
    });

    test('episode round-trips through map', () {
      const original = VodItem(
        id: 'ep_rt',
        name: 'Episode RT',
        streamUrl: 'http://x.com/ep.mkv',
        type: VodType.episode,
        seriesId: 'series_rt',
        seasonNumber: 2,
        episodeNumber: 5,
        duration: 45,
      );

      final map = vodItemToMap(original);
      final restored = mapToVodItem(map);

      expect(restored.type, VodType.episode);
      expect(restored.seriesId, 'series_rt');
      expect(restored.seasonNumber, 2);
      expect(restored.episodeNumber, 5);
    });

    test('minimal item round-trips through map', () {
      const original = VodItem(
        id: 'min_rt',
        name: 'Minimal',
        streamUrl: 'u',
        type: VodType.series,
      );

      final map = vodItemToMap(original);
      final restored = mapToVodItem(map);

      expect(restored.id, 'min_rt');
      expect(restored.type, VodType.series);
      expect(restored.posterUrl, isNull);
      expect(restored.isFavorite, false);
    });

    test('addedAt/updatedAt round-trip via ISO string', () {
      final now = DateTime.utc(2025, 6, 15, 14, 30, 0);
      const base = VodItem(
        id: 'dt_rt',
        name: 'DateTest',
        streamUrl: 'u',
        type: VodType.movie,
      );
      final withDates = base.copyWith(addedAt: now, updatedAt: now);

      final map = vodItemToMap(withDates);
      final restored = mapToVodItem(map);

      expect(restored.addedAt, now);
      expect(restored.updatedAt, now);
    });
  });
}
