import 'package:dio/dio.dart';
import '../../domain/entities/plex_server.dart';
import '../../../../../core/constants.dart';
import '../../../../../core/domain/media_source.dart';
import '../../../../../core/failures/failure.dart';
import '../models/plex_media_container.dart';
import '../models/plex_directory.dart';
import '../models/plex_metadata.dart';

/// Client for interacting with the Plex API (JSON).
class PlexApiClient {
  PlexApiClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// Validate server connection and return server details.
  ///
  /// [clientIdentifier] is a stable, app-wide opaque string sent via the
  /// `X-Plex-Client-Identifier` header on every request. Plex uses it to
  /// identify this client in its "Connected Devices" list and to scope
  /// session tokens. It must remain constant across app restarts — in
  /// CrispyTivi it is the compile-time constant
  /// `PlexLoginScreen._clientIdentifier` (`'crispy-tivi-web'`), which is
  /// persisted in [PlaylistSource.deviceId] after login so the same value
  /// is reused for all subsequent API calls.
  Future<PlexServer> validateServer({
    required String url,
    required String token,
    required String clientIdentifier,
  }) async {
    final baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;

    final headers = {
      'X-Plex-Token': token,
      'X-Plex-Client-Identifier': clientIdentifier,
      'Accept': 'application/json',
    };

    try {
      // /identity endpoint returns a MediaContainer with MachineIdentifier
      final response = await _dio.get(
        '$baseUrl/identity',
        options: Options(headers: headers),
      );

      final container = PlexMediaContainer.fromJson(
        response.data['MediaContainer'],
      );

      return PlexServer(
        url: baseUrl,
        name: container.friendlyName ?? 'Plex Server',
        accessToken: token,
        clientIdentifier: clientIdentifier,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthFailure(message: 'Invalid Plex Token');
      }
      throw ServerFailure(message: e.message ?? 'Connection failed');
    } catch (e) {
      throw ServerFailure(message: e.toString());
    }
  }

  /// Get list of libraries (Sections).
  Future<List<PlexDirectory>> getLibraries(PlexServer server) async {
    final endpoint = '${server.url}/library/sections';

    final headers = {
      'X-Plex-Token': server.accessToken,
      'X-Plex-Client-Identifier': server.clientIdentifier,
      'Accept': 'application/json',
    };

    try {
      final response = await _dio.get(
        endpoint,
        options: Options(headers: headers),
      );

      final container = PlexMediaContainer.fromJson(
        response.data['MediaContainer'],
      );
      return container.directory ?? [];
    } on DioException catch (e) {
      throw ServerFailure(message: e.message ?? 'Failed to fetch libraries');
    } catch (e) {
      throw ServerFailure(message: e.toString());
    }
  }

  /// Get items from a specific library section.
  Future<List<PlexMetadata>> getItems(
    PlexServer server, {
    required String libraryId,
  }) async {
    final endpoint = '${server.url}/library/sections/$libraryId/all';

    final headers = {
      'X-Plex-Token': server.accessToken,
      'X-Plex-Client-Identifier': server.clientIdentifier,
      'Accept': 'application/json',
    };

    try {
      final response = await _dio.get(
        endpoint,
        options: Options(headers: headers),
      );

      final container = PlexMediaContainer.fromJson(
        response.data['MediaContainer'],
      );
      return container.metadata ?? [];
    } on DioException catch (e) {
      throw ServerFailure(message: e.message ?? 'Failed to fetch items');
    } catch (e) {
      throw ServerFailure(message: e.toString());
    }
  }

  /// Get items from a specific library section with pagination.
  ///
  /// [start] - Starting index (0-based).
  /// [size] - Number of items to fetch. Defaults to [kMediaServerPageSize]
  ///   (shared with Emby/Jellyfin pagination).
  ///
  /// Returns a [PaginatedResult] containing items and pagination metadata.
  Future<PaginatedResult<PlexMetadata>> getItemsPaginated(
    PlexServer server, {
    required String libraryId,
    int start = 0,
    int size = kMediaServerPageSize,
  }) async {
    final endpoint = '${server.url}/library/sections/$libraryId/all';

    final headers = {
      'X-Plex-Token': server.accessToken,
      'X-Plex-Client-Identifier': server.clientIdentifier,
      'Accept': 'application/json',
    };

    final queryParams = {
      'X-Plex-Container-Start': start,
      'X-Plex-Container-Size': size,
    };

    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParams,
        options: Options(headers: headers),
      );

      final container = PlexMediaContainer.fromJson(
        response.data['MediaContainer'],
      );
      final items = container.metadata ?? [];
      return PaginatedResult<PlexMetadata>(
        items: items,
        totalCount: container.totalSize ?? container.size ?? 0,
        startIndex: container.offset ?? start,
        limit: size,
      );
    } on DioException catch (e) {
      throw ServerFailure(message: e.message ?? 'Failed to fetch items');
    } catch (e) {
      throw ServerFailure(message: e.toString());
    }
  }

  /// Get children of an item with pagination.
  ///
  /// Returns seasons of a show or episodes of a season.
  /// [size] defaults to [kMediaServerPageSize] (shared with Emby/Jellyfin).
  Future<PaginatedResult<PlexMetadata>> getChildrenPaginated(
    PlexServer server, {
    required String itemId,
    int start = 0,
    int size = kMediaServerPageSize,
  }) async {
    final endpoint = '${server.url}/library/metadata/$itemId/children';

    final headers = {
      'X-Plex-Token': server.accessToken,
      'X-Plex-Client-Identifier': server.clientIdentifier,
      'Accept': 'application/json',
    };

    final queryParams = {
      'X-Plex-Container-Start': start,
      'X-Plex-Container-Size': size,
    };

    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParams,
        options: Options(headers: headers),
      );

      final container = PlexMediaContainer.fromJson(
        response.data['MediaContainer'],
      );
      final items = container.metadata ?? [];
      return PaginatedResult<PlexMetadata>(
        items: items,
        totalCount: container.totalSize ?? container.size ?? 0,
        startIndex: container.offset ?? start,
        limit: size,
      );
    } on DioException catch (e) {
      throw ServerFailure(message: e.message ?? 'Failed to fetch children');
    } catch (e) {
      throw ServerFailure(message: e.toString());
    }
  }

  /// Get direct playback URL for an item.
  Future<String> getPlaybackUrl(
    PlexServer server,
    String itemId, // ratingKey
  ) async {
    // 1. Fetch item metadata to find 'Media' -> 'Part' -> 'key'
    final endpoint = '${server.url}/library/metadata/$itemId';

    final headers = {
      'X-Plex-Token': server.accessToken,
      'X-Plex-Client-Identifier': server.clientIdentifier,
      'Accept': 'application/json',
    };

    try {
      final response = await _dio.get(
        endpoint,
        options: Options(headers: headers),
      );

      final container = PlexMediaContainer.fromJson(
        response.data['MediaContainer'],
      );

      final metadataList = container.metadata;
      if (metadataList == null || metadataList.isEmpty) {
        throw const ServerFailure(message: 'Item not found');
      }

      final item = metadataList.first;
      final media = item.media;

      if (media == null || media.isEmpty) {
        throw const ServerFailure(message: 'No media found for item');
      }

      // Pick first media version (usually highest quality)
      final parts = media.first.part;
      if (parts == null || parts.isEmpty) {
        throw const ServerFailure(message: 'No media parts found');
      }

      final key = parts.first.key; // e.g. /library/parts/35/1709.../file.mkv
      if (key == null) {
        throw const ServerFailure(message: 'Invalid media part key');
      }

      // 2. Construct URL
      return '${server.url}$key?X-Plex-Token=${server.accessToken}';
    } on DioException catch (e) {
      throw ServerFailure(message: e.message ?? 'Failed to get playback info');
    } catch (e) {
      throw ServerFailure(message: e.toString());
    }
  }

  /// Get children of an item (seasons of a show, episodes of a season).
  Future<List<PlexMetadata>> getChildren(
    PlexServer server, {
    required String itemId,
  }) async {
    final endpoint = '${server.url}/library/metadata/$itemId/children';

    final headers = {
      'X-Plex-Token': server.accessToken,
      'X-Plex-Client-Identifier': server.clientIdentifier,
      'Accept': 'application/json',
    };

    try {
      final response = await _dio.get(
        endpoint,
        options: Options(headers: headers),
      );

      final container = PlexMediaContainer.fromJson(
        response.data['MediaContainer'],
      );
      return container.metadata ?? [];
    } on DioException catch (e) {
      throw ServerFailure(message: e.message ?? 'Failed to fetch children');
    } catch (e) {
      throw ServerFailure(message: e.toString());
    }
  }

  /// Fetches a raw JSON map from any Plex endpoint.
  ///
  /// Used by providers that need endpoints not yet modelled by specific
  /// methods (e.g. `/accounts`, `/library/onDeck`, `/hubs/*`).
  ///
  /// - [path] — full URL including server base (e.g.
  ///   `http://192.168.1.10:32400/library/onDeck`).
  /// - [token] — `X-Plex-Token` for authentication.
  /// - [clientId] — `X-Plex-Client-Identifier` sent on every request.
  /// - [queryParams] — optional extra query parameters.
  Future<Map<String, dynamic>> getRawJson(
    String path, {
    required String token,
    required String clientId,
    Map<String, dynamic>? queryParams,
  }) async {
    final headers = {
      'X-Plex-Token': token,
      'X-Plex-Client-Identifier': clientId,
      'Accept': 'application/json',
    };

    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParams,
        options: Options(headers: headers),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ServerFailure(message: e.message ?? 'Request failed: $path');
    } catch (e) {
      throw ServerFailure(message: e.toString());
    }
  }

  /// Search for items.
  Future<List<PlexMetadata>> search(
    PlexServer server, {
    required String query,
  }) async {
    final endpoint = '${server.url}/hubs/search';

    final queryParams = {'query': query, 'limit': 25};

    final headers = {
      'X-Plex-Token': server.accessToken,
      'X-Plex-Client-Identifier': server.clientIdentifier,
      'Accept': 'application/json',
    };

    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParams,
        options: Options(headers: headers),
      );

      PlexMediaContainer.fromJson(
        response.data['MediaContainer'],
      ); // Hubs search structure is complex
      // Actually /hubs/search returns MediaContainer -> Hub -> Metadata
      // My DTO doesn't support 'Hub' field yet.
      // I need to add 'Hub' to PlexMediaContainer.

      // For now, let's manually parse Hubs if DTO doesn't have it, or update DTO.
      // I'll update DTO later or handle dynamic map here for Hubs.
      // Let's assume I'll add Hub to DTO or ignore search for now in strict mode.

      // Let's do a quick manual parse for Hubs to respect the DTO pattern
      final hubs = response.data['MediaContainer']['Hub'] as List<dynamic>?;
      if (hubs == null) return [];

      final results = <PlexMetadata>[];
      for (final hub in hubs) {
        final metadata = hub['Metadata'] as List<dynamic>?;
        if (metadata != null) {
          results.addAll(metadata.map((e) => PlexMetadata.fromJson(e)));
        }
      }

      return results;
    } on DioException catch (e) {
      throw ServerFailure(message: e.message ?? 'Failed to search items');
    } catch (e) {
      throw ServerFailure(message: e.toString());
    }
  }
}
