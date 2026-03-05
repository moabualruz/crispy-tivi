part of 'memory_backend.dart';

/// Section builders: top picks, because you
/// watched, and popular in genre.
class _MemoryRecoSections {
  _MemoryRecoSections._();

  static const _maxBecauseSections = 3;

  static Map<String, dynamic> buildTopPicks({
    required List<Map<String, dynamic>> vods,
    required Set<dynamic> watchedIds,
    required Map<String, double> genreAffinity,
    required List<Map<String, dynamic>> history,
    required DateTime now,
  }) {
    final watchCounts = <String, int>{};
    final recentCutoff = now.subtract(const Duration(days: 7));
    for (final h in history) {
      final lastMs = (h['last_watched_ms'] as num).toInt();
      final lw = DateTime.fromMillisecondsSinceEpoch(lastMs);
      if (lw.isAfter(recentCutoff)) {
        final id = h['item_id'] as String;
        watchCounts[id] = (watchCounts[id] ?? 0) + 1;
      }
    }
    final maxWatches =
        watchCounts.values.isEmpty
            ? 1
            : watchCounts.values.reduce((a, b) => a > b ? a : b);
    final scored = <Map<String, dynamic>>[];
    for (final item in vods) {
      final id = item['id'] as String;
      if (watchedIds.contains(id)) continue;
      final itemType = item['type'] as String? ?? '';
      if (itemType == 'episode') continue;
      final cat = (item['category'] as String?)?.toLowerCase().trim() ?? '';
      final affinity = genreAffinity[cat] ?? 0.0;
      final addedAtStr = item['added_at'] as String?;
      double fresh = 0.0;
      if (addedAtStr != null) {
        final addedAt = DateTime.parse(addedAtStr);
        fresh = exp(-now.difference(addedAt).inDays.toDouble() / 14.0);
      }
      final numRating = parseRating(item['rating'] as String?);
      final ratingScore = numRating.clamp(0.0, 10.0) / 10.0;
      final trend = (watchCounts[id] ?? 0) / maxWatches.toDouble();
      final isFav = item['is_favorite'] == true;
      final favBoost = isFav ? 1.0 : 0.0;
      final score =
          affinity * _W.genreAffinity +
          favBoost * _W.favoriteBoost +
          fresh * _W.freshness +
          ratingScore * _W.contentRating +
          trend * _W.trendingBoost;
      scored.add(_recoToItem(item, 'topPick', score.clamp(0.0, 1.0)));
    }
    scored.sort(
      (a, b) => (b['score'] as double).compareTo(a['score'] as double),
    );
    return {
      'title': 'Top Picks for You',
      'section_type': 'topPicks',
      'items': scored.take(20).toList(),
    };
  }

  static List<Map<String, dynamic>> buildBecauseYouWatched({
    required List<Map<String, dynamic>> history,
    required List<Map<String, dynamic>> vods,
    required Set<dynamic> watchedIds,
  }) {
    final vodById = {for (final v in vods) v['id'] as String: v};
    final seenCategories = <String>{};
    final sourceItems = <Map<String, dynamic>>[];
    for (final h in history) {
      final mediaType = h['media_type'] as String;
      if (mediaType == 'channel') continue;
      final pct = (h['watched_percent'] as num).toDouble();
      if (pct < 0.25) continue;
      final id = h['item_id'] as String;
      final vod = vodById[id];
      final cat = vod?['category'] as String?;
      if (cat == null) continue;
      final normalized = cat.toLowerCase().trim();
      if (seenCategories.contains(normalized)) {
        continue;
      }
      seenCategories.add(normalized);
      sourceItems.add({...h, '_vod': vod});
      if (sourceItems.length >= _maxBecauseSections) {
        break;
      }
    }
    final sections = <Map<String, dynamic>>[];
    for (final source in sourceItems) {
      final sourceVod = source['_vod'] as Map<String, dynamic>?;
      if (sourceVod == null) continue;
      final sourceName = sourceVod['name'] as String;
      final cat = (sourceVod['category'] as String).toLowerCase().trim();
      final sourceYear = sourceVod['year'] as int?;
      final candidates =
          vods.where((item) {
            final id = item['id'] as String;
            if (watchedIds.contains(id)) {
              return false;
            }
            final t = item['type'] as String? ?? '';
            if (t == 'episode') return false;
            final ic = (item['category'] as String?)?.toLowerCase().trim();
            return ic == cat;
          }).toList();
      final scored =
          candidates.map((item) {
              double score = 0.5;
              final itemYear = item['year'] as int?;
              if (sourceYear != null && itemYear != null) {
                final diff = (sourceYear - itemYear).abs();
                if (diff < 3) score += 0.3;
                if (diff < 1) score += 0.1;
              }
              final numRating = parseRating(item['rating'] as String?);
              if (numRating > 0) {
                score += (numRating / 10.0) * 0.1;
              }
              final m = _recoToItem(
                item,
                'becauseYouWatched',
                score.clamp(0.0, 1.0),
              );
              m['source_item_name'] = sourceName;
              return m;
            }).toList()
            ..sort(
              (a, b) => (b['score'] as double).compareTo(a['score'] as double),
            );
      if (scored.isNotEmpty) {
        sections.add({
          'title':
              'Because you watched'
              ' $sourceName',
          'section_type': 'becauseYouWatched',
          'items': scored.take(10).toList(),
        });
      }
    }
    return sections;
  }

  static List<Map<String, dynamic>> buildPopularInGenre({
    required Map<String, double> genreAffinity,
    required List<Map<String, dynamic>> vods,
    required Set<dynamic> watchedIds,
    required List<Map<String, dynamic>> history,
    required int sectionSize,
  }) {
    if (genreAffinity.isEmpty) return [];
    final sortedGenres =
        genreAffinity.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final topGenres = sortedGenres.take(3).map((e) => e.key);
    final watchCounts = <String, int>{};
    for (final h in history) {
      final id = h['item_id'] as String;
      watchCounts[id] = (watchCounts[id] ?? 0) + 1;
    }
    final sections = <Map<String, dynamic>>[];
    for (final genre in topGenres) {
      final candidates =
          vods.where((item) {
            final id = item['id'] as String;
            if (watchedIds.contains(id)) {
              return false;
            }
            final t = item['type'] as String? ?? '';
            if (t == 'episode') return false;
            final c = (item['category'] as String?)?.toLowerCase().trim();
            return c == genre;
          }).toList();
      final scored =
          candidates.map((item) {
              final id = item['id'] as String;
              final watches = (watchCounts[id] ?? 0).toDouble();
              final numRating = parseRating(item['rating'] as String?);
              final hasAdded = item['added_at'] != null;
              final score =
                  watches * 0.4 +
                  (numRating / 10.0) * 0.3 +
                  (hasAdded ? 0.3 : 0.0);
              final m = _recoToItem(
                item,
                'popularInGenre',
                score.clamp(0.0, 1.0),
              );
              m['genre_name'] = _recoTitleCase(genre);
              return m;
            }).toList()
            ..sort(
              (a, b) => (b['score'] as double).compareTo(a['score'] as double),
            );
      if (scored.isNotEmpty) {
        sections.add({
          'title':
              'Popular in'
              ' ${_recoTitleCase(genre)}',
          'section_type': 'popularInGenre',
          'items': scored.take(sectionSize).toList(),
        });
      }
    }
    return sections;
  }
}
