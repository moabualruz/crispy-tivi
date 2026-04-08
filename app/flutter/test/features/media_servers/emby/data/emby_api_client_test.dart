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
  BaseOptions get options => BaseOptions(baseUrl: 'http://emby.local:8096');
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
  String name = 'My Emby',
  String version = '4.7.14',
  String id = 'emby-srv-1',
}) => {'ServerName': name, 'Version': version, 'Id': id};

Map<String, dynamic> _userJson({
  String id = 'eu1',
  String name = 'emby-admin',
}) => {
  'Id': id,
  'Name': name,
  'HasPassword': true,
  'HasConfiguredPassword': true,
};

Map<String, dynamic> _authResultJson() => {
  'User': _userJson(),
  'AccessToken': 'emby-tok-abc',
  'ServerId': 'emby-srv-1',
};

Map<String, dynamic> _itemJson({
  String id = 'eitem-1',
  String name = 'Emby Movie',
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
    client = MediaServerApiClient(mockDio, baseUrl: 'http://emby.local:8096');
  });

  // ── getPublicSystemInfo ──────────────────────────

  group('getPublicSystemInfo', () {
    test('returns MediaServerSystemInfo on success', () async {
      when(
        () => mockDio.fetch<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => _ok(_systemInfoJson()));

      final result = await client.getPublicSystemInfo();

      expect(result, isA<MediaServerSystemInfo>());
      expect(result.serverName, 'My Emby');
      expect(result.version, '4.7.14');
      expect(result.id, 'emby-srv-1');
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
        'Username': 'emby-admin',
        'Pw': 'password',
      });

      expect(result, isA<MediaServerAuthResult>());
      expect(result.accessToken, 'emby-tok-abc');
      expect(result.user.id, 'eu1');
      expect(result.user.name, 'emby-admin');
      expect(result.serverId, 'emby-srv-1');
    });

    test('throws on 401 invalid creds', () async {
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
      final json = {'User': _userJson(), 'AccessToken': 'emby-tok-xyz'};
      when(
        () => mockDio.fetch<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => _ok(json));

      final result = await client.authenticateByName({
        'Username': 'admin',
        'Pw': 'pass',
      });

      expect(result.serverId, isNull);
      expect(result.accessToken, 'emby-tok-xyz');
    });
  });

  // ── getUserViews ─────────────────────────────────

  group('getUserViews', () {
    test('returns items response on success', () async {
      final json = _itemsResponseJson(
        items: [
          _itemJson(id: 'lib-movies', name: 'Movies', type: 'CollectionFolder'),
        ],
        total: 1,
      );
      when(
        () => mockDio.fetch<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => _ok(json));

      final result = await client.getUserViews('eu1');

      expect(result, isA<MediaServerItemsResponse>());
      expect(result.items.length, 1);
      expect(result.items[0].name, 'Movies');
    });

    test('returns empty items list', () async {
      final json = _itemsResponseJson(items: [], total: 0);
      when(
        () => mockDio.fetch<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => _ok(json));

      final result = await client.getUserViews('eu1');
      expect(result.items, isEmpty);
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
        () => client.getUserViews('invalid'),
        throwsA(isA<DioException>()),
      );
    });
  });

  // ── getItems ─────────────────────────────────────

  group('getItems', () {
    test('returns items with default params', () async {
      final json = _itemsResponseJson(
        items: [_itemJson(id: 'em-1', name: 'Dune', type: 'Movie')],
      );
      when(
        () => mockDio.fetch<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => _ok(json));

      final result = await client.getItems('eu1');
      expect(result.items.length, 1);
      expect(result.items.first.name, 'Dune');
    });

    test('parses item with UserData (progress)', () async {
      final json = _itemsResponseJson(
        items: [
          {
            'Id': 'ep-1',
            'Name': 'Episode 1',
            'ImageTags': <String, String>{},
            'UserData': {
              'PlaybackPositionTicks': 500000000,
              'PlayCount': 0,
              'IsFavorite': false,
              'Played': false,
            },
          },
        ],
      );
      when(
        () => mockDio.fetch<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => _ok(json));

      final result = await client.getItems('eu1');
      final item = result.items.first;

      expect(item.userData, isNotNull);
      expect(item.userData!.playbackPositionMs, 50000);
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

      expect(() => client.getItems('eu1'), throwsA(isA<DioException>()));
    });
  });

  // ── getItem ──────────────────────────────────────

  group('getItem', () {
    test('returns single item on success', () async {
      when(() => mockDio.fetch<Map<String, dynamic>>(any())).thenAnswer(
        (_) async =>
            _ok(_itemJson(id: 'eitem-99', name: 'Solo Emby', type: 'Movie')),
      );

      final result = await client.getItem('eu1', 'eitem-99');

      expect(result, isA<MediaServerItem>());
      expect(result.id, 'eitem-99');
      expect(result.name, 'Solo Emby');
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
        () => client.getItem('eu1', 'missing'),
        throwsA(isA<DioException>()),
      );
    });

    test('parses item with all optional null', () async {
      final json = {
        'Id': 'emin',
        'Name': 'Min',
        'ImageTags': <String, String>{},
      };
      when(
        () => mockDio.fetch<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => _ok(json));

      final result = await client.getItem('eu1', 'emin');

      expect(result.overview, isNull);
      expect(result.runTimeTicks, isNull);
      expect(result.durationMs, isNull);
      expect(result.productionYear, isNull);
      expect(result.userData, isNull);
      expect(result.isWatched, isFalse);
    });
  });

  // ── Model serialization edge cases ───────────────

  group('model serialization', () {
    test('MediaServerSystemInfo roundtrip', () {
      const info = MediaServerSystemInfo(
        serverName: 'Emby',
        version: '4.7',
        id: 'e-1',
      );
      final json = info.toJson();
      final decoded = MediaServerSystemInfo.fromJson(json);

      expect(decoded.serverName, info.serverName);
      expect(decoded.version, info.version);
      expect(decoded.id, info.id);
    });

    test('MediaServerUser roundtrip', () {
      const user = MediaServerUser(
        id: 'eu-1',
        name: 'EmbyUser',
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

    test('MediaServerItemsResponse defaults', () {
      const resp = MediaServerItemsResponse();
      expect(resp.items, isEmpty);
      expect(resp.totalRecordCount, 0);
    });
  });
}
