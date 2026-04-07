import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/domain/entities/playlist_source.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import 'iptv_service_providers.dart';
import 'playlist_sync_service.dart';

/// EPG fetch and matching helpers for
/// [PlaylistSyncService].
///
/// Extracted to keep the main service file under
/// 500 lines.
mixin PlaylistEpgHelper {
  /// Riverpod ref for reading providers.
  Ref get ref;

  /// Fetches and parses EPG data from all sources'
  /// EPG URLs by directly commanding the Rust backend.
  ///
  /// Rust performs downloading, parsing, mapping, and
  /// directly persisting right into the SQLite database.
  Future<void> fetchEpg({bool force = false}) async {
    try {
      final settings = ref.read(settingsNotifierProvider).value;
      if (settings == null) return;

      // Collect all EPG URLs and their primary source IDs.
      final epgSourceMap = <String, String>{};
      for (final source in settings.sources) {
        final url = source.epgUrl;
        if (url != null && url.isNotEmpty) {
          // Use the first source ID that references this URL.
          epgSourceMap.putIfAbsent(url, () => source.id);
        }
      }

      final hasXtreamOrStalker = settings.sources.any(
        (s) =>
            s.type == PlaylistSourceType.xtream ||
            s.type == PlaylistSourceType.stalkerPortal,
      );

      if (epgSourceMap.isEmpty && !hasXtreamOrStalker) {
        debugPrint(
          'PlaylistSync: no EPG URLs or compatible sources configured',
        );
        ref
            .read(epgProvider.notifier)
            .setFetchResult('No EPG sources configured', success: false);
        return;
      }

      // Signal loading start.
      ref.read(epgProvider.notifier).setLoading();

      final backend = ref.read(crispyBackendProvider);

      // Pass 1: XMLTV EPG Sync (Full async backend operation)
      for (final entry in epgSourceMap.entries) {
        try {
          debugPrint(
            'PlaylistSync: syncing XMLTV from ${entry.key} for source ${entry.value}',
          );
          final inserted = await backend.syncXmltvEpg(
            url: entry.key,
            sourceId: entry.value,
            force: force,
          );
          debugPrint('PlaylistSync: Rust synced $inserted XMLTV combinations');
        } catch (e) {
          debugPrint(
            'PlaylistSync: XMLTV EPG sync failed for ${entry.key}: $e',
          );
        }
      }

      // Pass 2: Xtream short EPG for unfilled.
      await _fetchAllXtreamEpg(sources: settings.sources, force: force);

      // Pass 3: Stalker short EPG for unfilled.
      await _fetchAllStalkerEpg(
        sources: settings.sources,
        force: force,
      );

      // Rust has persisted everything to DB. Refresh
      // the UI's current day window without wiping
      // existing entries (avoids blank-screen flash).
      debugPrint('PlaylistSync: EPG sync complete, refreshing UI window...');

      final overrides =
          ref.read(settingsNotifierProvider).value?.epgOverrides ?? {};
      final notifier = ref.read(epgProvider.notifier);

      final currentChannels = ref.read(epgProvider).channels;
      if (currentChannels.isNotEmpty) {
        // Update channels + overrides, keep entries.
        notifier.updateChannels(
          channels: currentChannels,
          epgOverrides: overrides,
        );
      }

      // Merge today's window from DB into existing
      // entries (additive, no wipe).
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      await notifier.fetchEpgWindow(start, end);

      notifier.setFetchResult('EPG sync complete and timeline refreshed');
    } catch (e) {
      debugPrint('PlaylistSync: EPG pipeline error: $e');
      ref
          .read(epgProvider.notifier)
          .setFetchResult('EPG fetch failed: $e', success: false);
    }
  }

  /// Delegates to Rust to fetch Xtream full EPGs (via xmltv.php).
  Future<void> _fetchAllXtreamEpg({
    required List<PlaylistSource> sources,
    required bool force,
  }) async {
    final xtreamSources = sources.where(
      (s) => s.type == PlaylistSourceType.xtream,
    );
    if (xtreamSources.isEmpty) return;

    final backend = ref.read(crispyBackendProvider);
    for (final src in xtreamSources) {
      if (src.username != null && src.password != null) {
        try {
          debugPrint('PlaylistSync: syncing Xtream EPG for source ${src.id}');
          final inserted = await backend.syncXtreamEpg(
            baseUrl: src.url,
            username: src.username!,
            password: src.password!,
            sourceId: src.id,
            channelsJson: '[]', // Unused in Rust backend for Xtream.
            force: force,
          );
          debugPrint('PlaylistSync: Xtream sync inserted $inserted entries.');
        } catch (e) {
          debugPrint('PlaylistSync: Xtream EPG sync error for ${src.id}: $e');
        }
      }
    }
  }

  /// Delegates to Rust to fetch Stalker short EPGs for Live Channels.
  Future<void> _fetchAllStalkerEpg({
    required List<PlaylistSource> sources,
    required bool force,
  }) async {
    final stalkerSources = sources.where(
      (s) => s.type == PlaylistSourceType.stalkerPortal,
    );
    if (stalkerSources.isEmpty) return;

    final backend = ref.read(crispyBackendProvider);
    final cache = ref.read(cacheServiceProvider);
    for (final src in stalkerSources) {
      if (src.macAddress != null && src.macAddress!.isNotEmpty) {
        try {
          debugPrint('PlaylistSync: syncing Stalker EPG for source ${src.id}');
          final sourceChannels = await cache.getChannelsBySources([src.id]);
          if (sourceChannels.isEmpty) continue;

          final inserted = await backend.syncStalkerEpg(
            baseUrl: src.url,
            mac: src.macAddress!,
            sourceId: src.id,
            channelsJson: encodeChannelsJson(sourceChannels),
            force: force,
          );
          debugPrint('PlaylistSync: Stalker sync inserted $inserted entries.');
        } catch (e) {
          debugPrint('PlaylistSync: Stalker EPG sync error for ${src.id}: $e');
        }
      }
    }
  }
}
