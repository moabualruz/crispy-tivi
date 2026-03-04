import '../entities/vod_item.dart';

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
          final ra = double.tryParse(a.rating!) ?? 0;
          final rb = double.tryParse(b.rating!) ?? 0;
          return rb.compareTo(ra);
        });

  if (withRating.length >= minRated) {
    return withRating.take(limit).toList();
  }
  // Fallback: newest items with posters.
  return newReleases.where(hasValidPoster).take(limit).toList();
}
