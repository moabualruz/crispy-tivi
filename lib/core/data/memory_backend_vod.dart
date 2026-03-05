part of 'memory_backend.dart';

/// VOD items and VOD favorites methods
/// for [MemoryBackend].
mixin _MemoryVodMixin on _MemoryStorage {
  // ── VOD Items ───────────────────────────────────

  Future<List<Map<String, dynamic>>> loadVodItems() async =>
      vodItems.values.toList();

  Future<int> saveVodItems(List<Map<String, dynamic>> items) async {
    for (final v in items) {
      vodItems[v['id'] as String] = v;
    }
    return items.length;
  }

  Future<int> deleteRemovedVodItems(
    String sourceId,
    List<String> keepIds,
  ) async {
    final keep = keepIds.toSet();
    final toRemove =
        vodItems.keys.where((id) {
          final v = vodItems[id]!;
          return v['source_id'] == sourceId && !keep.contains(id);
        }).toList();
    for (final id in toRemove) {
      vodItems.remove(id);
    }
    return toRemove.length;
  }

  Future<List<Map<String, dynamic>>> getVodBySources(
    List<String> sourceIds,
  ) async {
    if (sourceIds.isEmpty) return vodItems.values.toList();
    final idSet = sourceIds.toSet();
    return vodItems.values
        .where((v) => idSet.contains(v['source_id']))
        .toList();
  }

  // ── VOD Favorites ──────────────────────────────

  Future<List<String>> getVodFavorites(String profileId) async =>
      (vodFavorites[profileId] ?? {}).toList();

  Future<void> addVodFavorite(String profileId, String vodItemId) async {
    (vodFavorites[profileId] ??= {}).add(vodItemId);
  }

  Future<void> removeVodFavorite(String profileId, String vodItemId) async {
    vodFavorites[profileId]?.remove(vodItemId);
  }

  // ── Watchlist ──────────────────────────────

  Future<List<Map<String, dynamic>>> getWatchlistItems(String profileId) async {
    final ids = (vodFavorites[profileId] ?? {}).toList();
    return ids
        .map((id) => vodItems[id])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<void> addWatchlistItem(String profileId, String vodItemId) async {
    (vodFavorites[profileId] ??= {}).add(vodItemId);
  }

  Future<void> removeWatchlistItem(String profileId, String vodItemId) async {
    vodFavorites[profileId]?.remove(vodItemId);
  }

  // ── Phase 8: VOD Service ───────────────────────

  Future<void> updateVodFavorite(String itemId, bool isFavorite) async {
    final item = vodItems[itemId];
    if (item != null) {
      item['is_favorite'] = isFavorite;
    }
  }
}
