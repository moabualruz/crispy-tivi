import 'package:dio/dio.dart';

import '../../../../core/data/crispy_backend.dart';
import 'stalker_portal_api.dart';
import 'stalker_portal_parser.dart';

export 'stalker_portal_api.dart';
export 'stalker_portal_parser.dart';
export 'stalker_portal_result.dart';

/// Stalker Portal (MAG middleware) API client.
///
/// Handles MAC address authentication, token
/// management, and delegation of JSON parsing to
/// the Rust backend.
///
/// Usage:
/// ```dart
/// final client = StalkerPortalClient(
///   baseUrl: 'http://provider.com',
///   macAddress: '00:1A:2B:3C:4D:5E',
///   backend: crispyBackend,
/// );
/// await client.authenticate(dio);
/// final channels =
///     await client.fetchLiveChannels(dio);
/// ```
class StalkerPortalClient with StalkerPortalParser, StalkerPortalApi {
  /// Creates a Stalker Portal API client.
  ///
  /// [baseUrl] is normalized to
  /// `scheme://host:port` (paths stripped).
  /// [macAddress] must be in format
  /// `XX:XX:XX:XX:XX:XX`.
  /// [backend] is the Rust backend for parsing.
  /// Throws [ArgumentError] for invalid inputs.
  StalkerPortalClient({
    required String baseUrl,
    required this.macAddress,
    required CrispyBackend backend,
    this.userAgent = 'MAG250/1.0 (CrispyTivi)',
  }) : _backend = backend {
    _validateMacAddress(macAddress);

    if (baseUrl.isEmpty) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'Must not be empty');
    }

    // Normalize via Rust backend.
    final normalized = _backend.normalizeApiBaseUrl(baseUrl);
    if (!normalized.contains('://')) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'Invalid URL format');
    }
    _baseUrl = normalized;
  }

  late final String _baseUrl;

  /// Rust backend for parsing delegation.
  final CrispyBackend _backend;

  @override
  CrispyBackend get parserBackend => _backend;

  /// Normalized base URL (scheme://host:port).
  @override
  String get baseUrl => _baseUrl;

  @override
  String get portalUrl => '$_baseUrl$_portalPath';

  /// MAC address for authentication.
  final String macAddress;

  /// User-Agent header value (MAG device
  /// emulation).
  final String userAgent;

  /// Access token obtained after authentication.
  String? _accessToken;

  /// Token expiry time.
  DateTime? _tokenExpiry;

  /// Checks if authenticated and token is still
  /// valid.
  @override
  bool get isAuthenticated =>
      _accessToken != null &&
      _tokenExpiry != null &&
      DateTime.now().isBefore(_tokenExpiry!);

  // ── Authentication ──────────────────────────

  /// Authenticates with the portal and obtains an
  /// access token.
  ///
  /// Stalker portals use various authentication
  /// endpoints:
  /// - `/stalker_portal/server/load.php?type=stb
  ///    &action=handshake`
  /// - `/portal.php?type=stb&action=handshake`
  ///
  /// This tries common endpoint patterns.
  @override
  Future<void> authenticate(Dio dio) async {
    // Try common Stalker portal paths
    final paths = [
      '/stalker_portal/server/load.php',
      '/portal.php',
      '/server/load.php',
      '/c/',
    ];

    Exception? lastError;

    for (final path in paths) {
      try {
        final response = await dio.get(
          '$_baseUrl$path',
          queryParameters: {
            'type': 'stb',
            'action': 'handshake',
            'token': '',
            'JsHttpRequest': '1-xml',
          },
          options: buildOptions(),
        );

        final data = response.data;
        if (data is Map<String, dynamic>) {
          final js = data['js'] as Map<String, dynamic>?;
          if (js != null && js['token'] != null) {
            _accessToken = js['token'] as String;
            _tokenExpiry = DateTime.now().add(const Duration(hours: 1));
            _portalPath = path;

            // Perform profile authorization
            await _doAuth(dio);
            return;
          }
        }
      } on DioException catch (e) {
        lastError = e;
        continue;
      }
    }

    throw lastError ??
        Exception(
          'Failed to authenticate with '
          'Stalker portal',
        );
  }

  String _portalPath = '/stalker_portal/server/load.php';

  /// Performs STB authorization after handshake.
  Future<void> _doAuth(Dio dio) async {
    await dio.get(
      '$_baseUrl$_portalPath',
      queryParameters: {
        'type': 'stb',
        'action': 'do_auth',
        'login': '',
        'password': '',
        'device_id': _deviceId,
        'device_id2': _deviceId,
        'JsHttpRequest': '1-xml',
      },
      options: buildOptions(),
    );
  }

  String get _deviceId => _backend.macToDeviceId(macAddress);

  // ── URL Builders ────────────────────────────

  /// Extracts stream URL from channel cmd via
  /// Rust backend.
  ///
  /// Stalker `cmd` field may contain:
  /// - Full URL: `http://...`
  /// - Relative path: `/live/...`
  /// - Command format: `ffrt http://...`
  String buildStreamUrl(String cmd) {
    return _backend.buildStalkerStreamUrl(cmd, _baseUrl);
  }

  /// Builds catch-up/timeshift URL for a past
  /// programme.
  ///
  /// Format varies by portal, common patterns:
  /// - `baseUrl/timeshift/duration/start/
  ///    streamId.ts`
  String catchupUrl(
    String cmd, {
    required int startUtc,
    required int durationMinutes,
  }) {
    final streamUrl = buildStreamUrl(cmd);
    return '$streamUrl?utc=$startUtc'
        '&lutc=${startUtc + durationMinutes * 60}';
  }

  // ── Private Helpers ─────────────────────────

  @override
  Options buildOptions() {
    final cookies = [
      'mac=$macAddress',
      'stb_lang=en',
      'timezone=UTC',
    ].join('; ');

    return Options(
      headers: {
        'User-Agent': userAgent,
        'Cookie': cookies,
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
        'X-User-Agent': 'Model: MAG250; Link: WiFi',
      },
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 15),
    );
  }

  /// Validates MAC address format via Rust
  /// backend.
  void _validateMacAddress(String mac) {
    if (!_backend.validateMacAddress(mac)) {
      throw ArgumentError.value(
        mac,
        'macAddress',
        'Invalid MAC address format. '
            'Expected XX:XX:XX:XX:XX:XX',
      );
    }
  }

  /// Verifies a Stalker Portal is reachable and
  /// responds to the handshake protocol.
  ///
  /// Returns `null` on success, or an error message
  /// string on failure. Does not require a
  /// [CrispyBackend] instance.
  static Future<String?> verifyPortal({
    required Dio dio,
    required String serverUrl,
    required String macAddress,
  }) async {
    final base = serverUrl.replaceAll(RegExp(r'/+$'), '');
    final paths = [
      '/stalker_portal/server/load.php',
      '/portal.php',
      '/server/load.php',
      '/c/',
    ];
    final cookies = 'mac=$macAddress; stb_lang=en; timezone=UTC';
    final options = Options(
      headers: {
        'User-Agent': 'MAG250/1.0 (CrispyTivi)',
        'Cookie': cookies,
        'X-User-Agent': 'Model: MAG250; Link: WiFi',
      },
      receiveTimeout: const Duration(seconds: 15),
    );

    for (final path in paths) {
      try {
        final response = await dio.get<dynamic>(
          '$base$path',
          queryParameters: {
            'type': 'stb',
            'action': 'handshake',
            'token': '',
            'JsHttpRequest': '1-xml',
          },
          options: options,
        );
        if (response.data is Map<String, dynamic>) {
          final js = (response.data as Map<String, dynamic>)['js'];
          if (js is Map<String, dynamic> && js['token'] != null) {
            return null; // Success
          }
        }
      } on DioException {
        continue;
      }
    }
    return 'Could not connect to Stalker portal. '
        'Check the URL and MAC address.';
  }
}
