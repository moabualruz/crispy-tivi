import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryBackend backend;

  setUp(() {
    backend = MemoryBackend();
  });

  // ── Lifecycle ───────────────────────────────────

  group('Lifecycle', () {
    test('init completes without error', () async {
      await backend.init('/tmp/test');
    });

    test('version returns memory marker', () {
      expect(backend.version(), '0.0.0-memory');
    });
  });

  // ── Channels ────────────────────────────────────

  group('Channels', () {
    test('loadChannels returns empty initially', () async {
      final result = await backend.loadChannels();
      expect(result, isEmpty);
    });

    test('saveChannels stores and returns count', () async {
      final count = await backend.saveChannels([
        {'id': 'ch1', 'name': 'BBC One'},
        {'id': 'ch2', 'name': 'CNN'},
      ]);
      expect(count, 2);

      final loaded = await backend.loadChannels();
      expect(loaded, hasLength(2));
    });

    test('saveChannels overwrites existing by id', () async {
      await backend.saveChannels([
        {'id': 'ch1', 'name': 'Old Name'},
      ]);
      await backend.saveChannels([
        {'id': 'ch1', 'name': 'New Name'},
      ]);

      final loaded = await backend.loadChannels();
      expect(loaded, hasLength(1));
      expect(loaded.first['name'], 'New Name');
    });

    test('getChannelsByIds returns matching subset', () async {
      await backend.saveChannels([
        {'id': 'a', 'name': 'A'},
        {'id': 'b', 'name': 'B'},
        {'id': 'c', 'name': 'C'},
      ]);

      final result = await backend.getChannelsByIds(['a', 'c']);
      expect(result.map((c) => c['id']).toSet(), {'a', 'c'});
    });

    test('getChannelsByIds returns empty '
        'for empty input', () async {
      await backend.saveChannels([
        {'id': 'a', 'name': 'A'},
      ]);
      final result = await backend.getChannelsByIds([]);
      expect(result, isEmpty);
    });

    test('deleteRemovedChannels removes stale '
        'channels for source', () async {
      await backend.saveChannels([
        {'id': 'keep', 'source_id': 's1'},
        {'id': 'stale', 'source_id': 's1'},
        {'id': 'other', 'source_id': 's2'},
      ]);

      final deleted = await backend.deleteRemovedChannels('s1', ['keep']);
      expect(deleted, 1);

      final remaining = await backend.loadChannels();
      expect(remaining.map((c) => c['id']).toSet(), {'keep', 'other'});
    });

    test('deleteRemovedChannels with empty keep '
        'deletes all for source', () async {
      await backend.saveChannels([
        {'id': 'a', 'source_id': 's1'},
        {'id': 'b', 'source_id': 's1'},
      ]);

      final deleted = await backend.deleteRemovedChannels('s1', []);
      expect(deleted, 2);
      expect(await backend.loadChannels(), isEmpty);
    });
  });

  // ── Channel Favorites ─────────────────────────

  group('Channel Favorites', () {
    test('getFavorites returns empty initially', () async {
      final result = await backend.getFavorites('p1');
      expect(result, isEmpty);
    });

    test('addFavorite then getFavorites', () async {
      await backend.addFavorite('p1', 'ch1');
      await backend.addFavorite('p1', 'ch2');
      final result = await backend.getFavorites('p1');
      expect(result, containsAll(['ch1', 'ch2']));
    });

    test('addFavorite is idempotent (Set)', () async {
      await backend.addFavorite('p1', 'ch1');
      await backend.addFavorite('p1', 'ch1');
      final result = await backend.getFavorites('p1');
      expect(result, hasLength(1));
    });

    test('removeFavorite removes the channel', () async {
      await backend.addFavorite('p1', 'ch1');
      await backend.addFavorite('p1', 'ch2');
      await backend.removeFavorite('p1', 'ch1');

      final result = await backend.getFavorites('p1');
      expect(result, ['ch2']);
    });

    test('removeFavorite on nonexistent is safe', () async {
      await backend.removeFavorite('p1', 'nope');
      final result = await backend.getFavorites('p1');
      expect(result, isEmpty);
    });

    test('favorites are scoped by profile', () async {
      await backend.addFavorite('p1', 'ch1');
      await backend.addFavorite('p2', 'ch2');

      expect(await backend.getFavorites('p1'), ['ch1']);
      expect(await backend.getFavorites('p2'), ['ch2']);
    });
  });

  // ── Categories ────────────────────────────────

  group('Categories', () {
    test('loadCategories returns empty initially', () async {
      final result = await backend.loadCategories();
      expect(result, isEmpty);
    });

    test('saveCategories then loadCategories '
        'round-trips', () async {
      await backend.saveCategories({
        'live': ['Sports', 'News'],
        'vod': ['Action', 'Comedy'],
      });

      final loaded = await backend.loadCategories();
      expect(loaded['live'], ['Sports', 'News']);
      expect(loaded['vod'], ['Action', 'Comedy']);
    });

    test('saveCategories replaces previous data', () async {
      await backend.saveCategories({
        'live': ['Sports'],
      });
      await backend.saveCategories({
        'vod': ['Drama'],
      });

      final loaded = await backend.loadCategories();
      expect(loaded.containsKey('live'), isFalse);
      expect(loaded['vod'], ['Drama']);
    });
  });

  // ── Category Favorites ────────────────────────

  group('Category Favorites', () {
    test('getFavoriteCategories returns empty '
        'initially', () async {
      final result = await backend.getFavoriteCategories('p1', 'live');
      expect(result, isEmpty);
    });

    test('addFavoriteCategory then '
        'getFavoriteCategories', () async {
      await backend.addFavoriteCategory('p1', 'live', 'Sports');
      await backend.addFavoriteCategory('p1', 'live', 'News');
      final result = await backend.getFavoriteCategories('p1', 'live');
      expect(result, containsAll(['Sports', 'News']));
    });

    test('removeFavoriteCategory removes it', () async {
      await backend.addFavoriteCategory('p1', 'live', 'Sports');
      await backend.removeFavoriteCategory('p1', 'live', 'Sports');
      final result = await backend.getFavoriteCategories('p1', 'live');
      expect(result, isEmpty);
    });

    test('categories scoped by profile and type', () async {
      await backend.addFavoriteCategory('p1', 'live', 'Sports');
      await backend.addFavoriteCategory('p1', 'vod', 'Action');
      await backend.addFavoriteCategory('p2', 'live', 'News');

      expect(await backend.getFavoriteCategories('p1', 'live'), ['Sports']);
      expect(await backend.getFavoriteCategories('p1', 'vod'), ['Action']);
      expect(await backend.getFavoriteCategories('p2', 'live'), ['News']);
    });
  });

  // ── Channel Order ─────────────────────────────

  group('Channel Order', () {
    test('loadChannelOrder returns null when '
        'no order set', () async {
      final result = await backend.loadChannelOrder('p1', 'All');
      expect(result, isNull);
    });

    test('saveChannelOrder then loadChannelOrder '
        'returns index map', () async {
      await backend.saveChannelOrder('p1', 'All', ['ch3', 'ch1', 'ch2']);

      final order = await backend.loadChannelOrder('p1', 'All');
      expect(order, isNotNull);
      expect(order!['ch3'], 0);
      expect(order['ch1'], 1);
      expect(order['ch2'], 2);
    });

    test('resetChannelOrder removes order', () async {
      await backend.saveChannelOrder('p1', 'All', ['ch1', 'ch2']);
      await backend.resetChannelOrder('p1', 'All');

      final result = await backend.loadChannelOrder('p1', 'All');
      expect(result, isNull);
    });

    test('orders are scoped by profile+group', () async {
      await backend.saveChannelOrder('p1', 'All', ['ch1']);
      await backend.saveChannelOrder('p1', 'Sports', ['ch2']);
      await backend.saveChannelOrder('p2', 'All', ['ch3']);

      final p1All = await backend.loadChannelOrder('p1', 'All');
      final p1Sports = await backend.loadChannelOrder('p1', 'Sports');
      final p2All = await backend.loadChannelOrder('p2', 'All');

      expect(p1All!.keys, ['ch1']);
      expect(p1Sports!.keys, ['ch2']);
      expect(p2All!.keys, ['ch3']);
    });
  });

  // ── VOD Items ─────────────────────────────────

  group('VOD Items', () {
    test('loadVodItems returns empty initially', () async {
      final result = await backend.loadVodItems();
      expect(result, isEmpty);
    });

    test('saveVodItems stores and returns count', () async {
      final count = await backend.saveVodItems([
        {'id': 'v1', 'name': 'Movie 1'},
        {'id': 'v2', 'name': 'Movie 2'},
      ]);
      expect(count, 2);
    });

    test('saveVodItems overwrites by id', () async {
      await backend.saveVodItems([
        {'id': 'v1', 'name': 'Old'},
      ]);
      await backend.saveVodItems([
        {'id': 'v1', 'name': 'New'},
      ]);

      final loaded = await backend.loadVodItems();
      expect(loaded, hasLength(1));
      expect(loaded.first['name'], 'New');
    });

    test('deleteRemovedVodItems removes stale items', () async {
      await backend.saveVodItems([
        {'id': 'keep', 'source_id': 's1'},
        {'id': 'stale', 'source_id': 's1'},
        {'id': 'other', 'source_id': 's2'},
      ]);

      final deleted = await backend.deleteRemovedVodItems('s1', ['keep']);
      expect(deleted, 1);

      final remaining = await backend.loadVodItems();
      expect(remaining.map((v) => v['id']).toSet(), {'keep', 'other'});
    });
  });

  // ── VOD Favorites ─────────────────────────────

  group('VOD Favorites', () {
    test('getVodFavorites returns empty initially', () async {
      final result = await backend.getVodFavorites('p1');
      expect(result, isEmpty);
    });

    test('addVodFavorite then getVodFavorites', () async {
      await backend.addVodFavorite('p1', 'v1');
      await backend.addVodFavorite('p1', 'v2');
      final result = await backend.getVodFavorites('p1');
      expect(result, containsAll(['v1', 'v2']));
    });

    test('removeVodFavorite removes item', () async {
      await backend.addVodFavorite('p1', 'v1');
      await backend.removeVodFavorite('p1', 'v1');
      final result = await backend.getVodFavorites('p1');
      expect(result, isEmpty);
    });

    test('updateVodFavorite toggles flag', () async {
      await backend.saveVodItems([
        {'id': 'v1', 'is_favorite': false},
      ]);
      await backend.updateVodFavorite('v1', true);

      final loaded = await backend.loadVodItems();
      expect(loaded.first['is_favorite'], isTrue);

      await backend.updateVodFavorite('v1', false);
      final loaded2 = await backend.loadVodItems();
      expect(loaded2.first['is_favorite'], isFalse);
    });

    test('updateVodFavorite on missing item is safe', () async {
      // Should not throw.
      await backend.updateVodFavorite('nope', true);
    });
  });

  // ── EPG ───────────────────────────────────────

  group('EPG', () {
    test('loadEpgEntries returns empty initially', () async {
      final result = await backend.loadEpgEntries();
      expect(result, isEmpty);
    });

    test('saveEpgEntries then loadEpgEntries '
        'round-trips', () async {
      final count = await backend.saveEpgEntries({
        'ch1': [
          {
            'title': 'News',
            'start_time': '2025-01-01T20:00:00Z',
            'end_time': '2025-01-01T21:00:00Z',
          },
        ],
        'ch2': [
          {
            'title': 'Movie',
            'start_time': '2025-01-01T22:00:00Z',
            'end_time': '2025-01-02T00:00:00Z',
          },
        ],
      });
      expect(count, 2);

      final loaded = await backend.loadEpgEntries();
      expect(loaded, contains('ch1'));
      expect(loaded, contains('ch2'));
      expect(loaded['ch1'], hasLength(1));
    });

    test('saveEpgEntries overwrites by channel', () async {
      await backend.saveEpgEntries({
        'ch1': [
          {'title': 'Old'},
        ],
      });
      await backend.saveEpgEntries({
        'ch1': [
          {'title': 'New'},
        ],
      });

      final loaded = await backend.loadEpgEntries();
      expect(loaded['ch1'], hasLength(1));
      expect(loaded['ch1']!.first['title'], 'New');
    });

    test('evictStaleEpg removes old entries', () async {
      final now = DateTime.now().toUtc();
      final old = now.subtract(const Duration(days: 10));
      final fresh = now.add(const Duration(hours: 1));

      await backend.saveEpgEntries({
        'ch1': [
          {'title': 'Stale', 'end_time': old.toIso8601String()},
          {'title': 'Fresh', 'end_time': fresh.toIso8601String()},
        ],
      });

      final evicted = await backend.evictStaleEpg(2);
      expect(evicted, 1);

      final loaded = await backend.loadEpgEntries();
      expect(loaded['ch1'], hasLength(1));
      expect(loaded['ch1']!.first['title'], 'Fresh');
    });

    test('clearEpgEntries removes all', () async {
      await backend.saveEpgEntries({
        'ch1': [
          {'title': 'X'},
        ],
      });
      await backend.clearEpgEntries();

      final loaded = await backend.loadEpgEntries();
      expect(loaded, isEmpty);
    });
  });

  // ── Watch History ─────────────────────────────

  group('Watch History', () {
    test('loadWatchHistory returns empty initially', () async {
      final result = await backend.loadWatchHistory();
      expect(result, isEmpty);
    });

    test('saveWatchHistory then loadWatchHistory', () async {
      await backend.saveWatchHistory({'id': 'wh1', 'name': 'Movie'});

      final loaded = await backend.loadWatchHistory();
      expect(loaded, hasLength(1));
      expect(loaded.first['name'], 'Movie');
    });

    test('saveWatchHistory overwrites by id', () async {
      await backend.saveWatchHistory({'id': 'wh1', 'position_ms': 1000});
      await backend.saveWatchHistory({'id': 'wh1', 'position_ms': 5000});

      final loaded = await backend.loadWatchHistory();
      expect(loaded, hasLength(1));
      expect(loaded.first['position_ms'], 5000);
    });

    test('deleteWatchHistory removes entry', () async {
      await backend.saveWatchHistory({'id': 'wh1'});
      await backend.saveWatchHistory({'id': 'wh2'});
      await backend.deleteWatchHistory('wh1');

      final loaded = await backend.loadWatchHistory();
      expect(loaded, hasLength(1));
      expect(loaded.first['id'], 'wh2');
    });

    test('deleteWatchHistory on nonexistent is safe', () async {
      await backend.deleteWatchHistory('nope');
      expect(await backend.loadWatchHistory(), isEmpty);
    });

    test('clearAllWatchHistory removes all', () async {
      await backend.saveWatchHistory({'id': 'wh1'});
      await backend.saveWatchHistory({'id': 'wh2'});

      final count = await backend.clearAllWatchHistory();
      expect(count, 2);
      expect(await backend.loadWatchHistory(), isEmpty);
    });
  });

  // ── Profiles ──────────────────────────────────

  group('Profiles', () {
    test('loadProfiles returns empty initially', () async {
      final result = await backend.loadProfiles();
      expect(result, isEmpty);
    });

    test('saveProfile then loadProfiles round-trips', () async {
      await backend.saveProfile({
        'id': 'p1',
        'name': 'Alice',
        'avatar_index': 3,
      });

      final loaded = await backend.loadProfiles();
      expect(loaded, hasLength(1));
      expect(loaded.first['name'], 'Alice');
    });

    test('saveProfile overwrites by id', () async {
      await backend.saveProfile({'id': 'p1', 'name': 'Old'});
      await backend.saveProfile({'id': 'p1', 'name': 'New'});

      final loaded = await backend.loadProfiles();
      expect(loaded, hasLength(1));
      expect(loaded.first['name'], 'New');
    });

    test('deleteProfile removes profile', () async {
      await backend.saveProfile({'id': 'p1', 'name': 'A'});
      await backend.saveProfile({'id': 'p2', 'name': 'B'});
      await backend.deleteProfile('p1');

      final loaded = await backend.loadProfiles();
      expect(loaded, hasLength(1));
      expect(loaded.first['id'], 'p2');
    });

    test('deleteProfile cascades favorites and '
        'source access', () async {
      await backend.saveProfile({'id': 'p1', 'name': 'A'});
      await backend.addFavorite('p1', 'ch1');
      await backend.addVodFavorite('p1', 'v1');
      await backend.grantSourceAccess('p1', 's1');

      await backend.deleteProfile('p1');

      expect(await backend.getFavorites('p1'), isEmpty);
      expect(await backend.getVodFavorites('p1'), isEmpty);
      expect(await backend.getSourceAccess('p1'), isEmpty);
    });

    test('deleteProfile on nonexistent is safe', () async {
      await backend.deleteProfile('nope');
    });
  });

  // ── Source Access ──────────────────────────────

  group('Source Access', () {
    test('getSourceAccess returns empty initially', () async {
      final result = await backend.getSourceAccess('p1');
      expect(result, isEmpty);
    });

    test('grantSourceAccess then getSourceAccess', () async {
      await backend.grantSourceAccess('p1', 's1');
      await backend.grantSourceAccess('p1', 's2');

      final result = await backend.getSourceAccess('p1');
      expect(result, containsAll(['s1', 's2']));
    });

    test('grantSourceAccess is idempotent', () async {
      await backend.grantSourceAccess('p1', 's1');
      await backend.grantSourceAccess('p1', 's1');

      final result = await backend.getSourceAccess('p1');
      expect(result, hasLength(1));
    });

    test('revokeSourceAccess removes source', () async {
      await backend.grantSourceAccess('p1', 's1');
      await backend.grantSourceAccess('p1', 's2');
      await backend.revokeSourceAccess('p1', 's1');

      final result = await backend.getSourceAccess('p1');
      expect(result, ['s2']);
    });

    test('setSourceAccess replaces all', () async {
      await backend.grantSourceAccess('p1', 's1');
      await backend.setSourceAccess('p1', ['s2', 's3']);

      final result = await backend.getSourceAccess('p1');
      expect(result, ['s2', 's3']);
    });

    test('getProfilesForSource returns matching '
        'profiles', () async {
      await backend.grantSourceAccess('p1', 's1');
      await backend.grantSourceAccess('p2', 's1');
      await backend.grantSourceAccess('p3', 's2');

      final result = await backend.getProfilesForSource('s1');
      expect(result.toSet(), {'p1', 'p2'});
    });

    test('getProfilesForSource returns empty when '
        'no matches', () async {
      final result = await backend.getProfilesForSource('nope');
      expect(result, isEmpty);
    });
  });

  // ── Settings ──────────────────────────────────

  group('Settings', () {
    test('getSetting returns null for unknown', () async {
      final result = await backend.getSetting('missing');
      expect(result, isNull);
    });

    test('setSetting then getSetting', () async {
      await backend.setSetting('theme', 'dark');
      final result = await backend.getSetting('theme');
      expect(result, 'dark');
    });

    test('setSetting overwrites existing', () async {
      await backend.setSetting('lang', 'en');
      await backend.setSetting('lang', 'fr');
      final result = await backend.getSetting('lang');
      expect(result, 'fr');
    });

    test('removeSetting clears the key', () async {
      await backend.setSetting('key', 'val');
      await backend.removeSetting('key');
      final result = await backend.getSetting('key');
      expect(result, isNull);
    });

    test('removeSetting on nonexistent is safe', () async {
      await backend.removeSetting('nope');
    });
  });

  // ── Sync Metadata ─────────────────────────────

  group('Sync Metadata', () {
    test('getLastSyncTime returns null initially', () async {
      final result = await backend.getLastSyncTime('src1');
      expect(result, isNull);
    });

    test('setLastSyncTime then getLastSyncTime', () async {
      await backend.setLastSyncTime('src1', 1234567890);
      final result = await backend.getLastSyncTime('src1');
      expect(result, 1234567890);
    });

    test('setLastSyncTime overwrites', () async {
      await backend.setLastSyncTime('src1', 100);
      await backend.setLastSyncTime('src1', 200);
      final result = await backend.getLastSyncTime('src1');
      expect(result, 200);
    });
  });

  // ── Image Cache ───────────────────────────────

  group('Image Cache', () {
    test('getCachedImageUrl returns null initially', () async {
      final result = await backend.getCachedImageUrl('item1', 'poster');
      expect(result, isNull);
    });

    test('setCachedImageUrl then getCachedImageUrl', () async {
      await backend.setCachedImageUrl({
        'item_id': 'item1',
        'image_kind': 'poster',
        'image_url': 'http://img.png',
      });

      final result = await backend.getCachedImageUrl('item1', 'poster');
      expect(result, 'http://img.png');
    });

    test('getAllCachedImageUrls filters by kind', () async {
      await backend.setCachedImageUrl({
        'item_id': 'a',
        'image_kind': 'poster',
        'image_url': 'http://a-poster',
      });
      await backend.setCachedImageUrl({
        'item_id': 'b',
        'image_kind': 'poster',
        'image_url': 'http://b-poster',
      });
      await backend.setCachedImageUrl({
        'item_id': 'a',
        'image_kind': 'logo',
        'image_url': 'http://a-logo',
      });

      final posters = await backend.getAllCachedImageUrls('poster');
      expect(posters, hasLength(2));
      expect(posters['a'], 'http://a-poster');
      expect(posters['b'], 'http://b-poster');

      final logos = await backend.getAllCachedImageUrls('logo');
      expect(logos, hasLength(1));
      expect(logos['a'], 'http://a-logo');
    });

    test('removeCachedImage removes entry', () async {
      await backend.setCachedImageUrl({
        'item_id': 'a',
        'image_kind': 'poster',
        'image_url': 'http://a',
      });
      await backend.removeCachedImage('a', 'poster');

      final result = await backend.getCachedImageUrl('a', 'poster');
      expect(result, isNull);
    });

    test('clearImageCache removes all', () async {
      await backend.setCachedImageUrl({
        'item_id': 'a',
        'image_kind': 'poster',
        'image_url': 'http://a',
      });
      await backend.clearImageCache();

      final result = await backend.getCachedImageUrl('a', 'poster');
      expect(result, isNull);
    });
  });

  // ── Recordings ────────────────────────────────

  group('Recordings', () {
    test('loadRecordings returns empty initially', () async {
      final result = await backend.loadRecordings();
      expect(result, isEmpty);
    });

    test('saveRecording then loadRecordings', () async {
      await backend.saveRecording({
        'id': 'rec1',
        'channel_name': 'CNN',
        'program_name': 'News',
      });

      final loaded = await backend.loadRecordings();
      expect(loaded, hasLength(1));
      expect(loaded.first['program_name'], 'News');
    });

    test('updateRecording overwrites by id', () async {
      await backend.saveRecording({'id': 'rec1', 'status': 'scheduled'});
      await backend.updateRecording({'id': 'rec1', 'status': 'recording'});

      final loaded = await backend.loadRecordings();
      expect(loaded.first['status'], 'recording');
    });

    test('deleteRecording removes entry', () async {
      await backend.saveRecording({'id': 'rec1'});
      await backend.saveRecording({'id': 'rec2'});
      await backend.deleteRecording('rec1');

      final loaded = await backend.loadRecordings();
      expect(loaded, hasLength(1));
      expect(loaded.first['id'], 'rec2');
    });

    test('deleteRecording on nonexistent is safe', () async {
      await backend.deleteRecording('nope');
    });
  });

  // ── Storage Backends ──────────────────────────

  group('Storage Backends', () {
    test('loadStorageBackends returns empty initially', () async {
      final result = await backend.loadStorageBackends();
      expect(result, isEmpty);
    });

    test('saveStorageBackend then '
        'loadStorageBackends', () async {
      await backend.saveStorageBackend({
        'id': 'sb1',
        'name': 'My NAS',
        'type': 'smb',
      });

      final loaded = await backend.loadStorageBackends();
      expect(loaded, hasLength(1));
      expect(loaded.first['name'], 'My NAS');
    });

    test('deleteStorageBackend removes entry', () async {
      await backend.saveStorageBackend({'id': 'sb1', 'name': 'A'});
      await backend.saveStorageBackend({'id': 'sb2', 'name': 'B'});
      await backend.deleteStorageBackend('sb1');

      final loaded = await backend.loadStorageBackends();
      expect(loaded, hasLength(1));
      expect(loaded.first['id'], 'sb2');
    });
  });

  // ── Transfer Tasks ────────────────────────────

  group('Transfer Tasks', () {
    test('loadTransferTasks returns empty initially', () async {
      final result = await backend.loadTransferTasks();
      expect(result, isEmpty);
    });

    test('saveTransferTask then loadTransferTasks', () async {
      await backend.saveTransferTask({
        'id': 'tt1',
        'recording_id': 'rec1',
        'status': 'queued',
      });

      final loaded = await backend.loadTransferTasks();
      expect(loaded, hasLength(1));
      expect(loaded.first['status'], 'queued');
    });

    test('updateTransferTask overwrites by id', () async {
      await backend.saveTransferTask({'id': 'tt1', 'status': 'queued'});
      await backend.updateTransferTask({'id': 'tt1', 'status': 'active'});

      final loaded = await backend.loadTransferTasks();
      expect(loaded.first['status'], 'active');
    });

    test('deleteTransferTask removes entry', () async {
      await backend.saveTransferTask({'id': 'tt1'});
      await backend.saveTransferTask({'id': 'tt2'});
      await backend.deleteTransferTask('tt1');

      final loaded = await backend.loadTransferTasks();
      expect(loaded, hasLength(1));
      expect(loaded.first['id'], 'tt2');
    });
  });

  // ── Saved Layouts ─────────────────────────────

  group('Saved Layouts', () {
    test('loadSavedLayouts returns empty initially', () async {
      final result = await backend.loadSavedLayouts();
      expect(result, isEmpty);
    });

    test('saveSavedLayout then loadSavedLayouts', () async {
      await backend.saveSavedLayout({
        'id': 'l1',
        'name': 'My Layout',
        'layout': 'twoByTwo',
      });

      final loaded = await backend.loadSavedLayouts();
      expect(loaded, hasLength(1));
      expect(loaded.first['name'], 'My Layout');
    });

    test('getSavedLayoutById returns matching layout', () async {
      await backend.saveSavedLayout({'id': 'l1', 'name': 'A'});
      await backend.saveSavedLayout({'id': 'l2', 'name': 'B'});

      final result = await backend.getSavedLayoutById('l2');
      expect(result, isNotNull);
      expect(result!['name'], 'B');
    });

    test('getSavedLayoutById returns null for missing', () async {
      final result = await backend.getSavedLayoutById('nope');
      expect(result, isNull);
    });

    test('deleteSavedLayout removes layout', () async {
      await backend.saveSavedLayout({'id': 'l1', 'name': 'A'});
      await backend.deleteSavedLayout('l1');

      final loaded = await backend.loadSavedLayouts();
      expect(loaded, isEmpty);
    });
  });

  // ── Search History ────────────────────────────

  group('Search History', () {
    test('loadSearchHistory returns empty initially', () async {
      final result = await backend.loadSearchHistory();
      expect(result, isEmpty);
    });

    test('saveSearchEntry then loadSearchHistory', () async {
      await backend.saveSearchEntry({
        'id': 's1',
        'query': 'action movies',
        'searched_at': '2025-06-01T00:00:00Z',
      });

      final loaded = await backend.loadSearchHistory();
      expect(loaded, hasLength(1));
      expect(loaded.first['query'], 'action movies');
    });

    test('deleteSearchEntry removes by id', () async {
      await backend.saveSearchEntry({'id': 's1', 'query': 'a'});
      await backend.saveSearchEntry({'id': 's2', 'query': 'b'});
      await backend.deleteSearchEntry('s1');

      final loaded = await backend.loadSearchHistory();
      expect(loaded, hasLength(1));
      expect(loaded.first['id'], 's2');
    });

    test('clearSearchHistory removes all', () async {
      await backend.saveSearchEntry({'id': 's1', 'query': 'a'});
      await backend.saveSearchEntry({'id': 's2', 'query': 'b'});
      await backend.clearSearchHistory();

      final loaded = await backend.loadSearchHistory();
      expect(loaded, isEmpty);
    });

    test('deleteSearchByQuery removes by query '
        '(case insensitive)', () async {
      await backend.saveSearchEntry({'id': 's1', 'query': 'Action Movies'});
      await backend.saveSearchEntry({'id': 's2', 'query': 'action movies'});
      await backend.saveSearchEntry({'id': 's3', 'query': 'comedy'});

      final deleted = await backend.deleteSearchByQuery('Action Movies');
      expect(deleted, 2);

      final loaded = await backend.loadSearchHistory();
      expect(loaded, hasLength(1));
      expect(loaded.first['query'], 'comedy');
    });
  });

  // ── Reminders ─────────────────────────────────

  group('Reminders', () {
    test('loadReminders returns empty initially', () async {
      final result = await backend.loadReminders();
      expect(result, isEmpty);
    });

    test('saveReminder then loadReminders round-trips', () async {
      await backend.saveReminder({
        'id': 'r1',
        'channel_id': 'ch1',
        'program_title': 'Big Game',
        'fired': false,
      });

      final loaded = await backend.loadReminders();
      expect(loaded, hasLength(1));
      expect(loaded.first['program_title'], 'Big Game');
    });

    test('deleteReminder removes entry', () async {
      await backend.saveReminder({'id': 'r1', 'fired': false});
      await backend.saveReminder({'id': 'r2', 'fired': false});
      await backend.deleteReminder('r1');

      final loaded = await backend.loadReminders();
      expect(loaded, hasLength(1));
      expect(loaded.first['id'], 'r2');
    });

    test('markReminderFired sets fired=true', () async {
      await backend.saveReminder({'id': 'r1', 'fired': false});
      await backend.markReminderFired('r1');

      final loaded = await backend.loadReminders();
      expect(loaded.first['fired'], isTrue);
    });

    test('markReminderFired on nonexistent is safe', () async {
      await backend.markReminderFired('nope');
    });

    test('clearFiredReminders removes only fired', () async {
      await backend.saveReminder({'id': 'r1', 'fired': false});
      await backend.saveReminder({'id': 'r2', 'fired': false});
      await backend.markReminderFired('r2');
      await backend.clearFiredReminders();

      final loaded = await backend.loadReminders();
      expect(loaded, hasLength(1));
      expect(loaded.first['id'], 'r1');
    });
  });

  // ── clearAll ──────────────────────────────────

  group('clearAll', () {
    test('removes all data from all stores', () async {
      // Populate multiple stores.
      await backend.saveChannels([
        {'id': 'ch1', 'name': 'A'},
      ]);
      await backend.saveVodItems([
        {'id': 'v1', 'name': 'M'},
      ]);
      await backend.setSetting('k', 'v');
      await backend.saveWatchHistory({'id': 'wh1'});
      await backend.saveProfile({'id': 'p1', 'name': 'A'});
      await backend.addFavorite('p1', 'ch1');
      await backend.addVodFavorite('p1', 'v1');
      await backend.saveEpgEntries({
        'ch1': [
          {'title': 'X'},
        ],
      });
      await backend.saveRecording({'id': 'rec1'});
      await backend.saveStorageBackend({'id': 'sb1', 'name': 'A'});
      await backend.saveSavedLayout({'id': 'l1', 'name': 'A'});
      await backend.saveSearchEntry({'id': 's1', 'query': 'x'});
      await backend.saveReminder({'id': 'r1', 'fired': false});

      await backend.clearAll();

      expect(await backend.loadChannels(), isEmpty);
      expect(await backend.loadVodItems(), isEmpty);
      expect(await backend.getSetting('k'), isNull);
      expect(await backend.loadWatchHistory(), isEmpty);
      expect(await backend.loadProfiles(), isEmpty);
      expect(await backend.getFavorites('p1'), isEmpty);
      expect(await backend.getVodFavorites('p1'), isEmpty);
      expect(await backend.loadEpgEntries(), isEmpty);
      expect(await backend.loadRecordings(), isEmpty);
      expect(await backend.loadStorageBackends(), isEmpty);
      expect(await backend.loadSavedLayouts(), isEmpty);
      expect(await backend.loadSearchHistory(), isEmpty);
      expect(await backend.loadReminders(), isEmpty);
    });
  });
}
