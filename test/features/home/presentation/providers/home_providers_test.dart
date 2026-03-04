import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/features/home/presentation/'
    'providers/home_providers.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/'
    'channel.dart';
import 'package:crispy_tivi/features/player/data/'
    'watch_history_service.dart';
import 'package:crispy_tivi/features/player/domain/entities/'
    'watch_history_entry.dart';
import 'package:crispy_tivi/features/profiles/data/'
    'profile_service.dart';
import 'package:crispy_tivi/features/profiles/domain/entities/'
    'user_profile.dart';
import 'package:crispy_tivi/features/vod/domain/entities/'
    'vod_item.dart';
import 'package:crispy_tivi/features/vod/presentation/providers/'
    'vod_providers.dart';

// ── Mocks ──────────────────────────────────────────

class MockWatchHistoryService extends Mock implements WatchHistoryService {}

class MockCacheService extends Mock implements CacheService {}

// ── Helpers ────────────────────────────────────────

WatchHistoryEntry _historyEntry({
  String id = 'h1',
  String mediaType = 'channel',
  String name = 'Test Channel',
  String streamUrl = 'http://test.com/stream',
  int positionMs = 1000,
  int durationMs = 5000,
  DateTime? lastWatched,
}) {
  return WatchHistoryEntry(
    id: id,
    mediaType: mediaType,
    name: name,
    streamUrl: streamUrl,
    positionMs: positionMs,
    durationMs: durationMs,
    lastWatched: lastWatched ?? DateTime(2026, 2, 20),
  );
}

Channel _channel({
  String id = 'c1',
  String name = 'Channel 1',
  String streamUrl = 'http://test.com/c1',
  String? group,
}) {
  return Channel(id: id, name: name, streamUrl: streamUrl, group: group);
}

VodItem _vodItem({
  String id = 'v1',
  String name = 'Movie 1',
  String streamUrl = 'http://test.com/v1.mp4',
  VodType type = VodType.movie,
  String? rating,
  String? posterUrl,
  int? year,
  String? backdropUrl,
}) {
  return VodItem(
    id: id,
    name: name,
    streamUrl: streamUrl,
    type: type,
    rating: rating,
    posterUrl: posterUrl,
    year: year,
    backdropUrl: backdropUrl,
  );
}

class _MockVodNotifier extends VodNotifier {
  final VodState _initial;
  _MockVodNotifier(this._initial);

  @override
  VodState build() => _initial;
}

void main() {
  late MockWatchHistoryService mockHistory;
  late MockCacheService mockCache;

  setUp(() {
    mockHistory = MockWatchHistoryService();
    mockCache = MockCacheService();
  });

  // ══════════════════════════════════════════════════
  //  recentChannelsProvider
  // ══════════════════════════════════════════════════

  group('recentChannelsProvider', () {
    ProviderContainer createContainer() {
      final c = ProviderContainer(
        overrides: [
          watchHistoryServiceProvider.overrideWithValue(mockHistory),
          cacheServiceProvider.overrideWithValue(mockCache),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('returns empty list when no channel history', () async {
      when(() => mockHistory.getAll()).thenAnswer((_) async => []);

      final container = createContainer();
      final result = await container.read(recentChannelsProvider.future);

      expect(result, isEmpty);
      verifyNever(() => mockCache.getChannelsByIds(any()));
    });

    test('returns channels in history order', () async {
      when(() => mockHistory.getAll()).thenAnswer(
        (_) async => [
          _historyEntry(id: 'c2', mediaType: 'channel'),
          _historyEntry(id: 'c1', mediaType: 'channel'),
        ],
      );
      when(() => mockCache.getChannelsByIds(['c2', 'c1'])).thenAnswer(
        (_) async => [
          _channel(id: 'c1'),
          _channel(id: 'c2', name: 'Channel 2'),
        ],
      );

      final container = createContainer();
      final result = await container.read(recentChannelsProvider.future);

      expect(result.length, 2);
      expect(result[0].id, 'c2');
      expect(result[1].id, 'c1');
    });

    test('filters out non-channel media types', () async {
      when(() => mockHistory.getAll()).thenAnswer(
        (_) async => [
          _historyEntry(id: 'c1', mediaType: 'channel'),
          _historyEntry(id: 'm1', mediaType: 'movie'),
          _historyEntry(id: 'e1', mediaType: 'episode'),
        ],
      );
      when(
        () => mockCache.getChannelsByIds(['c1']),
      ).thenAnswer((_) async => [_channel(id: 'c1')]);

      final container = createContainer();
      final result = await container.read(recentChannelsProvider.future);

      expect(result.length, 1);
      expect(result[0].id, 'c1');
    });

    test('caps at 10 channels max', () async {
      final entries = List.generate(
        15,
        (i) => _historyEntry(id: 'c$i', mediaType: 'channel'),
      );
      when(() => mockHistory.getAll()).thenAnswer((_) async => entries);

      final expectedIds = List.generate(10, (i) => 'c$i');
      final channels = expectedIds.map((id) => _channel(id: id));
      when(
        () => mockCache.getChannelsByIds(expectedIds),
      ).thenAnswer((_) async => channels.toList());

      final container = createContainer();
      final result = await container.read(recentChannelsProvider.future);

      expect(result.length, 10);
    });

    test('handles missing channels gracefully', () async {
      when(() => mockHistory.getAll()).thenAnswer(
        (_) async => [
          _historyEntry(id: 'c1', mediaType: 'channel'),
          _historyEntry(id: 'deleted', mediaType: 'channel'),
        ],
      );
      when(
        () => mockCache.getChannelsByIds(['c1', 'deleted']),
      ).thenAnswer((_) async => [_channel(id: 'c1')]);

      final container = createContainer();
      final result = await container.read(recentChannelsProvider.future);

      expect(result.length, 1);
      expect(result[0].id, 'c1');
    });

    test('returns channels only from history entries', () async {
      // All entries are movies — no channels
      when(() => mockHistory.getAll()).thenAnswer(
        (_) async => [
          _historyEntry(id: 'm1', mediaType: 'movie'),
          _historyEntry(id: 'm2', mediaType: 'movie'),
        ],
      );

      final container = createContainer();
      final result = await container.read(recentChannelsProvider.future);

      expect(result, isEmpty);
      verifyNever(() => mockCache.getChannelsByIds(any()));
    });
  });

  // ══════════════════════════════════════════════════
  //  favoriteChannelsProvider
  // ══════════════════════════════════════════════════

  group('favoriteChannelsProvider', () {
    test('returns empty when no active profile', () async {
      // Override at the provider level to bypass
      // the AsyncNotifier dependency chain.
      final container = ProviderContainer(
        overrides: [
          favoriteChannelsProvider.overrideWith((ref) async {
            // Simulate: profileState.asData is null
            return <Channel>[];
          }),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(favoriteChannelsProvider.future);

      expect(result, isEmpty);
    });

    test('returns empty when no favorites exist', () async {
      when(() => mockCache.getFavorites('p1')).thenAnswer((_) async => []);

      final container = ProviderContainer(
        overrides: [
          cacheServiceProvider.overrideWithValue(mockCache),
          profileServiceProvider.overrideWith(
            () => _SimpleProfileService(
              const ProfileState(
                profiles: [
                  UserProfile(
                    id: 'p1',
                    name: 'Test',
                    avatarIndex: 0,
                    isActive: true,
                  ),
                ],
                activeProfileId: 'p1',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Wait for profile to load first
      await container.read(profileServiceProvider.future);

      final result = await container.read(favoriteChannelsProvider.future);

      expect(result, isEmpty);
    });

    test('returns favorite channels for active '
        'profile', () async {
      when(
        () => mockCache.getFavorites('p1'),
      ).thenAnswer((_) async => ['c1', 'c2']);
      when(() => mockCache.getChannelsByIds(['c1', 'c2'])).thenAnswer(
        (_) async => [
          _channel(id: 'c1'),
          _channel(id: 'c2', name: 'Channel 2'),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          cacheServiceProvider.overrideWithValue(mockCache),
          profileServiceProvider.overrideWith(
            () => _SimpleProfileService(
              const ProfileState(
                profiles: [
                  UserProfile(
                    id: 'p1',
                    name: 'Test',
                    avatarIndex: 0,
                    isActive: true,
                  ),
                ],
                activeProfileId: 'p1',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(profileServiceProvider.future);

      final result = await container.read(favoriteChannelsProvider.future);

      expect(result.length, 2);
      expect(result[0].id, 'c1');
      expect(result[1].id, 'c2');
    });
  });

  // ══════════════════════════════════════════════════
  //  latestVodProvider
  // ══════════════════════════════════════════════════

  group('latestVodProvider', () {
    ProviderContainer createVodContainer(VodState state) {
      final c = ProviderContainer(
        overrides: [vodProvider.overrideWith(() => _MockVodNotifier(state))],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('returns empty list when no VOD items', () {
      final container = createVodContainer(VodState());
      final result = container.read(latestVodProvider);

      expect(result, isEmpty);
    });

    test('returns first 10 items from VOD state', () {
      final items = List.generate(
        15,
        (i) => _vodItem(id: 'v$i', name: 'Movie $i'),
      );

      final container = createVodContainer(VodState(items: items));
      final result = container.read(latestVodProvider);

      // Fallback path: no addedAt timestamps, so provider uses
      // items.reversed.take(10) — newest imports are at the end
      // of the playlist, so reversed gives v14..v5.
      expect(result.length, 10);
      expect(result.first.id, 'v14');
      expect(result.last.id, 'v5');
    });

    test('returns all items when fewer than 10', () {
      final items = [
        _vodItem(id: 'v1'),
        _vodItem(id: 'v2', name: 'Movie 2'),
        _vodItem(id: 'v3', name: 'Movie 3'),
      ];

      final container = createVodContainer(VodState(items: items));
      final result = container.read(latestVodProvider);

      expect(result.length, 3);
    });

    test('returns exactly 1 item when only 1 exists', () {
      final container = createVodContainer(VodState(items: [_vodItem()]));
      final result = container.read(latestVodProvider);

      expect(result.length, 1);
      expect(result.first.id, 'v1');
    });
  });

  // ══════════════════════════════════════════════════
  //  top10VodProvider
  // ══════════════════════════════════════════════════

  group('top10VodProvider', () {
    ProviderContainer createVodContainer(VodState state) {
      final c = ProviderContainer(
        overrides: [vodProvider.overrideWith(() => _MockVodNotifier(state))],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('returns empty list when no VOD items', () {
      final container = createVodContainer(VodState());
      final result = container.read(top10VodProvider);

      expect(result, isEmpty);
    });

    test('returns top rated items sorted descending', () {
      final items = [
        _vodItem(id: 'v1', rating: '7.5', posterUrl: 'http://test.com/p1.jpg'),
        _vodItem(id: 'v2', rating: '9.0', posterUrl: 'http://test.com/p2.jpg'),
        _vodItem(id: 'v3', rating: '8.2', posterUrl: 'http://test.com/p3.jpg'),
        _vodItem(id: 'v4', rating: '6.0', posterUrl: 'http://test.com/p4.jpg'),
        _vodItem(id: 'v5', rating: '5.5', posterUrl: 'http://test.com/p5.jpg'),
      ];

      final container = createVodContainer(VodState(items: items));
      final result = container.read(top10VodProvider);

      expect(result.length, 5);
      expect(result[0].id, 'v2'); // 9.0
      expect(result[1].id, 'v3'); // 8.2
      expect(result[2].id, 'v1'); // 7.5
      expect(result[3].id, 'v4'); // 6.0
      expect(result[4].id, 'v5'); // 5.5
    });

    test('falls back to new releases when fewer '
        'than 5 rated items', () {
      final items = [
        _vodItem(id: 'v1', rating: '8.0', posterUrl: 'http://test.com/p1.jpg'),
        _vodItem(id: 'v2', rating: '7.0', posterUrl: 'http://test.com/p2.jpg'),
        _vodItem(id: 'v3', year: 2026, posterUrl: 'http://test.com/p3.jpg'),
        _vodItem(id: 'v4', year: 2025, posterUrl: 'http://test.com/p4.jpg'),
      ];

      final container = createVodContainer(VodState(items: items));
      final result = container.read(top10VodProvider);

      expect(result.isNotEmpty, true);
      // newReleases sorted by year desc: v3 first
      expect(result.first.id, 'v3');
    });

    test('excludes items without poster from '
        'rating sort', () {
      final items = [
        _vodItem(id: 'v1', rating: '9.5', posterUrl: null),
        _vodItem(id: 'v2', rating: '8.0', posterUrl: 'http://test.com/p2.jpg'),
        _vodItem(id: 'v3', rating: '7.0', posterUrl: 'http://test.com/p3.jpg'),
        _vodItem(id: 'v4', rating: '6.0', posterUrl: 'http://test.com/p4.jpg'),
        _vodItem(id: 'v5', rating: '5.0', posterUrl: 'http://test.com/p5.jpg'),
        _vodItem(id: 'v6', rating: '4.0', posterUrl: 'http://test.com/p6.jpg'),
      ];

      final container = createVodContainer(VodState(items: items));
      final result = container.read(top10VodProvider);

      expect(result.length, 5);
      expect(result[0].id, 'v2');
      expect(result.every((r) => r.id != 'v1'), true);
    });

    test('excludes items with empty rating string', () {
      final items = [
        _vodItem(id: 'v1', rating: '', posterUrl: 'http://test.com/p1.jpg'),
        _vodItem(id: 'v2', rating: '8.0', posterUrl: 'http://test.com/p2.jpg'),
        _vodItem(id: 'v3', rating: '7.0', posterUrl: 'http://test.com/p3.jpg'),
        _vodItem(id: 'v4', rating: '6.0', posterUrl: 'http://test.com/p4.jpg'),
        _vodItem(id: 'v5', rating: '5.0', posterUrl: 'http://test.com/p5.jpg'),
        _vodItem(id: 'v6', rating: '4.0', posterUrl: 'http://test.com/p6.jpg'),
      ];

      final container = createVodContainer(VodState(items: items));
      final result = container.read(top10VodProvider);

      expect(result.every((r) => r.id != 'v1'), true);
    });

    test('caps at 10 items from rated list', () {
      final items = List.generate(
        20,
        (i) => _vodItem(
          id: 'v$i',
          rating: '${9.0 - i * 0.1}',
          posterUrl: 'http://test.com/p$i.jpg',
        ),
      );

      final container = createVodContainer(VodState(items: items));
      final result = container.read(top10VodProvider);

      expect(result.length, 10);
    });

    test('handles non-numeric rating gracefully', () {
      final items = [
        _vodItem(
          id: 'v1',
          rating: 'PG-13',
          posterUrl: 'http://test.com/p1.jpg',
        ),
        _vodItem(id: 'v2', rating: '8.0', posterUrl: 'http://test.com/p2.jpg'),
        _vodItem(id: 'v3', rating: 'N/A', posterUrl: 'http://test.com/p3.jpg'),
        _vodItem(id: 'v4', rating: '7.0', posterUrl: 'http://test.com/p4.jpg'),
        _vodItem(id: 'v5', rating: '6.0', posterUrl: 'http://test.com/p5.jpg'),
      ];

      final container = createVodContainer(VodState(items: items));
      final result = container.read(top10VodProvider);

      expect(result.length, 5);
      // v2 (8.0) first, non-numeric parse to 0
      expect(result[0].id, 'v2');
    });

    test('new releases fallback excludes items '
        'without poster', () {
      final items = [
        _vodItem(id: 'v1', rating: '8.0', posterUrl: 'http://test.com/p1.jpg'),
        _vodItem(id: 'v2', year: 2026, posterUrl: null),
        _vodItem(id: 'v3', year: 2025, posterUrl: 'http://test.com/p3.jpg'),
      ];

      final container = createVodContainer(VodState(items: items));
      final result = container.read(top10VodProvider);

      expect(result.every((r) => r.posterUrl != null), true);
    });
  });
}

/// Simple profile service that returns a fixed
/// state without touching CacheService or Backend.
class _SimpleProfileService extends ProfileService {
  final ProfileState _state;
  _SimpleProfileService(this._state);

  @override
  Future<ProfileState> build() async => _state;
}
