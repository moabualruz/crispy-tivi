import '../../../core/data/cache_service.dart';
import '../domain/entities/saved_layout.dart';
import '../domain/repositories/layout_repository.dart';

/// CrispyBackend-based implementation of
/// [LayoutRepository].
class LayoutRepositoryImpl implements LayoutRepository {
  LayoutRepositoryImpl(this._cache);

  final CacheService _cache;

  @override
  Future<List<SavedLayout>> getAll() async {
    final layouts = await _cache.loadSavedLayouts();
    // Sort by createdAt descending.
    layouts.sort((a, b) {
      final aDate = a.createdAt ?? DateTime(2000);
      final bDate = b.createdAt ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });
    return layouts;
  }

  @override
  Future<SavedLayout?> getById(String id) async {
    return _cache.getSavedLayoutById(id);
  }

  @override
  Future<void> save(SavedLayout layout) async {
    await _cache.saveSavedLayout(layout);
  }

  @override
  Future<void> delete(String id) async {
    await _cache.deleteSavedLayout(id);
  }

  @override
  String generateId() => 'layout_${DateTime.now().millisecondsSinceEpoch}';
}
