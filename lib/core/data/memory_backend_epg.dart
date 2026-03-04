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

  Future<int> syncXmltvEpg({required String url}) async => 0;

  Future<int> syncXtreamEpg({
    required String baseUrl,
    required String username,
    required String password,
    required String channelsJson,
  }) async => 0;

  Future<int> syncStalkerEpg({
    required String baseUrl,
    required String channelsJson,
  }) async => 0;

  Future<void> clearEpgEntries() async => epg.clear();

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
