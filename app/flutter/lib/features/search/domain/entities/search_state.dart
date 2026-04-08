import 'package:meta/meta.dart';

import 'grouped_search_results.dart';
import 'search_filter.dart';
import 'search_history_entry.dart';

/// Complete state for the search feature.
///
/// Tracks the current query, filters, results, history,
/// and available filter options.
@immutable
class SearchState {
  const SearchState({
    this.query = '',
    this.filter = const SearchFilter(),
    this.results = const GroupedSearchResults(),
    this.recentSearches = const [],
    this.availableCategories = const [],
    this.isLoading = false,
    this.error,
  });

  /// Current search query text.
  final String query;

  /// Active search filters.
  final SearchFilter filter;

  /// Grouped search results.
  final GroupedSearchResults results;

  /// Recent search history entries.
  final List<SearchHistoryEntry> recentSearches;

  /// Available categories for filtering (from content).
  final List<String> availableCategories;

  /// Whether a search is in progress.
  final bool isLoading;

  /// Error message if search failed.
  final String? error;

  /// Whether there's an active search query.
  bool get hasQuery => query.trim().isNotEmpty;

  /// Whether the search has completed with no results.
  bool get hasNoResults => hasQuery && !isLoading && results.isEmpty;

  /// Whether there are results to display.
  bool get hasResults => results.isNotEmpty;

  /// Whether there's recent search history to show.
  bool get hasHistory => recentSearches.isNotEmpty;

  SearchState copyWith({
    String? query,
    SearchFilter? filter,
    GroupedSearchResults? results,
    List<SearchHistoryEntry>? recentSearches,
    List<String>? availableCategories,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      filter: filter ?? this.filter,
      results: results ?? this.results,
      recentSearches: recentSearches ?? this.recentSearches,
      availableCategories: availableCategories ?? this.availableCategories,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Creates an initial state with loaded history.
  factory SearchState.withHistory(List<SearchHistoryEntry> history) {
    return SearchState(recentSearches: history);
  }
}
