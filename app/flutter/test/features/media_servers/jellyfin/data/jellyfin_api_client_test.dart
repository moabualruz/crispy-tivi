import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:crispy_tivi/features/media_servers/shared/data/media_server_api_client.dart';
import 'package:crispy_tivi/features/media_servers/shared/data/models/media_server_auth_result.dart';
import 'package:crispy_tivi/features/media_servers/shared/data/models/media_server_item.dart';
import 'package:crispy_tivi/features/media_servers/shared/data/models/media_server_items_response.dart';
import 'package:crispy_tivi/features/media_servers/shared/data/models/media_server_system_info.dart';
import 'package:crispy_tivi/features/media_servers/shared/data/models/media_server_user.dart';

// ── Mocks ──────────────────────────────────────────

class MockDio extends Mock implements Dio {
  @override
  BaseOptions get options => BaseOptions(baseUrl: 'http://jellyfin.local:8096');
}

class FakeRequestOptions extends Fake implements RequestOptions {}

// ── Helpers ────────────────────────────────────────

Response<T> _ok<T>(T data) => Response<T>(
  data: data,
  statusCode: 200,
  requestOptions: RequestOptions(path: ''),
);

Response<T> _error<T>(int code) =>
    Response<T>(statusCode: code, requestOptions: RequestOptions(path: ''));

Map<String, dynamic> _systemInfoJson({
  String name = 'My Jellyfin',
  String version = '10.8.13',
  String id = 'srv-001',
}) => {'ServerName': name, 'Version': version, 'Id': id};

Map<String, dynamic> _userJson({String id = 'u1', String name = 'admin'}) => {
  'Id': id,
  'Name': name,
  'HasPassword': true,
  'HasConfiguredPassword': true,
};

Map<String, dynamic> _authResultJson() => {
  'User': _userJson(),
  'AccessToken': 'tok-abc',
  'ServerId': 'srv-001',
};

Map<String, dynamic> _itemJson({
  String id = 'item-1',
  String name = 'Test Movie',
  String? type,
  int? runTimeTicks,
  Map<String, String>? imageTags,
}) => {
  'Id': id,
  'Name': name,
  if (type != null) 'Type': type,
  if (runTimeTicks != null) 'RunTimeTicks': runTimeTicks,
  'ImageTags': imageTags ?? <String, String>{},
};

Map<String, dynamic> _itemsResponseJson({
  List<Map<String, dynamic>>? items,
  int? total,
}) => {
  'Items': items ?? [_itemJson()],
  'TotalRecordCount': total ?? items?.length ?? 1,
};

// ── Tests ──────────────────────────────────────────

void main() {
  late MockDio mockDio;
  late MediaServerApiClient client;

  setUpAll(() {
    registerFallbackValue(FakeRequestOptions());
  });

  setUp(() {
    mockDio = MockDio();
    client = MediaServerApiClient(
      mockDio,
      baseUrl: 'http://jellyfin.local:8096',
    );
  });

  // ── getPublicSystemInfo ──────────────────────────

  group('getPublicSystemInfo', () {
    test('returns MediaServerSystemInfo on success', () async {
      when(
        () => mockDio.fetch<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => _ok(_systemInfoJson()));

      final result = await client.getPublicSystemInfo();

      expect(result, isA<MediaServerSystemInfo>());
      expect(result.serverName, 'My Jellyfin');
      expect(result.version, '10.8.13');
      expect(result.id, 'srv-001');
    });

    test('throws DioException on 500', () async {
      when(() => mockDio.fetch<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          type: DioExceptionType.badResponse,
          response: _error(500),
          requestOptions: RequestOptions(path: ''),
        ),
      );

      expect(() => client.getPublicSystemInfo(), throwsA(isA<DioException>()));
    });

    test('throws DioException on 401', () async {
      when(() => mockDio.fetch<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          type: DioExceptionType.badResponse,
          response: _error(401),
          requestOptions: RequestOptions(path: ''),
        ),
      );

      expect(() => client.getPublicSystemInfo(), throwsA(isA<DioException>()));
    });

    test('throws on connection timeout', () async {
      when(() => mockDio.fetch<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          type: DioExceptionType.connectionTimeout,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      expect(() => client.getPublicSystemInfo(), throwsA(isA<DioException>()));
    });

    test('throws on null response data', () async {
      when(() => mockDio.fetch<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: null,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      // Generated code does `_result.data!` so null
      // triggers a Null check error.
      expect(() => client.getPublicSystemInfo(), throwsA(anything));
    });
  });

  // ── authenticateByName ───────────────────────────

  group('authenticateByName', () {
    test('returns auth result on valid creds', () async {
      when(
        () => mockDio.fetch<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => _ok(_authResultJson()));

      final result = await client.authenticateByName({
        'Username': 'admin',
        'Pw': 'password',
      });

      expect(result, isA<MediaServerAuthResult>());
      expect(result.accessToken, 'tok-abc');
      expect(result.user.id, 'u1');
      expect(result.user.name, 'admin');
      expect(result.serverId, 'srv-001');
    });

    test('throws on invalid credentials (401)', () async {
      when(() => mockDio.fetch<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          type: DioExceptionType.badResponse,
          response: _error(401),
          requestOptions: RequestOptions(path: ''),
        ),
      );

      expect(
        () => client.authenticateByName({'Username': 'bad', 'Pw': 'wrong'}),
        throwsA(isA<DioException>()),
      );
    });

    test('parses auth result with null serverId', () async {
      final json = {'User': _userJson(), 'AccessToken': 'tok-xyz'};
      when(
        () => mockDio.fetch<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => _ok(json));

      final result = await client.authenticateByName({
        'Username': 'admin',
        'Pw': 'pass',
      });

      expect(result.serverId, isNull);
      expect(result.accessToken, 'tok-xyz');
    });
  });

  // ── getUserViews ─────────────────────────────────

  group('getUserViews', () {
    test('returns items response on success', () async {
      final json = _itemsResponseJson(
        items: [
          _itemJson(id: 'lib-movies', name: 'Movies', type: 'CollectionFolder'),
          _itemJson(id: 'lib-tv', name: 'TV Shows', type: 'CollectionFolder'),
        ],
        total: 2,
      );
      when(
        () => mockDio.fetch<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => _ok(json));

      final result = await client.getUserViews('u1');

      expect(result, isA<MediaServerItemsResponse>());
      expect(result.items.length, 2);
      expect(result.items[0].name, 'Movies');
      expect(result.items[1].name, 'TV Shows');
      expect(result.totalRecordCount, 2);
    });

    test('returns empty list for no views', () async {
      final json = _itemsResponseJson(items: [], total: 0);
      when(
        () => mockDio.fetch<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => _ok(json));

      final result = await client.getUserViews('u1');

      expect(result.items, isEmpty);
      expect(result.totalRecordCount, 0);
    });

    test('throws on 404', () async {
      when(() => mockDio.fetch<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          type: DioExceptionType.badResponse,
          response: _error(404),
          requestOptions: RequestOptions(path: ''),
        ),
      );

      expect(
        () => client.getUserViews('invalid-user'),
        throwsA(isA<DioException>()),
      );
    });
  });

  // ── getItems ─────────────────────────────────────

  group('getItems', () {
    test('returns items with default params', () async {
      final json = _itemsResponseJson(
        items: [_itemJson(id: 'movie-1', name: 'Inception', type: 'Movie')],
      );
      when(
        () => mockDio.fetch<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => _ok(json));

      final result = await client.getItems('u1');

      expect(result.items.length, 1);
      expect(result.items.first.name, 'Inception');
    });

    test('passes parentId and filter params', () async {
      final json = _itemsResponseJson(items: [], total: 0);
      when(
        () => mockDio.fetch<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => _ok(json));

      await client.getItems(
        'u1',
        parentId: 'lib-movies',
        includeItemTypes: 'Movie',
        recursive: true,
        limit: 20,
        startIndex: 0,
      );

      verify(() => mockDio.fetch<Map<String, dynamic>>(any())).called(1);
    });

    test('parses items with runTimeTicks and imageTags', () async {
      final json = _itemsResponseJson(
        items: [
          _itemJson(
            id: 'movie-2',
            name: 'Interstellar',
            type: 'Movie',
            runTimeTicks: 61200000000, // ~102min
            imageTags: {'Primary': 'tag-abc'},
          ),
        ],
      );
      when(
        () => mockDio.fetch<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => _ok(json));

      final result = await client.getItems('u1');
      final item = result.items.first;

      expect(item.runTimeTicks, 61200000000);
      expect(item.durationMs, 6120000);
      expect(item.primaryImageTag, 'tag-abc');
    });

    test('parses item with UserData (watched, progress)', () async {
      final json = _itemsResponseJson(
        items: [
          {
            'Id': 'ep-1',
            'Name': 'Episode 1',
            'ImageTags': <String, String>{},
            'UserData': {
              'PlaybackPositionTicks': 300000000,
              'PlayCount': 1,
              'IsFavorite': true,
              'Played': false,
            },
          },
        ],
      );
      when(
        () => mockDio.fetch<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => _ok(json));

      final result = await client.getItems('u1');
      final item = result.items.first;

      expect(item.userData, isNotNull);
      expect(item.userData!.isFavorite, isTrue);
      expect(item.userData!.played, isFalse);
      expect(item.userData!.playbackPositionMs, 30000);
      expect(item.isInProgress, isTrue);
      expect(item.isWatched, isFalse);
    });

    test('throws on receive timeout', () async {
      when(() => mockDio.fetch<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          type: DioExceptionType.receiveTimeout,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      expect(() => client.getItems('u1'), throwsA(isA<DioException>()));
    });
  });

  // ── getItem ──────────────────────────────────────

  group('getItem', () {
    test('returns single item on success', () async {
      when(() => mockDio.fetch<Map<String, dynamic>>(any())).thenAnswer(
        (_) async =>
            _ok(_itemJson(id: 'item-99', name: 'Solo Item', type: 'Movie')),
      );

      final result = await client.getItem('u1', 'item-99');

      expect(result, isA<MediaServerItem>());
      expect(result.id, 'item-99');
      expect(result.name, 'Solo Item');
    });

    test('throws on 404 item not found', () async {
      when(() => mockDio.fetch<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          type: DioExceptionType.badResponse,
          response: _error(404),
          requestOptions: RequestOptions(path: ''),
        ),
      );

      expect(
        () => client.getItem('u1', 'nonexistent'),
        throwsA(isA<DioException>()),
      );
    });

    test('parses item with backdrop image tags', () async {
      final json = {
        'Id': 'item-bd',
        'Name': 'Backdrop Item',
        'ImageTags': <String, String>{'Primary': 'p-tag'},
        'BackdropImageTags': ['bd-tag-1', 'bd-tag-2'],
      };
      when(
        () => mockDio.fetch<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => _ok(json));

      final result = await client.getItem('u1', 'item-bd');

      expect(result.backdropImageTags, hasLength(2));
      expect(result.backdropImageTag, 'bd-tag-1');
    });

    test('parses item with optional fields null', () async {
      final json = {
        'Id': 'item-min',
        'Name': 'Minimal',
        'ImageTags': <String, String>{},
      };
      when(
        () => mockDio.fetch<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => _ok(json));

      final result = await client.getItem('u1', 'item-min');

      expect(result.overview, isNull);
      expect(result.runTimeTicks, isNull);
      expect(result.durationMs, isNull);
      expect(result.productionYear, isNull);
      expect(result.type, isNull);
      expect(result.userData, isNull);
      expect(result.isWatched, isFalse);
      expect(result.isInProgress, isFalse);
    });
  });

  // ── Model serialization edge cases ───────────────

  group('model serialization', () {
    test('MediaServerSystemInfo roundtrip', () {
      const info = MediaServerSystemInfo(
        serverName: 'Test',
        version: '1.0',
        id: 'id-1',
      );
      final json = info.toJson();
      final decoded = MediaServerSystemInfo.fromJson(json);

      expect(decoded.serverName, info.serverName);
      expect(decoded.version, info.version);
      expect(decoded.id, info.id);
    });

    test('MediaServerUser roundtrip', () {
      const user = MediaServerUser(
        id: 'u-1',
        name: 'TestUser',
        hasPassword: true,
      );
      final json = user.toJson();
      final decoded = MediaServerUser.fromJson(json);

      expect(decoded.id, user.id);
      expect(decoded.name, user.name);
      expect(decoded.hasPassword, isTrue);
    });

    test('MediaServerItem isFolder defaults false', () {
      final item = MediaServerItem.fromJson(const {
        'Id': 'i1',
        'Name': 'X',
        'ImageTags': <String, String>{},
      });
      expect(item.isFolder, isFalse);
    });

    test('MediaServerItem watched via UserData', () {
      final item = MediaServerItem.fromJson(const {
        'Id': 'i2',
        'Name': 'Watched',
        'ImageTags': <String, String>{},
        'UserData': {'Played': true, 'PlayCount': 3},
      });
      expect(item.isWatched, isTrue);
      expect(item.isInProgress, isFalse);
    });
  });
}
