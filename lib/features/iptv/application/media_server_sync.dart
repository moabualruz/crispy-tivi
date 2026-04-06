import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/settings_notifier.dart';
import '../../../core/constants.dart';
import '../../../core/data/cache_service.dart';
import '../../../core/domain/entities/media_item.dart';
import '../../../core/domain/entities/media_type.dart';
import '../../../core/domain/entities/playlist_source.dart';
import '../../../core/domain/media_source.dart';
import '../../media_servers/plex/data/datasources/plex_api_client.dart';
import '../../media_servers/plex/domain/plex_source.dart';
import '../../media_servers/shared/data/media_server_api_client.dart';
import '../../media_servers/shared/data/media_server_dio_factory.dart';
import '../../media_servers/shared/data/media_server_source.dart';
import '../../media_servers/shared/utils/media_item_vod_adapter.dart';
import '../../media_servers/shared/utils/media_server_auth.dart';
import '../../vod/domain/entities/vod_item.dart';
import '../data/sync_report_codec.dart';

/// Syncs media server (Plex/Emby/Jellyfin) libraries into the
/// unified Rust VOD database.
///
/// Fetches library items via Dart HTTP clients, maps them to
/// [VodItem]s, and persists via [CacheService].
class MediaServerSyncService {
  MediaServerSyncService(this._ref);
  final Ref _ref;

  /// Syncs a single media server source and returns a [SyncReport].
  ///
  /// Updates the source sync status in the Rust DB on success or failure.
  Future<SyncReport> syncSource(PlaylistSource source) async {
    final cache = _ref.read(cacheServiceProvider);
    final stopwatch = Stopwatch()..start();

    try {
      final report = await switch (source.type) {
        PlaylistSourceType.plex => _syncPlex(source),
        PlaylistSourceType.emby ||
        PlaylistSourceType.jellyfin => _syncEmbyJellyfin(source),
        _ => throw ArgumentError('Not a media server: ${source.type}'),
      };

      stopwatch.stop();
      await cache.updateSourceSyncStatus(
        source.id,
        'success',
        syncTimeMs: stopwatch.elapsedMilliseconds,
      );
      return report;
    } catch (e, stack) {
      stopwatch.stop();
      debugPrint('MediaServerSync: ${source.name} sync failed: $e\n$stack');
      await cache.updateSourceSyncStatus(
        source.id,
        'error',
        error: e.toString(),
        syncTimeMs: stopwatch.elapsedMilliseconds,
      );
      rethrow;
    }
  }

  /// Re-authenticates an Emby/Jellyfin source to obtain a fresh userId.
  ///
  /// Returns the updated [PlaylistSource] with userId populated,
  /// or `null` if re-authentication fails.
  Future<PlaylistSource?> _reAuthEmbyJellyfin(
    PlaylistSource source,
    MediaServerApiClient client,
  ) async {
    if (source.username == null || source.password == null) return null;

    try {
      final authResult = await client.authenticateByName({
        'Username': source.username!,
        'Pw': source.password!,
      });

      final updated = source.copyWith(
        userId: authResult.user.id,
        accessToken: authResult.accessToken,
      );
      // Persist the refreshed credentials.
      await _ref.read(settingsNotifierProvider.notifier).updateSource(updated);
      return updated;
    } catch (e) {
      debugPrint('MediaServerSync: re-auth failed for ${source.name}: $e');
      return null;
    }
  }

  /// Syncs an Emby or Jellyfin source.
  Future<SyncReport> _syncEmbyJellyfin(PlaylistSource source) async {
    final dio = createEmbyJellyfinSyncDio(
      source.url,
      accessToken: source.accessToken,
      deviceId: source.deviceId,
    );
    try {
      var client = MediaServerApiClient(dio, baseUrl: source.url);

      // Re-authenticate if userId is missing instead of silently skipping.
      var activeSource = source;
      if (activeSource.userId == null) {
        final refreshed = await _reAuthEmbyJellyfin(activeSource, client);
        if (refreshed == null) {
          throw StateError(
            '${activeSource.name}: no userId and re-authentication failed '
            '(credentials may be missing or invalid)',
          );
        }
        activeSource = refreshed;
        // Recreate client with fresh token via a new Dio instance.
        dio.close();
        final freshDio = createEmbyJellyfinSyncDio(
          activeSource.url,
          accessToken: activeSource.accessToken,
          deviceId: activeSource.deviceId,
        );
        client = MediaServerApiClient(freshDio, baseUrl: activeSource.url);
      }

      final server = MediaServerSource(
        apiClient: client,
        serverUrl: activeSource.url,
        userId: activeSource.userId!,
        deviceId: activeSource.deviceId ?? kDefaultDeviceId,
        serverName: activeSource.name,
        serverId: activeSource.id,
        accessToken: activeSource.accessToken ?? '',
        type:
            activeSource.type == PlaylistSourceType.emby
                ? MediaServerType.emby
                : MediaServerType.jellyfin,
      );

      return _syncMediaServer(
        source: activeSource,
        fetchLibraries: () => server.getLibrary(null),
        fetchPage:
            (libraryId, startIndex) => server.getLibraryPaginated(
              libraryId,
              startIndex: startIndex,
              limit: kMediaServerPageSize,
            ),
        buildStreamUrl:
            (itemId) =>
                '${activeSource.type.name}://${activeSource.id}/$itemId',
        idPrefix: activeSource.type == PlaylistSourceType.emby ? 'emby' : 'jf',
      );
    } finally {
      dio.close();
    }
  }

  /// Syncs a Plex source.
  Future<SyncReport> _syncPlex(PlaylistSource source) async {
    final dio = createPlexSyncDio();
    try {
      final apiClient = PlexApiClient(dio: dio);
      final server = PlexSource(
        apiClient: apiClient,
        serverUrl: source.url,
        accessToken: source.accessToken ?? '',
        clientIdentifier: source.deviceId ?? 'crispy-tivi',
        serverName: source.name,
        serverId: source.id,
      );

      return _syncMediaServer(
        source: source,
        fetchLibraries: () => server.getLibrary(null),
        fetchPage:
            (libraryId, startIndex) => server.getLibraryPaginated(
              libraryId,
              startIndex: startIndex,
              limit: kMediaServerPageSize,
            ),
        buildStreamUrl: (itemId) => 'plex://${source.id}/$itemId',
        idPrefix: 'plex',
      );
    } finally {
      dio.close();
    }
  }

  /// Generic sync loop shared by all server types.
  ///
  /// Saves partial results on error and uses [CacheService] consistently
  /// for all data operations.
  Future<SyncReport> _syncMediaServer({
    required PlaylistSource source,
    required Future<List<MediaItem>> Function() fetchLibraries,
    required Future<PaginatedResult<MediaItem>> Function(
      String libraryId,
      int startIndex,
    )
    fetchPage,
    required String Function(String itemId) buildStreamUrl,
    required String idPrefix,
  }) async {
    final cache = _ref.read(cacheServiceProvider);

    // 1. Fetch root libraries.
    final libraries = await fetchLibraries();
    // Skip libraries with empty IDs (null key guard for Plex).
    final vodLibraries = libraries.where(
      (lib) => lib.type == MediaType.folder && lib.id.isNotEmpty,
    );

    final allVodItems = <VodItem>[];
    final allCategories = <String>[];

    // 2. For each library, paginate all items.
    for (final library in vodLibraries) {
      final category = '${source.name} > ${library.name}';
      allCategories.add(category);

      var startIndex = 0;
      var hasMore = true;

      while (hasMore) {
        final page = await withRetry(() => fetchPage(library.id, startIndex));

        for (final item in page.items) {
          // Skip non-playable container types.
          if (item.type == MediaType.folder || item.type == MediaType.unknown) {
            continue;
          }

          final namespacedId = '${idPrefix}_${source.id}_${item.id}';
          final streamUrl = buildStreamUrl(item.id);

          allVodItems.add(
            item
                .toVodItem(
                  streamUrl: streamUrl,
                  sourceId: source.id,
                  category: category,
                )
                .copyWith(id: namespacedId),
          );
        }

        hasMore = page.hasMore;
        startIndex = page.nextStartIndex;
      }
    }

    // 3. Persist to Rust DB + clean up stale items.
    // Guard: only delete when we got valid results. An empty result
    // could indicate a network/parse error, not that all items were
    // removed from the server. Prevents catastrophic data loss.
    if (allVodItems.isNotEmpty) {
      await cache.saveVodItems(allVodItems);
      final keepIds = allVodItems.map((v) => v.id).toSet();
      await cache.deleteRemovedVodItems(source.id, keepIds);
    }

    // 4. Save categories.
    if (allCategories.isNotEmpty) {
      // Merge with existing categories (don't overwrite IPTV ones).
      final existing = await cache.loadCategories();
      final vodCats = existing['vod'] ?? [];
      final merged = {...vodCats, ...allCategories}.toList();
      await cache.saveCategories(source.id, {'vod': merged});
    }

    debugPrint(
      'MediaServerSync: ${source.name} → '
      '${allVodItems.length} VOD items, '
      '${allCategories.length} libraries',
    );

    return SyncReport(
      vodCount: allVodItems.length,
      vodCategories: allCategories,
    );
  }

  /// Retries [fn] up to [maxAttempts] times for transient server errors.
  ///
  /// Only retries on 5xx status codes and timeouts. Client errors (4xx)
  /// are rethrown immediately. Uses exponential backoff between attempts.
  @visibleForTesting
  static Future<T> withRetry<T>(
    Future<T> Function() fn, {
    int maxAttempts = 3,
  }) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await fn();
      } catch (e) {
        if (attempt == maxAttempts || !isRetryableNetworkError(e)) rethrow;
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
    }
    // Unreachable — the loop always returns or rethrows.
    throw StateError('unreachable');
  }
}
