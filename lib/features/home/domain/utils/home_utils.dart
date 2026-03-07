import '../../../vod/domain/entities/vod_item.dart';
import '../../../vod/domain/utils/vod_utils.dart' show kRecentlyAddedDays;

// ── FE-H-05: Dynamic personalized row labels ────────────

/// Returns a rich label string for a home-screen section based on
/// [type] and optional context data.
///
/// Rules:
/// - `'continue_watching'` — appends item count badge when > 0.
/// - `'recently_added'`   — shows "Added this week · N new" when items
///   were added within the last 7 days; falls back to "Latest Added".
/// - `'recommendations'`  — returns the [dynamicTitle] from the
///   [RecommendationSection] (already computed by the engine).
///
/// All other types return [fallback] unchanged.
String dynamicSectionLabel({
  required String type,
  String fallback = '',
  int count = 0,
  List<VodItem>? items,
}) {
  switch (type) {
    case 'continue_watching':
      if (count <= 0) return fallback;
      return '$fallback · $count item${count == 1 ? '' : 's'}';

    case 'recently_added':
      if (items == null || items.isEmpty) return fallback;
      final cutoff = DateTime.now().subtract(
        const Duration(days: kRecentlyAddedDays),
      );
      final recent =
          items
              .where((i) => i.addedAt != null && i.addedAt!.isAfter(cutoff))
              .length;
      if (recent > 0) return 'Added this week · $recent new';
      return fallback;

    default:
      return fallback;
  }
}
