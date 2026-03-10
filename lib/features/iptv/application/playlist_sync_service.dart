import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/settings_notifier.dart';
import '../../../core/data/cache_service.dart';
import '../../../core/data/crispy_backend.dart';
import '../../../core/domain/entities/playlist_source.dart';
import '../../vod/presentation/providers/vod_providers.dart';
import 'media_server_sync.dart';
import 'playlist_epg_helper.dart';
import 'playlist_sync_helpers.dart';

/// Default sync interval in hours.
const kDefaultSyncIntervalHours = 24;

/// Result of partitioning sources into stale vs fresh.
///
/// [stale] — sources that need a network sync.
/// [nextSync] — time until the freshest source expires, or
/// `null` when all sources are stale.
typedef PartitionResult = ({List<PlaylistSource> stale, Duration? nextSync});

/// Result of a Rust source sync operation.
class SyncReport {
  const SyncReport({
    this.channelsCount = 0,
    this.channelGroups = const [],
    this.vodCount = 0,
    this.vodCategories = const [],
    this.epgUrl,
  });

  factory SyncReport.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return SyncReport(
      channelsCount: map['channels_count'] as int? ?? 0,
      channelGroups:
          (map['channel_groups'] as List?)?.cast<String>() ?? const [],
      vodCount: map['vod_count'] as int? ?? 0,
      vodCategories:
          (map['vod_categories'] as List?)?.cast<String>() ?? const [],
      epgUrl: map['epg_url'] as String?,
    );
  }

  final int channelsCount;
  final List<String> channelGroups;
  final int vodCount;
  final List<String> vodCategories;
  final String? epgUrl;

  /// Alias for [channelsCount] — kept for call-site compatibility.
  int get totalChannels => channelsCount;
}

/// Partitions [sources] into those that need syncing and
/// those that are still fresh.
///
/// A source is stale when it has no recorded [lastSyncTimes]
/// entry, or when the elapsed time since its last sync is
/// at least [interval].  For fresh sources the remaining
/// time until expiry is tracked and the smallest value is
/// returned as [nextSync].
///
/// All comparisons are done against the caller-supplied
/// [now] so the function is deterministic and testable
/// without side effects.
PartitionResult partitionStaleSources(
  List<PlaylistSource> sources,
  Map<String, DateTime> lastSyncTimes,
  Duration interval,
  DateTime now,
) {
  final stale = <PlaylistSource>[];
  Duration? nextSync;

  for (final source in sources) {
    final lastSync = lastSyncTimes[source.id];
    if (lastSync == null) {
      stale.add(source);
      continue;
    }
    final age = now.difference(lastSync);
    if (age >= interval) {
      stale.add(source);
    } else {
      final remaining = interval - age;
      if (nextSync == null || remaining < nextSync) {
        nextSync = remaining;
      }
    }
  }

  return (stale: stale, nextSync: nextSync);
}

/// Service that syncs playlist sources → channels
/// + VODs.
///
/// Bridges [SettingsNotifier] (user's configured
/// sources) with the Rust backend sync methods and
/// UI notifiers. Rust performs all HTTP fetching,
/// parsing, saving to DB, and cleanup of stale items.
class PlaylistSyncService with PlaylistSyncHelpers, PlaylistEpgHelper {
  PlaylistSyncService(this._ref);
  final Ref _ref;

  @override
  Ref get ref => _ref;

  late final _mediaServerSync = MediaServerSyncService(_ref);

  bool _syncing = false;
  Timer? _deferredSync;

  /// Syncs all configured playlist sources.
  ///
  /// On startup, first loads cached data for instant
  /// UI, then checks sync interval before making
  /// network requests. If all sources are fresh,
  /// schedules a deferred sync for when the oldest
  /// source's interval expires.
  Future<int> syncAll({bool force = false}) async {
    if (_syncing) return 0;
    _syncing = true;
    try {
      // 1. Immediately load cached data for
      //    instant display.
      await loadFromCache();
      if (!_ref.mounted) return 0;

      // 2. Await settings (may still be loading
      //    on startup).
      final settings = await _ref.read(settingsNotifierProvider.future);
      if (!_ref.mounted) return 0;

      final sources = settings.sources;
      if (sources.isEmpty) {
        debugPrint('PlaylistSync: no sources configured');
        return 0;
      }

      // 3. Check sync interval per source.
      final cache = _ref.read(cacheServiceProvider);
      final intervalHours = settings.syncIntervalHours;
      final interval = Duration(hours: intervalHours);
      final now = DateTime.now();

      // Build list of sources that need sync.
      late final List<PlaylistSource> staleSources;

      if (!force) {
        // Fetch last-sync timestamps for all sources
        // upfront so partitionStaleSources stays pure.
        final lastSyncTimes = <String, DateTime>{};
        for (final source in sources) {
          final t = await cache.getLastSyncTime(source.id);
          if (t != null) lastSyncTimes[source.id] = t;
        }

        final partition = partitionStaleSources(
          sources,
          lastSyncTimes,
          interval,
          now,
        );
        staleSources = partition.stale;

        if (staleSources.isEmpty) {
          // All sources are fresh — schedule deferred
          // sync for when the oldest one expires.
          _scheduleDeferredSync(partition.nextSync!);
          debugPrint(
            'PlaylistSync: all sources synced within '
            '${intervalHours}h — next sync in '
            '${partition.nextSync!.inMinutes}m',
          );
          return 0;
        }
      } else {
        staleSources = List<PlaylistSource>.of(sources);
      }

      // 4. Sync stale sources via Rust backend.
      final backend = _ref.read(crispyBackendProvider);

      var totalChannels = 0;
      var totalVod = 0;
      final allChannelGroups = <String>{};
      final allVodCategories = <String>{};

      // Sync stale sources concurrently (max 3 at a time).
      const maxConcurrent = 3;
      for (var i = 0; i < staleSources.length; i += maxConcurrent) {
        final chunk = staleSources.sublist(
          i,
          (i + maxConcurrent).clamp(0, staleSources.length),
        );
        final reports = await Future.wait(
          chunk.map((s) => _syncAndRecord(backend, cache, s)),
        );
        for (final report in reports) {
          totalChannels += report.channelsCount;
          allChannelGroups.addAll(report.channelGroups);
          totalVod += report.vodCount;
          allVodCategories.addAll(report.vodCategories);
        }
      }

      // Schedule next deferred sync.
      _scheduleDeferredSync(interval);

      // 5. Reload from cache (Rust already saved to DB).
      if (!_ref.mounted) return 0;
      if (totalChannels > 0) {
        await reloadChannelList();
      }
      if (!_ref.mounted) return 0;
      if (totalVod > 0) {
        if (_ref.mounted && _ref.exists(vodProvider)) {
          _ref.invalidate(vodProvider);
        }
      }

      // 6. Fetch EPG after successful sync.
      await fetchEpg();

      return totalChannels;
    } catch (e) {
      debugPrint('PlaylistSync error: $e');
      return 0;
    } finally {
      _syncing = false;
    }
  }

  /// Syncs a single source and reloads the channel
  /// + VOD lists.
  Future<SyncReport> syncSource(PlaylistSource source) async {
    try {
      final backend = _ref.read(crispyBackendProvider);
      final cache = _ref.read(cacheServiceProvider);

      final report = await _syncSourceViaRust(backend, source);
      debugPrint(
        'PlaylistSync: ${source.name} → '
        '${report.channelsCount} channels, '
        '${report.vodCount} VOD items',
      );

      // Push to UI from cache.
      if (!_ref.mounted) return report;
      if (report.channelsCount > 0) {
        await reloadChannelList();
      }
      if (!_ref.mounted) return report;
      if (report.vodCount > 0) {
        if (_ref.mounted && _ref.exists(vodProvider)) {
          _ref.invalidate(vodProvider);
        }
      }

      // Update cache sync time.
      await cache.setLastSyncTime(source.id, DateTime.now());

      // Auto-save discovered EPG URL (e.g. from M3U header).
      if (report.epgUrl != null &&
          (source.epgUrl == null || source.epgUrl!.isEmpty)) {
        await autoSaveEpgUrl(source, report.epgUrl!);
      }

      // Fetch EPG after single source sync.
      await fetchEpg();

      return report;
    } catch (e) {
      debugPrint('PlaylistSync syncSource error: $e');
      rethrow;
    }
  }

  /// Public method to manually refresh EPG data.
  Future<void> refreshEpg() => fetchEpg();

  /// Syncs a single source and records its completion
  /// metadata (EPG auto-save + last-sync timestamp).
  ///
  /// Extracted so it can be passed to [Future.wait]
  /// during concurrent multi-source sync.
  Future<SyncReport> _syncAndRecord(
    CrispyBackend backend,
    CacheService cache,
    PlaylistSource source,
  ) async {
    final report = await _syncSourceViaRust(backend, source);

    // Auto-save discovered EPG URL.
    if (report.epgUrl != null &&
        (source.epgUrl == null || source.epgUrl!.isEmpty)) {
      await autoSaveEpgUrl(source, report.epgUrl!);
    }

    // Record sync time.
    await cache.setLastSyncTime(source.id, DateTime.now());

    debugPrint(
      'PlaylistSync: ${source.name} → '
      '${report.channelsCount} channels, '
      '${report.vodCount} VOD items',
    );

    return report;
  }

  /// Dispatches a sync call to the appropriate backend
  /// method based on [source.type].
  ///
  /// IPTV sources (M3U, Xtream, Stalker) sync via Rust.
  /// Media server sources (Plex, Emby, Jellyfin) sync
  /// via Dart HTTP clients into the same Rust DB.
  Future<SyncReport> _syncSourceViaRust(
    CrispyBackend backend,
    PlaylistSource source,
  ) async {
    // Media server sources sync via Dart HTTP clients.
    if (source.type == PlaylistSourceType.plex ||
        source.type == PlaylistSourceType.emby ||
        source.type == PlaylistSourceType.jellyfin) {
      return _mediaServerSync.syncSource(source);
    }

    // IPTV sources sync via Rust.
    final json = switch (source.type) {
      PlaylistSourceType.m3u => await backend.syncM3uSource(
        url: source.url,
        sourceId: source.id,
        acceptInvalidCerts: source.acceptSelfSigned,
      ),
      PlaylistSourceType.xtream => await backend.syncXtreamSource(
        baseUrl: source.url,
        username: source.username ?? '',
        password: source.password ?? '',
        sourceId: source.id,
        acceptInvalidCerts: source.acceptSelfSigned,
      ),
      PlaylistSourceType.stalkerPortal => await backend.syncStalkerSource(
        baseUrl: source.url,
        macAddress: source.macAddress ?? '',
        sourceId: source.id,
        acceptInvalidCerts: source.acceptSelfSigned,
      ),
      _ =>
        '{"channels_count":0,"channel_groups":[],'
            '"vod_count":0,"vod_categories":[],"epg_url":null}',
    };
    return SyncReport.fromJson(json);
  }

  /// Schedules a one-shot timer to call [syncAll]
  /// after [delay]. Cancels any previously scheduled
  /// timer.
  void _scheduleDeferredSync(Duration delay) {
    _deferredSync?.cancel();
    _deferredSync = Timer(delay, () => syncAll());
  }
}

/// Global sync service provider.
final playlistSyncServiceProvider = Provider<PlaylistSyncService>(
  (ref) => PlaylistSyncService(ref),
);
