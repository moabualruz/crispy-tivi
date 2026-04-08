import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/data/memory_backend.dart';

/// Thin helper: calls the backend's [sortCategoriesWithFavorites]
/// and deserialises the JSON result.
List<String> sortCats(
  MemoryBackend backend,
  List<String> categories,
  Set<String> favorites,
) {
  final result = backend.sortCategoriesWithFavorites(
    jsonEncode(categories),
    jsonEncode(favorites.toList()),
  );
  return (jsonDecode(result) as List).cast<String>();
}

void main() {
  late MemoryBackend backend;

  setUp(() => backend = MemoryBackend());

  group('sortCategoriesWithFavorites (via backend)', () {
    test('favorites come first, both sorted', () {
      final categories = ['Drama', 'Action', 'Comedy', 'Horror', 'Sci-Fi'];
      final favorites = {'Comedy', 'Action'};

      final result = sortCats(backend, categories, favorites);

      // Favorites sorted: Action, Comedy
      // Rest sorted: Drama, Horror, Sci-Fi
      expect(result, ['Action', 'Comedy', 'Drama', 'Horror', 'Sci-Fi']);
    });

    test('no favorites returns sorted list', () {
      final categories = ['Z', 'A', 'M'];
      final favorites = <String>{};

      final result = sortCats(backend, categories, favorites);
      expect(result, ['A', 'M', 'Z']);
    });

    test('all favorites returns sorted list', () {
      final categories = ['Z', 'A', 'M'];
      final favorites = {'Z', 'A', 'M'};

      final result = sortCats(backend, categories, favorites);
      expect(result, ['A', 'M', 'Z']);
    });

    test('favorites not in categories are ignored', () {
      final categories = ['A', 'B'];
      final favorites = {'C', 'A'};

      final result = sortCats(backend, categories, favorites);
      // A is favorite (and in list), B is rest
      // C is ignored because not in categories
      expect(result, ['A', 'B']);
    });

    test('empty categories returns empty', () {
      final result = sortCats(backend, [], {'Action'});
      expect(result, isEmpty);
    });

    test('single category that is favorite', () {
      final result = sortCats(backend, ['Only'], {'Only'});
      expect(result, ['Only']);
    });

    test('single category that is not favorite', () {
      final result = sortCats(backend, ['Only'], <String>{});
      expect(result, ['Only']);
    });

    test('preserves separation with many items', () {
      final categories = List.generate(10, (i) => 'Cat_${9 - i}');
      // Favorites: Cat_5, Cat_1
      final favorites = {'Cat_5', 'Cat_1'};

      final result = sortCats(backend, categories, favorites);

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
