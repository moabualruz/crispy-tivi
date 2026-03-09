part of 'cache_service.dart';

/// Watch history, search, multiview layout, and
/// reminder methods for [CacheService].
mixin _CacheMediaMixin on _CacheServiceBase {
  // ── Watch History ─────────────────────────────────

  /// Load all watch history entries.
  Future<List<WatchHistoryEntry>> loadWatchHistory() async {
    final maps = await _backend.loadWatchHistory();
    return maps.map(mapToWatchHistoryEntry).toList();
  }

  /// Save a watch history entry (upsert).
  Future<void> saveWatchHistory(WatchHistoryEntry entry) async {
    await _backend.saveWatchHistory(watchHistoryEntryToMap(entry));
  }

  /// Delete a watch history entry by ID.
  Future<void> deleteWatchHistory(String id) async {
    await _backend.deleteWatchHistory(id);
  }

  /// Clear all watch history.
  Future<void> clearAllWatchHistory() async {
    await _backend.clearAllWatchHistory();
  }

  // ── Saved Layouts ─────────────────────────────────

  /// Load all saved multi-view layouts.
  Future<List<SavedLayout>> loadSavedLayouts() async {
    final maps = await _backend.loadSavedLayouts();
    return maps.map(_mapToSavedLayout).toList();
  }

  /// Get a saved layout by ID.
  Future<SavedLayout?> getSavedLayoutById(String id) async {
    final map = await _backend.getSavedLayoutById(id);
    if (map == null) return null;
    return _mapToSavedLayout(map);
  }

  /// Save a multi-view layout.
  Future<void> saveSavedLayout(SavedLayout layout) async {
    await _backend.saveSavedLayout(_savedLayoutToMap(layout));
  }

  /// Delete a saved layout by ID.
  Future<void> deleteSavedLayout(String id) async {
    await _backend.deleteSavedLayout(id);
  }

  // ── Search History ────────────────────────────────

  /// Load all search history entries.
  Future<List<SearchHistoryEntry>> loadSearchHistory() async {
    final maps = await _backend.loadSearchHistory();
    return maps.map(_mapToSearchHistoryEntry).toList();
  }

  /// Save a search history entry.
  Future<void> saveSearchEntry(SearchHistoryEntry entry) async {
    await _backend.saveSearchEntry(_searchHistoryEntryToMap(entry));
  }

  /// Delete a search history entry by query text
  /// (dedup).
  Future<void> deleteSearchEntriesByQuery(String query) async {
    await _backend.deleteSearchByQuery(query);
  }

  /// Delete a search history entry by ID.
  Future<void> deleteSearchEntry(String id) async {
    await _backend.deleteSearchEntry(id);
  }

  /// Clear all search history.
  Future<void> clearSearchHistory() async {
    await _backend.clearSearchHistory();
  }

  // ── Reminders ─────────────────────────────────────

  /// Load all reminders as raw maps.
  Future<List<Map<String, dynamic>>> loadReminders() async {
    return _backend.loadReminders();
  }

  /// Save a reminder (raw map).
  Future<void> saveReminder(Map<String, dynamic> reminder) async {
    await _backend.saveReminder(reminder);
  }

  /// Delete a reminder by ID.
  Future<void> deleteReminder(String id) async {
    await _backend.deleteReminder(id);
  }

  /// Mark a reminder as fired.
  Future<void> markReminderFired(String id) async {
    await _backend.markReminderFired(id);
  }

  // ── Bookmarks ──────────────────────────────────────

  /// Load all bookmarks for a content item.
  Future<List<Map<String, dynamic>>> loadBookmarks(String contentId) async {
    return _backend.loadBookmarks(contentId);
  }

  /// Save a bookmark (raw map).
  Future<void> saveBookmark(Map<String, dynamic> bookmark) async {
    await _backend.saveBookmark(bookmark);
  }

  /// Delete a bookmark by ID.
  Future<void> deleteBookmark(String id) async {
    await _backend.deleteBookmark(id);
  }

  /// Clear all bookmarks for a content item.
  Future<void> clearBookmarks(String contentId) async {
    await _backend.clearBookmarks(contentId);
  }

  // ── Smart Groups ──────────────────────────────────────

  /// Create a smart channel group. Returns UUID.
  Future<String> createSmartGroup(String name) async {
    return _backend.createSmartGroup(name);
  }

  /// Delete a smart group and all its members.
  Future<void> deleteSmartGroup(String groupId) async {
    await _backend.deleteSmartGroup(groupId);
  }

  /// Rename a smart group.
  Future<void> renameSmartGroup(String groupId, String name) async {
    await _backend.renameSmartGroup(groupId, name);
  }

  /// Add a channel to a smart group.
  Future<void> addSmartGroupMember(
    String groupId,
    String channelId,
    String sourceId,
    int priority,
  ) async {
    await _backend.addSmartGroupMember(groupId, channelId, sourceId, priority);
  }

  /// Remove a channel from a smart group.
  Future<void> removeSmartGroupMember(String groupId, String channelId) async {
    await _backend.removeSmartGroupMember(groupId, channelId);
  }

  /// Reorder members of a smart group.
  Future<void> reorderSmartGroupMembers(
    String groupId,
    String orderedChannelIdsJson,
  ) async {
    await _backend.reorderSmartGroupMembers(groupId, orderedChannelIdsJson);
  }

  /// Load all smart groups with members as JSON.
  Future<String> getSmartGroupsJson() async {
    return _backend.getSmartGroupsJson();
  }

  /// Get the smart group a channel belongs to, if any.
  Future<String?> getSmartGroupForChannel(String channelId) async {
    return _backend.getSmartGroupForChannel(channelId);
  }

  /// Get smart group alternatives (excluding same source).
  Future<String> getSmartGroupAlternatives(String channelId) async {
    return _backend.getSmartGroupAlternatives(channelId);
  }

  /// Auto-detect potential smart group candidates.
  Future<String> detectSmartGroupCandidates() async {
    return _backend.detectSmartGroupCandidates();
  }
}

// ── Watch history converters (top-level) ──────────

/// Converts a backend map to a
/// [WatchHistoryEntry] entity.
WatchHistoryEntry mapToWatchHistoryEntry(Map<String, dynamic> m) {
  return WatchHistoryEntry(
    id: m['id'] as String,
    mediaType: m['media_type'] as String,
    name: m['name'] as String,
    streamUrl: m['stream_url'] as String,
    posterUrl: m['poster_url'] as String?,
    seriesPosterUrl: m['series_poster_url'] as String?,
    positionMs: m['position_ms'] as int? ?? 0,
    durationMs: m['duration_ms'] as int? ?? 0,
    lastWatched: _parseNaiveUtc(m['last_watched'] as String),
    seriesId: m['series_id'] as String?,
    seasonNumber: m['season_number'] as int?,
    episodeNumber: m['episode_number'] as int?,
    deviceId: m['device_id'] as String?,
    deviceName: m['device_name'] as String?,
    profileId: m['profile_id'] as String?,
    sourceId: m['source_id'] as String?,
  );
}

/// Converts a [WatchHistoryEntry] entity to a
/// backend map.
Map<String, dynamic> watchHistoryEntryToMap(WatchHistoryEntry e) {
  return {
    'id': e.id,
    'media_type': e.mediaType,
    'name': e.name,
    'stream_url': e.streamUrl,
    'poster_url': e.posterUrl,
    'series_poster_url': e.seriesPosterUrl,
    'position_ms': e.positionMs,
    'duration_ms': e.durationMs,
    'last_watched': _toNaiveDateTime(e.lastWatched),
    'series_id': e.seriesId,
    'season_number': e.seasonNumber,
    'episode_number': e.episodeNumber,
    'device_id': e.deviceId,
    'device_name': e.deviceName,
    'profile_id': e.profileId,
    'source_id': e.sourceId,
  };
}

// ── Saved layout converters (private) ─────────────

SavedLayout _mapToSavedLayout(Map<String, dynamic> m) {
  final layoutStr = m['layout'] as String;
  final layout = MultiViewLayout.values.firstWhere(
    (e) => e.name == layoutStr,
    orElse: () => MultiViewLayout.twoByTwo,
  );
  final streamsJson = m['streams'] as String? ?? '[]';
  final streamsList = jsonDecode(streamsJson) as List<dynamic>;
  final streams =
      streamsList.map((item) {
        if (item == null) return null;
        return SavedStream.fromJson(item as Map<String, dynamic>);
      }).toList();

  return SavedLayout(
    id: m['id'] as String,
    name: m['name'] as String,
    layout: layout,
    streams: streams,
    createdAt: parseMapDateTime(m['created_at']),
  );
}

Map<String, dynamic> _savedLayoutToMap(SavedLayout l) {
  return {
    'id': l.id,
    'name': l.name,
    'layout': l.layout.name,
    'streams': jsonEncode(l.streams.map((s) => s?.toJson()).toList()),
    'created_at': _toNaiveDateTime(l.createdAt ?? DateTime.now()),
  };
}

// ── Search history converters (private) ───────────

SearchHistoryEntry _mapToSearchHistoryEntry(Map<String, dynamic> m) {
  // FE-SR-07: deserialise optional thumbnail fields — null-safe for
  // existing persisted entries that pre-date this field.
  final resultTypeStr = m['result_type'] as String?;
  final resultType =
      resultTypeStr != null
          ? SearchHistoryResultType.values.firstWhere(
            (e) => e.name == resultTypeStr,
            orElse: () => SearchHistoryResultType.vod,
          )
          : null;

  return SearchHistoryEntry(
    id: m['id'] as String,
    query: m['query'] as String,
    searchedAt: _parseNaiveUtc(m['searched_at'] as String),
    resultCount: m['result_count'] as int? ?? 0,
    thumbnailUrl: m['thumbnail_url'] as String?,
    resultType: resultType,
  );
}

Map<String, dynamic> _searchHistoryEntryToMap(SearchHistoryEntry e) {
  return {
    'id': e.id,
    'query': e.query,
    'searched_at': _toNaiveDateTime(e.searchedAt),
    'result_count': e.resultCount,
    // FE-SR-07: persist thumbnail metadata (null fields omitted).
    if (e.thumbnailUrl != null) 'thumbnail_url': e.thumbnailUrl,
    if (e.resultType != null) 'result_type': e.resultType!.name,
  };
}
