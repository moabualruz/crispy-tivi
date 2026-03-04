part of 'memory_backend.dart';

/// Trending, new-for-you, and cold-start
/// recommendation section builders.
class _MemoryRecoTrending {
  _MemoryRecoTrending._();

  static Map<String, dynamic> buildTrending({
    required List<Map<String, dynamic>> history,
    required List<Map<String, dynamic>> vods,
    required Set<dynamic> watchedIds,
    required DateTime now,
    required int sectionSize,
  }) {
    final cutoff = now.subtract(const Duration(days: 7));
    final watchCounts = <String, int>{};
    for (final h in history) {
      final lastMs = (h['last_watched_ms'] as num).toInt();
      final lw = DateTime.fromMillisecondsSinceEpoch(lastMs);
      final mediaType = h['media_type'] as String;
      if (lw.isAfter(cutoff) && mediaType != 'channel') {
        final id = h['item_id'] as String;
        watchCounts[id] = (watchCounts[id] ?? 0) + 1;
      }
    }
    final vodById = {for (final v in vods) v['id'] as String: v};
    final sorted =
        watchCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final items = <Map<String, dynamic>>[];
    for (final entry in sorted) {
      if (watchedIds.contains(entry.key)) {
        continue;
      }
      final vod = vodById[entry.key];
      if (vod == null) continue;
      final t = vod['type'] as String? ?? '';
      if (t == 'episode') continue;
      items.add(
        _recoToItem(
          vod,
          'trending',
          entry.value.toDouble() / sorted.first.value.toDouble(),
        ),
      );
      if (items.length >= sectionSize) break;
    }
    return {
      'title': 'Trending Now',
      'section_type': 'trending',
      'items': items,
    };
  }

  static Map<String, dynamic> buildNewForYou({
    required List<Map<String, dynamic>> vods,
    required Set<dynamic> watchedIds,
    required Map<String, double> genreAffinity,
    required DateTime now,
    required int sectionSize,
  }) {
    final cutoff = now.subtract(const Duration(days: 14));
    final candidates =
        vods.where((item) {
          final id = item['id'] as String;
          if (watchedIds.contains(id)) return false;
          final t = item['type'] as String? ?? '';
          if (t == 'episode') return false;
          final addedAtStr = item['added_at'] as String?;
          if (addedAtStr == null) return false;
          return DateTime.parse(addedAtStr).isAfter(cutoff);
        }).toList();
    final scored =
        candidates.map((item) {
            final cat =
                (item['category'] as String?)?.toLowerCase().trim() ?? '';
            final affinity = genreAffinity[cat] ?? 0.0;
            final ratingStr = item['rating'] as String? ?? '0';
            final numRating = double.tryParse(ratingStr) ?? 0.0;
            final score = affinity * 0.7 + (numRating / 10.0) * 0.3;
            return _recoToItem(item, 'newForYou', score.clamp(0.0, 1.0));
          }).toList()
          ..sort(
            (a, b) => (b['score'] as double).compareTo(a['score'] as double),
          );
    return {
      'title': 'New for You',
      'section_type': 'newForYou',
      'items': scored.take(sectionSize).toList(),
    };
  }

  static List<Map<String, dynamic>> buildColdStart({
    required List<Map<String, dynamic>> vods,
    required Set<dynamic> watchedIds,
  }) {
    final sections = <Map<String, dynamic>>[];
    final rated =
        vods.where((item) {
            final id = item['id'] as String;
            if (watchedIds.contains(id)) return false;
            final t = item['type'] as String? ?? '';
            if (t == 'episode') return false;
            return double.tryParse(item['rating'] as String? ?? '') != null;
          }).toList()
          ..sort((a, b) {
            final ra = double.parse(a['rating'] as String);
            final rb = double.parse(b['rating'] as String);
            return rb.compareTo(ra);
          });
    if (rated.isNotEmpty) {
      sections.add({
        'title': 'Highly Rated',
        'section_type': 'coldStart',
        'items':
            rated
                .take(15)
                .map((v) => _recoToItem(v, 'coldStart', _vodRatingScore(v)))
                .toList(),
      });
    }
    final recent =
        vods.where((item) {
            final id = item['id'] as String;
            if (watchedIds.contains(id)) return false;
            final t = item['type'] as String? ?? '';
            if (t == 'episode') return false;
            return item['added_at'] != null;
          }).toList()
          ..sort((a, b) {
            final aa = DateTime.parse(a['added_at'] as String);
            final bb = DateTime.parse(b['added_at'] as String);
            return bb.compareTo(aa);
          });
    if (recent.isNotEmpty) {
      sections.add({
        'title': 'Recently Added',
        'section_type': 'coldStart',
        'items':
            recent
                .take(15)
                .map((v) => _recoToItem(v, 'coldStart', _vodRatingScore(v)))
                .toList(),
      });
    }
    return sections;
  }
}
