part of 'memory_backend.dart';

/// Recommendation engine, section parsing, and
/// deserialization methods for [MemoryBackend].
mixin _MemoryRecommendationsMixin on _MemoryStorage {
  Future<String> computeRecommendations({
    required String vodItemsJson,
    required String channelsJson,
    required String historyJson,
    required List<String> favoriteChannelIds,
    required List<String> favoriteVodIds,
    required int maxAllowedRating,
    required int nowUtcMs,
  }) async {
    return _MemoryRecommendations.compute(
      vodItemsJson: vodItemsJson,
      channelsJson: channelsJson,
      historyJson: historyJson,
      favoriteChannelIds: favoriteChannelIds,
      favoriteVodIds: favoriteVodIds,
      maxAllowedRating: maxAllowedRating,
      nowUtcMs: nowUtcMs,
    );
  }

  Future<String> parseRecommendationSections(String sectionsJson) async {
    final raw =
        (jsonDecode(sectionsJson) as List<dynamic>)
            .cast<Map<String, dynamic>>();
    final typed = <Map<String, dynamic>>[];
    for (final section in raw) {
      final rawItems =
          (section['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          <Map<String, dynamic>>[];
      final typedItems =
          rawItems.map((item) {
            return <String, dynamic>{
              'id': item['id'],
              'name': item['title'] ?? item['name'],
              'media_type': item['media_type'],
              'reason_type': item['reason'],
              'score': item['score'],
              'source_title': item['source_item_name'],
              'genre': item['category'],
            };
          }).toList();
      typed.add({
        'title': section['title'],
        'section_type': section['section_type'],
        'items': typedItems,
      });
    }
    return jsonEncode(typed);
  }

  Future<String> deserializeRecommendationSections(String sectionsJson) async {
    final raw =
        (jsonDecode(sectionsJson) as List<dynamic>)
            .cast<Map<String, dynamic>>();
    final full = <Map<String, dynamic>>[];
    for (final section in raw) {
      final rawItems =
          (section['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          <Map<String, dynamic>>[];
      final fullItems =
          rawItems.map((item) {
            final rating = item['rating'];
            return <String, dynamic>{
              'id': item['id'],
              'name': item['title'] ?? item['name'],
              'media_type': item['media_type'],
              'score': item['score'],
              'reason_type': item['reason'],
              'source_title': item['source_item_name'],
              'genre': item['category'],
              'poster_url': item['poster_url'],
              'category': item['category'],
              'stream_url': item['stream_url'],
              'rating': rating != null ? '$rating' : null,
              'year': item['year'],
              'series_id': item['series_id'],
            };
          }).toList();
      full.add({
        'title': section['title'],
        'section_type': section['section_type'],
        'items': fullItems,
      });
    }
    return jsonEncode(full);
  }
}

// ── Dart reference recommendation engine ────────
// Mirrors the scoring algorithm so MemoryBackend
// produces realistic results in tests.

/// Scoring weights for recommendation signals.
abstract final class _W {
  static const double genreAffinity = 0.30;
  static const double favoriteBoost = 0.20;
  static const double freshness = 0.20;
  static const double contentRating = 0.15;
  static const double trendingBoost = 0.15;
}

/// Core recommendation engine: compute entry
/// point, genre affinity, and shared helpers.
class _MemoryRecommendations {
  static const _coldStartThreshold = 3;
  static const _sectionSize = 15;

  static String compute({
    required String vodItemsJson,
    required String channelsJson,
    required String historyJson,
    required List<String> favoriteChannelIds,
    required List<String> favoriteVodIds,
    required int maxAllowedRating,
    required int nowUtcMs,
  }) {
    final vods =
        (jsonDecode(vodItemsJson) as List).cast<Map<String, dynamic>>();
    final chans =
        (jsonDecode(channelsJson) as List).cast<Map<String, dynamic>>();
    final history =
        (jsonDecode(historyJson) as List).cast<Map<String, dynamic>>();
    final favChannelSet = favoriteChannelIds.toSet();
    final now = DateTime.fromMillisecondsSinceEpoch(nowUtcMs);
    final watchedIds = history.map((h) => h['item_id']).toSet();
    final genreAffinity = _buildGenreAffinity(
      history: history,
      favChannelIds: favChannelSet,
      vods: vods,
      channels: chans,
      now: now,
    );

    if (history.length < _coldStartThreshold) {
      return jsonEncode(
        _MemoryRecoTrending.buildColdStart(vods: vods, watchedIds: watchedIds),
      );
    }

    final sections = <Map<String, dynamic>>[];

    final topPicks = _MemoryRecoSections.buildTopPicks(
      vods: vods,
      watchedIds: watchedIds,
      genreAffinity: genreAffinity,
      history: history,
      now: now,
    );
    if ((topPicks['items'] as List).isNotEmpty) {
      sections.add(topPicks);
    }

    sections.addAll(
      _MemoryRecoSections.buildBecauseYouWatched(
        history: history,
        vods: vods,
        watchedIds: watchedIds,
      ),
    );

    sections.addAll(
      _MemoryRecoSections.buildPopularInGenre(
        genreAffinity: genreAffinity,
        vods: vods,
        watchedIds: watchedIds,
        history: history,
        sectionSize: _sectionSize,
      ),
    );

    final trending = _MemoryRecoTrending.buildTrending(
      history: history,
      vods: vods,
      watchedIds: watchedIds,
      now: now,
      sectionSize: _sectionSize,
    );
    if ((trending['items'] as List).isNotEmpty) {
      sections.add(trending);
    }

    final newForYou = _MemoryRecoTrending.buildNewForYou(
      vods: vods,
      watchedIds: watchedIds,
      genreAffinity: genreAffinity,
      now: now,
      sectionSize: _sectionSize,
    );
    if ((newForYou['items'] as List).isNotEmpty) {
      sections.add(newForYou);
    }

    return jsonEncode(sections);
  }

  static Map<String, double> _buildGenreAffinity({
    required List<Map<String, dynamic>> history,
    required Set<String> favChannelIds,
    required List<Map<String, dynamic>> vods,
    required List<Map<String, dynamic>> channels,
    required DateTime now,
  }) {
    final scores = <String, double>{};
    final vodById = {for (final v in vods) v['id'] as String: v};
    final channelById = {for (final c in channels) c['id'] as String: c};
    for (final entry in history) {
      final id = entry['item_id'] as String;
      final mediaType = entry['media_type'] as String;
      String? category;
      if (mediaType == 'channel') {
        category = channelById[id]?['channel_group'] as String?;
      } else {
        category = vodById[id]?['category'] as String?;
      }
      if (category == null) continue;
      final normalized = category.toLowerCase().trim();
      final lastMs = entry['last_watched_ms'] as num;
      final lastWatched = DateTime.fromMillisecondsSinceEpoch(lastMs.toInt());
      final days = now.difference(lastWatched).inDays.toDouble();
      final decay = exp(-days / 30.0);
      final pct = (entry['watched_percent'] as num).toDouble();
      double signal;
      if (pct >= kCompletionThreshold) {
        signal = 1.0;
      } else if (pct > 0.1) {
        signal = 0.5;
      } else {
        signal = 0.2;
      }
      scores[normalized] = (scores[normalized] ?? 0) + signal * decay;
    }
    for (final favId in favChannelIds) {
      final channel = channelById[favId];
      final group = channel?['channel_group'] as String?;
      if (group != null) {
        final normalized = group.toLowerCase().trim();
        scores[normalized] = (scores[normalized] ?? 0) + 1.5;
      }
    }
    for (final vod in vods) {
      final isFav = vod['is_favorite'] == true;
      final cat = vod['category'] as String?;
      if (isFav && cat != null) {
        final normalized = cat.toLowerCase().trim();
        scores[normalized] = (scores[normalized] ?? 0) + 1.5;
      }
    }
    if (scores.isEmpty) return scores;
    final maxScore = scores.values.reduce((a, b) => a > b ? a : b);
    if (maxScore > 0) {
      for (final key in scores.keys.toList()) {
        scores[key] = scores[key]! / maxScore;
      }
    }
    return scores;
  }
}

// ── Shared helpers ──────────────────────────────

double _vodRatingScore(Map<String, dynamic> v) {
  final r =
      double.tryParse(
        v['rating'] as String? ?? '',
      )?.clamp(0.0, 10.0).toDouble();
  return (r ?? 0.0) / 10.0;
}

Map<String, dynamic> _recoToItem(
  Map<String, dynamic> item,
  String reason,
  double score,
) {
  final itemType = item['type'] as String? ?? 'movie';
  final mediaType = itemType == 'series' ? 'series' : 'movie';
  return {
    'id': item['id'],
    'title': item['name'],
    'poster_url': item['poster_url'],
    'backdrop_url': item['backdrop_url'],
    'rating': item['rating'],
    'year': item['year'],
    'media_type': mediaType,
    'reason': reason,
    'score': score,
    'category': item['category'],
    'stream_url': item['stream_url'],
    'series_id': item['series_id'],
  };
}

String _recoTitleCase(String input) {
  if (input.isEmpty) return input;
  return input
      .split(' ')
      .map(
        (w) =>
            w.isEmpty
                ? w
                : '${w[0].toUpperCase()}'
                    '${w.substring(1)}',
      )
      .join(' ');
}
