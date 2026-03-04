import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/data/cache_service.dart';
import '../../../core/data/crispy_backend.dart';
import '../../../core/network/http_service.dart';
import '../../vod/domain/entities/vod_item.dart';
import '../data/parsers/stalker_portal_client.dart';
import '../data/repositories/channel_repository_impl.dart';
import '../domain/entities/channel.dart';
import '../../../core/domain/entities/playlist_source.dart';
import 'refresh_playlist.dart';

/// Stalker Portal refresh logic for
/// [RefreshPlaylist].
///
/// Extracted to keep the main orchestrator file under
/// 500 lines. This mixin provides
/// [refreshStalkerPortal].
mixin RefreshStalkerMixin {
  /// Repository for persisting channels.
  ChannelRepositoryImpl get repository;

  /// HTTP service for network requests.
  HttpService get http;

  /// Rust backend for parsing delegation.
  CrispyBackend get backend;

  /// Fetches Stalker Portal data -- live channels,
  /// VOD, and series with paginated retrieval.
  ///
  /// Stalker Portal (MAG middleware) uses MAC address
  /// authentication and a different API structure
  /// than Xtream Codes.
  Future<SyncResult> refreshStalkerPortal(PlaylistSource source) async {
    try {
      if (source.macAddress == null || source.macAddress!.isEmpty) {
        debugPrint(
          'RefreshPlaylist: Stalker source '
          'missing MAC address',
        );
        return const SyncResult();
      }

      final client = StalkerPortalClient(
        baseUrl: source.url,
        macAddress: source.macAddress!,
        backend: backend,
        userAgent: source.userAgent ?? 'MAG250/1.0 (CrispyTivi)',
      );

      // Authenticate first
      await client.authenticate(http.dio);

      // ── 1. Fetch categories ──
      Map<String, String> categoryMap = {};
      try {
        final categories = await client.fetchCategories(http.dio);
        categoryMap = {
          for (final cat in categories)
            cat['id'] as String: cat['title'] as String,
        };
        debugPrint(
          'RefreshPlaylist: Stalker categories '
          'loaded — ${categoryMap.length} genres',
        );
      } catch (e) {
        debugPrint(
          'RefreshPlaylist: Stalker category '
          'fetch failed: $e',
        );
      }

      // ── 2. Fetch all channels (paginated) ──
      List<Channel> channels = [];
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final result = await client.fetchLiveChannels(http.dio, page: page);

        if (result.channels.isEmpty) {
          hasMore = false;
        } else {
          final pageChannels = await client.parseLiveStreams(
            result.channels,
            sourceId: source.id,
          );
          channels.addAll(pageChannels);
          page++;

          // Check if more pages available
          hasMore = result.hasMorePages && page <= result.totalPages;

          // Safety limit to prevent infinite loops
          if (page > 100) {
            debugPrint(
              'RefreshPlaylist: Stalker hit '
              'page limit (100)',
            );
            hasMore = false;
          }
        }
      }

      // ── 3. Resolve category IDs via backend ──
      if (categoryMap.isNotEmpty) {
        final resolved = await backend.resolveChannelCategories(
          jsonEncode(channels.map(channelToMap).toList()),
          jsonEncode(categoryMap),
        );
        channels =
            (jsonDecode(resolved) as List)
                .cast<Map<String, dynamic>>()
                .map(mapToChannel)
                .toList();
      }

      // ── 4. Persist channels ──
      await repository.saveChannels(channels, sourceId: source.id);

      // Extract groups via Rust backend.
      final channelGroups = await backend.extractSortedGroups(
        jsonEncode(channels.map(channelToMap).toList()),
      );

      debugPrint(
        'RefreshPlaylist: Stalker '
        '→ ${channels.length} channels, '
        '${channelGroups.length} groups',
      );

      // ── 5. Fetch VOD + series ──
      final vodResult = await _fetchStalkerVod(client, source);

      return SyncResult(
        channels: channels,
        channelGroups: channelGroups,
        vodItems: vodResult.items,
        vodCategories: vodResult.categories,
      );
    } catch (e) {
      debugPrint('RefreshPlaylist Stalker error: $e');
      return const SyncResult();
    }
  }

  /// Fetches VOD movies and series from a Stalker
  /// portal with pagination and category resolution.
  Future<_StalkerVodData> _fetchStalkerVod(
    StalkerPortalClient client,
    PlaylistSource source,
  ) async {
    // ── VOD categories ──
    Map<String, String> vodCatMap = {};
    try {
      final vodCats = await client.fetchVodCategories(http.dio);
      vodCatMap = {
        for (final cat in vodCats) cat['id'] as String: cat['title'] as String,
      };
      debugPrint(
        'RefreshPlaylist: Stalker VOD categories '
        '— ${vodCatMap.length}',
      );
    } catch (e) {
      debugPrint(
        'RefreshPlaylist: Stalker VOD category '
        'fetch failed: $e',
      );
    }

    // ── Fetch all VOD items (paginated) ──
    List<VodItem> vodItems = [];
    try {
      int vodPage = 1;
      bool vodHasMore = true;

      while (vodHasMore) {
        final result = await client.fetchVodItems(http.dio, page: vodPage);

        if (result.items.isEmpty) {
          vodHasMore = false;
        } else {
          final pageItems = await client.parseVodItems(
            result.items,
            type: VodType.movie,
          );
          vodItems.addAll(pageItems);
          vodPage++;

          vodHasMore = result.hasMorePages && vodPage <= result.totalPages;

          // Safety limit
          if (vodPage > 100) {
            debugPrint(
              'RefreshPlaylist: Stalker VOD '
              'hit page limit (100)',
            );
            vodHasMore = false;
          }
        }
      }

      debugPrint(
        'RefreshPlaylist: Stalker VOD '
        '→ ${vodItems.length} movies',
      );
    } catch (e) {
      debugPrint(
        'RefreshPlaylist: Stalker VOD '
        'fetch failed: $e',
      );
    }

    // ── Series categories ──
    Map<String, String> seriesCatMap = {};
    try {
      final seriesCats = await client.fetchSeriesCategories(http.dio);
      seriesCatMap = {
        for (final cat in seriesCats)
          cat['id'] as String: cat['title'] as String,
      };
      debugPrint(
        'RefreshPlaylist: Stalker series '
        'categories — ${seriesCatMap.length}',
      );
    } catch (e) {
      debugPrint(
        'RefreshPlaylist: Stalker series category '
        'fetch failed: $e',
      );
    }

    // ── Fetch all series items (paginated) ──
    try {
      int seriesPage = 1;
      bool seriesHasMore = true;

      while (seriesHasMore) {
        final result = await client.fetchSeriesItems(
          http.dio,
          page: seriesPage,
        );

        if (result.items.isEmpty) {
          seriesHasMore = false;
        } else {
          final pageItems = await client.parseVodItems(
            result.items,
            type: VodType.series,
          );
          vodItems.addAll(pageItems);
          seriesPage++;

          seriesHasMore =
              result.hasMorePages && seriesPage <= result.totalPages;

          // Safety limit
          if (seriesPage > 100) {
            debugPrint(
              'RefreshPlaylist: Stalker series '
              'hit page limit (100)',
            );
            seriesHasMore = false;
          }
        }
      }

      debugPrint(
        'RefreshPlaylist: Stalker series → '
        '${vodItems.where((v) => v.type == VodType.series).length} items',
      );
    } catch (e) {
      debugPrint(
        'RefreshPlaylist: Stalker series '
        'fetch failed: $e',
      );
    }

    // ── Resolve VOD category IDs via backend ──
    final combinedCatMap = {...vodCatMap, ...seriesCatMap};
    if (combinedCatMap.isNotEmpty) {
      final resolved = await backend.resolveVodCategories(
        jsonEncode(vodItems.map(vodItemToMap).toList()),
        jsonEncode(combinedCatMap),
      );
      vodItems =
          (jsonDecode(resolved) as List)
              .cast<Map<String, dynamic>>()
              .map(mapToVodItem)
              .toList();
    }

    // Extract VOD categories via backend.
    final vodCategories = await backend.extractSortedVodCategories(
      jsonEncode(vodItems.map(vodItemToMap).toList()),
    );

    return _StalkerVodData(items: vodItems, categories: vodCategories);
  }
}

/// Internal result type for Stalker VOD + series
/// fetch operations.
class _StalkerVodData {
  const _StalkerVodData({required this.items, required this.categories});

  final List<VodItem> items;
  final List<String> categories;
}
