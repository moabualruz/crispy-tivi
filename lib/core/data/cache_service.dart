import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dvr/domain/entities/recording.dart';
import '../../features/dvr/domain/entities/recording_profile.dart';
import '../../features/dvr/domain/entities/storage_backend.dart';
import '../../features/dvr/domain/entities/transfer_task.dart';
import '../../features/dvr/domain/entities/commercial_marker.dart';
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

  /// Save category map (type -> list of names).
  Future<void> saveCategories(Map<String, List<String>> cats) async {
    final sw = Stopwatch()..start();
    final totalCats = cats.values.fold<int>(
      0,
      (sum, list) => sum + list.length,
    );
    await _backend.saveCategories(cats);
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

  // ── Image Cache ───────────────────────────────
  // (Removed in Phase 10 serverless image loading)

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
/// Rust's `NaiveDateTime` expects
/// `"2024-01-01T15:00:00"` — no timezone suffix,
/// no fractional seconds. Dart's
/// `toIso8601String()` emits
/// `"2024-01-01T15:00:00.000Z"` which Rust's serde
/// cannot parse.
String _toNaiveDateTime(DateTime dt) {
  final utc = dt.toUtc();
  return '${utc.year.toString().padLeft(4, '0')}-'
      '${utc.month.toString().padLeft(2, '0')}-'
      '${utc.day.toString().padLeft(2, '0')}T'
      '${utc.hour.toString().padLeft(2, '0')}:'
      '${utc.minute.toString().padLeft(2, '0')}:'
      '${utc.second.toString().padLeft(2, '0')}';
}

/// Parse a NaiveDateTime string (no timezone) as UTC.
///
/// Rust's `NaiveDateTime` serde produces
/// `"2024-01-01T15:00:00"` — [DateTime.parse] treats
/// this as local time, but in this app all NaiveDateTime
/// values are UTC. This helper ensures the round-trip
/// `_toNaiveDateTime` → `_parseNaiveUtc` preserves
/// the UTC flag.
DateTime _parseNaiveUtc(String s) {
  final dt = DateTime.parse(s);
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
