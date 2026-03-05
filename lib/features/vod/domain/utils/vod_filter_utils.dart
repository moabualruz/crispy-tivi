import '../../../parental/domain/content_rating.dart';
import '../entities/vod_item.dart';

/// Filters [items] to only those whose content rating is allowed
/// for the given [maxRating].
///
/// Items with no rating string (or an unrecognised one) parse to
/// [ContentRatingLevel.unrated], which [ContentRatingLevel.isAllowedFor]
/// treats as always-allowed.
///
/// Pure function — no framework imports, no side effects.
List<VodItem> filterByContentRating(
  List<VodItem> items,
  ContentRatingLevel maxRating,
) {
  return items.where((item) {
    final rating = ContentRatingLevel.fromString(item.rating);
    return rating.isAllowedFor(maxRating);
  }).toList();
}
