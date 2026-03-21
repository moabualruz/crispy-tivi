import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/genre_pill_row.dart';
import '../../../../core/widgets/source_selector_bar.dart';
import '../../../../core/widgets/tv_master_detail_layout.dart';
import '../../../home/presentation/widgets/vod_row.dart';
import '../../domain/entities/vod_item.dart';
import '../providers/vod_providers.dart';
import 'vod_movies_grid.dart';
import 'vod_tv_layout.dart';

/// TV layout for the series browser screen.
///
/// Reuses the same [VodMoviesGrid], [VodRow], and
/// [VodTvSelectionScope] as the movies TV layout so cards
/// look identical and the slide-over detail pane works the
/// same way on both screens.
class SeriesTvLayout extends ConsumerStatefulWidget {
  const SeriesTvLayout({super.key});

  @override
  ConsumerState<SeriesTvLayout> createState() => _SeriesTvLayoutState();
}

class _SeriesTvLayoutState extends ConsumerState<SeriesTvLayout> {
  VodItem? _selectedItem;
  String? _selectedCategory;

  void _onItemSelected(VodItem item) {
    setState(() => _selectedItem = item);
  }

  void _dismissDetail() {
    setState(() => _selectedItem = null);
  }

  void _navigateToDetail() {
    if (_selectedItem == null) return;
    final item = _selectedItem!;
    _dismissDetail();
    context.push(AppRoutes.seriesDetail, extra: item);
  }

  @override
  Widget build(BuildContext context) {
    final allSeries = ref.watch(filteredSeriesProvider);
    final seriesCategories = ref.watch(
      vodProvider.select((s) => s.seriesCategories),
    );
    final isCategory = _selectedCategory != null;
    final filtered =
        isCategory
            ? allSeries.where((s) => s.category == _selectedCategory).toList()
            : allSeries;

    // VodTvSelectionScope lets VodRow and VodMoviesGrid intercept
    // taps to open the slide-over detail pane — same as movies.
    return VodTvSelectionScope(
      onItemSelected: _onItemSelected,
      child: TvMasterDetailLayout(
        showDetail: _selectedItem != null,
        onDetailDismissed: _dismissDetail,
        masterPanel: FocusTraversalGroup(
          child: Column(
            children: [
              const SourceSelectorBar(),
              GenrePillRow(
                categories: seriesCategories,
                selectedCategory: _selectedCategory,
                onCategorySelected: (cat) {
                  setState(() => _selectedCategory = cat);
                },
              ),
              const SizedBox(height: CrispySpacing.sm),
              Expanded(
                child: _buildContent(
                  context,
                  allSeries: allSeries,
                  filtered: filtered,
                  categories: seriesCategories,
                  isCategory: isCategory,
                ),
              ),
            ],
          ),
        ),
        detailPanel: _SeriesDetailPanel(
          item: _selectedItem,
          onPlay: _selectedItem != null ? _navigateToDetail : null,
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required List<VodItem> allSeries,
    required List<VodItem> filtered,
    required List<String> categories,
    required bool isCategory,
  }) {
    if (allSeries.isEmpty) {
      return const Center(child: Text('No series available'));
    }

    // When a genre pill is selected → standard poster grid (same as movies).
    if (isCategory) {
      return CustomScrollView(slivers: [VodMoviesGrid(movies: filtered)]);
    }

    // No category → swimlanes per category (same VodRow as movies).
    final nonEmpty =
        categories
            .where((cat) => allSeries.any((s) => s.category == cat))
            .toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: CrispySpacing.sm),
      itemCount: nonEmpty.length,
      itemBuilder: (context, index) {
        final cat = nonEmpty[index];
        final items = allSeries.where((s) => s.category == cat).toList();
        return VodRow(
          title: cat,
          icon: Icons.tv,
          items: items,
          isTitleBadge: true,
        );
      },
    );
  }
}

/// Detail panel — shared between movies and series could be
/// extracted later, but for now keeps series-specific label.
class _SeriesDetailPanel extends ConsumerWidget {
  const _SeriesDetailPanel({required this.item, required this.onPlay});

  final VodItem? item;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item == null) return const SizedBox.shrink();

    // Trigger on-demand metadata fetch for this series.
    final detailAsync = ref.watch(vodDetailProvider(item!));
    final liveItem = detailAsync.asData?.value ?? item!;

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(CrispySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            liveItem.name,
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: CrispySpacing.sm),
          Wrap(
            spacing: CrispySpacing.sm,
            children: [
              if (liveItem.year != null)
                Text(
                  '${liveItem.year}',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              if (liveItem.category != null)
                Text(
                  liveItem.category!,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              if (liveItem.rating != null && liveItem.rating!.isNotEmpty)
                Text(
                  '\u2605 ${liveItem.rating}',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              if (liveItem.seasonCount != null && liveItem.seasonCount! > 0)
                Text(
                  '${liveItem.seasonCount} season${liveItem.seasonCount! == 1 ? '' : 's'}',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(height: CrispySpacing.md),
          if (liveItem.description != null &&
              liveItem.description!.isNotEmpty) ...[
            Text(
              liveItem.description!,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: CrispySpacing.md),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              autofocus: true,
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow),
              label: const Text('To Series'),
            ),
          ),
        ],
      ),
    );
  }
}
