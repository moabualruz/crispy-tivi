import 'dart:async';

import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/core/failures/failure.dart';

import 'plex_api_client.dart';

/// Result of a successful Plex OAuth flow.
class PlexOAuthResult {
  const PlexOAuthResult({required this.authToken, required this.servers});

  /// The plex.tv user auth token (X-Plex-Token).
  final String authToken;

  /// Servers available to the authenticated user.
  final List<PlexOAuthServer> servers;
}

/// A Plex Media Server discovered from plex.tv resources.
class PlexOAuthServer {
  const PlexOAuthServer({
    required this.name,
    required this.scheme,
    required this.host,
    required this.port,
    required this.accessToken,
    required this.owned,
  });

  /// Human-readable server name (e.g. `'My Plex Server'`).
  final String name;

  /// URL scheme (`'http'` or `'https'`).
  final String scheme;

  /// Server hostname or IP address.
  final String host;

  /// Server port number.
  final int port;

  /// Token scoped to this particular server.
  final String accessToken;

  /// Whether the authenticated user owns this server.
  final bool owned;

  /// Full base URL constructed from scheme, host, port.
  String get baseUrl => '$scheme://$host:$port';
}

/// Plex OAuth flow result used by the presentation layer.
class PlexOAuthState {
  const PlexOAuthState({
    required this.pinCode,
    required this.expiresAt,
    this.servers,
    this.authToken,
  });

  /// Human-readable PIN code displayed to the user.
  final String pinCode;

  /// When this PIN session expires.
  final DateTime expiresAt;

  /// Auth token — non-null after successful authorization.
  final String? authToken;

  /// Servers — non-null after successful authorization and resource fetch.
  final List<PlexOAuthServer>? servers;

  /// Whether the OAuth flow is waiting for the user to approve.
  bool get isWaiting => authToken == null;

  /// Remaining seconds before expiry.
  int get secondsRemaining {
    final diff = expiresAt.difference(DateTime.now()).inSeconds;
    return diff < 0 ? 0 : diff;
  }
}

/// Service that implements the Plex PIN-based OAuth flow.
///
/// Flow:
/// 1. POST `https://plex.tv/api/v2/pins` → get [pinId] + [pinCode].
/// 2. Open browser to `https://app.plex.tv/auth#?clientID=…&code=…`.
/// 3. Poll `GET https://plex.tv/api/v2/pins/{pinId}` every 2 s.
/// 4. When claimed, exchange for user token and fetch servers from
///    `GET https://plex.tv/api/v2/resources?includeHttps=1`.
class PlexAuthService {
  PlexAuthService({Dio? plexTvDio, PlexApiClient? apiClient})
    : _dio = plexTvDio ?? Dio(),
      _apiClient = apiClient ?? PlexApiClient();

  static const _kPlexTvBase = 'https://plex.tv';
  static const _kAuthBase = 'https://app.plex.tv';
  static const _kPollIntervalSeconds = 2;
  static const _kClientName = 'CrispyTivi';
  static const String clientIdentifier = 'crispy-tivi';

  final Dio _dio;
  final PlexApiClient _apiClient;

  /// Initiates a PIN-based OAuth session.
  ///
  /// Returns the [PlexOAuthState] with the PIN code and expiry. The
  /// caller is responsible for opening the browser and polling.
  Future<({int pinId, PlexOAuthState state})> initiate() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_kPlexTvBase/api/v2/pins',
        data: {
          'strong': 'true',
          'X-Plex-Client-Identifier': clientIdentifier,
          'X-Plex-Product': _kClientName,
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
            'X-Plex-Client-Identifier': clientIdentifier,
            'X-Plex-Product': _kClientName,
          },
        ),
      );

      final data = response.data;
      if (data == null) {
        throw const ServerFailure(message: 'Empty response from plex.tv');
      }

      final pinId = data['id'] as int?;
      final code = data['code'] as String?;
      final expiresInSeconds = data['expiresIn'] as int? ?? 1800;

      if (pinId == null || code == null) {
        throw const ServerFailure(message: 'Invalid PIN response from plex.tv');
      }

      return (
        pinId: pinId,
        state: PlexOAuthState(
          pinCode: code,
          expiresAt: DateTime.now().add(Duration(seconds: expiresInSeconds)),
        ),
      );
    } on DioException catch (e) {
      throw ServerFailure(
        message: e.message ?? 'Cannot reach plex.tv. Check your connection.',
      );
    }
  }

  /// Opens the Plex auth page in the platform browser.
  Future<void> openAuthPage(String pinCode) async {
    final uri = Uri.parse(
      '$_kAuthBase/auth'
      '#?clientID=$clientIdentifier'
      '&code=$pinCode'
      '&context%5Bdevice%5D%5Bproduct%5D=${Uri.encodeComponent(_kClientName)}',
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw const ServerFailure(
        message: 'Could not open the browser. Please open the URL manually.',
      );
    }
  }

  /// Polls plex.tv until the PIN is claimed.
  ///
  /// Resolves with the user auth token when approved, or throws
  /// [ServerFailure] when the PIN expires.
  ///
  /// [onTick] is called on each poll with the latest [PlexOAuthState].
  Future<String> pollForAuth({
    required int pinId,
    required PlexOAuthState initialState,
    void Function(PlexOAuthState)? onTick,
  }) async {
    final completer = Completer<String>();
    PlexOAuthState current = initialState;

    Timer.periodic(const Duration(seconds: _kPollIntervalSeconds), (
      timer,
    ) async {
      if (current.secondsRemaining <= 0) {
        timer.cancel();
        completer.completeError(
          const ServerFailure(message: 'Plex authorization timed out.'),
        );
        return;
      }

      try {
        final response = await _dio.get<Map<String, dynamic>>(
          '$_kPlexTvBase/api/v2/pins/$pinId',
          options: Options(
            headers: {
              'Accept': 'application/json',
              'X-Plex-Client-Identifier': clientIdentifier,
            },
          ),
        );

        final data = response.data;
        final authToken = data?['authToken'] as String?;

        current = PlexOAuthState(
          pinCode: current.pinCode,
          expiresAt: current.expiresAt,
          authToken: authToken,
        );

        onTick?.call(current);

        if (authToken != null && authToken.isNotEmpty) {
          timer.cancel();
          if (!completer.isCompleted) {
            completer.complete(authToken);
          }
        }
      } catch (_) {
        // Non-fatal — retry on next tick.
      }
    });

    return completer.future;
  }

  /// Fetches the list of Plex servers for the authenticated user.
  ///
  /// Uses `GET https://plex.tv/api/v2/resources?includeHttps=1`.
  Future<List<PlexOAuthServer>> fetchServers(String authToken) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '$_kPlexTvBase/api/v2/resources',
        queryParameters: {'includeHttps': '1', 'includeRelay': '0'},
        options: Options(
          headers: {
            'Accept': 'application/json',
            'X-Plex-Token': authToken,
            'X-Plex-Client-Identifier': clientIdentifier,
          },
        ),
      );

      final resources = response.data ?? [];
      final servers = <PlexOAuthServer>[];

      for (final resource in resources) {
        final map = resource as Map<String, dynamic>;
        final provides = (map['provides'] as String? ?? '').split(',');
        if (!provides.contains('server')) continue;

        final name = (map['name'] as String?) ?? 'Plex Server';
        final token = (map['accessToken'] as String?) ?? authToken;
        final owned = (map['owned'] as bool?) ?? false;

        final connections = map['connections'] as List<dynamic>? ?? [];
        for (final conn in connections) {
          final c = conn as Map<String, dynamic>;
          final scheme = c['protocol'] as String? ?? 'http';
          final host = c['address'] as String?;
          final port = c['port'] as int?;
          // Prefer local connections.
          final isLocal = c['local'] as bool? ?? false;
          if (host == null || port == null) continue;
          if (isLocal) {
            servers.insert(
              0,
              PlexOAuthServer(
                name: name,
                scheme: scheme,
                host: host,
                port: port,
                accessToken: token,
                owned: owned,
              ),
            );
          } else {
            servers.add(
              PlexOAuthServer(
                name: name,
                scheme: scheme,
                host: host,
                port: port,
                accessToken: token,
                owned: owned,
              ),
            );
          }
          break; // Use first connection per server.
        }
      }

      return servers;
    } on DioException catch (e) {
      throw ServerFailure(
        message: e.message ?? 'Failed to fetch Plex servers.',
      );
    }
  }

  /// Converts a [PlexOAuthServer] into a [PlaylistSource] by validating
  /// the server connection via [PlexApiClient.validateServer].
  Future<PlaylistSource> buildSource(PlexOAuthServer server) async {
    final plexServer = await _apiClient.validateServer(
      url: server.baseUrl,
      token: server.accessToken,
      clientIdentifier: clientIdentifier,
    );

    return PlaylistSource(
      id: 'plex_${server.baseUrl.hashCode}',
      name: plexServer.name,
      url: server.baseUrl,
      type: PlaylistSourceType.plex,
      accessToken: server.accessToken,
      deviceId: clientIdentifier,
    );
  }
}
