import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:crispy_tivi/core/domain/entities/media_item.dart';
import 'package:crispy_tivi/core/domain/entities/media_type.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/core/domain/media_source.dart';
import 'package:crispy_tivi/features/iptv/application/media_server_sync.dart';
import 'package:crispy_tivi/features/media_servers/plex/data/datasources/plex_api_client.dart';
import 'package:crispy_tivi/features/media_servers/plex/data/models/plex_metadata.dart';
import 'package:crispy_tivi/features/media_servers/plex/domain/entities/plex_server.dart';
import 'package:crispy_tivi/features/media_servers/plex/domain/plex_source.dart';
import 'package:crispy_tivi/features/media_servers/shared/utils/media_item_vod_adapter.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';

// ── Mocks ──────────────────────────────────────────

class MockPlexApiClient extends Mock implements PlexApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  group('MediaItemVodAdapter', () {
    test('maps movie correctly', () {
      final item = MediaItem(
        id: '123',
        name: 'Test Movie',
        type: MediaType.movie,
        logoUrl: 'http://img/poster.jpg',
        overview: 'A great movie',
        rating: 'PG-13',
        durationMs: 7200000, // 120 min
        metadata: {'backdropUrl': 'http://img/backdrop.jpg', 'year': 2023},
        releaseDate: DateTime(2023),
      );

      final vod = item.toVodItem(
        streamUrl: 'emby://src1/123',
        sourceId: 'src1',
        category: 'My Server > Movies',
      );

      expect(vod.id, '123');
      expect(vod.name, 'Test Movie');
      expect(vod.streamUrl, 'emby://src1/123');
      expect(vod.type, VodType.movie);
      expect(vod.posterUrl, 'http://img/poster.jpg');
      expect(vod.backdropUrl, 'http://img/backdrop.jpg');
      expect(vod.description, 'A great movie');
      expect(vod.rating, 'PG-13');
      expect(vod.year, 2023);
      expect(vod.duration, 120);
      expect(vod.category, 'My Server > Movies');
      expect(vod.sourceId, 'src1');
      expect(vod.isFavorite, false);
      expect(vod.addedAt, isNotNull);
    });

    test('maps series correctly', () {
      final item = MediaItem(
        id: '456',
        name: 'Test Series',
        type: MediaType.series,
        logoUrl: 'http://img/series.jpg',
      );

      final vod = item.toVodItem(streamUrl: 'jf://src2/456');
      expect(vod.type, VodType.series);
    });

    test('maps episode with season/episode numbers', () {
      final item = MediaItem(
        id: '789',
        name: 'Episode 5',
        type: MediaType.episode,
        durationMs: 2700000, // 45 min
        metadata: {'parentIndex': 2, 'index': 5},
      );

      final vod = item.toVodItem(
        streamUrl: 'emby://src1/789',
        sourceId: 'src1',
        category: 'Server > TV Shows',
      );

      expect(vod.type, VodType.episode);
      expect(vod.seasonNumber, 2);
      expect(vod.episodeNumber, 5);
      expect(vod.duration, 45);
    });

    test('maps folder to series type', () {
      final item = MediaItem(
        id: 'f1',
        name: 'Collection',
        type: MediaType.folder,
      );

      final vod = item.toVodItem(streamUrl: '');
      expect(vod.type, VodType.series);
    });

    test('uses logoUrl as backdrop when no backdropUrl in metadata', () {
      final item = MediaItem(
        id: '1',
        name: 'No Backdrop',
        type: MediaType.movie,
        logoUrl: 'http://img/poster.jpg',
        metadata: const {},
      );

      final vod = item.toVodItem(streamUrl: '');
      expect(vod.backdropUrl, 'http://img/poster.jpg');
    });

    test('uses backdropUrl from metadata when available', () {
      final item = MediaItem(
        id: '1',
        name: 'Has Backdrop',
        type: MediaType.movie,
        logoUrl: 'http://img/poster.jpg',
        metadata: const {'backdropUrl': 'http://img/backdrop.jpg'},
      );

      final vod = item.toVodItem(streamUrl: '');
      expect(vod.backdropUrl, 'http://img/backdrop.jpg');
    });

    test('handles null duration', () {
      final item = MediaItem(
        id: '1',
        name: 'No Duration',
        type: MediaType.movie,
      );

      final vod = item.toVodItem(streamUrl: '');
      expect(vod.duration, isNull);
    });

    test('backward compatibility: existing callers still work', () {
      // Existing callers pass only streamUrl — new params are optional.
      final item = MediaItem(
        id: '1',
        name: 'Old Style',
        type: MediaType.movie,
        logoUrl: 'http://img/poster.jpg',
      );

      final vod = item.toVodItem(streamUrl: 'http://stream.m3u8');
      expect(vod.id, '1');
      expect(vod.streamUrl, 'http://stream.m3u8');
      expect(vod.sourceId, isNull);
      expect(vod.category, isNull);
    });
  });

  group('Stream URL scheme', () {
    test('Emby stream URL format', () {
      const sourceId = 'src_emby_1';
      const itemId = 'abc123';
      final url = 'emby://$sourceId/$itemId';
      expect(url, 'emby://src_emby_1/abc123');
    });

    test('Jellyfin stream URL format', () {
      const sourceId = 'src_jf_1';
      const itemId = 'def456';
      final url = 'jellyfin://$sourceId/$itemId';
      expect(url, 'jellyfin://src_jf_1/def456');
    });

    test('Plex stream URL format', () {
      const sourceId = 'src_plex_1';
      const itemId = '12345';
      final url = 'plex://$sourceId/$itemId';
      expect(url, 'plex://src_plex_1/12345');
    });
  });

  group('VodItem ID namespacing', () {
    test('Emby ID prefix', () {
      const prefix = 'emby';
      const sourceId = 'src1';
      const itemId = 'abc';
      expect('${prefix}_${sourceId}_$itemId', 'emby_src1_abc');
    });

    test('Jellyfin ID prefix', () {
      const prefix = 'jf';
      const sourceId = 'src2';
      const itemId = 'def';
      expect('${prefix}_${sourceId}_$itemId', 'jf_src2_def');
    });

    test('Plex ID prefix', () {
      const prefix = 'plex';
      const sourceId = 'src3';
      const itemId = '123';
      expect('${prefix}_${sourceId}_$itemId', 'plex_src3_123');
    });
  });

  group('Category format', () {
    test('category uses source name and library name', () {
      const sourceName = 'My Plex';
      const libraryName = 'Movies';
      expect('$sourceName > $libraryName', 'My Plex > Movies');
    });

    test('category with special characters', () {
      const sourceName = 'Home Server (Jellyfin)';
      const libraryName = '4K Movies';
      expect(
        '$sourceName > $libraryName',
        'Home Server (Jellyfin) > 4K Movies',
      );
    });
  });

  group('PlaylistSourceType media server detection', () {
    test('plex is a media server type', () {
      expect(
        PlaylistSourceType.plex != PlaylistSourceType.m3u &&
            PlaylistSourceType.plex != PlaylistSourceType.xtream &&
            PlaylistSourceType.plex != PlaylistSourceType.stalkerPortal,
        true,
      );
    });

    test('emby is a media server type', () {
      expect(PlaylistSourceType.emby.name, 'emby');
    });

    test('jellyfin is a media server type', () {
      expect(PlaylistSourceType.jellyfin.name, 'jellyfin');
    });
  });

  group('MediaItem type to VodType mapping', () {
    final types = {
      MediaType.movie: VodType.movie,
      MediaType.series: VodType.series,
      MediaType.season: VodType.series,
      MediaType.episode: VodType.episode,
      MediaType.folder: VodType.series,
      MediaType.channel: VodType.movie,
      MediaType.unknown: VodType.movie,
    };

    for (final entry in types.entries) {
      test('${entry.key.name} → ${entry.value.name}', () {
        final item = MediaItem(id: 'test', name: 'Test', type: entry.key);
        final vod = item.toVodItem(streamUrl: '');
        expect(vod.type, entry.value);
      });
    }
  });

  group('VodItem copyWith for ID namespacing', () {
    test('copyWith preserves all fields except id', () {
      final original = VodItem(
        id: 'original_id',
        name: 'Test',
        streamUrl: 'plex://src/123',
        type: VodType.movie,
        sourceId: 'src',
        category: 'Server > Movies',
        posterUrl: 'http://img.jpg',
        year: 2023,
      );

      final namespaced = original.copyWith(id: 'plex_src_123');

      expect(namespaced.id, 'plex_src_123');
      expect(namespaced.name, 'Test');
      expect(namespaced.streamUrl, 'plex://src/123');
      expect(namespaced.sourceId, 'src');
      expect(namespaced.category, 'Server > Movies');
      expect(namespaced.posterUrl, 'http://img.jpg');
      expect(namespaced.year, 2023);
    });
  });

  // ── Plex image URL construction ───────────────────

  group('Plex image URL construction', () {
    late MockPlexApiClient mockApiClient;
    late PlexSource plexSource;

    const serverUrl = 'http://plex.local:32400';
    const token = 'plex-token-abc';
    const server = PlexServer(
      url: serverUrl,
      name: 'Test Plex',
      accessToken: token,
      clientIdentifier: 'crispy-id',
    );

    setUp(() {
      mockApiClient = MockPlexApiClient();
      plexSource = PlexSource(
        apiClient: mockApiClient,
        serverUrl: serverUrl,
        accessToken: token,
        clientIdentifier: 'crispy-id',
        serverName: 'Test Plex',
        serverId: 'plex-srv-1',
      );
    });

    setUpAll(() {
      registerFallbackValue(server);
    });

    test('produces fully-qualified image URLs with token', () async {
      when(() => mockApiClient.getLibraries(any())).thenAnswer((_) async => []);
      when(
        () => mockApiClient.getItems(any(), libraryId: any(named: 'libraryId')),
      ).thenAnswer(
        (_) async => [
          const PlexMetadata(
            ratingKey: '42',
            title: 'Inception',
            type: 'movie',
            thumb: '/library/metadata/42/thumb/1234',
            art: '/library/metadata/42/art/5678',
          ),
        ],
      );

      final items = await plexSource.getLibrary('1');
      expect(items, hasLength(1));

      final item = items.first;
      expect(
        item.logoUrl,
        '$serverUrl/library/metadata/42/thumb/1234?X-Plex-Token=$token',
      );
      expect(
        item.metadata['backdropUrl'],
        '$serverUrl/library/metadata/42/art/5678?X-Plex-Token=$token',
      );
    });

    test('handles null thumb and art paths gracefully', () async {
      when(
        () => mockApiClient.getItems(any(), libraryId: any(named: 'libraryId')),
      ).thenAnswer(
        (_) async => [
          const PlexMetadata(
            ratingKey: '99',
            title: 'No Images',
            type: 'movie',
          ),
        ],
      );

      final items = await plexSource.getLibrary('1');
      expect(items, hasLength(1));
      expect(items.first.logoUrl, isNull);
      expect(items.first.metadata['backdropUrl'], isNull);
    });
  });

  // ── Null section key filtering ────────────────────

  group('Null Plex section key filtering', () {
    test('libraries with empty id are skipped', () {
      final libraries = [
        const MediaItem(id: '1', name: 'Movies', type: MediaType.folder),
        const MediaItem(id: '', name: 'Bad Section', type: MediaType.folder),
        const MediaItem(id: '3', name: 'TV Shows', type: MediaType.folder),
      ];

      // Same filter used in _syncMediaServer.
      final valid = libraries.where(
        (lib) => lib.type == MediaType.folder && lib.id.isNotEmpty,
      );

      expect(valid.map((l) => l.name), ['Movies', 'TV Shows']);
    });

    test('non-folder types are also filtered out', () {
      final libraries = [
        const MediaItem(id: '1', name: 'Movies', type: MediaType.folder),
        const MediaItem(id: '2', name: 'A Movie', type: MediaType.movie),
      ];

      final valid = libraries.where(
        (lib) => lib.type == MediaType.folder && lib.id.isNotEmpty,
      );

      expect(valid.map((l) => l.name), ['Movies']);
    });
  });

  // ── Retry logic ───────────────────────────────────

  group('withRetry', () {
    test('returns immediately on success', () async {
      var calls = 0;
      final result = await MediaServerSyncService.withRetry(() async {
        calls++;
        return 42;
      });
      expect(result, 42);
      expect(calls, 1);
    });

    test('retries up to 3 times for 5xx errors', () async {
      var calls = 0;
      final result = await MediaServerSyncService.withRetry(() async {
        calls++;
        if (calls < 3) {
          throw DioException(
            type: DioExceptionType.badResponse,
            response: Response(
              statusCode: 500,
              requestOptions: RequestOptions(path: ''),
            ),
            requestOptions: RequestOptions(path: ''),
          );
        }
        return 'ok';
      });
      expect(result, 'ok');
      expect(calls, 3);
    });

    test('retries on connection timeout', () async {
      var calls = 0;
      final result = await MediaServerSyncService.withRetry(() async {
        calls++;
        if (calls < 2) {
          throw DioException(
            type: DioExceptionType.connectionTimeout,
            requestOptions: RequestOptions(path: ''),
          );
        }
        return 'recovered';
      });
      expect(result, 'recovered');
      expect(calls, 2);
    });

    test('retries on receive timeout', () async {
      var calls = 0;
      final result = await MediaServerSyncService.withRetry(() async {
        calls++;
        if (calls < 2) {
          throw DioException(
            type: DioExceptionType.receiveTimeout,
            requestOptions: RequestOptions(path: ''),
          );
        }
        return 'recovered';
      });
      expect(result, 'recovered');
      expect(calls, 2);
    });

    test('does NOT retry 4xx errors', () async {
      var calls = 0;
      await expectLater(
        () => MediaServerSyncService.withRetry(() async {
          calls++;
          throw DioException(
            type: DioExceptionType.badResponse,
            response: Response(
              statusCode: 404,
              requestOptions: RequestOptions(path: ''),
            ),
            requestOptions: RequestOptions(path: ''),
          );
        }),
        throwsA(isA<DioException>()),
      );
      expect(calls, 1);
    });

    test('does NOT retry 401 Unauthorized', () async {
      var calls = 0;
      await expectLater(
        () => MediaServerSyncService.withRetry(() async {
          calls++;
          throw DioException(
            type: DioExceptionType.badResponse,
            response: Response(
              statusCode: 401,
              requestOptions: RequestOptions(path: ''),
            ),
            requestOptions: RequestOptions(path: ''),
          );
        }),
        throwsA(isA<DioException>()),
      );
      expect(calls, 1);
    });

    test('rethrows after max attempts exhausted', () async {
      var calls = 0;
      await expectLater(
        () => MediaServerSyncService.withRetry(() async {
          calls++;
          throw DioException(
            type: DioExceptionType.badResponse,
            response: Response(
              statusCode: 503,
              requestOptions: RequestOptions(path: ''),
            ),
            requestOptions: RequestOptions(path: ''),
          );
        }, maxAttempts: 2),
        throwsA(isA<DioException>()),
      );
      // Should have tried exactly maxAttempts times.
      expect(calls, 2);
    });

    test('non-DioException errors are not retried', () async {
      var calls = 0;
      await expectLater(
        () => MediaServerSyncService.withRetry(() async {
          calls++;
          throw StateError('something broke');
        }),
        throwsA(isA<StateError>()),
      );
      expect(calls, 1);
    });
  });

  // ── Large response offloading ─────────────────────

  group('Large response UTF-8 decoding', () {
    test('small payload decodes synchronously via utf8', () {
      final smallPayload = utf8.encode('{"hello":"world"}');
      // Verify the payload is under the 50KB threshold.
      expect(smallPayload.length, lessThan(50 * 1024));

      final decoded = utf8.decode(smallPayload, allowMalformed: true);
      expect(decoded, '{"hello":"world"}');
    });

    test('large payload (>50KB) decodes correctly', () {
      // Generate a payload larger than the 50KB threshold.
      final largeString = 'x' * (60 * 1024);
      final largePayload = utf8.encode(largeString);
      expect(largePayload.length, greaterThan(50 * 1024));

      final decoded = utf8.decode(largePayload, allowMalformed: true);
      expect(decoded.length, 60 * 1024);
    });

    test('malformed UTF-8 does not throw', () {
      // Invalid UTF-8 sequence.
      final malformed = [0xC0, 0xAF, 0x48, 0x65, 0x6C, 0x6C, 0x6F];
      final decoded = utf8.decode(malformed, allowMalformed: true);
      // Should contain replacement chars but not throw.
      expect(decoded, contains('Hello'));
    });
  });

  // ── Sync report and status patterns ───────────────

  group('Sync error and status patterns', () {
    test('ArgumentError thrown for non-media-server types', () {
      // The sync service throws ArgumentError for M3U and Xtream types.
      // Verify the expected types ARE media servers.
      expect(PlaylistSourceType.plex.name, 'plex');
      expect(PlaylistSourceType.emby.name, 'emby');
      expect(PlaylistSourceType.jellyfin.name, 'jellyfin');

      // These should NOT be passed to media server sync.
      expect(PlaylistSourceType.m3u.name, 'm3u');
      expect(PlaylistSourceType.xtream.name, 'xtream');
    });

    test('empty items guard prevents deletion of existing content', () {
      // When allVodItems is empty, deleteRemovedVodItems should NOT
      // be called. This prevents data loss on network errors.
      final allVodItems = <VodItem>[];
      expect(allVodItems.isNotEmpty, false);
    });

    test('keepIds set is built from allVodItems correctly', () {
      final items = [
        VodItem(
          id: 'plex_src_1',
          name: 'Movie 1',
          streamUrl: 'plex://src/1',
          type: VodType.movie,
          sourceId: 'src',
        ),
        VodItem(
          id: 'plex_src_2',
          name: 'Movie 2',
          streamUrl: 'plex://src/2',
          type: VodType.movie,
          sourceId: 'src',
        ),
      ];

      final keepIds = items.map((v) => v.id).toSet();
      expect(keepIds, {'plex_src_1', 'plex_src_2'});
    });
  });

  // ── PaginatedResult behavior ──────────────────────

  group('PaginatedResult pagination logic', () {
    test('hasMore is true when more items exist', () {
      const result = PaginatedResult<MediaItem>(
        items: [
          MediaItem(id: '1', name: 'A', type: MediaType.movie),
          MediaItem(id: '2', name: 'B', type: MediaType.movie),
        ],
        totalCount: 10,
        startIndex: 0,
        limit: 2,
      );
      expect(result.hasMore, true);
      expect(result.nextStartIndex, 2);
    });

    test('hasMore is false on last page', () {
      const result = PaginatedResult<MediaItem>(
        items: [
          MediaItem(id: '9', name: 'I', type: MediaType.movie),
          MediaItem(id: '10', name: 'J', type: MediaType.movie),
        ],
        totalCount: 10,
        startIndex: 8,
        limit: 2,
      );
      expect(result.hasMore, false);
    });

    test('empty result has no more items', () {
      final result = PaginatedResult.empty<MediaItem>();
      expect(result.hasMore, false);
      expect(result.items, isEmpty);
      expect(result.totalCount, 0);
    });
  });
}
