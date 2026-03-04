import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/vod/data/vod_parser.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';

/// Test backend that returns pre-canned maps from
/// parser methods, simulating Rust output.
class _VodTestBackend extends MemoryBackend {
  List<Map<String, dynamic>>? vodStreamsResult;
  List<Map<String, dynamic>>? seriesResult;
  List<Map<String, dynamic>>? episodesResult;
  List<Map<String, dynamic>>? m3uVodResult;

  @override
  Future<List<Map<String, dynamic>>> parseVodStreams(
    String json, {
    required String baseUrl,
    required String username,
    required String password,
    String? sourceId,
  }) async => vodStreamsResult ?? [];

  @override
  Future<List<Map<String, dynamic>>> parseSeries(
    String json, {
    String? sourceId,
  }) async => seriesResult ?? [];

  @override
  Future<List<Map<String, dynamic>>> parseEpisodes(
    String json, {
    required String baseUrl,
    required String username,
    required String password,
    required String seriesId,
  }) async => episodesResult ?? [];

  @override
  Future<List<Map<String, dynamic>>> parseM3uVod(
    String json, {
    String? sourceId,
  }) async => m3uVodResult ?? [];
}

void main() {
  late _VodTestBackend backend;

  setUp(() {
    backend = _VodTestBackend();
  });

  group('VodParser.parseVodStreams', () {
    test('converts backend maps to VodItems', () async {
      backend.vodStreamsResult = [
        {
          'id': 'vod_101',
          'name': 'The Matrix',
          'type': 'movie',
          'stream_url':
              'http://x.com/movie/u/p/'
              '101.mkv',
          'poster_url': 'http://img.com/matrix.jpg',
          'year': 1999,
          'ext': 'mkv',
          'rating': '8.7',
        },
        {
          'id': 'vod_102',
          'name': 'Inception',
          'type': 'movie',
          'stream_url':
              'http://x.com/movie/u/p/'
              '102.mp4',
          'ext': 'mp4',
        },
      ];

      final result = await VodParser.parseVodStreams(
        [
          {'stream_id': 101},
          {'stream_id': 102},
        ],
        backend,
        baseUrl: 'http://x.com',
        username: 'u',
        password: 'p',
      );

      expect(result.length, 2);
      expect(result[0].id, 'vod_101');
      expect(result[0].name, 'The Matrix');
      expect(result[0].type, VodType.movie);
      expect(result[0].year, 1999);
      expect(result[0].extension, 'mkv');
      expect(result[1].name, 'Inception');
    });

    test('returns empty for empty backend result', () async {
      final result = await VodParser.parseVodStreams(
        [],
        backend,
        baseUrl: 'http://x.com',
        username: 'u',
        password: 'p',
      );
      expect(result, isEmpty);
    });
  });

  group('VodParser.parseSeries', () {
    test('converts backend maps to series VodItems', () async {
      backend.seriesResult = [
        {
          'id': 'series_50',
          'name': 'Breaking Bad',
          'type': 'series',
          'stream_url': '',
          'poster_url': 'http://img.com/bb.jpg',
          'year': 2008,
          'description':
              'A chemistry teacher turns '
              'to crime.',
        },
      ];

      final result = await VodParser.parseSeries([
        {'series_id': 50, 'name': 'Breaking Bad'},
      ], backend);

      expect(result.length, 1);
      expect(result[0].id, 'series_50');
      expect(result[0].name, 'Breaking Bad');
      expect(result[0].type, VodType.series);
      expect(result[0].streamUrl, '');
      expect(result[0].year, 2008);
    });
  });

  group('VodParser.parseEpisodes', () {
    test('converts backend maps to episode VodItems', () async {
      backend.episodesResult = [
        {
          'id': 'ep_50_1001',
          'name': 'Pilot',
          'type': 'episode',
          'stream_url':
              'http://x.com/series/u/p/'
              '1001.mkv',
          'season_number': 1,
          'episode_number': 1,
          'duration': 60,
        },
      ];

      final result = await VodParser.parseEpisodes(
        {'episodes': {}},
        backend,
        baseUrl: 'http://x.com',
        username: 'u',
        password: 'p',
        seriesId: '50',
      );

      expect(result.length, 1);
      expect(result[0].id, 'ep_50_1001');
      expect(result[0].name, 'Pilot');
      expect(result[0].type, VodType.episode);
      expect(result[0].seasonNumber, 1);
      expect(result[0].episodeNumber, 1);
      expect(result[0].duration, 60);
    });

    test('returns empty for empty backend result', () async {
      final result = await VodParser.parseEpisodes(
        {'episodes': {}},
        backend,
        baseUrl: 'http://x.com',
        username: 'u',
        password: 'p',
        seriesId: '1',
      );
      expect(result, isEmpty);
    });
  });

  group('VodParser.parseM3uVod', () {
    test('converts backend maps to VodItems', () async {
      backend.m3uVodResult = [
        {
          'id': 'm3u_vod_1',
          'name': 'Movie A',
          'type': 'movie',
          'stream_url': 'http://host.com/movie.mp4',
          'poster_url': 'http://img.com/a.jpg',
        },
      ];

      final result = await VodParser.parseM3uVod([
        {'name': 'Movie A', 'streamUrl': 'http://host.com/movie.mp4'},
      ], backend);

      expect(result.length, 1);
      expect(result[0].name, 'Movie A');
      expect(result[0].type, VodType.movie);
    });

    test('returns empty for non-VOD M3U entries', () async {
      final result = await VodParser.parseM3uVod([
        {'name': 'CNN', 'streamUrl': 'http://host.com/cnn.m3u8'},
      ], backend);
      expect(result, isEmpty);
    });
  });
}
