import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:crispy_tivi/core/data/crispy_backend.dart';
import 'package:crispy_tivi/core/domain/entities/'
    'media_item.dart';
import 'package:crispy_tivi/core/domain/entities/'
    'media_type.dart';
import 'package:crispy_tivi/core/domain/media_source.dart';
import 'package:crispy_tivi/features/iptv/domain/'
    'entities/channel.dart';
import 'package:crispy_tivi/features/search/data/'
    'repositories/search_repository_impl.dart';
import 'package:crispy_tivi/features/search/domain/'
    'entities/search_filter.dart';
import 'package:crispy_tivi/features/vod/domain/'
    'entities/vod_item.dart';

// ── Mocks ──────────────────────────────────────────

class MockCrispyBackend extends Mock implements CrispyBackend {}

class MockMediaSource extends Mock implements MediaSource {}

void main() {
  late MockCrispyBackend mockBackend;
  late SearchRepositoryImpl repo;

  setUp(() {
    mockBackend = MockCrispyBackend();
    repo = SearchRepositoryImpl(mockBackend);
  });

  // ── Helpers ──────────────────────────────────────

  const defaultFilter = SearchFilter();

  Channel makeChannel(String id) =>
      Channel(id: id, name: 'Channel $id', streamUrl: 'http://example.com/$id');

  VodItem makeVodItem(String id) => VodItem(
    id: id,
    name: 'Movie $id',
    streamUrl: 'http://example.com/vod/$id',
    type: VodType.movie,
  );

  /// Sets up backend mocks for searchContent +
  /// enrichSearchResults with empty results.
  void stubEmptySearch() {
    when(
      () => mockBackend.searchContent(
        query: any(named: 'query'),
        channelsJson: any(named: 'channelsJson'),
        vodItemsJson: any(named: 'vodItemsJson'),
        epgEntriesJson: any(named: 'epgEntriesJson'),
        filterJson: any(named: 'filterJson'),
      ),
    ).thenAnswer((_) async => '[]');

    when(
      () => mockBackend.enrichSearchResults(any(), any(), any(), any()),
    ).thenAnswer((_) async => '[]');
  }

  /// Sets up backend mocks that return channel
  /// results.
  void stubChannelSearch(List<Channel> channels) {
    when(
      () => mockBackend.searchContent(
        query: any(named: 'query'),
        channelsJson: any(named: 'channelsJson'),
        vodItemsJson: any(named: 'vodItemsJson'),
        epgEntriesJson: any(named: 'epgEntriesJson'),
        filterJson: any(named: 'filterJson'),
      ),
    ).thenAnswer((_) async => '[]');

    final enriched =
        channels
            .map(
              (c) => {
                'id': c.id,
                'name': c.name,
                'media_type': 'channel',
                'metadata': {'logo_url': c.logoUrl, 'stream_url': c.streamUrl},
              },
            )
            .toList();

    when(
      () => mockBackend.enrichSearchResults(any(), any(), any(), any()),
    ).thenAnswer((_) async => jsonEncode(enriched));
  }

  /// Sets up backend mocks that return movie
  /// results.
  void stubMovieSearch(List<VodItem> movies) {
    when(
      () => mockBackend.searchContent(
        query: any(named: 'query'),
        channelsJson: any(named: 'channelsJson'),
        vodItemsJson: any(named: 'vodItemsJson'),
        epgEntriesJson: any(named: 'epgEntriesJson'),
        filterJson: any(named: 'filterJson'),
      ),
    ).thenAnswer((_) async => '[]');

    final enriched =
        movies
            .map(
              (v) => {
                'id': v.id,
                'name': v.name,
                'media_type': 'movie',
                'metadata': {
                  'poster_url': v.posterUrl,
                  'stream_url': v.streamUrl,
                  'year': v.year,
                  'rating': v.rating,
                  'duration': v.duration,
                  'description': v.description,
                  'category': v.category,
                },
              },
            )
            .toList();

    when(
      () => mockBackend.enrichSearchResults(any(), any(), any(), any()),
    ).thenAnswer((_) async => jsonEncode(enriched));
  }

  // ── Empty query ──────────────────────────────────

  group('search - empty query', () {
    test('returns empty GroupedSearchResults for '
        'empty query', () async {
      final result = await repo.search('', filter: defaultFilter, sources: []);

      expect(result.isEmpty, isTrue);
      expect(result.totalCount, 0);
    });

    test('returns empty for whitespace-only query', () async {
      final result = await repo.search(
        '   ',
        filter: defaultFilter,
        sources: [],
      );

      expect(result.isEmpty, isTrue);
    });

    test('does not call backend for empty query', () async {
      await repo.search('', filter: defaultFilter, sources: []);

      verifyNever(
        () => mockBackend.searchContent(
          query: any(named: 'query'),
          channelsJson: any(named: 'channelsJson'),
          vodItemsJson: any(named: 'vodItemsJson'),
          epgEntriesJson: any(named: 'epgEntriesJson'),
          filterJson: any(named: 'filterJson'),
        ),
      );
    });
  });

  // ── No results ───────────────────────────────────

  group('search - no results', () {
    test('returns empty results when backend returns '
        'empty', () async {
      stubEmptySearch();

      final result = await repo.search(
        'nonexistent',
        filter: defaultFilter,
        sources: [],
      );

      expect(result.isEmpty, isTrue);
      expect(result.channels, isEmpty);
      expect(result.movies, isEmpty);
      expect(result.series, isEmpty);
      expect(result.epgPrograms, isEmpty);
    });

    test('calls searchContent with trimmed query', () async {
      stubEmptySearch();

      await repo.search('  hello  ', filter: defaultFilter, sources: []);

      verify(
        () => mockBackend.searchContent(
          query: 'hello',
          channelsJson: any(named: 'channelsJson'),
          vodItemsJson: any(named: 'vodItemsJson'),
          epgEntriesJson: any(named: 'epgEntriesJson'),
          filterJson: any(named: 'filterJson'),
        ),
      ).called(1);
    });

    test('passes empty JSON arrays when no '
        'channels/vod', () async {
      stubEmptySearch();

      await repo.search('test', filter: defaultFilter, sources: []);

      verify(
        () => mockBackend.searchContent(
          query: 'test',
          channelsJson: '[]',
          vodItemsJson: '[]',
          epgEntriesJson: '{}',
          filterJson: any(named: 'filterJson'),
        ),
      ).called(1);
    });
  });

  // ── Channel results ──────────────────────────────

  group('search - channel results', () {
    test('groups channel results correctly', () async {
      final channels = [makeChannel('ch1'), makeChannel('ch2')];
      stubChannelSearch(channels);

      final result = await repo.search(
        'channel',
        filter: defaultFilter,
        sources: [],
        channels: channels,
      );

      expect(result.channels.length, 2);
      expect(result.channels[0].type, MediaType.channel);
      expect(result.channels[0].id, 'ch1');
      expect(result.channels[1].id, 'ch2');
    });

    test('channel results include metadata from '
        'original', () async {
      final ch = Channel(
        id: 'ch1',
        name: 'Sports',
        streamUrl: 'http://example.com/ch1',
        logoUrl: 'http://example.com/logo.png',
      );
      stubChannelSearch([ch]);

      final result = await repo.search(
        'sports',
        filter: defaultFilter,
        sources: [],
        channels: [ch],
      );

      final item = result.channels.first;
      expect(item.name, 'Sports');
      expect(item.type, MediaType.channel);
    });

    test('channel metadata contains source iptv', () async {
      stubChannelSearch([makeChannel('ch1')]);

      final result = await repo.search(
        'test',
        filter: defaultFilter,
        sources: [],
        channels: [makeChannel('ch1')],
      );

      expect(result.channels.first.metadata['source'], 'iptv');
    });
  });

  // ── Movie results ────────────────────────────────

  group('search - movie results', () {
    test('groups movie results correctly', () async {
      final movies = [makeVodItem('m1'), makeVodItem('m2')];
      stubMovieSearch(movies);

      final result = await repo.search(
        'movie',
        filter: defaultFilter,
        sources: [],
        vodItems: movies,
      );

      expect(result.movies.length, 2);
      expect(result.movies[0].type, MediaType.movie);
    });

    test('movie metadata contains source iptv_vod', () async {
      stubMovieSearch([makeVodItem('m1')]);

      final result = await repo.search(
        'test',
        filter: defaultFilter,
        sources: [],
        vodItems: [makeVodItem('m1')],
      );

      expect(result.movies.first.metadata['source'], 'iptv_vod');
    });

    test('enriched movie preserves year as '
        'releaseDate', () async {
      final movie = VodItem(
        id: 'm1',
        name: 'Test',
        streamUrl: 'http://example.com/m1',
        type: VodType.movie,
        year: 2024,
      );
      stubMovieSearch([movie]);

      final result = await repo.search(
        'test',
        filter: defaultFilter,
        sources: [],
        vodItems: [movie],
      );

      expect(result.movies.first.releaseDate?.year, 2024);
    });
  });

  // ── Media server search ──────────────────────────

  group('search - media server sources', () {
    test('includes media server results in output', () async {
      stubEmptySearch();
      final source = MockMediaSource();
      when(() => source.search(any())).thenAnswer(
        (_) async => [
          const MediaItem(
            id: 'jf1',
            name: 'Jellyfin Movie',
            type: MediaType.movie,
            metadata: {},
          ),
        ],
      );

      final result = await repo.search(
        'jellyfin',
        filter: defaultFilter,
        sources: [source],
      );

      expect(result.mediaServerItems.length, 1);
      expect(result.mediaServerItems.first.name, 'Jellyfin Movie');
    });

    test('media server items include mediaSource '
        'in metadata', () async {
      stubEmptySearch();
      final source = MockMediaSource();
      when(() => source.search(any())).thenAnswer(
        (_) async => [
          const MediaItem(
            id: 'jf1',
            name: 'Movie',
            type: MediaType.movie,
            metadata: {},
          ),
        ],
      );

      final result = await repo.search(
        'test',
        filter: defaultFilter,
        sources: [source],
      );

      expect(result.mediaServerItems.first.metadata['mediaSource'], source);
    });

    test('individual source failures are ignored', () async {
      stubEmptySearch();
      final failingSource = MockMediaSource();
      when(
        () => failingSource.search(any()),
      ).thenThrow(Exception('Network error'));

      final goodSource = MockMediaSource();
      when(() => goodSource.search(any())).thenAnswer(
        (_) async => [
          const MediaItem(
            id: 'ok1',
            name: 'Good',
            type: MediaType.movie,
            metadata: {},
          ),
        ],
      );

      final result = await repo.search(
        'test',
        filter: defaultFilter,
        sources: [failingSource, goodSource],
      );

      expect(result.mediaServerItems.length, 1);
      expect(result.mediaServerItems.first.name, 'Good');
    });

    test('all source failures still returns empty '
        'media items', () async {
      stubEmptySearch();
      final source = MockMediaSource();
      when(() => source.search(any())).thenThrow(Exception('Error'));

      final result = await repo.search(
        'test',
        filter: defaultFilter,
        sources: [source],
      );

      expect(result.mediaServerItems, isEmpty);
    });

    test('preserves original item fields in media '
        'server results', () async {
      stubEmptySearch();
      final source = MockMediaSource();
      when(() => source.search(any())).thenAnswer(
        (_) async => [
          const MediaItem(
            id: 'ms1',
            name: 'Full Item',
            type: MediaType.movie,
            logoUrl: 'http://logo.png',
            overview: 'A great movie',
            rating: 'PG-13',
            durationMs: 7200000,
            streamUrl: 'http://stream.url',
            metadata: {'genre': 'action'},
          ),
        ],
      );

      final result = await repo.search(
        'full',
        filter: defaultFilter,
        sources: [source],
      );

      final item = result.mediaServerItems.first;
      expect(item.id, 'ms1');
      expect(item.name, 'Full Item');
      expect(item.logoUrl, 'http://logo.png');
      expect(item.overview, 'A great movie');
      expect(item.rating, 'PG-13');
      expect(item.durationMs, 7200000);
      expect(item.streamUrl, 'http://stream.url');
      expect(item.metadata['genre'], 'action');
    });
  });

  // ── Error handling ───────────────────────────────

  group('search - error handling', () {
    test('throws when searchContent throws', () async {
      when(
        () => mockBackend.searchContent(
          query: any(named: 'query'),
          channelsJson: any(named: 'channelsJson'),
          vodItemsJson: any(named: 'vodItemsJson'),
          epgEntriesJson: any(named: 'epgEntriesJson'),
          filterJson: any(named: 'filterJson'),
        ),
      ).thenThrow(Exception('Backend crash'));

      expect(
        () => repo.search('test', filter: defaultFilter, sources: []),
        throwsA(isA<Exception>()),
      );
    });

    test('throws when enrichSearchResults throws', () async {
      when(
        () => mockBackend.searchContent(
          query: any(named: 'query'),
          channelsJson: any(named: 'channelsJson'),
          vodItemsJson: any(named: 'vodItemsJson'),
          epgEntriesJson: any(named: 'epgEntriesJson'),
          filterJson: any(named: 'filterJson'),
        ),
      ).thenAnswer((_) async => '[]');

      when(
        () => mockBackend.enrichSearchResults(any(), any(), any(), any()),
      ).thenThrow(Exception('Enrich failed'));

      expect(
        () => repo.search('test', filter: defaultFilter, sources: []),
        throwsA(isA<Exception>()),
      );
    });

    test('throws on malformed enriched JSON', () async {
      when(
        () => mockBackend.searchContent(
          query: any(named: 'query'),
          channelsJson: any(named: 'channelsJson'),
          vodItemsJson: any(named: 'vodItemsJson'),
          epgEntriesJson: any(named: 'epgEntriesJson'),
          filterJson: any(named: 'filterJson'),
        ),
      ).thenAnswer((_) async => '[]');

      when(
        () => mockBackend.enrichSearchResults(any(), any(), any(), any()),
      ).thenAnswer((_) async => 'not valid json');

      expect(
        () => repo.search('test', filter: defaultFilter, sources: []),
        throwsA(isA<FormatException>()),
      );
    });
  });

  // ── Filter encoding ──────────────────────────────

  group('search - filter encoding', () {
    test('encodes filter with all types enabled by '
        'default', () async {
      stubEmptySearch();

      await repo.search('test', filter: const SearchFilter(), sources: []);

      final captured =
          verify(
                () => mockBackend.searchContent(
                  query: any(named: 'query'),
                  channelsJson: any(named: 'channelsJson'),
                  vodItemsJson: any(named: 'vodItemsJson'),
                  epgEntriesJson: any(named: 'epgEntriesJson'),
                  filterJson: captureAny(named: 'filterJson'),
                ),
              ).captured.single
              as String;

      final decoded = jsonDecode(captured) as Map<String, dynamic>;
      expect(decoded['search_channels'], isTrue);
      expect(decoded['search_movies'], isTrue);
      expect(decoded['search_series'], isTrue);
      expect(decoded['search_epg'], isTrue);
      expect(decoded['search_in_description'], isFalse);
    });

    test('encodes filter with specific types '
        'disabled', () async {
      stubEmptySearch();
      const filter = SearchFilter(contentTypes: {SearchContentType.channels});

      await repo.search('test', filter: filter, sources: []);

      final captured =
          verify(
                () => mockBackend.searchContent(
                  query: any(named: 'query'),
                  channelsJson: any(named: 'channelsJson'),
                  vodItemsJson: any(named: 'vodItemsJson'),
                  epgEntriesJson: any(named: 'epgEntriesJson'),
                  filterJson: captureAny(named: 'filterJson'),
                ),
              ).captured.single
              as String;

      final decoded = jsonDecode(captured) as Map<String, dynamic>;
      expect(decoded['search_channels'], isTrue);
      expect(decoded['search_movies'], isFalse);
      expect(decoded['search_series'], isFalse);
      expect(decoded['search_epg'], isFalse);
    });

    test('encodes category and year range in filter', () async {
      stubEmptySearch();
      const filter = SearchFilter(
        category: 'Sports',
        yearMin: 2020,
        yearMax: 2025,
        searchInDescription: true,
      );

      await repo.search('test', filter: filter, sources: []);

      final captured =
          verify(
                () => mockBackend.searchContent(
                  query: any(named: 'query'),
                  channelsJson: any(named: 'channelsJson'),
                  vodItemsJson: any(named: 'vodItemsJson'),
                  epgEntriesJson: any(named: 'epgEntriesJson'),
                  filterJson: captureAny(named: 'filterJson'),
                ),
              ).captured.single
              as String;

      final decoded = jsonDecode(captured) as Map<String, dynamic>;
      expect(decoded['category'], 'Sports');
      expect(decoded['year_min'], 2020);
      expect(decoded['year_max'], 2025);
      expect(decoded['search_in_description'], isTrue);
    });
  });
}
