import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/crispy_backend.dart';
import 'package:crispy_tivi/core/data/device_service.dart';
import 'package:crispy_tivi/features/player/data/'
    'watch_history_service.dart';
import 'package:crispy_tivi/features/player/domain/entities/'
    'watch_history_entry.dart';

// ── Mocks ──────────────────────────────────────────

class MockCacheService extends Mock implements CacheService {}

class MockDeviceService extends Mock implements DeviceService {}

class MockCrispyBackend extends Mock implements CrispyBackend {}

// ── Helpers ────────────────────────────────────────

WatchHistoryEntry _entry({
  String id = 'item-1',
  String mediaType = 'movie',
  String name = 'Test Movie',
  String streamUrl = 'http://example.com/movie.mp4',
  String? posterUrl,
  int positionMs = 5000,
  int durationMs = 100000,
  DateTime? lastWatched,
  String? seriesId,
  int? seasonNumber,
  int? episodeNumber,
  String? deviceId,
  String? deviceName,
}) {
  return WatchHistoryEntry(
    id: id,
    mediaType: mediaType,
    name: name,
    streamUrl: streamUrl,
    posterUrl: posterUrl,
    positionMs: positionMs,
    durationMs: durationMs,
    lastWatched: lastWatched ?? DateTime(2026, 2, 20),
    seriesId: seriesId,
    seasonNumber: seasonNumber,
    episodeNumber: episodeNumber,
    deviceId: deviceId,
    deviceName: deviceName,
  );
}

void main() {
  late MockCacheService mockCache;
  late MockDeviceService mockDevice;
  late MockCrispyBackend mockBackend;
  late WatchHistoryService service;

  const testDeviceId = 'device-abc-123';
  const testDeviceName = 'Windows PC';

  setUpAll(() {
    registerFallbackValue(_entry());
    registerFallbackValue('dummy');
  });

  setUp(() {
    mockCache = MockCacheService();
    mockDevice = MockDeviceService();
    mockBackend = MockCrispyBackend();

    when(() => mockDevice.getDeviceId()).thenAnswer((_) async => testDeviceId);
    when(
      () => mockDevice.getDeviceName(),
    ).thenAnswer((_) async => testDeviceName);

    service = WatchHistoryService(
      mockCache,
      mockDevice,
      mockBackend,
      'default',
    );
  });

  // ── record() ─────────────────────────────────────

  group('record()', () {
    setUp(() {
      when(() => mockCache.saveWatchHistory(any())).thenAnswer((_) async {});
      when(() => mockCache.loadWatchHistory()).thenAnswer((_) async => []);
    });

    test('saves entry with device info from service', () async {
      await service.record(
        id: 'movie-1',
        mediaType: 'movie',
        name: 'Test Movie',
        streamUrl: 'http://example.com/movie.mp4',
        positionMs: 3000,
        durationMs: 120000,
      );

      final captured =
          verify(() => mockCache.saveWatchHistory(captureAny())).captured.single
              as WatchHistoryEntry;

      expect(captured.id, 'movie-1');
      expect(captured.mediaType, 'movie');
      expect(captured.name, 'Test Movie');
      expect(captured.streamUrl, 'http://example.com/movie.mp4');
      expect(captured.positionMs, 3000);
      expect(captured.durationMs, 120000);
      expect(captured.deviceId, testDeviceId);
      expect(captured.deviceName, testDeviceName);
    });

    test('saves entry with optional series fields', () async {
      await service.record(
        id: 'ep-1',
        mediaType: 'episode',
        name: 'Episode 1',
        streamUrl: 'http://example.com/ep.mp4',
        seriesId: 'series-42',
        seasonNumber: 2,
        episodeNumber: 5,
      );

      final captured =
          verify(() => mockCache.saveWatchHistory(captureAny())).captured.single
              as WatchHistoryEntry;

      expect(captured.seriesId, 'series-42');
      expect(captured.seasonNumber, 2);
      expect(captured.episodeNumber, 5);
    });

    test('saves entry with optional poster URL', () async {
      await service.record(
        id: 'movie-2',
        mediaType: 'movie',
        name: 'Movie Two',
        streamUrl: 'http://example.com/m2.mp4',
        posterUrl: 'http://example.com/poster.jpg',
      );

      final captured =
          verify(() => mockCache.saveWatchHistory(captureAny())).captured.single
              as WatchHistoryEntry;

      expect(captured.posterUrl, 'http://example.com/poster.jpg');
    });

    test('uses default positionMs=0 and durationMs=0', () async {
      await service.record(
        id: 'ch-1',
        mediaType: 'channel',
        name: 'Channel 1',
        streamUrl: 'http://example.com/live',
      );

      final captured =
          verify(() => mockCache.saveWatchHistory(captureAny())).captured.single
              as WatchHistoryEntry;

      expect(captured.positionMs, 0);
      expect(captured.durationMs, 0);
    });

    test('sets lastWatched to approximately now', () async {
      final before = DateTime.now();

      await service.record(
        id: 'movie-3',
        mediaType: 'movie',
        name: 'Movie Three',
        streamUrl: 'http://example.com/m3.mp4',
      );

      final after = DateTime.now();

      final captured =
          verify(() => mockCache.saveWatchHistory(captureAny())).captured.single
              as WatchHistoryEntry;

      expect(
        captured.lastWatched.isAfter(
          before.subtract(const Duration(seconds: 1)),
        ),
        isTrue,
      );
      expect(
        captured.lastWatched.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });
  });

  // ── updatePosition() ─────────────────────────────

  group('updatePosition()', () {
    setUp(() {
      when(() => mockCache.saveWatchHistory(any())).thenAnswer((_) async {});
    });

    test('updates position on existing entry', () async {
      final existing = _entry(id: 'movie-1', positionMs: 1000);
      when(
        () => mockCache.loadWatchHistory(),
      ).thenAnswer((_) async => [existing]);

      await service.updatePosition('movie-1', 50000);

      final captured =
          verify(() => mockCache.saveWatchHistory(captureAny())).captured.single
              as WatchHistoryEntry;

      expect(captured.id, 'movie-1');
      expect(captured.positionMs, 50000);
      expect(captured.deviceId, testDeviceId);
      expect(captured.deviceName, testDeviceName);
    });

    test('does nothing when entry not found', () async {
      when(() => mockCache.loadWatchHistory()).thenAnswer((_) async => []);

      await service.updatePosition('missing-id', 50000);

      verifyNever(() => mockCache.saveWatchHistory(any()));
    });

    test('updates lastWatched to approximately now', () async {
      final existing = _entry(id: 'movie-1', positionMs: 1000);
      when(
        () => mockCache.loadWatchHistory(),
      ).thenAnswer((_) async => [existing]);

      final before = DateTime.now();
      await service.updatePosition('movie-1', 50000);
      final after = DateTime.now();

      final captured =
          verify(() => mockCache.saveWatchHistory(captureAny())).captured.single
              as WatchHistoryEntry;

      expect(
        captured.lastWatched.isAfter(
          before.subtract(const Duration(seconds: 1)),
        ),
        isTrue,
      );
      expect(
        captured.lastWatched.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('finds correct entry among multiple', () async {
      final entries = [
        _entry(id: 'item-a', positionMs: 100),
        _entry(id: 'item-b', positionMs: 200),
        _entry(id: 'item-c', positionMs: 300),
      ];
      when(() => mockCache.loadWatchHistory()).thenAnswer((_) async => entries);

      await service.updatePosition('item-b', 99999);

      final captured =
          verify(() => mockCache.saveWatchHistory(captureAny())).captured.single
              as WatchHistoryEntry;

      expect(captured.id, 'item-b');
      expect(captured.positionMs, 99999);
    });
  });

  // ── getAll() ──────────────────────────────────────

  group('getAll()', () {
    test('returns entries sorted by recency descending', () async {
      final entries = [
        _entry(id: 'old', lastWatched: DateTime(2026, 1, 1)),
        _entry(id: 'newest', lastWatched: DateTime(2026, 3, 1)),
        _entry(id: 'mid', lastWatched: DateTime(2026, 2, 1)),
      ];
      when(() => mockCache.loadWatchHistory()).thenAnswer((_) async => entries);

      final result = await service.getAll();

      expect(result.map((e) => e.id).toList(), ['newest', 'mid', 'old']);
    });

    test('returns empty list when no history', () async {
      when(() => mockCache.loadWatchHistory()).thenAnswer((_) async => []);

      final result = await service.getAll();

      expect(result, isEmpty);
    });

    test('returns single item unchanged', () async {
      final entries = [_entry(id: 'only-one')];
      when(() => mockCache.loadWatchHistory()).thenAnswer((_) async => entries);

      final result = await service.getAll();

      expect(result, hasLength(1));
      expect(result.first.id, 'only-one');
    });
  });

  // ── getContinueWatching() ─────────────────────────

  group('getContinueWatching()', () {
    test('delegates to backend with serialized history', () async {
      final entries = [
        _entry(id: 'movie-1', positionMs: 5000, durationMs: 100000),
      ];
      when(() => mockCache.loadWatchHistory()).thenAnswer((_) async => entries);

      final resultMap = watchHistoryEntryToMap(entries.first);
      when(
        () => mockBackend.filterContinueWatching(
          any(),
          mediaType: null,
          profileId: 'default',
        ),
      ).thenAnswer((_) async => jsonEncode([resultMap]));

      final result = await service.getContinueWatching();

      expect(result, hasLength(1));
      expect(result.first.id, 'movie-1');
    });

    test('passes mediaType filter to backend', () async {
      when(() => mockCache.loadWatchHistory()).thenAnswer((_) async => []);
      when(
        () => mockBackend.filterContinueWatching(
          any(),
          mediaType: 'movie',
          profileId: 'default',
        ),
      ).thenAnswer((_) async => '[]');

      await service.getContinueWatching(mediaType: 'movie');

      verify(
        () => mockBackend.filterContinueWatching(
          any(),
          mediaType: 'movie',
          profileId: 'default',
        ),
      ).called(1);
    });

    test('returns empty list when backend returns empty', () async {
      when(() => mockCache.loadWatchHistory()).thenAnswer((_) async => []);
      when(
        () => mockBackend.filterContinueWatching(
          any(),
          mediaType: null,
          profileId: 'default',
        ),
      ).thenAnswer((_) async => '[]');

      final result = await service.getContinueWatching();

      expect(result, isEmpty);
    });

    test('passes null mediaType by default', () async {
      when(() => mockCache.loadWatchHistory()).thenAnswer((_) async => []);
      when(
        () => mockBackend.filterContinueWatching(
          any(),
          mediaType: null,
          profileId: 'default',
        ),
      ).thenAnswer((_) async => '[]');

      await service.getContinueWatching();

      verify(
        () => mockBackend.filterContinueWatching(
          any(),
          mediaType: null,
          profileId: 'default',
        ),
      ).called(1);
    });
  });

  // ── getFromOtherDevices() ─────────────────────────

  group('getFromOtherDevices()', () {
    test('passes current device ID and cutoff to backend', () async {
      when(() => mockCache.loadWatchHistory()).thenAnswer((_) async => []);
      when(
        () => mockBackend.filterCrossDevice(any(), any(), any()),
      ).thenAnswer((_) async => '[]');

      await service.getFromOtherDevices();

      final captured =
          verify(
            () => mockBackend.filterCrossDevice(
              any(),
              captureAny(),
              captureAny(),
            ),
          ).captured;

      expect(captured[0], testDeviceId);
      // cutoffMs should be approximately 7 days ago.
      final cutoffMs = captured[1] as int;
      final sevenDaysAgo =
          DateTime.now()
              .subtract(const Duration(days: 7))
              .millisecondsSinceEpoch;
      expect((cutoffMs - sevenDaysAgo).abs(), lessThan(5000));
    });

    test('returns entries from backend response', () async {
      final otherEntry = _entry(
        id: 'other-1',
        deviceId: 'other-device',
        deviceName: 'Phone',
      );
      final map = watchHistoryEntryToMap(otherEntry);

      when(
        () => mockCache.loadWatchHistory(),
      ).thenAnswer((_) async => [otherEntry]);
      when(
        () => mockBackend.filterCrossDevice(any(), any(), any()),
      ).thenAnswer((_) async => jsonEncode([map]));

      final result = await service.getFromOtherDevices();

      expect(result, hasLength(1));
      expect(result.first.id, 'other-1');
    });

    test('returns empty list when no cross-device items', () async {
      when(() => mockCache.loadWatchHistory()).thenAnswer((_) async => []);
      when(
        () => mockBackend.filterCrossDevice(any(), any(), any()),
      ).thenAnswer((_) async => '[]');

      final result = await service.getFromOtherDevices();

      expect(result, isEmpty);
    });
  });

  // ── getOtherDeviceSource() ────────────────────────

  group('getOtherDeviceSource()', () {
    test('returns device name when watched on other device', () async {
      final entry = _entry(
        id: 'item-1',
        deviceId: 'other-device-id',
        deviceName: 'Phone',
      );
      when(() => mockCache.loadWatchHistory()).thenAnswer((_) async => [entry]);

      final result = await service.getOtherDeviceSource('item-1');

      expect(result, 'Phone');
    });

    test('returns "Another device" when deviceName is null', () async {
      final entry = _entry(
        id: 'item-1',
        deviceId: 'other-device-id',
        deviceName: null,
      );
      when(() => mockCache.loadWatchHistory()).thenAnswer((_) async => [entry]);

      final result = await service.getOtherDeviceSource('item-1');

      expect(result, 'Another device');
    });

    test('returns null when watched on current device', () async {
      final entry = _entry(
        id: 'item-1',
        deviceId: testDeviceId,
        deviceName: testDeviceName,
      );
      when(() => mockCache.loadWatchHistory()).thenAnswer((_) async => [entry]);

      final result = await service.getOtherDeviceSource('item-1');

      expect(result, isNull);
    });

    test('returns null when entry not found', () async {
      when(() => mockCache.loadWatchHistory()).thenAnswer((_) async => []);

      final result = await service.getOtherDeviceSource('missing');

      expect(result, isNull);
    });

    test('returns null when entry has null deviceId', () async {
      final entry = _entry(id: 'item-1', deviceId: null, deviceName: null);
      when(() => mockCache.loadWatchHistory()).thenAnswer((_) async => [entry]);

      final result = await service.getOtherDeviceSource('item-1');

      expect(result, isNull);
    });
  });

  // ── getById() ─────────────────────────────────────

  group('getById()', () {
    test('returns entry when found', () async {
      final entries = [_entry(id: 'a'), _entry(id: 'b'), _entry(id: 'c')];
      when(() => mockCache.loadWatchHistory()).thenAnswer((_) async => entries);

      final result = await service.getById('b');

      expect(result, isNotNull);
      expect(result!.id, 'b');
    });

    test('returns null when not found', () async {
      when(() => mockCache.loadWatchHistory()).thenAnswer((_) async => []);

      final result = await service.getById('nonexistent');

      expect(result, isNull);
    });

    test('returns first match when duplicates exist', () async {
      final entries = [
        _entry(id: 'dup', positionMs: 100),
        _entry(id: 'dup', positionMs: 200),
      ];
      when(() => mockCache.loadWatchHistory()).thenAnswer((_) async => entries);

      final result = await service.getById('dup');

      expect(result, isNotNull);
      expect(result!.positionMs, 100);
    });
  });

  // ── delete() ──────────────────────────────────────

  group('delete()', () {
    test('delegates to cache service', () async {
      when(() => mockCache.deleteWatchHistory(any())).thenAnswer((_) async {});

      await service.delete('item-1');

      verify(() => mockCache.deleteWatchHistory('item-1')).called(1);
    });

    test('passes correct ID to cache', () async {
      when(() => mockCache.deleteWatchHistory(any())).thenAnswer((_) async {});

      await service.delete('special-id-xyz');

      verify(() => mockCache.deleteWatchHistory('special-id-xyz')).called(1);
    });

    test('calls cache exactly once per invocation', () async {
      when(() => mockCache.deleteWatchHistory(any())).thenAnswer((_) async {});

      await service.delete('id-1');
      await service.delete('id-2');

      verify(() => mockCache.deleteWatchHistory('id-1')).called(1);
      verify(() => mockCache.deleteWatchHistory('id-2')).called(1);
    });
  });

  // ── clearAll() ────────────────────────────────────

  group('clearAll()', () {
    test('delegates to cache service', () async {
      when(() => mockCache.clearAllWatchHistory()).thenAnswer((_) async {});

      await service.clearAll();

      verify(() => mockCache.clearAllWatchHistory()).called(1);
    });

    test('can be called multiple times without error', () async {
      when(() => mockCache.clearAllWatchHistory()).thenAnswer((_) async {});

      await service.clearAll();
      await service.clearAll();

      verify(() => mockCache.clearAllWatchHistory()).called(2);
    });

    test('propagates cache errors', () async {
      when(
        () => mockCache.clearAllWatchHistory(),
      ).thenThrow(Exception('DB error'));

      expect(() => service.clearAll(), throwsException);
    });
  });

  // ── deriveId() ────────────────────────────────────

  group('deriveId()', () {
    /// Compute expected SHA-256 prefix for test assertions.
    String sha256Prefix(String url) {
      final bytes = sha256.convert(utf8.encode(url)).bytes;
      return bytes
          .take(8)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
    }

    test('returns 16 hex characters', () {
      final id = WatchHistoryService.deriveId('http://example.com/stream.m3u8');
      expect(id.length, 16);
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(id), isTrue);
    });

    test('is stable — same URL always returns same ID', () {
      const url = 'http://iptv.example.com/live/stream/1234.m3u8';
      expect(
        WatchHistoryService.deriveId(url),
        WatchHistoryService.deriveId(url),
      );
    });

    test('produces different IDs for different URLs', () {
      final id1 = WatchHistoryService.deriveId('http://example.com/a');
      final id2 = WatchHistoryService.deriveId('http://example.com/b');
      expect(id1, isNot(id2));
    });

    test('matches expected SHA-256 prefix', () {
      const url = 'http://example.com/movie.mp4';
      expect(WatchHistoryService.deriveId(url), sha256Prefix(url));
    });

    test('handles empty string', () {
      final id = WatchHistoryService.deriveId('');
      expect(id.length, 16);
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(id), isTrue);
    });

    test('handles URL with query params', () {
      const url = 'http://example.com/stream?token=abc&quality=hd';
      final id = WatchHistoryService.deriveId(url);
      expect(id.length, 16);
      expect(id, sha256Prefix(url));
    });

    test('is case-sensitive', () {
      final lower = WatchHistoryService.deriveId('http://example.com/movie');
      final upper = WatchHistoryService.deriveId('HTTP://EXAMPLE.COM/MOVIE');
      expect(lower, isNot(upper));
    });
  });

  // ── migrateWatchHistoryIds() ──────────────────────

  group('migrateWatchHistoryIds()', () {
    setUp(() {
      when(() => mockCache.saveWatchHistory(any())).thenAnswer((_) async {});
      when(() => mockCache.deleteWatchHistory(any())).thenAnswer((_) async {});
    });

    test('migrates entry with stale hashCode-style ID to SHA-256 ID', () async {
      const url = 'http://example.com/stream.m3u8';
      final staleId = url.hashCode.toRadixString(36);
      final stableId = WatchHistoryService.deriveId(url);
      final staleEntry = _entry(id: staleId, streamUrl: url);

      when(
        () => mockCache.loadWatchHistory(),
      ).thenAnswer((_) async => [staleEntry]);

      await service.migrateWatchHistoryIds();

      verify(() => mockCache.deleteWatchHistory(staleId)).called(1);
      final captured =
          verify(() => mockCache.saveWatchHistory(captureAny())).captured.single
              as WatchHistoryEntry;
      expect(captured.id, stableId);
      expect(captured.streamUrl, url);
    });

    test('skips entries whose ID already matches SHA-256', () async {
      const url = 'http://example.com/movie.mp4';
      final stableId = WatchHistoryService.deriveId(url);
      final alreadyMigratedEntry = _entry(id: stableId, streamUrl: url);

      when(
        () => mockCache.loadWatchHistory(),
      ).thenAnswer((_) async => [alreadyMigratedEntry]);

      await service.migrateWatchHistoryIds();

      verifyNever(() => mockCache.deleteWatchHistory(any()));
      verifyNever(() => mockCache.saveWatchHistory(any()));
    });

    test('skips entries with empty streamUrl', () async {
      final noUrl = _entry(id: 'some-old-id', streamUrl: '');
      when(() => mockCache.loadWatchHistory()).thenAnswer((_) async => [noUrl]);

      await service.migrateWatchHistoryIds();

      verifyNever(() => mockCache.deleteWatchHistory(any()));
      verifyNever(() => mockCache.saveWatchHistory(any()));
    });

    test('migrates multiple entries in one pass', () async {
      const url1 = 'http://example.com/ep1.mp4';
      const url2 = 'http://example.com/ep2.mp4';
      final stale1 = _entry(
        id: url1.hashCode.toRadixString(36),
        streamUrl: url1,
      );
      final stale2 = _entry(
        id: url2.hashCode.toRadixString(36),
        streamUrl: url2,
      );

      when(
        () => mockCache.loadWatchHistory(),
      ).thenAnswer((_) async => [stale1, stale2]);

      await service.migrateWatchHistoryIds();

      verify(() => mockCache.deleteWatchHistory(stale1.id)).called(1);
      verify(() => mockCache.deleteWatchHistory(stale2.id)).called(1);
      verify(() => mockCache.saveWatchHistory(any())).called(2);
    });

    test('no-op when history is empty', () async {
      when(() => mockCache.loadWatchHistory()).thenAnswer((_) async => []);

      await service.migrateWatchHistoryIds();

      verifyNever(() => mockCache.deleteWatchHistory(any()));
      verifyNever(() => mockCache.saveWatchHistory(any()));
    });

    test('preserves all entry fields during migration', () async {
      const url = 'http://example.com/movie.mp4';
      final staleId = url.hashCode.toRadixString(36);
      final original = WatchHistoryEntry(
        id: staleId,
        mediaType: 'movie',
        name: 'Test Film',
        streamUrl: url,
        posterUrl: 'http://example.com/poster.jpg',
        positionMs: 42000,
        durationMs: 90000,
        lastWatched: DateTime(2026, 1, 15),
        deviceId: 'dev-xyz',
        deviceName: 'Windows PC',
        profileId: 'profile-1',
        sourceId: 'src-1',
      );

      when(
        () => mockCache.loadWatchHistory(),
      ).thenAnswer((_) async => [original]);

      await service.migrateWatchHistoryIds();

      final captured =
          verify(() => mockCache.saveWatchHistory(captureAny())).captured.single
              as WatchHistoryEntry;

      expect(captured.mediaType, 'movie');
      expect(captured.name, 'Test Film');
      expect(captured.streamUrl, url);
      expect(captured.posterUrl, 'http://example.com/poster.jpg');
      expect(captured.positionMs, 42000);
      expect(captured.durationMs, 90000);
      expect(captured.lastWatched, DateTime(2026, 1, 15));
      expect(captured.deviceId, 'dev-xyz');
      expect(captured.deviceName, 'Windows PC');
      expect(captured.profileId, 'profile-1');
      expect(captured.sourceId, 'src-1');
    });
  });
}
