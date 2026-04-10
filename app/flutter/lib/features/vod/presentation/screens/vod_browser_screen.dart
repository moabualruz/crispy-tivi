import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crispy_tivi/l10n/l10n_extension.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/testing/test_keys.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/screen_template.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../../core/widgets/tv_master_detail_layout.dart';
import '../../../home/presentation/widgets/vod_row.dart';
import '../../domain/entities/vod_item.dart';
import '../providers/vod_providers.dart';
import '../widgets/vod_catalog_browser.dart';
import '../widgets/vod_browser_shell.dart';
import '../widgets/vod_poster_card.dart';
import '../widgets/vod_selection_scope.dart';
import '../widgets/vod_search_sort_bar.dart';

/// VOD movies browser screen backed by paginated VOD providers.
class VodBrowserScreen extends ConsumerWidget {
  const VodBrowserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vodState = ref.watch(vodProvider);
    final movies = ref.watch(filteredMoviesProvider);

    return VodBrowserShell(
      title: context.l10n.vodMovies,
      isLoading: vodState.isLoading,
      error: vodState.error,
      isEmpty: !vodState.isLoading && vodState.error == null && movies.isEmpty,
      emptyIcon: Icons.movie_outlined,
      emptyTitle: context.l10n.vodNoItems,
      emptyDescription: 'Add a playlist source in Settings',
      onRetry: () => ref.read(vodProvider.notifier).refreshFromBackend(),
      child: Scaffold(
        key: TestKeys.vodBrowserScreen,
        appBar: AppBar(
          title: Text(context.l10n.vodMovies),
          actions: [
            IconButton(
              tooltip: context.l10n.homeMyList,
              icon: const Icon(Icons.playlist_add_check_rounded),
              onPressed: () => context.go(AppRoutes.favorites),
            ),
          ],
        ),
        body: ScreenTemplate(
          focusRestorationKey: 'vod-browser',
          compactBody: const _VodMoviesBody(enableTvSelection: false),
          largeBody: const _VodMoviesTvLayout(),
        ),
      ),
    );
  }
}

class _VodMoviesBody extends ConsumerStatefulWidget {
  const _VodMoviesBody({required this.enableTvSelection});

  final bool enableTvSelection;

  @override
  ConsumerState<_VodMoviesBody> createState() => _VodMoviesBodyState();
}

class _VodMoviesBodyState extends ConsumerState<_VodMoviesBody> {
  VodGridDensity _density = VodGridDensity.standard;

  @override
  void initState() {
    super.initState();
    _loadDensity();
  }

  Future<void> _loadDensity() async {
    final notifier = ref.read(settingsNotifierProvider.notifier);
    final raw = await notifier.getVodGridDensity();
    if (!mounted) return;
    final density = VodGridDensity.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => VodGridDensity.standard,
    );
    if (density != _density) {
      setState(() => _density = density);
    }
  }

  void _onDensityChanged(VodGridDensity next) {
    setState(() => _density = next);
    ref.read(settingsNotifierProvider.notifier).setVodGridDensity(next.name);
  }

  Future<void> _onShuffle(List<VodItem> items) async {
    if (!mounted) return;
    if (items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No items to shuffle')));
      return;
    }

    final item = items[math.Random().nextInt(items.length)];
    final tag = '${item.id}_shuffle';
    unawaited(
      context.push(AppRoutes.vodDetails, extra: {'item': item, 'heroTag': tag}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialItems = ref.watch(filteredMoviesProvider);
    return VodCatalogBrowser(
      initialItems: initialItems,
      currentItems: (ref) => ref.watch(filteredMoviesProvider),
      subscribe:
          (ref, onItems) => ref.listenManual(
            filteredMoviesProvider,
            (_, next) => onItems(next),
          ),
      hintText: 'Search movies...',
      loadSortOption: (notifier) => notifier.getVodSortOption(),
      saveSortOption: (notifier, value) => notifier.setVodSortOption(value),
      maxCategories: 30,
      extraSliversBuilder: (context, ref, visibleItems, isSearchOrCategory) {
        final items = List<VodItem>.of(visibleItems);
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                CrispySpacing.md,
                CrispySpacing.sm,
                CrispySpacing.md,
                0,
              ),
              child: Row(
                children: [
                  const Spacer(),
                  Tooltip(
                    message: 'Grid density: ${_density.label}',
                    child: IconButton(
                      icon: Icon(_density.icon),
                      onPressed: () => _onDensityChanged(_density.next),
                    ),
                  ),
                  Tooltip(
                    message: 'Play random item',
                    child: IconButton(
                      icon: const Icon(Icons.shuffle),
                      onPressed: () => _onShuffle(items),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];
      },
      gridBuilder:
          (context, ref, items) => _VodGrid(
            items: items,
            maxExtent: _density.maxCardExtent(MediaQuery.sizeOf(context).width),
            enableTvSelection: widget.enableTvSelection,
          ),
      rowBuilder: (context, ref, category, items) {
        return _VodCategoryRow(
          category: category,
          items: items,
          icon: Icons.local_movies,
        );
      },
    );
  }
}

class _VodMoviesTvLayout extends StatefulWidget {
  const _VodMoviesTvLayout();

  @override
  State<_VodMoviesTvLayout> createState() => _VodMoviesTvLayoutState();
}

class _VodMoviesTvLayoutState extends State<_VodMoviesTvLayout> {
  VodItem? _selectedItem;

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
    context.push(
      AppRoutes.vodDetails,
      extra: {'item': item, 'heroTag': '${item.id}_tv'},
    );
  }

  @override
  Widget build(BuildContext context) {
    return VodSelectionScope(
      onItemSelected: _onItemSelected,
      child: TvMasterDetailLayout(
        showDetail: _selectedItem != null,
        onDetailDismissed: _dismissDetail,
        masterPanel: FocusTraversalGroup(
          child: _VodMoviesBody(enableTvSelection: true),
        ),
        detailPanel: _VodMovieDetailPanel(
          item: _selectedItem,
          onPlay: _navigateToDetail,
        ),
      ),
    );
  }
}

class _VodCategoryRow extends StatelessWidget {
  const _VodCategoryRow({
    required this.category,
    required this.items,
    required this.icon,
  });

  final String category;
  final List<VodItem> items;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return VodRow(
      title: category,
      icon: icon,
      items: items,
      isTitleBadge: true,
    );
  }
}

class _VodGrid extends StatelessWidget {
  const _VodGrid({
    required this.items,
    required this.maxExtent,
    this.enableTvSelection = false,
  });

  final List<VodItem> items;
  final double maxExtent;
  final bool enableTvSelection;

  @override
  Widget build(BuildContext context) {
    final crossSpacing =
        (maxExtent * (CrispyAnimation.hoverScale - 1.0)) + CrispySpacing.xs;
    final mainSpacing =
        (maxExtent * 1.5 * (CrispyAnimation.hoverScale - 1.0)) +
        CrispySpacing.sm;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.md),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxExtent,
          childAspectRatio: 2 / 3,
          mainAxisSpacing: mainSpacing,
          crossAxisSpacing: crossSpacing,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= items.length) {
              return const SizedBox.shrink();
            }
            final item = items[index];
            return VodPosterCard(
              item: item,
              onTap:
                  enableTvSelection
                      ? () => VodSelectionScope.maybeOf(
                        context,
                      )?.onItemSelected(item)
                      : null,
            );
          },
          childCount: items.length,
          semanticIndexCallback: (_, index) => index,
        ),
      ),
    );
  }
}

class _VodMovieDetailPanel extends ConsumerWidget {
  const _VodMovieDetailPanel({required this.item, required this.onPlay});

  final VodItem? item;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item == null) return const SizedBox.shrink();

    final detailAsync = ref.watch(vodDetailProvider(item!));
    final displayItem = detailAsync.asData?.value ?? item!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(CrispySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SmartImage(
                    itemId: displayItem.id,
                    title: displayItem.name,
                    imageUrl: displayItem.posterUrl,
                    imageKind: 'poster',
                    icon: Icons.movie_outlined,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: CrispySpacing.lg),
          Text(
            displayItem.name,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: CrispySpacing.sm),
          Wrap(
            spacing: CrispySpacing.sm,
            children: [
              if (displayItem.year != null)
                Text(
                  '${displayItem.year}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              if (displayItem.category != null)
                Text(
                  displayItem.category!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              if (displayItem.rating != null && displayItem.rating!.isNotEmpty)
                Text(
                  '\u2605 ${displayItem.rating}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              if (displayItem.duration != null && displayItem.duration! > 0)
                Text(
                  '${displayItem.duration} min',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: CrispySpacing.md),
          if (detailAsync.isLoading &&
              (displayItem.description == null ||
                  displayItem.description!.isEmpty))
            const Padding(
              padding: EdgeInsets.only(bottom: CrispySpacing.md),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          if (displayItem.description != null &&
              displayItem.description!.isNotEmpty) ...[
            Text(
              displayItem.description!,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: CrispySpacing.md),
          ],
          if (displayItem.director != null &&
              displayItem.director!.isNotEmpty) ...[
            Text(
              'Director: ${displayItem.director}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: CrispySpacing.xs),
          ],
          if (displayItem.cast != null && displayItem.cast!.isNotEmpty) ...[
            Text(
              'Cast: ${displayItem.cast!.take(3).join(', ')}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
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
              label: const Text('To Movie'),
            ),
          ),
        ],
      ),
    );
  }
}
