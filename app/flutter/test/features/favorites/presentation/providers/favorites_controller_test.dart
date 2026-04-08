import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:crispy_tivi/features/favorites/presentation/providers/favorites_controller.dart';
import 'package:crispy_tivi/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/channel.dart';
import 'package:crispy_tivi/features/profiles/data/profile_service.dart';

class _FakeProfileService extends ProfileService {
  @override
  Future<ProfileState> build() async =>
      const ProfileState(activeProfileId: 'default');
}

class MockFavoritesRepository implements FavoritesRepository {
  final List<Channel> _favorites = [];
  bool shouldThrow = false;

  @override
  Future<List<Channel>> getFavorites() async {
    if (shouldThrow) throw Exception('Test DB Error');
    return _favorites.toList();
  }

  @override
  Future<void> addFavorite(Channel channel) async {
    if (shouldThrow) throw Exception('Test DB Error');
    _favorites.add(channel.copyWith(isFavorite: true));
  }

  @override
  Future<void> removeFavorite(String channelId) async {
    if (shouldThrow) throw Exception('Test DB Error');
    _favorites.removeWhere((c) => c.id == channelId);
  }

  @override
  Future<bool> isFavorite(String channelId) async {
    if (shouldThrow) throw Exception('Test DB Error');
    return _favorites.any((c) => c.id == channelId);
  }
}

void main() {
  group('FavoritesController', () {
    late ProviderContainer container;
    late MockFavoritesRepository mockRepo;
    late Channel testChannel1;

    setUp(() {
      mockRepo = MockFavoritesRepository();
      container = ProviderContainer(
        overrides: [
          favoritesRepositoryProvider.overrideWithValue(mockRepo),
          profileServiceProvider.overrideWith(() => _FakeProfileService()),
        ],
      );

      testChannel1 = const Channel(
        id: 'ch1',
        name: 'Channel 1',
        streamUrl: 'http://test',
      );
    });

    tearDown(() async {
      // Let pending async rebuilds drain before disposing.
      await Future<void>.delayed(Duration.zero);
      container.dispose();
    });

    test('initial build loads from repo', () async {
      mockRepo._favorites.add(testChannel1);

      final sub = container.listen(
        favoritesControllerProvider,
        (prev, next) {},
      );
      // Wait for profile + favorites to complete
      await container.read(profileServiceProvider.future);
      await container.read(favoritesControllerProvider.future);

      final state = container.read(favoritesControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.value?.length, 1);
      expect(state.value?.first.id, 'ch1');
      sub.close();
    });

    test('toggleFavorite adds then removes', () async {
      await container.read(profileServiceProvider.future);
      await container.read(favoritesControllerProvider.future);
      final notifier = container.read(favoritesControllerProvider.notifier);

      expect(notifier.isFavorite('ch1'), isFalse);

      // Add
      await notifier.toggleFavorite(testChannel1);
      final stateAfterAdd = container.read(favoritesControllerProvider);
      expect(stateAfterAdd.value?.length, 1);
      expect(stateAfterAdd.value?.first.id, 'ch1');
      expect(notifier.isFavorite('ch1'), isTrue);

      // Remove
      await notifier.toggleFavorite(testChannel1);
      final stateAfterRemove = container.read(favoritesControllerProvider);
      expect(stateAfterRemove.value?.length, 0);
      expect(notifier.isFavorite('ch1'), isFalse);
    });

    test('handles errors correctly during toggle', () async {
      await container.read(profileServiceProvider.future);
      await container.read(favoritesControllerProvider.future);
      final notifier = container.read(favoritesControllerProvider.notifier);

      mockRepo.shouldThrow = true;

      await notifier.toggleFavorite(testChannel1);

      final state = container.read(favoritesControllerProvider);
      expect(state.hasError, isTrue);
    });
  });
}
