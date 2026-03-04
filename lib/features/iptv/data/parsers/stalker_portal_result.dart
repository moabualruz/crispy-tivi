/// Result from fetching Stalker channels with
/// pagination info.
class StalkerChannelsResult {
  const StalkerChannelsResult({
    required this.channels,
    this.totalItems = 0,
    this.maxPageItems = 25,
  });

  /// Raw channel data from API.
  final List<dynamic> channels;

  /// Total items available.
  final int totalItems;

  /// Items per page.
  final int maxPageItems;

  /// Whether there are more pages.
  bool get hasMorePages => totalItems > 0 && channels.length < totalItems;

  /// Total number of pages.
  int get totalPages =>
      maxPageItems > 0 ? (totalItems / maxPageItems).ceil() : 1;
}

/// Result from fetching Stalker VOD items with
/// pagination info.
class StalkerVodResult {
  const StalkerVodResult({
    required this.items,
    this.totalItems = 0,
    this.maxPageItems = 25,
  });

  /// Raw VOD item data from API.
  final List<dynamic> items;

  /// Total items available.
  final int totalItems;

  /// Items per page.
  final int maxPageItems;

  /// Whether there are more pages.
  bool get hasMorePages => totalItems > 0 && items.length < totalItems;

  /// Total number of pages.
  int get totalPages =>
      maxPageItems > 0 ? (totalItems / maxPageItems).ceil() : 1;
}
