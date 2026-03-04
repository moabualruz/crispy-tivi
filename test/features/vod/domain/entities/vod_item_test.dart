import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/vod/domain/entities/'
    'vod_item.dart';

void main() {
  const movie = VodItem(
    id: 'vod_1',
    name: 'The Matrix',
    streamUrl: 'http://x.com/movie/1.mkv',
    type: VodType.movie,
    posterUrl: 'http://img.com/matrix.jpg',
    backdropUrl: 'http://img.com/matrix_bg.jpg',
    description: 'A computer hacker learns the truth.',
    rating: '8.7',
    year: 1999,
    duration: 136,
    category: 'Sci-Fi',
    extension: 'mkv',
    sourceId: 'src_1',
  );

  const episode = VodItem(
    id: 'ep_50_1',
    name: 'Pilot',
    streamUrl: 'http://x.com/series/1.mkv',
    type: VodType.episode,
    seriesId: '50',
    seasonNumber: 1,
    episodeNumber: 1,
    duration: 60,
  );

  group('VodItem', () {
    test('constructor sets all fields correctly', () {
      expect(movie.id, 'vod_1');
      expect(movie.name, 'The Matrix');
      expect(movie.streamUrl, 'http://x.com/movie/1.mkv');
      expect(movie.type, VodType.movie);
      expect(movie.posterUrl, 'http://img.com/matrix.jpg');
      expect(movie.backdropUrl, 'http://img.com/matrix_bg.jpg');
      expect(movie.description, 'A computer hacker learns the truth.');
      expect(movie.rating, '8.7');
      expect(movie.year, 1999);
      expect(movie.duration, 136);
      expect(movie.category, 'Sci-Fi');
      expect(movie.extension, 'mkv');
      expect(movie.isFavorite, false);
      expect(movie.sourceId, 'src_1');
      expect(movie.seriesId, isNull);
      expect(movie.seasonNumber, isNull);
      expect(movie.episodeNumber, isNull);
      expect(movie.addedAt, isNull);
      expect(movie.updatedAt, isNull);
    });

    test('episode fields set correctly', () {
      expect(episode.type, VodType.episode);
      expect(episode.seriesId, '50');
      expect(episode.seasonNumber, 1);
      expect(episode.episodeNumber, 1);
      expect(episode.duration, 60);
    });

    test('isFavorite defaults to false', () {
      const item = VodItem(
        id: '1',
        name: 'X',
        streamUrl: 'u',
        type: VodType.movie,
      );
      expect(item.isFavorite, false);
    });
  });

  group('VodItem.copyWith', () {
    test('returns identical item when no args', () {
      final copy = movie.copyWith();
      expect(copy.id, movie.id);
      expect(copy.name, movie.name);
      expect(copy.streamUrl, movie.streamUrl);
      expect(copy.type, movie.type);
      expect(copy.posterUrl, movie.posterUrl);
      expect(copy.backdropUrl, movie.backdropUrl);
      expect(copy.description, movie.description);
      expect(copy.rating, movie.rating);
      expect(copy.year, movie.year);
      expect(copy.duration, movie.duration);
      expect(copy.category, movie.category);
      expect(copy.extension, movie.extension);
      expect(copy.isFavorite, movie.isFavorite);
      expect(copy.sourceId, movie.sourceId);
    });

    test('overrides single field', () {
      final copy = movie.copyWith(name: 'Reloaded');
      expect(copy.name, 'Reloaded');
      expect(copy.id, movie.id);
    });

    test('overrides isFavorite', () {
      final copy = movie.copyWith(isFavorite: true);
      expect(copy.isFavorite, true);
      expect(copy.name, movie.name);
    });

    test('overrides multiple fields', () {
      final now = DateTime(2025, 1, 1);
      final copy = movie.copyWith(
        year: 2003,
        rating: '7.2',
        addedAt: now,
        updatedAt: now,
      );
      expect(copy.year, 2003);
      expect(copy.rating, '7.2');
      expect(copy.addedAt, now);
      expect(copy.updatedAt, now);
    });

    test('overrides type from movie to episode', () {
      final copy = movie.copyWith(
        type: VodType.episode,
        seriesId: '99',
        seasonNumber: 2,
        episodeNumber: 5,
      );
      expect(copy.type, VodType.episode);
      expect(copy.seriesId, '99');
      expect(copy.seasonNumber, 2);
      expect(copy.episodeNumber, 5);
    });
  });

  group('VodItem equality', () {
    test('equal by id', () {
      const a = VodItem(
        id: 'same_id',
        name: 'A',
        streamUrl: 'u1',
        type: VodType.movie,
      );
      const b = VodItem(
        id: 'same_id',
        name: 'B',
        streamUrl: 'u2',
        type: VodType.series,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('not equal with different id', () {
      const a = VodItem(
        id: 'id_1',
        name: 'Same',
        streamUrl: 'u',
        type: VodType.movie,
      );
      const b = VodItem(
        id: 'id_2',
        name: 'Same',
        streamUrl: 'u',
        type: VodType.movie,
      );
      expect(a, isNot(equals(b)));
    });

    test('not equal to non-VodItem', () {
      // ignore: unrelated_type_equality_checks
      expect(movie == 42, false);
    });

    test('identical reference is equal', () {
      expect(identical(movie, movie), true);
      expect(movie, equals(movie));
    });
  });

  group('VodItem.toString', () {
    test('includes name and type', () {
      expect(
        movie.toString(),
        'VodItem(The Matrix, type=VodType.movie, '
        'source=src_1)',
      );
    });

    test('shows null source', () {
      expect(
        episode.toString(),
        'VodItem(Pilot, type=VodType.episode, '
        'source=null)',
      );
    });
  });

  group('VodType enum', () {
    test('has three values', () {
      expect(VodType.values.length, 3);
    });

    test('values are movie, series, episode', () {
      expect(
        VodType.values,
        containsAll([VodType.movie, VodType.series, VodType.episode]),
      );
    });

    test('byName round-trips', () {
      for (final v in VodType.values) {
        expect(VodType.values.byName(v.name), v);
      }
    });
  });
}
