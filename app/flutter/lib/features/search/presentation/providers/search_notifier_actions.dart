import '../../domain/entities/search_filter.dart';
import '../../domain/entities/search_history_entry.dart';
import '../../domain/entities/search_state.dart';
import 'search_providers.dart';

/// Filter action extensions for [SearchNotifier].
///
/// Split from [search_providers.dart] to keep each file under
/// the 300-line limit while preserving all public API.
extension SearchNotifierActions on SearchNotifier {
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
}
