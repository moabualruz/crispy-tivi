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
