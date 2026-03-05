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

/// Returns the video quality label for a [VodItem] ("4K", "HD", or null).
///
/// Inspects the item's [VodItem.extension] field and stream URL for
/// quality keywords. Pure domain logic — no Flutter dependencies.
String? resolveVodQuality(VodItem item) {
  final ext = (item.extension ?? '').toLowerCase();
  final url = item.streamUrl.toLowerCase();

  if (ext.contains('4k') ||
      ext.contains('uhd') ||
      url.contains('4k') ||
      url.contains('uhd')) {
    return '4K';
  }
  if (ext.contains('hd') ||
      ext.contains('720') ||
      ext.contains('1080') ||
      url.contains('1080') ||
      url.contains('720')) {
    return 'HD';
  }
  return null;
}

/// Returns the top-rated [limit] VOD items with poster art from [items].
///
/// Filters for items with a parseable numeric rating and a valid HTTP
/// poster URL, sorts descending by rating. Falls back to [newReleases]
/// (also filtered for HTTP poster URLs) when fewer than [minRated] rated
/// items exist.
///
/// This is pure domain logic — no Flutter or provider dependencies.
List<VodItem> top10Vod(
  List<VodItem> items,
  List<VodItem> newReleases, {
  int minRated = 5,
  int limit = 10,
}) {
  bool hasValidPoster(VodItem i) =>
      i.posterUrl != null &&
      i.posterUrl!.trim().isNotEmpty &&
      i.posterUrl!.startsWith('http');

  final withRating =
      items
          .where(
            (i) =>
                i.rating != null && i.rating!.isNotEmpty && hasValidPoster(i),
          )
          .toList()
        ..sort((a, b) {
          final ra = parseRating(a.rating);
          final rb = parseRating(b.rating);
          return rb.compareTo(ra);
        });

  if (withRating.length >= minRated) {
    return withRating.take(limit).toList();
  }
  // Fallback: newest items with posters.
  return newReleases.where(hasValidPoster).take(limit).toList();
}
