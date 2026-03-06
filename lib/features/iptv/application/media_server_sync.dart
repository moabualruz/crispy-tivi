import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/data/cache_service.dart';
import '../../../core/data/crispy_backend.dart';
import '../../../core/domain/entities/media_item.dart';
import '../../../core/domain/entities/media_type.dart';
import '../../../core/domain/entities/playlist_source.dart';
import '../../../core/domain/media_source.dart';
import '../../media_servers/plex/data/datasources/plex_api_client.dart';
import '../../media_servers/plex/domain/plex_source.dart';
import '../../media_servers/shared/data/media_server_api_client.dart';
import '../../media_servers/shared/data/media_server_source.dart';
import '../../media_servers/shared/utils/media_item_vod_adapter.dart';
import '../../media_servers/shared/utils/media_server_auth.dart';
import '../../vod/domain/entities/vod_item.dart';
import 'playlist_sync_service.dart';

/// Syncs media server (Plex/Emby/Jellyfin) libraries into the
/// unified Rust VOD database.
///
/// Fetches library items via Dart HTTP clients, maps them to
/// [VodItem]s, and persists via [CrispyBackend.saveVodItems].
class MediaServerSyncService {
  MediaServerSyncService(this._ref);
  final Ref _ref;

  /// Syncs a single media server source and returns a [SyncReport].
  Future<SyncReport> syncSource(PlaylistSource source) async {
    return switch (source.type) {
      PlaylistSourceType.plex => _syncPlex(source),
      PlaylistSourceType.emby ||
      PlaylistSourceType.jellyfin => _syncEmbyJellyfin(source),
      _ => throw ArgumentError('Not a media server: ${source.type}'),
    };
  }

  /// Syncs an Emby or Jellyfin source.
  Future<SyncReport> _syncEmbyJellyfin(PlaylistSource source) async {
    if (source.userId == null) {
      debugPrint('MediaServerSync: ${source.name} — no userId, skip');
      return const SyncReport();
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: source.url,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    try {
      if (source.accessToken != null) {
        dio.options.headers['X-Emby-Token'] = source.accessToken;
      }
      dio.options.headers['X-Emby-Authorization'] = embyAuthHeader(
        source.deviceId,
      );

      final server = MediaServerSource(
        apiClient: MediaServerApiClient(dio, baseUrl: source.url),
        serverUrl: source.url,
        userId: source.userId!,
        deviceId: source.deviceId ?? kDefaultDeviceId,
        serverName: source.name,
        serverId: source.id,
        accessToken: source.accessToken ?? '',
        type:
            source.type == PlaylistSourceType.emby
                ? MediaServerType.emby
                : MediaServerType.jellyfin,
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
        buildStreamUrl:
            (itemId) => '${source.type.name}://${source.id}/$itemId',
        idPrefix: source.type == PlaylistSourceType.emby ? 'emby' : 'jf',
      );
    } finally {
      dio.close();
    }
  }

  /// Syncs a Plex source.
  Future<SyncReport> _syncPlex(PlaylistSource source) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
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
    final backend = _ref.read(crispyBackendProvider);
    final cache = _ref.read(cacheServiceProvider);

    // 1. Fetch root libraries.
    final libraries = await fetchLibraries();
    final vodLibraries = libraries.where((lib) => lib.type == MediaType.folder);

    final allVodItems = <VodItem>[];
    final allCategories = <String>[];

    // 2. For each library, paginate all items.
    for (final library in vodLibraries) {
      final category = '${source.name} > ${library.name}';
      allCategories.add(category);

      var startIndex = 0;
      var hasMore = true;

      while (hasMore) {
        final page = await fetchPage(library.id, startIndex);

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

    // 3. Persist to Rust DB.
    if (allVodItems.isNotEmpty) {
      await cache.saveVodItems(allVodItems);
    }

    // 4. Clean up items no longer on server.
    final keepIds = allVodItems.map((v) => v.id).toSet();
    await backend.deleteRemovedVodItems(source.id, keepIds.toList());

    // 5. Save categories.
    if (allCategories.isNotEmpty) {
      // Merge with existing categories (don't overwrite IPTV ones).
      final existing = await cache.loadCategories();
      final vodCats = existing['vod'] ?? [];
      final merged = {...vodCats, ...allCategories}.toList();
      await cache.saveCategories({'vod': merged});
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
}
