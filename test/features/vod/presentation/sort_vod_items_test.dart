import 'package:flutter_test/flutter_test.dart';

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
  group('VodSortOption enum', () {
    test('has 5 values', () {
      expect(VodSortOption.values.length, 5);
    });

    test('each has a non-empty label', () {
      for (final opt in VodSortOption.values) {
        expect(opt.label.isNotEmpty, true);
      }
    });
  });

  group('sortVodItems', () {
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

    test('recentlyAdded — newest first', () {
      final sorted = sortVodItems(items, VodSortOption.recentlyAdded);
      expect(sorted[0].id, '3'); // Jan 5
      expect(sorted[1].id, '1'); // Jan 3
      expect(sorted[2].id, '2'); // Jan 1
    });

    test('nameAsc — alphabetical A-Z', () {
      final sorted = sortVodItems(items, VodSortOption.nameAsc);
      expect(sorted[0].name, 'Alpha');
      expect(sorted[1].name, 'Bravo');
      expect(sorted[2].name, 'Charlie');
    });

    test('nameDesc — alphabetical Z-A', () {
      final sorted = sortVodItems(items, VodSortOption.nameDesc);
      expect(sorted[0].name, 'Charlie');
      expect(sorted[1].name, 'Bravo');
      expect(sorted[2].name, 'Alpha');
    });

    test('yearDesc — newest year first', () {
      final sorted = sortVodItems(items, VodSortOption.yearDesc);
      expect(sorted[0].year, 2022);
      expect(sorted[1].year, 2020);
      expect(sorted[2].year, 2018);
    });

    test('ratingDesc — highest rating first', () {
      final sorted = sortVodItems(items, VodSortOption.ratingDesc);
      expect(sorted[0].rating, '9.0');
      expect(sorted[1].rating, '8.2');
      expect(sorted[2].rating, '7.5');
    });

    test('recentlyAdded handles null addedAt', () {
      final mixed = [
        _item(id: 'a', addedAt: DateTime(2025, 6, 1)),
        _item(id: 'b'),
        _item(id: 'c', addedAt: DateTime(2025, 3, 1)),
      ];
      final sorted = sortVodItems(mixed, VodSortOption.recentlyAdded);
      expect(sorted[0].id, 'a');
      expect(sorted[1].id, 'c');
      // null addedAt falls to DateTime(2000)
      expect(sorted[2].id, 'b');
    });

    test('yearDesc handles null year as 0', () {
      final mixed = [
        _item(id: 'a', year: 2020),
        _item(id: 'b'),
        _item(id: 'c', year: 2015),
      ];
      final sorted = sortVodItems(mixed, VodSortOption.yearDesc);
      expect(sorted[0].id, 'a');
      expect(sorted[1].id, 'c');
      expect(sorted[2].id, 'b');
    });

    test('ratingDesc handles null and non-numeric', () {
      final mixed = [
        _item(id: 'a', rating: '6.0'),
        _item(id: 'b'),
        _item(id: 'c', rating: 'N/A'),
      ];
      final sorted = sortVodItems(mixed, VodSortOption.ratingDesc);
      expect(sorted[0].id, 'a');
      // null and 'N/A' both parse to 0.0
      expect(sorted[1].id, 'b');
      expect(sorted[2].id, 'c');
    });

    test('nameAsc is case-insensitive', () {
      final mixed = [
        _item(id: '1', name: 'banana'),
        _item(id: '2', name: 'Apple'),
        _item(id: '3', name: 'cherry'),
      ];
      final sorted = sortVodItems(mixed, VodSortOption.nameAsc);
      expect(sorted[0].name, 'Apple');
      expect(sorted[1].name, 'banana');
      expect(sorted[2].name, 'cherry');
    });

    test('does not mutate original list', () {
      final original = [_item(id: '1', name: 'Z'), _item(id: '2', name: 'A')];
      final origFirst = original.first.id;
      sortVodItems(original, VodSortOption.nameAsc);
      expect(original.first.id, origFirst);
    });

    test('empty list returns empty', () {
      final sorted = sortVodItems([], VodSortOption.nameAsc);
      expect(sorted, isEmpty);
    });

    test('single item returns same item', () {
      final single = [_item(id: '1', name: 'Only')];
      final sorted = sortVodItems(single, VodSortOption.nameAsc);
      expect(sorted.length, 1);
      expect(sorted.first.id, '1');
    });
  });
}
