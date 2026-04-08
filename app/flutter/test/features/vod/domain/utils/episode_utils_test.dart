import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/player/domain/entities/watch_history_entry.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';
import 'package:crispy_tivi/features/vod/data/episode_progress_codec.dart';
import 'package:crispy_tivi/features/vod/domain/utils/episode_utils.dart';

// ── Helpers ────────────────────────────────────────────

VodItem _ep({
  required String id,
  required int season,
  required int episode,
  String seriesId = 'series_1',
}) => VodItem(
  id: id,
  name: 'S${season}E${episode.toString().padLeft(2, '0')}',
  streamUrl: 'http://x.com/$id.mkv',
  type: VodType.episode,
  seriesId: seriesId,
  seasonNumber: season,
  episodeNumber: episode,
);

WatchHistoryEntry _entry({
  required String id,
  required String mediaType,
  int positionMs = 0,
  int durationMs = 0,
  String? seriesId,
  int? season,
  int? episode,
}) => WatchHistoryEntry(
  id: id,
  mediaType: mediaType,
  name: id,
  streamUrl: 'http://x.com/$id.mkv',
  positionMs: positionMs,
  durationMs: durationMs,
  lastWatched: DateTime(2024),
  seriesId: seriesId,
  seasonNumber: season,
  episodeNumber: episode,
);

// ── resolveNextEpisodes ────────────────────────────────

void main() {
  group('resolveNextEpisodes', () {
    final ep1 = _ep(id: 'e1', season: 1, episode: 1);
    final ep2 = _ep(id: 'e2', season: 1, episode: 2);
    final ep3 = _ep(id: 'e3', season: 2, episode: 1);
    final allVod = [ep1, ep2, ep3];

    test('returns non-episode entries unchanged', () {
      final entry = _entry(
        id: 'movie_1',
        mediaType: 'movie',
        positionMs: 950,
        durationMs: 1000,
      );
      final result = resolveNextEpisodes([entry], allVod);
      expect(result.single.id, 'movie_1');
    });

    test('returns episode with zero duration unchanged', () {
      final entry = _entry(
        id: 'e1',
        mediaType: 'episode',
        positionMs: 0,
        durationMs: 0,
        seriesId: 'series_1',
        season: 1,
        episode: 1,
      );
      final result = resolveNextEpisodes([entry], allVod);
      expect(result.single.id, 'e1');
    });

    test('keeps entry when progress < threshold', () {
      // positionMs/durationMs = 80% < 90%
      final entry = _entry(
        id: 'e1',
        mediaType: 'episode',
        positionMs: 800,
        durationMs: 1000,
        seriesId: 'series_1',
        season: 1,
        episode: 1,
      );
      final result = resolveNextEpisodes([entry], allVod);
      expect(result.single.id, 'e1');
    });

    test('substitutes next episode when progress >= threshold', () {
      // positionMs/durationMs = 95% >= 90%
      final entry = _entry(
        id: 'e1',
        mediaType: 'episode',
        positionMs: 950,
        durationMs: 1000,
        seriesId: 'series_1',
        season: 1,
        episode: 1,
      );
      final result = resolveNextEpisodes([entry], allVod);
      expect(result.single.id, 'e2');
      expect(result.single.seasonNumber, 1);
      expect(result.single.episodeNumber, 2);
    });

    test('substitutes across season boundary', () {
      final entry = _entry(
        id: 'e2',
        mediaType: 'episode',
        positionMs: 950,
        durationMs: 1000,
        seriesId: 'series_1',
        season: 1,
        episode: 2,
      );
      final result = resolveNextEpisodes([entry], allVod);
      expect(result.single.id, 'e3');
      expect(result.single.seasonNumber, 2);
      expect(result.single.episodeNumber, 1);
    });

    test('keeps last episode entry when no next episode exists', () {
      final entry = _entry(
        id: 'e3',
        mediaType: 'episode',
        positionMs: 950,
        durationMs: 1000,
        seriesId: 'series_1',
        season: 2,
        episode: 1,
      );
      final result = resolveNextEpisodes([entry], allVod);
      expect(result.single.id, 'e3');
    });

    test('preserves sort order across multiple entries', () {
      final entries = [
        _entry(
          id: 'e1',
          mediaType: 'episode',
          positionMs: 950,
          durationMs: 1000,
          seriesId: 'series_1',
          season: 1,
          episode: 1,
        ),
        _entry(
          id: 'e2',
          mediaType: 'episode',
          positionMs: 500,
          durationMs: 1000,
          seriesId: 'series_1',
          season: 1,
          episode: 2,
        ),
      ];
      final result = resolveNextEpisodes(entries, allVod);
      expect(result.length, 2);
      // First entry (90%+ complete) substituted to ep2
      expect(result[0].id, 'e2');
      // Second entry (<90% complete) kept as-is
      expect(result[1].id, 'e2');
    });

    test('keeps entry when seriesId is null', () {
      final entry = _entry(
        id: 'e1',
        mediaType: 'episode',
        positionMs: 950,
        durationMs: 1000,
      );
      final result = resolveNextEpisodes([entry], allVod);
      expect(result.single.id, 'e1');
    });

    test('returns empty list for empty input', () {
      expect(resolveNextEpisodes([], allVod), isEmpty);
    });
  });

  // ── episodeCountBySeason ──────────────────────────────

  group('episodeCountBySeason', () {
    test('returns empty map for empty list', () {
      expect(episodeCountBySeason([]), isEmpty);
    });

    test('counts episodes per season', () {
      final episodes = [
        _ep(id: 'e1', season: 1, episode: 1),
        _ep(id: 'e2', season: 1, episode: 2),
        _ep(id: 'e3', season: 2, episode: 1),
      ];
      final counts = episodeCountBySeason(episodes);
      expect(counts[1], 2);
      expect(counts[2], 1);
    });

    test('ignores episodes with null seasonNumber', () {
      final episodes = [
        const VodItem(
          id: 'e_null',
          name: 'No Season',
          streamUrl: 'http://x.com/null.mkv',
          type: VodType.episode,
        ),
        _ep(id: 'e1', season: 1, episode: 1),
      ];
      final counts = episodeCountBySeason(episodes);
      expect(counts.length, 1);
      expect(counts[1], 1);
    });

    test('handles single episode', () {
      final counts = episodeCountBySeason([
        _ep(id: 'e1', season: 3, episode: 7),
      ]);
      expect(counts[3], 1);
    });
  });

  // ── upNextIndex ───────────────────────────────────────

  group('upNextIndex', () {
    final ep1 = _ep(id: 'e1', season: 1, episode: 1);
    final ep2 = _ep(id: 'e2', season: 1, episode: 2);
    final ep3 = _ep(id: 'e3', season: 1, episode: 3);
    final filtered = [ep1, ep2, ep3];

    test('returns -1 when lastId is null', () {
      expect(upNextIndex(filtered, {}, null), -1);
    });

    test('returns -1 when filtered is empty', () {
      expect(upNextIndex([], {}, ep1.streamUrl), -1);
    });

    test('returns -1 when lastId not found in filtered', () {
      expect(upNextIndex(filtered, {}, 'http://x.com/unknown.mkv'), -1);
    });

    test('returns -1 when last episode is the final one', () {
      expect(upNextIndex(filtered, {}, ep3.streamUrl), -1);
    });

    test('returns index after last-watched episode', () {
      expect(upNextIndex(filtered, {}, ep1.streamUrl), 1);
    });

    test('returns correct index for middle episode', () {
      expect(upNextIndex(filtered, {}, ep2.streamUrl), 2);
    });

    test('pMap parameter is accepted but not used in index calculation', () {
      // upNextIndex uses stream URL matching, not progress map
      final pMap = {ep1.streamUrl: 0.95};
      expect(upNextIndex(filtered, pMap, ep1.streamUrl), 1);
    });
  });

  // ── decodeEpisodeProgress ────────────────────────────

  group('decodeEpisodeProgress', () {
    test('decodes progress map and last watched url', () {
      const json =
          '{"progress_map":{"http://x.com/e1.mkv":0.5,'
          '"http://x.com/e2.mkv":1.0},'
          '"last_watched_url":"http://x.com/e2.mkv"}';
      final result = decodeEpisodeProgress(json);
      expect(result.progressMap, {
        'http://x.com/e1.mkv': 0.5,
        'http://x.com/e2.mkv': 1.0,
      });
      expect(result.lastWatchedUrl, 'http://x.com/e2.mkv');
    });

    test('handles null last_watched_url', () {
      const json = '{"progress_map":{},"last_watched_url":null}';
      final result = decodeEpisodeProgress(json);
      expect(result.progressMap, isEmpty);
      expect(result.lastWatchedUrl, isNull);
    });

    test('handles empty progress map', () {
      const json = '{"progress_map":{},"last_watched_url":null}';
      final result = decodeEpisodeProgress(json);
      expect(result.progressMap, isEmpty);
    });

    test('converts integer progress values to double', () {
      const json =
          '{"progress_map":{"http://x.com/e1.mkv":1},'
          '"last_watched_url":null}';
      final result = decodeEpisodeProgress(json);
      expect(result.progressMap['http://x.com/e1.mkv'], isA<double>());
      expect(result.progressMap['http://x.com/e1.mkv'], 1.0);
    });

    test('progressMap contains all entries from JSON', () {
      const json =
          '{"progress_map":{"a":0.1,"b":0.5,"c":0.95},'
          '"last_watched_url":"c"}';
      final result = decodeEpisodeProgress(json);
      expect(result.progressMap.length, 3);
      expect(result.progressMap['a'], closeTo(0.1, 0.001));
      expect(result.progressMap['c'], closeTo(0.95, 0.001));
    });
  });
}
