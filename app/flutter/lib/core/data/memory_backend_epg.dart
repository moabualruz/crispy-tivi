part of 'memory_backend.dart';

/// EPG entries and watch history methods
/// for [MemoryBackend].
mixin _MemoryEpgMixin on _MemoryStorage {
  // ── EPG ────────────────────────────────────────

  Future<Map<String, List<Map<String, dynamic>>>> getEpgsForChannels(
    List<String> channelIds,
    DateTime start,
    DateTime end,
  ) async {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final id in channelIds) {
      if (epg.containsKey(id)) {
        result[id] =
            epg[id]!.where((e) {
              final eStart = DateTime.tryParse(
                e['start_time'] as String? ?? '',
              );
              final eEnd = DateTime.tryParse(e['end_time'] as String? ?? '');
              if (eStart == null || eEnd == null) return false;
              return eEnd.isAfter(start) && eStart.isBefore(end);
            }).toList();
      }
    }
    return result;
  }

  Future<Map<String, List<Map<String, dynamic>>>> getChannelsEpg(
    List<String> channelIds,
    DateTime start,
    DateTime end,
  ) => getEpgsForChannels(channelIds, start, end);

  Future<List<String>> getEpgCoverageChannelIds(
    List<String> channelIds,
    DateTime start,
    DateTime end,
  ) async {
    final result = <String>[];
    for (final id in channelIds) {
      final entries = epg[id];
      if (entries == null) continue;
      final hasCoverage = entries.any((e) {
        final eStart = DateTime.tryParse(e['start_time'] as String? ?? '');
        final eEnd = DateTime.tryParse(e['end_time'] as String? ?? '');
        if (eStart == null || eEnd == null) return false;
        return eEnd.isAfter(start) && eStart.isBefore(end);
      });
      if (hasCoverage) result.add(id);
    }
    return result;
  }

  Future<Map<String, List<Map<String, dynamic>>>> getEpgBySources(
    List<String> sourceIds,
  ) async {
    if (sourceIds.isEmpty) return Map.from(epg);
    final idSet = sourceIds.toSet();
    final result = <String, List<Map<String, dynamic>>>{};
    for (final entry in epg.entries) {
      final filtered =
          entry.value.where((e) => idSet.contains(e['source_id'])).toList();
      if (filtered.isNotEmpty) {
        result[entry.key] = filtered;
      }
    }
    return result;
  }

  Future<Map<String, List<Map<String, dynamic>>>> loadEpgEntries() async =>
      Map.from(epg);

  Future<int> saveEpgEntries(
    Map<String, List<Map<String, dynamic>>> entries,
  ) async {
    int count = 0;
    for (final e in entries.entries) {
      epg[e.key] = e.value;
      count += e.value.length;
    }
    return count;
  }

  Future<int> evictStaleEpg(int days) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    int removed = 0;
    for (final key in epg.keys.toList()) {
      epg[key]!.removeWhere((e) {
        final end = DateTime.tryParse(e['end_time'] as String? ?? '');
        if (end != null && end.isBefore(cutoff)) {
          removed++;
          return true;
        }
        return false;
      });
    }
    return removed;
  }

  Future<int> syncXmltvEpg({
    required String url,
    required String sourceId,
    bool force = false,
  }) async => 0;

  Future<int> syncXtreamEpg({
    required String baseUrl,
    required String username,
    required String password,
    required String sourceId,
    required String channelsJson,
    bool force = false,
  }) async => 0;

  Future<int> syncStalkerEpg({
    required String baseUrl,
    required String mac,
    required String sourceId,
    required String channelsJson,
    bool force = false,
  }) async => 0;

  Future<void> clearEpgEntries() async => epg.clear();

  // ── EPG Mappings ─────────────────────────────────

  Future<void> saveEpgMapping(Map<String, dynamic> mapping) async {
    epgMappings[mapping['channel_id'] as String] = mapping;
  }

  Future<List<Map<String, dynamic>>> getEpgMappings() async =>
      epgMappings.values.toList();

  Future<void> lockEpgMapping(String channelId) async {
    final m = epgMappings[channelId];
    if (m != null) m['locked'] = true;
  }

  Future<void> deleteEpgMapping(String channelId) async {
    epgMappings.remove(channelId);
  }

  Future<List<Map<String, dynamic>>> getPendingEpgSuggestions() async =>
      epgMappings.values
          .where(
            (m) =>
                (m['confidence'] as num) >= 0.40 &&
                (m['confidence'] as num) < 0.70 &&
                m['locked'] != true,
          )
          .toList();

  Future<void> setChannel247(String channelId, {required bool is247}) async {
    channel247Flags[channelId] = is247;
    final ch = channels[channelId];
    if (ch != null) ch['is_247'] = is247;
  }

  // ── Watch History ──────────────────────────────

  Future<List<Map<String, dynamic>>> loadWatchHistory() async =>
      watchHistory.values.toList();

  Future<void> saveWatchHistory(Map<String, dynamic> entry) async {
    watchHistory[entry['id'] as String] = entry;
  }

  Future<void> deleteWatchHistory(String id) async {
    watchHistory.remove(id);
  }

  Future<int> clearAllWatchHistory() async {
    final count = watchHistory.length;
    watchHistory.clear();
    return count;
  }
}
