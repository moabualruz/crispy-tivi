import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../core/data/cache_service.dart';
import '../../../core/data/crispy_backend.dart';
import '../../../core/network/http_service.dart';
import '../../vod/data/vod_parser.dart';
import '../../vod/domain/entities/vod_item.dart';
import '../data/parsers/xtream_client.dart';
import '../data/repositories/channel_repository_impl.dart';
import '../domain/entities/channel.dart';
import '../../../core/domain/entities/playlist_source.dart';
import 'refresh_playlist.dart';

/// Xtream Codes refresh logic for [RefreshPlaylist].
///
/// Extracted to keep the main orchestrator file under
/// 500 lines. This mixin provides [refreshXtream].
mixin RefreshXtreamMixin {
  /// Repository for persisting channels.
  ChannelRepositoryImpl get repository;

  /// HTTP service for network requests.
  HttpService get http;

  /// Rust backend for parsing delegation.
  CrispyBackend get backend;

  /// Fetches Xtream Codes data -- live channels, VOD
  /// movies, and series. Resolves category IDs to
  /// human-readable names.
  Future<SyncResult> refreshXtream(PlaylistSource source) async {
    try {
      final client = XtreamClient(
        baseUrl: source.url,
        username: source.username ?? '',
        password: source.password ?? '',
        backend: backend,
        userAgent: source.userAgent ?? 'CrispyTivi/1.0',
      );

      // ── 1. Fetch all categories concurrently ──
      Map<String, String> liveCatMap = {};
      Map<String, String> vodCatMap = {};
      Map<String, String> seriesCatMap = {};

      try {
        final results = await Future.wait([
          http.getJsonList(client.buildActionUrl('get_live_categories')),
          http.getJsonList(client.buildActionUrl('get_vod_categories')),
          http.getJsonList(client.buildActionUrl('get_series_categories')),
        ]);
        liveCatMap = await _buildCategoryMap(results[0], backend);
        vodCatMap = await _buildCategoryMap(results[1], backend);
        seriesCatMap = await _buildCategoryMap(results[2], backend);
        debugPrint(
          'RefreshPlaylist: categories loaded — '
          'Live: ${liveCatMap.length}, '
          'VOD: ${vodCatMap.length}, '
          'Series: ${seriesCatMap.length}',
        );
      } catch (e) {
        debugPrint(
          'RefreshPlaylist: category fetch '
          'failed: $e',
        );
      }

      // ── 2. Fetch live streams ──
      List<Channel> channels = [];
      try {
        final liveUrl = client.buildActionUrl('get_live_streams');
        final liveData = await http.getJsonList(liveUrl);
        if (liveData.isNotEmpty) {
          channels = await client.parseLiveStreams(liveData);

          // Resolve category IDs via backend.
          if (liveCatMap.isNotEmpty) {
            final resolved = await backend.resolveChannelCategories(
              jsonEncode(channels.map(channelToMap).toList()),
              jsonEncode(liveCatMap),
            );
            channels =
                (jsonDecode(resolved) as List)
                    .cast<Map<String, dynamic>>()
                    .map(mapToChannel)
                    .toList();
          }

          // Persist channels.
          await repository.saveChannels(channels, sourceId: source.id);
        }
      } catch (e) {
        debugPrint(
          'RefreshPlaylist: live streams '
          'failed: $e',
        );
      }

      // Extract groups via Rust backend.
      final channelGroups = await backend.extractSortedGroups(
        jsonEncode(channels.map(channelToMap).toList()),
      );

      // ── 3. Fetch VOD movies ──
      List<VodItem> vodItems = [];
      try {
        final vodUrl = client.buildActionUrl('get_vod_streams');
        final vodData = await http.getJsonList(vodUrl);

        debugPrint(
          'RefreshPlaylist: fetched ${vodData.length} VOD JSON items from HTTP',
        );
        if (vodData.isNotEmpty) {
          vodItems = await VodParser.parseVodStreams(
            vodData,
            backend,
            baseUrl: client.baseUrl,
            username: client.username,
            password: client.password,
            sourceId: source.id,
          );

          // Resolve category IDs via backend.
          if (vodCatMap.isNotEmpty) {
            try {
              debugPrint(
                'RefreshPlaylist: Resolving categories for ${vodItems.length} items using map size ${vodCatMap.length}',
              );
              final resolved = await backend.resolveVodCategories(
                jsonEncode(vodItems.map(vodItemToMap).toList()),
                jsonEncode(vodCatMap),
              );
              debugPrint(
                'RefreshPlaylist: resolveVodCategories returned JSON string of length ${resolved.length}',
              );
              final decodedList = jsonDecode(resolved) as List;
              debugPrint(
                'RefreshPlaylist: resolveVodCategories decoded to List of size ${decodedList.length}',
              );
              vodItems =
                  decodedList
                      .cast<Map<String, dynamic>>()
                      .map(mapToVodItem)
                      .toList();
              debugPrint(
                'RefreshPlaylist: Successfully mapped ${vodItems.length} items back to VodItem objects.',
              );
            } catch (innerE, st) {
              debugPrint(
                'RefreshPlaylist: CRITICAL ERROR during resolveVodCategories: $innerE\n$st',
              );
            }
          }

          debugPrint(
            'RefreshPlaylist: '
            '${vodItems.length} VOD movies loaded',
          );
        }
      } catch (e) {
        debugPrint(
          'RefreshPlaylist: VOD streams '
          'failed: $e',
        );
      }

      // ── 4. Fetch series ──
      try {
        final seriesUrl = client.buildActionUrl('get_series');
        final seriesData = await http.getJsonList(seriesUrl);
        if (seriesData.isNotEmpty) {
          var seriesItems = await VodParser.parseSeries(
            seriesData,
            backend,
            sourceId: source.id,
          );

          // Resolve category IDs via backend.
          if (seriesCatMap.isNotEmpty) {
            final resolved = await backend.resolveVodCategories(
              jsonEncode(seriesItems.map(vodItemToMap).toList()),
              jsonEncode(seriesCatMap),
            );
            seriesItems =
                (jsonDecode(resolved) as List)
                    .cast<Map<String, dynamic>>()
                    .map(mapToVodItem)
                    .toList();
          }

          vodItems = [...vodItems, ...seriesItems];
          debugPrint(
            'RefreshPlaylist: '
            '${seriesItems.length} series loaded',
          );
        }
      } catch (e) {
        debugPrint('RefreshPlaylist: series failed: $e');
      }

      // Extract VOD categories via backend.
      final vodCategories = await backend.extractSortedVodCategories(
        jsonEncode(vodItems.map(vodItemToMap).toList()),
      );

      return SyncResult(
        channels: channels,
        channelGroups: channelGroups,
        vodItems: vodItems,
        vodCategories: vodCategories,
      );
    } catch (e) {
      debugPrint('RefreshPlaylist Xtream error: $e');
      return const SyncResult();
    }
  }

  /// Converts raw JSON category list into
  /// {id -> name} map via Rust backend.
  static Future<Map<String, String>> _buildCategoryMap(
    List<dynamic> data,
    CrispyBackend backend,
  ) async {
    final json = await backend.buildCategoryMap(jsonEncode(data));
    final map = jsonDecode(json) as Map<String, dynamic>;
    return map.cast<String, String>();
  }
}
