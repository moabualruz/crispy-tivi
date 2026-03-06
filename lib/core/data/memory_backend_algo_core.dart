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

  // ── Channel Sorting ────────────────────────────

  Future<String> filterAndSortChannels(
    String channelsJson,
    String paramsJson,
  ) async {
    final channels =
        (jsonDecode(channelsJson) as List).cast<Map<String, dynamic>>();
    final params = jsonDecode(paramsJson) as Map<String, dynamic>;

    final hiddenGroups =
        ((params['hidden_groups'] as List?) ?? []).cast<String>().toSet();
    final hiddenIds =
        ((params['hidden_ids'] as List?) ?? []).cast<String>().toSet();
    final selectedGroup = params['selected_group'] as String?;
    final searchQuery = (params['search_query'] as String? ?? '').toLowerCase();
    final sortMode = params['sort_mode'] as String? ?? 'defaultOrder';
    final duplicatePolicy = params['duplicate_policy'] as String? ?? 'show';
    final duplicatesJson = params['duplicates_json'] as String? ?? '[]';
    final favoritesGroup =
        params['favorites_group'] as String? ?? '\u2B50 Favorites';
    final favoriteIds =
        ((params['favorite_ids'] as List?) ?? []).cast<String>().toSet();
    final lastWatchedRaw =
        (params['last_watched_map'] as Map<String, dynamic>?) ?? {};

    // Parse duplicate IDs.
    final duplicateIds = <String>{};
    if (duplicatePolicy == 'hide') {
      try {
        final groups =
            (jsonDecode(duplicatesJson) as List).cast<Map<String, dynamic>>();
        for (final g in groups) {
          final ids = (g['channel_ids'] as List?)?.cast<String>() ?? [];
          if (ids.isNotEmpty) {
            // Keep first, hide the rest.
            for (var i = 1; i < ids.length; i++) {
              duplicateIds.add(ids[i]);
            }
          }
        }
      } catch (_) {}
    }

    var result = channels.toList();

    // 1. Exclude hidden groups.
    if (hiddenGroups.isNotEmpty) {
      result =
          result
              .where((c) => !hiddenGroups.contains(c['channel_group']))
              .toList();
    }

    // 2. Exclude individually hidden channels.
    if (hiddenIds.isNotEmpty) {
      result =
          result.where((c) => !hiddenIds.contains(c['id'] as String?)).toList();
    }

    // 3. Exclude duplicates.
    if (duplicateIds.isNotEmpty) {
      result =
          result
              .where((c) => !duplicateIds.contains(c['id'] as String?))
              .toList();
    }

    // 4. Group filter.
    if (selectedGroup == favoritesGroup) {
      result =
          result
              .where((c) => favoriteIds.contains(c['id'] as String?))
              .toList();
    } else if (selectedGroup != null) {
      result =
          result.where((c) => c['channel_group'] == selectedGroup).toList();
    }

    // 5. Search.
    if (searchQuery.isNotEmpty) {
      result =
          result.where((c) {
            final name = (c['name'] as String? ?? '').toLowerCase();
            final group = (c['channel_group'] as String? ?? '').toLowerCase();
            return name.contains(searchQuery) || group.contains(searchQuery);
          }).toList();
    }

    // Sort.
    int defaultSort(Map<String, dynamic> a, Map<String, dynamic> b) {
      final na = a['channel_number'] as int?;
      final nb = b['channel_number'] as int?;
      if (na != null && nb != null) return na.compareTo(nb);
      if (na != null) return -1;
      if (nb != null) return 1;
      return (a['name'] as String? ?? '').toLowerCase().compareTo(
        (b['name'] as String? ?? '').toLowerCase(),
      );
    }

    switch (sortMode) {
      case 'byName':
        result.sort(
          (a, b) => (a['name'] as String? ?? '').toLowerCase().compareTo(
            (b['name'] as String? ?? '').toLowerCase(),
          ),
        );
      case 'byDateAdded':
        result.sort((a, b) {
          final at = a['added_at'] as String?;
          final bt = b['added_at'] as String?;
          if (at != null && bt != null) return bt.compareTo(at);
          if (at != null) return -1;
          if (bt != null) return 1;
          return defaultSort(a, b);
        });
      case 'byWatchTime':
        result.sort((a, b) {
          final aid = a['id'] as String? ?? '';
          final bid = b['id'] as String? ?? '';
          final at = lastWatchedRaw[aid];
          final bt = lastWatchedRaw[bid];
          if (at != null && bt != null) {
            return (bt as String).compareTo(at as String);
          }
          if (at != null) return -1;
          if (bt != null) return 1;
          return defaultSort(a, b);
        });
      default:
        result.sort(defaultSort);
    }

    return jsonEncode(result);
  }

  /// Delegates to shared [dartSortFavorites].
  String sortFavorites(String channelsJson, String sortMode) =>
      dartSortFavorites(channelsJson, sortMode);

  // ── Category Sorting ────────────────────────────

  /// Delegates to shared [dartSortCategoriesWithFavorites].
  String sortCategoriesWithFavorites(
    String categoriesJson,
    String favoritesJson,
  ) => dartSortCategoriesWithFavorites(categoriesJson, favoritesJson);

  // ── Watch History ───────────────────────────────

  /// Delegates to shared [dartComputeWatchStreak].
  int computeWatchStreak(String timestampsJson, int nowMs) =>
      dartComputeWatchStreak(timestampsJson, nowMs);

  Future<String> computeProfileStats(String historyJson, int nowMs) async {
    List<Map<String, dynamic>> entries;
    try {
      entries = (jsonDecode(historyJson) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      entries = [];
    }
    if (entries.isEmpty) {
      return jsonEncode({
        'total_hours_watched': 0.0,
        'top_genres': <String>[],
        'top_channels': <String>[],
        'watch_streak_days': 0,
      });
    }

    // Total watch time.
    final totalMs = entries.fold<int>(
      0,
      (sum, e) => sum + ((e['position_ms'] as num?)?.toInt() ?? 0),
    );
    final totalHours = totalMs / 3600000.0;

    // Top channels — by frequency.
    final channelCounts = <String, int>{};
    for (final e in entries) {
      final sid = e['series_id'] as String?;
      final name = e['name'] as String? ?? '';
      final key = sid != null ? name.split(' - ').first : name;
      channelCounts[key] = (channelCounts[key] ?? 0) + 1;
    }
    final topChannels =
        (channelCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(3)
            .map((e) => e.key)
            .toList();

    // Top genres — from mediaType.
    final genreCounts = <String, int>{};
    for (final e in entries) {
      final mediaType = e['media_type'] as String? ?? '';
      final genre = _mediaTypeToGenreLabel(mediaType);
      genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
    }
    final topGenres =
        (genreCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(3)
            .map((e) => e.key)
            .toList();

    // Watch streak.
    final timestamps =
        entries
            .map((e) {
              final lw = e['last_watched'];
              if (lw is int) return lw;
              if (lw is String) {
                return DateTime.tryParse(lw)?.millisecondsSinceEpoch;
              }
              return null;
            })
            .whereType<int>()
            .toList();
    final tsJson = jsonEncode(timestamps);
    final streak = dartComputeWatchStreak(tsJson, nowMs);

    return jsonEncode({
      'total_hours_watched': totalHours,
      'top_genres': topGenres,
      'top_channels': topChannels,
      'watch_streak_days': streak,
    });
  }

  static String _mediaTypeToGenreLabel(String mediaType) {
    switch (mediaType) {
      case 'movie':
        return 'Movies';
      case 'episode':
        return 'Series';
      case 'channel':
        return 'Live TV';
      default:
        return 'Other';
    }
  }

  Future<String> mergeDedupSortHistory(String aJson, String bJson) async {
    List<Map<String, dynamic>> a;
    List<Map<String, dynamic>> b;
    try {
      a = (jsonDecode(aJson) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      a = [];
    }
    try {
      b = (jsonDecode(bJson) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      b = [];
    }
    final combined = [...a, ...b];
    final seen = <String>{};
    final deduped =
        combined.where((e) => seen.add(e['id'] as String? ?? '')).toList();
    deduped.sort((x, y) {
      final xLw = x['last_watched'] as String? ?? '';
      final yLw = y['last_watched'] as String? ?? '';
      return yLw.compareTo(xLw);
    });
    return jsonEncode(deduped);
  }

  Future<String> filterByCwStatus(String historyJson, String filter) async {
    List<Map<String, dynamic>> entries;
    try {
      entries = (jsonDecode(historyJson) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return '[]';
    }
    return jsonEncode(dartFilterByCwStatus(entries, filter));
  }

  Future<String> seriesIdsWithNewEpisodes(
    String seriesJson,
    int days,
    int nowMs,
  ) async {
    List<Map<String, dynamic>> series;
    try {
      series = (jsonDecode(seriesJson) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return '[]';
    }
    final cutoffMs = nowMs - Duration(days: days).inMilliseconds;
    final ids =
        series
            .where((s) {
              final updatedAt = s['updated_at'];
              if (updatedAt == null) return false;
              int? ms;
              if (updatedAt is int) {
                ms = updatedAt;
              } else if (updatedAt is String) {
                ms = DateTime.tryParse(updatedAt)?.millisecondsSinceEpoch;
              }
              return ms != null && ms > cutoffMs;
            })
            .map((s) => s['id'] as String? ?? '')
            .where((id) => id.isNotEmpty)
            .toList();
    return jsonEncode(ids);
  }

  /// Delegates to shared [dartCountInProgressEpisodes].
  int countInProgressEpisodes(String historyJson, String seriesId) =>
      dartCountInProgressEpisodes(historyJson, seriesId);

  // ── EPG: Upcoming Programs ──────────────────────

  Future<String> filterUpcomingPrograms(
    String epgMapJson,
    String favoritesJson,
    int nowMs,
    int windowMinutes,
    int limit,
  ) async => '[]';

  // ── Search (Advanced) ───────────────────────────

  Future<String> searchChannelsByLiveProgram(
    String epgMapJson,
    String query,
    int nowMs,
  ) async => '[]';

  Future<String> mergeEpgMatchedChannels(
    String baseJson,
    String allChannelsJson,
    String matchedIdsJson,
    String epgOverridesJson,
  ) async => baseJson;

  /// Delegates to shared [dartBuildSearchCategories].
  String buildSearchCategories(
    String vodCategoriesJson,
    String channelGroupsJson,
  ) => dartBuildSearchCategories(vodCategoriesJson, channelGroupsJson);

  // ── DVR (Advanced) ──────────────────────────────

  Future<String> computeStorageBreakdown(
    String recordingsJson,
    int nowMs,
  ) async => '{"total_bytes":0,"by_status":{}}';

  Future<String> filterDvrRecordings(
    String recordingsJson,
    String query,
  ) async {
    if (query.isEmpty) return recordingsJson;
    List<dynamic> items;
    try {
      items = jsonDecode(recordingsJson) as List;
    } catch (_) {
      return '[]';
    }
    final q = query.toLowerCase();
    final filtered =
        items.whereType<Map<String, dynamic>>().where((r) {
          final name = (r['program_name'] as String? ?? '').toLowerCase();
          final channel = (r['channel_name'] as String? ?? '').toLowerCase();
          return name.contains(q) || channel.contains(q);
        }).toList();
    return jsonEncode(filtered);
  }

  /// Delegates to shared [dartClassifyFileType].
  String classifyFileType(String filename) => dartClassifyFileType(filename);

  Future<String> sortRemoteFiles(String filesJson, String order) async =>
      filesJson;

  // ── Watch History (Advanced) ────────────────────

  Future<String> resolveNextEpisodes(
    String entriesJson,
    String vodItemsJson,
    double threshold,
  ) async => '[]';

  /// Delegates to shared [dartEpisodeCountBySeason].
  String episodeCountBySeason(String episodesJson) =>
      dartEpisodeCountBySeason(episodesJson);

  /// Delegates to shared [dartVodBadgeKind].
  String vodBadgeKind(int? year, int? addedAtMs, int nowMs) =>
      dartVodBadgeKind(year, addedAtMs, nowMs);

  Future<String> similarVodItems(
    String itemsJson,
    String itemId,
    int limit,
  ) async => '[]';

  // ── PIN Lockout ─────────────────────────────────

  /// Delegates to shared [dartIsLockActive].
  bool isLockActive(int lockedUntilMs, int nowMs) =>
      dartIsLockActive(lockedUntilMs, nowMs);

  /// Delegates to shared [dartLockRemainingMs].
  int lockRemainingMs(int lockedUntilMs, int nowMs) =>
      dartLockRemainingMs(lockedUntilMs, nowMs);

  // ── Watch History ID ─────────────────────────────

  /// Delegates to shared [dartDeriveWatchHistoryId].
  String deriveWatchHistoryId(String url) => dartDeriveWatchHistoryId(url);
}
