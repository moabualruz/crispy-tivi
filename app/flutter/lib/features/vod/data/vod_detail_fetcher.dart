import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/settings_notifier.dart';
import '../../../core/data/cache_service.dart';
import '../../../core/domain/entities/playlist_source.dart';
import '../../../core/network/http_service.dart';
import '../domain/entities/vod_item.dart';

/// TTL for on-demand metadata fetches. If the item was updated
/// less than this duration ago, skip the API call.
const _kFetchTtl = Duration(minutes: 10);

// ─────────────────────────────────────────────────────────────
//  Public API
// ─────────────────────────────────────────────────────────────

/// Fetches full metadata for a VOD item (movie or series) from its
/// source API. Only calls the API for Xtream and Stalker sources.
/// M3U items are returned as-is (no detail endpoint).
///
/// Respects a [_kFetchTtl] TTL — if the item's [updatedAt] is
/// recent, the cached data is returned without an API call.
///
/// For **movies**: calls `get_vod_info/{id}` (Xtream) to get
/// plot, cast, director, genre, duration, backdrop, TMDB ID.
///
/// For **series**: calls `get_series_info/{id}` (Xtream) to get
/// plot, cast, director, genre, backdrop + fresh season/episode
/// lists. Episodes are saved to DB so the series detail screen
/// has up-to-date data.
///
/// After fetching, persists the updated item to the local DB via
/// [CacheService.saveVodItems] so subsequent opens skip the fetch.
Future<VodItem?> fetchVodDetail(Ref ref, VodItem item) async {
  // TTL check — skip if recently fetched.
  if (item.updatedAt != null) {
    final age = DateTime.now().difference(item.updatedAt!);
    if (age < _kFetchTtl) return item;
  }

  final settings = ref.read(settingsNotifierProvider).value;
  if (settings == null) return null;

  // Find the source that owns this item.
  final source = _findSource(settings.sources, item);
  if (source == null) return null;

  switch (source.type) {
    case PlaylistSourceType.xtream:
      return _fetchXtream(ref, item, source);
    case PlaylistSourceType.stalkerPortal:
      return _fetchStalker(ref, item, source);
    default:
      return null; // M3U — no detail endpoint
  }
}

// ─────────────────────────────────────────────────────────────
//  Xtream
// ─────────────────────────────────────────────────────────────

Future<VodItem?> _fetchXtream(
  Ref ref,
  VodItem item,
  PlaylistSource source,
) async {
  final baseUrl = _baseUrl(source.url);
  final creds = 'username=${source.username}&password=${source.password}';

  // Movies: get_vod_info. Series: get_series_info.
  final String action;
  final String numericId;

  if (item.type == VodType.series) {
    action = 'get_series_info';
    // Series IDs: "ser_{series_id}" or just the numeric part
    numericId = item.id.replaceFirst(RegExp(r'^ser_'), '');
  } else {
    action = 'get_vod_info';
    numericId = item.id.replaceFirst(RegExp(r'^vod_'), '');
  }

  final url =
      '$baseUrl/player_api.php?$creds&action=$action&'
      '${action == "get_series_info" ? "series_id" : "vod_id"}=$numericId';

  try {
    final http = ref.read(httpServiceProvider);
    final data = await http.getJson(url);
    if (data is! Map<String, dynamic>) return null;

    final info = data['info'] as Map<String, dynamic>? ?? {};

    // Merge metadata into item.
    final updated = _mergeXtreamInfo(item, info);

    // For series: also save episodes from the response.
    if (item.type == VodType.series) {
      final episodes = _parseXtreamEpisodes(data, source, baseUrl, item);
      if (episodes.isNotEmpty) {
        final cache = ref.read(cacheServiceProvider);
        await cache.saveVodItems(episodes);
      }
    }

    // Persist updated item with fresh updatedAt.
    final withTimestamp = updated.copyWith(updatedAt: DateTime.now());
    final cache = ref.read(cacheServiceProvider);
    await cache.saveVodItems([withTimestamp]);

    return withTimestamp;
  } catch (e) {
    debugPrint('[VodDetailFetcher] $action failed for ${item.id}: $e');
    return null;
  }
}

VodItem _mergeXtreamInfo(VodItem item, Map<String, dynamic> info) {
  return item.copyWith(
    description: _firstNonEmpty(item.description, info['plot'] as String?),
    cast: item.cast ?? _parseCast(info['cast'] as String?),
    director: _firstNonEmpty(item.director, info['director'] as String?),
    backdropUrl: _firstNonEmpty(
      item.backdropUrl,
      _parseBackdrop(info['backdrop_path']),
    ),
    duration: item.duration ?? _parseDuration(info['duration'] as String?),
    year: item.year ?? _parseYear(info['releasedate']),
    rating: _firstNonEmpty(item.rating, info['rating']?.toString()),
    posterUrl: _firstNonEmpty(item.posterUrl, info['cover_big'] as String?),
  );
}

/// Parses episodes from a `get_series_info` response.
List<VodItem> _parseXtreamEpisodes(
  Map<String, dynamic> data,
  PlaylistSource source,
  String baseUrl,
  VodItem series,
) {
  final episodes = <VodItem>[];
  final seasonsMap = data['episodes'];
  if (seasonsMap is! Map<String, dynamic>) return episodes;

  for (final entry in seasonsMap.entries) {
    final seasonNum = int.tryParse(entry.key);
    final epList = entry.value;
    if (epList is! List) continue;

    for (final ep in epList) {
      if (ep is! Map<String, dynamic>) continue;

      final epId = ep['id']?.toString() ?? '';
      final ext = ep['container_extension'] as String? ?? 'mp4';
      final epInfo = ep['info'] as Map<String, dynamic>? ?? {};

      final streamUrl =
          '$baseUrl/series/${source.username}/${source.password}/$epId.$ext';

      episodes.add(
        VodItem(
          id: 'ep_${series.sourceId}_$epId',
          name: ep['title'] as String? ?? 'Episode ${ep['episode_num']}',
          streamUrl: streamUrl,
          type: VodType.episode,
          posterUrl: epInfo['movie_image'] as String? ?? series.posterUrl,
          description: epInfo['plot'] as String?,
          duration: _parseDuration(epInfo['duration'] as String?),
          year: _parseYear(epInfo['releasedate']),
          rating: epInfo['rating']?.toString(),
          category: series.category,
          seriesId: series.id,
          seasonNumber: seasonNum,
          episodeNumber: int.tryParse(ep['episode_num']?.toString() ?? ''),
          extension: ext,
          sourceId: series.sourceId,
          addedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  return episodes;
}

// ─────────────────────────────────────────────────────────────
//  Stalker
// ─────────────────────────────────────────────────────────────

Future<VodItem?> _fetchStalker(
  Ref ref,
  VodItem item,
  PlaylistSource source,
) async {
  final backend = ref.read(crispyBackendProvider);
  final cache = ref.read(cacheServiceProvider);

  // Extract the Stalker-native numeric ID from the prefixed ID.
  // Channels: "stk_42", VODs: "stk_vod_101", Series: "stk_vod_201".
  final movieId = item.id
      .replaceFirst(RegExp(r'^stk_vod_'), '')
      .replaceFirst(RegExp(r'^stk_'), '');

  try {
    if (item.type == VodType.series) {
      // Series: fetch season/episode structure.
      final json = await backend.fetchStalkerSeriesDetail(
        baseUrl: source.url,
        macAddress: source.macAddress ?? '',
        movieId: movieId,
        sourceId: source.id,
        acceptInvalidCerts: source.acceptSelfSigned,
      );

      final episodes = _parseStalkerEpisodes(json, item);
      if (episodes.isNotEmpty) {
        await cache.saveVodItems(episodes);
      }

      // Stamp updatedAt on the series item itself.
      final updated = item.copyWith(updatedAt: DateTime.now());
      await cache.saveVodItems([updated]);
      return updated;
    } else {
      // Movie: fetch detailed metadata.
      final json = await backend.fetchStalkerVodDetail(
        baseUrl: source.url,
        macAddress: source.macAddress ?? '',
        movieId: movieId,
        sourceId: source.id,
        acceptInvalidCerts: source.acceptSelfSigned,
      );

      final updated = _parseStalkerVodDetail(json, item);
      final withTimestamp = updated.copyWith(updatedAt: DateTime.now());
      await cache.saveVodItems([withTimestamp]);
      return withTimestamp;
    }
  } catch (e) {
    debugPrint('[VodDetailFetcher] Stalker detail failed for ${item.id}: $e');
    // Fallback: stamp updatedAt to respect TTL and avoid retrying.
    final fallback = item.copyWith(updatedAt: DateTime.now());
    await cache.saveVodItems([fallback]);
    return fallback;
  }
}

/// Parses a Stalker VOD detail JSON response into a [VodItem].
///
/// Merges the detailed metadata from the Rust response with the
/// existing [item] fields, preferring fresh data when available.
VodItem _parseStalkerVodDetail(String json, VodItem item) {
  try {
    final data = jsonDecode(json) as Map<String, dynamic>;
    return item.copyWith(
      name: _firstNonEmpty(null, data['name'] as String?) ?? item.name,
      description: _firstNonEmpty(
        item.description,
        data['description'] as String?,
      ),
      posterUrl: _firstNonEmpty(item.posterUrl, data['poster_url'] as String?),
      backdropUrl: _firstNonEmpty(
        item.backdropUrl,
        data['backdrop_url'] as String?,
      ),
      duration: item.duration ?? (data['duration'] as int?),
      year: item.year ?? (data['year'] as int?),
      rating: _firstNonEmpty(item.rating, data['rating']?.toString()),
      director: _firstNonEmpty(item.director, data['director'] as String?),
      cast: item.cast ?? _parseStalkerCast(data['cast']),
      streamUrl:
          _firstNonEmpty(null, data['stream_url'] as String?) ?? item.streamUrl,
    );
  } catch (e) {
    debugPrint('[VodDetailFetcher] Stalker VOD parse error: $e');
    return item;
  }
}

/// Parses a Stalker series detail JSON response (array of episodes).
List<VodItem> _parseStalkerEpisodes(String json, VodItem series) {
  try {
    final list = jsonDecode(json) as List<dynamic>;
    return list.whereType<Map<String, dynamic>>().map((ep) {
      final id = ep['id']?.toString() ?? '';
      final name = ep['name'] as String? ?? 'Episode';
      final streamUrl = ep['stream_url'] as String? ?? '';
      final seasonNum = ep['season_number'] as int?;
      final episodeNum = ep['episode_number'] as int?;
      final posterUrl = ep['poster_url'] as String? ?? series.posterUrl;
      final description = ep['description'] as String?;
      final duration = ep['duration'] as int?;
      final year = ep['year'] as int?;
      final rating = ep['rating']?.toString();

      return VodItem(
        id: id.isNotEmpty ? id : 'stk_ep_${series.id}_$episodeNum',
        name: name,
        streamUrl: streamUrl,
        type: VodType.episode,
        posterUrl: posterUrl,
        description: description,
        duration: duration,
        year: year,
        rating: rating,
        category: series.category,
        seriesId: series.id,
        seasonNumber: seasonNum,
        episodeNumber: episodeNum,
        sourceId: series.sourceId,
        addedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }).toList();
  } catch (e) {
    debugPrint('[VodDetailFetcher] Stalker episodes parse error: $e');
    return const [];
  }
}

/// Parses cast from Stalker detail (may be a list or comma-separated string).
List<String>? _parseStalkerCast(dynamic raw) {
  if (raw is List) {
    return raw
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
  if (raw is String) return _parseCast(raw);
  return null;
}

// ─────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────

PlaylistSource? _findSource(List<PlaylistSource> sources, VodItem item) {
  if (item.sourceId != null) {
    final match = sources.where((s) => s.id == item.sourceId).firstOrNull;
    if (match != null) return match;
  }
  // Infer from ID prefix.
  if (item.id.startsWith('vod_') || item.id.startsWith('ser_')) {
    return sources
        .where((s) => s.type == PlaylistSourceType.xtream)
        .firstOrNull;
  }
  if (item.id.startsWith('stk_')) {
    return sources
        .where((s) => s.type == PlaylistSourceType.stalkerPortal)
        .firstOrNull;
  }
  return null;
}

String _baseUrl(String url) {
  final uri = Uri.parse(url);
  return '${uri.scheme}://${uri.host}${uri.hasPort ? ":${uri.port}" : ""}';
}

String? _firstNonEmpty(String? existing, String? fetched) {
  if (existing != null && existing.isNotEmpty) return existing;
  if (fetched != null && fetched.isNotEmpty) return fetched;
  return existing;
}

List<String>? _parseCast(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return raw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

String? _parseBackdrop(dynamic raw) {
  if (raw is List && raw.isNotEmpty) return raw.first.toString();
  if (raw is String && raw.isNotEmpty) return raw;
  return null;
}

int? _parseDuration(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split(':');
  if (parts.length == 3) {
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h != null && m != null) return h * 60 + m;
  }
  if (parts.length == 2) {
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h != null && m != null) return h * 60 + m;
  }
  return int.tryParse(raw);
}

int? _parseYear(dynamic raw) {
  if (raw == null) return null;
  final str = raw.toString().trim();
  if (str.isEmpty) return null;
  if (str.length >= 4) {
    final year = int.tryParse(str.substring(0, 4));
    if (year != null && year > 1800 && year < 2200) return year;
  }
  return int.tryParse(str);
}
