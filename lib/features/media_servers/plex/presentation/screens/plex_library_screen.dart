import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crispy_tivi/core/constants.dart';
import 'package:crispy_tivi/core/domain/entities/media_item.dart';
import 'package:crispy_tivi/core/domain/entities/media_type.dart';
import 'package:crispy_tivi/core/domain/media_source.dart';
import 'package:crispy_tivi/core/navigation/app_routes.dart';
import 'package:crispy_tivi/core/theme/crispy_animation.dart';
import 'package:crispy_tivi/core/theme/crispy_radius.dart';
import 'package:crispy_tivi/core/theme/crispy_spacing.dart';
import 'package:crispy_tivi/core/utils/format_utils.dart';
import 'package:crispy_tivi/core/widgets/context_menu_builders.dart';
import 'package:crispy_tivi/core/widgets/context_menu_panel.dart';
import 'package:crispy_tivi/core/widgets/focus_wrapper.dart';
import '../../../shared/presentation/screens/paginated_library_screen.dart';
import '../../../shared/presentation/widgets/watched_indicator.dart';
import '../providers/plex_providers.dart';
import 'plex_home_screen.dart' show PlexCardRatios;

// ── Grid layout constants ─────────────────────────────────────────────

/// Max cell width for portrait poster mode.
const double _kPortraitMaxCrossAxisExtent = 200;

/// Max cell width for landscape thumbnail mode.
const double _kLandscapeMaxCrossAxisExtent = 360;

/// Aspect ratio for landscape thumbnail cells (16:9).
const double _kLandscapeAspectRatio = 16 / 9;

// ── Filter toolbar constants ──────────────────────────────────────────

/// Predefined decade options for the filter toolbar.
// PX-FE-08
const List<String> _kDecadeOptions = [
  '1970s',
  '1980s',
  '1990s',
  '2000s',
  '2010s',
  '2020s',
];

/// Predefined content rating options for the filter toolbar.
// PX-FE-08
const List<String> _kContentRatingOptions = [
  'G',
  'PG',
  'PG-13',
  'R',
  'NC-17',
  'TV-Y',
  'TV-G',
  'TV-PG',
  'TV-14',
  'TV-MA',
];

/// Predefined resolution options for the filter toolbar.
// PX-FE-08
const List<String> _kResolutionOptions = ['4k', '1080', '720', 'sd'];

// ── Screen ────────────────────────────────────────────────────────────

class PlexLibraryScreen extends ConsumerWidget {
  const PlexLibraryScreen({
    required this.libraryId,
    required this.title,
    this.parentTitle,
    this.isChildren = false,
    super.key,
  });

  final String libraryId;
  final String title;

  /// [PX-FE-BREAD] Title of the immediate parent (e.g. series name).
  ///
  /// When set, the AppBar title shows a tappable breadcrumb prefix
  /// ("{parentTitle} ›") that pops back one level.
  final String? parentTitle;

  /// When true, uses [plexPaginatedChildrenProvider] for seasons/episodes.
  /// When false, uses [plexPaginatedItemsProvider] for library items.
  final bool isChildren;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // PX-FE-09: read persisted grid mode from provider.
    final gridMode = ref.watch(plexGridModeProvider(libraryId));

    // PX-FE-08: read filter/sort state for this library.
    final filterState = ref.watch(plexLibraryFilterProvider(libraryId));

    final initialProvider =
        isChildren
            ? plexPaginatedChildrenProvider(libraryId)
            : plexPaginatedItemsProvider(libraryId);

    final (double maxExtent, double aspectRatio) = switch (gridMode) {
      PlexGridMode.portrait => (
        _kPortraitMaxCrossAxisExtent,
        PlexCardRatios.itemPoster,
      ),
      PlexGridMode.landscape => (
        _kLandscapeMaxCrossAxisExtent,
        _kLandscapeAspectRatio,
      ),
    };

    return PaginatedMediaLibraryScreen(
      // PX-FE-BREAD: Pass breadcrumb widget as the title widget.
      title: title,
      titleWidget: _PlexBreadcrumbTitle(title: title, parentTitle: parentTitle),
      initialDataProvider: initialProvider,
      childAspectRatio: aspectRatio,
      maxCrossAxisExtent: maxExtent,
      // PX-FE-08: inject filter toolbar above the grid.
      headerSliver:
          isChildren ? null : _PlexFilterToolbar(libraryId: libraryId),
      appBarActions: [
        // PX-FE-09: Toggle poster art mode (portrait ↔ landscape).
        IconButton(
          tooltip:
              gridMode == PlexGridMode.portrait
                  ? 'Switch to landscape view'
                  : 'Switch to portrait view',
          icon: Icon(
            gridMode == PlexGridMode.portrait
                ? Icons.view_agenda_outlined
                : Icons.grid_view,
          ),
          onPressed:
              () => ref.read(plexGridModeProvider(libraryId).notifier).toggle(),
        ),
        // PX-FE-08: filter active indicator badge.
        if (!isChildren && filterState.hasActiveFilters)
          IconButton(
            tooltip: 'Clear filters',
            icon: Badge(
              label: const Text(''),
              child: const Icon(Icons.filter_alt),
            ),
            onPressed:
                () =>
                    ref
                        .read(plexLibraryFilterProvider(libraryId).notifier)
                        .clearFilters(),
          ),
      ],
      loadMoreItems: (startIndex) async {
        final source = ref.read(plexSourceProvider);
        if (source == null) throw Exception('No Plex source connected');

        // PX-FE-08: merge filter query params into the paginated request.
        final extraParams = isChildren ? null : filterState.toQueryParams();

        final result =
            isChildren
                ? await source.getChildrenPaginated(
                  libraryId,
                  startIndex: startIndex,
                  limit: kMediaServerPageSize,
                )
                : await source.getLibraryPaginatedFiltered(
                  libraryId,
                  startIndex: startIndex,
                  limit: kMediaServerPageSize,
                  queryParams: extraParams,
                );
        return result.items;
      },
      // PX-FE-11: pass isChildren flag so episode cards show extra metadata.
      itemBuilder:
          (context, item) =>
              _PlexItemCard(item: item, showEpisodeMeta: isChildren),
    );
  }
}

// ── PX-FE-08: Filter toolbar ─────────────────────────────────────────

/// [PX-FE-08] Collapsible filter and sort toolbar for Plex library screens.
///
/// Appears above the grid as a thin, scrollable chip row. Tapping the
/// expand icon reveals full sort + filter controls. Active filters are
/// highlighted with [ColorScheme.primaryContainer].
// PX-FE-08
class _PlexFilterToolbar extends ConsumerStatefulWidget {
  const _PlexFilterToolbar({required this.libraryId});

  final String libraryId;

  @override
  ConsumerState<_PlexFilterToolbar> createState() => _PlexFilterToolbarState();
}

class _PlexFilterToolbarState extends ConsumerState<_PlexFilterToolbar> {
  // PX-FE-08
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // PX-FE-08
    final state = ref.watch(plexLibraryFilterProvider(widget.libraryId));
    final notifier = ref.read(
      plexLibraryFilterProvider(widget.libraryId).notifier,
    );
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AnimatedSize(
      duration: CrispyAnimation.normal,
      curve: CrispyAnimation.enterCurve,
      child: ColoredBox(
        color: cs.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Collapsed row: sort chips + expand toggle ──────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: CrispySpacing.sm,
                vertical: CrispySpacing.xs,
              ),
              child: Row(
                children: [
                  // PX-FE-08: sort field chips.
                  ...PlexSortField.values.map((field) {
                    final isActive = state.sortField == field;
                    return Padding(
                      padding: const EdgeInsets.only(right: CrispySpacing.xs),
                      child: FilterChip(
                        label: Text(field.label),
                        selected: isActive,
                        onSelected: (_) => notifier.setSort(field),
                        avatar:
                            isActive
                                ? Icon(
                                  state.sortDirection == PlexSortDirection.asc
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  size: 14,
                                )
                                : null,
                        visualDensity: VisualDensity.compact,
                        labelStyle: tt.labelSmall,
                      ),
                    );
                  }),

                  // PX-FE-08: expand / collapse toggle.
                  IconButton(
                    tooltip: _expanded ? 'Collapse filters' : 'Expand filters',
                    iconSize: 20,
                    icon: Icon(
                      _expanded ? Icons.expand_less : Icons.tune,
                      color:
                          state.hasActiveFilters
                              ? cs.primary
                              : cs.onSurfaceVariant,
                    ),
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
                ],
              ),
            ),

            // ── Expanded panel: genre / decade / rating / resolution / HDR ──
            if (_expanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(CrispySpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Decade filter.
                    _FilterSection(
                      label: 'Decade',
                      options: _kDecadeOptions,
                      selected: state.decade,
                      onSelected: notifier.setDecade,
                    ),
                    const SizedBox(height: CrispySpacing.xs),

                    // Content rating filter.
                    _FilterSection(
                      label: 'Rating',
                      options: _kContentRatingOptions,
                      selected: state.contentRating,
                      onSelected: notifier.setContentRating,
                    ),
                    const SizedBox(height: CrispySpacing.xs),

                    // Resolution filter.
                    _FilterSection(
                      label: 'Resolution',
                      options: _kResolutionOptions,
                      selected: state.resolution,
                      onSelected: notifier.setResolution,
                    ),
                    const SizedBox(height: CrispySpacing.xs),

                    // HDR toggle.
                    Row(
                      children: [
                        Text('HDR', style: tt.labelSmall),
                        const SizedBox(width: CrispySpacing.sm),
                        ChoiceChip(
                          label: const Text('Any'),
                          selected: state.hdr == null,
                          onSelected: (_) => notifier.setHdr(null),
                          visualDensity: VisualDensity.compact,
                          labelStyle: tt.labelSmall,
                        ),
                        const SizedBox(width: CrispySpacing.xs),
                        ChoiceChip(
                          label: const Text('HDR'),
                          selected: state.hdr == true,
                          onSelected: (_) => notifier.setHdr(true),
                          visualDensity: VisualDensity.compact,
                          labelStyle: tt.labelSmall,
                        ),
                        const SizedBox(width: CrispySpacing.xs),
                        ChoiceChip(
                          label: const Text('SDR'),
                          selected: state.hdr == false,
                          onSelected: (_) => notifier.setHdr(false),
                          visualDensity: VisualDensity.compact,
                          labelStyle: tt.labelSmall,
                        ),
                        const Spacer(),
                        // PX-FE-08: clear all filters button.
                        if (state.hasActiveFilters)
                          TextButton.icon(
                            onPressed: notifier.clearFilters,
                            icon: const Icon(Icons.clear_all, size: 16),
                            label: const Text('Clear'),
                            style: TextButton.styleFrom(
                              foregroundColor: cs.error,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const Divider(height: 1),
          ],
        ),
      ),
    );
  }
}

/// [PX-FE-08] A horizontal chip row for a single filter dimension.
// PX-FE-08
class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // "All" chip — clears the filter.
                Padding(
                  padding: const EdgeInsets.only(right: CrispySpacing.xs),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: selected == null,
                    onSelected: (_) => onSelected(null),
                    visualDensity: VisualDensity.compact,
                    labelStyle: tt.labelSmall,
                  ),
                ),
                ...options.map((opt) {
                  return Padding(
                    padding: const EdgeInsets.only(right: CrispySpacing.xs),
                    child: ChoiceChip(
                      label: Text(opt),
                      selected: selected == opt,
                      onSelected: (_) {
                        onSelected(selected == opt ? null : opt);
                      },
                      visualDensity: VisualDensity.compact,
                      labelStyle: tt.labelSmall,
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── PX-FE-BREAD: Breadcrumb AppBar title ─────────────────────────────

/// [PX-FE-BREAD] AppBar title widget that shows a tappable breadcrumb prefix.
///
/// When [parentTitle] is set, renders:
///   `{parentTitle} ›  {title}`
/// Tapping the parent prefix pops back one level.
class _PlexBreadcrumbTitle extends StatelessWidget {
  const _PlexBreadcrumbTitle({required this.title, this.parentTitle});

  final String title;
  final String? parentTitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (parentTitle == null) {
      return Text(title, overflow: TextOverflow.ellipsis);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tappable parent segment.
        Flexible(
          child: InkWell(
            borderRadius: BorderRadius.circular(CrispyRadius.tv),
            onTap: () => context.pop(),
            child: Text(
              parentTitle!,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.xs),
          child: Text(
            '›',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        // Current level title.
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Item card ─────────────────────────────────────────────────────────

class _PlexItemCard extends ConsumerWidget {
  const _PlexItemCard({required this.item, this.showEpisodeMeta = false});

  final MediaItem item;

  /// [PX-FE-11] When true, renders episode metadata below the art.
  final bool showEpisodeMeta;

  void _onTap(BuildContext context, WidgetRef ref) {
    if (item.type == MediaType.folder ||
        item.type == MediaType.series ||
        item.type == MediaType.season) {
      context.push(AppRoutes.plexChildren(item.id, title: item.name));
    } else {
      context.push(
        AppRoutes.mediaServerDetails,
        extra: {
          'item': item,
          'serverType': MediaServerType.plex,
          'getStreamUrl':
              (String itemId) => ref.read(plexStreamUrlProvider(itemId).future),
          'heroTag': 'plex_${item.id}',
        },
      );
    }
  }

  void _onLongPress(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPlayable =
        item.type != MediaType.folder &&
        item.type != MediaType.series &&
        item.type != MediaType.season;

    showContextMenuPanel(
      context: context,
      sections: buildMediaServerItemContextMenu(
        itemName: item.name,
        colorScheme: colorScheme,
        isWatched: item.isWatched,
        onPlay: () => _onTap(context, ref),
        onViewDetails: () {
          context.push(
            AppRoutes.mediaServerDetails,
            extra: {
              'item': item,
              'serverType': MediaServerType.plex,
              'getStreamUrl':
                  (String itemId) =>
                      ref.read(plexStreamUrlProvider(itemId).future),
              'heroTag': 'plex_${item.id}',
            },
          );
        },
        // Watchlist requires plex.tv OAuth — stub until cloud auth lands.
        onAddToQueue:
            isPlayable
                ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Watchlist requires Plex cloud sign-in (coming soon)',
                      ),
                    ),
                  );
                }
                : null,
        // Mark as watched: local-only stub until server write API is wired.
        onToggleWatched:
            isPlayable
                ? () {
                  final action = item.isWatched ? 'unwatched' : 'watched';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('"${item.name}" marked as $action')),
                  );
                }
                : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FocusWrapper(
      onSelect: () => _onTap(context, ref),
      onLongPress: () => _onLongPress(context, ref),
      borderRadius: CrispyRadius.md,
      scaleFactor: 1.05,
      padding: EdgeInsets.zero,
      child: GestureDetector(
        onLongPress: () => _onLongPress(context, ref),
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(),
          child:
              showEpisodeMeta
                  // PX-FE-11: Episode children — card stacks art + metadata row.
                  ? _PlexEpisodeCard(item: item)
                  : _PlexPosterStack(item: item),
        ),
      ),
    );
  }
}

// ── PX-FE-11: Episode card ────────────────────────────────────────────

/// [PX-FE-11] Episode card for children views.
///
/// Displays the poster art on top and a metadata row beneath:
/// episode badge (S01E03), air date, runtime, watched checkmark.
class _PlexEpisodeCard extends StatelessWidget {
  const _PlexEpisodeCard({required this.item});

  final MediaItem item;

  /// Formats episode badge from metadata fields `parentIndex` (season)
  /// and `index` (episode) stored by the Plex data layer.
  String? _episodeBadge() {
    final s = item.metadata['parentIndex'];
    final e = item.metadata['index'];
    if (s == null || e == null) return null;
    final sNum = s.toString().padLeft(2, '0');
    final eNum = e.toString().padLeft(2, '0');
    return 'S${sNum}E$eNum';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final badge = _episodeBadge();
    final duration = formatDurationMs(item.durationMs);
    final airDate = item.releaseDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Art (takes available space).
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.logoUrl != null)
                Hero(
                  tag: 'plex_${item.id}',
                  child: Image.network(
                    item.logoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, _, _) =>
                            const Center(child: Icon(Icons.broken_image)),
                  ),
                )
              else
                Center(
                  child: Icon(
                    Icons.movie,
                    size: 48,
                    color: cs.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              WatchedIndicator(
                isWatched: item.isWatched,
                isInProgress: item.isInProgress,
                watchProgress: item.watchProgress,
              ),
              // PX-FE-11: Episode badge (S01E03) in top-left corner.
              if (badge != null)
                Positioned(
                  top: CrispySpacing.xs,
                  left: CrispySpacing.xs,
                  child: _EpisodeBadge(label: badge, cs: cs),
                ),
              // Watched checkmark overlay on top-right.
              if (item.isWatched)
                Positioned(
                  top: CrispySpacing.xs,
                  right: CrispySpacing.xs,
                  child: Icon(Icons.check_circle, size: 18, color: cs.primary),
                ),
            ],
          ),
        ),
        // PX-FE-11: Metadata row — title, air date, runtime.
        ColoredBox(
          color: cs.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CrispySpacing.xs,
              vertical: CrispySpacing.xxs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (airDate != null || duration != null)
                  Text(
                    [
                      if (airDate != null)
                        '${airDate.year}-'
                            '${airDate.month.toString().padLeft(2, '0')}-'
                            '${airDate.day.toString().padLeft(2, '0')}',
                      if (duration != null) duration,
                    ].join('  ·  '),
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Small pill badge for episode identifiers (S01E03).
class _EpisodeBadge extends StatelessWidget {
  const _EpisodeBadge({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CrispySpacing.xs,
          vertical: CrispySpacing.xxs,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: cs.onPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}

// ── Poster-only stack (non-children view) ─────────────────────────────

class _PlexPosterStack extends StatelessWidget {
  const _PlexPosterStack({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (item.logoUrl != null)
          Hero(
            tag: 'plex_${item.id}',
            child: Image.network(
              item.logoUrl!,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, _, _) => const Center(child: Icon(Icons.broken_image)),
            ),
          )
        else
          const Center(child: Icon(Icons.movie, size: 48)),
        WatchedIndicator(
          isWatched: item.isWatched,
          isInProgress: item.isInProgress,
          watchProgress: item.watchProgress,
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: ColoredBox(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.54),
            child: Padding(
              padding: const EdgeInsets.all(CrispySpacing.xs),
              child: Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
