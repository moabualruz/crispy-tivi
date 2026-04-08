import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../home/presentation/widgets/vod_row.dart';
import '../../domain/entities/vod_item.dart';

/// T10: Hero/featured section shown at the top of the series browser.
///
/// Displays a horizontally-scrollable row of series with large poster
/// cards. Only the first [_kFeaturedLimit] series from [items] are
/// included, prioritising items that have a backdrop URL.
class SeriesFeaturedBanner extends StatelessWidget {
  const SeriesFeaturedBanner({required this.items, super.key});

  /// All filtered series — a featured subset is derived internally.
  final List<VodItem> items;

  /// Maximum number of series shown in the banner.
  static const int _kFeaturedLimit = 12;

  @override
  Widget build(BuildContext context) {
    // Prefer series with a backdrop; fall back to any series.
    final withBackdrop =
        items
            .where((i) => i.backdropUrl != null && i.backdropUrl!.isNotEmpty)
            .take(_kFeaturedLimit)
            .toList();

    final featured =
        withBackdrop.isNotEmpty
            ? withBackdrop
            : items.take(_kFeaturedLimit).toList();

    if (featured.isEmpty) return const SizedBox.shrink();

    final w = MediaQuery.sizeOf(context).width;
    final cardW =
        w >= Breakpoints.expanded
            ? 260.0
            : (w >= Breakpoints.medium ? 220.0 : 180.0);
    final cardH = cardW * 1.5;
    final hoverScale = CrispyAnimation.hoverScale;
    final hoverPadding = (cardH * hoverScale) - cardH;
    final sectionH = cardH + (CrispySpacing.md * 2) + hoverPadding + 45;

    return VodRow(
      title: 'Featured Series',
      icon: Icons.tv,
      items: featured,
      cardWidth: cardW,
      cardHeight: cardH,
      sectionHeight: sectionH,
      itemSpacing: CrispySpacing.md,
      arrowWidth: 48.0,
      arrowIconSize: 32.0,
    );
  }
}
