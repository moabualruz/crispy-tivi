part of 'memory_backend.dart';

/// Channel CRUD, favorites, categories, and
/// channel order methods for [MemoryBackend].
mixin _MemoryChannelsMixin on _MemoryStorage {
  // ── Channels ────────────────────────────────────

  Future<List<Map<String, dynamic>>> loadChannels() async =>
      channels.values.toList();

  Future<int> saveChannels(List<Map<String, dynamic>> items) async {
    for (final c in items) {
      channels[c['id'] as String] = c;
    }
    return items.length;
  }

  Future<List<Map<String, dynamic>>> getChannelsByIds(List<String> ids) async {
    final idSet = ids.toSet();
    return channels.values.where((c) => idSet.contains(c['id'])).toList();
  }

  Future<int> deleteRemovedChannels(
    String sourceId,
    List<String> keepIds,
  ) async {
    final keep = keepIds.toSet();
    final toRemove =
        channels.keys.where((id) {
          final c = channels[id]!;
          return c['source_id'] == sourceId && !keep.contains(id);
        }).toList();
    for (final id in toRemove) {
      channels.remove(id);
    }
    return toRemove.length;
  }

  Future<List<Map<String, dynamic>>> getChannelsBySources(
    List<String> sourceIds,
  ) async {
    if (sourceIds.isEmpty) return channels.values.toList();
    final idSet = sourceIds.toSet();
    return channels.values
        .where((c) => idSet.contains(c['source_id']))
        .toList();
  }

  // ── Channel Favorites ───────────────────────────

  Future<List<String>> getFavorites(String profileId) async =>
      (favorites[profileId] ?? {}).toList();

  Future<void> addFavorite(String profileId, String channelId) async {
    (favorites[profileId] ??= {}).add(channelId);
  }

  Future<void> removeFavorite(String profileId, String channelId) async {
    favorites[profileId]?.remove(channelId);
  }

  // ── Categories ──────────────────────────────────

  Future<Map<String, List<String>>> loadCategories() async =>
      Map.from(categories);

  Future<void> saveCategories(
    String sourceId,
    Map<String, List<String>> cats,
  ) async {
    categories
      ..clear()
      ..addAll(cats);
  }

  Future<Map<String, List<String>>> getCategoriesBySources(
    List<String> sourceIds,
  ) async {
    if (sourceIds.isEmpty) return Map.from(categories);
    // MemoryBackend categories don't track source_id,
    // so return all when filtering is requested.
    return Map.from(categories);
  }

  // ── Category Favorites ──────────────────────────

  String _catKey(String pid, String type) => '$pid:$type';

  Future<List<String>> getFavoriteCategories(
    String profileId,
    String categoryType,
  ) async => (favCategories[_catKey(profileId, categoryType)] ?? {}).toList();

  Future<void> addFavoriteCategory(
    String profileId,
    String categoryType,
    String categoryName,
  ) async {
    (favCategories[_catKey(profileId, categoryType)] ??= {}).add(categoryName);
  }

  Future<void> removeFavoriteCategory(
    String profileId,
    String categoryType,
    String categoryName,
  ) async {
    favCategories[_catKey(profileId, categoryType)]?.remove(categoryName);
  }

  // ── Channel Order ───────────────────────────────

  String _orderKey(String pid, String grp) => '$pid:$grp';

  Future<void> saveChannelOrder(
    String profileId,
    String groupName,
    List<String> channelIds,
  ) async {
    channelOrders[_orderKey(profileId, groupName)] = channelIds;
  }

  Future<Map<String, int>?> loadChannelOrder(
    String profileId,
    String groupName,
  ) async {
    final ids = channelOrders[_orderKey(profileId, groupName)];
    if (ids == null) return null;
    return {for (var i = 0; i < ids.length; i++) ids[i]: i};
  }

  Future<void> resetChannelOrder(String profileId, String groupName) async {
    channelOrders.remove(_orderKey(profileId, groupName));
  }
}
