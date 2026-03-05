import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/constants.dart';
import 'package:crispy_tivi/core/domain/entities/media_item.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/core/domain/media_source.dart';
import 'package:crispy_tivi/core/exceptions/media_source_exception.dart';
import 'package:crispy_tivi/features/media_servers/shared/data/media_server_api_client.dart';
import 'package:crispy_tivi/features/media_servers/shared/data/media_server_source.dart';
import 'package:crispy_tivi/features/media_servers/shared/utils/media_server_auth.dart';

// ── MSB-FE-07: Cross-server resume item type ──────────────────────────

/// A resume item annotated with which server it came from.
///
/// Used by [allServersResumeItemsProvider] to merge results from
/// multiple Jellyfin/Emby/Plex servers into a single sorted list.
class ServerResumeItem {
  const ServerResumeItem({required this.item, required this.server});

  /// The in-progress media item.
  final MediaItem item;

  /// The [PlaylistSource] this item belongs to.
  final PlaylistSource server;
}

// ── Internal factory helpers ───────────────────────────────────────────

/// Constructs a [MediaServerSource] from a [PlaylistSource] config.
MediaServerSource _buildMediaServerSource(PlaylistSource config) {
  final dio = Dio(BaseOptions(baseUrl: config.url));
  if (config.accessToken != null) {
    dio.options.headers['X-Emby-Token'] = config.accessToken;
  }
  dio.options.headers['X-Emby-Authorization'] = embyAuthHeader(config.deviceId);

  return MediaServerSource(
    apiClient: MediaServerApiClient(dio, baseUrl: config.url),
    serverUrl: config.url,
    userId: config.userId!,
    deviceId: config.deviceId ?? kDefaultDeviceId,
    serverName: config.name,
    serverId: config.id,
    accessToken: config.accessToken ?? '',
    type: toServerType(config.type),
  );
}

// ── Saved server list ──────────────────────────────────────────────────

/// Filtered list of saved media server sources (Jellyfin, Emby, Plex).
///
/// Derived from [settingsNotifierProvider]. Returns an empty list while
/// settings are loading or on error.
final savedMediaServersProvider = Provider<List<PlaylistSource>>((ref) {
  final settings = ref.watch(settingsNotifierProvider).asData?.value;
  if (settings == null) return [];
  return settings.sources
      .where(
        (s) =>
            s.type == PlaylistSourceType.jellyfin ||
            s.type == PlaylistSourceType.emby ||
            s.type == PlaylistSourceType.plex,
      )
      .toList();
});

// ── Generic provider family ────────────────────────────────────────────

/// Provider for the active [MediaSource] of the given [PlaylistSourceType].
///
/// Supports [PlaylistSourceType.emby] and [PlaylistSourceType.jellyfin].
/// Returns `null` when no matching source is configured or on error.
final mediaServerSourceProvider =
    Provider.family<MediaSource?, PlaylistSourceType>((ref, type) {
      final settings = ref.watch(settingsNotifierProvider).asData?.value;
      if (settings == null) return null;

      try {
        final config = settings.sources.firstWhere((s) => s.type == type);
        return switch (type) {
          PlaylistSourceType.emby ||
          PlaylistSourceType.jellyfin => _buildMediaServerSource(config),
          _ => null,
        };
      } catch (_) {
        return null;
      }
    });

/// Fetches root libraries (user views) for the given server type.
final mediaServerLibrariesProvider =
    FutureProvider.family<List<MediaItem>, PlaylistSourceType>((
      ref,
      type,
    ) async {
      final source = ref.watch(mediaServerSourceProvider(type));
      if (source == null) return [];
      return source.getLibrary(null);
    });

/// Fetches items within a folder for the given server type.
///
/// The family parameter combines [PlaylistSourceType] and `parentId`
/// via a [MediaServerLibraryQuery].
final mediaServerItemsProvider =
    FutureProvider.family<List<MediaItem>, MediaServerLibraryQuery>((
      ref,
      query,
    ) async {
      final source = ref.watch(mediaServerSourceProvider(query.type));
      if (source == null) return [];
      return source.getLibrary(query.parentId);
    });

/// Resolves the playback URL for an item from the given server type.
///
/// The family parameter is a [MediaServerStreamQuery].
final mediaServerStreamUrlProvider =
    FutureProvider.family<String, MediaServerStreamQuery>((ref, query) async {
      final source = ref.read(mediaServerSourceProvider(query.type));
      if (source == null) {
        throw MediaSourceException.server(
          message: 'No ${query.type.name} source connected',
        );
      }
      return source.getStreamUrl(query.itemId);
    });

/// Paginated library items for the given server type and parent folder.
final mediaServerPaginatedItemsProvider = FutureProvider.autoDispose
    .family<PaginatedResult<MediaItem>, MediaServerLibraryQuery>((
      ref,
      query,
    ) async {
      final source = ref.watch(mediaServerSourceProvider(query.type));
      if (source == null) return PaginatedResult.empty();
      if (source is MediaServerSource) {
        return source.getLibraryPaginated(
          query.parentId,
          startIndex: 0,
          limit: kMediaServerPageSize,
        );
      }
      // Fallback: wrap non-paginated result
      final items = await source.getLibrary(query.parentId);
      return PaginatedResult(items: items, totalCount: items.length);
    });

// ── Query value types ─────────────────────────────────────────────────

/// Query key for [mediaServerItemsProvider] and
/// [mediaServerPaginatedItemsProvider].
class MediaServerLibraryQuery {
  const MediaServerLibraryQuery({required this.type, required this.parentId});

  final PlaylistSourceType type;
  final String parentId;

  @override
  bool operator ==(Object other) =>
      other is MediaServerLibraryQuery &&
      type == other.type &&
      parentId == other.parentId;

  @override
  int get hashCode => Object.hash(type, parentId);
}

/// Query key for [mediaServerStreamUrlProvider].
class MediaServerStreamQuery {
  const MediaServerStreamQuery({required this.type, required this.itemId});

  final PlaylistSourceType type;
  final String itemId;

  @override
  bool operator ==(Object other) =>
      other is MediaServerStreamQuery &&
      type == other.type &&
      itemId == other.itemId;

  @override
  int get hashCode => Object.hash(type, itemId);
}

// ── MSB-FE-07: Unified "Continue Watching" across all servers ─────────

/// Fetches resume items from ALL configured Jellyfin/Emby/Plex servers
/// in parallel and merges them into a single list sorted by most recently
/// watched (using [MediaItem.playbackPositionMs] as a proxy when
/// last-watched timestamp is unavailable from the server model).
///
/// Results from each server are fetched concurrently with [Future.wait].
/// Failures from individual servers are swallowed so the row is never
/// blocked by a single unreachable server.
///
/// Each result is wrapped in [ServerResumeItem] so the UI can display
/// a server-type badge on each card.
final allServersResumeItemsProvider = FutureProvider<List<ServerResumeItem>>((
  ref,
) async {
  final servers = ref.watch(savedMediaServersProvider);
  if (servers.isEmpty) return [];

  // Build one task per server, in parallel.
  final futures = servers.map((server) async {
    try {
      // Only Jellyfin and Emby support the /Items/Resume endpoint.
      // Plex has a different API — skip it for now (TODO: Plex resume).
      if (server.type == PlaylistSourceType.plex) return <ServerResumeItem>[];
      if (server.userId == null) return <ServerResumeItem>[];

      final dio = Dio(
        BaseOptions(
          baseUrl: server.url,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      if (server.accessToken != null) {
        dio.options.headers['X-Emby-Token'] = server.accessToken;
      }

      final source = MediaServerSource(
        apiClient: MediaServerApiClient(dio, baseUrl: server.url),
        serverUrl: server.url,
        userId: server.userId!,
        deviceId: server.deviceId ?? kDefaultDeviceId,
        serverName: server.name,
        serverId: server.id,
        accessToken: server.accessToken ?? '',
        type:
            server.type == PlaylistSourceType.emby
                ? MediaServerType.emby
                : MediaServerType.jellyfin,
      );

      final items = await source.getResumeItems();
      return items
          .map((item) => ServerResumeItem(item: item, server: server))
          .toList();
    } catch (_) {
      // Individual server failures are ignored so other servers still show.
      return <ServerResumeItem>[];
    }
  });

  final results = await Future.wait(futures);
  final merged = results.expand((list) => list).toList();

  // Sort by descending playbackPositionMs (most recently played first).
  // Items with null position go to the end.
  merged.sort((a, b) {
    final aPos = a.item.playbackPositionMs ?? 0;
    final bPos = b.item.playbackPositionMs ?? 0;
    return bPos.compareTo(aPos);
  });

  return merged;
});
