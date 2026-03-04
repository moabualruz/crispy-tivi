import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/data/cache_service.dart';
import '../../../core/data/crispy_backend.dart';
import '../../../core/network/http_service.dart';
import '../../vod/data/vod_parser.dart';
import '../../vod/domain/entities/vod_item.dart';
import '../data/parsers/m3u_parser.dart';
import '../data/repositories/channel_repository_impl.dart';
import '../domain/entities/channel.dart';
import '../../../core/domain/entities/playlist_source.dart';
import 'refresh_stalker.dart';
import 'refresh_xtream.dart';

/// Result of a full playlist sync operation.
class SyncResult {
  const SyncResult({
    this.channels = const [],
    this.channelGroups = const [],
    this.vodItems = const [],
    this.vodCategories = const [],
    this.discoveredEpgUrl,
  });

  final List<Channel> channels;
  final List<String> channelGroups;
  final List<VodItem> vodItems;
  final List<String> vodCategories;

  /// EPG URL discovered from M3U header or Xtream
  /// convention. Null if none found.
  final String? discoveredEpgUrl;

  int get totalChannels => channels.length;
  int get totalVod => vodItems.length;
}

/// Refreshes channel + VOD data for a playlist
/// source.
///
/// Fetches the M3U/Xtream data, parses it, and
/// persists channels to local storage. Returns a
/// [SyncResult] with all content.
class RefreshPlaylist with RefreshXtreamMixin, RefreshStalkerMixin {
  RefreshPlaylist(this._repository, this._http, this._backend);

  final ChannelRepositoryImpl _repository;
  final HttpService _http;
  final CrispyBackend _backend;

  @override
  ChannelRepositoryImpl get repository => _repository;

  @override
  HttpService get http => _http;

  @override
  CrispyBackend get backend => _backend;

  /// Refreshes all content from the given [source].
  Future<SyncResult> call(PlaylistSource source) async {
    switch (source.type) {
      case PlaylistSourceType.m3u:
        return _refreshM3u(source);
      case PlaylistSourceType.xtream:
        return refreshXtream(source);
      case PlaylistSourceType.stalkerPortal:
        return refreshStalkerPortal(source);
      case PlaylistSourceType.jellyfin:
      case PlaylistSourceType.emby:
      case PlaylistSourceType.plex:
        // On-demand sources, no sync needed
        return const SyncResult();
    }
  }

  /// Fetches M3U content via Dio, parses in isolate,
  /// persists.
  Future<SyncResult> _refreshM3u(PlaylistSource source) async {
    try {
      final content = await _http.getString(
        source.url,
        headers:
            source.userAgent != null ? {'User-Agent': source.userAgent!} : null,
      );

      if (content.isEmpty) return const SyncResult();

      // Parse channels via Rust backend.
      final result = await M3uParser.parseContent(content, _backend);
      final channels = result.channels;

      // Extract groups via Rust backend.
      final groups = await _backend.extractSortedGroups(
        jsonEncode(channels.map(channelToMap).toList()),
      );

      // Persist channels.
      await _repository.saveChannels(channels, sourceId: source.id);

      // Parse VOD from M3U (movies with
      // extensions) via Rust backend.
      final vodItems = await VodParser.parseM3uVod(
        channels
            .map(
              (c) => {
                'streamUrl': c.streamUrl,
                'name': c.name,
                'group': c.group,
                'logoUrl': c.logoUrl,
              },
            )
            .toList(),
        _backend,
        sourceId: source.id,
      );

      // Extract VOD categories via Rust backend.
      final vodCats = await _backend.extractSortedVodCategories(
        jsonEncode(vodItems.map(vodItemToMap).toList()),
      );

      return SyncResult(
        channels: channels,
        channelGroups: groups,
        vodItems: vodItems,
        vodCategories: vodCats,
        discoveredEpgUrl: result.epgUrl,
      );
    } catch (e) {
      debugPrint('RefreshPlaylist M3U error: $e');
      return const SyncResult();
    }
  }
}
