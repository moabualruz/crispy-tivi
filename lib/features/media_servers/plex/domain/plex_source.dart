import 'package:crispy_tivi/core/constants.dart';
import 'package:crispy_tivi/core/domain/entities/media_item.dart';
import 'package:crispy_tivi/core/domain/entities/media_type.dart';
import 'package:crispy_tivi/core/domain/media_source.dart';
import 'package:crispy_tivi/core/exceptions/media_source_exception.dart';
import 'package:crispy_tivi/core/failures/failure.dart';
import 'package:crispy_tivi/features/media_servers/shared/utils/dio_error_utils.dart';

import '../data/datasources/plex_api_client.dart';
import '../data/models/plex_metadata.dart';
import 'entities/plex_server.dart';

/// Implementation of [MediaSource] for a Plex server.
class PlexSource implements MediaSource {
  PlexSource({
    required this.apiClient,
    required this.serverUrl,
    required this.accessToken,
    required this.clientIdentifier,
    required this.serverName,
    required this.serverId,
  });

  /// The Plex API client.
  final PlexApiClient apiClient;

  final String serverUrl;
  final String accessToken;
  final String clientIdentifier;
  final String serverName;
  final String serverId;

  @override
  String get id => serverId;

  @override
  String get displayName => serverName;

  @override
  MediaServerType get type => MediaServerType.plex;

  PlexServer get _server => PlexServer(
    url: serverUrl,
    name: serverName,
    accessToken: accessToken,
    clientIdentifier: clientIdentifier,
  );

  /// Returns library sections or items.
  /// If [parentId] is null, fetches libraries.
  /// If [parentId] is provided, fetches items in that library.
  @override
  Future<List<MediaItem>> getLibrary(
    String? parentId, {
    int? startIndex,
    int? limit,
  }) async {
    try {
      if (parentId == null) {
        // Fetch libraries
        final libraries = await apiClient.getLibraries(_server);
        return libraries.map((lib) {
          return MediaItem(
            id: lib.key ?? '',
            name: lib.title ?? 'Unknown',
            type: MediaType.folder,
            parentId: null,
          );
        }).toList();
      } else {
        // Fetch items in library
        final items = await apiClient.getItems(_server, libraryId: parentId);
        return items.map(_mapToMediaItem).toList();
      }
    } on AuthFailure catch (e) {
      throw MediaSourceException.auth(message: e.message, cause: e);
    } on ServerFailure catch (e) {
      throw MediaSourceException.server(message: e.message, cause: e);
    } catch (e) {
      if (e is MediaSourceException) rethrow;
      throw toMediaSourceException(e, 'Plex');
    }
  }

  /// Fetches library items with pagination metadata.
  ///
  /// Returns a [PaginatedResult] containing items and total count
  /// for infinite scroll support.
  Future<PaginatedResult<MediaItem>> getLibraryPaginated(
    String? parentId, {
    int startIndex = 0,
    int limit = kMediaServerPageSize,
  }) async {
    try {
      if (parentId == null) {
        // Libraries - no pagination needed
        final libraries = await apiClient.getLibraries(_server);
        final items =
            libraries.map((lib) {
              return MediaItem(
                id: lib.key ?? '',
                name: lib.title ?? 'Unknown',
                type: MediaType.folder,
                parentId: null,
              );
            }).toList();
        return PaginatedResult(
          items: items,
          totalCount: items.length,
          startIndex: 0,
        );
      } else {
        // Fetch items in library with pagination
        final result = await apiClient.getItemsPaginated(
          _server,
          libraryId: parentId,
          start: startIndex,
          size: limit,
        );
        return PaginatedResult(
          items: result.items.map(_mapToMediaItem).toList(),
          totalCount: result.totalCount,
          startIndex: result.startIndex,
          limit: limit,
        );
      }
    } on AuthFailure catch (e) {
      throw MediaSourceException.auth(message: e.message, cause: e);
    } on ServerFailure catch (e) {
      throw MediaSourceException.server(message: e.message, cause: e);
    } catch (e) {
      if (e is MediaSourceException) rethrow;
      throw toMediaSourceException(e, 'Plex');
    }
  }

  /// Fetch children of an item with pagination.
  ///
  /// Returns seasons of a show or episodes of a season.
  Future<PaginatedResult<MediaItem>> getChildrenPaginated(
    String itemId, {
    int startIndex = 0,
    int limit = kMediaServerPageSize,
  }) async {
    try {
      final result = await apiClient.getChildrenPaginated(
        _server,
        itemId: itemId,
        start: startIndex,
        size: limit,
      );
      return PaginatedResult(
        items: result.items.map(_mapToMediaItem).toList(),
        totalCount: result.totalCount,
        startIndex: result.startIndex,
        limit: limit,
      );
    } on AuthFailure catch (e) {
      throw MediaSourceException.auth(message: e.message, cause: e);
    } on ServerFailure catch (e) {
      throw MediaSourceException.server(message: e.message, cause: e);
    } catch (e) {
      if (e is MediaSourceException) rethrow;
      throw toMediaSourceException(e, 'Plex');
    }
  }

  /// [PX-FE-08] Fetches library items with pagination and optional filter/sort
  /// query parameters.
  ///
  /// Merges [queryParams] (from [PlexLibraryFilterState.toQueryParams]) into
  /// the Plex API request so sort/filter are applied server-side.
  /// Falls back to [getLibraryPaginated] when [queryParams] is null or empty.
  Future<PaginatedResult<MediaItem>> getLibraryPaginatedFiltered(
    String parentId, {
    int startIndex = 0,
    int limit = kMediaServerPageSize,
    Map<String, String>? queryParams,
  }) async {
    if (queryParams == null || queryParams.isEmpty) {
      return getLibraryPaginated(
        parentId,
        startIndex: startIndex,
        limit: limit,
      );
    }

    try {
      final endpoint = '$serverUrl/library/sections/$parentId/all';

      final combined = <String, dynamic>{
        'X-Plex-Container-Start': startIndex,
        'X-Plex-Container-Size': limit,
        ...queryParams,
      };

      final rawResult = await apiClient.getRawJson(
        endpoint,
        token: accessToken,
        clientId: clientIdentifier,
        queryParams: combined,
      );

      final container = rawResult['MediaContainer'] as Map<String, dynamic>?;
      if (container == null) return PaginatedResult.empty();

      final rawItems = container['Metadata'] as List<dynamic>? ?? [];
      final totalSize =
          (container['totalSize'] as int?) ??
          (container['size'] as int?) ??
          rawItems.length;
      final offset = (container['offset'] as int?) ?? startIndex;

      final items =
          rawItems.cast<Map<String, dynamic>>().map((m) {
            final thumbPath = m['thumb'] as String?;
            final artPath = m['art'] as String?;
            final thumbUrl =
                thumbPath != null
                    ? '$serverUrl$thumbPath?X-Plex-Token=$accessToken'
                    : null;
            final backdropUrl =
                artPath != null
                    ? '$serverUrl$artPath?X-Plex-Token=$accessToken'
                    : null;
            return MediaItem(
              id: (m['ratingKey'] ?? '').toString(),
              name: (m['title'] as String?) ?? 'Unknown',
              type: _mapType(m['type'] as String?),
              logoUrl: thumbUrl,
              overview: m['summary'] as String?,
              durationMs: m['duration'] as int?,
              playbackPositionMs: m['viewOffset'] as int?,
              isWatched: ((m['viewCount'] as int?) ?? 0) > 0,
              rating: m['contentRating'] as String?,
              metadata: {
                if (backdropUrl != null) 'backdropUrl': backdropUrl,
                if (m['year'] != null) 'year': m['year'],
              },
            );
          }).toList();

      return PaginatedResult(
        items: items,
        totalCount: totalSize,
        startIndex: offset,
        limit: limit,
      );
    } on AuthFailure catch (e) {
      throw MediaSourceException.auth(message: e.message, cause: e);
    } on ServerFailure catch (e) {
      throw MediaSourceException.server(message: e.message, cause: e);
    } catch (e) {
      if (e is MediaSourceException) rethrow;
      throw toMediaSourceException(e, 'Plex');
    }
  }

  /// Fetch children of an item (seasons of a show, episodes of a season).
  Future<List<MediaItem>> getChildren(String itemId) async {
    try {
      final items = await apiClient.getChildren(_server, itemId: itemId);
      return items.map(_mapToMediaItem).toList();
    } on AuthFailure catch (e) {
      throw MediaSourceException.auth(message: e.message, cause: e);
    } on ServerFailure catch (e) {
      throw MediaSourceException.server(message: e.message, cause: e);
    } catch (e) {
      if (e is MediaSourceException) rethrow;
      throw toMediaSourceException(e, 'Plex');
    }
  }

  @override
  Future<List<MediaItem>> search(
    String query, {
    int? startIndex,
    int? limit,
  }) async {
    try {
      // Note: Plex API pagination for search uses different params
      final items = await apiClient.search(_server, query: query);
      return items.map(_mapToMediaItem).toList();
    } on AuthFailure catch (e) {
      throw MediaSourceException.auth(message: e.message, cause: e);
    } on ServerFailure catch (e) {
      throw MediaSourceException.server(message: e.message, cause: e);
    } catch (e) {
      if (e is MediaSourceException) rethrow;
      throw toMediaSourceException(e, 'Plex');
    }
  }

  @override
  Future<String> getStreamUrl(String itemId) async {
    try {
      return apiClient.getPlaybackUrl(_server, itemId);
    } on AuthFailure catch (e) {
      throw MediaSourceException.auth(message: e.message, cause: e);
    } on ServerFailure catch (e) {
      throw MediaSourceException.server(message: e.message, cause: e);
    } catch (e) {
      if (e is MediaSourceException) rethrow;
      throw toMediaSourceException(e, 'Plex');
    }
  }

  /// Builds a full Plex image URL with authentication token.
  ///
  /// Plex API returns relative paths (e.g. `/library/metadata/35/thumb/...`).
  /// Clients must prepend the server URL and append the auth token.
  String? _buildImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    return '$serverUrl$path?X-Plex-Token=$accessToken';
  }

  MediaItem _mapToMediaItem(dynamic item) {
    if (item is PlexMetadata) {
      final releaseDate =
          item.originallyAvailableAt != null
              ? DateTime.tryParse(item.originallyAvailableAt!)
              : (item.year != null ? DateTime(item.year!) : null);

      final thumbUrl = _buildImageUrl(item.thumb);
      final backdropUrl = _buildImageUrl(item.art);

      return MediaItem(
        id: item.ratingKey ?? '',
        name: item.title ?? 'Unknown',
        type: _mapType(item.type),
        parentId: null,
        logoUrl: thumbUrl,
        overview: item.summary,
        releaseDate: releaseDate,
        durationMs: item.duration,
        // Watched status from Plex
        playbackPositionMs: item.playbackPositionMs,
        isWatched: item.isWatched,
        rating: item.contentRating,
        metadata: {
          if (backdropUrl != null) 'backdropUrl': backdropUrl,
          if (item.year != null) 'year': item.year,
        },
      );
    }
    throw MediaSourceException.server(
      message: 'Unknown Plex item type: ${item.runtimeType}',
    );
  }

  MediaType _mapType(String? type) {
    switch (type) {
      case 'movie':
        return MediaType.movie;
      case 'show':
        return MediaType.series;
      case 'season':
        return MediaType.season;
      case 'episode':
        return MediaType.episode;
      case 'artist':
      case 'album':
        return MediaType.folder;
      case 'track':
        return MediaType.unknown;
      default:
        return MediaType.unknown;
    }
  }
}
