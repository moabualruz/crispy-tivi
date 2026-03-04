import '../entities/search_history_entry.dart';

/// Contract for search history persistence.
abstract class SearchHistoryRepository {
  /// Gets recent search entries, ordered by most recent first.
  Future<List<SearchHistoryEntry>> getRecentSearches({int limit = 10});

  /// Saves a search entry (upserts by query text).
  Future<void> saveSearch(SearchHistoryEntry entry);

  /// Removes a single search entry by ID.
  Future<void> removeSearch(String id);

  /// Clears all search history.
  Future<void> clearAll();
}
