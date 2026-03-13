import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/core/network/network_timeouts.dart';
import 'package:crispy_tivi/core/utils/platform_info.dart';
import 'package:crispy_tivi/features/media_servers/plex/data/datasources/plex_api_client.dart';
import 'package:crispy_tivi/features/media_servers/plex/data/datasources/plex_auth_service.dart';
import 'package:crispy_tivi/features/media_servers/shared/data/media_server_api_client.dart';
import 'package:crispy_tivi/features/media_servers/shared/utils/media_server_auth.dart';

/// Result of a server connectivity test.
///
/// Returned by [testMediaServerConnection] on success. Carries the
/// server name and version string to display to the user.
class ServerConnectionInfo {
  const ServerConnectionInfo({required this.serverName, required this.version});

  /// Human-readable server name (e.g. "My Emby Server").
  final String serverName;

  /// Server version string (e.g. "4.8.7.0").
  final String version;
}

/// Device identifier sent in the MediaBrowser auth header and stored
/// in [PlaylistSource.deviceId].
///
/// Varies by platform so the media server can distinguish clients
/// (e.g. Android TV vs. web browser vs. Windows desktop).
String get mediaServerDeviceId {
  if (kIsWeb) return 'crispy_tivi_web';
  final p = PlatformInfo.instance;
  if (p.isAndroid) return 'crispy_tivi_android';
  if (p.isIOS) return 'crispy_tivi_ios';
  if (p.isWindows) return 'crispy_tivi_windows';
  if (p.isLinux) return 'crispy_tivi_linux';
  if (p.isMacOS) return 'crispy_tivi_macos';
  return 'crispy_tivi';
}

/// Callback that performs server-specific authentication.
///
/// Receives a pre-configured [Dio] instance (base URL + auth header set)
/// and raw field values. Must return a [PlaylistSource] on success or
/// throw on failure.
///
/// When the login screen's `showUsernameField` is `false`, [username]
/// is always an empty string.
typedef MediaServerAuthenticate =
    Future<PlaylistSource> Function(
      Dio dio,
      String url,
      String username,
      String password,
    );

/// Shared authentication logic for Emby and Jellyfin servers.
///
/// Both servers expose an identical wire protocol -- this function
/// handles the common authenticate-by-name flow. Callers supply the
/// [type] to distinguish the resulting [PlaylistSource].
Future<PlaylistSource> authenticateMediaServer(
  Dio dio,
  String url,
  String username,
  String password,
  PlaylistSourceType type,
) async {
  final client = MediaServerApiClient(dio, baseUrl: url);
  final systemInfo = await client.getPublicSystemInfo();
  final authResult = await client.authenticateByName({
    'Username': username,
    'Pw': password,
  });
  return PlaylistSource(
    id: systemInfo.id,
    name: systemInfo.serverName,
    url: url,
    type: type,
    username: authResult.user.name,
    userId: authResult.user.id,
    accessToken: authResult.accessToken,
    deviceId: mediaServerDeviceId,
  );
}

/// Creates a pre-configured [Dio] instance for media server communication.
///
/// Sets the base URL and Emby/Jellyfin authorization header.
/// Lives in the data layer so presentation code never imports `package:dio`.
Dio createMediaServerDio(String baseUrl, {Duration? connectTimeout}) {
  final dio = Dio(
    BaseOptions(baseUrl: baseUrl, connectTimeout: connectTimeout),
  );
  dio.options.headers['X-Emby-Authorization'] = embyAuthHeader(
    mediaServerDeviceId,
  );
  return dio;
}

/// Pings `/System/Info/Public` and returns server name + version.
///
/// Does not require authentication — Emby/Jellyfin expose this endpoint
/// publicly so the user can verify they have the right URL before
/// entering credentials.
Future<ServerConnectionInfo> testMediaServerConnection(String url) async {
  final dio = createMediaServerDio(url);
  final client = MediaServerApiClient(dio, baseUrl: url);
  final info = await client.getPublicSystemInfo();
  return ServerConnectionInfo(
    serverName: info.serverName,
    version: info.version,
  );
}

/// Authenticates against an Emby server and returns a [PlaylistSource].
///
/// Creates its own [Dio] instance internally so callers don't need
/// to import `package:dio`.
Future<PlaylistSource> authenticateEmby(
  String url,
  String username,
  String password,
) async {
  final dio = createMediaServerDio(url);
  return authenticateMediaServer(
    dio,
    url,
    username,
    password,
    PlaylistSourceType.emby,
  );
}

/// Returns a [MediaServerAuthenticate] callback for the given [type].
///
/// The callback delegates to [authenticateMediaServer], accepting the
/// [Dio] instance that [MediaServerLoginScreen] creates internally.
/// This allows login screens to pass the callback without importing dio.
MediaServerAuthenticate authenticateMediaServerCallback(
  PlaylistSourceType type,
) {
  return (dio, url, username, password) =>
      authenticateMediaServer(dio, url, username, password, type);
}

/// Creates a pre-configured [Dio] for Jellyfin server probing.
///
/// Uses [NetworkTimeouts.fastConnectTimeout] for quick response.
Dio createJellyfinProbeDio(String baseUrl) {
  return Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: NetworkTimeouts.fastConnectTimeout,
    ),
  );
}

/// Creates a pre-configured [Dio] for Jellyfin Quick Connect flow.
///
/// Sets fast timeouts and the Emby authorization header.
Dio createQuickConnectDio() {
  return Dio(
    BaseOptions(
      connectTimeout: NetworkTimeouts.fastConnectTimeout,
      receiveTimeout: NetworkTimeouts.fastReceiveTimeout,
      headers: {'X-Emby-Authorization': embyAuthHeader(mediaServerDeviceId)},
    ),
  );
}

/// Creates a [Dio] and initiates a Jellyfin Quick Connect session.
///
/// Returns `{code, secret}` on success, or throws a user-friendly
/// error string on failure (e.g. 403 = Quick Connect disabled).
Future<Map<String, String>> initiateQuickConnect(String serverUrl) async {
  final dio = createQuickConnectDio();
  try {
    final response = await dio.post<Map<String, dynamic>>(
      '$serverUrl/QuickConnect/Initiate',
    );
    final data = response.data;
    if (data == null) {
      throw Exception('Server returned an empty response.');
    }
    final code = data['Code'] as String?;
    final secret = data['Secret'] as String?;
    if (code == null || secret == null) {
      throw Exception('Invalid Quick Connect response from server.');
    }
    return {'code': code, 'secret': secret};
  } on DioException catch (e) {
    final status = e.response?.statusCode;
    if (status == 403) {
      throw Exception(
        'Quick Connect is disabled on this Jellyfin server. '
        'Ask your administrator to enable it in the dashboard.',
      );
    }
    throw Exception('Cannot reach the server. Check the URL and your network.');
  }
}

/// Polls the Jellyfin Quick Connect endpoint for authorization.
///
/// Returns `true` when the user has approved the code.
Future<bool> pollQuickConnect(String serverUrl, String secret) async {
  final dio = createQuickConnectDio();
  try {
    final response = await dio.get<Map<String, dynamic>>(
      '$serverUrl/QuickConnect/Connect',
      queryParameters: {'secret': secret},
    );
    final data = response.data;
    if (data == null) return false;
    return data['Authenticated'] as bool? ?? false;
  } catch (_) {
    return false; // Non-fatal poll failure — retry on next tick.
  }
}

/// Exchanges an approved Quick Connect secret for an auth token.
///
/// Returns the [PlaylistSource] on success.
Future<PlaylistSource> exchangeQuickConnect(
  String serverUrl,
  String secret,
) async {
  final dio = createQuickConnectDio();
  final authResponse = await dio.post<Map<String, dynamic>>(
    '$serverUrl/Users/AuthenticateWithQuickConnect',
    data: {'Secret': secret},
    options: Options(headers: {'Content-Type': 'application/json'}),
  );
  final authData = authResponse.data;
  if (authData == null) {
    throw Exception('Token exchange returned an empty response.');
  }

  final systemInfo =
      await MediaServerApiClient(dio, baseUrl: serverUrl).getPublicSystemInfo();

  final user = authData['User'] as Map<String, dynamic>?;
  final token = authData['AccessToken'] as String?;

  if (user == null || token == null) {
    throw Exception('Malformed authentication response from server.');
  }

  return PlaylistSource(
    id: systemInfo.id,
    name: systemInfo.serverName,
    url: serverUrl,
    type: PlaylistSourceType.jellyfin,
    username: user['Name'] as String?,
    userId: user['Id'] as String?,
    accessToken: token,
    deviceId: mediaServerDeviceId,
  );
}

/// Threshold in bytes above which JSON decoding is offloaded to a
/// background isolate to avoid UI jank during large library syncs.
const int kMediaServerOffloadThresholdBytes = 50 * 1024;

/// Decodes UTF-8 response bytes, offloading to a background isolate
/// for payloads larger than [kMediaServerOffloadThresholdBytes].
///
/// Used as [BaseOptions.responseDecoder] for media server Dio instances.
FutureOr<String> lenientUtf8Decoder(
  List<int> responseBytes,
  RequestOptions options,
  ResponseBody responseBody,
) {
  if (responseBytes.length > kMediaServerOffloadThresholdBytes) {
    return compute(_decodeUtf8Isolate, responseBytes);
  }
  return utf8.decode(responseBytes, allowMalformed: true);
}

String _decodeUtf8Isolate(List<int> bytes) =>
    utf8.decode(bytes, allowMalformed: true);

/// Creates a [Dio] for Emby/Jellyfin sync with extended timeouts.
///
/// Sets the access token header and authorization header.
/// Callers should close the instance when done.
Dio createEmbyJellyfinSyncDio(
  String baseUrl, {
  String? accessToken,
  String? deviceId,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 120),
    ),
  );
  if (accessToken != null) {
    dio.options.headers['X-Emby-Token'] = accessToken;
  }
  dio.options.headers['X-Emby-Authorization'] = embyAuthHeader(deviceId);
  return dio;
}

/// Creates a [Dio] for Plex sync with lenient UTF-8 decoding.
///
/// Large payloads are decoded in a background isolate.
/// Callers should close the instance when done.
Dio createPlexSyncDio() {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      responseDecoder: lenientUtf8Decoder,
    ),
  );
}

/// Returns true if the given [error] is a retryable server/timeout error.
///
/// Only 5xx status codes and connection/receive timeouts are retryable.
/// Client errors (4xx) should not be retried.
bool isRetryableNetworkError(Object error) {
  if (error is DioException) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        (error.response?.statusCode != null &&
            error.response!.statusCode! >= 500);
  }
  return false;
}

/// Authenticates against a Plex server using a pre-existing token.
///
/// Creates its own [Dio] instance internally so callers don't need
/// to import `package:dio`.
Future<PlaylistSource> authenticatePlex(String url, String token) async {
  final client = PlexApiClient(dio: Dio());
  final serverInfo = await client.validateServer(
    url: url,
    token: token,
    clientIdentifier: PlexAuthService.clientIdentifier,
  );
  return PlaylistSource(
    id: 'plex_${url.hashCode}',
    name: serverInfo.name,
    url: url,
    type: PlaylistSourceType.plex,
    accessToken: token,
    deviceId: PlexAuthService.clientIdentifier,
  );
}
