import 'package:dio/dio.dart';

import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/core/network/network_timeouts.dart';
import 'package:crispy_tivi/features/media_servers/plex/data/datasources/plex_api_client.dart';
import 'package:crispy_tivi/features/media_servers/plex/data/datasources/plex_auth_service.dart';
import 'package:crispy_tivi/features/media_servers/shared/data/media_server_api_client.dart';
import 'package:crispy_tivi/features/media_servers/shared/presentation/screens/media_server_login_screen.dart';
import 'package:crispy_tivi/features/media_servers/shared/utils/media_server_auth.dart';

/// Creates a pre-configured [Dio] instance for media server communication.
///
/// Sets the base URL and Emby/Jellyfin authorization header.
/// Lives in the data layer so presentation code never imports `package:dio`.
Dio createMediaServerDio(String baseUrl, {Duration? connectTimeout}) {
  final dio = Dio(
    BaseOptions(baseUrl: baseUrl, connectTimeout: connectTimeout),
  );
  dio.options.headers['X-Emby-Authorization'] = embyAuthHeader(
    MediaServerLoginScreen.kDeviceId,
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
      headers: {
        'X-Emby-Authorization': embyAuthHeader(
          MediaServerLoginScreen.kDeviceId,
        ),
      },
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
    deviceId: MediaServerLoginScreen.kDeviceId,
  );
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
