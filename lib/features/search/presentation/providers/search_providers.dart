import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/source_filter_provider.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../iptv/presentation/providers/channel_providers.dart';
import '../../../vod/presentation/providers/vod_providers.dart';
import '../../domain/entities/grouped_search_results.dart';
import '../../domain/entities/search_filter.dart';
import '../../domain/entities/search_history_entry.dart';
import '../../domain/entities/search_state.dart';
import 'search_repository_providers.dart';

export 'search_repository_providers.dart';
export 'search_notifier_actions.dart';

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
      if (state.hasQuery &&
          !state.isLoading &&
          state.results.isEmpty &&
          next.items.isNotEmpty) {
        search(state.query);
      }
    });
    ref.listen(channelListProvider, (prev, next) {
      _loadCategories();
      if (state.hasQuery &&
          !state.isLoading &&
          state.results.isEmpty &&
          next.channels.isNotEmpty) {
        search(state.query);
      }
    });

    _loadCategories();
    return const SearchState();
  }

  /// Loads recent search history from database.
  Future<void> _loadHistory() async {
    try {
      final history =
          await ref.read(searchHistoryRepositoryProvider).getRecentSearches();
      state = state.copyWith(recentSearches: history);
    } catch (e) {
      debugPrint('SearchNotifier._loadHistory: $e');
    }
  }

  /// Loads available categories from VOD and IPTV.
  void _loadCategories() {
    try {
      final vodItems = ref.read(vodProvider).items;
      final channelState = ref.read(channelListProvider);
      final vodCategories =
          vodItems
              .map((i) => i.category)
              .whereType<String>()
              .where((c) => c.isNotEmpty)
              .toList();
      final channelGroups =
          channelState.groups.where((g) => g.isNotEmpty).toList();

      final categories = ref
          .read(searchRepositoryProvider)
          .buildSearchCategories(vodCategories, channelGroups);
      state = state.copyWith(availableCategories: categories);
    } catch (e) {
      debugPrint('SearchNotifier._loadCategories: $e');
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

    final generation = ++_searchGeneration;
    state = state.copyWith(isLoading: true);

    _debounce = Timer(CrispyAnimation.slow, () async {
      await _executeSearch(query, generation);
    });
  }

  /// Executes the actual search operation.
  Future<void> _executeSearch(String query, int generation) async {
    const sources = <Never>[];
    final effectiveSourceIds = ref.read(effectiveSourceIdsProvider);
    final allVodItems = ref.read(vodProvider).items;
    final epgEntries = ref.read(epgProvider).entries;
    final allChannels = ref.read(channelListProvider).channels;

    final vodItems =
        effectiveSourceIds.isEmpty
            ? allVodItems
            : allVodItems
                .where(
                  (i) =>
                      i.sourceId != null &&
                      effectiveSourceIds.contains(i.sourceId),
                )
                .toList();
    final channels =
        effectiveSourceIds.isEmpty
            ? allChannels
            : allChannels
                .where(
                  (ch) =>
                      ch.sourceId != null &&
                      effectiveSourceIds.contains(ch.sourceId),
                )
                .toList();

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

      if (generation != _searchGeneration) return;

      if (results.isEmpty && startedWithNoLocalData) {
        final freshEffective = ref.read(effectiveSourceIdsProvider);
        final freshAllVod = ref.read(vodProvider).items;
        final freshAllChannels = ref.read(channelListProvider).channels;
        final freshVod =
            freshEffective.isEmpty
                ? freshAllVod
                : freshAllVod
                    .where(
                      (i) =>
                          i.sourceId != null &&
                          freshEffective.contains(i.sourceId),
                    )
                    .toList();
        final freshChannels =
            freshEffective.isEmpty
                ? freshAllChannels
                : freshAllChannels
                    .where(
                      (ch) =>
                          ch.sourceId != null &&
                          freshEffective.contains(ch.sourceId),
                    )
                    .toList();
        if (freshVod.isNotEmpty || freshChannels.isNotEmpty) {
          await _executeSearch(query, generation);
          return;
        }
      }

      state = state.copyWith(results: results, isLoading: false);

      if (results.isNotEmpty) {
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
      if (generation != _searchGeneration) return;
      state = state.copyWith(isLoading: false, error: 'Search failed: $e');
    }
  }

  /// Saves a search to history.
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
      final history =
          await ref.read(searchHistoryRepositoryProvider).getRecentSearches();
      state = state.copyWith(recentSearches: history);
    } catch (e) {
      debugPrint('SearchNotifier._saveToHistory: $e');
    }
  }

  /// Removes a search entry from history.
  Future<void> removeFromHistory(String id) async {
    try {
      await ref.read(searchHistoryRepositoryProvider).removeSearch(id);
      final history =
          await ref.read(searchHistoryRepositoryProvider).getRecentSearches();
      state = state.copyWith(recentSearches: history);
    } catch (e) {
      debugPrint('SearchNotifier.removeFromHistory: $e');
    }
  }

  /// Clears all search history.
  Future<void> clearHistory() async {
    try {
      await ref.read(searchHistoryRepositoryProvider).clearAll();
      state = state.copyWith(recentSearches: []);
    } catch (e) {
      debugPrint('SearchNotifier.clearHistory: $e');
    }
  }

  /// Resets search to a clean slate for a new session (S-011).
  void resetForNewSession() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _searchGeneration++;
    state = state.copyWith(
      query: '',
      results: GroupedSearchResults.empty,
      isLoading: false,
      clearError: true,
    );
  }

  /// Clears the current search query and results.
  void clearSearch() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _searchGeneration++;
    state = state.copyWith(
      query: '',
      results: GroupedSearchResults.empty,
      isLoading: false,
      clearError: true,
    );
  }
}
