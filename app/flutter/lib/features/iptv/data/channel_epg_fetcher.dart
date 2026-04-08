import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/settings_notifier.dart';
import '../../../core/data/cache_service.dart';
import '../../../core/domain/entities/playlist_source.dart';
import '../../../core/network/http_service.dart';
import '../domain/entities/channel.dart';
import '../domain/entities/epg_entry.dart';

/// Minimum TTL for on-demand per-channel EPG fetches.
///
/// The actual TTL is the longer of this and the time remaining
/// until the current show ends — so a 2-hour movie fetched
/// 6 minutes ago won't re-fetch until it finishes.
const _kMinChannelEpgTtl = Duration(minutes: 5);

/// In-memory cache entry for per-channel EPG data.
class _CacheEntry {
  _CacheEntry(this.entries, this.fetchedAt);

  final List<EpgEntry> entries;
  final DateTime fetchedAt;

  /// Expired when both: (a) minimum TTL has passed, and
  /// (b) the currently-live show (if any) has ended.
  bool get isExpired {
    final now = DateTime.now().toUtc();
    final age = now.difference(fetchedAt);
    // Find the live entry and use its end time as TTL.
    for (final e in entries) {
      if (e.isLiveAt(now)) {
        final showRemaining = e.endTime.difference(now);
        final ttl =
            showRemaining > _kMinChannelEpgTtl
                ? showRemaining
                : _kMinChannelEpgTtl;
        return age >= ttl;
      }
    }
    // No live show — use minimum TTL.
    return age >= _kMinChannelEpgTtl;
  }
}

/// In-memory TTL cache for per-channel on-demand EPG results.
///
/// Keyed by channel ID. Entries expire after [_kChannelEpgTtl].
/// This is a simple session-scoped cache; it resets on app restart.
final _channelEpgCache = <String, _CacheEntry>{};

/// Clears the in-memory per-channel EPG cache.
///
/// Useful when sources change or the user triggers a manual refresh.
void clearChannelEpgCache() => _channelEpgCache.clear();

/// Fetches current and upcoming EPG data for a single [channel]
/// from its source API (Xtream or Stalker).
///
/// This supplements the batch XMLTV data by calling the source's
/// `get_short_epg` endpoint. Results are cached in-memory with a
/// 5-minute TTL per channel.
///
/// Returns an empty list for M3U channels (no per-channel endpoint)
/// or on error.
Future<List<EpgEntry>> fetchChannelEpg(Ref ref, Channel channel) async {
  // TTL check — return cached if still fresh.
  final cached = _channelEpgCache[channel.id];
  if (cached != null && !cached.isExpired) {
    return cached.entries;
  }

  final settings = ref.read(settingsNotifierProvider).value;
  if (settings == null) return const [];

  // Find the source that owns this channel.
  final source = _findSource(settings.sources, channel);
  if (source == null) return const [];

  List<EpgEntry> entries;
  switch (source.type) {
    case PlaylistSourceType.xtream:
      entries = await _fetchXtreamEpg(ref, channel, source);
    case PlaylistSourceType.stalkerPortal:
      entries = await _fetchStalkerEpg(ref, channel, source);
    default:
      return const []; // M3U — no per-channel endpoint
  }

  // Cache the result.
  _channelEpgCache[channel.id] = _CacheEntry(entries, DateTime.now());
  return entries;
}

// ─────────────────────────────────────────────────────────────
//  Xtream: get_short_epg
// ─────────────────────────────────────────────────────────────

Future<List<EpgEntry>> _fetchXtreamEpg(
  Ref ref,
  Channel channel,
  PlaylistSource source,
) async {
  if (source.username == null || source.password == null) return const [];

  // Xtream channel IDs are "xc_{stream_id}".
  final streamIdStr = channel.id.replaceFirst(RegExp(r'^xc_'), '');
  final streamId = int.tryParse(streamIdStr);
  if (streamId == null) return const [];

  final baseUrl = _baseUrl(source.url);
  final url =
      '$baseUrl/player_api.php'
      '?username=${source.username}'
      '&password=${source.password}'
      '&action=get_short_epg'
      '&stream_id=$streamId';

  try {
    final http = ref.read(httpServiceProvider);
    final data = await http.getJson(url);
    if (data is! Map<String, dynamic>) return const [];

    final listings = data['epg_listings'];
    if (listings is! List || listings.isEmpty) return const [];

    // Parse via Rust FFI (handles base64 decoding of titles/descriptions).
    final listingsJson = jsonEncode(listings);
    final backend = ref.read(crispyBackendProvider);
    final resultJson = await backend.parseXtreamShortEpg(
      listingsJson,
      channel.id,
    );

    return _decodeEpgEntries(resultJson, channel.id);
  } catch (e) {
    debugPrint(
      '[ChannelEpgFetcher] Xtream get_short_epg failed '
      'for ${channel.id}: $e',
    );
    return const [];
  }
}

// ─────────────────────────────────────────────────────────────
//  Stalker: get_short_epg
// ─────────────────────────────────────────────────────────────

Future<List<EpgEntry>> _fetchStalkerEpg(
  Ref ref,
  Channel channel,
  PlaylistSource source,
) async {
  // Stalker channel IDs are "stk_{ch_id}".
  final stalkerIdStr = channel.id.replaceFirst(RegExp(r'^stk_'), '');

  final baseUrl = _baseUrl(source.url);
  final url =
      '$baseUrl/server/load.php'
      '?type=itv&action=get_short_epg'
      '&ch_id=$stalkerIdStr';

  try {
    final http = ref.read(httpServiceProvider);
    final rawJson = await http.getString(url);
    if (rawJson.isEmpty) return const [];

    // Parse via Rust FFI.
    final backend = ref.read(crispyBackendProvider);
    final resultJson = await backend.parseStalkerEpg(rawJson, channel.id);

    return _decodeEpgEntries(resultJson, channel.id);
  } catch (e) {
    debugPrint(
      '[ChannelEpgFetcher] Stalker get_short_epg failed '
      'for ${channel.id}: $e',
    );
    return const [];
  }
}

// ─────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────

/// Decodes the JSON array of EpgEntry objects returned by the
/// Rust parsers.
List<EpgEntry> _decodeEpgEntries(String json, String channelId) {
  try {
    final list = jsonDecode(json) as List;
    return list.map<EpgEntry>((e) {
        final m = e as Map<String, dynamic>;
        return EpgEntry(
          channelId: m['channel_id'] as String? ?? channelId,
          title: m['title'] as String? ?? '',
          startTime: _parseTimestamp(m['start_time']),
          endTime: _parseTimestamp(m['end_time']),
          description: m['description'] as String?,
          category: m['category'] as String?,
          iconUrl: m['icon_url'] as String?,
        );
      }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  } catch (e) {
    debugPrint('[ChannelEpgFetcher] Failed to decode EPG entries: $e');
    return const [];
  }
}

/// Parses a timestamp that may be an epoch-seconds int,
/// epoch-milliseconds int, or a date string.
DateTime _parseTimestamp(dynamic value) {
  if (value is int) {
    // Epoch seconds vs milliseconds heuristic:
    // if the value is > 1e12, it's likely milliseconds.
    if (value > 1e12) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
  }
  if (value is String) {
    return DateTime.tryParse(value)?.toUtc() ?? DateTime.now().toUtc();
  }
  return DateTime.now().toUtc();
}

/// Finds the [PlaylistSource] that owns a channel based on
/// [channel.sourceId] or ID prefix convention.
PlaylistSource? _findSource(List<PlaylistSource> sources, Channel channel) {
  if (channel.sourceId != null) {
    for (final s in sources) {
      if (s.id == channel.sourceId) return s;
    }
  }
  // Infer from ID prefix.
  if (channel.id.startsWith('xc_')) {
    for (final s in sources) {
      if (s.type == PlaylistSourceType.xtream) return s;
    }
  }
  if (channel.id.startsWith('stk_')) {
    for (final s in sources) {
      if (s.type == PlaylistSourceType.stalkerPortal) return s;
    }
  }
  return null;
}

/// Extracts the base URL (scheme + host + port) from a full URL.
String _baseUrl(String url) {
  final uri = Uri.parse(url);
  return '${uri.scheme}://${uri.host}${uri.hasPort ? ":${uri.port}" : ""}';
}
