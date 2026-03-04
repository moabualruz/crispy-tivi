import 'package:dio/dio.dart';

import 'stalker_portal_parser.dart';
import 'stalker_portal_result.dart';

/// API endpoint methods for
/// [StalkerPortalClient].
///
/// Extracted to keep the client class under
/// 500 lines. Requires the implementing class to
/// provide [portalUrl], [isAuthenticated],
/// [authenticate], [buildOptions], and the
/// [StalkerPortalParser] mixin.
mixin StalkerPortalApi on StalkerPortalParser {
  /// Full portal endpoint URL
  /// (e.g. `http://host:port/portal.php`).
  String get portalUrl;

  /// Whether the client has a valid auth token.
  bool get isAuthenticated;

  /// Authenticates with the portal.
  Future<void> authenticate(Dio dio);

  /// Builds [Options] with auth headers.
  Options buildOptions();

  /// Ensures the client is authenticated before
  /// making a request.
  Future<void> _ensureAuth(Dio dio) async {
    if (!isAuthenticated) {
      await authenticate(dio);
    }
  }

  /// Makes a GET request to the portal API.
  Future<Response<dynamic>> _portalGet(
    Dio dio,
    Map<String, String> queryParameters,
  ) async {
    await _ensureAuth(dio);
    return dio.get(
      portalUrl,
      queryParameters: {...queryParameters, 'JsHttpRequest': '1-xml'},
      options: buildOptions(),
    );
  }

  /// Fetches live channel categories (genres).
  Future<List<Map<String, dynamic>>> fetchCategories(Dio dio) async {
    final response = await _portalGet(dio, {
      'type': 'itv',
      'action': 'get_genres',
    });
    return parseCategories(response.data);
  }

  /// Fetches live channels (paginated).
  ///
  /// [genre] - Category ID filter
  /// (optional, '*' for all).
  /// [page] - Page number (1-indexed).
  Future<StalkerChannelsResult> fetchLiveChannels(
    Dio dio, {
    String genre = '*',
    int page = 1,
  }) async {
    final response = await _portalGet(dio, {
      'type': 'itv',
      'action': 'get_ordered_list',
      'genre': genre,
      'p': page.toString(),
    });
    return parseChannelsResult(response.data);
  }

  /// Creates an authenticated stream link for a
  /// channel.
  ///
  /// This is the preferred method for getting
  /// playback URLs as it generates a valid play
  /// token.
  ///
  /// [cmd] - The channel's cmd field value.
  Future<String?> createLink(Dio dio, {required String cmd}) async {
    final response = await _portalGet(dio, {
      'type': 'itv',
      'action': 'create_link',
      'cmd': cmd,
      'series': '',
      'forced_storage': 'false',
      'disable_ad': '1',
    });
    return parseCreateLinkResponse(response.data);
  }

  /// Fetches VOD (Video on Demand) categories.
  Future<List<Map<String, dynamic>>> fetchVodCategories(Dio dio) async {
    final response = await _portalGet(dio, {
      'type': 'vod',
      'action': 'get_categories',
    });
    return parseCategories(response.data);
  }

  /// Fetches VOD items (movies) with pagination.
  ///
  /// [category] - Category ID filter
  /// (optional, '*' for all).
  /// [page] - Page number (1-indexed).
  Future<StalkerVodResult> fetchVodItems(
    Dio dio, {
    String category = '*',
    int page = 1,
  }) async {
    final response = await _portalGet(dio, {
      'type': 'vod',
      'action': 'get_ordered_list',
      'category': category,
      'p': page.toString(),
    });
    return parseVodResult(response.data);
  }

  /// Fetches series categories.
  Future<List<Map<String, dynamic>>> fetchSeriesCategories(Dio dio) async {
    final response = await _portalGet(dio, {
      'type': 'series',
      'action': 'get_categories',
    });
    return parseCategories(response.data);
  }

  /// Fetches series items with pagination.
  ///
  /// [category] - Category ID filter
  /// (optional, '*' for all).
  /// [page] - Page number (1-indexed).
  Future<StalkerVodResult> fetchSeriesItems(
    Dio dio, {
    String category = '*',
    int page = 1,
  }) async {
    final response = await _portalGet(dio, {
      'type': 'series',
      'action': 'get_ordered_list',
      'category': category,
      'p': page.toString(),
    });
    return parseVodResult(response.data);
  }

  /// Creates an authenticated VOD stream link.
  ///
  /// [cmd] - The VOD item's cmd field value.
  Future<String?> createVodLink(Dio dio, {required String cmd}) async {
    final response = await _portalGet(dio, {
      'type': 'vod',
      'action': 'create_link',
      'cmd': cmd,
      'series': '',
      'forced_storage': 'false',
      'disable_ad': '1',
    });
    return parseCreateLinkResponse(response.data);
  }
}
