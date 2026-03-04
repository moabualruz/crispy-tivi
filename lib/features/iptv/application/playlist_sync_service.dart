import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/settings_notifier.dart';
import '../../../core/data/cache_service.dart';
import '../../../core/network/http_service.dart';
import '../../vod/presentation/providers/vod_providers.dart';
import '../data/datasources/channel_local_datasource.dart';
import '../data/repositories/channel_repository_impl.dart';
import '../../../core/domain/entities/playlist_source.dart';
import 'playlist_epg_helper.dart';
import 'playlist_sync_helpers.dart';
import 'refresh_playlist.dart';

/// Default sync interval in hours.
const kDefaultSyncIntervalHours = 24;

/// Result of partitioning sources into stale vs fresh.
///
/// [stale] — sources that need a network sync.
/// [nextSync] — time until the freshest source expires, or
/// `null` when all sources are stale.
typedef PartitionResult = ({List<PlaylistSource> stale, Duration? nextSync});

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

/// Singleton datasource so repository and sync share
/// the same store.
final channelDatasourceProvider = Provider<ChannelLocalDatasource>(
  (_) => ChannelLocalDatasource(),
);

/// Repository backed by the shared datasource.
final channelRepositoryProvider = Provider<ChannelRepositoryImpl>(
  (ref) => ChannelRepositoryImpl(
    ref.read(channelDatasourceProvider),
    ref.read(crispyBackendProvider),
  ),
);

/// Service that syncs playlist sources → channels
/// + VODs.
///
/// Bridges [SettingsNotifier] (user's configured
/// sources) with [RefreshPlaylist] (fetch/parse) and
/// UI notifiers. Persists results to [CacheService]
/// for cross-session continuity.
class PlaylistSyncService with PlaylistSyncHelpers, PlaylistEpgHelper {
  PlaylistSyncService(this._ref);
  final Ref _ref;

  @override
  Ref get ref => _ref;

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

      // 2. Await settings (may still be loading
      //    on startup).
      final settings = await _ref.read(settingsNotifierProvider.future);

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

      // 4. Sync stale sources from network.
      final http = _ref.read(httpServiceProvider);
      final repo = _ref.read(channelRepositoryProvider);
      final backend = _ref.read(crispyBackendProvider);
      final refresh = RefreshPlaylist(repo, http, backend);

      var totalChannels = 0;
      var allVodItems = <dynamic>[];
      final allChannelGroups = <String>{};
      final allVodCategories = <String>{};

      for (final source in staleSources) {
        final result = await refresh.call(source);
        totalChannels += result.totalChannels;
        allChannelGroups.addAll(result.channelGroups);
        allVodItems.addAll(result.vodItems);
        allVodCategories.addAll(result.vodCategories);

        // Cleanup stale items for this source.
        await cleanupStaleItems(
          source: source,
          freshChannelIds: result.channels.map((c) => c.id).toSet(),
          freshVodIds: result.vodItems.map((v) => v.id).toSet(),
        );

        // Auto-save discovered EPG URL.
        if (result.discoveredEpgUrl != null &&
            (source.epgUrl == null || source.epgUrl!.isEmpty)) {
          await autoSaveEpgUrl(source, result.discoveredEpgUrl!);
        }

        // Record sync time.
        await cache.setLastSyncTime(source.id, DateTime.now());

        debugPrint(
          'PlaylistSync: ${source.name} → '
          '${result.totalChannels} channels, '
          '${result.totalVod} VOD items',
        );
      }

      // Schedule next deferred sync.
      _scheduleDeferredSync(interval);

      // 5. Push to UI notifiers.
      if (totalChannels > 0) {
        await reloadChannelList();
      }
      if (allVodItems.isNotEmpty && _ref.exists(vodProvider)) {
        _ref.read(vodProvider.notifier).loadData(allVodItems.cast());
      }

      // 6. Persist to cache for next startup.
      final repo2 = _ref.read(channelRepositoryProvider);
      final channels = await repo2.getChannels();
      await cache.saveChannels(channels);
      await cache.saveVodItems(allVodItems.cast());
      await cache.saveCategories({
        'live': allChannelGroups.toList()..sort(),
        'vod': allVodCategories.toList()..sort(),
      });
      debugPrint(
        'PlaylistSync: persisted '
        '${channels.length} '
        'channels + ${allVodItems.length} '
        'VODs to DB',
      );

      // 7. Auto-fetch missing images in background.
      // (Removed in Phase 10)

      // 8. Fetch EPG after successful sync.
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
  Future<SyncResult> syncSource(PlaylistSource source) async {
    try {
      final http = _ref.read(httpServiceProvider);
      final repo = _ref.read(channelRepositoryProvider);
      final backend = _ref.read(crispyBackendProvider);
      final refresh = RefreshPlaylist(repo, http, backend);
      final cache = _ref.read(cacheServiceProvider);

      final result = await refresh.call(source);
      debugPrint(
        'PlaylistSync: ${source.name} → '
        '${result.totalChannels} channels, '
        '${result.totalVod} VOD items',
      );

      // Push to UI.
      if (result.totalChannels > 0) {
        await reloadChannelList();
      }
      if (result.vodItems.isNotEmpty && _ref.exists(vodProvider)) {
        // Merge with existing VOD items.
        final existing = _ref.read(vodProvider).items;
        final merged = [...existing, ...result.vodItems];
        _ref.read(vodProvider.notifier).loadData(merged);
      }

      // Update cache.
      await cache.setLastSyncTime(source.id, DateTime.now());
      final channels = await repo.getChannels();
      await cache.saveChannels(channels);

      // Wait, we need to save everything. But if the provider isn't mounted,
      // we can't reliably read its items (and they aren't merged anyway).
      // If we didn't merge because the UI isn't mounted, we should read
      // the existing VOD items from DB and merge before saving, OR
      // perhaps the cache save handles it?
      // Actually, cache.saveVodItems(allVod) does an UPSERT based on ID.
      // But if we only pass `result.vodItems`, it will just upsert those.
      // The previous code did:
      // final allVod = _ref.read(vodProvider).items;
      // await cache.saveVodItems(allVod);
      // Let's just save the new models, they will upsert!
      await cache.saveVodItems(result.vodItems);

      // Fetch EPG after single source sync.
      await fetchEpg();

      return result;
    } catch (e) {
      debugPrint('PlaylistSync error: $e');
      return const SyncResult();
    }
  }

  /// Public method to manually refresh EPG data.
  Future<void> refreshEpg() => fetchEpg();

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
