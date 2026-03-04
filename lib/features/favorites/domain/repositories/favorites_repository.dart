import '../../../../core/failures/failure.dart';
import '../../../iptv/domain/entities/channel.dart';

/// Repository for managing user favorite channels.
abstract class FavoritesRepository {
  /// Get all favorite channels for the current profile.
  ///
  /// Throws [Failure] on error.
  Future<List<Channel>> getFavorites();

  /// Add a channel to favorites.
  ///
  /// Throws [Failure] on error.
  Future<void> addFavorite(Channel channel);

  /// Remove a channel from favorites.
  ///
  /// Throws [Failure] on error.
  Future<void> removeFavorite(String channelId);

  /// Check if a channel is in favorites.
  Future<bool> isFavorite(String channelId);
}
