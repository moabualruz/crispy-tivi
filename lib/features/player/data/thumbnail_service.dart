import 'package:dio/dio.dart';

import '../../../core/data/crispy_backend.dart';
import '../domain/entities/thumbnail_sprite.dart';
import 'vtt_parser.dart';

/// Service for loading video thumbnail sprites.
///
/// Attempts to load thumbnails from various sources
/// in order:
/// 1. WebVTT sprite sheets (Jellyfin, Plex, Emby)
/// 2. Direct thumbnail API endpoints
/// 3. Returns null if no thumbnails available
class ThumbnailService {
  ThumbnailService({Dio? dio, required CrispyBackend backend})
    : _dio = dio ?? Dio(),
      _vttParser = VttParser(backend);

  final Dio _dio;
  final VttParser _vttParser;

  /// Cache of loaded sprites by stream URL.
  final Map<String, ThumbnailSprite?> _cache = {};

  /// Attempts to load thumbnail sprite for a VOD
  /// stream.
  ///
  /// [streamUrl] - The video stream URL.
  /// [duration] - The total duration of the video.
  ///
  /// Returns null if thumbnails are not available.
  Future<ThumbnailSprite?> loadThumbnails({
    required String streamUrl,
    required Duration duration,
  }) async {
    // Check cache first
    if (_cache.containsKey(streamUrl)) {
      return _cache[streamUrl];
    }

    ThumbnailSprite? sprite;

    // Try different thumbnail sources
    sprite ??= await _tryJellyfinThumbnails(streamUrl);
    sprite ??= await _tryVttThumbnails(streamUrl);
    sprite ??= await _tryXtreamThumbnails(streamUrl, duration);

    // Cache result (including null to avoid
    // repeated failures)
    _cache[streamUrl] = sprite;
    return sprite;
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
