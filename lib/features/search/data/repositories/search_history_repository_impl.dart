import '../../../../core/data/cache_service.dart';
import '../../domain/entities/'
    'search_history_entry.dart';
import '../../domain/repositories/'
    'search_history_repository.dart';

/// CrispyBackend-backed implementation of
/// [SearchHistoryRepository].
class SearchHistoryRepositoryImpl implements SearchHistoryRepository {
  SearchHistoryRepositoryImpl(this._cache);

  final CacheService _cache;

  @override
  Future<List<SearchHistoryEntry>> getRecentSearches({int limit = 10}) async {
    final all = await _cache.loadSearchHistory();
    // Sort by searchedAt descending.
    all.sort((a, b) => b.searchedAt.compareTo(a.searchedAt));
    return all.take(limit).toList();
  }

  @override
  Future<void> saveSearch(SearchHistoryEntry entry) async {
    // Delete existing entries with same query
    // to avoid duplicates.
    await _cache.deleteSearchEntriesByQuery(entry.query);
    await _cache.saveSearchEntry(entry);
  }

  @override
  Future<void> removeSearch(String id) async {
    await _cache.deleteSearchEntry(id);
  }

  @override
  Future<void> clearAll() async {
    await _cache.clearSearchHistory();
  }
}
