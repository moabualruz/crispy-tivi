import '../entities/channel.dart';

/// Repository contract for channel data operations.
///
/// Implemented by infrastructure layer with local storage
/// (ObjectBox) and M3U/Xtream parsers.
abstract interface class ChannelRepository {
  /// Returns all channels from all sources, sorted by number/name.
  Future<List<Channel>> getChannels();

  /// Returns channels filtered by group name.
  Future<List<Channel>> getByGroup(String group);

  /// Returns all unique group names across all sources.
  Future<List<String>> getGroups();

  /// Fuzzy search across channel names and groups.
  Future<List<Channel>> search(String query);

  /// Returns only favorite channels.
  Future<List<Channel>> getFavorites();

  /// Toggles favorite status for a channel.
  Future<Channel> toggleFavorite(String channelId);

  /// Returns a single channel by ID.
  Future<Channel?> getById(String channelId);
}
