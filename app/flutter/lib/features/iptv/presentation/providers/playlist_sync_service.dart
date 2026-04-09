import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/domain/entities/playlist_source.dart';
import '../../../favorites/presentation/providers/favorites_service_providers.dart'
    show stalkerFavoritesServiceProvider;
import 'channel_providers.dart' show channelListProvider;
import 'media_server_sync.dart';
import 'iptv_service_providers.dart';
import 'playlist_epg_helper.dart';
import 'playlist_sync_helpers.dart';
import 'playlist_sync_utils.dart';

export 'playlist_sync_utils.dart'
    show
        PartitionResult,
        SyncReport,
        kDefaultSyncIntervalHours,
        partitionStaleSources;

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

      // 5. Load channels into UI immediately (single DB query,
      //    no provider invalidation yet — avoids connection
      //    contention with the heavy EPG sync below).
      if (!_ref.mounted) return 0;
      if (totalChannels > 0) {
        debugPrint('PlaylistSync: loading channels into UI…');
        await ref.read(channelListProvider.notifier).refreshFromBackend();
        syncSourceNames();
      }

      // 6. Fetch EPG (heavy — 74K+ inserts, holds a DB connection).
      //    Runs BEFORE provider invalidation to avoid pool exhaustion.
      await fetchEpg();

      // 7. NOW invalidate dependent UI providers — EPG sync is done,
      //    DB connections are free for any follow-up reads.
      if (!_ref.mounted) return 0;
      if (totalVod > 0) {
        invalidateVodUiProviders();
      }

      // 7. Sync Stalker server-side favorites to local DB.
      if (!_ref.mounted) return totalChannels;
      final hasStalker = staleSources.any(
        (s) => s.type == PlaylistSourceType.stalkerPortal,
      );
      if (hasStalker) {
        try {
          await _ref.read(stalkerFavoritesServiceProvider).syncFromServer();
        } catch (e) {
          debugPrint('PlaylistSync: Stalker favorites sync error: $e');
        }
      }

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

      final report = await _syncAndRecord(backend, cache, source);
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
        invalidateVodUiProviders();
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
  Future<void> refreshEpg() => fetchEpg(force: true);

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
    final enrichVod =
        _ref.read(settingsNotifierProvider).value?.enrichVodOnSync ?? false;
    final report = await syncSourceViaRust(
      backend,
      source,
      _mediaServerSync,
      enrichVod,
    );

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
