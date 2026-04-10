import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:crispy_tivi/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:crispy_tivi/features/favorites/presentation/providers/favorites_controller.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/channel.dart';
import 'package:crispy_tivi/features/iptv/presentation/providers/channel_providers.dart';
import 'package:crispy_tivi/features/profiles/data/profile_service.dart';
import 'package:crispy_tivi/features/profiles/data/source_access_service.dart';

class _FakeProfileService extends ProfileService {
  @override
  Future<ProfileState> build() async =>
      const ProfileState(activeProfileId: 'default');
}

class _MockFavoritesRepository implements FavoritesRepository {
  _MockFavoritesRepository([List<Channel>? favorites]) {
    if (favorites != null) {
      _favorites.addAll(favorites);
    }
  }

  final List<Channel> _favorites = [];

  @override
  Future<void> addFavorite(Channel channel) async {
    _favorites.add(channel.copyWith(isFavorite: true));
  }

  @override
  Future<List<Channel>> getFavorites() async => _favorites.toList();

  @override
  Future<bool> isFavorite(String channelId) async {
    return _favorites.any((channel) => channel.id == channelId);
  }

  @override
  Future<void> removeFavorite(String channelId) async {
    _favorites.removeWhere((channel) => channel.id == channelId);
  }
}

void main() {
  group('ChannelListNotifier favorites sync', () {
    late ProviderContainer container;
    late _MockFavoritesRepository favoritesRepository;

    const favoriteChannel = Channel(
      id: 'fav-1',
      name: 'Favorite',
      streamUrl: 'http://example.com/favorite',
    );
    const otherChannel = Channel(
      id: 'other-1',
      name: 'Other',
      streamUrl: 'http://example.com/other',
    );

    setUp(() async {
      favoritesRepository = _MockFavoritesRepository([
        favoriteChannel.copyWith(isFavorite: true),
      ]);
      container = ProviderContainer(
        overrides: [
          favoritesRepositoryProvider.overrideWithValue(favoritesRepository),
          profileServiceProvider.overrideWith(_FakeProfileService.new),
          accessibleSourcesProvider.overrideWith((ref) async => null),
        ],
      );

      await container.read(profileServiceProvider.future);
      await container.read(favoritesControllerProvider.future);
      await container.read(accessibleSourcesProvider.future);
      container.read(channelListProvider);
    });

    tearDown(() async {
      await Future<void>.delayed(Duration.zero);
      container.dispose();
    });

    test(
      'loadChannels applies current favorite flags from favorites state',
      () {
        container.read(channelListProvider.notifier).loadChannels(const [
          favoriteChannel,
          otherChannel,
        ], const []);

        final channels = container.read(channelListProvider).channels;
        expect(
          channels
              .firstWhere((channel) => channel.id == favoriteChannel.id)
              .isFavorite,
          isTrue,
        );
        expect(
          channels
              .firstWhere((channel) => channel.id == otherChannel.id)
              .isFavorite,
          isFalse,
        );
      },
    );

    test('favorite updates resync loaded channels', () async {
      container.read(channelListProvider.notifier).loadChannels(const [
        favoriteChannel,
        otherChannel,
      ], const []);

      await container
          .read(favoritesControllerProvider.notifier)
          .toggleFavorite(otherChannel);
      await Future<void>.delayed(Duration.zero);

      final channels = container.read(channelListProvider).channels;
      expect(
        channels
            .firstWhere((channel) => channel.id == favoriteChannel.id)
            .isFavorite,
        isTrue,
      );
      expect(
        channels
            .firstWhere((channel) => channel.id == otherChannel.id)
            .isFavorite,
        isTrue,
      );
    });
  });
}
