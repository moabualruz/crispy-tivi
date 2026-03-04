import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/vod/domain/entities/'
    'vod_item.dart';

void main() {
  late MemoryBackend backend;
  late CacheService cache;

  setUp(() {
    backend = MemoryBackend();
    cache = CacheService(backend);
  });

  /// Helper to create a VOD map for the backend.
  Map<String, dynamic> vodMap({
    required String id,
    String name = 'Item',
    String type = 'movie',
    String streamUrl = 'http://x.com/v.mp4',
    String? sourceId,
    bool isFavorite = false,
  }) {
    return {
      'id': id,
      'name': name,
      'stream_url': streamUrl,
      'type': type,
      'is_favorite': isFavorite,
      'source_id': sourceId,
    };
  }

  group('MemoryBackend VOD save/load', () {
    test('saveVodItems stores items', () async {
      await backend.saveVodItems([
        vodMap(id: 'v1', name: 'Movie A'),
        vodMap(id: 'v2', name: 'Movie B'),
      ]);

      final loaded = await backend.loadVodItems();
      expect(loaded.length, 2);
    });

    test('loadVodItems returns empty initially', () async {
      final loaded = await backend.loadVodItems();
      expect(loaded, isEmpty);
    });

    test('saveVodItems upserts existing items', () async {
      await backend.saveVodItems([vodMap(id: 'v1', name: 'Original')]);
      await backend.saveVodItems([vodMap(id: 'v1', name: 'Updated')]);

      final loaded = await backend.loadVodItems();
      expect(loaded.length, 1);
      expect(loaded.first['name'], 'Updated');
    });
  });

  group('MemoryBackend deleteRemovedVodItems', () {
    test('removes items not in keepIds', () async {
      await backend.saveVodItems([
        vodMap(id: 'v1', sourceId: 'src1'),
        vodMap(id: 'v2', sourceId: 'src1'),
        vodMap(id: 'v3', sourceId: 'src1'),
      ]);

      final removed = await backend.deleteRemovedVodItems('src1', ['v1', 'v3']);

      expect(removed, 1);
      final loaded = await backend.loadVodItems();
      expect(loaded.length, 2);
      expect(loaded.map((m) => m['id']), containsAll(['v1', 'v3']));
    });

    test('only removes items from matching source', () async {
      await backend.saveVodItems([
        vodMap(id: 'v1', sourceId: 'src1'),
        vodMap(id: 'v2', sourceId: 'src2'),
      ]);

      final removed = await backend.deleteRemovedVodItems('src1', []);

      expect(removed, 1);
      final loaded = await backend.loadVodItems();
      expect(loaded.length, 1);
      expect(loaded.first['id'], 'v2');
    });

    test('returns 0 when nothing to remove', () async {
      await backend.saveVodItems([vodMap(id: 'v1', sourceId: 'src1')]);

      final removed = await backend.deleteRemovedVodItems('src1', ['v1']);
      expect(removed, 0);
    });
  });

  group('MemoryBackend VOD favorites', () {
    test('getVodFavorites returns empty initially', () async {
      final favs = await backend.getVodFavorites('profile_1');
      expect(favs, isEmpty);
    });

    test('addVodFavorite adds to set', () async {
      await backend.addVodFavorite('p1', 'v1');
      await backend.addVodFavorite('p1', 'v2');

      final favs = await backend.getVodFavorites('p1');
      expect(favs.toSet(), {'v1', 'v2'});
    });

    test('removeVodFavorite removes from set', () async {
      await backend.addVodFavorite('p1', 'v1');
      await backend.addVodFavorite('p1', 'v2');
      await backend.removeVodFavorite('p1', 'v1');

      final favs = await backend.getVodFavorites('p1');
      expect(favs, ['v2']);
    });

    test('favorites are profile-scoped', () async {
      await backend.addVodFavorite('p1', 'v1');
      await backend.addVodFavorite('p2', 'v2');

      final p1 = await backend.getVodFavorites('p1');
      final p2 = await backend.getVodFavorites('p2');

      expect(p1, ['v1']);
      expect(p2, ['v2']);
    });

    test('removing non-existent favorite is a no-op', () async {
      await backend.removeVodFavorite('p1', 'v999');
      final favs = await backend.getVodFavorites('p1');
      expect(favs, isEmpty);
    });

    test('duplicate add does not create duplicates', () async {
      await backend.addVodFavorite('p1', 'v1');
      await backend.addVodFavorite('p1', 'v1');

      final favs = await backend.getVodFavorites('p1');
      expect(favs.length, 1);
    });
  });

  group('MemoryBackend updateVodFavorite', () {
    test('updates is_favorite flag on item', () async {
      await backend.saveVodItems([vodMap(id: 'v1')]);

      await backend.updateVodFavorite('v1', true);
      final loaded = await backend.loadVodItems();
      expect(loaded.first['is_favorite'], true);

      await backend.updateVodFavorite('v1', false);
      final loaded2 = await backend.loadVodItems();
      expect(loaded2.first['is_favorite'], false);
    });

    test('no-op for non-existent item', () async {
      // Should not throw
      await backend.updateVodFavorite('nope', true);
    });
  });

  group('CacheService VOD via MemoryBackend', () {
    test('saveVodItems + loadVodItems round-trip', () async {
      final items = [
        const VodItem(
          id: 'cs_1',
          name: 'Cache Movie',
          streamUrl: 'http://x.com/cm.mp4',
          type: VodType.movie,
          category: 'Action',
          year: 2021,
          rating: '7.8',
        ),
        const VodItem(
          id: 'cs_2',
          name: 'Cache Series',
          streamUrl: '',
          type: VodType.series,
          category: 'Drama',
        ),
      ];

      await cache.saveVodItems(items);
      final loaded = await cache.loadVodItems();

      expect(loaded.length, 2);
      expect(loaded[0].id, 'cs_1');
      expect(loaded[0].name, 'Cache Movie');
      expect(loaded[0].type, VodType.movie);
      expect(loaded[0].category, 'Action');
      expect(loaded[1].id, 'cs_2');
      expect(loaded[1].type, VodType.series);
    });

    test('saveVodItems skips empty list', () async {
      await cache.saveVodItems([]);
      final loaded = await cache.loadVodItems();
      expect(loaded, isEmpty);
    });

    test('updateVodFavorite via CacheService', () async {
      final items = [
        const VodItem(
          id: 'fav_1',
          name: 'Fav Test',
          streamUrl: 'u',
          type: VodType.movie,
        ),
      ];
      await cache.saveVodItems(items);

      await cache.updateVodFavorite('fav_1', true);
      final loaded = await cache.loadVodItems();
      expect(loaded.first.isFavorite, true);
    });

    test('VOD favorites CRUD via CacheService', () async {
      await cache.addVodFavorite('profile_1', 'v1');
      await cache.addVodFavorite('profile_1', 'v2');

      var favs = await cache.getVodFavorites('profile_1');
      expect(favs.toSet(), {'v1', 'v2'});

      await cache.removeVodFavorite('profile_1', 'v1');
      favs = await cache.getVodFavorites('profile_1');
      expect(favs, ['v2']);
    });

    test('category favorites CRUD via CacheService', () async {
      await cache.addFavoriteCategory('p1', 'vod', 'Action');
      await cache.addFavoriteCategory('p1', 'vod', 'Drama');

      var cats = await cache.getFavoriteCategories('p1', 'vod');
      expect(cats.toSet(), {'Action', 'Drama'});

      await cache.removeFavoriteCategory('p1', 'vod', 'Action');
      cats = await cache.getFavoriteCategories('p1', 'vod');
      expect(cats, ['Drama']);
    });
  });

  group('MemoryBackend clearAll', () {
    test('clears VOD items and favorites', () async {
      await backend.saveVodItems([vodMap(id: 'v1')]);
      await backend.addVodFavorite('p1', 'v1');

      await backend.clearAll();

      final items = await backend.loadVodItems();
      final favs = await backend.getVodFavorites('p1');
      expect(items, isEmpty);
      expect(favs, isEmpty);
    });
  });
}
