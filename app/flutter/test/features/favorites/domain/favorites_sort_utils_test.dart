import 'package:crispy_tivi/config/settings_state.dart';
import 'package:crispy_tivi/features/favorites/domain/utils/favorites_sort_utils.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/channel.dart';
import 'package:flutter_test/flutter_test.dart';

Channel _ch(String id, String name, {String? group}) => Channel(
  id: id,
  name: name,
  streamUrl: 'http://example.com/$id',
  group: group,
);

void main() {
  group('sortFavorites', () {
    final alpha = _ch('c', 'Alpha', group: 'Sports');
    final beta = _ch('a', 'Beta', group: 'News');
    final gamma = _ch('b', 'Gamma', group: 'News');

    // Original insertion order: alpha, beta, gamma
    final original = [alpha, beta, gamma];

    test('recentlyAdded preserves original order', () {
      final result = sortFavorites(original, FavoritesSort.recentlyAdded);
      expect(result, equals([alpha, beta, gamma]));
    });

    test('recentlyAdded does not mutate input list', () {
      final copy = List<Channel>.from(original);
      sortFavorites(copy, FavoritesSort.recentlyAdded);
      expect(copy, equals(original));
    });

    test('nameAsc sorts A–Z', () {
      final result = sortFavorites(original, FavoritesSort.nameAsc);
      expect(result.map((c) => c.name).toList(), ['Alpha', 'Beta', 'Gamma']);
    });

    test('nameDesc sorts Z–A', () {
      final result = sortFavorites(original, FavoritesSort.nameDesc);
      expect(result.map((c) => c.name).toList(), ['Gamma', 'Beta', 'Alpha']);
    });

    test('nameAsc is case-insensitive', () {
      final channels = [
        _ch('1', 'zebra'),
        _ch('2', 'Apple'),
        _ch('3', 'mango'),
      ];
      final result = sortFavorites(channels, FavoritesSort.nameAsc);
      expect(result.map((c) => c.name).toList(), ['Apple', 'mango', 'zebra']);
    });

    test('contentType groups by group then name within group', () {
      // News: Beta, Gamma (alphabetical). Sports: Alpha.
      final result = sortFavorites(original, FavoritesSort.contentType);
      expect(result.map((c) => c.name).toList(), ['Beta', 'Gamma', 'Alpha']);
    });

    test(
      'contentType puts null group first (empty string sorts before others)',
      () {
        final noGroup = _ch('x', 'Zap');
        final channels = [alpha, noGroup, beta];
        final result = sortFavorites(channels, FavoritesSort.contentType);
        // noGroup has group=null → '' which sorts before 'News' and 'Sports'
        expect(result.first.id, equals('x'));
      },
    );

    test('does not mutate the input list', () {
      final input = [gamma, alpha, beta];
      sortFavorites(input, FavoritesSort.nameAsc);
      // Input must be unchanged.
      expect(input, equals([gamma, alpha, beta]));
    });

    test('returns empty list for empty input', () {
      expect(sortFavorites([], FavoritesSort.nameAsc), isEmpty);
    });

    test('single element returns same element', () {
      expect(sortFavorites([alpha], FavoritesSort.nameDesc), equals([alpha]));
    });
  });
}
