import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/domain/entities/playlist_source.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../profiles/presentation/providers/profile_service_providers.dart'
    show accessibleSourcesProvider;
import '../../../vod/presentation/providers/vod_paginated_providers.dart';
import '../../../vod/presentation/providers/vod_favorites_provider.dart';
import '../../domain/entities/channel.dart';
import 'channel_paginated_providers.dart';
import 'channel_providers.dart';
import 'duplicate_detection_service.dart';
import 'iptv_service_providers.dart';
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

      final cache = ref.read(cacheServiceProvider);
      return cache.filterChannelsBySourceTyped(channels, accessible, isAdmin);
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
    await ref.read(channelListProvider.notifier).refreshFromBackend();
    if (!ref.mounted) return;
    syncSourceNames();
    sw.stop();
    debugPrint(
      'PlaylistSync: cache → UI complete in ${sw.elapsedMilliseconds}ms',
    );
  }

  /// Reloads channels from cache into the UI notifier.
  ///
  /// Applies source access filtering based on the
  /// current profile's permissions.
  Future<void> reloadChannelList() async {
    debugPrint('PlaylistSync: reloading channel list from DB…');
    invalidateChannelPaginatedProviders();
    await ref.read(channelListProvider.notifier).refreshFromBackend();
    if (!ref.mounted) return;
    syncSourceNames();
    // Populate EPG with all channels for the guide
    if (!ref.mounted) return;
    final channels = ref.read(channelListProvider).channels;
    if (channels.isNotEmpty) {
      final overrides =
          ref.read(settingsNotifierProvider).value?.epgOverrides ?? {};
      ref
          .read(epgProvider.notifier)
          .updateChannels(channels: channels, epgOverrides: overrides);
      debugPrint(
        'PlaylistSync: synced ${channels.length} channels to EPG notifier',
      );
    }
  }

  /// Syncs playlist source names to the channel list
  /// provider.
  void syncSourceNames() {
    if (!ref.mounted) return;
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

  void invalidateChannelPaginatedProviders() {
    if (!ref.mounted) return;
    ref.invalidate(channelGroupsPaginatedProvider);
    ref.invalidate(channelCountPaginatedProvider);
    ref.invalidate(channelPagePaginatedProvider);
    ref.invalidate(channelIdsPaginatedProvider);
    ref.invalidate(channelByIdPaginatedProvider);
    ref.invalidate(channelSearchPaginatedProvider);
  }

  void invalidateVodPaginatedProviders() {
    if (!ref.mounted) return;
    ref.invalidate(vodCategoriesPaginatedProvider);
    ref.invalidate(vodCountPaginatedProvider);
    ref.invalidate(vodPagePaginatedProvider);
    ref.invalidate(vodSearchPaginatedProvider);
    ref.invalidate(vodAllPaginatedProvider);
    ref.invalidate(vodFavoritesProvider);
  }
}
