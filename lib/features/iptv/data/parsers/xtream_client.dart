import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/data/cache_service.dart';
import '../../../../core/data/crispy_backend.dart';
import '../../../../core/network/http_service.dart';
import '../../domain/entities/channel.dart';

/// Xtream Codes API client — delegates URL building and
/// parsing to the Rust backend via [CrispyBackend].
///
/// Handles URL normalization, API action requests, and
/// conversion of Xtream JSON responses to domain entities.
///
/// Usage:
/// ```dart
/// final client = XtreamClient(
///   baseUrl: 'http://provider.com:8080',
///   username: 'user',
///   password: 'pass',
///   backend: crispyBackend,
/// );
/// // Use with Dio for actual HTTP calls:
/// final response = await dio.get(
///   client.buildActionUrl('get_live_streams'),
/// );
/// final channels = await client.parseLiveStreams(
///   response.data,
/// );
/// ```
class XtreamClient {
  /// Creates an Xtream Codes API client.
  ///
  /// [baseUrl] is normalized to `scheme://host:port`
  /// (paths stripped).
  /// Throws [ArgumentError] for empty or invalid URLs.
  XtreamClient({
    required String baseUrl,
    required this.username,
    required this.password,
    required CrispyBackend backend,
    this.userAgent = 'CrispyTivi/1.0',
  }) : _backend = backend {
    if (baseUrl.isEmpty) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'Must not be empty');
    }

    // Normalize via Rust backend.
    final normalized = backend.normalizeApiBaseUrl(baseUrl);
    if (!normalized.contains('://')) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'Invalid URL format');
    }
    _baseUrl = normalized;
  }

  final CrispyBackend _backend;
  late final String _baseUrl;

  /// Normalized base URL (scheme://host:port).
  String get baseUrl => _baseUrl;

  /// Xtream Codes username.
  final String username;

  /// Xtream Codes password.
  final String password;

  /// User-Agent header value.
  final String userAgent;

  // ── URL Builders ─────────────────────────────────────────

  /// Builds the full player_api.php URL for a given
  /// [action].
  String buildActionUrl(String action, {Map<String, String>? params}) {
    return _backend.buildXtreamActionUrl(
      baseUrl: _baseUrl,
      username: username,
      password: password,
      action: action,
      paramsJson: params != null ? jsonEncode(params) : null,
    );
  }

  /// Builds a live stream URL for the given [streamId].
  ///
  /// Format: `baseUrl/live/username/password/streamId.ts`
  String liveStreamUrl(int streamId) {
    return _backend.buildXtreamStreamUrl(
      baseUrl: _baseUrl,
      username: username,
      password: password,
      streamId: streamId,
      streamType: 'live',
      extension: 'ts',
    );
  }

  /// Builds a VOD (movie) stream URL.
  ///
  /// Format:
  /// `baseUrl/movie/username/password/streamId.ext`
  String vodStreamUrl(int streamId, {String extension = 'mp4'}) {
    return _backend.buildXtreamStreamUrl(
      baseUrl: _baseUrl,
      username: username,
      password: password,
      streamId: streamId,
      streamType: 'movie',
      extension: extension,
    );
  }

  /// Builds a series episode stream URL.
  ///
  /// Format:
  /// `baseUrl/series/username/password/streamId.ext`
  String seriesStreamUrl(int streamId, {String extension = 'mkv'}) {
    return _backend.buildXtreamStreamUrl(
      baseUrl: _baseUrl,
      username: username,
      password: password,
      streamId: streamId,
      streamType: 'series',
      extension: extension,
    );
  }

  /// Builds a catch-up/timeshift stream URL.
  ///
  /// [streamId] - The live stream ID.
  /// [startUtc] - Programme start time (Unix seconds).
  /// [durationMinutes] - Programme duration in minutes.
  String catchupUrl(
    int streamId, {
    required int startUtc,
    required int durationMinutes,
  }) {
    return _backend.buildXtreamCatchupUrl(
      baseUrl: _baseUrl,
      username: username,
      password: password,
      streamId: streamId,
      startUtc: startUtc,
      durationMinutes: durationMinutes,
    );
  }

  // ── JSON Parsers ───────────────────────────────────────

  /// Parses Xtream's `get_live_streams` JSON into
  /// [Channel] list via Rust backend.
  ///
  /// The Rust side returns a JSON string of Channel
  /// array. Dart decodes it back to Channel objects
  /// using [mapToChannel].
  Future<List<Channel>> parseLiveStreams(List<dynamic> data) async {
    final result = await _backend.parseXtreamLiveStreams(
      jsonEncode(data),
      baseUrl: _baseUrl,
      username: username,
      password: password,
    );
    final list = jsonDecode(result) as List<dynamic>;
    return list.map((m) => mapToChannel(m as Map<String, dynamic>)).toList();
  }

  /// Parses category lists (live/vod/series) into
  /// sorted names via Rust backend.
  Future<List<String>> parseCategories(dynamic data) async {
    if (data == null || data is! List) return [];
    final result = await _backend.parseXtreamCategories(jsonEncode(data));
    final list = jsonDecode(result) as List<dynamic>;
    return list.cast<String>();
  }

  /// Provides [Dio] options with correct timeout
  /// and user-agent.
  Options get dioOptions => Options(
    headers: {'User-Agent': userAgent},
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(seconds: 30),
  );

  /// Verifies Xtream Codes credentials by calling the
  /// server info endpoint (no action parameter).
  ///
  /// Returns `null` on success, or an error message string
  /// on failure. Works without a [CrispyBackend] instance.
  static Future<String?> verifyCredentials({
    required HttpService http,
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final base = serverUrl.replaceAll(RegExp(r'/+$'), '');
    final url = '$base/player_api.php?username=$username&password=$password';
    try {
      final data = await http.getJson(url);
      if (data is! Map) return 'Invalid server response.';
      final userInfo = data['user_info'];
      if (userInfo is! Map) return 'Invalid server response.';
      final auth = userInfo['auth'];
      if (auth == 1 || auth == '1') return null; // Success
      final status = userInfo['status']?.toString() ?? 'unknown';
      return 'Authentication failed (status: $status).';
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return 'Connection timed out. Check the server URL.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Could not connect to server. Check the URL.';
      }
      return 'Connection error: ${e.message}';
    } catch (e) {
      return 'Verification failed: $e';
    }
  }
}
