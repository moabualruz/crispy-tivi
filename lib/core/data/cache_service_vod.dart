part of 'cache_service.dart';

/// VOD instance methods for [CacheService].
mixin _CacheVodMixin on _CacheServiceBase {
  // ── VOD Items ─────────────────────────────────────

  /// Save VOD items with delta sync.
  Future<void> saveVodItems(List<VodItem> items) async {
    if (items.isEmpty) {
      debugPrint('CacheService: saveVodItems — 0 items, skip');
      return;
    }
    final sw = Stopwatch()..start();
    await _backend.saveVodItems(items.map(vodItemToMap).toList());
    debugPrint(
      'CacheService: saved ${items.length} VOD '
      'items in ${sw.elapsedMilliseconds}ms',
    );
  }

  /// Load all VOD items.
  Future<List<VodItem>> loadVodItems() async {
    final sw = Stopwatch()..start();
    final maps = await _backend.loadVodItems();
    final result = maps.map(mapToVodItem).toList();
    debugPrint(
      'CacheService: loaded ${result.length} VOD '
      'items in ${sw.elapsedMilliseconds}ms',
    );
    return result;
  }

  /// Update a single VOD item's favorite flag.
  Future<void> updateVodFavorite(String itemId, bool isFavorite) async {
    await _backend.updateVodFavorite(itemId, isFavorite);
  }
}

// ── VOD converters (top-level) ────────────────────

/// Converts a backend map to a [VodItem] entity.
VodItem mapToVodItem(Map<String, dynamic> m) {
  // cast is stored as a comma-separated string in the backend map.
  final castRaw = m['cast'] as String?;
  final cast =
      (castRaw != null && castRaw.isNotEmpty)
          ? castRaw.split(',').map((s) => s.trim()).toList()
          : null;

  return VodItem(
    id: m['id'] as String,
    name: m['name'] as String,
    streamUrl: m['stream_url'] as String,
    type: VodType.values.byName(m['type'] as String),
    posterUrl: m['poster_url'] as String?,
    backdropUrl: m['backdrop_url'] as String?,
    description: m['description'] as String?,
    rating: m['rating'] as String?,
    year: m['year'] as int?,
    duration: m['duration'] as int?,
    category: m['category'] as String?,
    cast: cast,
    director: m['director'] as String?,
    seriesId: m['series_id'] as String?,
    seasonCount: m['season_count'] as int?,
    seasonNumber: m['season_number'] as int?,
    episodeNumber: m['episode_number'] as int?,
    extension: m['ext'] as String?,
    isFavorite: m['is_favorite'] as bool? ?? false,
    addedAt: parseMapDateTime(m['added_at']),
    updatedAt: parseMapDateTime(m['updated_at']),
    sourceId: m['source_id'] as String?,
  );
}

/// Converts a [VodItem] entity to a backend map.
Map<String, dynamic> vodItemToMap(VodItem v) {
  return {
    'id': v.id,
    'name': v.name,
    'stream_url': v.streamUrl,
    'type': v.type.name,
    'poster_url': v.posterUrl,
    'backdrop_url': v.backdropUrl,
    'description': v.description,
    'rating': v.rating,
    'year': v.year,
    'duration': v.duration,
    'category': v.category,
    // cast is serialized as a comma-separated string.
    'cast': v.cast?.join(','),
    'director': v.director,
    'series_id': v.seriesId,
    'season_count': v.seasonCount,
    'season_number': v.seasonNumber,
    'episode_number': v.episodeNumber,
    'ext': v.extension,
    'is_favorite': v.isFavorite,
    'added_at': v.addedAt != null ? _toNaiveDateTime(v.addedAt!) : null,
    'updated_at': v.updatedAt != null ? _toNaiveDateTime(v.updatedAt!) : null,
    'source_id': v.sourceId,
  };
}
