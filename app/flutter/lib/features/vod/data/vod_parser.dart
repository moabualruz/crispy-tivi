import 'dart:convert';

import '../../../core/data/cache_service.dart';
import '../../../core/data/crispy_backend.dart';
import '../domain/entities/vod_item.dart';

/// Parses VOD data by delegating to the Rust
/// [CrispyBackend] and converting results via
/// [CacheService] converters.
///
/// All methods are static and accept a [backend]
/// parameter for FFI delegation.
class VodParser {
  const VodParser._();

  /// Parses Xtream `get_vod_streams` response into
  /// movies via Rust backend.
  static Future<List<VodItem>> parseVodStreams(
    List<dynamic> data,
    CrispyBackend backend, {
    required String baseUrl,
    required String username,
    required String password,
    String? sourceId,
  }) async {
    final json = jsonEncode(data);
    final maps = await backend.parseVodStreams(
      json,
      baseUrl: baseUrl,
      username: username,
      password: password,
      sourceId: sourceId,
    );
    return maps.map(mapToVodItem).toList();
  }

  /// Parses Xtream `get_series` response into series
  /// containers via Rust backend.
  static Future<List<VodItem>> parseSeries(
    List<dynamic> data,
    CrispyBackend backend, {
    String? sourceId,
  }) async {
    final json = jsonEncode(data);
    final maps = await backend.parseSeries(json, sourceId: sourceId);
    return maps.map(mapToVodItem).toList();
  }

  /// Parses episodes from `get_series_info` response
  /// via Rust backend.
  static Future<List<VodItem>> parseEpisodes(
    Map<String, dynamic> seriesInfo,
    CrispyBackend backend, {
    required String baseUrl,
    required String username,
    required String password,
    required String seriesId,
  }) async {
    final json = jsonEncode(seriesInfo);
    final maps = await backend.parseEpisodes(
      json,
      baseUrl: baseUrl,
      username: username,
      password: password,
      seriesId: seriesId,
    );
    return maps.map(mapToVodItem).toList();
  }

  /// Parses VOD entries from raw M3U lines via Rust
  /// backend.
  static Future<List<VodItem>> parseM3uVod(
    List<dynamic> m3uChannels,
    CrispyBackend backend, {
    String? sourceId,
  }) async {
    final json = jsonEncode(m3uChannels);
    final maps = await backend.parseM3uVod(json, sourceId: sourceId);
    return maps.map(mapToVodItem).toList();
  }
}
