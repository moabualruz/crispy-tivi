import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/data/cache_service.dart';
import '../../../core/data/crispy_backend.dart';
import '../../../core/data/device_service.dart';
import '../../profiles/data/profile_service.dart';
import '../domain/entities/watch_history_entry.dart';

/// Manages watch history for continue-watching
/// and resume.
class WatchHistoryService {
  /// Derives a watch-history ID from a stream URL.
  static String deriveId(String streamUrl) =>
      streamUrl.hashCode.toRadixString(36);

  WatchHistoryService(
    this._cache,
    this._deviceService,
    this._backend,
    this._activeProfileId, {
    // FE-PM-10: guest profiles skip all watch history writes.
    bool isGuestProfile = false,
  }) : _isGuestProfile = isGuestProfile;

  final CacheService _cache;
  final DeviceService _deviceService;
  final CrispyBackend _backend;
  final String _activeProfileId;

  /// True when the active profile is a guest — no history is persisted.
  ///
  /// FE-PM-10: checked in [record] and [updatePosition].
  final bool _isGuestProfile;

  /// Record or update a watch history entry.
  ///
  /// FE-PM-10: no-op when the active profile is a guest.
  Future<void> record({
    required String id,
    required String mediaType,
    required String name,
    required String streamUrl,
    String? posterUrl,
    String? seriesPosterUrl,
    int positionMs = 0,
    int durationMs = 0,
    String? seriesId,
    int? seasonNumber,
    int? episodeNumber,
    String? sourceId,
  }) async {
    // FE-PM-10: guest profiles never persist watch history.
    if (_isGuestProfile) return;

    final deviceId = await _deviceService.getDeviceId();
    final deviceName = await _deviceService.getDeviceName();

    int finalDuration = durationMs;
    if (finalDuration <= 0) {
      final existing = await getById(id);
      if (existing != null && existing.durationMs > 0) {
        finalDuration = existing.durationMs;
      }
    }

    final entry = WatchHistoryEntry(
      id: id,
      mediaType: mediaType,
      name: name,
      streamUrl: streamUrl,
      posterUrl: posterUrl,
      seriesPosterUrl: seriesPosterUrl,
      positionMs: positionMs,
      durationMs: finalDuration,
      lastWatched: DateTime.now(),
      seriesId: seriesId,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      deviceId: deviceId,
      deviceName: deviceName,
      profileId: _activeProfileId,
      sourceId: sourceId,
    );
    await _cache.saveWatchHistory(entry);
  }

  /// Update just the playback position.
  ///
  /// FE-PM-10: no-op when the active profile is a guest.
  Future<void> updatePosition(String id, int positionMs) async {
    // FE-PM-10: guest profiles never persist watch history.
    if (_isGuestProfile) return;

    final deviceId = await _deviceService.getDeviceId();
    final deviceName = await _deviceService.getDeviceName();

    final all = await _cache.loadWatchHistory();
    final existing = all.where((e) => e.id == id);
    if (existing.isEmpty) return;

    final entry = existing.first.copyWith(
      positionMs: positionMs,
      lastWatched: DateTime.now(),
      deviceId: deviceId,
      deviceName: deviceName,
      profileId: _activeProfileId,
    );
    await _cache.saveWatchHistory(entry);
  }

  /// Get all watch history entries sorted by
  /// recency.
  Future<List<WatchHistoryEntry>> getAll() async {
    final entries = await _cache.loadWatchHistory();
    entries.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
    return entries;
  }

  /// Get continue-watching items
  /// (position > 0, < 95%).
  ///
  /// Delegates filtering, sorting, and limit to
  /// the Rust backend.
  Future<List<WatchHistoryEntry>> getContinueWatching({
    String? mediaType,
  }) async {
    final all = await _cache.loadWatchHistory();
    final maps = all.map(watchHistoryEntryToMap).toList();
    final json = jsonEncode(maps);

    final resultJson = await _backend.filterContinueWatching(
      json,
      mediaType: mediaType,
      profileId: _activeProfileId,
    );

    final decoded = jsonDecode(resultJson) as List<dynamic>;
    final entries =
        decoded
            .map((e) => mapToWatchHistoryEntry(e as Map<String, dynamic>))
            .toList();

    // Dedup by (profileId, mediaType, name) keeping the entry with the
    // highest lastWatched. Duplicates arise when the same media item is
    // watched from different stream URLs (e.g. token rotation in IPTV
    // links), producing distinct ids from different hashCodes.
    // filterContinueWatching already returns results sorted by
    // lastWatched DESC, so the first occurrence per key is the newest.
    final seen = <String>{};
    return entries.where((e) {
      final key = '${e.profileId}:${e.mediaType}:${e.name}';
      return seen.add(key);
    }).toList();
  }

  /// Get items watched on OTHER devices.
  ///
  /// Delegates filtering, sorting, and limit to
  /// the Rust backend.
  Future<List<WatchHistoryEntry>> getFromOtherDevices() async {
    final currentDeviceId = await _deviceService.getDeviceId();
    final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
    final cutoffMs = cutoffDate.millisecondsSinceEpoch;

    final all = await _cache.loadWatchHistory();
    final maps = all.map(watchHistoryEntryToMap).toList();
    final json = jsonEncode(maps);

    final resultJson = await _backend.filterCrossDevice(
      json,
      currentDeviceId,
      cutoffMs,
    );

    final decoded = jsonDecode(resultJson) as List<dynamic>;
    return decoded
        .map((e) => mapToWatchHistoryEntry(e as Map<String, dynamic>))
        .toList();
  }

  /// Check if item was last watched on a
  /// different device.
  Future<String?> getOtherDeviceSource(String id) async {
    final entry = await getById(id);
    if (entry == null) return null;

    final currentDeviceId = await _deviceService.getDeviceId();
    if (entry.deviceId != null && entry.deviceId != currentDeviceId) {
      return entry.deviceName ?? 'Another device';
    }
    return null;
  }

  /// Get a specific watch history entry by ID.
  Future<WatchHistoryEntry?> getById(String id) async {
    final all = await _cache.loadWatchHistory();
    final matches = all.where((e) => e.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  /// Delete a specific history entry.
  Future<void> delete(String id) async {
    await _cache.deleteWatchHistory(id);
  }

  /// Clear all history.
  Future<void> clearAll() async {
    await _cache.clearAllWatchHistory();
  }
}

/// Riverpod provider for [WatchHistoryService].
final watchHistoryServiceProvider = Provider<WatchHistoryService>((ref) {
  final cache = ref.watch(cacheServiceProvider);
  final deviceService = ref.watch(deviceServiceProvider);
  final backend = ref.watch(crispyBackendProvider);
  final profileState = ref.watch(profileServiceProvider).value;
  // FE-PM-10: pass isGuestProfile so guest sessions skip history writes.
  final isGuest = profileState?.activeProfile?.isGuest ?? false;
  return WatchHistoryService(
    cache,
    deviceService,
    backend,
    profileState?.activeProfileId ?? 'default',
    isGuestProfile: isGuest,
  );
});

/// Provider for continue-watching movies.
final continueWatchingMoviesProvider = FutureProvider<List<WatchHistoryEntry>>((
  ref,
) async {
  final service = ref.watch(watchHistoryServiceProvider);
  return service.getContinueWatching(mediaType: 'movie');
});

/// Provider for continue-watching episodes.
final continueWatchingSeriesProvider = FutureProvider<List<WatchHistoryEntry>>((
  ref,
) async {
  final service = ref.watch(watchHistoryServiceProvider);
  return service.getContinueWatching(mediaType: 'episode');
});

/// Provider for items watched on other devices.
final crossDeviceWatchingProvider = FutureProvider<List<WatchHistoryEntry>>((
  ref,
) async {
  final service = ref.watch(watchHistoryServiceProvider);
  return service.getFromOtherDevices();
});

/// Provider for progress lookup by media ID.
final watchProgressProvider = FutureProvider.family<double?, String>((
  ref,
  mediaId,
) async {
  final service = ref.watch(watchHistoryServiceProvider);
  final history = await service.getById(mediaId);
  if (history == null || history.durationMs == 0) {
    return null;
  }
  final progress = history.progress.clamp(0.0, 1.0);
  return progress < kCompletionThreshold ? progress : null;
});

/// Provider to check if item was watched on
/// another device.
final otherDeviceSourceProvider = FutureProvider.family<String?, String>((
  ref,
  mediaId,
) async {
  final service = ref.watch(watchHistoryServiceProvider);
  return service.getOtherDeviceSource(mediaId);
});

/// Provider that returns `true` when the media item has been
/// watched to completion (raw progress >=
/// [kCompletionThreshold]).
///
/// Unlike [watchProgressProvider] — which returns `null` for
/// completed items — this provider is specifically for the
/// "completed" checkmark badge on [VodPosterCard].
final vodItemIsCompletedProvider = FutureProvider.family<bool, String>((
  ref,
  mediaId,
) async {
  final service = ref.watch(watchHistoryServiceProvider);
  final history = await service.getById(mediaId);
  if (history == null || history.durationMs == 0) return false;
  final progress = history.progress.clamp(0.0, 1.0);
  return progress >= kCompletionThreshold;
});
