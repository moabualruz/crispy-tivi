import 'package:flutter/foundation.dart';

/// Kind of result that a search history entry resolved to.
///
/// Used by [RecentSearchesList] (FE-SR-07) to pick the correct
/// thumbnail shape: circle for channels, rounded square for VOD.
enum SearchHistoryResultType {
  /// A live IPTV channel (logo shown in a circle).
  channel,

  /// A VOD movie or series item (poster shown in rounded square).
  vod,

  /// An EPG programme entry.
  epg,
}

/// A persisted search history entry.
///
/// Tracks previous search queries along with when they were
/// performed and how many results were found.
///
/// FE-SR-07: [thumbnailUrl] and [resultType] are optional fields
/// populated when saving from a resolved result so that the history
/// list can show a small thumbnail next to each entry.
@immutable
class SearchHistoryEntry {
  const SearchHistoryEntry({
    required this.id,
    required this.query,
    required this.searchedAt,
    this.resultCount = 0,
    this.thumbnailUrl,
    this.resultType,
  });

  /// Unique identifier for this history entry.
  final String id;

  /// The search query text.
  final String query;

  /// When the search was performed.
  final DateTime searchedAt;

  /// Number of results found (for display).
  final int resultCount;

  /// FE-SR-07: URL of the thumbnail associated with the best match.
  ///
  /// Null when no single best-match result could be identified
  /// (e.g. a generic text search with no dominant result).
  final String? thumbnailUrl;

  /// FE-SR-07: Kind of result [thumbnailUrl] represents.
  ///
  /// Null when [thumbnailUrl] is null.
  final SearchHistoryResultType? resultType;

  /// Creates a new history entry for the current time.
  factory SearchHistoryEntry.create({
    required String query,
    int resultCount = 0,
    String? thumbnailUrl,
    SearchHistoryResultType? resultType,
  }) {
    return SearchHistoryEntry(
      id: 'search_${DateTime.now().millisecondsSinceEpoch}',
      query: query,
      searchedAt: DateTime.now(),
      resultCount: resultCount,
      thumbnailUrl: thumbnailUrl,
      resultType: resultType,
    );
  }

  SearchHistoryEntry copyWith({
    String? id,
    String? query,
    DateTime? searchedAt,
    int? resultCount,
    String? thumbnailUrl,
    SearchHistoryResultType? resultType,
    bool clearThumbnail = false,
  }) {
    return SearchHistoryEntry(
      id: id ?? this.id,
      query: query ?? this.query,
      searchedAt: searchedAt ?? this.searchedAt,
      resultCount: resultCount ?? this.resultCount,
      thumbnailUrl: clearThumbnail ? null : (thumbnailUrl ?? this.thumbnailUrl),
      resultType: clearThumbnail ? null : (resultType ?? this.resultType),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchHistoryEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => Object.hash(runtimeType, id);

  @override
  String toString() => 'SearchHistoryEntry($query)';
}
