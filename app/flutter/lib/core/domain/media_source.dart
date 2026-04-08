import 'entities/media_item.dart';

/// Interface for a media content source (e.g., IPTV playlist, Jellyfin server).
abstract interface class MediaSource {
  /// Unique ID for this source configuration.
  String get id;

  /// User-friendly display name.
  String get displayName;

  /// The type of source.
  MediaServerType get type;

  /// Fetch library items (folders, movies, channels).
  ///
  /// [parentId] - The ID of the parent folder to browse.
  /// If null, returns root libraries/categories.
  ///
  /// [startIndex] - Optional starting index for pagination (0-based).
  /// [limit] - Optional maximum number of items to return.
  ///
  /// For backwards compatibility, pagination parameters are optional.
  /// Implementations may ignore them if pagination is not supported.
  Future<List<MediaItem>> getLibrary(
    String? parentId, {
    int? startIndex,
    int? limit,
  });

  /// Search content in this source.
  ///
  /// [query] - The search query string.
  /// [startIndex] - Optional starting index for pagination.
  /// [limit] - Optional maximum number of results.
  Future<List<MediaItem>> search(String query, {int? startIndex, int? limit});

  /// Resolve the playback URL for a specific item.
  ///
  /// Returns a direct HTTP URL or HLS stream URL.
  Future<String> getStreamUrl(String itemId);
}

enum MediaServerType { jellyfin, emby, plex }

/// Result of a paginated query.
///
/// Contains a list of items along with pagination metadata
/// to support infinite scroll or page-based navigation.
class PaginatedResult<T> {
  const PaginatedResult({
    required this.items,
    required this.totalCount,
    this.startIndex = 0,
    this.limit,
  });

  /// The items in this page of results.
  final List<T> items;

  /// Total number of items available (across all pages).
  final int totalCount;

  /// The starting index of this result set (0-based).
  final int startIndex;

  /// The requested limit (may differ from items.length if fewer available).
  final int? limit;

  /// Whether there are more items available after this page.
  bool get hasMore => startIndex + items.length < totalCount;

  /// The number of items in this result.
  int get count => items.length;

  /// The index of the next item (for loading more).
  int get nextStartIndex => startIndex + items.length;

  /// Creates an empty result.
  static PaginatedResult<T> empty<T>() =>
      PaginatedResult<T>(items: const [], totalCount: 0);
}
