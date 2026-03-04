import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/vod/domain/entities/'
    'vod_item.dart';
import 'package:crispy_tivi/features/vod/presentation/'
    'providers/vod_providers.dart';

/// Helper to build a [VodItem] with minimal boilerplate.
VodItem _item({
  required String id,
  String name = 'Item',
  VodType type = VodType.movie,
  String? category,
  String? posterUrl,
  String? backdropUrl,
  int? year,
  String? rating,
  DateTime? addedAt,
  bool isFavorite = false,
}) {
  return VodItem(
    id: id,
    name: name,
    streamUrl: 'http://x.com/$id',
    type: type,
    category: category,
    posterUrl: posterUrl,
    backdropUrl: backdropUrl,
    year: year,
    rating: rating,
    addedAt: addedAt,
    isFavorite: isFavorite,
  );
}

void main() {
  group('VodState — default', () {
    test('empty state has sensible defaults', () {
      final s = VodState();
      expect(s.items, isEmpty);
      expect(s.categories, isEmpty);
      expect(s.selectedCategory, isNull);
      expect(s.isLoading, false);
      expect(s.error, isNull);
      expect(s.movies, isEmpty);
      expect(s.series, isEmpty);
      expect(s.featured, isEmpty);
      expect(s.newReleases, isEmpty);
      expect(s.filtered, isEmpty);
      expect(s.byCategory, isEmpty);
      expect(s.movieCategories, isEmpty);
      expect(s.seriesCategories, isEmpty);
    });
  });

  group('VodState — computed movies/series', () {
    test('splits items into movies and series', () {
      final items = [
        _item(id: '1', type: VodType.movie),
        _item(id: '2', type: VodType.series),
        _item(id: '3', type: VodType.movie),
        _item(id: '4', type: VodType.episode),
      ];

      final s = VodState(items: items);
      expect(s.movies.length, 2);
      expect(s.series.length, 1);
      expect(s.movies.map((i) => i.id), containsAll(['1', '3']));
      expect(s.series.first.id, '2');
    });
  });

  group('VodState — featured', () {
    test('includes items with posterUrl, max 10', () {
      final items = List.generate(
        15,
        (i) => _item(id: 'f$i', posterUrl: 'http://img/$i.jpg'),
      );
      final s = VodState(items: items);
      expect(s.featured.length, 10);
    });

    test('excludes items without posterUrl', () {
      final items = [
        _item(id: '1', posterUrl: 'http://img/bg.jpg'),
        _item(id: '2'),
        _item(id: '3', posterUrl: ''),
      ];
      final s = VodState(items: items);
      expect(s.featured.length, 1);
      expect(s.featured.first.id, '1');
    });
  });

  group('VodState — newReleases', () {
    test('sorted by year descending, max 15', () {
      final items = List.generate(20, (i) => _item(id: 'nr$i', year: 2000 + i));
      final s = VodState(items: items);
      expect(s.newReleases.length, 15);
      expect(s.newReleases.first.year, 2019);
      expect(s.newReleases.last.year, 2005);
    });

    test('excludes items without year', () {
      final items = [
        _item(id: '1', year: 2020),
        _item(id: '2'),
        _item(id: '3', year: 2021),
      ];
      final s = VodState(items: items);
      expect(s.newReleases.length, 2);
      expect(s.newReleases.first.year, 2021);
    });
  });

  group('VodState — byCategory', () {
    test('groups items by category', () {
      final items = [
        _item(id: '1', category: 'Action'),
        _item(id: '2', category: 'Comedy'),
        _item(id: '3', category: 'Action'),
        _item(id: '4'),
      ];
      final s = VodState(items: items);
      expect(s.byCategory['Action']?.length, 2);
      expect(s.byCategory['Comedy']?.length, 1);
      expect(s.byCategory['Uncategorized']?.length, 1);
    });

    test('empty items produce empty map', () {
      final s = VodState();
      expect(s.byCategory, isEmpty);
    });
  });

  group('VodState — filtered', () {
    test('returns all items when no category selected', () {
      final items = [
        _item(id: '1', category: 'Action'),
        _item(id: '2', category: 'Comedy'),
      ];
      final s = VodState(items: items);
      expect(s.filtered.length, 2);
    });

    test('filters by selected category', () {
      final items = [
        _item(id: '1', category: 'Action'),
        _item(id: '2', category: 'Comedy'),
        _item(id: '3', category: 'Action'),
      ];
      final s = VodState(items: items, selectedCategory: 'Action');
      expect(s.filtered.length, 2);
      expect(s.filtered.every((i) => i.category == 'Action'), true);
    });

    test('returns empty when category has no matches', () {
      final items = [_item(id: '1', category: 'Action')];
      final s = VodState(items: items, selectedCategory: 'Horror');
      expect(s.filtered, isEmpty);
    });
  });

  group('VodState — movieCategories / seriesCategories', () {
    test('extracts sorted movie categories', () {
      final items = [
        _item(id: '1', type: VodType.movie, category: 'Sci-Fi'),
        _item(id: '2', type: VodType.movie, category: 'Action'),
        _item(id: '3', type: VodType.series, category: 'Drama'),
        _item(id: '4', type: VodType.movie, category: 'Action'),
      ];
      final s = VodState(items: items);
      expect(s.movieCategories, ['Action', 'Sci-Fi']);
      expect(s.seriesCategories, ['Drama']);
    });

    test('excludes items with null or empty category', () {
      final items = [
        _item(id: '1', type: VodType.movie),
        _item(id: '2', type: VodType.movie, category: ''),
        _item(id: '3', type: VodType.movie, category: 'Action'),
      ];
      final s = VodState(items: items);
      expect(s.movieCategories, ['Action']);
    });
  });

  group('VodState.copyWith', () {
    test('preserves all fields when no args', () {
      final items = [_item(id: '1')];
      final s = VodState(
        items: items,
        categories: ['A'],
        selectedCategory: 'A',
        isLoading: true,
        error: 'oops',
      );
      final copy = s.copyWith();
      expect(copy.items.length, s.items.length);
      expect(copy.categories, s.categories);
      expect(copy.selectedCategory, s.selectedCategory);
      expect(copy.isLoading, s.isLoading);
      expect(copy.error, s.error);
    });

    test('overrides items', () {
      final s = VodState(items: [_item(id: '1')]);
      final newItems = [_item(id: '2'), _item(id: '3')];
      final copy = s.copyWith(items: newItems);
      expect(copy.items.length, 2);
    });

    test('clearError removes error', () {
      final s = VodState(error: 'bad');
      final copy = s.copyWith(clearError: true);
      expect(copy.error, isNull);
    });

    test('clearCategory removes selectedCategory', () {
      final s = VodState(
        items: [_item(id: '1', category: 'A')],
        selectedCategory: 'A',
      );
      final copy = s.copyWith(clearCategory: true);
      expect(copy.selectedCategory, isNull);
    });

    test('sets new error', () {
      final s = VodState();
      final copy = s.copyWith(error: 'fail');
      expect(copy.error, 'fail');
    });

    test('sets loading', () {
      final s = VodState();
      final copy = s.copyWith(isLoading: true);
      expect(copy.isLoading, true);
    });
  });
}
