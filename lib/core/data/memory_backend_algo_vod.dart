part of 'memory_backend.dart';

/// VOD sorting, categorization, episode-progress,
/// and content-rating algorithm implementations
/// for [MemoryBackend].
mixin _MemoryAlgoVodMixin on _MemoryStorage {
  // ── VOD Sorting & Categorization ──────────────

  Future<String> sortVodItems(String itemsJson, String sortBy) async {
    final list = _decodeMapList(itemsJson);
    switch (sortBy) {
      case 'name_asc':
        list.sort(
          (a, b) => (a['name'] as String? ?? '').toLowerCase().compareTo(
            (b['name'] as String? ?? '').toLowerCase(),
          ),
        );
      case 'name_desc':
        list.sort(
          (a, b) => (b['name'] as String? ?? '').toLowerCase().compareTo(
            (a['name'] as String? ?? '').toLowerCase(),
          ),
        );
      case 'year_desc':
        // Nulls-last: items without a year sort after those with one.
        list.sort((a, b) {
          final ay = a['year'] as int?;
          final by = b['year'] as int?;
          if (ay == null && by == null) return 0;
          if (ay == null) return 1;
          if (by == null) return -1;
          return by.compareTo(ay);
        });
      case 'rating_desc':
        list.sort((a, b) {
          final ra = parseRatingForSort(a['rating'] as String?);
          final rb = parseRatingForSort(b['rating'] as String?);
          if (ra.isNaN && rb.isNaN) return 0;
          if (ra.isNaN) return 1;
          if (rb.isNaN) return -1;
          return rb.compareTo(ra);
        });
      case 'added_desc':
        list.sort((a, b) {
          final at = a['added_at'] as String?;
          final bt = b['added_at'] as String?;
          if (bt == null && at == null) return 0;
          if (bt == null) return -1;
          if (at == null) return 1;
          return bt.compareTo(at);
        });
    }
    return jsonEncode(list);
  }

  Future<String> buildVodCategoryMap(String itemsJson) async {
    final list = _decodeMapList(itemsJson);
    final all = <String>{};
    final movies = <String>{};
    final series = <String>{};
    for (final item in list) {
      final cat = item['category'] as String?;
      if (cat == null || cat.isEmpty) continue;
      all.add(cat);
      final type = item['type'] as String? ?? '';
      if (type == 'movie') movies.add(cat);
      if (type == 'series') series.add(cat);
    }
    return jsonEncode({
      'categories': (all.toList()..sort()),
      'movie_categories': (movies.toList()..sort()),
      'series_categories': (series.toList()..sort()),
    });
  }

  Future<String> filterTopVod(String itemsJson, int limit) async {
    final list = _decodeMapList(itemsJson);

    // Mirrors Rust `filter_top_vod`: requires HTTP poster URL (not backdrop).
    bool hasHttpPoster(Map<String, dynamic> i) {
      final url = (i['poster_url'] as String? ?? '').trim();
      return url.isNotEmpty && url.toLowerCase().startsWith('http');
    }

    final rated =
        list.where((i) {
          final r = i['rating'] as String?;
          final hasRating = r != null && r.isNotEmpty;
          return hasRating && hasHttpPoster(i);
        }).toList();
    rated.sort((a, b) {
      final ra = parseRatingForSort(a['rating'] as String?);
      final rb = parseRatingForSort(b['rating'] as String?);
      if (ra.isNaN && rb.isNaN) return 0;
      if (ra.isNaN) return 1;
      if (rb.isNaN) return -1;
      return rb.compareTo(ra);
    });
    if (rated.length >= limit) {
      return jsonEncode(rated.take(limit).toList());
    }
    // Fallback: combine rated + byYear (poster-filtered, excluding rated ids).
    final ratedIds = rated.map((i) => i['id'] as String?).toSet();
    final byYear =
        list
            .where(
              (i) =>
                  i['year'] != null &&
                  !ratedIds.contains(i['id'] as String?) &&
                  hasHttpPoster(i),
            )
            .toList();
    byYear.sort(
      (a, b) => (b['year'] as int? ?? 0).compareTo(a['year'] as int? ?? 0),
    );
    final remaining = limit - rated.length;
    return jsonEncode([...rated, ...byYear.take(remaining)]);
  }

  Future<String> computeEpisodeProgress(
    String historyJson,
    String seriesId,
  ) async {
    final entries = _decodeMapList(historyJson);
    final progressMap = <String, double>{};
    String? latestTs;
    String? latestEp;
    for (final entry in entries) {
      final meta = entry['metadata'] as Map<String, dynamic>?;
      if (meta == null) continue;
      final sid = meta['series_id'] as String?;
      if (sid != seriesId) continue;
      final eid = meta['episode_id'] as String?;
      if (eid == null) continue;
      final pos = entry['position_ms'] as int? ?? 0;
      final dur = entry['duration_ms'] as int? ?? 0;
      final progress = dur <= 0 ? 0.0 : (pos / dur).clamp(0.0, 1.0);
      progressMap[eid] = progress;
      final ts = entry['last_watched'] as String?;
      if (ts != null && (latestTs == null || ts.compareTo(latestTs) > 0)) {
        latestTs = ts;
        latestEp = eid;
      }
    }
    return jsonEncode({
      'progress_map': progressMap,
      'last_watched_episode_id': latestEp,
    });
  }

  Future<String> computeEpisodeProgressFromDb(String seriesId) async {
    // In MemoryBackend, query watchHistory map.
    final progressMap = <String, double>{};
    String? latestTs;
    String? latestUrl;
    for (final entry in watchHistory.values) {
      final sid = entry['series_id'] as String?;
      if (sid != seriesId) continue;
      final dur = entry['duration_ms'] as int? ?? 0;
      if (dur <= 0) continue;
      final pos = entry['position_ms'] as int? ?? 0;
      final url = entry['stream_url'] as String;
      progressMap[url] = (pos / dur).clamp(0.0, 1.0);
      final ts = entry['last_watched'] as String?;
      if (ts != null && (latestTs == null || ts.compareTo(latestTs) > 0)) {
        latestTs = ts;
        latestUrl = url;
      }
    }
    return jsonEncode({
      'progress_map': progressMap,
      'last_watched_url': latestUrl,
    });
  }

  Future<String> filterVodByContentRating(
    String itemsJson,
    int maxRatingValue,
  ) async {
    final items = _decodeMapList(itemsJson);
    final filtered =
        items.where((item) {
          final level = _parseContentRating(item['rating'] as String?);
          return level == 5 || level <= maxRatingValue;
        }).toList();
    return jsonEncode(filtered);
  }

  Future<String> buildTypeCategories(String itemsJson, String vodType) async {
    final list = _decodeMapList(itemsJson);
    final cats = <String>{};
    for (final item in list) {
      final type = item['type'] as String? ?? '';
      if (type != vodType) continue;
      final cat = item['category'] as String?;
      if (cat != null && cat.isNotEmpty) {
        cats.add(cat);
      }
    }
    return jsonEncode(cats.toList()..sort());
  }

  Future<String> filterRecentlyAdded(
    String itemsJson,
    int cutoffDays,
    int nowMs,
  ) async {
    final list = _decodeMapList(itemsJson);
    final cutoffMs = nowMs - Duration(days: cutoffDays).inMilliseconds;
    final filtered =
        list.where((item) {
          final addedAt = item['added_at'];
          if (addedAt == null) return false;
          int? ms;
          if (addedAt is int) {
            ms = addedAt;
          } else if (addedAt is String) {
            ms = DateTime.tryParse(addedAt)?.millisecondsSinceEpoch;
          }
          return ms != null && ms > cutoffMs;
        }).toList();
    // Sort newest first.
    filtered.sort((a, b) {
      String? at = a['added_at'] is String ? a['added_at'] as String : null;
      String? bt = b['added_at'] is String ? b['added_at'] as String : null;
      if (at != null && bt != null) return bt.compareTo(at);
      if (at != null) return -1;
      if (bt != null) return 1;
      return 0;
    });
    return jsonEncode(filtered);
  }

  static int _parseContentRating(String? rating) {
    if (rating == null || rating.isEmpty) {
      return 5;
    }
    final s = rating.toUpperCase().trim();
    if (s.contains('NC-17') || s == 'NC17') {
      return 4;
    }
    if (s.contains('TV-MA') || s == 'TVMA') {
      return 4;
    }
    if (s == 'R' || s == 'RATED R') return 3;
    if (s.contains('PG-13') || s == 'PG13') {
      return 2;
    }
    if (s.contains('TV-14') || s == 'TV14') {
      return 2;
    }
    if (s == 'PG' || s == 'RATED PG') return 1;
    if (s.contains('TV-PG') || s == 'TVPG') {
      return 1;
    }
    if (s == 'G' || s == 'RATED G') return 0;
    if (s.contains('TV-G') || s == 'TVG') {
      return 0;
    }
    if (s.contains('TV-Y')) return 0;
    return 5;
  }
}
