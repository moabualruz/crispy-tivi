import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/data/cache_service.dart';
import '../../../../core/failures/failure.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../profiles/data/profile_service.dart';
import '../../domain/repositories/favorites_repository.dart';

/// Implementation of [FavoritesRepository] using
/// [CacheService].
class FavoritesRepositoryImpl implements FavoritesRepository {
  FavoritesRepositoryImpl(this._cache, this._profiles);

  final CacheService _cache;
  final ProfileService _profiles;

  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  String? get _activeProfileId => _profiles.state.value?.activeProfileId;

  @override
  Future<List<Channel>> getFavorites() async {
    final pid = _activeProfileId;
    if (pid == null) {
      throw const AuthFailure(message: 'No active profile');
    }
    final ids = await _cache.getFavorites(pid);
    if (ids.isEmpty) return const [];

    final channels = await _cache.getChannelsByIds(ids);

    return channels.map((c) => c.copyWith(isFavorite: true)).toList();
  }

  @override
  Future<void> addFavorite(Channel channel) async {
    final pid = _activeProfileId;
    if (pid == null) {
      throw const AuthFailure(message: 'No active profile');
    }
    await _cache.addFavorite(pid, channel.id);
  }

  @override
  Future<void> removeFavorite(String channelId) async {
    final pid = _activeProfileId;
    if (pid == null) {
      throw const AuthFailure(message: 'No active profile');
    }
    await _cache.removeFavorite(pid, channelId);
  }

  @override
  Future<bool> isFavorite(String channelId) async {
    final pid = _activeProfileId;
    if (pid == null) return false;
    final favs = await _cache.getFavorites(pid);
    return favs.contains(channelId);
  }
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final cache = ref.watch(cacheServiceProvider);
  final profiles = ref.watch(profileServiceProvider.notifier);
  return FavoritesRepositoryImpl(cache, profiles);
});
