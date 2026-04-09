import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/search/domain/entities/search_filter.dart';
import 'package:crispy_tivi/features/search/domain/entities/search_state.dart';
import 'package:crispy_tivi/features/search/presentation/providers/search_providers.dart';
import 'package:crispy_tivi/features/search/domain/repositories/search_repository.dart';
import 'package:crispy_tivi/features/search/domain/repositories/search_history_repository.dart';
import 'package:crispy_tivi/features/search/domain/entities/grouped_search_results.dart';
import 'package:crispy_tivi/features/search/domain/entities/search_history_entry.dart';
import 'package:crispy_tivi/core/domain/media_source.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/epg_entry.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/channel.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';

class MockSearchHistoryRepo implements SearchHistoryRepository {
  Map<String, SearchHistoryEntry> entries = {};

  @override
  Future<void> clearAll() async => entries.clear();

  @override
  Future<List<SearchHistoryEntry>> getRecentSearches({int limit = 10}) async {
    final list = entries.values.toList();
    list.sort((a, b) => b.searchedAt.compareTo(a.searchedAt));
    return list.take(limit).toList();
  }

  @override
  Future<void> removeSearch(String id) async => entries.remove(id);

  @override
  Future<void> saveSearch(SearchHistoryEntry entry) async {
    entries[entry.id] = entry;
  }
}

class MockSearchRepository implements SearchRepository {
  Future<GroupedSearchResults> Function(String)? onSearch;

  @override
  Future<GroupedSearchResults> search(
    String query, {
    SearchFilter? filter,
    List<MediaSource>? sources,
    List<VodItem>? vodItems,
    Map<String, List<EpgEntry>>? epgEntries,
    List<Channel>? channels,
  }) async {
    if (onSearch != null) return onSearch!(query);
    return GroupedSearchResults.empty;
  }

  @override
  List<String> buildSearchCategories(
    List<String> vodCategories,
    List<String> channelGroups,
  ) => [...vodCategories, ...channelGroups];
}

void main() {
  group('SearchState & Filter', () {
    test('SearchFilter toggles content types', () {
      const filter = SearchFilter(contentTypes: {});
      expect(filter.contentTypes.isEmpty, isTrue);

      final toggled = filter.toggleContentType(SearchContentType.channels);
      expect(toggled.contentTypes.contains(SearchContentType.channels), isTrue);

      final toggledOff = toggled.toggleContentType(SearchContentType.channels);
      expect(toggledOff.contentTypes.isEmpty, isTrue);
    });

    test('SearchState hasQuery identifies valid queries', () {
      expect(const SearchState().hasQuery, isFalse);
      expect(const SearchState(query: ' ').hasQuery, isFalse);
      expect(const SearchState(query: 'test').hasQuery, isTrue);
    });
  });

  group('SearchNotifier', () {
    late ProviderContainer container;
    late MockSearchHistoryRepo mockHistoryRepo;
    late MockSearchRepository mockSearchRepo;

    setUp(() {
      mockHistoryRepo = MockSearchHistoryRepo();
      mockSearchRepo = MockSearchRepository();
      container = ProviderContainer(
        overrides: [
          crispyBackendProvider.overrideWithValue(MemoryBackend()),
          searchHistoryRepositoryProvider.overrideWithValue(mockHistoryRepo),
          searchRepositoryProvider.overrideWithValue(mockSearchRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial build loads history', () async {
      final entry = SearchHistoryEntry.create(
        query: 'Initial query',
        resultCount: 5,
      );
      await mockHistoryRepo.saveSearch(entry);

      // Trigger initialization
      container.read(searchControllerProvider);

      // Since _loadHistory is fire-and-forget in build, allow a few microtask
      // turns for the async repository read to settle.
      SearchState updatedState = container.read(searchControllerProvider);
      for (var i = 0; i < 5 && updatedState.recentSearches.isEmpty; i++) {
        await Future.delayed(Duration.zero);
        updatedState = container.read(searchControllerProvider);
      }

      expect(updatedState.recentSearches.length, 1);
      expect(updatedState.recentSearches.first.query, 'Initial query');
    });

    test('updateFilter triggers search if query exists', () async {
      final notifier = container.read(searchControllerProvider.notifier);
      notifier.search('test'); // sets state and triggers debounce

      bool searchCalled = false;
      mockSearchRepo.onSearch = (q) async {
        searchCalled = true;
        return GroupedSearchResults.empty;
      };

      notifier.updateFilter(const SearchFilter(searchInDescription: true));
      expect(
        container.read(searchControllerProvider).filter.searchInDescription,
        isTrue,
      );
      // Wait for debounce and search
      await Future.delayed(const Duration(milliseconds: 650));
      expect(searchCalled, isTrue);
    });

    test('clearSearch clears query and cancels inflight', () async {
      final notifier = container.read(searchControllerProvider.notifier);

      mockSearchRepo.onSearch = (q) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return GroupedSearchResults.empty;
      };

      // T0: emit slow search
      notifier.search('slow');

      // T1: clear search
      notifier.clearSearch();
      final stateAfterClear = container.read(searchControllerProvider);

      expect(stateAfterClear.query, isEmpty);
      expect(stateAfterClear.isLoading, isFalse);

      // T2: wait for slow search to end
      await Future.delayed(const Duration(milliseconds: 200));

      final stateFinal = container.read(searchControllerProvider);
      // Ensure the old result didn't overwrite the clear
      expect(stateFinal.query, isEmpty);
      expect(stateFinal.isLoading, isFalse);
    });
  });
}
