import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/vod/presentation/providers/vod_providers.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';

void main() {
  group('VodState Logic', () {
    final item1 = VodItem(
      id: '1',
      name: 'Alpha Movie',
      type: VodType.movie,
      category: 'Action',
      posterUrl: 'http://img/alpha.jpg',
      year: 2020,
      streamUrl: 'http://test1',
    );
    final item2 = VodItem(
      id: '2',
      name: 'Beta Series',
      type: VodType.series,
      category: 'Drama',
      year: 2024,
      streamUrl: 'http://test2',
    );
    final item3 = VodItem(
      id: '3',
      name: 'Zeta Movie',
      type: VodType.movie,
      category: 'Action',
      year: 2022,
      streamUrl: 'http://test3',
    );

    final items = [item1, item2, item3];

    test('Computes categorized states correctly', () {
      final state = VodState(items: items);

      expect(state.movies.length, 2);
      expect(state.series.length, 1);

      expect(state.byCategory['Action']?.length, 2);
      expect(state.byCategory['Drama']?.length, 1);

      expect(state.movieCategories, ['Action']);
      expect(state.seriesCategories, ['Drama']);

      expect(state.featured.length, 1); // only item1 has posterUrl
      expect(state.featured.first.id, '1');

      expect(state.newReleases.length, 3);
      expect(state.newReleases.first.id, '2'); // 2024 is newest
      expect(state.newReleases.last.id, '1'); // 2020 is oldest
    });

    test('Filtering by selected category', () {
      final state = VodState(items: items, selectedCategory: 'Drama');
      expect(state.filtered.length, 1);
      expect(state.filtered.first.id, '2');
    });

    test('State copyWith behaviors', () {
      final state = VodState(items: items, selectedCategory: 'Action');
      final newItems = [
        ...items,
        VodItem(
          id: '4',
          name: 'New',
          type: VodType.movie,
          streamUrl: 'http://test4',
        ),
      ];

      final updated = state.copyWith(items: newItems, clearCategory: true);

      expect(updated.items.length, 4);
      expect(updated.selectedCategory, isNull);
      expect(
        updated.filtered.length,
        4,
      ); // All items because category is cleared
    });
  });

  group('sortVodItems', () {
    final t1 = DateTime(2024);
    final t2 = DateTime(2023);

    final items = [
      VodItem(
        id: '1',
        name: 'B',
        addedAt: t2,
        year: 2022,
        rating: '5.0',
        type: VodType.movie,
        streamUrl: 'http://1',
      ),
      VodItem(
        id: '2',
        name: 'A',
        addedAt: t1,
        year: 2024,
        rating: '8.0',
        type: VodType.movie,
        streamUrl: 'http://2',
      ),
      VodItem(
        id: '3',
        name: 'C',
        rating: 'Not a number',
        type: VodType.movie,
        streamUrl: 'http://3',
      ), // no year/addedAt
    ];

    test('nameAsc', () {
      final sorted = sortVodItems(items, VodSortOption.nameAsc);
      expect(sorted.map((e) => e.name), ['A', 'B', 'C']);
    });

    test('nameDesc', () {
      final sorted = sortVodItems(items, VodSortOption.nameDesc);
      expect(sorted.map((e) => e.name), ['C', 'B', 'A']);
    });

    test('recentlyAdded - newest first, nulls last', () {
      final sorted = sortVodItems(items, VodSortOption.recentlyAdded);
      expect(sorted.map((e) => e.id), ['2', '1', '3']);
    });

    test('yearDesc - newest first, nulls last', () {
      final sorted = sortVodItems(items, VodSortOption.yearDesc);
      expect(sorted.map((e) => e.id), ['2', '1', '3']);
    });

    test('ratingDesc - highest first, NaNs last', () {
      final sorted = sortVodItems(items, VodSortOption.ratingDesc);
      expect(sorted.map((e) => e.id), ['2', '1', '3']);
    });
  });
}
