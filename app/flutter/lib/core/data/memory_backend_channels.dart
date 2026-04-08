part of 'memory_backend.dart';

/// Channel CRUD, favorites, categories, and
/// channel order methods for [MemoryBackend].
mixin _MemoryChannelsMixin on _MemoryStorage {
  // ── Channels ────────────────────────────────────

  List<Map<String, dynamic>> _filteredChannels(
    List<String> sourceIds, {
    String? group,
    String? query,
  }) {
    final sourceIdSet = sourceIds.toSet();
    final normalizedGroup = group?.trim();
    final normalizedQuery = query?.trim().toLowerCase();

    return channels.values
        .where((channel) {
          final sourceId = channel['source_id'] as String?;
          if (sourceIdSet.isNotEmpty && !sourceIdSet.contains(sourceId)) {
            return false;
          }

          if (normalizedGroup != null &&
              normalizedGroup.isNotEmpty &&
              (channel['group_title'] as String? ??
                      channel['group'] as String?) !=
                  normalizedGroup) {
            return false;
          }

          if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
            final name = (channel['name'] as String? ?? '').toLowerCase();
            final tvgId = (channel['tvg_id'] as String? ?? '').toLowerCase();
            final groupTitle =
                (channel['group_title'] as String? ??
                        channel['group'] as String? ??
                        '')
                    .toLowerCase();
            if (!name.contains(normalizedQuery) &&
                !tvgId.contains(normalizedQuery) &&
                !groupTitle.contains(normalizedQuery)) {
              return false;
            }
          }

          return true;
        })
        .map((channel) => Map<String, dynamic>.from(channel))
        .toList();
  }

  void _sortChannels(List<Map<String, dynamic>> items, String sort) {
    switch (sort) {
      case 'name_desc':
        items.sort(
          (a, b) => (b['name'] as String? ?? '').toLowerCase().compareTo(
            (a['name'] as String? ?? '').toLowerCase(),
          ),
        );
        return;
      case 'number_asc':
        items.sort(
          (a, b) => ((a['number'] as num?)?.toInt() ?? 1 << 30).compareTo(
            (b['number'] as num?)?.toInt() ?? 1 << 30,
          ),
        );
        return;
      case 'number_desc':
        items.sort(
          (a, b) => ((b['number'] as num?)?.toInt() ?? -1).compareTo(
            (a['number'] as num?)?.toInt() ?? -1,
          ),
        );
        return;
      case 'name_asc':
      default:
        items.sort(
          (a, b) => (a['name'] as String? ?? '').toLowerCase().compareTo(
            (b['name'] as String? ?? '').toLowerCase(),
          ),
        );
    }
  }

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

  Future<String> getChannelGroups(String sourceIdsJson) async {
    final sourceIds = (jsonDecode(sourceIdsJson) as List).cast<String>();
    final counts = <String, int>{};
    for (final channel in _filteredChannels(sourceIds)) {
      final name =
          (channel['group_title'] as String? ??
                  channel['group'] as String? ??
                  '')
              .trim();
      if (name.isEmpty) continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final result =
        counts.entries
            .map((entry) => {'name': entry.key, 'count': entry.value})
            .toList()
          ..sort(
            (a, b) => categoryBucketCompare(
              a['name']! as String,
              b['name']! as String,
            ),
          );
    return jsonEncode(result);
  }

  Future<String> getChannelsPage(
    String sourceIdsJson, {
    String? group,
    required String sort,
    required int offset,
    required int limit,
  }) async {
    final sourceIds = (jsonDecode(sourceIdsJson) as List).cast<String>();
    final filtered = _filteredChannels(sourceIds, group: group);
    _sortChannels(filtered, sort);
    if (offset >= filtered.length || limit <= 0) {
      return '[]';
    }
    final end = (offset + limit).clamp(0, filtered.length);
    return jsonEncode(filtered.sublist(offset, end));
  }

  Future<int> getChannelCount(String sourceIdsJson, {String? group}) async {
    final sourceIds = (jsonDecode(sourceIdsJson) as List).cast<String>();
    return _filteredChannels(sourceIds, group: group).length;
  }

  Future<List<String>> getChannelIdsForGroup(
    String sourceIdsJson, {
    String? group,
    required String sort,
  }) async {
    final sourceIds = (jsonDecode(sourceIdsJson) as List).cast<String>();
    final filtered = _filteredChannels(sourceIds, group: group);
    _sortChannels(filtered, sort);
    return filtered.map((channel) => channel['id'] as String).toList();
  }

  Future<Map<String, dynamic>?> getChannelById(String id) async {
    final channel = channels[id];
    return channel == null ? null : Map<String, dynamic>.from(channel);
  }

  Future<String> getFavoriteChannels(
    String sourceIdsJson,
    String profileId,
  ) async {
    final sourceIds = (jsonDecode(sourceIdsJson) as List).cast<String>();
    final favoriteIds = favorites[profileId] ?? const <String>{};
    final filtered =
        _filteredChannels(
          sourceIds,
        ).where((channel) => favoriteIds.contains(channel['id'])).toList();
    return jsonEncode(filtered);
  }

  Future<String> searchChannels(
    String query,
    String sourceIdsJson,
    int offset,
    int limit,
  ) async {
    final sourceIds = (jsonDecode(sourceIdsJson) as List).cast<String>();
    final filtered = _filteredChannels(sourceIds, query: query);
    _sortChannels(filtered, 'name_asc');
    if (offset >= filtered.length || limit <= 0) {
      return '[]';
    }
    final end = (offset + limit).clamp(0, filtered.length);
    return jsonEncode(filtered.sublist(offset, end));
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
