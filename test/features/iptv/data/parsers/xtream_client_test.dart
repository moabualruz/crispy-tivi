import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:crispy_tivi/core/data/crispy_backend.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/iptv/data/parsers/xtream_client.dart';

class MockCrispyBackend extends Mock implements CrispyBackend {}

void main() {
  late MockCrispyBackend mockBackend;

  setUp(() {
    mockBackend = MockCrispyBackend();
  });

  XtreamClient createClient({
    String baseUrl = 'http://example.com:8080',
    String username = 'user',
    String password = 'pass',
  }) {
    final mb = MemoryBackend();
    when(() => mockBackend.normalizeApiBaseUrl(any())).thenAnswer(
      (inv) => mb.normalizeApiBaseUrl(inv.positionalArguments[0] as String),
    );
    return XtreamClient(
      baseUrl: baseUrl,
      username: username,
      password: password,
      backend: mockBackend,
    );
  }

  group('XtreamClient', () {
    group('URL normalization', () {
      test('strips trailing path from base URL', () {
        final client = createClient(
          baseUrl: 'http://example.com:8080/some/path',
        );
        expect(client.baseUrl, 'http://example.com:8080');
      });

      test('strips trailing slash', () {
        final client = createClient(baseUrl: 'http://example.com:8080/');
        expect(client.baseUrl, 'http://example.com:8080');
      });

      test('throws on empty baseUrl', () {
        expect(() => createClient(baseUrl: ''), throwsA(isA<ArgumentError>()));
      });

      test('normalizes bare hostname with http', () {
        final client = createClient(baseUrl: 'not-a-url');
        expect(client.baseUrl, 'http://not-a-url');
      });
    });

    group('API URL building', () {
      test('delegates buildActionUrl to backend', () {
        when(
          () => mockBackend.buildXtreamActionUrl(
            baseUrl: any(named: 'baseUrl'),
            username: any(named: 'username'),
            password: any(named: 'password'),
            action: any(named: 'action'),
            paramsJson: any(named: 'paramsJson'),
          ),
        ).thenReturn(
          'http://example.com:8080/player_api.php'
          '?username=testuser'
          '&password=testpass'
          '&action=get_live_categories',
        );

        final client = createClient(username: 'testuser', password: 'testpass');
        final url = client.buildActionUrl('get_live_categories');

        expect(url, contains('/player_api.php'));
        expect(url, contains('username=testuser'));
        expect(url, contains('password=testpass'));
        expect(url, contains('action=get_live_categories'));

        verify(
          () => mockBackend.buildXtreamActionUrl(
            baseUrl: 'http://example.com:8080',
            username: 'testuser',
            password: 'testpass',
            action: 'get_live_categories',
            paramsJson: null,
          ),
        ).called(1);
      });

      test('passes extra params as JSON', () {
        when(
          () => mockBackend.buildXtreamActionUrl(
            baseUrl: any(named: 'baseUrl'),
            username: any(named: 'username'),
            password: any(named: 'password'),
            action: any(named: 'action'),
            paramsJson: any(named: 'paramsJson'),
          ),
        ).thenReturn(
          'http://example.com:8080/player_api.php'
          '?username=user&password=pass'
          '&action=get_vod_info&vod_id=123',
        );

        final client = createClient();
        final url = client.buildActionUrl(
          'get_vod_info',
          params: {'vod_id': '123'},
        );

        expect(url, contains('vod_id=123'));

        verify(
          () => mockBackend.buildXtreamActionUrl(
            baseUrl: 'http://example.com:8080',
            username: 'user',
            password: 'pass',
            action: 'get_vod_info',
            paramsJson: jsonEncode({'vod_id': '123'}),
          ),
        ).called(1);
      });
    });

    group('stream URL building', () {
      test('delegates liveStreamUrl to backend', () {
        when(
          () => mockBackend.buildXtreamStreamUrl(
            baseUrl: any(named: 'baseUrl'),
            username: any(named: 'username'),
            password: any(named: 'password'),
            streamId: any(named: 'streamId'),
            streamType: any(named: 'streamType'),
            extension: any(named: 'extension'),
          ),
        ).thenReturn(
          'http://example.com:8080'
          '/live/user/pass/42.ts',
        );

        final client = createClient();
        final url = client.liveStreamUrl(42);

        expect(
          url,
          'http://example.com:8080'
          '/live/user/pass/42.ts',
        );

        verify(
          () => mockBackend.buildXtreamStreamUrl(
            baseUrl: 'http://example.com:8080',
            username: 'user',
            password: 'pass',
            streamId: 42,
            streamType: 'live',
            extension: 'ts',
          ),
        ).called(1);
      });

      test('delegates vodStreamUrl to backend', () {
        when(
          () => mockBackend.buildXtreamStreamUrl(
            baseUrl: any(named: 'baseUrl'),
            username: any(named: 'username'),
            password: any(named: 'password'),
            streamId: any(named: 'streamId'),
            streamType: any(named: 'streamType'),
            extension: any(named: 'extension'),
          ),
        ).thenReturn(
          'http://example.com:8080'
          '/movie/user/pass/99.mp4',
        );

        final client = createClient();
        final url = client.vodStreamUrl(99, extension: 'mp4');

        expect(
          url,
          'http://example.com:8080'
          '/movie/user/pass/99.mp4',
        );

        verify(
          () => mockBackend.buildXtreamStreamUrl(
            baseUrl: 'http://example.com:8080',
            username: 'user',
            password: 'pass',
            streamId: 99,
            streamType: 'movie',
            extension: 'mp4',
          ),
        ).called(1);
      });

      test('delegates seriesStreamUrl to backend', () {
        when(
          () => mockBackend.buildXtreamStreamUrl(
            baseUrl: any(named: 'baseUrl'),
            username: any(named: 'username'),
            password: any(named: 'password'),
            streamId: any(named: 'streamId'),
            streamType: any(named: 'streamType'),
            extension: any(named: 'extension'),
          ),
        ).thenReturn(
          'http://example.com:8080'
          '/series/user/pass/55.mkv',
        );

        final client = createClient();
        final url = client.seriesStreamUrl(55, extension: 'mkv');

        expect(
          url,
          'http://example.com:8080'
          '/series/user/pass/55.mkv',
        );

        verify(
          () => mockBackend.buildXtreamStreamUrl(
            baseUrl: 'http://example.com:8080',
            username: 'user',
            password: 'pass',
            streamId: 55,
            streamType: 'series',
            extension: 'mkv',
          ),
        ).called(1);
      });

      test('delegates catchupUrl to backend', () {
        when(
          () => mockBackend.buildXtreamCatchupUrl(
            baseUrl: any(named: 'baseUrl'),
            username: any(named: 'username'),
            password: any(named: 'password'),
            streamId: any(named: 'streamId'),
            startUtc: any(named: 'startUtc'),
            durationMinutes: any(named: 'durationMinutes'),
          ),
        ).thenReturn(
          'http://example.com:8080'
          '/timeshift/user/pass'
          '/60/1700000000/42.ts',
        );

        final client = createClient();
        final url = client.catchupUrl(
          42,
          startUtc: 1700000000,
          durationMinutes: 60,
        );

        expect(url, contains('/timeshift/'));

        verify(
          () => mockBackend.buildXtreamCatchupUrl(
            baseUrl: 'http://example.com:8080',
            username: 'user',
            password: 'pass',
            streamId: 42,
            startUtc: 1700000000,
            durationMinutes: 60,
          ),
        ).called(1);
      });
    });

    group('response parsing', () {
      test('parseLiveStreams delegates to backend', () async {
        final raw = [
          {
            'stream_id': 1,
            'name': 'BBC One',
            'stream_icon': 'http://logo.com/bbc.png',
            'category_id': '5',
            'num': 101,
            'epg_channel_id': 'bbc1.uk',
          },
          {
            'stream_id': 2,
            'name': 'CNN',
            'stream_icon': '',
            'category_id': '3',
          },
        ];

        // Backend returns JSON array of Channel
        // maps matching mapToChannel
        // format.
        final backendResult = jsonEncode([
          {
            'id': 'xc_1',
            'name': 'BBC One',
            'stream_url':
                'http://ex.com:8080'
                '/live/u/p/1.ts',
            'logo_url': 'http://logo.com/bbc.png',
            'channel_group': '5',
            'number': 101,
            'tvg_id': 'bbc1.uk',
            'tvg_name': 'BBC One',
            'has_catchup': false,
            'catchup_days': 0,
          },
          {
            'id': 'xc_2',
            'name': 'CNN',
            'stream_url':
                'http://ex.com:8080'
                '/live/u/p/2.ts',
            'logo_url': '',
            'channel_group': '3',
            'tvg_id': '2',
            'tvg_name': 'CNN',
            'has_catchup': false,
            'catchup_days': 0,
          },
        ]);

        when(
          () => mockBackend.parseXtreamLiveStreams(
            any(),
            baseUrl: any(named: 'baseUrl'),
            username: any(named: 'username'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => backendResult);

        final client = createClient(
          baseUrl: 'http://ex.com:8080',
          username: 'u',
          password: 'p',
        );
        final channels = await client.parseLiveStreams(raw);

        expect(channels, hasLength(2));
        expect(channels[0].name, 'BBC One');
        expect(channels[0].streamUrl, 'http://ex.com:8080/live/u/p/1.ts');
        expect(channels[0].logoUrl, 'http://logo.com/bbc.png');
        expect(channels[0].number, 101);
        expect(channels[0].tvgId, 'bbc1.uk');
        expect(channels[1].name, 'CNN');
      });

      test('parseCategories delegates to backend', () async {
        final raw = [
          {'category_id': '1', 'category_name': 'Sports'},
          {'category_id': '2', 'category_name': 'News'},
          {'category_id': '3', 'category_name': 'Entertainment'},
        ];

        when(() => mockBackend.parseXtreamCategories(any())).thenAnswer(
          (_) async => jsonEncode(['Entertainment', 'News', 'Sports']),
        );

        final client = createClient();
        final names = await client.parseCategories(raw);

        expect(names, ['Entertainment', 'News', 'Sports']);
      });

      test('parseCategories handles empty list', () async {
        when(
          () => mockBackend.parseXtreamCategories(any()),
        ).thenAnswer((_) async => jsonEncode([]));

        final client = createClient();
        final result = await client.parseCategories([]);
        expect(result, isEmpty);
      });

      test('parseCategories handles null data', () async {
        final client = createClient();
        final result = await client.parseCategories(null);
        expect(result, isEmpty);

        // Should not call backend for null.
        verifyNever(() => mockBackend.parseXtreamCategories(any()));
      });
    });
  });
}
