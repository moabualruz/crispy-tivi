part of 'cache_service.dart';

/// EPG entries, EPG mappings, and EPG converter helpers for [CacheService].
mixin _CacheEpgMixin on _CacheServiceBase {
  // ── EPG Entries ───────────────────────────────────

  /// Fetch exactly the programs airing within [start] and [end]
  /// for the specified [channelIds].
  Future<Map<String, List<EpgEntry>>> getEpgsForChannels(
    List<String> channelIds,
    DateTime start,
    DateTime end,
  ) async {
    if (channelIds.isEmpty) return {};
    final sw = Stopwatch()..start();
    final raw = await _backend.getEpgsForChannels(channelIds, start, end);
    final result = <String, List<EpgEntry>>{};
    int count = 0;
    for (final entry in raw.entries) {
      result[entry.key] = entry.value.map(mapToEpgEntry).toList();
      count += entry.value.length;
    }
    debugPrint(
      'CacheService: loaded $count EPG entries for '
      '${result.length} viewed channels in ${sw.elapsedMilliseconds}ms',
    );
    return result;
  }

  /// Fetch EPG via the 3-layer facade (L1 hot cache → L2 SQLite → L3 API).
  Future<Map<String, List<EpgEntry>>> getChannelsEpg(
    List<String> channelIds,
    DateTime start,
    DateTime end,
  ) async {
    if (channelIds.isEmpty) return {};
    final sw = Stopwatch()..start();
    final raw = await _backend.getChannelsEpg(channelIds, start, end);
    final result = <String, List<EpgEntry>>{};
    int count = 0;
    for (final entry in raw.entries) {
      result[entry.key] = entry.value.map(mapToEpgEntry).toList();
      count += entry.value.length;
    }
    debugPrint(
      'CacheService: loaded $count EPG entries (facade) for '
      '${result.length} channels in ${sw.elapsedMilliseconds}ms',
    );
    return result;
  }

  /// Resolve internal channel IDs with real EPG coverage in the window.
  Future<List<String>> getEpgCoverageChannelIds(
    List<String> channelIds,
    DateTime start,
    DateTime end,
  ) async {
    if (channelIds.isEmpty) return const [];
    final sw = Stopwatch()..start();
    final ids = await _backend.getEpgCoverageChannelIds(channelIds, start, end);
    debugPrint(
      'CacheService: resolved ${ids.length} EPG-covered channels '
      'from ${channelIds.length} candidates in ${sw.elapsedMilliseconds}ms',
    );
    return ids;
  }

  /// Saves EPG entries using upsert.
  Future<void> saveEpgEntries(
    Map<String, List<EpgEntry>> entriesByChannel,
  ) async {
    final sw = Stopwatch()..start();
    final totalEntries = entriesByChannel.values.fold<int>(
      0,
      (sum, list) => sum + list.length,
    );

    final mapEntries = <String, List<Map<String, dynamic>>>{};
    for (final entry in entriesByChannel.entries) {
      mapEntries[entry.key] = entry.value.map(epgEntryToMap).toList();
    }

    await _backend.saveEpgEntries(mapEntries);
    debugPrint(
      'CacheService: upserted $totalEntries EPG '
      'entries across '
      '${entriesByChannel.length} channels '
      'in ${sw.elapsedMilliseconds}ms',
    );
  }

  /// Loads all EPG entries grouped by channel ID.
  Future<Map<String, List<EpgEntry>>> loadEpgEntries() async {
    final sw = Stopwatch()..start();
    final raw = await _backend.loadEpgEntries();
    final result = <String, List<EpgEntry>>{};
    int count = 0;
    for (final entry in raw.entries) {
      result[entry.key] = entry.value.map(mapToEpgEntry).toList();
      count += entry.value.length;
    }
    debugPrint(
      'CacheService: loaded $count EPG '
      'entries across ${result.length} channels '
      'in ${sw.elapsedMilliseconds}ms',
    );
    return result;
  }

  /// Evicts EPG entries older than [days] days.
  Future<int> evictStaleEpgEntries({int days = 2}) async {
    final sw = Stopwatch()..start();
    final count = await _backend.evictStaleEpg(days);
    if (count > 0) {
      debugPrint(
        'CacheService: evicted $count stale EPG '
        'entries (older than $days days) '
        'in ${sw.elapsedMilliseconds}ms',
      );
    }
    return count;
  }

  /// Clears all EPG entries.
  Future<void> clearEpgEntries() async {
    await _backend.clearEpgEntries();
  }

  // ── EPG Mappings ─────────────────────────────────

  /// Save an EPG mapping.
  Future<void> saveEpgMapping(Map<String, dynamic> mapping) =>
      _backend.saveEpgMapping(mapping);

  /// Get all EPG mappings.
  Future<List<Map<String, dynamic>>> getEpgMappings() =>
      _backend.getEpgMappings();

  /// Lock an EPG mapping so it won't be overridden.
  Future<void> lockEpgMapping(String channelId) =>
      _backend.lockEpgMapping(channelId);

  /// Delete an EPG mapping.
  Future<void> deleteEpgMapping(String channelId) =>
      _backend.deleteEpgMapping(channelId);

  /// Get pending EPG suggestions (0.40-0.69 confidence, not locked).
  Future<List<Map<String, dynamic>>> getPendingEpgSuggestions() =>
      _backend.getPendingEpgSuggestions();

  /// Mark a channel as 24/7.
  Future<void> setChannel247(String channelId, {required bool is247}) =>
      _backend.setChannel247(channelId, is247: is247);
}

// ── EPG converters (top-level) ────────────────────

/// Converts a backend map to an [EpgEntry] entity.
///
/// Handles two serialization formats emitted by the Rust layer:
/// 1. SQLite row map — `channel_id`, `start_time` / `end_time` as NaiveDateTime strings.
/// 2. Rust `EpgEntry` serde JSON — `epg_channel_id`, `start_time` / `end_time` as
///    NaiveDateTime strings (snake_case, no rename_all).
EpgEntry mapToEpgEntry(Map<String, dynamic> m) {
  // Field name: Rust serializes EpgEntry.epg_channel_id; SQLite rows use channel_id.
  final channelId = (m['epg_channel_id'] ?? m['channel_id']) as String? ?? '';

  // Timestamps arrive as NaiveDateTime strings ("2024-01-01T12:00:00") from both
  // SQLite rows and the Rust serde path. Fall back to epoch on null.
  final startTime = _parseTimestamp(m['start_time']);
  final endTime = _parseTimestamp(m['end_time']);

  return EpgEntry(
    channelId: channelId,
    title: m['title'] as String? ?? '',
    startTime: startTime,
    endTime: endTime,
    description: m['description'] as String?,
    category: m['category'] as String?,
    iconUrl: m['icon_url'] as String?,
    sourceId: m['source_id'] as String?,
  );
}

/// Parses a timestamp value from a backend map.
///
/// Accepts:
/// - `String` — NaiveDateTime ("2024-01-01T12:00:00") parsed as UTC.
/// - `int` — epoch seconds (used by some Rust paths).
DateTime _parseTimestamp(dynamic value) {
  if (value == null) return DateTime.utc(1970);
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
  }
  if (value is String) return _parseNaiveUtc(value);
  return DateTime.utc(1970);
}

/// Converts an [EpgEntry] entity to a backend map.
Map<String, dynamic> epgEntryToMap(EpgEntry e) {
  return {
    'channel_id': e.channelId,
    'title': e.title,
    'start_time': _toNaiveDateTime(e.startTime),
    'end_time': _toNaiveDateTime(e.endTime),
    'description': e.description,
    'category': e.category,
    'icon_url': e.iconUrl,
    'source_id': e.sourceId,
  };
}
