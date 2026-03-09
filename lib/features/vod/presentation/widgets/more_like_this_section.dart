import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/context_menu_builders.dart';
import '../../../../core/widgets/context_menu_panel.dart';
import '../../../../core/widgets/horizontal_scroll_row.dart';
import '../../domain/entities/vod_item.dart';
import '../providers/vod_favorites_provider.dart';
import '../providers/vod_providers.dart';
import 'vod_layout_helpers.dart';
import 'vod_poster_card.dart';

/// "More Like This" horizontal carousel showing
/// series in the same category as [currentSeries].
///
/// Delegates scroll scaffolding to [HorizontalScrollRow].
class MoreLikeThisSection extends ConsumerWidget {
  const MoreLikeThisSection({super.key, required this.currentSeries});

  final VodItem currentSeries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = currentSeries.category;
    if (category == null || category.isEmpty) {
      return const SizedBox.shrink();
    }

    final allSeries = ref.watch(filteredSeriesProvider);
    final similar =
        allSeries
            .where((s) => s.category == category && s.id != currentSeries.id)
            .take(10)
            .toList();

    if (similar.isEmpty) {
      return const SizedBox.shrink();
    }

    final w = MediaQuery.sizeOf(context).width;
    final cardW = vodPosterCardWidth(w);
    final sectionH = vodSectionHeight(w);

    return Padding(
      padding: const EdgeInsets.only(top: CrispySpacing.md),
      child: HorizontalScrollRow<VodItem>(
        items: similar,
        itemWidth: cardW,
        sectionHeight: sectionH,
        headerTitle: 'More Like This',
        itemSpacing: CrispySpacing.xs,
        itemBuilder:
            (ctx, item, _) => VodPosterCard(
              item: item,
              heroTag: '${item.id}_more_like',
              onTap: () => _openDetail(ctx, item),
              onLongPress: () => _showMenu(ctx, ref, item),
            ),
      ),
    );
  }

  void _openDetail(BuildContext ctx, VodItem item) {
    ctx.push(AppRoutes.seriesDetail, extra: item);
  }

  void _showMenu(BuildContext ctx, WidgetRef ref, VodItem item) {
    final cs = Theme.of(ctx).colorScheme;
    final favs = ref.read(vodFavoritesProvider).value ?? {};
    showContextMenuPanel(
      context: ctx,
      sections: buildSeriesContextMenu(
        context: ctx,
        seriesName: item.name,
        isFavorite: favs.contains(item.id),
        colorScheme: cs,
        onToggleFavorite:
            () =>
                ref.read(vodFavoritesProvider.notifier).toggleFavorite(item.id),
        onViewDetails: () => _openDetail(ctx, item),
      ),
    );
  }
}
