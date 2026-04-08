import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/failures/failure.dart';
import 'package:crispy_tivi/features/favorites/data/'
    'repositories/favorites_repository_impl.dart';
import 'package:crispy_tivi/features/iptv/domain/'
    'entities/channel.dart';
import 'package:crispy_tivi/features/profiles/data/'
    'profile_service.dart';

class MockCacheService extends Mock implements CacheService {}

class MockProfileService extends Mock implements ProfileService {}

void main() {
  late MockCacheService mockCache;
  late MockProfileService mockProfiles;
  late FavoritesRepositoryImpl repo;

  const activeProfileId = 'profile_1';

  setUpAll(() {
    registerFallbackValue(
      const Channel(id: '_fallback', name: '', streamUrl: ''),
    );
  });

  setUp(() {
    mockCache = MockCacheService();
    mockProfiles = MockProfileService();

    // Default: active profile is set.
    when(() => mockProfiles.state).thenReturn(
      AsyncData(const ProfileState(activeProfileId: activeProfileId)),
    );

    repo = FavoritesRepositoryImpl(mockCache, mockProfiles);
  });

  // ── Helpers ──────────────────────────────────────

  Channel makeChannel(String id) =>
      Channel(id: id, name: 'Channel $id', streamUrl: 'http://example.com/$id');

  void setNoActiveProfile() {
    when(
      () => mockProfiles.state,
    ).thenReturn(const AsyncLoading<ProfileState>());
  }

  // ── getFavorites ─────────────────────────────────

  group('getFavorites', () {
    test('throws AuthFailure when no active profile', () async {
      setNoActiveProfile();

      expect(() => repo.getFavorites(), throwsA(isA<AuthFailure>()));
    });

    test('returns empty list when no favorites exist', () async {
      when(
        () => mockCache.getFavorites(activeProfileId),
      ).thenAnswer((_) async => []);

      final result = await repo.getFavorites();

      expect(result, isEmpty);
    });

    test('returns channels with isFavorite set to true', () async {
      when(
        () => mockCache.getFavorites(activeProfileId),
      ).thenAnswer((_) async => ['ch1', 'ch2']);
      when(
        () => mockCache.getChannelsByIds(['ch1', 'ch2']),
      ).thenAnswer((_) async => [makeChannel('ch1'), makeChannel('ch2')]);

      final channels = await repo.getFavorites();

      expect(channels.length, 2);
      expect(channels.every((c) => c.isFavorite), isTrue);
      expect(channels[0].id, 'ch1');
      expect(channels[1].id, 'ch2');
    });

    test('rethrows when cache throws', () async {
      when(
        () => mockCache.getFavorites(activeProfileId),
      ).thenThrow(Exception('DB error'));

      expect(() => repo.getFavorites(), throwsA(isA<Exception>()));
    });

    test('rethrows when getChannelsByIds throws', () async {
      when(
        () => mockCache.getFavorites(activeProfileId),
      ).thenAnswer((_) async => ['ch1']);
      when(
        () => mockCache.getChannelsByIds(any()),
      ).thenThrow(Exception('Lookup failed'));

      expect(() => repo.getFavorites(), throwsA(isA<Exception>()));
    });
  });

  // ── addFavorite ──────────────────────────────────

  group('addFavorite', () {
    test('throws AuthFailure when no active profile', () async {
      setNoActiveProfile();

      expect(
        () => repo.addFavorite(makeChannel('ch1')),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('delegates to cache with profile and '
        'channel ID', () async {
      when(() => mockCache.addFavorite(any(), any())).thenAnswer((_) async {});

      await repo.addFavorite(makeChannel('ch1'));

      verify(() => mockCache.addFavorite(activeProfileId, 'ch1')).called(1);
    });

    test('rethrows when cache throws', () async {
      when(
        () => mockCache.addFavorite(any(), any()),
      ).thenThrow(Exception('Write failed'));

      expect(
        () => repo.addFavorite(makeChannel('ch1')),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── removeFavorite ───────────────────────────────

  group('removeFavorite', () {
    test('throws AuthFailure when no active profile', () async {
      setNoActiveProfile();

      expect(() => repo.removeFavorite('ch1'), throwsA(isA<AuthFailure>()));
    });

    test('delegates to cache with profile and '
        'channel ID', () async {
      when(
        () => mockCache.removeFavorite(any(), any()),
      ).thenAnswer((_) async {});

      await repo.removeFavorite('ch1');

      verify(() => mockCache.removeFavorite(activeProfileId, 'ch1')).called(1);
    });

    test('rethrows when cache throws', () async {
      when(
        () => mockCache.removeFavorite(any(), any()),
      ).thenThrow(Exception('Delete failed'));

      expect(() => repo.removeFavorite('ch1'), throwsA(isA<Exception>()));
    });
  });

  // ── isFavorite ───────────────────────────────────

  group('isFavorite', () {
    test('returns false when no active profile', () async {
      setNoActiveProfile();

      final result = await repo.isFavorite('ch1');

      expect(result, isFalse);
    });

    test('returns true when channel is in favorites', () async {
      when(
        () => mockCache.getFavorites(activeProfileId),
      ).thenAnswer((_) async => ['ch1', 'ch2', 'ch3']);

      final result = await repo.isFavorite('ch2');

      expect(result, isTrue);
    });

    test('returns false when channel is not in '
        'favorites', () async {
      when(
        () => mockCache.getFavorites(activeProfileId),
      ).thenAnswer((_) async => ['ch1', 'ch3']);

      final result = await repo.isFavorite('ch2');

      expect(result, isFalse);
    });

    test('returns false when favorites list is empty', () async {
      when(
        () => mockCache.getFavorites(activeProfileId),
      ).thenAnswer((_) async => []);

      final result = await repo.isFavorite('ch1');

      expect(result, isFalse);
    });
  });
}
