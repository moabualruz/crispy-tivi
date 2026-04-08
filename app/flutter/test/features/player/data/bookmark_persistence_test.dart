import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/player/presentation/widgets/'
    'bookmark_overlay.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── VideoBookmark.fromMap / toMap ───────────────────

  group('VideoBookmark serialization', () {
    test('round-trips through toMap and fromMap', () {
      final bm = VideoBookmark(
        id: 'bm-1',
        position: const Duration(seconds: 30),
        label: 'Cool scene',
        createdAt: DateTime(2026, 3, 9, 12, 0),
      );

      final map = bm.toMap('content-abc', 'vod');
      final restored = VideoBookmark.fromMap(map);

      expect(restored.id, 'bm-1');
      expect(restored.position, const Duration(seconds: 30));
      expect(restored.label, 'Cool scene');
      expect(restored.createdAt.year, 2026);
    });

    test('toMap sets correct content fields', () {
      final bm = VideoBookmark(
        id: 'bm-2',
        position: const Duration(minutes: 5),
        createdAt: DateTime.now(),
      );

      final map = bm.toMap('ch-123', 'channel');

      expect(map['content_id'], 'ch-123');
      expect(map['content_type'], 'channel');
      expect(map['position_ms'], 300000);
      expect(map['label'], isNull);
    });

    test('fromMap handles missing label', () {
      final map = {
        'id': 'bm-3',
        'content_id': 'c1',
        'content_type': 'vod',
        'position_ms': 10000,
        'label': null,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };

      final bm = VideoBookmark.fromMap(map);
      expect(bm.label, isNull);
      expect(bm.position.inSeconds, 10);
    });
  });

  // ── MemoryBackend bookmark CRUD ───────────────────

  group('MemoryBackend bookmark CRUD', () {
    late MemoryBackend backend;

    setUp(() {
      backend = MemoryBackend();
    });

    test('saves and loads bookmarks', () async {
      final bm = {
        'id': 'bm-1',
        'content_id': 'vod-abc',
        'content_type': 'vod',
        'position_ms': 5000,
        'label': 'First',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };

      await backend.saveBookmark(bm);
      final loaded = await backend.loadBookmarks('vod-abc');

      expect(loaded, hasLength(1));
      expect(loaded.first['id'], 'bm-1');
      expect(loaded.first['label'], 'First');
    });

    test('isolates bookmarks by content_id', () async {
      await backend.saveBookmark({
        'id': 'a1',
        'content_id': 'vod-1',
        'content_type': 'vod',
        'position_ms': 1000,
        'created_at': 0,
      });
      await backend.saveBookmark({
        'id': 'b1',
        'content_id': 'vod-2',
        'content_type': 'vod',
        'position_ms': 2000,
        'created_at': 0,
      });

      expect(await backend.loadBookmarks('vod-1'), hasLength(1));
      expect(await backend.loadBookmarks('vod-2'), hasLength(1));
      expect(await backend.loadBookmarks('vod-3'), isEmpty);
    });

    test('deleteBookmark removes by id', () async {
      await backend.saveBookmark({
        'id': 'bm-del',
        'content_id': 'c1',
        'content_type': 'vod',
        'position_ms': 100,
        'created_at': 0,
      });

      await backend.deleteBookmark('bm-del');
      expect(await backend.loadBookmarks('c1'), isEmpty);
    });

    test('clearBookmarks removes all for content', () async {
      await backend.saveBookmark({
        'id': 'x1',
        'content_id': 'c1',
        'content_type': 'vod',
        'position_ms': 100,
        'created_at': 0,
      });
      await backend.saveBookmark({
        'id': 'x2',
        'content_id': 'c1',
        'content_type': 'vod',
        'position_ms': 200,
        'created_at': 0,
      });
      await backend.saveBookmark({
        'id': 'y1',
        'content_id': 'c2',
        'content_type': 'channel',
        'position_ms': 300,
        'created_at': 0,
      });

      await backend.clearBookmarks('c1');
      expect(await backend.loadBookmarks('c1'), isEmpty);
      expect(await backend.loadBookmarks('c2'), hasLength(1));
    });

    test('upsert overwrites existing bookmark', () async {
      await backend.saveBookmark({
        'id': 'bm-up',
        'content_id': 'c1',
        'content_type': 'vod',
        'position_ms': 100,
        'label': 'old',
        'created_at': 0,
      });
      await backend.saveBookmark({
        'id': 'bm-up',
        'content_id': 'c1',
        'content_type': 'vod',
        'position_ms': 100,
        'label': 'new',
        'created_at': 0,
      });

      final loaded = await backend.loadBookmarks('c1');
      expect(loaded, hasLength(1));
      expect(loaded.first['label'], 'new');
    });
  });

  // ── CacheService bookmark passthrough ─────────────

  group('CacheService bookmark passthrough', () {
    late MemoryBackend backend;
    late CacheService cache;

    setUp(() {
      backend = MemoryBackend();
      cache = CacheService(backend);
    });

    test('round-trips bookmarks through CacheService', () async {
      final bm = {
        'id': 'bm-cs',
        'content_id': 'vod-x',
        'content_type': 'vod',
        'position_ms': 42000,
        'label': 'Test',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };

      await cache.saveBookmark(bm);
      final loaded = await cache.loadBookmarks('vod-x');

      expect(loaded, hasLength(1));
      expect(loaded.first['position_ms'], 42000);
    });

    test('deleteBookmark removes via CacheService', () async {
      await cache.saveBookmark({
        'id': 'bm-del',
        'content_id': 'c1',
        'content_type': 'vod',
        'position_ms': 100,
        'created_at': 0,
      });

      await cache.deleteBookmark('bm-del');
      expect(await cache.loadBookmarks('c1'), isEmpty);
    });

    test('clearBookmarks removes all for content', () async {
      await cache.saveBookmark({
        'id': 'a1',
        'content_id': 'c1',
        'content_type': 'vod',
        'position_ms': 100,
        'created_at': 0,
      });
      await cache.saveBookmark({
        'id': 'a2',
        'content_id': 'c1',
        'content_type': 'vod',
        'position_ms': 200,
        'created_at': 0,
      });

      await cache.clearBookmarks('c1');
      expect(await cache.loadBookmarks('c1'), isEmpty);
    });
  });

  // ── BookmarkNotifier with CacheService ────────────

  group('BookmarkNotifier persistence', () {
    late MemoryBackend backend;
    late ProviderContainer container;

    setUp(() {
      backend = MemoryBackend();
      container = ProviderContainer(
        overrides: [
          cacheServiceProvider.overrideWithValue(CacheService(backend)),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('loadForContent populates state from backend', () async {
      // Pre-seed backend with a bookmark.
      await backend.saveBookmark({
        'id': 'bm-1',
        'content_id': 'vod-abc',
        'content_type': 'vod',
        'position_ms': 15000,
        'label': 'Scene A',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      await container
          .read(bookmarkProvider.notifier)
          .loadForContent('vod-abc', 'vod');

      final bookmarks = container.read(bookmarkProvider);
      expect(bookmarks, hasLength(1));
      expect(bookmarks.first.id, 'bm-1');
      expect(bookmarks.first.position.inSeconds, 15);
      expect(bookmarks.first.label, 'Scene A');
    });

    test('add persists to backend', () async {
      await container
          .read(bookmarkProvider.notifier)
          .loadForContent('vod-xyz', 'vod');

      await container
          .read(bookmarkProvider.notifier)
          .add(const Duration(seconds: 42));

      // Check backend directly.
      final stored = await backend.loadBookmarks('vod-xyz');
      expect(stored, hasLength(1));
      expect(stored.first['position_ms'], 42000);
    });

    test('remove deletes from backend', () async {
      await backend.saveBookmark({
        'id': 'bm-del',
        'content_id': 'c1',
        'content_type': 'channel',
        'position_ms': 5000,
        'created_at': 0,
      });

      await container
          .read(bookmarkProvider.notifier)
          .loadForContent('c1', 'channel');

      expect(container.read(bookmarkProvider), hasLength(1));

      await container.read(bookmarkProvider.notifier).remove('bm-del');

      expect(container.read(bookmarkProvider), isEmpty);
      expect(await backend.loadBookmarks('c1'), isEmpty);
    });

    test('updateLabel persists updated bookmark', () async {
      await backend.saveBookmark({
        'id': 'bm-lbl',
        'content_id': 'v1',
        'content_type': 'vod',
        'position_ms': 10000,
        'label': 'Old',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      await container
          .read(bookmarkProvider.notifier)
          .loadForContent('v1', 'vod');

      await container
          .read(bookmarkProvider.notifier)
          .updateLabel('bm-lbl', 'New Label');

      final stored = await backend.loadBookmarks('v1');
      expect(stored.first['label'], 'New Label');
    });

    test('clear resets local state without deleting from backend', () async {
      await backend.saveBookmark({
        'id': 'bm-clr',
        'content_id': 'v2',
        'content_type': 'vod',
        'position_ms': 1000,
        'created_at': 0,
      });

      await container
          .read(bookmarkProvider.notifier)
          .loadForContent('v2', 'vod');

      expect(container.read(bookmarkProvider), hasLength(1));

      container.read(bookmarkProvider.notifier).clear();

      expect(container.read(bookmarkProvider), isEmpty);
      // Backend still has the bookmark.
      expect(await backend.loadBookmarks('v2'), hasLength(1));
    });

    test('bookmarks sorted by position', () async {
      await container
          .read(bookmarkProvider.notifier)
          .loadForContent('sorted', 'vod');

      await container
          .read(bookmarkProvider.notifier)
          .add(const Duration(seconds: 30));
      await container
          .read(bookmarkProvider.notifier)
          .add(const Duration(seconds: 10));
      await container
          .read(bookmarkProvider.notifier)
          .add(const Duration(seconds: 20));

      final positions =
          container
              .read(bookmarkProvider)
              .map((b) => b.position.inSeconds)
              .toList();
      expect(positions, [10, 20, 30]);
    });

    test('nearestTo finds closest bookmark', () async {
      await container
          .read(bookmarkProvider.notifier)
          .loadForContent('snap', 'vod');

      await container
          .read(bookmarkProvider.notifier)
          .add(const Duration(seconds: 10));
      await container
          .read(bookmarkProvider.notifier)
          .add(const Duration(seconds: 30));

      final nearest = container
          .read(bookmarkProvider.notifier)
          .nearestTo(const Duration(seconds: 11));

      expect(nearest, isNotNull);
      expect(nearest!.position.inSeconds, 10);
    });
  });
}
