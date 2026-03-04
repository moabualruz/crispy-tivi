import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:crispy_tivi/core/failures/failure.dart';
import 'package:crispy_tivi/features/media_servers/'
    'plex/data/datasources/plex_api_client.dart';
import 'package:crispy_tivi/features/media_servers/'
    'plex/data/models/plex_metadata.dart';
import 'package:crispy_tivi/features/media_servers/'
    'plex/domain/entities/plex_server.dart';

// ── Mocks ──────────────────────────────────────────

class MockDio extends Mock implements Dio {}

class FakeOptions extends Fake implements Options {}

// ── Helpers ────────────────────────────────────────

const _server = PlexServer(
  url: 'http://plex.local:32400',
  name: 'Test Plex',
  accessToken: 'plex-token-123',
  clientIdentifier: 'crispy-client-id',
);

/// Build a mock OK response with properly typed
/// nested maps (JSON roundtrip ensures
/// `Map<String, dynamic>` at every level).
Response<dynamic> _ok(Map<String, dynamic> data) => Response<dynamic>(
  data: jsonDecode(jsonEncode(data)) as Map<String, dynamic>,
  statusCode: 200,
  requestOptions: RequestOptions(path: ''),
);

DioException _dioError(int statusCode, {String? message}) => DioException(
  type: DioExceptionType.badResponse,
  response: Response<dynamic>(
    statusCode: statusCode,
    requestOptions: RequestOptions(path: ''),
  ),
  message: message,
  requestOptions: RequestOptions(path: ''),
);

DioException _timeoutError() => DioException(
  type: DioExceptionType.connectionTimeout,
  requestOptions: RequestOptions(path: ''),
  message: 'Connection timed out',
);

/// Use [omitFriendlyName] to exclude friendlyName
/// from the response entirely.
Map<String, dynamic> _identityResponse({
  String? machineId,
  String friendlyName = 'Living Room Plex',
  bool omitFriendlyName = false,
}) => {
  'MediaContainer': {
    'MachineIdentifier': machineId ?? 'plex-machine-1',
    if (!omitFriendlyName) 'friendlyName': friendlyName,
  },
};

Map<String, dynamic> _librariesResponse() => {
  'MediaContainer': {
    'Directory': [
      {'key': '1', 'type': 'movie', 'title': 'Movies'},
      {'key': '2', 'type': 'show', 'title': 'TV Shows'},
    ],
  },
};

Map<String, dynamic> _itemsResponse({
  List<Map<String, dynamic>>? metadata,
  int? size,
  int? totalSize,
  int? offset,
}) => {
  'MediaContainer': {
    if (size != null) 'size': size,
    if (totalSize != null) 'totalSize': totalSize,
    if (offset != null) 'offset': offset,
    'Metadata':
        metadata ??
        [
          {
            'ratingKey': '101',
            'title': 'Inception',
            'type': 'movie',
            'year': 2010,
            'duration': 8880000,
          },
        ],
  },
};

Map<String, dynamic> _playbackResponse({String? partKey}) => {
  'MediaContainer': {
    'Metadata': [
      {
        'ratingKey': '101',
        'title': 'Inception',
        'Media': [
          {
            'Part': [
              {'key': partKey ?? '/library/parts/35/file.mkv'},
            ],
          },
        ],
      },
    ],
  },
};

Map<String, dynamic> _searchResponse({List<Map<String, dynamic>>? hubs}) => {
  'MediaContainer': {
    'Hub':
        hubs ??
        [
          {
            'type': 'movie',
            'title': 'Movies',
            'Metadata': [
              {'ratingKey': '201', 'title': 'Found Movie', 'type': 'movie'},
            ],
          },
        ],
  },
};

// ── Tests ──────────────────────────────────────────

void main() {
  late MockDio mockDio;
  late PlexApiClient client;

  setUpAll(() {
    registerFallbackValue(FakeOptions());
  });

  setUp(() {
    mockDio = MockDio();
    client = PlexApiClient(dio: mockDio);
  });

  // ── validateServer ───────────────────────────────

  group('validateServer', () {
    test('returns PlexServer on success', () async {
      when(
        () => mockDio.get(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => _ok(_identityResponse()));

      final result = await client.validateServer(
        url: 'http://plex.local:32400',
        token: 'tok',
        clientIdentifier: 'cid',
      );

      expect(result, isA<PlexServer>());
      expect(result.name, 'Living Room Plex');
      expect(result.url, 'http://plex.local:32400');
      expect(result.accessToken, 'tok');
      expect(result.clientIdentifier, 'cid');
    });

    test('strips trailing slash from URL', () async {
      when(
        () => mockDio.get(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => _ok(_identityResponse()));

      final result = await client.validateServer(
        url: 'http://plex.local:32400/',
        token: 'tok',
        clientIdentifier: 'cid',
      );

      expect(result.url, 'http://plex.local:32400');
    });

    test('uses default name if friendlyName null', () async {
      when(
        () => mockDio.get(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => _ok(_identityResponse(omitFriendlyName: true)));

      final result = await client.validateServer(
        url: 'http://plex.local:32400',
        token: 'tok',
        clientIdentifier: 'cid',
      );

      expect(result.name, 'Plex Server');
    });

    test('throws AuthFailure on 401', () async {
      when(
        () => mockDio.get(any(), options: any(named: 'options')),
      ).thenThrow(_dioError(401));

      expect(
        () => client.validateServer(
          url: 'http://plex.local:32400',
          token: 'bad-token',
          clientIdentifier: 'cid',
        ),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('throws ServerFailure on 500', () async {
      when(
        () => mockDio.get(any(), options: any(named: 'options')),
      ).thenThrow(_dioError(500, message: 'Internal Server Error'));

      expect(
        () => client.validateServer(
          url: 'http://plex.local:32400',
          token: 'tok',
          clientIdentifier: 'cid',
        ),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('throws ServerFailure on connection timeout', () async {
      when(
        () => mockDio.get(any(), options: any(named: 'options')),
      ).thenThrow(_timeoutError());

      expect(
        () => client.validateServer(
          url: 'http://plex.local:32400',
          token: 'tok',
          clientIdentifier: 'cid',
        ),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('throws ServerFailure on malformed response', () async {
      when(
        () => mockDio.get(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => _ok({'unexpected': 'data'}));

      expect(
        () => client.validateServer(
          url: 'http://plex.local:32400',
          token: 'tok',
          clientIdentifier: 'cid',
        ),
        throwsA(isA<ServerFailure>()),
      );
    });
  });

  // ── getLibraries ─────────────────────────────────

  group('getLibraries', () {
    test('returns list of directories on success', () async {
      when(
        () => mockDio.get(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => _ok(_librariesResponse()));

      final result = await client.getLibraries(_server);

      expect(result, hasLength(2));
      expect(result[0].title, 'Movies');
      expect(result[0].key, '1');
      expect(result[1].title, 'TV Shows');
      expect(result[1].type, 'show');
    });

    test('returns empty list when no directories', () async {
      when(
        () => mockDio.get(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => _ok({'MediaContainer': {}}));

      final result = await client.getLibraries(_server);
      expect(result, isEmpty);
    });

    test('throws ServerFailure on DioException', () async {
      when(
        () => mockDio.get(any(), options: any(named: 'options')),
      ).thenThrow(_dioError(500, message: 'Server error'));

      expect(() => client.getLibraries(_server), throwsA(isA<ServerFailure>()));
    });
  });

  // ── getItems ─────────────────────────────────────

  group('getItems', () {
    test('returns list of metadata on success', () async {
      when(
        () => mockDio.get(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => _ok(_itemsResponse()));

      final result = await client.getItems(_server, libraryId: '1');

      expect(result, hasLength(1));
      expect(result.first.title, 'Inception');
      expect(result.first.year, 2010);
      expect(result.first.ratingKey, '101');
    });

    test('returns empty list when no metadata', () async {
      when(
        () => mockDio.get(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => _ok({'MediaContainer': {}}));

      final result = await client.getItems(_server, libraryId: '1');
      expect(result, isEmpty);
    });

    test('throws ServerFailure on error', () async {
      when(
        () => mockDio.get(any(), options: any(named: 'options')),
      ).thenThrow(_dioError(403));

      expect(
        () => client.getItems(_server, libraryId: '1'),
        throwsA(isA<ServerFailure>()),
      );
    });
  });

  // ── getItemsPaginated ────────────────────────────

  group('getItemsPaginated', () {
    test('returns paginated result', () async {
      when(
        () => mockDio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => _ok(_itemsResponse(size: 2, totalSize: 50, offset: 0)),
      );

      final result = await client.getItemsPaginated(
        _server,
        libraryId: '1',
        start: 0,
        size: 2,
      );

      expect(result.items, hasLength(1));
      expect(result.totalSize, 50);
      expect(result.offset, 0);
      expect(result.size, 2);
      expect(result.hasMore, isTrue);
    });

    test('hasMore is false when at end', () async {
      when(
        () => mockDio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => _ok(_itemsResponse(size: 5, totalSize: 5, offset: 0)),
      );

      final result = await client.getItemsPaginated(_server, libraryId: '1');

      expect(result.hasMore, isFalse);
    });

    test('throws ServerFailure on error', () async {
      when(
        () => mockDio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenThrow(_dioError(500));

      expect(
        () => client.getItemsPaginated(_server, libraryId: '1'),
        throwsA(isA<ServerFailure>()),
      );
    });
  });

  // ── getChildren ──────────────────────────────────

  group('getChildren', () {
    test('returns list of child metadata', () async {
      final childrenResponse = {
        'MediaContainer': {
          'Metadata': [
            {
              'ratingKey': '201',
              'title': 'Season 1',
              'type': 'season',
              'index': 1,
            },
            {
              'ratingKey': '202',
              'title': 'Season 2',
              'type': 'season',
              'index': 2,
            },
          ],
        },
      };
      when(
        () => mockDio.get(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => _ok(childrenResponse));

      final result = await client.getChildren(_server, itemId: '100');

      expect(result, hasLength(2));
      expect(result[0].title, 'Season 1');
      expect(result[1].title, 'Season 2');
    });

    test('returns empty list when no children', () async {
      when(
        () => mockDio.get(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => _ok({'MediaContainer': {}}));

      final result = await client.getChildren(_server, itemId: '100');
      expect(result, isEmpty);
    });

    test('throws ServerFailure on error', () async {
      when(
        () => mockDio.get(any(), options: any(named: 'options')),
      ).thenThrow(_dioError(404));

      expect(
        () => client.getChildren(_server, itemId: '999'),
        throwsA(isA<ServerFailure>()),
      );
    });
  });

  // ── getChildrenPaginated ─────────────────────────

  group('getChildrenPaginated', () {
    test('returns paginated children', () async {
      final resp = {
        'MediaContainer': {
          'size': 3,
          'totalSize': 10,
          'offset': 0,
          'Metadata': [
            {'ratingKey': '301', 'title': 'Ep 1', 'type': 'episode'},
            {'ratingKey': '302', 'title': 'Ep 2', 'type': 'episode'},
            {'ratingKey': '303', 'title': 'Ep 3', 'type': 'episode'},
          ],
        },
      };
      when(
        () => mockDio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => _ok(resp));

      final result = await client.getChildrenPaginated(
        _server,
        itemId: '200',
        start: 0,
        size: 3,
      );

      expect(result.items, hasLength(3));
      expect(result.totalSize, 10);
      expect(result.hasMore, isTrue);
    });

    test('throws ServerFailure on error', () async {
      when(
        () => mockDio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenThrow(_dioError(500));

      expect(
        () => client.getChildrenPaginated(_server, itemId: '200'),
        throwsA(isA<ServerFailure>()),
      );
    });
  });

  // ── getPlaybackUrl ───────────────────────────────

  group('getPlaybackUrl', () {
    test('returns constructed playback URL', () async {
      when(
        () => mockDio.get(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => _ok(_playbackResponse()));

      final url = await client.getPlaybackUrl(_server, '101');

      expect(
        url,
        'http://plex.local:32400'
        '/library/parts/35/file.mkv'
        '?X-Plex-Token=plex-token-123',
      );
    });

    test('throws ServerFailure when no metadata', () async {
      when(() => mockDio.get(any(), options: any(named: 'options'))).thenAnswer(
        (_) async => _ok({
          'MediaContainer': {'Metadata': []},
        }),
      );

      expect(
        () => client.getPlaybackUrl(_server, '101'),
        throwsA(
          isA<ServerFailure>().having(
            (f) => f.message,
            'message',
            contains('Item not found'),
          ),
        ),
      );
    });

    test('throws ServerFailure when no media', () async {
      when(() => mockDio.get(any(), options: any(named: 'options'))).thenAnswer(
        (_) async => _ok({
          'MediaContainer': {
            'Metadata': [
              {'ratingKey': '101', 'title': 'NoMedia'},
            ],
          },
        }),
      );

      expect(
        () => client.getPlaybackUrl(_server, '101'),
        throwsA(
          isA<ServerFailure>().having(
            (f) => f.message,
            'message',
            contains('No media found'),
          ),
        ),
      );
    });

    test('throws ServerFailure when no parts', () async {
      when(() => mockDio.get(any(), options: any(named: 'options'))).thenAnswer(
        (_) async => _ok({
          'MediaContainer': {
            'Metadata': [
              {
                'ratingKey': '101',
                'title': 'NoParts',
                'Media': [
                  {'Part': []},
                ],
              },
            ],
          },
        }),
      );

      expect(
        () => client.getPlaybackUrl(_server, '101'),
        throwsA(
          isA<ServerFailure>().having(
            (f) => f.message,
            'message',
            contains('No media parts'),
          ),
        ),
      );
    });

    test('throws ServerFailure when part key null', () async {
      when(() => mockDio.get(any(), options: any(named: 'options'))).thenAnswer(
        (_) async => _ok({
          'MediaContainer': {
            'Metadata': [
              {
                'ratingKey': '101',
                'title': 'NullKey',
                'Media': [
                  {
                    'Part': [{}],
                  },
                ],
              },
            ],
          },
        }),
      );

      expect(
        () => client.getPlaybackUrl(_server, '101'),
        throwsA(
          isA<ServerFailure>().having(
            (f) => f.message,
            'message',
            contains('Invalid media part key'),
          ),
        ),
      );
    });

    test('throws ServerFailure on DioException', () async {
      when(
        () => mockDio.get(any(), options: any(named: 'options')),
      ).thenThrow(_dioError(500));

      expect(
        () => client.getPlaybackUrl(_server, '101'),
        throwsA(isA<ServerFailure>()),
      );
    });
  });

  // ── search ───────────────────────────────────────

  group('search', () {
    test('returns metadata from hubs', () async {
      when(
        () => mockDio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => _ok(_searchResponse()));

      final result = await client.search(_server, query: 'Found');

      expect(result, hasLength(1));
      expect(result.first.title, 'Found Movie');
    });

    test('returns empty list when no hubs', () async {
      when(
        () => mockDio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => _ok({'MediaContainer': {}}));

      final result = await client.search(_server, query: 'nothing');
      expect(result, isEmpty);
    });

    test('aggregates results from multiple hubs', () async {
      final multiHub = _searchResponse(
        hubs: [
          {
            'type': 'movie',
            'Metadata': [
              {'ratingKey': '301', 'title': 'Movie A', 'type': 'movie'},
            ],
          },
          {
            'type': 'show',
            'Metadata': [
              {'ratingKey': '302', 'title': 'Show B', 'type': 'show'},
              {'ratingKey': '303', 'title': 'Show C', 'type': 'show'},
            ],
          },
        ],
      );
      when(
        () => mockDio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => _ok(multiHub));

      final result = await client.search(_server, query: 'test');

      expect(result, hasLength(3));
    });

    test('skips hubs with null metadata', () async {
      final hubNoMeta = _searchResponse(
        hubs: [
          {
            'type': 'artist',
            // No Metadata key
          },
          {
            'type': 'movie',
            'Metadata': [
              {'ratingKey': '401', 'title': 'Valid', 'type': 'movie'},
            ],
          },
        ],
      );
      when(
        () => mockDio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => _ok(hubNoMeta));

      final result = await client.search(_server, query: 'test');

      expect(result, hasLength(1));
      expect(result.first.title, 'Valid');
    });

    test('throws ServerFailure on error', () async {
      when(
        () => mockDio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenThrow(_dioError(500));

      expect(
        () => client.search(_server, query: 'fail'),
        throwsA(isA<ServerFailure>()),
      );
    });
  });

  // ── PlexPaginatedResult ──────────────────────────

  group('PlexPaginatedResult', () {
    test('hasMore true when more items exist', () {
      const result = PlexPaginatedResult(
        items: [],
        totalSize: 100,
        offset: 0,
        size: 50,
      );
      expect(result.hasMore, isTrue);
    });

    test('hasMore false when at end', () {
      const result = PlexPaginatedResult(
        items: [],
        totalSize: 50,
        offset: 0,
        size: 50,
      );
      expect(result.hasMore, isFalse);
    });

    test('hasMore false when past end', () {
      const result = PlexPaginatedResult(
        items: [],
        totalSize: 10,
        offset: 10,
        size: 5,
      );
      expect(result.hasMore, isFalse);
    });
  });

  // ── PlexMetadata computed properties ─────────────

  group('PlexMetadata properties', () {
    test('isWatched true when viewCount > 0', () {
      final json = {'ratingKey': '1', 'title': 'Watched', 'viewCount': 2};
      final m = _parseMetadata(json);
      expect(m.isWatched, isTrue);
    });

    test('isWatched false when viewCount null', () {
      final json = {'ratingKey': '1', 'title': 'Unwatched'};
      final m = _parseMetadata(json);
      expect(m.isWatched, isFalse);
    });

    test('isInProgress true with offset, not watched', () {
      final json = {
        'ratingKey': '1',
        'title': 'In Progress',
        'viewOffset': 60000,
      };
      final m = _parseMetadata(json);
      expect(m.isInProgress, isTrue);
      expect(m.playbackPositionMs, 60000);
    });

    test('isInProgress false when watched despite offset', () {
      final json = {
        'ratingKey': '1',
        'title': 'Done',
        'viewOffset': 60000,
        'viewCount': 1,
      };
      final m = _parseMetadata(json);
      expect(m.isInProgress, isFalse);
      expect(m.isWatched, isTrue);
    });
  });
}

PlexMetadata _parseMetadata(Map<String, dynamic> json) =>
    PlexMetadata.fromJson(json);
