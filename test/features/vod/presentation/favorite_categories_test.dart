import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/vod/presentation/'
    'providers/favorite_categories_provider.dart';

void main() {
  group('sortCategoriesWithFavorites', () {
    test('favorites come first, both sorted', () {
      final categories = ['Drama', 'Action', 'Comedy', 'Horror', 'Sci-Fi'];
      final favorites = {'Comedy', 'Action'};

      final result = sortCategoriesWithFavorites(categories, favorites);

      // Favorites sorted: Action, Comedy
      // Rest sorted: Drama, Horror, Sci-Fi
      expect(result, ['Action', 'Comedy', 'Drama', 'Horror', 'Sci-Fi']);
    });

    test('no favorites returns sorted list', () {
      final categories = ['Z', 'A', 'M'];
      final favorites = <String>{};

      final result = sortCategoriesWithFavorites(categories, favorites);
      expect(result, ['A', 'M', 'Z']);
    });

    test('all favorites returns sorted list', () {
      final categories = ['Z', 'A', 'M'];
      final favorites = {'Z', 'A', 'M'};

      final result = sortCategoriesWithFavorites(categories, favorites);
      expect(result, ['A', 'M', 'Z']);
    });

    test('favorites not in categories are ignored', () {
      final categories = ['A', 'B'];
      final favorites = {'C', 'A'};

      final result = sortCategoriesWithFavorites(categories, favorites);
      // A is favorite (and in list), B is rest
      // C is ignored because not in categories
      expect(result, ['A', 'B']);
    });

    test('empty categories returns empty', () {
      final result = sortCategoriesWithFavorites([], {'Action'});
      expect(result, isEmpty);
    });

    test('single category that is favorite', () {
      final result = sortCategoriesWithFavorites(['Only'], {'Only'});
      expect(result, ['Only']);
    });

    test('single category that is not favorite', () {
      final result = sortCategoriesWithFavorites(['Only'], <String>{});
      expect(result, ['Only']);
    });

    test('preserves separation with many items', () {
      final categories = List.generate(10, (i) => 'Cat_${9 - i}');
      // Favorites: Cat_5, Cat_1
      final favorites = {'Cat_5', 'Cat_1'};

      final result = sortCategoriesWithFavorites(categories, favorites);

      // Favs first: Cat_1, Cat_5
      // Then rest: Cat_0, Cat_2, Cat_3, Cat_4,
      //            Cat_6, Cat_7, Cat_8, Cat_9
      expect(result[0], 'Cat_1');
      expect(result[1], 'Cat_5');
      expect(result[2], 'Cat_0');
      expect(result.last, 'Cat_9');
      expect(result.length, 10);
    });
  });
}
