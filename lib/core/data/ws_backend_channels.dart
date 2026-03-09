part of 'ws_backend.dart';

/// Channel-related WebSocket commands, plus M3U/Stalker/Xtream parsers.
mixin _WsChannelsMixin on _WsBackendBase {
  // ── Channels ─────────────────────────────────────

  Future<List<Map<String, dynamic>>> loadChannels() async {
    final data = await _send('loadChannels');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<int> saveChannels(List<Map<String, dynamic>> channels) async {
    final res = await _send('saveChannels', {'channels': channels});
    return _countFromResult(res);
  }

  Future<List<Map<String, dynamic>>> getChannelsByIds(List<String> ids) async {
    final data = await _send('getChannelsByIds', {'ids': ids});
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<int> deleteRemovedChannels(
    String sourceId,
    List<String> keepIds,
  ) async {
    final res = await _send('deleteRemovedChannels', {
      'sourceId': sourceId,
      'keepIds': keepIds,
    });
    return _countFromResult(res);
  }

  Future<List<Map<String, dynamic>>> getChannelsBySources(
    List<String> sourceIds,
  ) async {
    final data = await _send('getChannelsBySources', {'sourceIds': sourceIds});
    return (data as List).cast<Map<String, dynamic>>();
  }

  // ── Channel Favorites ────────────────────────────

  Future<List<String>> getFavorites(String profileId) async {
    final data = await _send('getFavorites', {'profileId': profileId});
    return (data as List).cast<String>();
  }

  Future<void> addFavorite(String profileId, String channelId) =>
      _send('addFavorite', {'profileId': profileId, 'channelId': channelId});

  Future<void> removeFavorite(String profileId, String channelId) =>
      _send('removeFavorite', {'profileId': profileId, 'channelId': channelId});

  // ── Categories ───────────────────────────────────

  Future<Map<String, List<String>>> loadCategories() async {
    final data = await _send('loadCategories');
    final raw = data as Map<String, dynamic>;
    return raw.map((k, v) => MapEntry(k, (v as List).cast<String>()));
  }

  Future<void> saveCategories(Map<String, List<String>> categories) =>
      _send('saveCategories', {'categories': categories});

  Future<Map<String, List<String>>> getCategoriesBySources(
    List<String> sourceIds,
  ) async {
    final data = await _send('getCategoriesBySources', {
      'sourceIds': sourceIds,
    });
    final raw = data as Map<String, dynamic>;
    return raw.map((k, v) => MapEntry(k, (v as List).cast<String>()));
  }

  // ── Category Favorites ───────────────────────────

  Future<List<String>> getFavoriteCategories(
    String profileId,
    String categoryType,
  ) async {
    final data = await _send('getFavoriteCategories', {
      'profileId': profileId,
      'categoryType': categoryType,
    });
    return (data as List).cast<String>();
  }

  Future<void> addFavoriteCategory(
    String profileId,
    String categoryType,
    String categoryName,
  ) => _send('addFavoriteCategory', {
    'profileId': profileId,
    'categoryType': categoryType,
    'categoryName': categoryName,
  });

  Future<void> removeFavoriteCategory(
    String profileId,
    String categoryType,
    String categoryName,
  ) => _send('removeFavoriteCategory', {
    'profileId': profileId,
    'categoryType': categoryType,
    'categoryName': categoryName,
  });

  // ── Channel Order ────────────────────────────────

  Future<void> saveChannelOrder(
    String profileId,
    String groupName,
    List<String> channelIds,
  ) => _send('saveChannelOrder', {
    'profileId': profileId,
    'groupName': groupName,
    'channelIds': channelIds,
  });

  Future<Map<String, int>?> loadChannelOrder(
    String profileId,
    String groupName,
  ) async {
    final data = await _send('loadChannelOrder', {
      'profileId': profileId,
      'groupName': groupName,
    });
    if (data == null) return null;
    final raw = data as Map<String, dynamic>;
    return raw.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  Future<void> resetChannelOrder(String profileId, String groupName) => _send(
    'resetChannelOrder',
    {'profileId': profileId, 'groupName': groupName},
  );

  // ── Channel Sorting ────────────────────────────

  Future<String> sortChannelsJson(String channelsJson) async {
    final data = await _send('sortChannels', {'json': channelsJson});
    return data as String;
  }

  // ── Channel Categories ─────────────────────────

  Future<String> resolveChannelCategories(
    String channelsJson,
    String catMapJson,
  ) async {
    final data = await _send('resolveChannelCategories', {
      'channelsJson': channelsJson,
      'catMapJson': catMapJson,
    });
    return data as String;
  }

  Future<List<String>> extractSortedGroups(String channelsJson) async {
    final data = await _send('extractSortedGroups', {
      'channelsJson': channelsJson,
    });
    return (data as List).cast<String>();
  }

  // ── Duplicate Detection ────────────────────────

  Future<String?> findGroupForChannel(
    String groupsJson,
    String channelId,
  ) async {
    final data = await _send('findGroupForChannel', {
      'groupsJson': groupsJson,
      'channelId': channelId,
    });
    return data as String?;
  }

  /// Sync — delegates to shared [dartIsDuplicate].
  bool isDuplicate(String groupsJson, String channelId) =>
      dartIsDuplicate(groupsJson, channelId);

  Future<List<String>> getAllDuplicateIds(String groupsJson) async {
    final data = await _send('getAllDuplicateIds', {'groupsJson': groupsJson});
    return (data as List).cast<String>();
  }

  // ── Channel Algorithms ─────────────────────────

  /// Sync — delegates to shared [dartNormalizeChannelName].
  String normalizeChannelName(String name) => dartNormalizeChannelName(name);

  /// Sync — delegates to shared [dartNormalizeStreamUrl].
  String normalizeStreamUrl(String url) => dartNormalizeStreamUrl(url);

  Future<List<Map<String, dynamic>>> detectDuplicateChannels(
    String channelsJson,
  ) async {
    final data = await _send('detectDuplicateChannels', {'json': channelsJson});
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> matchEpgToChannels({
    required String entriesJson,
    required String channelsJson,
    required String displayNamesJson,
  }) async {
    final data = await _send('matchEpgToChannels', {
      'entriesJson': entriesJson,
      'channelsJson': channelsJson,
      'displayNamesJson': displayNamesJson,
    });
    return data as Map<String, dynamic>;
  }

  Future<String> matchEpgWithConfidence({
    required String entriesJson,
    required String channelsJson,
    required String displayNamesJson,
  }) async {
    final data = await _send('matchEpgWithConfidence', {
      'entriesJson': entriesJson,
      'channelsJson': channelsJson,
      'displayNamesJson': displayNamesJson,
    });
    return data as String;
  }

  Future<String?> buildCatchupUrl({
    required String channelJson,
    required int startUtc,
    required int endUtc,
  }) async {
    final data = await _send('buildCatchupUrl', {
      'channelJson': channelJson,
      'startUtc': startUtc,
      'endUtc': endUtc,
    });
    return data as String?;
  }

  // ── M3U Parser ─────────────────────────────────

  Future<Map<String, dynamic>> parseM3u(String content) async {
    final data = await _send('parseM3u', {'content': content});
    return data as Map<String, dynamic>;
  }

  // ── Utility Algorithms ─────────────────────────

  String tryBase64Decode(String input) {
    try {
      final decoded = utf8.decode(base64.decode(input));
      // If it decodes to printable text, use it.
      if (decoded.codeUnits.every((c) => c >= 32 || c == 10 || c == 13)) {
        return decoded;
      }
    } catch (_) {
      // Base64 decode failed — input isn't base64.
    }
    return input;
  }

  // ── Stalker Parsers ────────────────────────────

  Future<String> parseStalkerVodItems(
    String json,
    String baseUrl, {
    String vodType = 'movie',
  }) async {
    final data = await _send('parseStalkerVodItems', {
      'json': json,
      'baseUrl': baseUrl,
      'vodType': vodType,
    });
    return data as String;
  }

  Future<String> parseStalkerChannels(String json) async {
    final data = await _send('parseStalkerChannels', {'json': json});
    return data as String;
  }

  Future<String> parseStalkerLiveStreams(
    String json,
    String sourceId,
    String baseUrl,
  ) async {
    final data = await _send('parseStalkerLiveStreams', {
      'json': json,
      'sourceId': sourceId,
      'baseUrl': baseUrl,
    });
    return data as String;
  }

  String buildStalkerStreamUrl(String cmd, String baseUrl) {
    // Sync — local fallback (same logic as Rust).
    final url = cmd.trim();
    final resolved =
        url.startsWith('ffrt ') || url.startsWith('ffmpeg ')
            ? url.substring(url.indexOf(' ') + 1).trim()
            : url;
    if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
      return resolved;
    }
    if (resolved.startsWith('/')) {
      return '$baseUrl$resolved';
    }
    return '$baseUrl/$resolved';
  }

  Future<String?> parseStalkerCreateLink(String json, String baseUrl) async {
    final data = await _send('parseStalkerCreateLink', {
      'json': json,
      'baseUrl': baseUrl,
    });
    return data as String?;
  }

  Future<String> parseStalkerCategories(String json) async {
    final data = await _send('parseStalkerCategories', {'json': json});
    return data as String;
  }

  Future<String> parseStalkerVodResult(String json) async {
    final data = await _send('parseStalkerVodResult', {'json': json});
    return data as String;
  }

  // ── Xtream Parsers ─────────────────────────────

  Future<String> buildCategoryMap(String categoriesJson) async {
    final data = await _send('buildCategoryMap', {
      'categoriesJson': categoriesJson,
    });
    return data as String;
  }

  Future<String> parseXtreamLiveStreams(
    String json, {
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final data = await _send('parseXtreamLiveStreams', {
      'json': json,
      'baseUrl': baseUrl,
      'username': username,
      'password': password,
    });
    return data as String;
  }

  Future<String> parseXtreamCategories(String json) async {
    final data = await _send('parseXtreamCategories', {'json': json});
    return data as String;
  }

  // ── Xtream URL Builders ────────────────────────

  /// Sync — delegates to shared [dartBuildXtreamActionUrl].
  String buildXtreamActionUrl({
    required String baseUrl,
    required String username,
    required String password,
    required String action,
    String? paramsJson,
  }) => dartBuildXtreamActionUrl(
    baseUrl: baseUrl,
    username: username,
    password: password,
    action: action,
    paramsJson: paramsJson,
  );

  /// Sync — delegates to shared [dartBuildXtreamStreamUrl].
  String buildXtreamStreamUrl({
    required String baseUrl,
    required String username,
    required String password,
    required int streamId,
    required String streamType,
    required String extension,
  }) => dartBuildXtreamStreamUrl(
    baseUrl: baseUrl,
    username: username,
    password: password,
    streamId: streamId,
    streamType: streamType,
    extension: extension,
  );

  /// Sync — delegates to shared [dartBuildXtreamCatchupUrl].
  String buildXtreamCatchupUrl({
    required String baseUrl,
    required String username,
    required String password,
    required int streamId,
    required int startUtc,
    required int durationMinutes,
  }) => dartBuildXtreamCatchupUrl(
    baseUrl: baseUrl,
    username: username,
    password: password,
    streamId: streamId,
    startUtc: startUtc,
    durationMinutes: durationMinutes,
  );

  // ── Source Filter ─────────────────────────────

  Future<String> filterChannelsBySource(
    String channelsJson,
    String accessibleSourceIdsJson,
    bool isAdmin,
  ) async {
    final data = await _send('filterChannelsBySource', {
      'channelsJson': channelsJson,
      'accessibleSourceIdsJson': accessibleSourceIdsJson,
      'isAdmin': isAdmin,
    });
    return data as String;
  }
}
