import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'http_client_native.dart'
    if (dart.library.js_interop) 'http_client_web.dart';
import 'network_timeouts.dart';

/// Centralized HTTP client for all network requests.
///
/// Provides pre-configured Dio instance with:
/// - Timeouts (connect: 15s, receive: 120s)
/// - User-Agent header
/// - Disabled automatic gzip decompression on native platforms
///   (Dart SDK #32994: streaming zlib filter drops last chunks)
/// - Resilient JSON parsing for large IPTV responses
class HttpService {
  HttpService() : _dio = Dio(_defaultOptions) {
    // Disable dart:io's HttpClient.autoUncompress on native platforms.
    // Dart's streaming zlib filter silently drops trailing bytes on
    // large gzip responses (Dart SDK #32994, Dio #1352), causing
    // "FormatException: Filter error, bad data" or truncated JSON.
    // With autoUncompress=false + Accept-Encoding: identity, the
    // server sends uncompressed data and Dart never touches zlib.
    configureNativeHttpClient(_dio);
  }

  final Dio _dio;

  /// Server base URL for the web CORS relay proxy.
  ///
  /// Set once at startup from `main.dart` on web builds.
  static String? proxyBaseUrl;

  static final _defaultOptions = BaseOptions(
    connectTimeout: NetworkTimeouts.connectTimeout,
    receiveTimeout: NetworkTimeouts.receiveTimeout,
    headers:
        kIsWeb
            ? null
            : {
              'User-Agent': 'CrispyTivi/1.0',
              // Tell server not to compress — we disabled autoUncompress
              // so Dart won't decode gzip even if the server ignores this.
              'Accept-Encoding': 'identity',
            },
  );

  /// Returns the raw Dio instance for advanced use cases.
  Dio get dio => _dio;

  /// GET request returning response body as [String].
  Future<String> getString(String url, {Map<String, String>? headers}) async {
    final response = await _dio.get<String>(
      _resolveUrl(url),
      options: Options(responseType: ResponseType.plain, headers: headers),
    );
    return response.data ?? '';
  }

  /// GET request returning parsed JSON as [dynamic].
  Future<dynamic> getJson(String url, {Map<String, String>? headers}) async {
    final response = await _dio.get<dynamic>(
      _resolveUrl(url),
      options: Options(responseType: ResponseType.json, headers: headers),
    );
    return response.data;
  }

  /// GET request returning parsed JSON [List].
  ///
  /// Uses resilient parsing to handle common IPTV server issues:
  /// - Truncated responses (missing closing `]`)
  /// - Bad unicode escapes (lone surrogates from PHP servers)
  /// - Malformed UTF-8 characters
  ///
  /// Falls back to standard [getJson] for small responses.
  Future<List<dynamic>> getJsonList(
    String url, {
    Map<String, String>? headers,
  }) async {
    // Fetch as raw bytes for binary-safe handling of large responses.
    final response = await _dio.get<List<int>>(
      _resolveUrl(url),
      options: Options(responseType: ResponseType.bytes, headers: headers),
    );
    final rawBytes = response.data;
    if (rawBytes == null || rawBytes.isEmpty) return [];

    // Some IPTV servers ignore Accept-Encoding: identity and send gzip
    // regardless. With autoUncompress=false we get raw gzip bytes —
    // detect and decompress manually.
    final bytes = decompressIfGzip(rawBytes);

    // Decode UTF-8 with malformed-character tolerance.
    var str = utf8.decode(bytes, allowMalformed: true);
    if (str.isEmpty) return [];

    // Fast path: try standard parse first.
    try {
      final data = jsonDecode(str);
      if (data is List) return data;
      return [];
    } on FormatException catch (e) {
      debugPrint(
        'HttpService: JSON parse failed at offset ${e.offset}, '
        'attempting recovery for ${bytes.length} bytes',
      );
    }

    // ── Recovery: sanitize common IPTV server JSON issues ──
    str = _sanitizeJson(str);

    // Fix truncated JSON array: find the last complete object and
    // close the array.
    if (str.trimLeft().startsWith('[')) {
      final lastBrace = str.lastIndexOf('}');
      if (lastBrace > 0) {
        final tail = str.substring(lastBrace + 1).trim();
        if (tail.isEmpty || tail == ',' || !tail.endsWith(']')) {
          str = '${str.substring(0, lastBrace + 1)}]';
        }
      }
    }

    try {
      final data = jsonDecode(str);
      if (data is List) {
        debugPrint(
          'HttpService: JSON recovery succeeded — ${data.length} items',
        );
        return data;
      }
    } on FormatException catch (e) {
      debugPrint('HttpService: JSON recovery failed: $e');
    }
    return [];
  }

  // ── Regex patterns compiled once for reuse across calls ──

  static final _invalidEscape = RegExp(r'\\(?!["\\/bfnrtu])');
  static final _truncatedUnicode = RegExp(
    r'\\u([0-9a-fA-F]{3})(?![0-9a-fA-F])',
  );
  static final _loneHighSurrogate = RegExp(
    r'\\u[dD][89aAbB][0-9a-fA-F]{2}'
    r'(?!\\u[dD][cCdDeEfF][0-9a-fA-F]{2})',
  );
  static final _loneLowSurrogate = RegExp(
    r'(?<!\\u[dD][89aAbB][0-9a-fA-F]{2})'
    r'\\u[dD][cCdDeEfF][0-9a-fA-F]{2}',
  );
  // Missing opening quote after key: "key":value" → "key":"value"
  // Only matches after `":` to avoid false positives inside strings.
  static final _missingOpenQuote = RegExp(r'":\s*([a-zA-Z_][a-zA-Z0-9_.]*)"');

  /// Sanitizes common IPTV server JSON malformations.
  static String _sanitizeJson(String str) {
    var sanitized = str;
    // Fix invalid escape sequences (\0, \x, \a, etc.) → remove backslash
    sanitized = sanitized.replaceAll(_invalidEscape, '');
    // Fix truncated unicode escapes: \uXXX → \u0XXX
    sanitized = sanitized.replaceAllMapped(
      _truncatedUnicode,
      (m) => '\\u0${m[1]}',
    );
    // Fix lone surrogates → replacement character
    sanitized = sanitized.replaceAll(_loneHighSurrogate, r'\uFFFD');
    sanitized = sanitized.replaceAll(_loneLowSurrogate, r'\uFFFD');
    // Fix missing opening quotes on values (Xtream bug)
    sanitized = sanitized.replaceAllMapped(
      _missingOpenQuote,
      (m) => '":"${m[1]}"',
    );
    return sanitized;
  }

  /// Verifies an M3U URL is reachable.
  ///
  /// Sends a HEAD request to check server connectivity.
  /// Returns `null` on success, or an error message string
  /// on failure.
  static Future<String?> verifyM3uUrl({
    required HttpService http,
    required String url,
  }) async {
    try {
      await http._dio.head<void>(
        url,
        options: Options(receiveTimeout: NetworkTimeouts.verifyReceiveTimeout),
      );
      return null; // Server reachable
    } on DioException catch (e) {
      // 405 = server reachable but doesn't support HEAD.
      if (e.response?.statusCode == 405) return null;
      return _dioErrorMessage(e);
    } catch (e) {
      return 'Verification failed: $e';
    }
  }

  static String _dioErrorMessage(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      return 'Connection timed out. Check the URL.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Could not connect to server. Check the URL.';
    }
    final status = e.response?.statusCode;
    if (status != null) {
      return 'Server returned error $status.';
    }
    return 'Connection error: ${e.message}';
  }

  /// Routes external web requests through the Rust `/proxy` endpoint.
  ///
  /// This keeps browser-side API calls working against IPTV providers that
  /// do not send permissive CORS headers.
  static String _resolveUrl(String url) {
    if (!kIsWeb) return url;
    final base = proxyBaseUrl;
    if (base == null || base.isEmpty || !url.startsWith('http')) {
      return url;
    }
    if (url.startsWith(base)) {
      return url;
    }
    return '$base/proxy?url=${Uri.encodeComponent(url)}';
  }
}

/// Global HTTP service provider.
final httpServiceProvider = Provider<HttpService>((ref) => HttpService());
