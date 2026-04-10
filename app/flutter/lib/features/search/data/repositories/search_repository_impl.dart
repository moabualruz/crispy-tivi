import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/cache_service.dart';
import '../../../../core/data/crispy_backend.dart';
import '../../../../core/domain/entities/media_item.dart';
import '../../../../core/domain/entities/media_type.dart';
import '../../../../core/domain/media_source.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../iptv/domain/entities/epg_entry.dart';
import '../../../vod/domain/entities/vod_item.dart';
import '../../domain/constants/search_source_key.dart';
import '../../domain/entities/grouped_search_results.dart';
import '../../domain/entities/search_filter.dart';
import '../../domain/repositories/search_repository.dart';

/// Implementation of [SearchRepository] that delegates
/// channel/VOD/EPG filtering to the Rust backend via
/// [CrispyBackend.searchContent].
///
/// Media server search stays in Dart because it
/// involves async I/O with external services.
class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl(this._backend, this._cache);

  final CrispyBackend _backend;
  final CacheService _cache;

  List<Channel>? _cachedChannelsRef;
  String _cachedChannelsJson = '[]';
  Map<String, Channel> _cachedChannelMap = const {};

  List<VodItem>? _cachedVodItemsRef;
  String _cachedVodItemsJson = '[]';
  Map<String, VodItem> _cachedVodMap = const {};

  Map<String, List<EpgEntry>>? _cachedEpgEntriesRef;
  String _cachedEpgJson = '{}';

  @override
  Future<GroupedSearchResults> search(
    String query, {
    required SearchFilter filter,
    required List<MediaSource> sources,
    List<VodItem>? vodItems,
    Map<String, List<EpgEntry>>? epgEntries,
    List<Channel>? channels,
  }) async {
    final q = query.trim();
    if (q.isEmpty) {
      return GroupedSearchResults.empty;
    }

    // ── Serialize inputs ──────────────────────
    final chJson = _encodeChannels(channels);
    final vdJson = _encodeVodItems(vodItems);
    final epgJson = _encodeEpg(epgEntries);

    // ── Delegate filtering to Rust ────────────
    final resultJson = await _backend.searchContent(
      query: q,
      channelsJson: chJson,
      vodItemsJson: vdJson,
      epgEntriesJson: epgJson,
      filterJson: _encodeFilter(filter),
    );

    // ── Enrich results via Rust ───────────────
    final enrichedJson = await _backend.enrichSearchResults(
      q,
      resultJson,
      chJson,
      vdJson,
    );

    // ── Group enriched results ────────────────
    final grouped = _groupEnriched(enrichedJson, channels, vodItems);

    // ── Media server search (stays Dart) ──────
    final mediaServerResults = <MediaItem>[];
    for (final source in sources) {
      try {
        final items = await source.search(query);
        for (final item in items) {
          final meta = Map<String, dynamic>.from(item.metadata);
          meta['mediaSource'] = source;

          mediaServerResults.add(
            MediaItem(
              id: item.id,
              name: item.name,
              type: item.type,
              parentId: item.parentId,
              logoUrl: item.logoUrl,
              overview: item.overview,
              releaseDate: item.releaseDate,
              rating: item.rating,
              durationMs: item.durationMs,
              streamUrl: item.streamUrl,
              metadata: meta,
            ),
          );
        }
      } catch (_) {
        // Ignore individual source failures
      }
    }

    return GroupedSearchResults(
      channels: grouped.channels,
      movies: grouped.movies,
      series: grouped.series,
      epgPrograms: grouped.epgPrograms,
      mediaServerItems: mediaServerResults,
    );
  }

  // ── Serialization helpers ───────────────────────

  String _encodeChannels(List<Channel>? channels) {
    if (identical(channels, _cachedChannelsRef)) {
      return _cachedChannelsJson;
    }
    if (channels == null || channels.isEmpty) {
      _cachedChannelsRef = channels;
      _cachedChannelsJson = '[]';
      _cachedChannelMap = const {};
      return _cachedChannelsJson;
    }
    _cachedChannelsRef = channels;
    _cachedChannelsJson = jsonEncode(channels.map(channelToMap).toList());
    _cachedChannelMap = {for (final channel in channels) channel.id: channel};
    return _cachedChannelsJson;
  }

  String _encodeVodItems(List<VodItem>? vodItems) {
    if (identical(vodItems, _cachedVodItemsRef)) {
      return _cachedVodItemsJson;
    }
    if (vodItems == null || vodItems.isEmpty) {
      _cachedVodItemsRef = vodItems;
      _cachedVodItemsJson = '[]';
      _cachedVodMap = const {};
      return _cachedVodItemsJson;
    }
    _cachedVodItemsRef = vodItems;
    _cachedVodItemsJson = jsonEncode(vodItems.map(vodItemToMap).toList());
    _cachedVodMap = {for (final item in vodItems) item.id: item};
    return _cachedVodItemsJson;
  }

  String _encodeEpg(Map<String, List<EpgEntry>>? epgEntries) {
    if (identical(epgEntries, _cachedEpgEntriesRef)) {
      return _cachedEpgJson;
    }
    if (epgEntries == null || epgEntries.isEmpty) {
      _cachedEpgEntriesRef = epgEntries;
      return _cachedEpgJson = '{}';
    }
    final map = <String, List<Map<String, dynamic>>>{};
    for (final entry in epgEntries.entries) {
      map[entry.key] = entry.value.map(epgEntryToMap).toList();
    }
    _cachedEpgEntriesRef = epgEntries;
    return _cachedEpgJson = jsonEncode(map);
  }

  String _encodeFilter(SearchFilter filter) {
    return jsonEncode({
      'search_channels': filter.isTypeEnabled(SearchContentType.channels),
      'search_movies': filter.isTypeEnabled(SearchContentType.movies),
      'search_series': filter.isTypeEnabled(SearchContentType.series),
      'search_epg': filter.isTypeEnabled(SearchContentType.epg),
      'search_in_description': filter.searchInDescription,
      'category': filter.category,
      'year_min': filter.yearMin,
      'year_max': filter.yearMax,
    });
  }

  // ── Enriched result grouping ──────────────────

  // NOTE: Intentionally separate from Rust `group_search_results()`
  // (lib/src/rust/api/algorithms.dart).
  //
  // The Rust function returns a flat JSON struct with primitive fields
  // (logo_url, stream_url, year, etc.) — useful for Rust-only pipelines.
  // This Dart method does something Rust cannot: it embeds live typed Dart
  // entity references (Channel, VodItem, EpgEntry) into each MediaItem's
  // `metadata` map so that the UI can access the full domain objects without
  // a second lookup.  Those typed Dart objects cannot cross the FFI boundary,
  // so this materialisation step must remain on the Dart side.
  //
  // Do NOT replace this with a call to `groupSearchResults()` from Rust —
  // you would lose the typed entity references and break every widget that
  // reads `metadata['channel']`, `metadata['vodItem']`, or
  // `metadata['epgEntry']`.

  /// Groups the flat enriched results from the
  /// Rust backend into [GroupedSearchResults],
  /// looking up original Dart entities for
  /// metadata.
  GroupedSearchResults _groupEnriched(
    String enrichedJson,
    List<Channel>? channels,
    List<VodItem>? vodItems,
  ) {
    final enriched =
        (jsonDecode(enrichedJson) as List<dynamic>)
            .cast<Map<String, dynamic>>();
    if (enriched.isEmpty) {
      return GroupedSearchResults.empty;
    }

    // Build lookup maps for original entities.
    final chMap =
        identical(channels, _cachedChannelsRef)
            ? _cachedChannelMap
            : {
              for (final channel in channels ?? const <Channel>[])
                channel.id: channel,
            };
    final vMap =
        identical(vodItems, _cachedVodItemsRef)
            ? _cachedVodMap
            : {for (final item in vodItems ?? const <VodItem>[]) item.id: item};

    final chResults = <MediaItem>[];
    final mvResults = <MediaItem>[];
    final srResults = <MediaItem>[];
    final epgResults = <MediaItem>[];

    for (final r in enriched) {
      final id = r['id'] as String;
      final name = r['name'] as String;
      final mediaType = r['media_type'] as String;
      final meta = r['metadata'] as Map<String, dynamic>?;

      switch (mediaType) {
        case 'channel':
          final ch = chMap[id];
          chResults.add(
            MediaItem(
              id: id,
              name: name,
              type: MediaType.channel,
              logoUrl: meta?['logo_url'] as String? ?? ch?.logoUrl,
              streamUrl: meta?['stream_url'] as String? ?? ch?.streamUrl,
              metadata: {
                if (ch != null) 'channel': ch,
                'source': SearchSourceKey.iptv,
              },
            ),
          );
        case 'movie':
          final v = vMap[id];
          final year = meta?['year'] as int? ?? v?.year;
          mvResults.add(
            MediaItem(
              id: id,
              name: name,
              type: MediaType.movie,
              logoUrl:
                  meta?['poster_url'] as String? ??
                  v?.posterUrl ??
                  v?.backdropUrl,
              streamUrl: meta?['stream_url'] as String? ?? v?.streamUrl,
              rating: meta?['rating'] as String? ?? v?.rating,
              releaseDate: year != null ? DateTime(year) : null,
              durationMs: meta?['duration'] as int? ?? v?.duration,
              overview: meta?['description'] as String? ?? v?.description,
              metadata: {
                if (v != null) 'vodItem': v,
                'source': SearchSourceKey.iptvVod,
                'category': meta?['category'] as String? ?? v?.category,
              },
            ),
          );
        case 'series':
          final v = vMap[id];
          final year = meta?['year'] as int? ?? v?.year;
          srResults.add(
            MediaItem(
              id: id,
              name: name,
              type: MediaType.series,
              logoUrl:
                  meta?['poster_url'] as String? ??
                  v?.posterUrl ??
                  v?.backdropUrl,
              streamUrl: meta?['stream_url'] as String? ?? v?.streamUrl,
              rating: meta?['rating'] as String? ?? v?.rating,
              releaseDate: year != null ? DateTime(year) : null,
              durationMs: meta?['duration'] as int? ?? v?.duration,
              overview: meta?['description'] as String? ?? v?.description,
              metadata: {
                if (v != null) 'vodItem': v,
                'source': SearchSourceKey.iptvVod,
                'category': meta?['category'] as String? ?? v?.category,
              },
            ),
          );
        case 'epg':
          final ch = chMap[id];
          final entryMap = meta?['entry'] as Map<String, dynamic>?;
          final entry = entryMap != null ? mapToEpgEntry(entryMap) : null;
          final startTime = entry?.startTime;
          final endTime = entry?.endTime;
          final durMs =
              startTime != null && endTime != null
                  ? endTime.difference(startTime).inMilliseconds
                  : null;

          epgResults.add(
            MediaItem(
              id:
                  '${id}_'
                  '${startTime?.millisecondsSinceEpoch ?? 0}',
              name: entry?.title ?? name,
              type: MediaType.channel,
              logoUrl:
                  entry?.iconUrl ?? meta?['logo_url'] as String? ?? ch?.logoUrl,
              streamUrl: meta?['stream_url'] as String? ?? ch?.streamUrl,
              overview: entry?.description,
              releaseDate: startTime,
              durationMs: durMs,
              metadata: {
                if (ch != null) 'channel': ch,
                if (entry != null) 'epgEntry': entry,
                'source': SearchSourceKey.iptvEpg,
              },
            ),
          );
      }
    }

    return GroupedSearchResults(
      channels: chResults,
      movies: mvResults,
      series: srResults,
      epgPrograms: epgResults,
    );
  }

  @override
  List<String> buildSearchCategories(
    List<String> vodCategories,
    List<String> channelGroups,
  ) => _cache.buildSearchCategories(vodCategories, channelGroups);
}

/// Riverpod provider for [SearchRepository].
final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepositoryImpl(
    ref.read(crispyBackendProvider),
    ref.read(cacheServiceProvider),
  );
});
