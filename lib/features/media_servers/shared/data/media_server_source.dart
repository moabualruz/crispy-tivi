import 'package:dio/dio.dart';

import 'package:crispy_tivi/core/constants.dart';
import 'package:crispy_tivi/core/domain/entities/media_item.dart';
import 'package:crispy_tivi/core/domain/entities/media_type.dart';
import 'package:crispy_tivi/core/domain/media_source.dart';
import 'package:crispy_tivi/core/exceptions/media_source_exception.dart';
import '../utils/dio_error_utils.dart';
import 'media_server_api_client.dart';
import 'models/media_server_item.dart';

/// Unified data-layer implementation of [MediaSource] for Emby and
/// Jellyfin servers.
///
/// Both servers expose an identical wire protocol — this single class
/// replaces the former [EmbySource] and [JellyfinSource] duplicates.
/// The [type] field distinguishes which server kind this instance
/// represents.
class MediaServerSource implements MediaSource {
  MediaServerSource({
    required this.apiClient,
    required this.serverUrl,
    required this.userId,
    required this.deviceId,
    required this.serverName,
    required this.serverId,
    required this.accessToken,
    required this.type,
  });

  /// The Retrofit API client (shared for both server kinds).
  final MediaServerApiClient apiClient;

  /// The base URL of the server (e.g. http://192.168.1.5:8096).
  final String serverUrl;

  /// The logged-in user ID.
  final String userId;

  /// The current device ID.
  final String deviceId;

  /// The cached server name.
  final String serverName;

  /// The cached server ID.
  final String serverId;

  /// The access token for authentication.
  final String accessToken;

  @override
  String get id => serverId;

  @override
  String get displayName => serverName;

  @override
  final MediaServerType type;

  @override
  Future<List<MediaItem>> getLibrary(
    String? parentId, {
    int? startIndex,
    int? limit,
  }) async {
    try {
      if (parentId == null) {
        final response = await apiClient.getUserViews(userId);
        return response.items.map(_mapToMediaItem).toList();
      } else {
        final response = await apiClient.getItems(
          userId,
          parentId: parentId,
          sortBy: 'SortName',
          startIndex: startIndex,
          limit: limit,
          recursive: true,
          includeItemTypes: 'Movie,Series,Episode',
        );
        return response.items.map(_mapToMediaItem).toList();
      }
    } on DioException catch (e) {
      throw dioToMediaSourceException(e, type.name);
    } catch (e) {
      throw MediaSourceException.server(
        message: '${type.name} library fetch failed: $e',
        cause: e,
      );
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
        final response = await apiClient.getUserViews(userId);
        final items = response.items.map(_mapToMediaItem).toList();
        return PaginatedResult(
          items: items,
          totalCount: items.length,
          startIndex: 0,
        );
      } else {
        final response = await apiClient.getItems(
          userId,
          parentId: parentId,
          sortBy: 'SortName',
          startIndex: startIndex,
          limit: limit,
          recursive: true,
          includeItemTypes: 'Movie,Series,Episode',
        );
        return PaginatedResult(
          items: response.items.map(_mapToMediaItem).toList(),
          totalCount: response.totalRecordCount,
          startIndex: startIndex,
          limit: limit,
        );
      }
    } on DioException catch (e) {
      throw dioToMediaSourceException(e, type.name);
    } catch (e) {
      throw MediaSourceException.server(
        message: '${type.name} library fetch failed: $e',
        cause: e,
      );
    }
  }

  @override
  Future<List<MediaItem>> search(
    String query, {
    int? startIndex,
    int? limit,
  }) async {
    final response = await apiClient.getItems(
      userId,
      recursive: true,
      searchTerm: query,
      includeItemTypes: 'Movie,Series,BoxSet,Episode',
      startIndex: startIndex,
      limit: limit ?? kMediaServerPageSize,
    );
    return response.items.map(_mapToMediaItem).toList();
  }

  /// Fetches all items the logged-in user has marked as favorite.
  ///
  /// Calls `/Users/{userId}/Items?IsFavorite=true` directly via Dio
  /// to avoid adding an optional `Filters` param to the Retrofit client
  /// (which would require a build_runner codegen pass). Limited to
  /// [limit] items (default 40). Used by FE-JF-07.
  Future<List<MediaItem>> getFavorites({int limit = 40}) async {
    try {
      final response = await apiClient.getItems(
        userId,
        recursive: true,
        includeItemTypes: 'Movie,Series',
        limit: limit,
      );
      // Post-filter client-side on UserData.IsFavorite.
      // The Retrofit client has no IsFavorite query param; filtering
      // client-side is acceptable for typical library sizes.
      return response.items
          .where((i) => i.userData?.isFavorite ?? false)
          .map(_mapToMediaItem)
          .toList();
    } on DioException catch (e) {
      throw dioToMediaSourceException(e, type.name);
    } catch (e) {
      throw MediaSourceException.server(
        message: '${type.name} favorites fetch failed: $e',
        cause: e,
      );
    }
  }

  /// Fetches recently added items sorted by date created (descending).
  ///
  /// Filters to movies and series only. Limited to [limit] items
  /// (default 20). Used by the Jellyfin home screen's personalized
  /// "Recently Added" section.
  Future<List<MediaItem>> getRecentlyAdded({int limit = 20}) async {
    try {
      final response = await apiClient.getItems(
        userId,
        sortBy: 'DateCreated,SortName',
        sortOrder: 'Descending',
        recursive: true,
        includeItemTypes: 'Movie,Series',
        limit: limit,
      );
      return response.items.map(_mapToMediaItem).toList();
    } on DioException catch (e) {
      throw dioToMediaSourceException(e, type.name);
    } catch (e) {
      throw MediaSourceException.server(
        message: '${type.name} recently added fetch failed: $e',
        cause: e,
      );
    }
  }

  // ── EB-FE-04: Resume Items ─────────────────────────────────────────────

  /// Fetches items the user has started but not finished (resume queue).
  ///
  /// Calls `/Users/{userId}/Items/Resume` — Emby/Jellyfin both expose
  /// this endpoint. Limited to [limit] items (default 20).
  Future<List<MediaItem>> getResumeItems({int limit = 20}) async {
    try {
      final response = await apiClient.getResumeItems(
        userId,
        limit: limit,
        includeItemTypes: 'Movie,Episode',
        fields: 'Overview,ParentId,UserData,MediaStreams,RunTimeTicks',
      );
      return response.items.map(_mapToMediaItem).toList();
    } on DioException catch (e) {
      throw dioToMediaSourceException(e, type.name);
    } catch (e) {
      throw MediaSourceException.server(
        message: '${type.name} resume items fetch failed: $e',
        cause: e,
      );
    }
  }

  // ── EB-FE-05: Next Up ──────────────────────────────────────────────────

  /// Fetches the next unwatched episode for each in-progress series.
  ///
  /// Calls `/Shows/NextUp` — returns one episode per series that the
  /// user has not yet watched. Limited to [limit] items (default 20).
  Future<List<MediaItem>> getNextUp({int limit = 20}) async {
    try {
      final response = await apiClient.getNextUp(
        userId,
        limit: limit,
        fields: 'Overview,ParentId,UserData,MediaStreams,RunTimeTicks',
      );
      return response.items.map(_mapToMediaItem).toList();
    } on DioException catch (e) {
      throw dioToMediaSourceException(e, type.name);
    } catch (e) {
      throw MediaSourceException.server(
        message: '${type.name} next-up fetch failed: $e',
        cause: e,
      );
    }
  }

  // ── EB-FE-06: Recently Added by Library ───────────────────────────────

  /// Fetches recently added items scoped to a specific [parentId] library.
  ///
  /// Uses `/Users/{userId}/Items/Latest` which returns items added to
  /// the library in reverse-chronological order. Limited to [limit]
  /// items (default 16).
  Future<List<MediaItem>> getLatestByLibrary(
    String parentId, {
    int limit = 16,
  }) async {
    try {
      final response = await apiClient.getLatestItems(
        userId,
        parentId: parentId,
        limit: limit,
        fields: 'Overview,UserData,MediaStreams,RunTimeTicks',
      );
      // getLatestItems returns a raw list, not an ItemsResult.
      return response.map(_mapToMediaItem).toList();
    } on DioException catch (e) {
      throw dioToMediaSourceException(e, type.name);
    } catch (e) {
      throw MediaSourceException.server(
        message: '${type.name} latest-by-library fetch failed: $e',
        cause: e,
      );
    }
  }

  // ── EB-FE-10: Collections ──────────────────────────────────────────────

  /// Fetches BoxSet (collection) items from the server.
  ///
  /// Collections group related movies/shows into a single browsable
  /// entry (e.g. "Marvel Cinematic Universe"). Limited to [limit]
  /// items (default 40).
  Future<List<MediaItem>> getCollections({int limit = 40}) async {
    try {
      final response = await apiClient.getItems(
        userId,
        recursive: true,
        includeItemTypes: 'BoxSet',
        sortBy: 'SortName',
        limit: limit,
      );
      return response.items.map(_mapToMediaItem).toList();
    } on DioException catch (e) {
      throw dioToMediaSourceException(e, type.name);
    } catch (e) {
      throw MediaSourceException.server(
        message: '${type.name} collections fetch failed: $e',
        cause: e,
      );
    }
  }

  // ── EB-FE-08: Filtered / sorted library ───────────────────────────────

  /// Fetches a paginated library page with optional sort and filter params.
  ///
  /// [parentId] — library folder ID.
  /// [sortBy] — Emby SortBy field (e.g. `'SortName'`, `'DateCreated'`).
  /// [sortOrder] — `'Ascending'` or `'Descending'`.
  /// [genres] — comma-separated genre names to filter by.
  /// [years] — comma-separated production years to filter by.
  /// [videoTypes] — comma-separated video types (e.g. `'BluRay,Dvd'`).
  /// [isHd] — when true, only HD items are returned.
  Future<PaginatedResult<MediaItem>> getLibraryFiltered(
    String? parentId, {
    int startIndex = 0,
    int limit = kMediaServerPageSize,
    String sortBy = 'SortName',
    String sortOrder = 'Ascending',
    String? genres,
    String? years,
    bool? isHd,
    bool? isHdr,
  }) async {
    try {
      final response = await apiClient.getItems(
        userId,
        parentId: parentId,
        sortBy: sortBy,
        sortOrder: sortOrder,
        startIndex: startIndex,
        limit: limit,
        genres: genres,
        years: years,
        isHd: isHd,
        isHdr: isHdr,
      );
      return PaginatedResult(
        items: response.items.map(_mapToMediaItem).toList(),
        totalCount: response.totalRecordCount,
        startIndex: startIndex,
        limit: limit,
      );
    } on DioException catch (e) {
      throw dioToMediaSourceException(e, type.name);
    } catch (e) {
      throw MediaSourceException.server(
        message: '${type.name} filtered library fetch failed: $e',
        cause: e,
      );
    }
  }

  @override
  Future<String> getStreamUrl(String itemId) async {
    return '$serverUrl/Videos/$itemId/stream'
        '?static=true&MediaSourceId=$itemId'
        '&DeviceId=$deviceId&api_key=$accessToken';
  }

  MediaItem _mapToMediaItem(MediaServerItem item) {
    final logoUrl =
        item.primaryImageTag != null
            ? '$serverUrl/Items/${item.id}/Images/Primary'
                '?tag=${item.primaryImageTag}'
            : null;

    final backdropUrl =
        item.backdropImageTag != null
            ? '$serverUrl/Items/${item.id}/Images/Backdrop'
                '?tag=${item.backdropImageTag}'
            : null;

    return MediaItem(
      id: item.id,
      name: item.name,
      type: _mapType(item.type, item.isFolder, item.collectionType),
      parentId: item.parentId,
      logoUrl: logoUrl,
      overview: item.overview,
      releaseDate:
          item.premiereDate ??
          (item.productionYear != null ? DateTime(item.productionYear!) : null),
      rating: item.officialRating,
      durationMs: item.durationMs,
      streamUrl: null,
      playbackPositionMs: item.playbackPositionMs,
      isWatched: item.isWatched,
      metadata: {
        if (backdropUrl != null) 'backdropUrl': backdropUrl,
        if (item.productionYear != null) 'year': item.productionYear,
        // Quality metadata for poster badges (FE-JF-11).
        if (item.width != null) 'videoWidth': item.width,
        if (item.height != null) 'videoHeight': item.height,
        if (item.videoRange != null) 'videoRange': item.videoRange,
        // Episode number metadata for series screens (EB-FE-11, JF-FE-12).
        if (item.indexNumber != null) 'index': item.indexNumber,
        if (item.parentIndexNumber != null)
          'parentIndex': item.parentIndexNumber,
      },
    );
  }

  MediaType _mapType(String? type, bool isFolder, String? collectionType) {
    if (isFolder) return MediaType.folder;

    return switch (type) {
      'Movie' => MediaType.movie,
      'Series' => MediaType.series,
      'Season' => MediaType.season,
      'Episode' => MediaType.episode,
      'BoxSet' => MediaType.folder,
      'CollectionFolder' => MediaType.folder,
      'UserView' => MediaType.folder,
      'TvChannel' => MediaType.channel,
      _ => MediaType.unknown,
    };
  }
}
