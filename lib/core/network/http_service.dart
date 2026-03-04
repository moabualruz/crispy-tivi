import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Centralized HTTP client for all network requests.
///
/// Provides pre-configured Dio instance with:
/// - Timeouts (connect: 15s, receive: 60s)
/// - User-Agent header
/// - Response logging (debug only)
class HttpService {
  HttpService() : _dio = Dio(_defaultOptions);

  final Dio _dio;

  static final _defaultOptions = BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 60),
    headers: kIsWeb ? null : {'User-Agent': 'CrispyTivi/1.0'},
  );

  /// Returns the raw Dio instance for advanced use cases.
  Dio get dio => _dio;

  /// GET request returning response body as [String].
  Future<String> getString(String url, {Map<String, String>? headers}) async {
    final response = await _dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain, headers: headers),
    );
    return response.data ?? '';
  }

  /// GET request returning parsed JSON as [dynamic].
  Future<dynamic> getJson(String url, {Map<String, String>? headers}) async {
    final response = await _dio.get<dynamic>(
      url,
      options: Options(responseType: ResponseType.json, headers: headers),
    );
    return response.data;
  }

  /// GET request returning parsed JSON [List].
  Future<List<dynamic>> getJsonList(
    String url, {
    Map<String, String>? headers,
  }) async {
    final data = await getJson(url, headers: headers);
    if (data is List) return data;
    return [];
  }
}

/// Global HTTP service provider.
final httpServiceProvider = Provider<HttpService>((ref) => HttpService());
