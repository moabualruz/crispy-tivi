import 'package:crispy_tivi/features/parental/domain/content_rating.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';
import 'package:crispy_tivi/features/vod/domain/utils/vod_filter_utils.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Helpers ────────────────────────────────────────────────────────────────

VodItem _movie({required String id, String? rating}) => VodItem(
  id: id,
  name: 'Movie $id',
  streamUrl: 'http://x.com/$id.mkv',
  type: VodType.movie,
  rating: rating,
);

// ── filterByContentRating ──────────────────────────────────────────────────

void main() {
  group('filterByContentRating', () {
    test('returns all items when maxRating is nc17 (unrestricted)', () {
      final items = [
        _movie(id: 'm1', rating: 'G'),
        _movie(id: 'm2', rating: 'PG'),
        _movie(id: 'm3', rating: 'PG-13'),
        _movie(id: 'm4', rating: 'R'),
        _movie(id: 'm5', rating: 'NC-17'),
      ];
      final result = filterByContentRating(items, ContentRatingLevel.nc17);
      expect(result.length, 5);
    });

    test('filters out items exceeding maxRating', () {
      final items = [
        _movie(id: 'm1', rating: 'G'),
        _movie(id: 'm2', rating: 'PG'),
        _movie(id: 'm3', rating: 'PG-13'),
        _movie(id: 'm4', rating: 'R'),
        _movie(id: 'm5', rating: 'NC-17'),
      ];
      final result = filterByContentRating(items, ContentRatingLevel.pg13);
      expect(result.map((i) => i.id), containsAll(['m1', 'm2', 'm3']));
      expect(result.map((i) => i.id), isNot(contains('m4')));
      expect(result.map((i) => i.id), isNot(contains('m5')));
    });

    test('allows unrated items regardless of maxRating', () {
      final items = [
        _movie(id: 'm1', rating: null),
        _movie(id: 'm2', rating: ''),
        _movie(id: 'm3', rating: 'Unrated'),
      ];
      // Even the most restrictive setting allows unrated
      final result = filterByContentRating(items, ContentRatingLevel.g);
      expect(result.length, 3);
    });

    test('returns empty list when all items exceed maxRating', () {
      final items = [
        _movie(id: 'm1', rating: 'R'),
        _movie(id: 'm2', rating: 'NC-17'),
      ];
      final result = filterByContentRating(items, ContentRatingLevel.pg);
      expect(result, isEmpty);
    });

    test('returns empty list for empty input', () {
      final result = filterByContentRating([], ContentRatingLevel.pg13);
      expect(result, isEmpty);
    });

    test('handles TV Parental Guidelines ratings', () {
      final items = [
        _movie(id: 'm1', rating: 'TV-G'),
        _movie(id: 'm2', rating: 'TV-PG'),
        _movie(id: 'm3', rating: 'TV-14'),
        _movie(id: 'm4', rating: 'TV-MA'),
      ];
      // maxRating = pg maps to value 1; TV-14 → pg13 (value 2) is excluded
      final result = filterByContentRating(items, ContentRatingLevel.pg);
      expect(result.map((i) => i.id), containsAll(['m1', 'm2']));
      expect(result.map((i) => i.id), isNot(contains('m3')));
      expect(result.map((i) => i.id), isNot(contains('m4')));
    });

    test('returns exact item matching maxRating boundary', () {
      final items = [
        _movie(id: 'm1', rating: 'PG-13'),
        _movie(id: 'm2', rating: 'R'),
      ];
      final result = filterByContentRating(items, ContentRatingLevel.pg13);
      expect(result.map((i) => i.id), equals(['m1']));
    });
  });
}
