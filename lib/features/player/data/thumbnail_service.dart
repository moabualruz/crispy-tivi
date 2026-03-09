import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/data/crispy_backend.dart';
import '../domain/entities/thumbnail_sprite.dart';
import 'bif_thumbnail_data.dart';
import 'vtt_parser.dart';

/// Maximum number of cached thumbnail sources.
///
/// 10 entries × ~500 KB–5 MB = ~5–50 MB max memory.
const kMaxThumbnailCacheEntries = 10;

/// Simple LRU cache backed by a [LinkedHashMap].
///
/// Insertion order tracks recency (most recent at tail).
/// When [maxSize] is exceeded the oldest (head) entry is
/// evicted.
class _LruCache<K, V> {
  _LruCache(this.maxSize);

  final int maxSize;
  final _map = <K, V>{};

  V? operator [](K key) {
    final value = _map.remove(key);
    if (value != null) {
      _map[key] = value; // move to tail (MRU)
    }
    return value;
  }

  void operator []=(K key, V value) {
    _map.remove(key);
    _map[key] = value;
    if (_map.length > maxSize) {
      _map.remove(_map.keys.first); // evict LRU
    }
  }

  bool containsKey(K key) => _map.containsKey(key);
  void remove(K key) => _map.remove(key);
  void clear() => _map.clear();
}

/// Service for loading video thumbnail data.
///
/// Attempts to load thumbnails from various sources
/// in order:
/// 1. WebVTT sprite sheets (Jellyfin, Plex, Emby)
/// 2. BIF trickplay files (Plex, Emby)
/// 3. Returns null if no thumbnails available
class ThumbnailService {
  ThumbnailService({Dio? dio, required CrispyBackend backend})
    : _dio = dio ?? Dio(),
      _backend = backend,
      _vttParser = VttParser(backend);

  final Dio _dio;
  final CrispyBackend _backend;
  final VttParser _vttParser;

  /// LRU cache of loaded thumbnail sources by stream URL.
  final _LruCache<String, ThumbnailSource?> _cache = _LruCache(
    kMaxThumbnailCacheEntries,
  );

  /// Attempts to load thumbnail data for a VOD stream.
  ///
  /// [streamUrl] - The video stream URL.
  /// [duration] - The total duration of the video.
  ///
  /// Returns null if thumbnails are not available.
  Future<ThumbnailSource?> loadThumbnails({
    required String streamUrl,
    required Duration duration,
  }) async {
    // Check cache first
    if (_cache.containsKey(streamUrl)) {
      return _cache[streamUrl];
    }

    ThumbnailSource? source;

    // Try different thumbnail sources (VTT first, BIF fallback)
    source ??= await _tryJellyfinThumbnails(streamUrl);
    source ??= await _tryVttThumbnails(streamUrl);
    source ??= await _tryBifThumbnails(streamUrl);
    source ??= await _tryXtreamThumbnails(streamUrl, duration);

    // Cache result (including null to avoid
    // repeated failures)
    _cache[streamUrl] = source;
    return source;
  }

  /// Tries to load Jellyfin-style trickplay
  /// thumbnails.
  Future<ThumbnailSprite?> _tryJellyfinThumbnails(String streamUrl) async {
    try {
      final uri = Uri.parse(streamUrl);
      final segments = uri.pathSegments;

      final videosIndex = segments.indexOf('Videos');
      if (videosIndex == -1 || videosIndex + 1 >= segments.length) {
        return null;
      }

      final itemId = segments[videosIndex + 1];
      final baseUrl = '${uri.scheme}://${uri.host}';
      final port = uri.hasPort ? ':${uri.port}' : '';
      final vttUrl =
          '$baseUrl$port/Videos/'
          '$itemId/Trickplay/160/tiles.vtt';

      final response = await _dio.get<String>(
        vttUrl,
        options: Options(
          headers: {'Accept': 'text/vtt'},
          responseType: ResponseType.plain,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return await _vttParser.parse(
          response.data!,
          '$baseUrl$port/Videos/$itemId'
          '/Trickplay/160/',
        );
      }
    } catch (_) {
      // Jellyfin thumbnails not available
    }
    return null;
  }

  /// Tries to load thumbnails from a .vtt file
  /// adjacent to the stream.
  Future<ThumbnailSprite?> _tryVttThumbnails(String streamUrl) async {
    try {
      final baseUrl = streamUrl.replaceAll(RegExp(r'\.[^.]+$'), '');
      final vttUrls = [
        '${baseUrl}_thumbnails.vtt',
        '$baseUrl.vtt',
        '$baseUrl-thumbnails.vtt',
      ];

      for (final vttUrl in vttUrls) {
        try {
          final response = await _dio.get<String>(
            vttUrl,
            options: Options(
              headers: {'Accept': 'text/vtt'},
              responseType: ResponseType.plain,
              receiveTimeout: const Duration(seconds: 5),
            ),
          );

          if (response.statusCode == 200 && response.data != null) {
            final sprite = await _vttParser.parse(
              response.data!,
              vttUrl.substring(0, vttUrl.lastIndexOf('/') + 1),
            );
            if (sprite != null) {
              return sprite;
            }
          }
        } catch (_) {
          // Try next URL
        }
      }
    } catch (_) {
      // VTT thumbnails not available
    }
    return null;
  }

  /// Tries to load BIF trickplay thumbnails.
  ///
  /// Checks for `.bif` file adjacent to the stream URL
  /// and Plex-style `/indexes/sd` endpoint.
  Future<BifThumbnailData?> _tryBifThumbnails(String streamUrl) async {
    try {
      final baseUrl = streamUrl.replaceAll(RegExp(r'\.[^.]+$'), '');
      final bifUrls = [
        '$baseUrl.bif',
        // Plex: /library/parts/{id}/file.mp4 → /indexes/sd
        if (streamUrl.contains('/library/parts/'))
          '${streamUrl.substring(0, streamUrl.lastIndexOf('/'))}/indexes/sd',
      ];

      for (final bifUrl in bifUrls) {
        try {
          final response = await _dio.get<List<int>>(
            bifUrl,
            options: Options(
              responseType: ResponseType.bytes,
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

          if (response.statusCode == 200 && response.data != null) {
            final bytes = Uint8List.fromList(response.data!);
            final indexJson = await _backend.parseBifIndex(bytes);
            if (indexJson.isNotEmpty && indexJson != '[]') {
              return BifThumbnailData.fromIndexJson(bytes, indexJson);
            }
          }
        } catch (_) {
          // Try next URL
        }
      }
    } catch (_) {
      // BIF thumbnails not available
    }
    return null;
  }

  /// Tries to load thumbnails for Xtream Codes VOD.
  Future<ThumbnailSprite?> _tryXtreamThumbnails(
    String streamUrl,
    Duration duration,
  ) async {
    // Xtream Codes doesn't have a standard
    // thumbnail API. Placeholder for future
    // custom integrations.
    return null;
  }

  /// Clears the thumbnail cache.
  void clearCache() {
    _cache.clear();
  }

  /// Removes a specific entry from the cache.
  void removeFromCache(String streamUrl) {
    _cache.remove(streamUrl);
  }
}
