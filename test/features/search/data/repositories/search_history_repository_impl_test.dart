import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/features/search/data/'
    'repositories/search_history_repository_impl.dart';
import 'package:crispy_tivi/features/search/domain/'
    'entities/search_history_entry.dart';

class MockCacheService extends Mock implements CacheService {}

void main() {
  late MockCacheService mockCache;
  late SearchHistoryRepositoryImpl repo;

  setUpAll(() {
    registerFallbackValue(
      SearchHistoryEntry(
        id: '_fallback',
        query: '',
        searchedAt: DateTime(2025),
      ),
    );
  });

  setUp(() {
    mockCache = MockCacheService();
    repo = SearchHistoryRepositoryImpl(mockCache);
  });

  // ── Helpers ────────────────────────────────────────

  SearchHistoryEntry makeEntry({
    required String id,
    required String query,
    required DateTime searchedAt,
    int resultCount = 0,
  }) => SearchHistoryEntry(
    id: id,
    query: query,
    searchedAt: searchedAt,
    resultCount: resultCount,
  );

  // ── getRecentSearches ──────────────────────────────

  group('getRecentSearches', () {
    test('returns empty list when cache has no entries', () async {
      when(() => mockCache.loadSearchHistory()).thenAnswer((_) async => []);

      final result = await repo.getRecentSearches();

      expect(result, isEmpty);
      verify(() => mockCache.loadSearchHistory()).called(1);
    });

    test('returns entries sorted by searchedAt descending', () async {
      final old = makeEntry(
        id: 's1',
        query: 'old',
        searchedAt: DateTime(2025, 1, 1),
      );
      final mid = makeEntry(
        id: 's2',
        query: 'mid',
        searchedAt: DateTime(2025, 6, 1),
      );
      final recent = makeEntry(
        id: 's3',
        query: 'recent',
        searchedAt: DateTime(2026, 1, 1),
      );

      when(
        () => mockCache.loadSearchHistory(),
      ).thenAnswer((_) async => [mid, old, recent]);

      final result = await repo.getRecentSearches();

      expect(result.length, 3);
      expect(result[0].query, 'recent');
      expect(result[1].query, 'mid');
      expect(result[2].query, 'old');
    });

    test('respects the limit parameter', () async {
      final entries = List.generate(
        15,
        (i) => makeEntry(
          id: 's_$i',
          query: 'q$i',
          searchedAt: DateTime(2025, 1, 1 + i),
        ),
      );

      when(
        () => mockCache.loadSearchHistory(),
      ).thenAnswer((_) async => entries);

      final result = await repo.getRecentSearches(limit: 5);

      expect(result.length, 5);
    });

    test('uses default limit of 10', () async {
      final entries = List.generate(
        20,
        (i) => makeEntry(
          id: 's_$i',
          query: 'q$i',
          searchedAt: DateTime(2025, 1, 1 + i),
        ),
      );

      when(
        () => mockCache.loadSearchHistory(),
      ).thenAnswer((_) async => entries);

      final result = await repo.getRecentSearches();

      expect(result.length, 10);
    });

    test('returns all entries when fewer than limit', () async {
      final entries = [
        makeEntry(id: 's1', query: 'only', searchedAt: DateTime(2025, 1, 1)),
      ];

      when(
        () => mockCache.loadSearchHistory(),
      ).thenAnswer((_) async => entries);

      final result = await repo.getRecentSearches(limit: 10);

      expect(result.length, 1);
      expect(result.first.query, 'only');
    });
  });

  // ── saveSearch ─────────────────────────────────────

  group('saveSearch', () {
    test('deletes existing entries by query then saves', () async {
      final entry = makeEntry(
        id: 's1',
        query: 'flutter',
        searchedAt: DateTime(2025, 6, 1),
        resultCount: 42,
      );

      when(
        () => mockCache.deleteSearchEntriesByQuery(any()),
      ).thenAnswer((_) async {});
      when(() => mockCache.saveSearchEntry(any())).thenAnswer((_) async {});

      await repo.saveSearch(entry);

      verify(() => mockCache.deleteSearchEntriesByQuery('flutter')).called(1);
      verify(() => mockCache.saveSearchEntry(entry)).called(1);
    });

    test('calls delete before save to avoid duplicates', () async {
      final callOrder = <String>[];
      final entry = makeEntry(
        id: 's1',
        query: 'test',
        searchedAt: DateTime(2025, 1, 1),
      );

      when(() => mockCache.deleteSearchEntriesByQuery(any())).thenAnswer((
        _,
      ) async {
        callOrder.add('delete');
      });
      when(() => mockCache.saveSearchEntry(any())).thenAnswer((_) async {
        callOrder.add('save');
      });

      await repo.saveSearch(entry);

      expect(callOrder, ['delete', 'save']);
    });

    test('passes exact entry to cache save', () async {
      final entry = makeEntry(
        id: 's1',
        query: 'dart',
        searchedAt: DateTime(2026, 2, 1),
        resultCount: 7,
      );

      when(
        () => mockCache.deleteSearchEntriesByQuery(any()),
      ).thenAnswer((_) async {});
      when(() => mockCache.saveSearchEntry(any())).thenAnswer((_) async {});

      await repo.saveSearch(entry);

      final captured =
          verify(() => mockCache.saveSearchEntry(captureAny())).captured;
      expect(captured.single, entry);
    });
  });

  // ── removeSearch ───────────────────────────────────

  group('removeSearch', () {
    test('delegates to cache deleteSearchEntry', () async {
      when(() => mockCache.deleteSearchEntry(any())).thenAnswer((_) async {});

      await repo.removeSearch('s42');

      verify(() => mockCache.deleteSearchEntry('s42')).called(1);
    });

    test('passes exact ID to cache', () async {
      when(() => mockCache.deleteSearchEntry(any())).thenAnswer((_) async {});

      await repo.removeSearch('search_999');

      verify(() => mockCache.deleteSearchEntry('search_999')).called(1);
    });

    test('handles empty string ID without error', () async {
      when(() => mockCache.deleteSearchEntry(any())).thenAnswer((_) async {});

      await repo.removeSearch('');

      verify(() => mockCache.deleteSearchEntry('')).called(1);
    });
  });

  // ── clearAll ───────────────────────────────────────

  group('clearAll', () {
    test('delegates to cache clearSearchHistory', () async {
      when(() => mockCache.clearSearchHistory()).thenAnswer((_) async {});

      await repo.clearAll();

      verify(() => mockCache.clearSearchHistory()).called(1);
    });

    test('can be called multiple times without error', () async {
      when(() => mockCache.clearSearchHistory()).thenAnswer((_) async {});

      await repo.clearAll();
      await repo.clearAll();

      verify(() => mockCache.clearSearchHistory()).called(2);
    });

    test('does not call any other cache methods', () async {
      when(() => mockCache.clearSearchHistory()).thenAnswer((_) async {});

      await repo.clearAll();

      verifyNever(() => mockCache.deleteSearchEntry(any()));
      verifyNever(() => mockCache.deleteSearchEntriesByQuery(any()));
    });
  });
}
