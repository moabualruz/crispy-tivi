import '../entities/vod_item.dart';

/// Number of days to consider an item "recently added".
const kRecentlyAddedDays = 7;

/// Parse a rating string to a double, returning 0.0 on failure.
///
/// Handles null, empty, and non-numeric strings gracefully.
/// Used by VOD sorting, recommendations, and MemoryBackend mirrors.
double parseRating(String? rating) => double.tryParse(rating ?? '') ?? 0.0;

/// Like [parseRating] but returns [double.nan] on failure — NaN-sort-last
/// sentinel for sort comparators where unrated items must sort after rated.
double parseRatingForSort(String? rating) =>
    double.tryParse(rating ?? '') ?? double.nan;

/// Pure function: filters [items] to those added after the cutoff derived
/// from [now] minus [kRecentlyAddedDays] days, then sorts newest-first.
///
/// The [now] parameter defaults to [DateTime.now] and can be injected in
/// tests for deterministic results.
List<VodItem> filterRecentlyAdded(List<VodItem> items, {DateTime? now}) {
  final cutoff = (now ?? DateTime.now()).subtract(
    const Duration(days: kRecentlyAddedDays),
  );
  return items
      .where((item) => item.addedAt != null && item.addedAt!.isAfter(cutoff))
      .toList()
    ..sort((a, b) => b.addedAt!.compareTo(a.addedAt!));
}

/// Items with a backdrop URL, suitable for a hero banner.
///
/// [limit] controls the maximum number returned (default 10).
List<VodItem> featuredItems(List<VodItem> items, {int limit = 10}) =>
    items
        // Filter by posterUrl (what VodPosterCard renders), not backdropUrl
        // (which is often absent for Xtream VOD movies). This prevents grey
        // placeholder boxes in the hero carousel when backdropUrl is set but
        // posterUrl is missing.
        .where((i) => i.posterUrl != null && i.posterUrl!.isNotEmpty)
        .take(limit)
        .toList();

/// Items sorted by release year descending.
///
/// Items without a year are excluded. [limit] controls the
/// maximum number returned (default 15).
List<VodItem> newReleasesItems(List<VodItem> items, {int limit = 15}) =>
    (items.where((i) => i.year != null).toList()
          ..sort((a, b) => b.year!.compareTo(a.year!)))
        .take(limit)
        .toList();
