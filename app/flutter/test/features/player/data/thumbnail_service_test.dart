import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:crispy_tivi/core/data/crispy_backend.dart';
import 'package:crispy_tivi/features/player/data/'
    'thumbnail_service.dart';
import 'package:crispy_tivi/features/player/domain/entities/'
    'thumbnail_sprite.dart';

// ── Mocks ──────────────────────────────────────────

class MockDio extends Mock implements Dio {}

class MockCrispyBackend extends Mock implements CrispyBackend {}

class FakeOptions extends Fake implements Options {}

class FakeRequestOptions extends Fake implements RequestOptions {}

void main() {
  late MockDio mockDio;
  late MockCrispyBackend mockBackend;
  late ThumbnailService service;

  setUpAll(() {
    registerFallbackValue(FakeOptions());
    registerFallbackValue(FakeRequestOptions());
  });

  setUp(() {
    mockDio = MockDio();
    mockBackend = MockCrispyBackend();
    service = ThumbnailService(dio: mockDio, backend: mockBackend);
  });

  // ── Helper ───────────────────────────────────────

  Response<String> okResponse(String data) {
    return Response<String>(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: ''),
    );
  }

  Map<String, dynamic> validSpriteMap() {
    return <String, dynamic>{
      'image_url': 'http://x.com/tile.jpg',
      'columns': 10,
      'rows': 5,
      'thumb_width': 160,
      'thumb_height': 90,
      'cues': <Map<String, dynamic>>[
        {'start_ms': 0, 'end_ms': 5000, 'x': 0, 'y': 0},
      ],
    };
  }

  // ── loadThumbnails() — Jellyfin source ───────────

  group('loadThumbnails() — Jellyfin source', () {
    const jellyfinUrl = 'http://jellyfin.local/Videos/abc123/stream';

    test('loads thumbnails from Jellyfin trickplay URL', () async {
      when(
        () => mockDio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => okResponse('WEBVTT content'));
      when(
        () => mockBackend.parseVttThumbnails(any(), any()),
      ).thenAnswer((_) async => validSpriteMap());

      final result = await service.loadThumbnails(
        streamUrl: jellyfinUrl,
        duration: const Duration(minutes: 90),
      );

      expect(result, isNotNull);
      expect(result, isA<ThumbnailSprite>());
      expect((result! as ThumbnailSprite).imageUrl, 'http://x.com/tile.jpg');
    });

    test('constructs correct trickplay VTT URL', () async {
      when(
        () => mockDio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => okResponse('WEBVTT'));
      when(
        () => mockBackend.parseVttThumbnails(any(), any()),
      ).thenAnswer((_) async => validSpriteMap());

      await service.loadThumbnails(
        streamUrl: jellyfinUrl,
        duration: const Duration(minutes: 90),
      );

      final captured =
          verify(
                () => mockDio.get<String>(
                  captureAny(),
                  options: any(named: 'options'),
                ),
              ).captured.first
              as String;

      expect(captured, contains('/Videos/abc123/Trickplay/160/tiles.vtt'));
    });

    test('returns null when Jellyfin returns non-200', () async {
      when(
        () => mockDio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => Response<String>(
          data: null,
          statusCode: 404,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final result = await service.loadThumbnails(
        streamUrl: jellyfinUrl,
        duration: const Duration(minutes: 90),
      );

      expect(result, isNull);
    });

    test('returns null when Jellyfin throws DioException', () async {
      when(
        () => mockDio.get<String>(any(), options: any(named: 'options')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final result = await service.loadThumbnails(
        streamUrl: jellyfinUrl,
        duration: const Duration(minutes: 90),
      );

      expect(result, isNull);
    });
  });

  // ── loadThumbnails() — non-Jellyfin URL ──────────

  group('loadThumbnails() — VTT fallback', () {
    const vodUrl = 'http://cdn.example.com/movie.mp4';

    test('skips Jellyfin and tries VTT URLs for '
        'non-Jellyfin stream', () async {
      // All Dio calls fail — no thumbnails.
      when(
        () => mockDio.get<String>(any(), options: any(named: 'options')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final result = await service.loadThumbnails(
        streamUrl: vodUrl,
        duration: const Duration(minutes: 120),
      );

      expect(result, isNull);
    });

    test('tries multiple VTT URL patterns', () async {
      // Track all requested URLs.
      final requestedUrls = <String>[];
      when(
        () => mockDio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((inv) {
        final url = inv.positionalArguments[0] as String;
        requestedUrls.add(url);
        throw DioException(
          requestOptions: RequestOptions(path: url),
          type: DioExceptionType.connectionTimeout,
        );
      });

      await service.loadThumbnails(
        streamUrl: vodUrl,
        duration: const Duration(minutes: 120),
      );

      // Should have tried _thumbnails.vtt, .vtt,
      // and -thumbnails.vtt patterns.
      final vttUrls = requestedUrls.where((u) => u.contains('movie'));
      expect(vttUrls, isNotEmpty);
    });

    test('returns sprite from first successful VTT URL', () async {
      when(
        () => mockDio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((inv) {
        final url = inv.positionalArguments[0] as String;
        // First VTT URL fails (non-Jellyfin),
        // then _thumbnails.vtt fails,
        // then .vtt succeeds.
        if (url.endsWith('.vtt') &&
            !url.contains('_thumbnails') &&
            !url.contains('-thumbnails') &&
            !url.contains('tiles.vtt')) {
          return Future.value(okResponse('WEBVTT data'));
        }
        throw DioException(
          requestOptions: RequestOptions(path: url),
          type: DioExceptionType.connectionTimeout,
        );
      });

      when(
        () => mockBackend.parseVttThumbnails(any(), any()),
      ).thenAnswer((_) async => validSpriteMap());

      final result = await service.loadThumbnails(
        streamUrl: vodUrl,
        duration: const Duration(minutes: 120),
      );

      expect(result, isNotNull);
    });
  });

  // ── loadThumbnails() — caching behavior ──────────

  group('loadThumbnails() — caching', () {
    const streamUrl = 'http://jellyfin.local/Videos/abc/stream';

    test('returns cached sprite on second call', () async {
      when(
        () => mockDio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => okResponse('WEBVTT'));
      when(
        () => mockBackend.parseVttThumbnails(any(), any()),
      ).thenAnswer((_) async => validSpriteMap());

      // First call: hits network + backend.
      final first = await service.loadThumbnails(
        streamUrl: streamUrl,
        duration: const Duration(minutes: 90),
      );

      // Second call: should use cache.
      final second = await service.loadThumbnails(
        streamUrl: streamUrl,
        duration: const Duration(minutes: 90),
      );

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(
        (first! as ThumbnailSprite).imageUrl,
        (second! as ThumbnailSprite).imageUrl,
      );

      // Backend only called once.
      verify(() => mockBackend.parseVttThumbnails(any(), any())).called(1);
    });

    test('caches null results to avoid repeated failures', () async {
      when(
        () => mockDio.get<String>(any(), options: any(named: 'options')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      // First call: all attempts fail.
      final first = await service.loadThumbnails(
        streamUrl: streamUrl,
        duration: const Duration(minutes: 90),
      );

      // Second call: should return cached null
      // without hitting network.
      final second = await service.loadThumbnails(
        streamUrl: streamUrl,
        duration: const Duration(minutes: 90),
      );

      expect(first, isNull);
      expect(second, isNull);
    });

    test('different stream URLs are cached independently', () async {
      const url1 = 'http://jellyfin.local/Videos/aaa/stream';
      const url2 = 'http://jellyfin.local/Videos/bbb/stream';

      when(
        () => mockDio.get<String>(any(), options: any(named: 'options')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await service.loadThumbnails(
        streamUrl: url1,
        duration: const Duration(minutes: 90),
      );
      await service.loadThumbnails(
        streamUrl: url2,
        duration: const Duration(minutes: 90),
      );

      // Both made network attempts (not shared cache).
      // Each URL triggers at least one Dio get call.
      verify(
        () => mockDio.get<String>(any(), options: any(named: 'options')),
      ).called(greaterThanOrEqualTo(2));
    });
  });

  // ── clearCache() ──────────────────────────────────

  group('clearCache()', () {
    const streamUrl = 'http://jellyfin.local/Videos/abc/stream';

    test('clears all cached entries', () async {
      when(
        () => mockDio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => okResponse('WEBVTT'));
      when(
        () => mockBackend.parseVttThumbnails(any(), any()),
      ).thenAnswer((_) async => validSpriteMap());

      // Populate cache.
      await service.loadThumbnails(
        streamUrl: streamUrl,
        duration: const Duration(minutes: 90),
      );

      // Clear cache.
      service.clearCache();

      // Next call should hit network again.
      await service.loadThumbnails(
        streamUrl: streamUrl,
        duration: const Duration(minutes: 90),
      );

      verify(() => mockBackend.parseVttThumbnails(any(), any())).called(2);
    });

    test('can be called on empty cache without error', () {
      expect(() => service.clearCache(), returnsNormally);
    });

    test('can be called multiple times without error', () {
      service.clearCache();
      service.clearCache();
      service.clearCache();
      // No exception expected.
    });
  });

  // ── removeFromCache() ─────────────────────────────

  group('removeFromCache()', () {
    const streamUrl = 'http://jellyfin.local/Videos/abc/stream';

    test('removes specific stream URL from cache', () async {
      when(
        () => mockDio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => okResponse('WEBVTT'));
      when(
        () => mockBackend.parseVttThumbnails(any(), any()),
      ).thenAnswer((_) async => validSpriteMap());

      // Populate cache.
      await service.loadThumbnails(
        streamUrl: streamUrl,
        duration: const Duration(minutes: 90),
      );

      // Remove only this URL.
      service.removeFromCache(streamUrl);

      // Next call should hit network again.
      await service.loadThumbnails(
        streamUrl: streamUrl,
        duration: const Duration(minutes: 90),
      );

      verify(() => mockBackend.parseVttThumbnails(any(), any())).called(2);
    });

    test('does not affect other cached entries', () async {
      const url1 = 'http://jellyfin.local/Videos/aaa/stream';
      const url2 = 'http://jellyfin.local/Videos/bbb/stream';

      when(
        () => mockDio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => okResponse('WEBVTT'));
      when(
        () => mockBackend.parseVttThumbnails(any(), any()),
      ).thenAnswer((_) async => validSpriteMap());

      // Populate cache for both.
      await service.loadThumbnails(
        streamUrl: url1,
        duration: const Duration(minutes: 90),
      );
      await service.loadThumbnails(
        streamUrl: url2,
        duration: const Duration(minutes: 90),
      );

      // Remove only url1.
      service.removeFromCache(url1);

      // url2 should still be cached (no new call).
      reset(mockBackend);
      when(
        () => mockBackend.parseVttThumbnails(any(), any()),
      ).thenAnswer((_) async => validSpriteMap());

      final result = await service.loadThumbnails(
        streamUrl: url2,
        duration: const Duration(minutes: 90),
      );

      expect(result, isNotNull);
      // Backend should NOT be called for url2
      // (still cached).
      verifyNever(() => mockBackend.parseVttThumbnails(any(), any()));
    });

    test('removing non-existent URL is a no-op', () {
      expect(() => service.removeFromCache('no-such-url'), returnsNormally);
    });
  });

  // ── Xtream thumbnails ─────────────────────────────

  group('loadThumbnails() — Xtream source', () {
    test('returns null for Xtream-style URLs (placeholder)', () async {
      const xtreamUrl =
          'http://iptv.example.com/movie/user/pass/'
          '12345.mp4';

      // All Dio calls fail.
      when(
        () => mockDio.get<String>(any(), options: any(named: 'options')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final result = await service.loadThumbnails(
        streamUrl: xtreamUrl,
        duration: const Duration(minutes: 120),
      );

      expect(result, isNull);
    });
  });

  // ── Constructor ───────────────────────────────────

  group('ThumbnailService constructor', () {
    test('creates service with custom Dio instance', () {
      final svc = ThumbnailService(dio: mockDio, backend: mockBackend);
      expect(svc, isNotNull);
    });

    test('creates service with default Dio when not '
        'provided', () {
      final svc = ThumbnailService(backend: mockBackend);
      expect(svc, isNotNull);
    });

    test('service is usable immediately after creation', () async {
      when(
        () => mockDio.get<String>(any(), options: any(named: 'options')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final svc = ThumbnailService(dio: mockDio, backend: mockBackend);

      // Should not throw.
      final result = await svc.loadThumbnails(
        streamUrl: 'http://example.com/test.mp4',
        duration: const Duration(minutes: 60),
      );
      expect(result, isNull);
    });
  });
}
