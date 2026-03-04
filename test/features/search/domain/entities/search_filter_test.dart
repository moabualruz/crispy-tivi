import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/search/domain/entities/search_filter.dart';
import 'package:crispy_tivi/features/search/domain/entities/search_history_entry.dart';

void main() {
  group('SearchFilter', () {
    test('default constructor has no active filters', () {
      const filter = SearchFilter();

      expect(filter.contentTypes, isEmpty);
      expect(filter.category, isNull);
      expect(filter.yearMin, isNull);
      expect(filter.yearMax, isNull);
      expect(filter.searchInDescription, isFalse);
      expect(filter.hasActiveFilters, isFalse);
    });

    group('hasActiveFilters', () {
      test('returns true when contentTypes is non-empty', () {
        const filter = SearchFilter(contentTypes: {SearchContentType.channels});
        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns true when category is set', () {
        const filter = SearchFilter(category: 'Sports');
        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns true when yearMin is set', () {
        const filter = SearchFilter(yearMin: 2020);
        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns true when yearMax is set', () {
        const filter = SearchFilter(yearMax: 2025);
        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns true when searchInDescription is true', () {
        const filter = SearchFilter(searchInDescription: true);
        expect(filter.hasActiveFilters, isTrue);
      });
    });

    group('isTypeEnabled', () {
      test('returns true for any type when contentTypes is empty', () {
        const filter = SearchFilter();

        for (final type in SearchContentType.values) {
          expect(filter.isTypeEnabled(type), isTrue);
        }
      });

      test('returns true only for selected types', () {
        const filter = SearchFilter(
          contentTypes: {SearchContentType.channels, SearchContentType.movies},
        );

        expect(filter.isTypeEnabled(SearchContentType.channels), isTrue);
        expect(filter.isTypeEnabled(SearchContentType.movies), isTrue);
        expect(filter.isTypeEnabled(SearchContentType.series), isFalse);
        expect(filter.isTypeEnabled(SearchContentType.epg), isFalse);
      });
    });

    group('toggleContentType', () {
      test('adds type when not present', () {
        const filter = SearchFilter();
        final toggled = filter.toggleContentType(SearchContentType.channels);

        expect(toggled.contentTypes, contains(SearchContentType.channels));
      });

      test('removes type when already present', () {
        const filter = SearchFilter(contentTypes: {SearchContentType.channels});
        final toggled = filter.toggleContentType(SearchContentType.channels);

        expect(toggled.contentTypes, isEmpty);
      });

      test('preserves other types when toggling', () {
        const filter = SearchFilter(
          contentTypes: {SearchContentType.channels, SearchContentType.movies},
        );
        final toggled = filter.toggleContentType(SearchContentType.channels);

        expect(toggled.contentTypes, {SearchContentType.movies});
      });
    });

    group('copyWith', () {
      test('returns identical filter when no params given', () {
        const filter = SearchFilter(
          contentTypes: {SearchContentType.epg},
          category: 'News',
          yearMin: 2020,
          yearMax: 2025,
          searchInDescription: true,
        );
        final copy = filter.copyWith();

        expect(copy, equals(filter));
      });

      test('clearCategory nullifies category', () {
        const filter = SearchFilter(category: 'Sports');
        final cleared = filter.copyWith(clearCategory: true);

        expect(cleared.category, isNull);
      });

      test('clearYearRange nullifies both yearMin and yearMax', () {
        const filter = SearchFilter(yearMin: 2020, yearMax: 2025);
        final cleared = filter.copyWith(clearYearRange: true);

        expect(cleared.yearMin, isNull);
        expect(cleared.yearMax, isNull);
      });

      test('new category overrides existing', () {
        const filter = SearchFilter(category: 'Sports');
        final updated = filter.copyWith(category: 'News');

        expect(updated.category, 'News');
      });

      test('clearCategory takes precedence over new category', () {
        const filter = SearchFilter(category: 'Sports');
        final result = filter.copyWith(category: 'News', clearCategory: true);

        expect(result.category, isNull);
      });
    });

    group('clear', () {
      test('resets all filters to default', () {
        const filter = SearchFilter(
          contentTypes: {SearchContentType.movies},
          category: 'Action',
          yearMin: 2020,
          yearMax: 2025,
          searchInDescription: true,
        );
        final cleared = filter.clear();

        expect(cleared, equals(const SearchFilter()));
        expect(cleared.hasActiveFilters, isFalse);
      });
    });

    group('equality', () {
      test('equal when all fields match', () {
        const a = SearchFilter(
          contentTypes: {SearchContentType.channels, SearchContentType.movies},
          category: 'Sports',
        );
        const b = SearchFilter(
          contentTypes: {SearchContentType.channels, SearchContentType.movies},
          category: 'Sports',
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('not equal when fields differ', () {
        const a = SearchFilter(category: 'Sports');
        const b = SearchFilter(category: 'News');

        expect(a, isNot(equals(b)));
      });
    });
  });

  group('SearchHistoryEntry', () {
    test('create factory generates id and timestamp', () {
      final entry = SearchHistoryEntry.create(query: 'test', resultCount: 5);

      expect(entry.id, startsWith('search_'));
      expect(entry.query, 'test');
      expect(entry.resultCount, 5);
      expect(entry.searchedAt, isNotNull);
    });

    test('copyWith overrides specified fields', () {
      final entry = SearchHistoryEntry(
        id: 'search_1',
        query: 'original',
        searchedAt: DateTime(2025, 1, 1),
        resultCount: 3,
      );
      final copy = entry.copyWith(query: 'updated', resultCount: 10);

      expect(copy.id, 'search_1');
      expect(copy.query, 'updated');
      expect(copy.resultCount, 10);
    });

    test('equality is based on id only', () {
      final a = SearchHistoryEntry(
        id: 'search_1',
        query: 'foo',
        searchedAt: DateTime(2025, 1, 1),
      );
      final b = SearchHistoryEntry(
        id: 'search_1',
        query: 'bar',
        searchedAt: DateTime(2026, 6, 1),
      );

      expect(a, equals(b));
    });

    test('toString returns formatted string', () {
      final entry = SearchHistoryEntry(
        id: 'search_1',
        query: 'test',
        searchedAt: DateTime(2025, 1, 1),
      );

      expect(entry.toString(), 'SearchHistoryEntry(test)');
    });
  });
}
