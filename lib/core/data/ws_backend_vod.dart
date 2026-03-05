part of 'ws_backend.dart';

/// VOD-related WebSocket commands, parsers, and sorting algorithms.
mixin _WsVodMixin on _WsBackendBase {
  // ── VOD Items ────────────────────────────────────

  Future<List<Map<String, dynamic>>> loadVodItems() async {
    final data = await _send('loadVodItems');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<int> saveVodItems(List<Map<String, dynamic>> items) async {
    final res = await _send('saveVodItems', {'items': items});
    return _countFromResult(res);
  }

  Future<int> deleteRemovedVodItems(
    String sourceId,
    List<String> keepIds,
  ) async {
    final res = await _send('deleteRemovedVodItems', {
      'sourceId': sourceId,
      'keepIds': keepIds,
    });
    return _countFromResult(res);
  }

  // ── VOD Favorites ────────────────────────────────

  Future<List<String>> getVodFavorites(String profileId) async {
    final data = await _send('getVodFavorites', {'profileId': profileId});
    return (data as List).cast<String>();
  }

  Future<void> addVodFavorite(String profileId, String vodItemId) =>
      _send('addVodFavorite', {'profileId': profileId, 'vodItemId': vodItemId});

  Future<void> removeVodFavorite(String profileId, String vodItemId) => _send(
    'removeVodFavorite',
    {'profileId': profileId, 'vodItemId': vodItemId},
  );

  // ── Watchlist ────────────────────────────────

  Future<List<Map<String, dynamic>>> getWatchlistItems(String profileId) async {
    final data = await _send('getWatchlistItems', {'profileId': profileId});
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> addWatchlistItem(String profileId, String vodItemId) => _send(
    'addWatchlistItem',
    {'profileId': profileId, 'vodItemId': vodItemId},
  );

  Future<void> removeWatchlistItem(String profileId, String vodItemId) => _send(
    'removeWatchlistItem',
    {'profileId': profileId, 'vodItemId': vodItemId},
  );

  // ── Phase 8: VOD Service ─────────────────────────

  Future<void> updateVodFavorite(String itemId, bool isFavorite) =>
      _send('updateVodFavorite', {'itemId': itemId, 'isFavorite': isFavorite});

  // ── VOD Categories ─────────────────────────────

  Future<String> resolveVodCategories(
    String itemsJson,
    String catMapJson,
  ) async {
    final data = await _send('resolveVodCategories', {
      'itemsJson': itemsJson,
      'catMapJson': catMapJson,
    });
    return data as String;
  }

  Future<List<String>> extractSortedVodCategories(String itemsJson) async {
    final data = await _send('extractSortedVodCategories', {
      'itemsJson': itemsJson,
    });
    return (data as List).cast<String>();
  }

  // ── VOD Parsers ────────────────────────────────

  Future<List<Map<String, dynamic>>> parseVodStreams(
    String json, {
    required String baseUrl,
    required String username,
    required String password,
    String? sourceId,
  }) async {
    debugPrint(
      'WsBackend _send: parseVodStreams sending \${json.length} characters to Rust',
    );
    final data = await _send('parseVodStreams', {
      'json': json,
      'baseUrl': baseUrl,
      'username': username,
      'password': password,
      if (sourceId != null) 'sourceId': sourceId,
    });
    final resultList = (data as List).cast<Map<String, dynamic>>();
    debugPrint(
      'WsBackend parseVodStreams received \${resultList.length} items from Rust',
    );
    return resultList;
  }

  Future<List<Map<String, dynamic>>> parseSeries(
    String json, {
    String? sourceId,
  }) async {
    debugPrint(
      'WsBackend _send: parseSeries sending \${json.length} characters to Rust',
    );
    final data = await _send('parseSeries', {
      'json': json,
      if (sourceId != null) 'sourceId': sourceId,
    });
    final resultList = (data as List).cast<Map<String, dynamic>>();
    debugPrint(
      'WsBackend parseSeries received \${resultList.length} items from Rust',
    );
    return resultList;
  }

  Future<List<Map<String, dynamic>>> parseEpisodes(
    String json, {
    required String baseUrl,
    required String username,
    required String password,
    required String seriesId,
  }) async {
    final data = await _send('parseEpisodes', {
      'json': json,
      'baseUrl': baseUrl,
      'username': username,
      'password': password,
      'seriesId': seriesId,
    });
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> parseM3uVod(
    String json, {
    String? sourceId,
  }) async {
    final data = await _send('parseM3uVod', {
      'json': json,
      if (sourceId != null) 'sourceId': sourceId,
    });
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> parseVttThumbnails(
    String content,
    String baseUrl,
  ) async {
    final data = await _send('parseVttThumbnails', {
      'content': content,
      'baseUrl': baseUrl,
    });
    if (data == null) return null;
    return data as Map<String, dynamic>;
  }

  // ── VOD Sorting & Categorization ──────────────

  Future<String> sortVodItems(String itemsJson, String sortBy) async {
    final data = await _send('sortVodItems', {
      'itemsJson': itemsJson,
      'sortBy': sortBy,
    });
    return data as String;
  }

  Future<String> buildVodCategoryMap(String itemsJson) async {
    final data = await _send('buildVodCategoryMap', {'itemsJson': itemsJson});
    return data as String;
  }

  Future<String> filterTopVod(String itemsJson, int limit) async {
    final data = await _send('filterTopVod', {
      'itemsJson': itemsJson,
      'limit': limit,
    });
    return data as String;
  }

  Future<String> computeEpisodeProgress(
    String historyJson,
    String seriesId,
  ) async {
    final data = await _send('computeEpisodeProgress', {
      'historyJson': historyJson,
      'seriesId': seriesId,
    });
    return data as String;
  }

  Future<String> computeEpisodeProgressFromDb(String seriesId) async {
    final data = await _send('computeEpisodeProgressFromDb', {
      'seriesId': seriesId,
    });
    return data as String;
  }

  Future<String> filterVodByContentRating(
    String itemsJson,
    int maxRatingValue,
  ) async {
    final data = await _send('filterVodByContentRating', {
      'itemsJson': itemsJson,
      'maxRatingValue': maxRatingValue,
    });
    return data as String;
  }
}
