import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'models/media_server_auth_result.dart';
import 'models/media_server_item.dart';
import 'models/media_server_items_response.dart';
import 'models/media_server_system_info.dart';
import 'models/media_server_user.dart';

part 'media_server_api_client.g.dart';

/// Retrofit API client for Emby/Jellyfin servers.
///
/// Both servers expose an identical wire protocol — this single client
/// handles both. Instantiate with the appropriate base URL and auth
/// headers for the target server type.
@RestApi()
abstract class MediaServerApiClient {
  factory MediaServerApiClient(Dio dio, {String baseUrl}) =
      _MediaServerApiClient;

  @GET('/System/Info/Public')
  Future<MediaServerSystemInfo> getPublicSystemInfo();

  @POST('/Users/AuthenticateByName')
  Future<MediaServerAuthResult> authenticateByName(
    @Body() Map<String, dynamic> body,
  );

  @GET('/Users/{userId}/Views')
  Future<MediaServerItemsResponse> getUserViews(@Path('userId') String userId);

  @GET('/Users/{userId}/Items')
  Future<MediaServerItemsResponse> getItems(
    @Path('userId') String userId, {
    @Query('ParentId') String? parentId,
    @Query('SortBy') String sortBy = 'SortName',
    @Query('SortOrder') String sortOrder = 'Ascending',
    @Query('Fields')
    String fields =
        'Overview,Path,ParentId,DisplayPreferencesId,DateCreated,MediaStreams,SeasonUserData,DateLastMediaAdded',
    @Query('ExcludeItemTypes') String? excludeItemTypes,
    @Query('IncludeItemTypes') String? includeItemTypes,
    @Query('Recursive') bool? recursive,
    @Query('SearchTerm') String? searchTerm,
    @Query('StartIndex') int? startIndex,
    @Query('Limit') int? limit,
    // ── EB-FE-08: filter params ─────────────────────────────
    @Query('Genres') String? genres,
    @Query('Years') String? years,
    @Query('IsHD') bool? isHd,
    @Query('IsHDR') bool? isHdr,
  });

  @GET('/Users/{userId}/Items/{itemId}')
  Future<MediaServerItem> getItem(
    @Path('userId') String userId,
    @Path('itemId') String itemId,
  );

  // ── EB-FE-04: Resume Items ─────────────────────────────────────────────

  /// Fetches items in the user's resume queue (`/Users/{userId}/Items/Resume`).
  @GET('/Users/{userId}/Items/Resume')
  Future<MediaServerItemsResponse> getResumeItems(
    @Path('userId') String userId, {
    @Query('Limit') int? limit,
    @Query('IncludeItemTypes') String? includeItemTypes,
    @Query('Fields') String? fields,
  });

  // ── EB-FE-05: Next Up ──────────────────────────────────────────────────

  /// Fetches the next unwatched episode per series (`/Shows/NextUp`).
  @GET('/Shows/NextUp')
  Future<MediaServerItemsResponse> getNextUp(
    @Query('UserId') String userId, {
    @Query('Limit') int? limit,
    @Query('Fields') String? fields,
  });

  // ── EB-FE-06: Latest Items by Library ─────────────────────────────────

  /// Fetches latest (recently added) items for a specific library folder.
  ///
  /// Returns a raw JSON array — mapped to [MediaServerItemsResponse]
  /// via a dedicated parser, not an [ItemsResult] wrapper.
  @GET('/Users/{userId}/Items/Latest')
  Future<List<MediaServerItem>> getLatestItems(
    @Path('userId') String userId, {
    @Query('ParentId') String? parentId,
    @Query('Limit') int? limit,
    @Query('Fields') String? fields,
  });

  // ── EB-FE-02: Public Users ────────────────────────────────────────────

  /// Fetches the list of public users from the server (no auth required).
  ///
  /// Emby/Jellyfin expose `/Users/Public` without authentication.
  @GET('/Users/Public')
  Future<List<MediaServerUser>> getPublicUsers();
}
