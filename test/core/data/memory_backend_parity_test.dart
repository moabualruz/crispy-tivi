import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';

/// MemoryBackend parity verification.
///
/// Ensures every CrispyBackend method group used in the
/// test suite has a working MemoryBackend implementation
/// (no UnimplementedError, correct CRUD consistency).
///
/// Method groups: lifecycle, sources, channels, VOD items,
/// EPG, watch history, favorites, profiles, settings,
/// categories, sync metadata, AFR, events, app update.
void main() {
  late MemoryBackend backend;

  setUp(() async {
    backend = MemoryBackend();
    await backend.init('');
  });

  // ── Lifecycle ──────────────────────────────────────────
  group('Lifecycle', () {
    test('init completes without error', () async {
      final b = MemoryBackend();
      await expectLater(b.init('test.db'), completes);
    });

    test('version returns a non-empty string', () {
      expect(backend.version(), isA<String>());
      expect(backend.version(), isNotEmpty);
    });

    test('dispose completes without error', () async {
      await expectLater(backend.dispose(), completes);
    });

    test('detectGpu returns valid JSON', () async {
      final gpu = await backend.detectGpu();
      expect(() => jsonDecode(gpu), returnsNormally);
    });

    test('clearAll empties all data', () async {
      await backend.saveChannels([
        {
          'id': 'ch1',
          'name': 'Test',
          'stream_url': 'http://test.com',
          'source_id': 'src1',
        },
      ]);
      final before = await backend.loadChannels();
      expect(before, isNotEmpty);

      await backend.clearAll();
      final after = await backend.loadChannels();
      expect(after, isEmpty);
    });
  });

  // ── Sources ────────────────────────────────────────────
  group('Sources', () {
    test('getSources returns empty list on fresh backend', () async {
      final sources = await backend.getSources();
      expect(sources, isEmpty);
    });

    test('CacheService.getSources returns empty on fresh init', () async {
      final cache = CacheService(backend);
      final sources = await cache.getSources();
      expect(sources, isEmpty);
    });
  });

  // ── Settings ───────────────────────────────────────────
  group('Settings', () {
    test('getSetting returns null for unknown key', () async {
      final val = await backend.getSetting('nonexistent');
      expect(val, isNull);
    });

    test('setSetting + getSetting round-trips value', () async {
      await backend.setSetting('test_key', 'test_value');
      final val = await backend.getSetting('test_key');
      expect(val, equals('test_value'));
    });

    test('removeSetting removes the key', () async {
      await backend.setSetting('del_key', 'value');
      await backend.removeSetting('del_key');
      final val = await backend.getSetting('del_key');
      expect(val, isNull);
    });

    test('CacheService.setSetting + getSetting parity', () async {
      final cache = CacheService(backend);
      await cache.setSetting('cs_key', 'cs_value');
      final val = await cache.getSetting('cs_key');
      expect(val, equals('cs_value'));
    });
  });

  // ── Channels ───────────────────────────────────────────
  group('Channels', () {
    final testChannel = {
      'id': 'ch-1',
      'name': 'Channel One',
      'stream_url': 'http://example.com/live/1',
      'source_id': 'src-1',
      'group': 'News',
      'tvg_id': 'ch1.epg',
    };

    test('saveChannels + loadChannels round-trips', () async {
      await backend.saveChannels([testChannel]);
      final channels = await backend.loadChannels();
      expect(channels, hasLength(1));
      expect(channels.first['id'], equals('ch-1'));
      expect(channels.first['name'], equals('Channel One'));
    });

    test('getChannelsByIds returns matching channels', () async {
      await backend.saveChannels([testChannel]);
      final result = await backend.getChannelsByIds(['ch-1']);
      expect(result, hasLength(1));
      expect(result.first['id'], equals('ch-1'));
    });

    test('getChannelsByIds returns empty for unknown IDs', () async {
      await backend.saveChannels([testChannel]);
      final result = await backend.getChannelsByIds(['unknown']);
      expect(result, isEmpty);
    });

    test('getChannelsBySources filters by source', () async {
      await backend.saveChannels([
        testChannel,
        {
          'id': 'ch-2',
          'name': 'Other',
          'stream_url': 'http://other.com',
          'source_id': 'src-2',
        },
      ]);
      final result = await backend.getChannelsBySources(['src-1']);
      expect(result, hasLength(1));
      expect(result.first['source_id'], equals('src-1'));
    });

    test('deleteRemovedChannels removes unlisted channels', () async {
      await backend.saveChannels([
        testChannel,
        {
          'id': 'ch-2',
          'name': 'Removable',
          'stream_url': 'http://rem.com',
          'source_id': 'src-1',
        },
      ]);
      await backend.deleteRemovedChannels('src-1', ['ch-1']);
      final remaining = await backend.loadChannels();
      expect(remaining, hasLength(1));
      expect(remaining.first['id'], equals('ch-1'));
    });
  });

  // ── Channel Favorites ─────────────────────────────────
  group('Channel Favorites', () {
    test('addFavorite + getFavorites round-trips', () async {
      await backend.addFavorite('profile-1', 'ch-1');
      final favs = await backend.getFavorites('profile-1');
      expect(favs, contains('ch-1'));
    });

    test('removeFavorite removes the favorite', () async {
      await backend.addFavorite('profile-1', 'ch-1');
      await backend.removeFavorite('profile-1', 'ch-1');
      final favs = await backend.getFavorites('profile-1');
      expect(favs, isNot(contains('ch-1')));
    });
  });

  // ── VOD Items ──────────────────────────────────────────
  group('VOD Items', () {
    final testVod = {
      'id': 'vod-1',
      'name': 'Test Movie',
      'stream_url': 'http://example.com/vod/1',
      'type': 'movie',
      'source_id': 'src-1',
    };

    test('saveVodItems + loadVodItems round-trips', () async {
      await backend.saveVodItems([testVod]);
      final items = await backend.loadVodItems();
      expect(items, hasLength(1));
      expect(items.first['id'], equals('vod-1'));
    });

    test('getVodBySources filters by source', () async {
      await backend.saveVodItems([
        testVod,
        {
          'id': 'vod-2',
          'name': 'Other Movie',
          'stream_url': 'http://other.com/vod',
          'type': 'movie',
          'source_id': 'src-2',
        },
      ]);
      final result = await backend.getVodBySources(['src-1']);
      expect(result, hasLength(1));
    });

    test('deleteRemovedVodItems removes unlisted items', () async {
      await backend.saveVodItems([
        testVod,
        {
          'id': 'vod-2',
          'name': 'Removable',
          'stream_url': 'http://rem.com',
          'type': 'movie',
          'source_id': 'src-1',
        },
      ]);
      await backend.deleteRemovedVodItems('src-1', ['vod-1']);
      final remaining = await backend.loadVodItems();
      expect(remaining, hasLength(1));
      expect(remaining.first['id'], equals('vod-1'));
    });
  });

  // ── VOD Favorites ─────────────────────────────────────
  group('VOD Favorites', () {
    test('addVodFavorite + getVodFavorites round-trips', () async {
      await backend.addVodFavorite('profile-1', 'vod-1');
      final favs = await backend.getVodFavorites('profile-1');
      expect(favs, contains('vod-1'));
    });

    test('removeVodFavorite removes the favorite', () async {
      await backend.addVodFavorite('profile-1', 'vod-1');
      await backend.removeVodFavorite('profile-1', 'vod-1');
      final favs = await backend.getVodFavorites('profile-1');
      expect(favs, isNot(contains('vod-1')));
    });
  });

  // ── Watchlist ──────────────────────────────────────────
  group('Watchlist', () {
    test('addWatchlistItem + getWatchlistItems round-trips', () async {
      await backend.saveVodItems([
        {
          'id': 'vod-w1',
          'name': 'Watchlist Movie',
          'stream_url': 'http://ex.com/w',
          'type': 'movie',
          'source_id': 'src-1',
        },
      ]);
      await backend.addWatchlistItem('profile-1', 'vod-w1');
      final items = await backend.getWatchlistItems('profile-1');
      expect(items, isNotEmpty);
    });

    test('removeWatchlistItem removes the item', () async {
      await backend.addWatchlistItem('profile-1', 'vod-w1');
      await backend.removeWatchlistItem('profile-1', 'vod-w1');
      final items = await backend.getWatchlistItems('profile-1');
      expect(items, isEmpty);
    });
  });

  // ── EPG ────────────────────────────────────────────────
  group('EPG', () {
    test('saveEpgEntries + loadEpgEntries round-trips', () async {
      final now = DateTime.now();
      await backend.saveEpgEntries({
        'ch-1': [
          {
            'channel_id': 'ch-1',
            'title': 'News at 6',
            'start': now.toIso8601String(),
            'end': now.add(const Duration(hours: 1)).toIso8601String(),
            'source_id': 'src-1',
          },
        ],
      });
      final entries = await backend.loadEpgEntries();
      expect(entries, isNotEmpty);
      expect(entries['ch-1'], isNotNull);
      expect(entries['ch-1'], hasLength(1));
    });

    test('clearEpgEntries removes all EPG data', () async {
      final now = DateTime.now();
      await backend.saveEpgEntries({
        'ch-1': [
          {
            'channel_id': 'ch-1',
            'title': 'Show',
            'start': now.toIso8601String(),
            'end': now.add(const Duration(hours: 1)).toIso8601String(),
            'source_id': 'src-1',
          },
        ],
      });
      await backend.clearEpgEntries();
      final entries = await backend.loadEpgEntries();
      expect(entries, isEmpty);
    });
  });

  // ── Watch History ──────────────────────────────────────
  group('Watch History', () {
    test('saveWatchHistory + loadWatchHistory round-trips', () async {
      await backend.saveWatchHistory({
        'id': 'wh-1',
        'channel_id': 'ch-1',
        'profile_id': 'profile-1',
        'position_ms': 0,
        'duration_ms': 3600000,
        'watched_at': DateTime.now().toIso8601String(),
        'source_id': 'src-1',
      });
      final history = await backend.loadWatchHistory();
      expect(history, isNotEmpty);
    });
  });

  // ── Profiles ───────────────────────────────────────────
  group('Profiles', () {
    test('saveProfile + loadProfiles round-trips', () async {
      await backend.saveProfile({
        'id': 'p1',
        'name': 'Admin',
        'avatar_index': 0,
      });
      final profiles = await backend.loadProfiles();
      expect(profiles, isNotEmpty);
      expect(profiles.first['id'], equals('p1'));
    });

    test('deleteProfile removes the profile', () async {
      await backend.saveProfile({
        'id': 'p-del',
        'name': 'Delete Me',
        'avatar_index': 0,
      });
      await backend.deleteProfile('p-del');
      final profiles = await backend.loadProfiles();
      final ids = profiles.map((p) => p['id']).toList();
      expect(ids, isNot(contains('p-del')));
    });
  });

  // ── Categories ─────────────────────────────────────────
  group('Categories', () {
    test('saveCategories + loadCategories round-trips', () async {
      await backend.saveCategories({
        'News': ['ch-1', 'ch-2'],
        'Sports': ['ch-3'],
      });
      final cats = await backend.loadCategories();
      expect(cats.keys, containsAll(['News', 'Sports']));
      expect(cats['News'], hasLength(2));
    });
  });

  // ── Sync Metadata ─────────────────────────────────────
  group('Sync Metadata', () {
    test('setLastSyncTime + getLastSyncTime round-trips', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await backend.setLastSyncTime('src-1', now);
      final stored = await backend.getLastSyncTime('src-1');
      expect(stored, equals(now));
    });

    test('getLastSyncTime returns null for unknown source', () async {
      final stored = await backend.getLastSyncTime('unknown');
      expect(stored, isNull);
    });
  });

  // ── AFR / Display ──────────────────────────────────────
  group('AFR / Display', () {
    test('afrSwitchMode returns false (no-op)', () async {
      final result = await backend.afrSwitchMode(60.0);
      expect(result, isFalse);
    });

    test('afrRestoreMode returns false (no-op)', () async {
      final result = await backend.afrRestoreMode();
      expect(result, isFalse);
    });
  });

  // ── Events ─────────────────────────────────────────────
  group('Events', () {
    test('dataEvents stream emits injected events', () async {
      expectLater(backend.dataEvents, emits('{"type":"test"}'));
      backend.emitTestEvent('{"type":"test"}');
    });
  });

  // ── App Update ─────────────────────────────────────────
  group('App Update', () {
    test('checkForUpdate returns no-update JSON', () async {
      final result = await backend.checkForUpdate('0.1.0', 'http://repo');
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['has_update'], isFalse);
    });

    test('getPlatformAssetUrl returns null', () {
      final url = backend.getPlatformAssetUrl('[]', 'windows');
      expect(url, isNull);
    });
  });
}
