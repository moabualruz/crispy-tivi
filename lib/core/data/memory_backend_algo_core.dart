part of 'memory_backend.dart';

/// Core algorithm implementations for [MemoryBackend]:
/// normalize, dedup, sorting, category resolution,
/// group icon, URL normalization, config merge,
/// permission, source filter, cloud sync, DVR
/// scheduling, and EPG window merge.
mixin _MemoryAlgoCoreMixin on _MemoryStorage {
  // ── Algorithms ─────────────────────────────────

  /// Delegates to shared [dartNormalizeChannelName].
  String normalizeChannelName(String name) => dartNormalizeChannelName(name);

  /// Delegates to shared [dartNormalizeStreamUrl].
  String normalizeStreamUrl(String url) => dartNormalizeStreamUrl(url);

  String tryBase64Decode(String input) => input;

  Future<List<Map<String, dynamic>>> detectDuplicateChannels(
    String channelsJson,
  ) async => [];

  Future<Map<String, dynamic>> matchEpgToChannels({
    required String entriesJson,
    required String channelsJson,
    required String displayNamesJson,
  }) async => {'matched': <String, dynamic>{}, 'stats': <String, dynamic>{}};

  Future<String?> buildCatchupUrl({
    required String channelJson,
    required int startUtc,
    required int endUtc,
  }) async => null;

  // ── DVR Algorithms ─────────────────────────────

  Future<String> expandRecurringRecordings(
    String recordingsJson,
    int nowUtcMs,
  ) async => '[]';

  Future<bool> detectRecordingConflict(
    String recordingsJson, {
    String? excludeId,
    required String channelName,
    required int startUtcMs,
    required int endUtcMs,
  }) async {
    final list = jsonDecode(recordingsJson) as List;
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      if (excludeId != null && m['id'] == excludeId) {
        continue;
      }
      final cn = m['channel_name'] as String? ?? '';
      if (cn != channelName) continue;
      final s = DateTime.parse('${m['start_time']}Z').millisecondsSinceEpoch;
      final e = DateTime.parse('${m['end_time']}Z').millisecondsSinceEpoch;
      if (s < endUtcMs && e > startUtcMs) {
        return true;
      }
    }
    return false;
  }

  /// Delegates to shared [dartSanitizeFilename].
  String sanitizeFilename(String name) => dartSanitizeFilename(name);

  // ── Group Icon ────────────────────────────────

  /// Delegates to shared [dartMatchGroupIcon].
  String matchGroupIcon(String groupName) => dartMatchGroupIcon(groupName);

  // ── Search Grouping ───────────────────────────

  Future<String> groupSearchResults(
    String resultsJson,
    String channelsJson,
    String vodJson,
    String epgJson,
  ) async => '{"channels":[],"movies":[],"series":[],"epg_programs":[]}';

  // ── Sorting ────────────────────────────────────

  Future<String> sortChannelsJson(String channelsJson) async {
    final list =
        (jsonDecode(channelsJson) as List).cast<Map<String, dynamic>>();
    list.sort((a, b) {
      final na = a['channel_number'] as int? ?? 0;
      final nb = b['channel_number'] as int? ?? 0;
      if (na != nb) return na.compareTo(nb);
      final sa = (a['name'] as String?)?.toLowerCase() ?? '';
      final sb = (b['name'] as String?)?.toLowerCase() ?? '';
      return sa.compareTo(sb);
    });
    return jsonEncode(list);
  }

  // ── Category Resolution ────────────────────────

  Future<String> resolveChannelCategories(
    String channelsJson,
    String catMapJson,
  ) async {
    final chs = (jsonDecode(channelsJson) as List).cast<Map<String, dynamic>>();
    final catMap =
        (jsonDecode(catMapJson) as Map<String, dynamic>).cast<String, String>();
    for (final c in chs) {
      final catId = c['category_id'] as String?;
      if (catId != null && catMap.containsKey(catId)) {
        c['channel_group'] = catMap[catId];
      }
    }
    return jsonEncode(chs);
  }

  Future<String> resolveVodCategories(
    String itemsJson,
    String catMapJson,
  ) async {
    final items = (jsonDecode(itemsJson) as List).cast<Map<String, dynamic>>();
    final catMap =
        (jsonDecode(catMapJson) as Map<String, dynamic>).cast<String, String>();
    for (final v in items) {
      final catId = v['category_id'] as String?;
      if (catId != null && catMap.containsKey(catId)) {
        v['category'] = catMap[catId];
      }
    }
    return jsonEncode(items);
  }

  Future<List<String>> extractSortedGroups(String channelsJson) async {
    final chs = (jsonDecode(channelsJson) as List).cast<Map<String, dynamic>>();
    final groups = <String>{};
    for (final c in chs) {
      final g = c['channel_group'] as String?;
      if (g != null && g.isNotEmpty) {
        groups.add(g);
      }
    }
    return groups.toList()..sort();
  }

  Future<List<String>> extractSortedVodCategories(String itemsJson) async {
    final items = (jsonDecode(itemsJson) as List).cast<Map<String, dynamic>>();
    final cats = <String>{};
    for (final v in items) {
      final c = v['category'] as String?;
      if (c != null && c.isNotEmpty) {
        cats.add(c);
      }
    }
    return cats.toList()..sort();
  }

  // ── Dedup ──────────────────────────────────────

  Future<String?> findGroupForChannel(
    String groupsJson,
    String channelId,
  ) async {
    final groups =
        (jsonDecode(groupsJson) as List).cast<Map<String, dynamic>>();
    for (final g in groups) {
      final ids = (g['channel_ids'] as List).cast<String>();
      if (ids.contains(channelId)) {
        return jsonEncode(g);
      }
    }
    return null;
  }

  /// Delegates to shared [dartIsDuplicate].
  bool isDuplicate(String groupsJson, String channelId) =>
      dartIsDuplicate(groupsJson, channelId);

  Future<List<String>> getAllDuplicateIds(String groupsJson) async {
    final groups =
        (jsonDecode(groupsJson) as List).cast<Map<String, dynamic>>();
    final ids = <String>{};
    for (final g in groups) {
      ids.addAll((g['channel_ids'] as List).cast<String>());
    }
    return ids.toList();
  }

  // ── Normalize ──────────────────────────────────

  bool validateMacAddress(String mac) {
    return RegExp(kMacAddressPattern).hasMatch(mac);
  }

  String macToDeviceId(String mac) => mac.replaceAll(':', '');

  /// Delegates to shared [dartGuessLogoDomains].
  List<String> guessLogoDomains(String name) => dartGuessLogoDomains(name);

  // ── URL Normalization ─────────────────────────

  /// Delegates to shared [dartNormalizeApiBaseUrl].
  String normalizeApiBaseUrl(String url) => dartNormalizeApiBaseUrl(url);

  // ── Config Merge ──────────────────────────────

  /// Delegates to shared [dartDeepMergeJson].
  String deepMergeJson(String baseJson, String overridesJson) =>
      dartDeepMergeJson(baseJson, overridesJson);

  /// Delegates to shared [dartSetNestedValue].
  String setNestedValue(String mapJson, String dotPath, String valueJson) =>
      dartSetNestedValue(mapJson, dotPath, valueJson);

  // ── Permission ────────────────────────────────

  /// Delegates to shared [dartCanViewRecording].
  bool canViewRecording(
    String role,
    String recordingOwnerId,
    String currentProfileId,
  ) => dartCanViewRecording(role, recordingOwnerId, currentProfileId);

  /// Delegates to shared [dartCanDeleteRecording].
  bool canDeleteRecording(
    String role,
    String recordingOwnerId,
    String currentProfileId,
  ) => dartCanDeleteRecording(role, recordingOwnerId, currentProfileId);

  // ── Source Filter ─────────────────────────────

  Future<String> filterChannelsBySource(
    String channelsJson,
    String accessibleSourceIdsJson,
    bool isAdmin,
  ) async {
    if (isAdmin) return channelsJson;
    List<String> accessible;
    try {
      accessible = (jsonDecode(accessibleSourceIdsJson) as List).cast<String>();
    } catch (_) {
      return '[]';
    }
    List<Map<String, dynamic>> channels;
    try {
      channels =
          (jsonDecode(channelsJson) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return '[]';
    }
    final ids = accessible.toSet();
    final filtered =
        channels.where((ch) => ids.contains(ch['source_id'])).toList();
    return jsonEncode(filtered);
  }

  // ── Cloud Sync Direction ───────────────────────

  String determineSyncDirection(
    int localMs,
    int cloudMs,
    int lastSyncMs,
    String localDevice,
    String cloudDevice,
  ) {
    if (cloudMs == 0) {
      if (localMs == 0) return 'no_change';
      return 'upload';
    }
    if (localMs == 0) return 'download';
    if ((localMs - cloudMs).abs() <= 5000) return 'no_change';
    if (cloudDevice.isNotEmpty &&
        cloudDevice != localDevice &&
        localMs > lastSyncMs) {
      return 'conflict';
    }
    return localMs > cloudMs ? 'upload' : 'download';
  }

  // ── DVR: Recordings to Start ──────────────────

  Future<String> getRecordingsToStart(String recordingsJson, int nowMs) async {
    List<dynamic> items;
    try {
      items = jsonDecode(recordingsJson) as List;
    } catch (_) {
      return '[]';
    }
    final ids =
        items
            .whereType<Map<String, dynamic>>()
            .where((r) {
              final status = r['status'] as String? ?? '';
              final start = r['startTime'] as int? ?? -1;
              final end = r['endTime'] as int? ?? 0;
              return status == 'scheduled' &&
                  start >= 0 &&
                  start <= nowMs &&
                  end > nowMs;
            })
            .map((r) => r['id'] as String)
            .toList();
    return jsonEncode(ids);
  }

  // ── EPG Window Merge ──────────────────────────

  /// Delegates to shared [dartMergeEpgWindow].
  Future<String> mergeEpgWindow(String existingJson, String newJson) =>
      dartMergeEpgWindow(existingJson, newJson);
}
