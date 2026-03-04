import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/settings_notifier.dart';
import '../../../core/data/cache_service.dart';
import '../../epg/presentation/providers/epg_providers.dart';
import '../../profiles/data/source_access_service.dart';
import '../../vod/domain/entities/vod_item.dart';
import '../../vod/presentation/providers/vod_favorites_provider.dart';
import '../../vod/presentation/providers/vod_providers.dart';
import '../domain/entities/channel.dart';
import '../domain/utils/channel_utils.dart';
import '../../../core/domain/entities/playlist_source.dart';
import '../presentation/providers/channel_providers.dart';
import 'duplicate_detection_service.dart';
import 'playlist_sync_service.dart';

/// Cache, cleanup, and UI reload helpers for
/// [PlaylistSyncService].
///
/// Extracted to keep the main service file under
/// 500 lines.
mixin PlaylistSyncHelpers {
  /// Riverpod ref for reading providers.
  Ref get ref;

  /// Filters channels by source access for the
  /// current profile via Rust backend.
  ///
  /// Returns all channels if user is admin
  /// (accessibleSources is null). Otherwise returns
  /// only channels from accessible sources.
  Future<List<Channel>> filterBySourceAccess(List<Channel> channels) async {
    try {
      final accessible = await ref.read(accessibleSourcesProvider.future);
      final isAdmin = accessible == null;

      final backend = ref.read(crispyBackendProvider);
      final channelsJson = jsonEncode(channels.map(channelToMap).toList());
      final sourceIdsJson = jsonEncode(accessible ?? <String>[]);

      final resultJson = await backend.filterChannelsBySource(
        channelsJson,
        sourceIdsJson,
        isAdmin,
      );

      final list = jsonDecode(resultJson) as List<dynamic>;
      return list.map((m) => mapToChannel(m as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint(
        'PlaylistSync: source access filter '
        'error: $e',
      );
      return channels;
    }
  }

  /// Loads cached channels + VODs + EPG into UI
  /// notifiers for instant display.
  ///
  /// Runs all three independent DB reads in parallel
  /// via [Future.wait] to cut startup time from the
  /// sum to the max of the three queries. Each load
  /// is wrapped in its own try-catch so a single
  /// failure doesn't block the other entities from
  /// loading.
  Future<void> loadFromCache() async {
    final sw = Stopwatch()..start();
    debugPrint('PlaylistSync: loading from cache…');
    final cache = ref.read(cacheServiceProvider);

    // Load each entity independently so partial
    // success is possible — a corrupt EPG table
    // shouldn't prevent channels from loading.
    List<Channel> cachedChannels = [];
    List<VodItem> cachedVods = [];
    final errors = <String>[];

    final channelSw = Stopwatch();
    final vodSw = Stopwatch();

    await Future.wait([
      () async {
        channelSw.start();
        try {
          cachedChannels = await cache.loadChannels();
        } catch (e) {
          errors.add('channels: $e');
        }
        channelSw.stop();
      }(),
      () async {
        vodSw.start();
        try {
          cachedVods = await cache.loadVodItems();
        } catch (e) {
          errors.add('vods: $e');
        }
        vodSw.stop();
      }(),
    ]);

    debugPrint(
      'PlaylistSync: cache read complete in '
      '${sw.elapsedMilliseconds}ms — '
      '${cachedChannels.length} channels '
      '(${channelSw.elapsedMilliseconds}ms), '
      '${cachedVods.length} VODs '
      '(${vodSw.elapsedMilliseconds}ms)',
    );

    if (errors.isNotEmpty) {
      debugPrint(
        'PlaylistSync: cache load errors: '
        '${errors.join('; ')}',
      );
    }

    // Filter channels by source access.
    try {
      cachedChannels = await filterBySourceAccess(cachedChannels);
    } catch (e) {
      debugPrint(
        'PlaylistSync: source access filter '
        'error: $e',
      );
    }

    if (cachedChannels.isNotEmpty) {
      final groups = extractSortedGroups(cachedChannels);
      ref
          .read(channelListProvider.notifier)
          .loadChannels(cachedChannels, groups);
      syncSourceNames();
    }

    if (cachedVods.isNotEmpty) {
      if (ref.exists(vodProvider)) {
        ref.read(vodProvider.notifier).loadData(cachedVods);
        // Re-apply profile-scoped favorites — the DB column
        // may be stale from a prior playlist sync.
        final favIds = ref.read(vodFavoritesProvider).value;
        if (favIds != null && favIds.isNotEmpty) {
          ref.read(vodProvider.notifier).applyFavorites(favIds);
        }
      }
    }

    if (cachedChannels.isNotEmpty) {
      // Set channels + overrides without wiping
      // any existing EPG entries.
      final overrides =
          ref.read(settingsNotifierProvider).value?.epgOverrides ?? {};
      final notifier = ref.read(epgProvider.notifier);
      notifier.updateChannels(
        channels: cachedChannels,
        epgOverrides: overrides,
      );

      // Auto-fetch the initial day window.
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      notifier.fetchEpgWindow(start, end);
    }

    sw.stop();
    debugPrint(
      'PlaylistSync: cache → UI complete in '
      '${sw.elapsedMilliseconds}ms',
    );
  }

  /// Reloads channels from repository into the UI
  /// notifier.
  ///
  /// Applies source access filtering based on the
  /// current profile's permissions.
  Future<void> reloadChannelList() async {
    final repo = ref.read(channelRepositoryProvider);
    var channels = await repo.getChannels();

    // Filter by source access.
    channels = await filterBySourceAccess(channels);

    // Recompute groups from filtered channels.
    final groups = extractSortedGroups(channels);

    ref.read(channelListProvider.notifier).loadChannels(channels, groups);
    syncSourceNames();

    // Detect duplicate channels after loading.
    await detectDuplicates(channels);
  }

  /// Syncs playlist source names to the channel list
  /// provider.
  void syncSourceNames() {
    final settings = ref.read(settingsNotifierProvider).value;
    if (settings == null) return;
    final names = <String, String>{};
    for (final source in settings.sources) {
      names[source.id] = source.name;
    }
    ref.read(channelListProvider.notifier).setSourceNames(names);
  }

  /// Detects duplicate channels and updates state.
  Future<void> detectDuplicates(List<Channel> channels) async {
    final service = ref.read(duplicateDetectionServiceProvider);
    final groups = await service.detectDuplicates(channels);

    // Update the global duplicate groups provider.
    ref.read(duplicateGroupsProvider.notifier).setGroups(groups);

    // Update channel list with duplicate IDs for
    // filtering.
    final duplicateIds = await service.getDuplicateIds(groups);
    ref.read(channelListProvider.notifier).setDuplicateIds(duplicateIds);
  }

  /// Removes items from DB and in-memory store that
  /// existed for [source] but are no longer in the
  /// fresh response.
  Future<void> cleanupStaleItems({
    required PlaylistSource source,
    required Set<String> freshChannelIds,
    required Set<String> freshVodIds,
  }) async {
    try {
      final cache = ref.read(cacheServiceProvider);

      // 1. Clean channels from DB.
      final deletedChannels = await cache.deleteRemovedChannels(
        source.id,
        freshChannelIds,
      );

      // 2. Clean channels from in-memory store.
      final datasource = ref.read(channelDatasourceProvider);
      datasource.removeStaleBySource(source.id, freshChannelIds);

      // 3. Clean VOD items from DB.
      final deletedVod = await cache.deleteRemovedVodItems(
        source.id,
        freshVodIds,
      );

      if (deletedChannels > 0 || deletedVod > 0) {
        debugPrint(
          'PlaylistSync: cleanup ${source.name} '
          '— removed $deletedChannels channels, '
          '$deletedVod VOD items',
        );
      }
    } catch (e) {
      debugPrint(
        'PlaylistSync: cleanup error for '
        '${source.name}: $e',
      );
    }
  }

  /// Auto-populates a source's EPG URL from
  /// discovered M3U header or Xtream convention.
  Future<void> autoSaveEpgUrl(PlaylistSource source, String epgUrl) async {
    try {
      final notifier = ref.read(settingsNotifierProvider.notifier);
      final updatedSource = source.copyWith(epgUrl: epgUrl);
      await notifier.updateSource(updatedSource);

      debugPrint(
        'PlaylistSync: auto-saved EPG URL for '
        '${source.name}: $epgUrl',
      );
    } catch (e) {
      debugPrint(
        'PlaylistSync: failed to auto-save EPG '
        'URL: $e',
      );
    }
  }
}
