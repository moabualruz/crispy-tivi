part of 'ffi_backend.dart';

/// EPG-related FFI calls.
mixin _FfiEpgMixin on _FfiBackendBase {
  // ── EPG Parsers ────────────────────────────────

  Future<List<Map<String, dynamic>>> parseEpg(String content) async {
    final json = await rust_api.parseEpg(content: content);
    return _decodeJsonList(json);
  }

  Future<Map<String, String>> extractEpgChannelNames(String content) async {
    final json = await rust_api.extractEpgChannelNames(content: content);
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as String));
  }

  Future<String> parseXtreamShortEpg(String listingsJson, String channelId) =>
      rust_api.parseXtreamShortEpg(
        listingsJson: listingsJson,
        channelId: channelId,
      );

  Future<String> parseStalkerEpg(String json, String channelId) =>
      rust_api.parseStalkerEpg(json: json, channelId: channelId);

  // ── EPG Data ───────────────────────────────────

  Future<Map<String, List<Map<String, dynamic>>>> getEpgsForChannels(
    List<String> channelIds,
    DateTime start,
    DateTime end,
  ) async {
    final json = await rust_api.getEpgsForChannels(
      channelIds: channelIds,
      startTime: PlatformInt64Util.from(start.millisecondsSinceEpoch ~/ 1000),
      endTime: PlatformInt64Util.from(end.millisecondsSinceEpoch ~/ 1000),
    );
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map(
      (key, value) =>
          MapEntry(key, (value as List).cast<Map<String, dynamic>>()),
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>> getEpgBySources(
    List<String> sourceIds,
  ) async {
    final json = await rust_api.getEpgBySources(
      sourceIdsJson: jsonEncode(sourceIds),
    );
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map(
      (key, value) =>
          MapEntry(key, (value as List).cast<Map<String, dynamic>>()),
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>> loadEpgEntries() async {
    final json = await rust_api.loadEpgEntries();
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map(
      (key, value) =>
          MapEntry(key, (value as List).cast<Map<String, dynamic>>()),
    );
  }

  Future<int> saveEpgEntries(
    Map<String, List<Map<String, dynamic>>> entries,
  ) async {
    final result = await rust_api.saveEpgEntries(json: jsonEncode(entries));
    return result.toInt();
  }

  Future<int> evictStaleEpg(int days) async {
    final result = await rust_api.evictStaleEpg(
      days: PlatformInt64Util.from(days),
    );
    return result.toInt();
  }

  Future<int> syncXmltvEpg({required String url}) async {
    final count = await rust_api.syncXmltvEpg(url: url);
    return count.toInt();
  }

  Future<int> syncXtreamEpg({
    required String baseUrl,
    required String username,
    required String password,
    required String channelsJson,
  }) async {
    final count = await rust_api.syncXtreamEpg(
      baseUrl: baseUrl,
      username: username,
      password: password,
      channelsJson: channelsJson,
    );
    return count.toInt();
  }

  Future<int> syncStalkerEpg({
    required String baseUrl,
    required String channelsJson,
  }) async {
    final count = await rust_api.syncStalkerEpg(
      baseUrl: baseUrl,
      channelsJson: channelsJson,
    );
    return count.toInt();
  }

  Future<void> clearEpgEntries() => rust_api.clearEpgEntries();

  // ── EPG Facade (L1 hot cache → L2 SQLite → L3 API) ──

  /// Fetch EPG for a single channel via the 3-layer facade.
  Future<Map<String, List<Map<String, dynamic>>>> getChannelEpg(
    String channelId,
    int count,
  ) async {
    final json = await rust_api.getChannelEpg(
      channelId: channelId,
      count: BigInt.from(count),
    );
    final list = jsonDecode(json) as List;
    return {channelId: list.cast<Map<String, dynamic>>()};
  }

  /// Fetch EPG for multiple channels via the 3-layer facade.
  Future<Map<String, List<Map<String, dynamic>>>> getChannelsEpg(
    List<String> channelIds,
    DateTime start,
    DateTime end,
  ) async {
    final json = await rust_api.getChannelsEpg(
      channelIdsJson: jsonEncode(channelIds),
      startTime: PlatformInt64Util.from(start.millisecondsSinceEpoch ~/ 1000),
      endTime: PlatformInt64Util.from(end.millisecondsSinceEpoch ~/ 1000),
    );
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map(
      (key, value) =>
          MapEntry(key, (value as List).cast<Map<String, dynamic>>()),
    );
  }

  Future<void> invalidateEpgCache(String channelId) =>
      rust_api.invalidateEpgCache(channelId: channelId);

  Future<void> clearEpgCaches() => rust_api.clearEpgCaches();

  // ── EPG Mappings ─────────────────────────────────

  Future<void> saveEpgMapping(Map<String, dynamic> mapping) =>
      rust_api.saveEpgMapping(json: jsonEncode(mapping));

  Future<List<Map<String, dynamic>>> getEpgMappings() async {
    final json = await rust_api.getEpgMappings();
    return _decodeJsonList(json);
  }

  Future<void> lockEpgMapping(String channelId) =>
      rust_api.lockEpgMapping(channelId: channelId);

  Future<void> deleteEpgMapping(String channelId) =>
      rust_api.deleteEpgMapping(channelId: channelId);

  Future<List<Map<String, dynamic>>> getPendingEpgSuggestions() async {
    final json = await rust_api.getPendingEpgSuggestions();
    return _decodeJsonList(json);
  }

  Future<void> setChannel247(String channelId, {required bool is247}) =>
      rust_api.setChannel247(channelId: channelId, is247: is247);

  // ── Watch History ────────────────────────────────

  Future<List<Map<String, dynamic>>> loadWatchHistory() async {
    final json = await rust_api.loadWatchHistory();
    return _decodeJsonList(json);
  }

  Future<void> saveWatchHistory(Map<String, dynamic> entry) =>
      rust_api.saveWatchHistory(json: jsonEncode(entry));

  Future<void> deleteWatchHistory(String id) =>
      rust_api.deleteWatchHistory(id: id);

  // ── Reminders ────────────────────────────────────

  Future<List<Map<String, dynamic>>> loadReminders() async {
    final json = await rust_api.loadReminders();
    return _decodeJsonList(json);
  }

  Future<void> saveReminder(Map<String, dynamic> reminder) =>
      rust_api.saveReminder(json: jsonEncode(reminder));

  Future<void> deleteReminder(String id) => rust_api.deleteReminder(id: id);

  Future<void> clearFiredReminders() => rust_api.clearFiredReminders();

  Future<void> markReminderFired(String id) =>
      rust_api.markReminderFired(id: id);

  // ── Bookmarks ────────────────────────────────────

  Future<List<Map<String, dynamic>>> loadBookmarks(String contentId) async {
    final json = await rust_api.loadBookmarks(contentId: contentId);
    return _decodeJsonList(json);
  }

  Future<void> saveBookmark(Map<String, dynamic> bookmark) =>
      rust_api.saveBookmark(json: jsonEncode(bookmark));

  Future<void> deleteBookmark(String id) => rust_api.deleteBookmark(id: id);

  Future<void> clearBookmarks(String contentId) =>
      rust_api.clearBookmarks(contentId: contentId);

  // ── Smart Groups ──────────────────────────────

  Future<String> createSmartGroup(String name) =>
      rust_api.createSmartGroup(name: name);

  Future<void> deleteSmartGroup(String groupId) =>
      rust_api.deleteSmartGroup(groupId: groupId);

  Future<void> renameSmartGroup(String groupId, String name) =>
      rust_api.renameSmartGroup(groupId: groupId, name: name);

  Future<void> addSmartGroupMember(
    String groupId,
    String channelId,
    String sourceId,
    int priority,
  ) => rust_api.addSmartGroupMember(
    groupId: groupId,
    channelId: channelId,
    sourceId: sourceId,
    priority: priority,
  );

  Future<void> removeSmartGroupMember(String groupId, String channelId) =>
      rust_api.removeSmartGroupMember(groupId: groupId, channelId: channelId);

  Future<void> reorderSmartGroupMembers(
    String groupId,
    String orderedChannelIdsJson,
  ) => rust_api.reorderSmartGroupMembers(
    groupId: groupId,
    orderedChannelIdsJson: orderedChannelIdsJson,
  );

  Future<String> getSmartGroupsJson() => rust_api.getSmartGroupsJson();

  Future<String?> getSmartGroupForChannel(String channelId) =>
      rust_api.getSmartGroupForChannel(channelId: channelId);

  Future<String> getSmartGroupAlternatives(String channelId) =>
      rust_api.getSmartGroupAlternatives(channelId: channelId);

  Future<String> detectSmartGroupCandidates() =>
      rust_api.detectSmartGroupCandidates();

  // ── Watch History Algorithms ───────────────────

  Future<String> filterContinueWatching(
    String historyJson, {
    String? mediaType,
    String? profileId,
  }) => rust_api.filterContinueWatching(
    historyJson: historyJson,
    mediaType: mediaType,
    profileId: profileId,
  );

  Future<String> filterCrossDevice(
    String historyJson,
    String currentDeviceId,
    int cutoffUtcMs,
  ) => rust_api.filterCrossDevice(
    historyJson: historyJson,
    currentDeviceId: currentDeviceId,
    cutoffUtcMs: PlatformInt64Util.from(cutoffUtcMs),
  );

  // ── EPG Timezone ───────────────────────────────

  String formatEpgTime(int timestampMs, double offsetHours) =>
      rust_api.formatEpgTime(
        timestampMs: PlatformInt64Util.from(timestampMs),
        offsetHours: offsetHours,
      );

  String formatEpgDatetime(int timestampMs, double offsetHours) =>
      rust_api.formatEpgDatetime(
        timestampMs: PlatformInt64Util.from(timestampMs),
        offsetHours: offsetHours,
      );

  String formatDurationMinutes(int minutes) =>
      rust_api.formatDurationMinutes(minutes: minutes);

  int durationBetweenMs(int startMs, int endMs) => rust_api.durationBetweenMs(
    startMs: PlatformInt64Util.from(startMs),
    endMs: PlatformInt64Util.from(endMs),
  );

  // ── DST-aware Timezone ─────────────────────────

  int getTimezoneOffsetMinutes(String tzName, int epochMs) =>
      rust_api.getTimezoneOffsetMinutes(
        tzName: tzName,
        epochMs: PlatformInt64Util.from(epochMs),
      );

  int applyTimezoneOffset(int epochMs, String tzName) =>
      rust_api
          .applyTimezoneOffset(
            epochMs: PlatformInt64Util.from(epochMs),
            tzName: tzName,
          )
          .toInt();

  String formatTimeWithSeconds(int epochMs, String tzName) =>
      rust_api.formatTimeWithSeconds(
        epochMs: PlatformInt64Util.from(epochMs),
        tzName: tzName,
      );
}
