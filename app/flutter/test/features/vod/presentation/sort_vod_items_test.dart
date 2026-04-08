import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/vod/domain/entities/'
    'vod_item.dart';
import 'package:crispy_tivi/features/vod/presentation/'
    'providers/vod_providers.dart';

/// Helper to build a [VodItem] with minimal boilerplate.
VodItem _item({
  required String id,
  String name = 'Item',
  int? year,
  String? rating,
  DateTime? addedAt,
}) {
  return VodItem(
    id: id,
    name: name,
    streamUrl: 'http://x.com/$id',
    type: VodType.movie,
    year: year,
    rating: rating,
    addedAt: addedAt,
  );
}

void main() {
  late CacheService cache;

  setUp(() {
    cache = CacheService(MemoryBackend());
  });

  group('VodSortOption enum', () {
    test('has 5 values', () {
      expect(VodSortOption.values.length, 5);
    });

    test('each has a non-empty label', () {
      for (final opt in VodSortOption.values) {
        expect(opt.label.isNotEmpty, true);
      }
    });

    test('each has a non-empty sortByKey', () {
      for (final opt in VodSortOption.values) {
        expect(opt.sortByKey.isNotEmpty, true);
      }
    });
  });

  group('CacheService.sortVodItems', () {
    final items = [
      _item(
        id: '1',
        name: 'Charlie',
        year: 2020,
        rating: '7.5',
        addedAt: DateTime(2025, 1, 3),
      ),
      _item(
        id: '2',
        name: 'Alpha',
        year: 2022,
        rating: '9.0',
        addedAt: DateTime(2025, 1, 1),
      ),
      _item(
        id: '3',
        name: 'Bravo',
        year: 2018,
        rating: '8.2',
        addedAt: DateTime(2025, 1, 5),
      ),
    ];

    test('recentlyAdded — newest first', () async {
      final sorted = await cache.sortVodItems(
        items,
        VodSortOption.recentlyAdded.sortByKey,
      );
      expect(sorted[0].id, '3'); // Jan 5
      expect(sorted[1].id, '1'); // Jan 3
      expect(sorted[2].id, '2'); // Jan 1
    });

    test('nameAsc — alphabetical A-Z', () async {
      final sorted = await cache.sortVodItems(
        items,
        VodSortOption.nameAsc.sortByKey,
      );
      expect(sorted[0].name, 'Alpha');
      expect(sorted[1].name, 'Bravo');
      expect(sorted[2].name, 'Charlie');
    });

    test('nameDesc — alphabetical Z-A', () async {
      final sorted = await cache.sortVodItems(
        items,
        VodSortOption.nameDesc.sortByKey,
      );
      expect(sorted[0].name, 'Charlie');
      expect(sorted[1].name, 'Bravo');
      expect(sorted[2].name, 'Alpha');
    });

    test('yearDesc — newest year first', () async {
      final sorted = await cache.sortVodItems(
        items,
        VodSortOption.yearDesc.sortByKey,
      );
      expect(sorted[0].year, 2022);
      expect(sorted[1].year, 2020);
      expect(sorted[2].year, 2018);
    });

    test('ratingDesc — highest rating first', () async {
      final sorted = await cache.sortVodItems(
        items,
        VodSortOption.ratingDesc.sortByKey,
      );
      expect(sorted[0].rating, '9.0');
      expect(sorted[1].rating, '8.2');
      expect(sorted[2].rating, '7.5');
    });

    test('recentlyAdded handles null addedAt — null sorts last', () async {
      final mixed = [
        _item(id: 'a', addedAt: DateTime(2025, 6, 1)),
        _item(id: 'b'),
        _item(id: 'c', addedAt: DateTime(2025, 3, 1)),
      ];
      final sorted = await cache.sortVodItems(
        mixed,
        VodSortOption.recentlyAdded.sortByKey,
      );
      expect(sorted[0].id, 'a');
      expect(sorted[1].id, 'c');
      // null addedAt sorts last
      expect(sorted[2].id, 'b');
    });

    test('yearDesc handles null year — null sorts last', () async {
      final mixed = [
        _item(id: 'a', year: 2020),
        _item(id: 'b'),
        _item(id: 'c', year: 2015),
      ];
      final sorted = await cache.sortVodItems(
        mixed,
        VodSortOption.yearDesc.sortByKey,
      );
      expect(sorted[0].id, 'a');
      expect(sorted[1].id, 'c');
      // null year sorts last
      expect(sorted[2].id, 'b');
    });

    test('ratingDesc handles null and non-numeric', () async {
      final mixed = [
        _item(id: 'a', rating: '6.0'),
        _item(id: 'b'),
        _item(id: 'c', rating: 'N/A'),
      ];
      final sorted = await cache.sortVodItems(
        mixed,
        VodSortOption.ratingDesc.sortByKey,
      );
      expect(sorted[0].id, 'a');
      // null and 'N/A' are both NaN — sort last
      expect(sorted.sublist(1).map((i) => i.id).toSet(), {'b', 'c'});
    });

    test('nameAsc is case-insensitive', () async {
      final mixed = [
        _item(id: '1', name: 'banana'),
        _item(id: '2', name: 'Apple'),
        _item(id: '3', name: 'cherry'),
      ];
      final sorted = await cache.sortVodItems(
        mixed,
        VodSortOption.nameAsc.sortByKey,
      );
      expect(sorted[0].name, 'Apple');
      expect(sorted[1].name, 'banana');
      expect(sorted[2].name, 'cherry');
    });

    test('does not mutate original list', () async {
      final original = [_item(id: '1', name: 'Z'), _item(id: '2', name: 'A')];
      final origFirst = original.first.id;
      await cache.sortVodItems(original, VodSortOption.nameAsc.sortByKey);
      expect(original.first.id, origFirst);
    });

    test('empty list returns empty', () async {
      final sorted = await cache.sortVodItems(
        [],
        VodSortOption.nameAsc.sortByKey,
      );
      expect(sorted, isEmpty);
    });

    test('single item returns same item', () async {
      final single = [_item(id: '1', name: 'Only')];
      final sorted = await cache.sortVodItems(
        single,
        VodSortOption.nameAsc.sortByKey,
      );
      expect(sorted.length, 1);
      expect(sorted.first.id, '1');
    });
  });
}
