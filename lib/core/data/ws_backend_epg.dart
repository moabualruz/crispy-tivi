part of 'ws_backend.dart';

/// EPG-related WebSocket commands.
mixin _WsEpgMixin on _WsBackendBase {
  // ── EPG Parsers ────────────────────────────────

  Future<List<Map<String, dynamic>>> parseEpg(String content) async {
    final data = await _send('parseEpg', {'content': content});
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, String>> extractEpgChannelNames(String content) async {
    final data = await _send('extractEpgChannelNames', {'content': content});
    final raw = data as Map<String, dynamic>;
    return raw.map((k, v) => MapEntry(k, v as String));
  }

  Future<String> parseXtreamShortEpg(
    String listingsJson,
    String channelId,
  ) async {
    final data = await _send('parseXtreamShortEpg', {
      'listingsJson': listingsJson,
      'channelId': channelId,
    });
    return data as String;
  }

  Future<String> parseStalkerEpg(String json, String channelId) async {
    final data = await _send('parseStalkerEpg', {
      'json': json,
      'channelId': channelId,
    });
    return data as String;
  }

  // ── EPG Data ───────────────────────────────────

  Future<Map<String, List<Map<String, dynamic>>>> getEpgsForChannels(
    List<String> channelIds,
    DateTime start,
    DateTime end,
  ) async {
    final data = await _send('getEpgsForChannels', {
      'channelIds': channelIds,
      'startTimeMs': start.millisecondsSinceEpoch,
      'endTimeMs': end.millisecondsSinceEpoch,
    });
    final raw = data as Map<String, dynamic>;
    return raw.map(
      (k, v) => MapEntry(k, (v as List).cast<Map<String, dynamic>>()),
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>> loadEpgEntries() async {
    final data = await _send('loadEpgEntries');
    final raw = data as Map<String, dynamic>;
    return raw.map(
      (k, v) => MapEntry(k, (v as List).cast<Map<String, dynamic>>()),
    );
  }

  Future<int> saveEpgEntries(
    Map<String, List<Map<String, dynamic>>> entries,
  ) async {
    final res = await _send('saveEpgEntries', {'entries': entries});
    return _countFromResult(res);
  }

  Future<int> evictStaleEpg(int days) async {
    final res = await _send('evictStaleEpg', {'days': days});
    return _countFromResult(res);
  }

  Future<int> syncXmltvEpg({required String url}) async {
    final res = await _send('syncXmltvEpg', {'url': url});
    return _countFromResult(res);
  }

  Future<int> syncXtreamEpg({
    required String baseUrl,
    required String username,
    required String password,
    required String channelsJson,
  }) async {
    final res = await _send('syncXtreamEpg', {
      'baseUrl': baseUrl,
      'username': username,
      'password': password,
      'channelsJson': channelsJson,
    });
    return _countFromResult(res);
  }

  Future<int> syncStalkerEpg({
    required String baseUrl,
    required String channelsJson,
  }) async {
    final res = await _send('syncStalkerEpg', {
      'baseUrl': baseUrl,
      'channelsJson': channelsJson,
    });
    return _countFromResult(res);
  }

  Future<void> clearEpgEntries() => _send('clearEpgEntries');

  // ── Watch History ────────────────────────────────

  Future<List<Map<String, dynamic>>> loadWatchHistory() async {
    final data = await _send('loadWatchHistory');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> saveWatchHistory(Map<String, dynamic> entry) =>
      _send('saveWatchHistory', {'entry': entry});

  Future<void> deleteWatchHistory(String id) =>
      _send('deleteWatchHistory', {'id': id});

  // ── Reminders ────────────────────────────────────

  Future<List<Map<String, dynamic>>> loadReminders() async {
    final data = await _send('loadReminders');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> saveReminder(Map<String, dynamic> reminder) =>
      _send('saveReminder', {'reminder': reminder});

  Future<void> deleteReminder(String id) => _send('deleteReminder', {'id': id});

  Future<void> clearFiredReminders() => _send('clearFiredReminders');

  Future<void> markReminderFired(String id) =>
      _send('markReminderFired', {'id': id});

  // ── Watch History Algorithms ───────────────────

  Future<String> filterContinueWatching(
    String historyJson, {
    String? mediaType,
    String? profileId,
  }) async {
    final data = await _send('filterContinueWatching', {
      'historyJson': historyJson,
      if (mediaType != null) 'mediaType': mediaType,
      if (profileId != null) 'profileId': profileId,
    });
    return data as String;
  }

  Future<String> filterCrossDevice(
    String historyJson,
    String currentDeviceId,
    int cutoffUtcMs,
  ) async {
    final data = await _send('filterCrossDevice', {
      'historyJson': historyJson,
      'currentDeviceId': currentDeviceId,
      'cutoffUtcMs': cutoffUtcMs,
    });
    return data as String;
  }

  // ── EPG Timezone ───────────────────────────────

  /// Sync — delegates to shared [dartFormatEpgTime].
  String formatEpgTime(int timestampMs, double offsetHours) =>
      dartFormatEpgTime(timestampMs, offsetHours);

  /// Sync — delegates to shared [dartFormatEpgDatetime].
  String formatEpgDatetime(int timestampMs, double offsetHours) =>
      dartFormatEpgDatetime(timestampMs, offsetHours);

  /// Sync — delegates to shared [dartFormatDurationMinutes].
  String formatDurationMinutes(int minutes) =>
      dartFormatDurationMinutes(minutes);

  /// Sync — delegates to shared [dartDurationBetweenMs].
  int durationBetweenMs(int startMs, int endMs) =>
      dartDurationBetweenMs(startMs, endMs);

  // ── DST-aware Timezone ─────────────────────────

  /// Sync — delegates to shared [dartGetTimezoneOffsetMinutes].
  int getTimezoneOffsetMinutes(String tzName, int epochMs) =>
      dartGetTimezoneOffsetMinutes(tzName, epochMs);

  /// Sync — delegates to shared [dartApplyTimezoneOffset].
  int applyTimezoneOffset(int epochMs, String tzName) =>
      dartApplyTimezoneOffset(epochMs, tzName);

  /// Sync — delegates to shared [dartFormatTimeWithSeconds].
  String formatTimeWithSeconds(int epochMs, String tzName) =>
      dartFormatTimeWithSeconds(epochMs, tzName);

  // ── EPG Window Merge ──────────────────────────

  /// Delegates to shared [dartMergeEpgWindow].
  Future<String> mergeEpgWindow(String existingJson, String newJson) =>
      dartMergeEpgWindow(existingJson, newJson);
}
