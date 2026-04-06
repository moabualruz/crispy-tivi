part of 'cache_service.dart';

/// Channel instance methods for [CacheService].
mixin _CacheChannelsMixin on _CacheServiceBase {
  // ── Channels ──────────────────────────────────────

  /// Save channels to backend (batch upsert).
  Future<void> saveChannels(List<Channel> channels) async {
    final sw = Stopwatch()..start();
    await _backend.saveChannels(channels.map(channelToMap).toList());
    debugPrint(
      'CacheService: saved ${channels.length} '
      'channels in ${sw.elapsedMilliseconds}ms',
    );
  }

  /// Load all channels.
  Future<List<Channel>> loadChannels() async {
    final sw = Stopwatch()..start();
    final maps = await _backend.loadChannels();
    final result = maps.map(mapToChannel).toList();
    debugPrint(
      'CacheService: loaded ${result.length} '
      'channels in ${sw.elapsedMilliseconds}ms',
    );
    return result;
  }

  /// Load specific channels by ID.
  Future<List<Channel>> getChannelsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final maps = await _backend.getChannelsByIds(ids);
    return maps.map(mapToChannel).toList();
  }

  /// Returns sorted, deduplicated group names from [channels].
  ///
  /// Delegates to the Rust backend, which applies Arabic-first
  /// then Latin alphabetical ordering.
  Future<List<String>> extractSortedGroups(List<Channel> channels) async {
    if (channels.isEmpty) return [];
    final json = jsonEncode(channels.map(channelToMap).toList());
    return _backend.extractSortedGroups(json);
  }

  /// Load channels filtered by source IDs.
  /// Empty [sourceIds] returns all channels.
  Future<List<Channel>> getChannelsBySources(List<String> sourceIds) async {
    final maps = await _backend.getChannelsBySources(sourceIds);
    return maps.map(mapToChannel).toList();
  }

  /// Load channel groups with item counts filtered by source IDs.
  Future<List<({String name, int count})>> getChannelGroups(
    List<String> sourceIds,
  ) async {
    final resultJson = await _backend.getChannelGroups(jsonEncode(sourceIds));
    return _decodeNameCountList(resultJson);
  }

  /// Load a page of channels filtered by source IDs and group.
  Future<List<Channel>> getChannelsPage({
    required List<String> sourceIds,
    String? group,
    required String sort,
    required int offset,
    required int limit,
  }) async {
    final resultJson = await _backend.getChannelsPage(
      jsonEncode(sourceIds),
      group: group,
      sort: sort,
      offset: offset,
      limit: limit,
    );
    return (jsonDecode(resultJson) as List)
        .cast<Map<String, dynamic>>()
        .map(mapToChannel)
        .toList();
  }

  /// Count channels filtered by source IDs and group.
  Future<int> getChannelCount({
    required List<String> sourceIds,
    String? group,
  }) => _backend.getChannelCount(jsonEncode(sourceIds), group: group);

  /// Load ordered channel IDs for a group filtered by source IDs.
  Future<List<String>> getChannelIdsForGroup({
    required List<String> sourceIds,
    String? group,
    required String sort,
  }) => _backend.getChannelIdsForGroup(
    jsonEncode(sourceIds),
    group: group,
    sort: sort,
  );

  /// Load a single channel by ID.
  Future<Channel?> getChannelById(String id) async {
    final map = await _backend.getChannelById(id);
    if (map == null) return null;
    return mapToChannel(map);
  }

  /// Load favourite channels for a profile filtered by source IDs.
  Future<List<Channel>> getFavoriteChannels({
    required List<String> sourceIds,
    required String profileId,
  }) async {
    final resultJson = await _backend.getFavoriteChannels(
      jsonEncode(sourceIds),
      profileId,
    );
    return (jsonDecode(resultJson) as List)
        .cast<Map<String, dynamic>>()
        .map(mapToChannel)
        .toList();
  }

  /// Search channels by query with pagination.
  Future<List<Channel>> searchChannels({
    required String query,
    required List<String> sourceIds,
    required int offset,
    required int limit,
  }) async {
    final resultJson = await _backend.searchChannels(
      query,
      jsonEncode(sourceIds),
      offset,
      limit,
    );
    return (jsonDecode(resultJson) as List)
        .cast<Map<String, dynamic>>()
        .map(mapToChannel)
        .toList();
  }

  /// Load categories filtered by source IDs.
  /// Empty [sourceIds] returns all categories.
  Future<Map<String, List<String>>> getCategoriesBySources(
    List<String> sourceIds,
  ) => _backend.getCategoriesBySources(sourceIds);

  /// Load EPG entries filtered by source IDs.
  /// Empty [sourceIds] returns all EPG entries.
  Future<Map<String, List<EpgEntry>>> getEpgBySources(
    List<String> sourceIds,
  ) async {
    final raw = await _backend.getEpgBySources(sourceIds);
    final result = <String, List<EpgEntry>>{};
    for (final entry in raw.entries) {
      result[entry.key] = entry.value.map(mapToEpgEntry).toList();
    }
    return result;
  }

  // ── Algorithm Wrappers ───────────────────────────

  /// Searches channel IDs whose live EPG program matches [query].
  Future<List<String>> searchChannelsByLiveProgram(
    Map<String, List<EpgEntry>> epgEntries,
    String query,
    int nowMs,
  ) async {
    final epgMapJson = jsonEncode(
      epgEntries.map((k, v) => MapEntry(k, v.map(epgEntryToMap).toList())),
    );
    final resultJson = await _backend.searchChannelsByLiveProgram(
      epgMapJson,
      query,
      nowMs,
    );
    return (jsonDecode(resultJson) as List).cast<String>();
  }

  /// Merges EPG-matched channel IDs into a base filtered list.
  Future<List<Channel>> mergeEpgMatchedChannels({
    required List<Channel> baseChannels,
    required List<Channel> allChannels,
    required List<String> matchedIds,
    required Map<String, String> epgOverrides,
  }) async {
    final baseJson = jsonEncode(baseChannels.map(channelToMap).toList());
    final allJson = jsonEncode(allChannels.map(channelToMap).toList());
    final matchedIdsJson = jsonEncode(matchedIds);
    final overridesJson = jsonEncode(epgOverrides);
    final resultJson = await _backend.mergeEpgMatchedChannels(
      baseJson,
      allJson,
      matchedIdsJson,
      overridesJson,
    );
    return (jsonDecode(resultJson) as List)
        .cast<Map<String, dynamic>>()
        .map(mapToChannel)
        .toList();
  }

  /// Builds deduplicated search categories from VOD and channel data.
  List<String> buildSearchCategories(
    List<String> vodCategories,
    List<String> channelGroups,
  ) {
    final vodJson = jsonEncode(vodCategories);
    final groupsJson = jsonEncode(channelGroups);
    final resultJson = _backend.buildSearchCategories(vodJson, groupsJson);
    return (jsonDecode(resultJson) as List).cast<String>();
  }

  // ── Typed JSON Helpers ─────────────────────────────

  /// Filters channels by source access for the current profile
  /// via the Rust backend.
  ///
  /// Returns all channels if [isAdmin] is true (accessibleSources
  /// is null). Otherwise returns only channels from [sourceIds].
  Future<List<Channel>> filterChannelsBySourceTyped(
    List<Channel> channels,
    List<String>? sourceIds,
    bool isAdmin,
  ) async {
    final channelsJson = encodeChannelsJson(channels);
    final sourceIdsJson = jsonEncode(sourceIds ?? <String>[]);
    final resultJson = await _backend.filterChannelsBySource(
      channelsJson,
      sourceIdsJson,
      isAdmin,
    );
    final list = jsonDecode(resultJson) as List<dynamic>;
    return list.map((m) => mapToChannel(m as Map<String, dynamic>)).toList();
  }

  // ── Sync Cleanup ──────────────────────────────────

  /// Deletes channels for [sourceId] not in
  /// [keepIds].
  Future<int> deleteRemovedChannels(
    String sourceId,
    Set<String> keepIds,
  ) async {
    final sw = Stopwatch()..start();
    final deleted = await _backend.deleteRemovedChannels(
      sourceId,
      keepIds.toList(),
    );
    debugPrint(
      'CacheService: deleted $deleted stale '
      'channels for source $sourceId '
      'in ${sw.elapsedMilliseconds}ms',
    );
    return deleted;
  }

  /// Deletes VOD items for [sourceId] not in
  /// [keepIds].
  Future<int> deleteRemovedVodItems(
    String sourceId,
    Set<String> keepIds,
  ) async {
    final sw = Stopwatch()..start();
    final deleted = await _backend.deleteRemovedVodItems(
      sourceId,
      keepIds.toList(),
    );
    debugPrint(
      'CacheService: deleted $deleted stale VOD '
      'items for source $sourceId '
      'in ${sw.elapsedMilliseconds}ms',
    );
    return deleted;
  }
}

// ── Channel JSON helpers (top-level) ──────────────

/// Encodes a list of [Channel]s to the JSON string expected by
/// Rust backend methods.
///
/// Application-layer code should call this instead of importing
/// `dart:convert` directly.
String encodeChannelsJson(List<Channel> channels) {
  return jsonEncode(channels.map(channelToMap).toList());
}

List<({String name, int count})> _decodeNameCountList(String json) {
  try {
    final raw = jsonDecode(json) as List<dynamic>;
    return raw.map((entry) {
      if (entry is List && entry.length >= 2) {
        return (
          name: entry[0] as String? ?? '',
          count: (entry[1] as num?)?.toInt() ?? 0,
        );
      }
      final map = entry as Map<String, dynamic>;
      return (
        name:
            (map['name'] ?? map['group'] ?? map['category'] ?? '') as String,
        count: (map['count'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  } catch (e) {
    debugPrint('CacheService JSON decode error in _decodeNameCountList: $e');
    return [];
  }
}

// ── Channel converters (top-level) ────────────────

/// Heuristic fallback to detect sports channels from their group name.
bool _guessIsSport(String? group) {
  if (group == null) return false;
  final lower = group.toLowerCase();
  return lower.contains('sport') ||
      lower.contains('football') ||
      lower.contains('soccer') ||
      lower.contains('nba') ||
      lower.contains('nfl') ||
      lower.contains('nhl') ||
      lower.contains('cricket') ||
      lower.contains('tennis') ||
      lower.contains('f1') ||
      lower.contains('racing');
}

/// Converts a backend map to a [Channel] entity.
Channel mapToChannel(Map<String, dynamic> m) {
  return Channel(
    id: m['id'] as String,
    nativeId: m['native_id'] as String?,
    name: m['name'] as String,
    streamUrl: m['stream_url'] as String,
    number: m['number'] as int?,
    group: m['channel_group'] as String?,
    logoUrl: m['logo_url'] as String?,
    tvgId: m['tvg_id'] as String?,
    tvgName: m['tvg_name'] as String?,
    isFavorite: m['is_favorite'] as bool? ?? false,
    userAgent: m['user_agent'] as String?,
    hasCatchup: m['has_catchup'] as bool? ?? false,
    catchupDays: m['catchup_days'] as int? ?? 0,
    catchupType: m['catchup_type'] as String?,
    catchupSource: m['catchup_source'] as String?,
    sourceId: m['source_id'] as String?,
    resolution: m['resolution'] as String?,
    addedAt: parseMapDateTime(m['added_at']),
    updatedAt: parseMapDateTime(m['updated_at']),
    is247: m['is_247'] as bool? ?? false,
    isSport:
        m['is_sport'] as bool? ?? _guessIsSport(m['channel_group'] as String?),
    tvgUrl: m['tvg_url'] as String?,
    streamPropertiesJson: m['stream_properties_json'] as String?,
    vlcOptionsJson: m['vlc_options_json'] as String?,
    timeshift: m['timeshift'] as String?,
    streamType: m['stream_type'] as String?,
    thumbnailUrl: m['thumbnail_url'] as String?,
  );
}

/// Converts a [Channel] entity to a backend map.
Map<String, dynamic> channelToMap(Channel c) {
  return {
    'id': c.id,
    'native_id': c.nativeId,
    'name': c.name,
    'stream_url': c.streamUrl,
    'number': c.number,
    'channel_group': c.group,
    'logo_url': c.logoUrl,
    'tvg_id': c.tvgId,
    'tvg_name': c.tvgName,
    'is_favorite': c.isFavorite,
    'user_agent': c.userAgent,
    'has_catchup': c.hasCatchup,
    'catchup_days': c.catchupDays,
    'catchup_type': c.catchupType,
    'catchup_source': c.catchupSource,
    'source_id': c.sourceId,
    'resolution': c.resolution,
    'added_at': c.addedAt != null ? _toNaiveDateTime(c.addedAt!) : null,
    'updated_at': c.updatedAt != null ? _toNaiveDateTime(c.updatedAt!) : null,
    'is_247': c.is247,
    'is_sport': c.isSport,
    'tvg_url': c.tvgUrl,
    'stream_properties_json': c.streamPropertiesJson,
    'vlc_options_json': c.vlcOptionsJson,
    'timeshift': c.timeshift,
    'stream_type': c.streamType,
    'thumbnail_url': c.thumbnailUrl,
  };
}
