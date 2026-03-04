import 'package:flutter/foundation.dart';

import '../../../../core/domain/entities/media_item.dart';

/// Search results grouped by content type.
///
/// Provides easy access to results by category and
/// aggregate statistics.
@immutable
class GroupedSearchResults {
  const GroupedSearchResults({
    this.channels = const [],
    this.movies = const [],
    this.series = const [],
    this.epgPrograms = const [],
    this.mediaServerItems = const [],
  });

  /// IPTV channels matching the search.
  final List<MediaItem> channels;

  /// VOD movies matching the search.
  final List<MediaItem> movies;

  /// VOD series matching the search.
  final List<MediaItem> series;

  /// EPG program titles matching the search.
  final List<MediaItem> epgPrograms;

  /// Media server items (Jellyfin/Emby/Plex) matching the search.
  final List<MediaItem> mediaServerItems;

  /// Whether there are no results in any category.
  bool get isEmpty =>
      channels.isEmpty &&
      movies.isEmpty &&
      series.isEmpty &&
      epgPrograms.isEmpty &&
      mediaServerItems.isEmpty;

  /// Whether there are results in any category.
  bool get isNotEmpty => !isEmpty;

  /// Total number of results across all categories.
  int get totalCount =>
      channels.length +
      movies.length +
      series.length +
      epgPrograms.length +
      mediaServerItems.length;

  /// Number of categories with results.
  int get categoryCount {
    var count = 0;
    if (channels.isNotEmpty) count++;
    if (movies.isNotEmpty) count++;
    if (series.isNotEmpty) count++;
    if (epgPrograms.isNotEmpty) count++;
    if (mediaServerItems.isNotEmpty) count++;
    return count;
  }

  /// Flattened list of all results (for backwards compatibility).
  List<MediaItem> get all => [
    ...channels,
    ...movies,
    ...series,
    ...epgPrograms,
    ...mediaServerItems,
  ];

  GroupedSearchResults copyWith({
    List<MediaItem>? channels,
    List<MediaItem>? movies,
    List<MediaItem>? series,
    List<MediaItem>? epgPrograms,
    List<MediaItem>? mediaServerItems,
  }) {
    return GroupedSearchResults(
      channels: channels ?? this.channels,
      movies: movies ?? this.movies,
      series: series ?? this.series,
      epgPrograms: epgPrograms ?? this.epgPrograms,
      mediaServerItems: mediaServerItems ?? this.mediaServerItems,
    );
  }

  /// Creates an empty result set.
  static const empty = GroupedSearchResults();
}
