import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/source_filter_provider.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../iptv/presentation/providers/channel_providers.dart';
import '../../../vod/presentation/providers/vod_providers.dart';
import '../../domain/entities/grouped_search_results.dart';
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
    ref.watch(effectiveSourceIdsProvider);

    void onCatalogUpdated() {
      _syncAvailableCategories();
      if (state.hasQuery && !state.isLoading && state.results.isEmpty) {
        search(state.query);
      }
    }

    ref.listen(channelListProvider.select((s) => s.groups), (_, _) {
      onCatalogUpdated();
    });
    ref.listen(vodProvider.select((s) => s.movieCategories), (_, _) {
      onCatalogUpdated();
    });
    ref.listen(vodProvider.select((s) => s.seriesCategories), (_, _) {
      onCatalogUpdated();
    });

    final initialCategories = _buildAvailableCategories();
    return SearchState(availableCategories: initialCategories);
  }

  /// Loads recent search history from database.
  Future<void> _loadHistory() async {
    try {
      final history =
          await ref.read(searchHistoryRepositoryProvider).getRecentSearches();
      if (!ref.mounted) return;
      state = state.copyWith(recentSearches: history);
    } catch (e) {
      debugPrint('SearchNotifier._loadHistory: $e');
    }
  }

  List<String> _buildAvailableCategories() {
    final channelGroups =
        ref
            .read(channelListProvider)
            .groups
            .where((group) => group.isNotEmpty)
            .toList();
    final vodState = ref.read(vodProvider);
    final vodCategories =
        [
          ...vodState.movieCategories,
          ...vodState.seriesCategories,
        ].where((category) => category.isNotEmpty).toList();
    return ref
        .read(searchRepositoryProvider)
        .buildSearchCategories(vodCategories, channelGroups);
  }

  void _syncAvailableCategories() {
    try {
      state = state.copyWith(availableCategories: _buildAvailableCategories());
    } catch (e) {
      debugPrint('SearchNotifier._syncAvailableCategories: $e');
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
    final epgEntries = ref.read(epgProvider).entries;
    final channels = ref.read(channelListProvider).channels;
    final vodItems = ref.read(filteredVodProvider);

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

      if (!ref.mounted || generation != _searchGeneration) return;

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
        unawaited(
          _saveToHistory(
            query,
            results.totalCount,
            thumbnailUrl: thumbnailUrl,
            resultType: resultType,
          ),
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
      if (!ref.mounted) return;
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
      if (!ref.mounted) return;
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
