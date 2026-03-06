import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';

import '../../../../core/data/cache_service.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../iptv/presentation/providers/channel_providers.dart';
import '../../../vod/presentation/providers/vod_providers.dart';
import '../../data/repositories/search_history_repository_impl.dart';
import '../../data/repositories/search_repository_impl.dart';
import '../../domain/entities/grouped_search_results.dart';
import '../../domain/entities/search_filter.dart';
import '../../domain/entities/search_history_entry.dart';
import '../../domain/entities/search_state.dart';
import '../../domain/repositories/search_history_repository.dart';
import '../../domain/repositories/search_repository.dart';

// ── Repository Providers ─────────────────────────────────────────────────────

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepositoryImpl(ref.read(crispyBackendProvider));
});

final searchHistoryRepositoryProvider = Provider<SearchHistoryRepository>((
  ref,
) {
  return SearchHistoryRepositoryImpl(ref.read(cacheServiceProvider));
});

// ── Search State Provider ────────────────────────────────────────────────────

final searchControllerProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);

/// Manages search state including query, filters, results, and history.
class SearchNotifier extends Notifier<SearchState> {
  Timer? _debounce;

  /// Incremented on every new search. Stale async completions
  /// check this before writing state — if the value changed,
  /// the result is discarded (S-18: in-flight cancellation guard).
  int _searchGeneration = 0;

  @override
  SearchState build() {
    _loadHistory();

    // React to VOD and channel data changes so
    // categories populate once data arrives, and
    // re-run any active search when data loads.
    ref.listen(vodProvider, (prev, next) {
      _loadCategories();
      // Re-run search if results are empty and data just became available.
      // The (prev was empty) guard is intentionally removed — if a playlist
      // refresh loads new data while search has empty results, we should
      // re-trigger regardless of previous state.
      if (state.hasQuery &&
          !state.isLoading &&
          state.results.isEmpty &&
          next.items.isNotEmpty) {
        search(state.query);
      }
    });
    ref.listen(channelListProvider, (prev, next) {
      _loadCategories();
      // Re-run search if results are empty and data just became available.
      if (state.hasQuery &&
          !state.isLoading &&
          state.results.isEmpty &&
          next.channels.isNotEmpty) {
        search(state.query);
      }
    });

    // Initial load (may be empty if data not yet loaded).
    _loadCategories();
    return const SearchState();
  }

  /// Loads recent search history from database.
  Future<void> _loadHistory() async {
    try {
      final history =
          await ref.read(searchHistoryRepositoryProvider).getRecentSearches();
      state = state.copyWith(recentSearches: history);
    } catch (_) {
      // Ignore history load errors
    }
  }

  /// Loads available categories from VOD and IPTV.
  void _loadCategories() {
    try {
      final vodItems = ref.read(vodProvider).items;
      final channelState = ref.read(channelListProvider);
      final backend = ref.read(crispyBackendProvider);

      final vodCategoriesJson = jsonEncode(
        vodItems
            .map((i) => i.category)
            .whereType<String>()
            .where((c) => c.isNotEmpty)
            .toList(),
      );
      final channelGroupsJson = jsonEncode(
        channelState.groups.where((g) => g.isNotEmpty).toList(),
      );

      final result = backend.buildSearchCategories(
        vodCategoriesJson,
        channelGroupsJson,
      );
      final categories = (jsonDecode(result) as List).cast<String>();
      state = state.copyWith(availableCategories: categories);
    } catch (_) {
      // Ignore category load errors
    }
  }

  /// Performs a search with the given query.
  void search(String query) {
    state = state.copyWith(query: query, clearError: true);

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().isEmpty) {
      state = state.copyWith(
        results: GroupedSearchResults.empty,
        isLoading: false,
      );
      return;
    }

    // S-18: bump generation so any in-flight search discards its result.
    final generation = ++_searchGeneration;

    state = state.copyWith(isLoading: true);

    _debounce = Timer(CrispyAnimation.slow, () async {
      await _executeSearch(query, generation);
    });
  }

  /// Executes the actual search operation.
  ///
  /// [generation] is compared against [_searchGeneration] before writing
  /// state. If a newer search has started, this result is discarded (S-18).
  Future<void> _executeSearch(String query, int generation) async {
    // Read local content state
    const sources = <Never>[];
    final vodItems = ref.read(vodProvider).items;
    final epgEntries = ref.read(epgProvider).entries;
    final channels = ref.read(channelListProvider).channels;

    // Track whether we started with no local data — used below to
    // detect the race condition where data loaded while this search
    // was in-flight.
    final startedWithNoLocalData = vodItems.isEmpty && channels.isEmpty;

    try {
      final results = await ref
          .read(searchRepositoryProvider)
          .search(
            query,
            filter: state.filter,
            sources: sources,
            vodItems: vodItems,
            epgEntries: epgEntries,
            channels: channels,
          );

      // S-18: discard stale result if a newer search has started.
      if (generation != _searchGeneration) return;

      // Race-condition retry: if we started the search with no local
      // data (providers still loading) and got empty results, check
      // whether data has since arrived.  If it has, retry immediately
      // with the fresh snapshot — no extra debounce needed.
      //
      // This handles the case where playlist data loads during the
      // 500 ms debounce window and the ref.listen re-trigger was
      // blocked because isLoading was already true.
      if (results.isEmpty && startedWithNoLocalData) {
        final freshVod = ref.read(vodProvider).items;
        final freshChannels = ref.read(channelListProvider).channels;
        if (freshVod.isNotEmpty || freshChannels.isNotEmpty) {
          // Data is now available — retry this generation once.
          // startedWithNoLocalData will be false on re-entry so
          // this branch cannot recurse infinitely.
          await _executeSearch(query, generation);
          return;
        }
      }

      state = state.copyWith(results: results, isLoading: false);

      // Save to history if we have results
      if (results.isNotEmpty) {
        // FE-SR-07: pick a thumbnail from the best single-category result.
        String? thumbnailUrl;
        SearchHistoryResultType? resultType;
        if (results.channels.isNotEmpty) {
          thumbnailUrl = results.channels.first.logoUrl;
          resultType = SearchHistoryResultType.channel;
        } else if (results.movies.isNotEmpty) {
          thumbnailUrl = results.movies.first.logoUrl;
          resultType = SearchHistoryResultType.vod;
        } else if (results.series.isNotEmpty) {
          thumbnailUrl = results.series.first.logoUrl;
          resultType = SearchHistoryResultType.vod;
        }
        _saveToHistory(
          query,
          results.totalCount,
          thumbnailUrl: thumbnailUrl,
          resultType: resultType,
        );
      }
    } catch (e) {
      // S-18: discard stale error too.
      if (generation != _searchGeneration) return;
      state = state.copyWith(isLoading: false, error: 'Search failed: $e');
    }
  }

  /// Saves a search to history.
  ///
  /// FE-SR-07: optional [thumbnailUrl] and [resultType] attach a
  /// thumbnail to the history entry so the list can display it.
  Future<void> _saveToHistory(
    String query,
    int resultCount, {
    String? thumbnailUrl,
    SearchHistoryResultType? resultType,
  }) async {
    try {
      final entry = SearchHistoryEntry.create(
        query: query,
        resultCount: resultCount,
        thumbnailUrl: thumbnailUrl,
        resultType: resultType,
      );
      await ref.read(searchHistoryRepositoryProvider).saveSearch(entry);

      // Reload history
      final history =
          await ref.read(searchHistoryRepositoryProvider).getRecentSearches();
      state = state.copyWith(recentSearches: history);
    } catch (_) {
      // Ignore history save errors
    }
  }

  /// Updates the search filter and re-executes search.
  void updateFilter(SearchFilter filter) {
    state = state.copyWith(filter: filter);
    if (state.hasQuery) {
      search(state.query);
    }
  }

  /// Toggles a content type in the filter.
  void toggleContentType(SearchContentType type) {
    final newFilter = state.filter.toggleContentType(type);
    updateFilter(newFilter);
  }

  /// Sets the category filter.
  void setCategory(String? category) {
    final newFilter = state.filter.copyWith(
      category: category,
      clearCategory: category == null,
    );
    updateFilter(newFilter);
  }

  /// Sets the year range filter.
  void setYearRange(int? min, int? max) {
    final newFilter = state.filter.copyWith(
      yearMin: min,
      yearMax: max,
      clearYearRange: min == null && max == null,
    );
    updateFilter(newFilter);
  }

  /// Toggles search in description.
  void toggleSearchInDescription(bool value) {
    final newFilter = state.filter.copyWith(searchInDescription: value);
    updateFilter(newFilter);
  }

  /// Clears all active filters.
  void clearFilters() {
    updateFilter(const SearchFilter());
  }

  /// Selects a recent search entry.
  void selectRecentSearch(SearchHistoryEntry entry) {
    search(entry.query);
  }

  /// Removes a search entry from history.
  Future<void> removeFromHistory(String id) async {
    try {
      await ref.read(searchHistoryRepositoryProvider).removeSearch(id);
      final history =
          await ref.read(searchHistoryRepositoryProvider).getRecentSearches();
      state = state.copyWith(recentSearches: history);
    } catch (_) {
      // Ignore remove errors
    }
  }

  /// Clears all search history.
  Future<void> clearHistory() async {
    try {
      await ref.read(searchHistoryRepositoryProvider).clearAll();
      state = state.copyWith(recentSearches: []);
    } catch (_) {
      // Ignore clear errors
    }
  }

  /// Clears the current search query and results.
  void clearSearch() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    // S-18: bump generation so any in-flight search is invalidated.
    _searchGeneration++;
    state = state.copyWith(
      query: '',
      results: GroupedSearchResults.empty,
      isLoading: false,
      clearError: true,
    );
  }
}
