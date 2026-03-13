import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../../core/widgets/tv_master_detail_layout.dart';
import '../../domain/entities/vod_item.dart';
import '../providers/vod_providers.dart';

/// TV layout for the series browser screen.
///
/// Uses [TvMasterDetailLayout] with a series grid on the left
/// and a detail preview of the selected series on the right.
class SeriesTvLayout extends ConsumerStatefulWidget {
  /// Creates a TV layout for the series browser.
  const SeriesTvLayout({super.key});

  @override
  ConsumerState<SeriesTvLayout> createState() => _SeriesTvLayoutState();
}

class _SeriesTvLayoutState extends ConsumerState<SeriesTvLayout> {
  VodItem? _selectedItem;

  @override
  Widget build(BuildContext context) {
    final allSeries = ref.watch(filteredSeriesProvider);

    return TvMasterDetailLayout(
      masterPanel: _SeriesMasterPanel(
        series: allSeries,
        selectedItem: _selectedItem,
        onItemFocused: (item) => setState(() => _selectedItem = item),
        onItemSelected: (item) {
          context.push(AppRoutes.seriesDetail, extra: item);
        },
      ),
      detailPanel: _SeriesDetailPanel(item: _selectedItem),
    );
  }
}

/// Left panel: scrollable grid of series items.
class _SeriesMasterPanel extends StatelessWidget {
  const _SeriesMasterPanel({
    required this.series,
    required this.selectedItem,
    required this.onItemFocused,
    required this.onItemSelected,
  });

  final List<VodItem> series;
  final VodItem? selectedItem;
  final ValueChanged<VodItem> onItemFocused;
  final ValueChanged<VodItem> onItemSelected;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return const Center(child: Text('No series available'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(CrispySpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: CrispySpacing.sm,
        mainAxisSpacing: CrispySpacing.sm,
      ),
      itemCount: series.length,
      itemBuilder: (context, index) {
        final item = series[index];
        final isSelected = item.id == selectedItem?.id;

        return Focus(
          onFocusChange: (hasFocus) {
            if (hasFocus) onItemFocused(item);
          },
          child: GestureDetector(
            onTap: () => onItemSelected(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                border:
                    isSelected
                        ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                        : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SmartImage(
                  itemId: item.id,
                  title: item.name,
                  imageUrl: item.posterUrl,
                  imageKind: 'poster',
                  icon: Icons.tv,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Right panel: detail preview of the selected series.
class _SeriesDetailPanel extends StatelessWidget {
  const _SeriesDetailPanel({required this.item});

  final VodItem? item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (item == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tv,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: CrispySpacing.md),
            Text(
              'Select a series',
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(CrispySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SmartImage(
                    itemId: item!.id,
                    title: item!.name,
                    imageUrl: item!.posterUrl,
                    imageKind: 'poster',
                    icon: Icons.tv,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: CrispySpacing.lg),

          // Title
          Text(
            item!.name,
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: CrispySpacing.sm),

          // Metadata
          Row(
            children: [
              if (item!.year != null)
                Padding(
                  padding: const EdgeInsets.only(right: CrispySpacing.sm),
                  child: Text(
                    '${item!.year}',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              if (item!.category != null)
                Text(
                  item!.category!,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(height: CrispySpacing.md),

          // Synopsis
          if (item!.description != null && item!.description!.isNotEmpty)
            Text(
              item!.description!,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }
}
