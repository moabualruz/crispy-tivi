import 'package:collection/collection.dart' show SetEquality;
import 'package:meta/meta.dart';

/// Types of content that can be searched.
enum SearchContentType { channels, movies, series, epg }

/// Filter configuration for search queries.
///
/// Allows filtering by content type, category, year range,
/// and whether to include description text in search.
@immutable
class SearchFilter {
  const SearchFilter({
    this.contentTypes = const {},
    this.category,
    this.yearMin,
    this.yearMax,
    this.searchInDescription = false,
  });

  /// Content types to include. Empty set means search all types.
  final Set<SearchContentType> contentTypes;

  /// Category/genre filter (null means all categories).
  final String? category;

  /// Minimum year for VOD content.
  final int? yearMin;

  /// Maximum year for VOD content.
  final int? yearMax;

  /// Whether to search in item descriptions.
  final bool searchInDescription;

  /// Whether any filters are active.
  bool get hasActiveFilters =>
      contentTypes.isNotEmpty ||
      category != null ||
      yearMin != null ||
      yearMax != null ||
      searchInDescription;

  /// Whether a specific content type is enabled.
  bool isTypeEnabled(SearchContentType type) {
    // Empty set means all types enabled
    return contentTypes.isEmpty || contentTypes.contains(type);
  }

  SearchFilter copyWith({
    Set<SearchContentType>? contentTypes,
    String? category,
    int? yearMin,
    int? yearMax,
    bool? searchInDescription,
    bool clearCategory = false,
    bool clearYearRange = false,
  }) {
    return SearchFilter(
      contentTypes: contentTypes ?? this.contentTypes,
      category: clearCategory ? null : (category ?? this.category),
      yearMin: clearYearRange ? null : (yearMin ?? this.yearMin),
      yearMax: clearYearRange ? null : (yearMax ?? this.yearMax),
      searchInDescription: searchInDescription ?? this.searchInDescription,
    );
  }

  /// Toggles a content type in the filter.
  SearchFilter toggleContentType(SearchContentType type) {
    final newTypes = Set<SearchContentType>.from(contentTypes);
    if (newTypes.contains(type)) {
      newTypes.remove(type);
    } else {
      newTypes.add(type);
    }
    return copyWith(contentTypes: newTypes);
  }

  /// Clears all filters.
  SearchFilter clear() {
    return const SearchFilter();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchFilter &&
          runtimeType == other.runtimeType &&
          const SetEquality<SearchContentType>().equals(
            contentTypes,
            other.contentTypes,
          ) &&
          category == other.category &&
          yearMin == other.yearMin &&
          yearMax == other.yearMax &&
          searchInDescription == other.searchInDescription;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(contentTypes),
    category,
    yearMin,
    yearMax,
    searchInDescription,
  );
}
