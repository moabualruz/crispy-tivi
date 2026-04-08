part of 'memory_backend.dart';

/// VOD items and VOD favorites methods
/// for [MemoryBackend].
mixin _MemoryVodMixin on _MemoryStorage {
  // ── VOD Items ───────────────────────────────────

  List<Map<String, dynamic>> _filteredVodItems(
    List<String> sourceIds, {
    String? itemType,
    String? category,
    String? query,
  }) {
    final normalizedType = itemType?.trim().toLowerCase();
    final normalizedCategory = category?.trim();
    final normalizedQuery = query?.trim().toLowerCase();
    final sourceIdSet = sourceIds.toSet();

    return vodItems.values
        .where((item) {
          final sourceId = item['source_id'] as String?;
          if (sourceIdSet.isNotEmpty && !sourceIdSet.contains(sourceId)) {
            return false;
          }

          final type = (item['type'] as String? ?? '').trim().toLowerCase();
          if (normalizedType != null &&
              normalizedType.isNotEmpty &&
              type != normalizedType) {
            return false;
          }

          final itemCategory = (item['category'] as String?)?.trim();
          if (normalizedCategory != null && normalizedCategory.isNotEmpty) {
            if (normalizedCategory == 'Uncategorized') {
              if (itemCategory != null && itemCategory.isNotEmpty) {
                return false;
              }
            } else if (itemCategory != normalizedCategory) {
              return false;
            }
          }

          if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
            final haystacks = [
              item['name'],
              item['description'],
              item['category'],
              item['director'],
            ];
            final cast = item['cast'];
            final matchesText = haystacks.any(
              (value) =>
                  value is String &&
                  value.toLowerCase().contains(normalizedQuery),
            );
            final matchesCast =
                cast is List &&
                cast.any(
                  (value) =>
                      value is String &&
                      value.toLowerCase().contains(normalizedQuery),
                );
            if (!matchesText && !matchesCast) {
              return false;
            }
          }

          return true;
        })
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  void _sortVodMaps(List<Map<String, dynamic>> items, String sort) {
    switch (sort) {
      case 'name_asc':
        items.sort(
          (a, b) => (a['name'] as String? ?? '').toLowerCase().compareTo(
            (b['name'] as String? ?? '').toLowerCase(),
          ),
        );
        return;
      case 'name_desc':
        items.sort(
          (a, b) => (b['name'] as String? ?? '').toLowerCase().compareTo(
            (a['name'] as String? ?? '').toLowerCase(),
          ),
        );
        return;
      case 'year_desc':
        items.sort((a, b) {
          final ay = a['year'] as int?;
          final by = b['year'] as int?;
          if (ay == null && by == null) return 0;
          if (ay == null) return 1;
          if (by == null) return -1;
          return by.compareTo(ay);
        });
        return;
      case 'rating_desc':
        items.sort((a, b) {
          final ra = parseRatingForSort(a['rating'] as String?);
          final rb = parseRatingForSort(b['rating'] as String?);
          if (ra.isNaN && rb.isNaN) return 0;
          if (ra.isNaN) return 1;
          if (rb.isNaN) return -1;
          return rb.compareTo(ra);
        });
        return;
      case 'added_desc':
      default:
        items.sort((a, b) {
          final at = a['added_at'] as String?;
          final bt = b['added_at'] as String?;
          if (bt == null && at == null) return 0;
          if (bt == null) return -1;
          if (at == null) return 1;
          return bt.compareTo(at);
        });
    }
  }

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

  Future<String> getVodPage(
    String sourceIdsJson, {
    String? itemType,
    String? category,
    String? query,
    required String sort,
    required int offset,
    required int limit,
  }) async {
    final sourceIds = (jsonDecode(sourceIdsJson) as List).cast<String>();
    final filtered = _filteredVodItems(
      sourceIds,
      itemType: itemType,
      category: category,
      query: query,
    );
    _sortVodMaps(filtered, sort);

    if (offset >= filtered.length || limit <= 0) {
      return '[]';
    }

    final end = (offset + limit).clamp(0, filtered.length);
    return jsonEncode(filtered.sublist(offset, end));
  }

  Future<int> getVodCount(
    String sourceIdsJson, {
    String? itemType,
    String? category,
    String? query,
  }) async {
    final sourceIds = (jsonDecode(sourceIdsJson) as List).cast<String>();
    return _filteredVodItems(
      sourceIds,
      itemType: itemType,
      category: category,
      query: query,
    ).length;
  }

  Future<String> getVodCategories(
    String sourceIdsJson, {
    String? itemType,
  }) async {
    final sourceIds = (jsonDecode(sourceIdsJson) as List).cast<String>();
    final counts = <String, int>{};
    for (final item in _filteredVodItems(sourceIds, itemType: itemType)) {
      final category = (item['category'] as String?)?.trim();
      final key =
          (category == null || category.isEmpty) ? 'Uncategorized' : category;
      counts[key] = (counts[key] ?? 0) + 1;
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

  Future<String> searchVod(
    String query,
    String sourceIdsJson,
    int offset,
    int limit,
  ) => getVodPage(
    sourceIdsJson,
    query: query,
    sort: 'name_asc',
    offset: offset,
    limit: limit,
  );

  // ── VOD Favorites ──────────────────────────────

  Future<String> getFilteredVod(
    String sourceIdsJson, {
    String? itemType,
    String? category,
    String? query,
    required String sortBy,
  }) async {
    // simplified for memory backend
    return '[]';
  }

  Future<String> filterAndSortVodItems(
    String itemsJson, {
    String? category,
    String? query,
    required String sortBy,
  }) async {
    // simplified for memory backend
    return itemsJson;
  }

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

  Future<List<Map<String, dynamic>>> findVodAlternatives(
    String name,
    int year,
    String excludeId,
    int limit,
  ) async {
    final lowerName = name.toLowerCase().trim();
    return vodItems.values
        .where((v) {
          if (v['id'] == excludeId) return false;
          final vName = (v['name'] as String?)?.toLowerCase().trim() ?? '';
          if (vName != lowerName) return false;
          if (year > 0 && v['year'] != year) return false;
          return true;
        })
        .take(limit)
        .toList();
  }
}
