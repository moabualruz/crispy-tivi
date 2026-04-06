import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dvr/domain/entities/recording.dart';
import '../../features/dvr/domain/entities/recording_profile.dart';
import '../../features/dvr/domain/entities/storage_backend.dart';
import '../../features/dvr/domain/entities/transfer_task.dart';
import '../../features/dvr/domain/entities/commercial_marker.dart';
import '../../features/dvr/domain/utils/dvr_payload.dart';
import '../../features/iptv/domain/entities/channel.dart';
import '../../features/iptv/domain/entities/epg_entry.dart';
import '../../features/multiview/domain/entities/'
    'multiview_session.dart';
import '../../features/multiview/domain/entities/'
    'saved_layout.dart';
import '../../features/player/domain/entities/'
    'watch_history_entry.dart';
import '../../features/profiles/domain/entities/'
    'user_profile.dart';
import '../../features/profiles/domain/enums/'
    'dvr_permission.dart';
import '../../features/profiles/domain/enums/user_role.dart';
import '../../features/search/domain/entities/'
    'search_history_entry.dart';
import '../../features/vod/domain/entities/vod_item.dart';
import '../domain/entities/playlist_source.dart';
import '../domain/entities/xtream_account_info.dart';
import 'codecs/xtream_json_codec.dart';
import '../../features/multiview/data/multiview_json_codec.dart';
import '../utils/date_format_utils.dart';
import 'crispy_backend.dart';

part 'cache_service_channels.dart';
part 'cache_service_vod.dart';
part 'cache_service_profiles.dart';
part 'cache_service_dvr.dart';
part 'cache_service_media.dart';

/// Base class providing backend access to all
/// [CacheService] mixins.
abstract class _CacheServiceBase {
  _CacheServiceBase(this._backend);

  final CrispyBackend _backend;
}

/// Cross-platform persistent cache backed by Rust
/// via [CrispyBackend].
///
/// Converts domain entities to/from snake_case maps
/// that the Rust backend expects.
class CacheService extends _CacheServiceBase
    with
        _CacheChannelsMixin,
        _CacheVodMixin,
        _CacheProfilesMixin,
        _CacheDvrMixin,
        _CacheMediaMixin {
  CacheService(super.backend);

  // ── Categories ────────────────────────────────

  /// Save category map for a source (type -> list of names).
  Future<void> saveCategories(
    String sourceId,
    Map<String, List<String>> cats,
  ) async {
    final sw = Stopwatch()..start();
    final totalCats = cats.values.fold<int>(
      0,
      (sum, list) => sum + list.length,
    );
    await _backend.saveCategories(sourceId, cats);
    debugPrint(
      'CacheService: saved $totalCats categories '
      '(${cats.keys.join(', ')}) '
      'in ${sw.elapsedMilliseconds}ms',
    );
  }

  /// Load category map.
  Future<Map<String, List<String>>> loadCategories() async {
    return _backend.loadCategories();
  }

  // ── Sync Metadata ─────────────────────────────

  /// Save last sync time for a source.
  Future<void> setLastSyncTime(String sourceId, DateTime time) async {
    await _backend.setLastSyncTime(
      sourceId,
      time.millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// Get last sync time for a source.
  Future<DateTime?> getLastSyncTime(String sourceId) async {
    final ts = await _backend.getLastSyncTime(sourceId);
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts * 1000);
  }

  // ── Settings ──────────────────────────────────

  /// Reads a setting value by [key].
  Future<String?> getSetting(String key) async {
    return _backend.getSetting(key);
  }

  /// Writes a setting [value] for [key] (upsert).
  Future<void> setSetting(String key, String value) async {
    await _backend.setSetting(key, value);
  }

  /// Removes a setting by [key].
  Future<void> removeSetting(String key) async {
    await _backend.removeSetting(key);
  }

  /// Reads a setting stored as a JSON list of ints.
  ///
  /// Returns `null` if the key is not set or the value is empty.
  Future<List<int>?> getSettingIntList(String key) async {
    final raw = await _backend.getSetting(key);
    if (raw == null || raw.isEmpty) return null;
    return (jsonDecode(raw) as List).cast<int>();
  }

  /// Writes a list of ints as a JSON setting.
  Future<void> setSettingIntList(String key, List<int> values) async {
    await _backend.setSetting(key, jsonEncode(values));
  }

  // ── Sources ──────────────────────────────────

  /// Load all content sources sorted by sort_order.
  Future<List<PlaylistSource>> getSources() async {
    final maps = await _backend.getSources();
    return maps.map(mapToSource).toList();
  }

  /// Get a single source by ID.
  Future<PlaylistSource?> getSource(String id) async {
    final m = await _backend.getSource(id);
    if (m == null) return null;
    return mapToSource(m);
  }

  /// Create or update a content source.
  Future<void> saveSource(PlaylistSource source) async {
    await _backend.saveSource(sourceToMap(source));
  }

  /// Delete a source and cascade-delete all its
  /// channels, VOD, EPG, categories, sync metadata.
  Future<void> deleteSource(String id) async {
    await _backend.deleteSource(id);
  }

  /// Reorder sources by providing the full ordered
  /// list of source IDs.
  Future<void> reorderSources(List<String> ids) async {
    await _backend.reorderSources(ids);
  }

  /// Update sync status fields on a source.
  Future<void> updateSourceSyncStatus(
    String id,
    String status, {
    String? error,
    int? syncTimeMs,
  }) async {
    await _backend.updateSourceSyncStatus(
      id,
      status,
      error: error,
      syncTimeMs: syncTimeMs,
    );
  }

  /// Get per-source stats (channel count, VOD count).
  Future<String> getSourceStats() => _backend.getSourceStats();

  /// Fetch Xtream account info for a source.
  ///
  /// Calls the Xtream `get_account_info` endpoint and
  /// returns the parsed [XtreamAccountInfo] entity.
  Future<XtreamAccountInfo> fetchXtreamAccountInfo({
    required String baseUrl,
    required String username,
    required String password,
    bool acceptInvalidCerts = false,
  }) async {
    final jsonStr = await _backend.fetchXtreamAccountInfo(
      baseUrl: baseUrl,
      username: username,
      password: password,
      acceptInvalidCerts: acceptInvalidCerts,
    );
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return XtreamJsonCodec.fromJson(map);
  }

  // ── Buffer Tier ───────────────────────────────

  /// Get the persisted adaptive-buffer tier for [urlHash].
  Future<String?> getBufferTier(String urlHash) =>
      _backend.getBufferTier(urlHash);

  /// Persist an adaptive-buffer [tier] for [urlHash].
  Future<void> setBufferTier(String urlHash, String tier) =>
      _backend.setBufferTier(urlHash, tier);

  /// Prune buffer-tier entries, keeping only the newest
  /// [maxEntries]. Returns the number of rows deleted.
  Future<int> pruneBufferTiers(int maxEntries) =>
      _backend.pruneBufferTiers(maxEntries);

  /// Feed a buffer-health sample and return the
  /// (possibly updated) tier as JSON.
  Future<String> evaluateBufferSample(
    String urlHash,
    double cacheDurationSecs,
  ) => _backend.evaluateBufferSample(urlHash, cacheDurationSecs);

  /// Reset in-memory buffer counters for [urlHash].
  Future<void> resetBufferState(String urlHash) =>
      _backend.resetBufferState(urlHash);

  /// Android heap-adaptive forward-buffer cap in MB.
  int getBufferCapMb(int heapMaxMb) => _backend.getBufferCapMb(heapMaxMb);

  // ── Stream Health ──────────────────────────────

  /// Record a stream stall event for [urlHash].
  Future<void> recordStreamStall(String urlHash) =>
      _backend.recordStreamStall(urlHash);

  /// Record a buffer health sample for [urlHash].
  Future<void> recordStreamBufferSample(
    String urlHash,
    double cacheDurationSecs,
  ) => _backend.recordStreamBufferSample(urlHash, cacheDurationSecs);

  /// Record time-to-first-frame for [urlHash].
  Future<void> recordStreamTtff(String urlHash, int ttffMs) =>
      _backend.recordStreamTtff(urlHash, ttffMs);

  /// Get the health score for [urlHash] (0.0–1.0).
  Future<double> getStreamHealthScore(String urlHash) =>
      _backend.getStreamHealthScore(urlHash);

  /// Get health scores for multiple URL hashes.
  Future<String> getStreamHealthScores(String urlHashesJson) =>
      _backend.getStreamHealthScores(urlHashesJson);

  /// Keep only the newest [maxEntries] stream health rows.
  Future<int> pruneStreamHealth(int maxEntries) =>
      _backend.pruneStreamHealth(maxEntries);

  /// Feed a failover event and get the action decision.
  Future<String> evaluateFailoverEvent(
    String urlHash,
    String eventType,
    double value,
  ) => _backend.evaluateFailoverEvent(urlHash, eventType, value);

  /// Reset in-memory failover counters for [urlHash].
  Future<void> resetFailoverState(String urlHash) =>
      _backend.resetFailoverState(urlHash);

  /// Rank alternative streams for failover.
  Future<String> rankStreamAlternatives(
    String targetJson,
    String allChannelsJson,
    String healthScoresJson,
  ) => _backend.rankStreamAlternatives(
    targetJson,
    allChannelsJson,
    healthScoresJson,
  );

  /// Extract a US broadcast call sign from a channel name.
  String extractCallSign(String name) => _backend.extractCallSign(name);

  // ── App Update ─────────────────────────────────

  String? _lastUpdateCheckResult;
  DateTime? _lastUpdateCheckTime;

  /// Check for updates with in-memory caching.
  ///
  /// [checkInterval] — skip if last successful check was
  /// within this duration.
  Future<String> checkForUpdate(
    String currentVersion,
    String repoUrl, {
    Duration? checkInterval,
  }) async {
    if (checkInterval != null &&
        _lastUpdateCheckResult != null &&
        _lastUpdateCheckTime != null) {
      final elapsed = DateTime.now().difference(_lastUpdateCheckTime!);
      if (elapsed < checkInterval) {
        return _lastUpdateCheckResult!;
      }
    }
    final result = await _backend.checkForUpdate(currentVersion, repoUrl);
    final parsed = jsonDecode(result) as Map<String, dynamic>;
    if (parsed['error'] == null) {
      _lastUpdateCheckResult = result;
      _lastUpdateCheckTime = DateTime.now();
    }
    return result;
  }

  /// Checks for update and returns parsed map.
  ///
  /// Wraps [checkForUpdate] with JSON decoding so callers
  /// don't need dart:convert.
  Future<Map<String, dynamic>> checkForUpdateParsed(
    String currentVersion,
    String repoUrl, {
    Duration? checkInterval,
  }) async {
    final raw = await checkForUpdate(
      currentVersion,
      repoUrl,
      checkInterval: checkInterval,
    );
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Find a platform-specific download URL from release assets.
  String? getPlatformAssetUrl(String assetsJson, String platform) =>
      _backend.getPlatformAssetUrl(assetsJson, platform);

  // ── Logo Resolver ─────────────────────────────

  /// Resolve a channel logo URL from the tv-logos index.
  Future<String?> resolveChannelLogo(String name) =>
      _backend.resolveChannelLogo(name);

  /// Resolve logos for multiple channels at once.
  Future<String> resolveLogosBatch(String namesJson) =>
      _backend.resolveLogosBatch(namesJson);

  /// Check if the tv-logos index needs refreshing.
  Future<bool> isLogoIndexStale() => _backend.isLogoIndexStale();

  /// Fetch and cache a fresh tv-logos index.
  Future<void> refreshLogoIndex() => _backend.refreshLogoIndex();

  /// Decode a BlurHash string into BMP image bytes.
  Uint8List decodeBlurHash(String hash, {int width = 16, int height = 16}) =>
      _backend.decodeBlurHash(hash, width, height);

  // ── Clear ─────────────────────────────────────

  /// Clears all cached data.
  Future<void> clearAll() async {
    await _backend.clearAll();
  }
}

// ── Helpers ─────────────────────────────────────

/// Format [DateTime] as a NaiveDateTime string for
/// Rust serde.
///
/// Delegates to [toNaiveDateTime] in
/// `date_format_utils.dart`.
String _toNaiveDateTime(DateTime dt) => toNaiveDateTime(dt);

/// Parse a NaiveDateTime string (no timezone) as UTC.
///
/// Delegates to [parseNaiveUtc] in
/// `date_format_utils.dart`.
DateTime _parseNaiveUtc(String s) => parseNaiveUtc(s);

/// Parses a [DateTime] from a map value that may
/// be a [String], [DateTime], or null. Treats
/// timezone-less strings as UTC (NaiveDateTime
/// round-trip from Rust).
DateTime? parseMapDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    final dt = DateTime.tryParse(value);
    if (dt == null) return null;
    return dt.isUtc
        ? dt
        : DateTime.utc(
          dt.year,
          dt.month,
          dt.day,
          dt.hour,
          dt.minute,
          dt.second,
          dt.millisecond,
          dt.microsecond,
        );
  }
  return null;
}

// ── Source converters ────────────────────────────

/// Converts a [PlaylistSource] entity to a backend
/// map matching the Rust `Source` struct fields.
Map<String, dynamic> sourceToMap(PlaylistSource s) => {
  'id': s.id,
  'name': s.name,
  'source_type': s.type.name,
  'url': s.url,
  'username': s.username,
  'password': s.password,
  'access_token': s.accessToken,
  'device_id': s.deviceId,
  'user_id': s.userId,
  'mac_address': s.macAddress,
  'epg_url': s.epgUrl,
  'user_agent': s.userAgent,
  'refresh_interval_minutes': s.refreshIntervalMinutes,
  'accept_self_signed': s.acceptSelfSigned,
  'enabled': true,
  'sort_order': 0,
};

/// Converts a backend map to a [PlaylistSource].
PlaylistSource mapToSource(Map<String, dynamic> m) {
  return PlaylistSource(
    id: m['id'] as String,
    name: m['name'] as String,
    url: m['url'] as String,
    type: PlaylistSourceType.values.firstWhere(
      (e) => e.name == m['source_type'],
      orElse: () => PlaylistSourceType.m3u,
    ),
    epgUrl: m['epg_url'] as String?,
    userAgent: m['user_agent'] as String?,
    refreshIntervalMinutes: (m['refresh_interval_minutes'] as int?) ?? 60,
    username: m['username'] as String?,
    password: m['password'] as String?,
    accessToken: m['access_token'] as String?,
    deviceId: m['device_id'] as String?,
    userId: m['user_id'] as String?,
    macAddress: m['mac_address'] as String?,
    acceptSelfSigned: m['accept_self_signed'] as bool? ?? false,
  );
}

/// Backend provider — platform-selected.
/// Override this in main() with FfiBackend or
/// WsBackend.
final crispyBackendProvider = Provider<CrispyBackend>(
  (ref) => throw UnimplementedError('Override crispyBackendProvider in main()'),
);

/// Riverpod provider for [CacheService].
final cacheServiceProvider = Provider<CacheService>((ref) {
  final backend = ref.watch(crispyBackendProvider);
  return CacheService(backend);
});
