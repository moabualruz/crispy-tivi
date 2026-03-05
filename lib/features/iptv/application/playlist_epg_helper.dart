import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/settings_notifier.dart';
import '../../../core/data/cache_service.dart';
import '../../epg/presentation/providers/epg_providers.dart';
import '../../../core/domain/entities/playlist_source.dart';
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
  Future<void> fetchEpg() async {
    try {
      final settings = ref.read(settingsNotifierProvider).value;
      if (settings == null) return;

      // Collect all EPG URLs from sources.
      final epgUrls = <String>{};
      for (final source in settings.sources) {
        final url = source.epgUrl;
        if (url != null && url.isNotEmpty) {
          epgUrls.add(url);
        }
      }

      final hasXtreamOrStalker = settings.sources.any(
        (s) =>
            s.type == PlaylistSourceType.xtream ||
            s.type == PlaylistSourceType.stalkerPortal,
      );

      if (epgUrls.isEmpty && !hasXtreamOrStalker) {
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
      final cache = ref.read(cacheServiceProvider);
      final channels = await cache.loadChannels();
      final channelsJson = jsonEncode(channels.map(channelToMap).toList());

      // Pass 1: XMLTV EPG Sync (Full async backend operation)
      for (final url in epgUrls) {
        try {
          debugPrint('PlaylistSync: syncing XMLTV from $url via Rust backend');
          final inserted = await backend.syncXmltvEpg(url: url);
          debugPrint('PlaylistSync: Rust synced $inserted XMLTV combinations');
        } catch (e) {
          debugPrint('PlaylistSync: XMLTV EPG sync failed for $url: $e');
        }
      }

      // Pass 2: Xtream short EPG for unfilled.
      await _fetchShortEpgForMissing(
        sources: settings.sources,
        channelsJson: channelsJson,
      );

      // Pass 3: Stalker short EPG for unfilled.
      await _fetchShortEpgForStalkerMissing(
        sources: settings.sources,
        channelsJson: channelsJson,
      );

      // Rust has persisted everything to DB. Refresh
      // the UI's current day window without wiping
      // existing entries (avoids blank-screen flash).
      debugPrint('PlaylistSync: EPG sync complete, refreshing UI window...');

      final overrides =
          ref.read(settingsNotifierProvider).value?.epgOverrides ?? {};
      final notifier = ref.read(epgProvider.notifier);

      // Update channels + overrides, keep entries.
      notifier.updateChannels(channels: channels, epgOverrides: overrides);

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

  /// Delegates to Rust to fetch Xtream short EPGs for Live Channels.
  Future<void> _fetchShortEpgForMissing({
    required List<PlaylistSource> sources,
    required String channelsJson,
  }) async {
    try {
      PlaylistSource? xtreamSource;
      for (final source in sources) {
        if (source.username != null && source.password != null) {
          xtreamSource = source;
          break;
        }
      }
      if (xtreamSource == null) return;

      debugPrint('PlaylistSync: Triggering Xtream short EPG fetch via Rust');
      final backend = ref.read(crispyBackendProvider);

      final inserted = await backend.syncXtreamEpg(
        baseUrl: xtreamSource.url,
        username: xtreamSource.username!,
        password: xtreamSource.password!,
        channelsJson: channelsJson,
      );
      debugPrint('PlaylistSync: Xtream short EPG inserted $inserted mappings.');
    } catch (e) {
      debugPrint('PlaylistSync: short EPG batch error: $e');
    }
  }

  /// Delegates to Rust to fetch Stalker short EPGs for Live Channels.
  Future<void> _fetchShortEpgForStalkerMissing({
    required List<PlaylistSource> sources,
    required String channelsJson,
  }) async {
    try {
      PlaylistSource? stalkerSource;
      for (final source in sources) {
        if (source.type == PlaylistSourceType.stalkerPortal &&
            source.macAddress != null &&
            source.macAddress!.isNotEmpty) {
          stalkerSource = source;
          break;
        }
      }
      if (stalkerSource == null) return;

      debugPrint('PlaylistSync: Triggering Stalker short EPG fetch via Rust');
      final backend = ref.read(crispyBackendProvider);

      final inserted = await backend.syncStalkerEpg(
        baseUrl: stalkerSource.url,
        channelsJson: channelsJson,
      );
      debugPrint(
        'PlaylistSync: Stalker short EPG inserted $inserted mappings.',
      );
    } catch (e) {
      debugPrint('PlaylistSync: stalker short EPG batch error: $e');
    }
  }
}
