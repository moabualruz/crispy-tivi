import 'package:flutter/material.dart';

import '../../../home/presentation/widgets/vod_row.dart';
import '../../../vod/domain/entities/vod_item.dart';
import '../../domain/entities/recommendation.dart';

/// Displays a vertical stack of horizontal swimlanes of recommended items.
///
/// Refactored to map all sections within a single widget to
/// fix state loss and disappearance bugs when lists rebuild.
class RecommendationSectionWidget extends StatelessWidget {
  const RecommendationSectionWidget({super.key, required this.sections});

  final List<RecommendationSection> sections;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children:
          sections.map((section) {
            final items = section.items.map(_toVodItem).toList();
            if (items.isEmpty) return const SizedBox.shrink();

            return VodRow(
              key: PageStorageKey(section.title),
              title: section.displayTitle,
              icon: _iconFor(section.reasonType),
              items: items,
              isTitleBadge: true,
            );
          }).toList(),
    );
  }

  VodItem _toVodItem(Recommendation rec) {
    return VodItem(
      id: rec.itemId,
      name: rec.itemName,
      streamUrl: rec.streamUrl ?? '',
      type: VodTypeConversion.fromMediaType(rec.mediaType),
      posterUrl: rec.posterUrl,
      category: rec.category,
      rating: rec.rating,
      year: rec.year,
      seriesId: rec.seriesId,
    );
  }

  static IconData _iconFor(RecommendationReasonType type) {
    switch (type) {
      case RecommendationReasonType.becauseYouWatched:
        return Icons.history;
      case RecommendationReasonType.popularInGenre:
        return Icons.local_fire_department;
      case RecommendationReasonType.trending:
        return Icons.trending_up;
      case RecommendationReasonType.newForYou:
        return Icons.new_releases;
      case RecommendationReasonType.topPick:
        return Icons.auto_awesome;
      case RecommendationReasonType.coldStart:
        return Icons.explore;
    }
  }
}
