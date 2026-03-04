import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:crispy_tivi/core/data/crispy_backend.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/iptv/data/parsers/stalker_portal_client.dart';

class MockCrispyBackend extends Mock implements CrispyBackend {}

void main() {
  late MockCrispyBackend mockBackend;

  setUp(() {
    mockBackend = MockCrispyBackend();
  });

  StalkerPortalClient createClient({
    String baseUrl = 'http://example.com',
    String macAddress = '00:1A:2B:3C:4D:5E',
    bool validMac = true,
  }) {
    when(() => mockBackend.validateMacAddress(any())).thenReturn(validMac);
    final mb = MemoryBackend();
    when(() => mockBackend.normalizeApiBaseUrl(any())).thenAnswer(
      (inv) => mb.normalizeApiBaseUrl(inv.positionalArguments[0] as String),
    );
    return StalkerPortalClient(
      baseUrl: baseUrl,
      macAddress: macAddress,
      backend: mockBackend,
    );
  }

  group('StalkerPortalClient', () {
    group('MAC address validation', () {
      test('accepts valid MAC address with uppercase', () {
        expect(
          () => createClient(macAddress: '00:1A:2B:3C:4D:5E'),
          returnsNormally,
        );
      });

      test('accepts valid MAC address with lowercase', () {
        expect(
          () => createClient(macAddress: '00:1a:2b:3c:4d:5e'),
          returnsNormally,
        );
      });

      test('throws on invalid MAC format (no colons)', () {
        expect(
          () => createClient(macAddress: '001A2B3C4D5E', validMac: false),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws on MAC with wrong separator', () {
        expect(
          () => createClient(macAddress: '00-1A-2B-3C-4D-5E', validMac: false),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws on MAC with too few octets', () {
        expect(
          () => createClient(macAddress: '00:1A:2B:3C:4D', validMac: false),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws on empty MAC address', () {
        expect(
          () => createClient(macAddress: '', validMac: false),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('URL normalization', () {
      test('strips trailing path from base URL', () {
        final client = createClient(baseUrl: 'http://example.com/c/');
        expect(client.baseUrl, 'http://example.com');
      });

      test('strips trailing slash', () {
        final client = createClient(baseUrl: 'http://example.com:25461/');
        expect(client.baseUrl, 'http://example.com:25461');
      });

      test('preserves port number', () {
        final client = createClient(
          baseUrl: 'http://example.com:8080/portal.php',
        );
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

    group('stream URL building', () {
      test('delegates to backend buildStalkerStreamUrl', () {
        when(
          () => mockBackend.buildStalkerStreamUrl(any(), any()),
        ).thenReturn('http://stream.com/live/123.ts');

        final client = createClient();
        final url = client.buildStreamUrl('http://stream.com/live/123.ts');

        expect(url, 'http://stream.com/live/123.ts');
        verify(
          () => mockBackend.buildStalkerStreamUrl(
            'http://stream.com/live/123.ts',
            'http://example.com',
          ),
        ).called(1);
      });

      test('builds relative URL via backend', () {
        when(
          () => mockBackend.buildStalkerStreamUrl(any(), any()),
        ).thenReturn('http://example.com/live/123.ts');

        final client = createClient();
        final url = client.buildStreamUrl('/live/123.ts');

        expect(url, 'http://example.com/live/123.ts');
      });

      test('builds ffrt cmd URL via backend', () {
        when(
          () => mockBackend.buildStalkerStreamUrl(any(), any()),
        ).thenReturn('http://stream.com/live.ts');

        final client = createClient();
        final url = client.buildStreamUrl('ffrt http://stream.com/live.ts');

        expect(url, 'http://stream.com/live.ts');
      });
    });

    group('catchup URL building', () {
      test('builds catch-up URL with query params', () {
        when(
          () => mockBackend.buildStalkerStreamUrl(any(), any()),
        ).thenReturn('http://example.com/live/123.ts');

        final client = createClient();
        final url = client.catchupUrl(
          '/live/123.ts',
          startUtc: 1700000000,
          durationMinutes: 30,
        );

        expect(url, contains('utc=1700000000'));
        expect(url, contains('lutc=1700001800'));
      });
    });

    group('response parsing', () {
      test('parseCategories parses JS objects correctly', () async {
        final client = createClient();
        final raw = {
          'js': [
            {'id': '1', 'title': 'Sports'},
            {'id': '2', 'title': 'News'},
            {'id': '3', 'title': 'Movies'},
          ],
        };

        final categories = await client.parseCategories(raw);
        expect(categories, hasLength(3));
        expect(categories[0]['id'], '1');
        expect(categories[0]['title'], 'Sports');
      });

      test('parseCategories handles null', () async {
        final client = createClient();
        final categories = await client.parseCategories(null);
        expect(categories, isEmpty);
      });

      test('parseChannelsResult delegates to '
          'parseStalkerChannels', () async {
        when(() => mockBackend.parseStalkerChannels(any())).thenAnswer(
          (_) async => jsonEncode({
            'total_items': 100,
            'max_page_items': 25,
            'data': [
              {'id': '123', 'name': 'BBC One'},
            ],
          }),
        );

        final client = createClient();
        final raw = {
          'js': {
            'total_items': 100,
            'max_page_items': 25,
            'data': [
              {'id': '123', 'name': 'BBC One'},
            ],
          },
        };

        final result = await client.parseChannelsResult(raw);
        expect(result.channels, hasLength(1));
        expect(result.totalItems, 100);
        expect(result.maxPageItems, 25);
        expect(result.hasMorePages, isTrue);
        expect(result.totalPages, 4);
      });

      test('parseChannelsResult handles null', () async {
        final client = createClient();
        final result = await client.parseChannelsResult(null);
        expect(result.channels, isEmpty);
      });

      test('parseLiveStreams delegates to '
          'parseStalkerLiveStreams', () async {
        when(
          () => mockBackend.parseStalkerLiveStreams(any(), any(), any()),
        ).thenAnswer(
          (_) async => jsonEncode([
            {
              'id': 'stk_123',
              'name': 'BBC One',
              'stream_url': 'http://example.com/live/123.ts',
              'channel_group': '1',
              'logo_url': 'http://logo.com/bbc.png',
              'tvg_id': 'bbc1.uk',
              'has_catchup': true,
              'catchup_days': 7,
              'source_id': 'test_source',
            },
          ]),
        );

        final client = createClient();
        final channels = await client.parseLiveStreams([
          {'id': '123', 'name': 'BBC One', 'cmd': '/live/123.ts'},
        ], sourceId: 'test_source');

        expect(channels, hasLength(1));
        expect(channels[0].id, 'stk_123');
        expect(channels[0].name, 'BBC One');
        verify(
          () => mockBackend.parseStalkerLiveStreams(
            any(),
            'test_source',
            'http://example.com',
          ),
        ).called(1);
      });

      test('parseVodResult delegates to '
          'parseStalkerVodResult', () async {
        when(() => mockBackend.parseStalkerVodResult(any())).thenAnswer(
          (_) async => jsonEncode({
            'total_items': 200,
            'max_page_items': 50,
            'data': [
              {'id': '1', 'name': 'Test Movie', 'cmd': '/vod/1.mp4'},
            ],
          }),
        );

        final client = createClient();
        final raw = {
          'js': {
            'total_items': 200,
            'max_page_items': 50,
            'data': [
              {'id': '1', 'name': 'Test Movie', 'cmd': '/vod/1.mp4'},
            ],
          },
        };

        final result = await client.parseVodResult(raw);
        expect(result.items, hasLength(1));
        expect(result.totalItems, 200);
        expect(result.maxPageItems, 50);
        expect(result.hasMorePages, isTrue);
        expect(result.totalPages, 4);
      });

      test('parseVodResult handles null', () async {
        final client = createClient();
        final result = await client.parseVodResult(null);
        expect(result.items, isEmpty);
        expect(result.totalItems, 0);
      });

      test('parseVodItems delegates to '
          'parseStalkerVodItems', () async {
        when(
          () => mockBackend.parseStalkerVodItems(
            any(),
            any(),
            vodType: any(named: 'vodType'),
          ),
        ).thenAnswer(
          (_) async => jsonEncode([
            {
              'id': 'stk_vod_123',
              'name': 'Action Movie',
              'stream_url': 'http://example.com/vod/123.mp4',
              'type': 'movie',
              'poster_url': 'http://img.com/poster.jpg',
              'description': 'An action-packed film',
              'rating': '7.5',
              'year': 2023,
              'duration': 120,
              'category': '5',
            },
          ]),
        );

        final client = createClient();
        final items = await client.parseVodItems([
          {'id': '123', 'name': 'Action Movie', 'cmd': '/vod/123.mp4'},
        ]);

        expect(items, hasLength(1));
        expect(items[0].id, 'stk_vod_123');
        expect(items[0].name, 'Action Movie');
        verify(
          () => mockBackend.parseStalkerVodItems(
            any(),
            'http://example.com',
            vodType: 'movie',
          ),
        ).called(1);
      });

      test('parseCreateLinkResponse delegates to '
          'parseStalkerCreateLink', () async {
        when(
          () => mockBackend.parseStalkerCreateLink(any(), any()),
        ).thenAnswer((_) async => 'http://stream.com/live.ts?token=abc123');

        final client = createClient();
        final raw = {
          'js': {'cmd': 'ffrt http://stream.com/live.ts?token=abc123'},
        };

        final url = await client.parseCreateLinkResponse(raw);
        expect(url, 'http://stream.com/live.ts?token=abc123');
      });

      test('parseCreateLinkResponse returns null '
          'for null data', () async {
        final client = createClient();
        final url = await client.parseCreateLinkResponse(null);
        expect(url, isNull);
      });
    });

    group('authentication state', () {
      test('isAuthenticated is false initially', () {
        final client = createClient();
        expect(client.isAuthenticated, isFalse);
      });
    });
  });
}
