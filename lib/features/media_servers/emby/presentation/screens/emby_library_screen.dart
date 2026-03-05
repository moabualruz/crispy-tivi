import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crispy_tivi/core/constants.dart';
import 'package:crispy_tivi/core/domain/media_source.dart';
import 'package:crispy_tivi/core/theme/crispy_spacing.dart';
import '../../../shared/presentation/screens/paginated_library_screen.dart';
import '../../../shared/presentation/widgets/media_server_item_card.dart';
import '../providers/emby_providers.dart';

/// Emby library browser screen with sort and filter controls (FE-EB-08).
///
/// Renders a collapsible filter toolbar above the paginated grid.
/// Sort and filter state is held in [embyLibraryFilterProvider] which
/// is scoped to this screen via [NotifierProvider.autoDispose].
class EmbyLibraryScreen extends ConsumerStatefulWidget {
  const EmbyLibraryScreen({
    required this.parentId,
    required this.title,
    super.key,
  });

  final String parentId;
  final String title;

  @override
  ConsumerState<EmbyLibraryScreen> createState() => _EmbyLibraryScreenState();
}

class _EmbyLibraryScreenState extends ConsumerState<EmbyLibraryScreen> {
  /// Whether the filter toolbar is expanded.
  bool _filterExpanded = false;

  @override
  Widget build(BuildContext context) {
    // FE-EB-08
    final filter = ref.watch(embyLibraryFilterProvider);

    return PaginatedMediaLibraryScreen(
      title: widget.title,
      initialDataProvider: embyPaginatedItemsProvider(widget.parentId),
      appBarActions: [
        // FE-EB-08: toggle filter toolbar
        IconButton(
          icon: Icon(
            _filterExpanded
                ? Icons.filter_list_off_outlined
                : Icons.filter_list_outlined,
          ),
          tooltip: _filterExpanded ? 'Hide filters' : 'Sort & Filter',
          onPressed: () => setState(() => _filterExpanded = !_filterExpanded),
        ),
      ],
      // FE-EB-08: inject filter toolbar above the grid when expanded
      headerSliver:
          _filterExpanded
              ? _EmbyFilterToolbar(parentId: widget.parentId)
              : null,
      loadMoreItems: (startIndex) async {
        final source = ref.read(embySourceProvider);
        if (source == null) throw Exception('No Emby source connected');
        final result = await source.getLibraryFiltered(
          widget.parentId,
          startIndex: startIndex,
          limit: kMediaServerPageSize,
          sortBy: filter.sortBy.apiValue,
          sortOrder: filter.ascending ? 'Ascending' : 'Descending',
          genres: filter.genresParam,
          years: filter.yearsParam,
          isHd: filter.hdOnly ? true : null,
          isHdr: filter.hdrOnly ? true : null,
        );
        return result.items;
      },
      itemBuilder:
          (context, item) => MediaServerItemCard(
            item: item,
            serverType: MediaServerType.emby,
            getStreamUrl:
                (itemId) => ref.read(embyStreamUrlProvider(itemId).future),
            heroPrefix: 'emby',
          ),
    );
  }
}

// ── FE-EB-08: Filter toolbar ──────────────────────────────────────────────

/// FE-EB-08: Collapsible toolbar with sort and filter controls.
///
/// Returns a plain [Widget] (not a Sliver) — the caller wraps it in a
/// [SliverToBoxAdapter] via [PaginatedMediaLibraryScreen.headerSliver].
///
/// Shows:
/// - SortBy chips: Name, Date Added, Release Date, Rating
/// - SortOrder toggle: ascending / descending
/// - Filter chips: HD, HDR
/// - "Clear all" button when any filter is active
class _EmbyFilterToolbar extends ConsumerWidget {
  const _EmbyFilterToolbar({required this.parentId});

  final String parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FE-EB-08
    final filter = ref.watch(embyLibraryFilterProvider);
    final notifier = ref.read(embyLibraryFilterProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    final hasActiveFilter =
        filter.sortBy != EmbyLibrarySortBy.name ||
        !filter.ascending ||
        filter.hdOnly ||
        filter.hdrOnly ||
        filter.selectedGenres.isNotEmpty ||
        filter.selectedYears.isNotEmpty;

    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(
        CrispySpacing.md,
        CrispySpacing.sm,
        CrispySpacing.md,
        CrispySpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Sort row ──────────────────────────────────────────
          Row(
            children: [
              Text(
                'Sort:',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: CrispySpacing.sm),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final sort in EmbyLibrarySortBy.values)
                        Padding(
                          padding: const EdgeInsets.only(
                            right: CrispySpacing.xs,
                          ),
                          child: FilterChip(
                            label: Text(sort.label),
                            selected: filter.sortBy == sort,
                            onSelected: (_) => notifier.setSortBy(sort),
                          ),
                        ),
                      // Sort direction toggle
                      IconButton(
                        icon: Icon(
                          filter.ascending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 18,
                        ),
                        tooltip: filter.ascending ? 'Ascending' : 'Descending',
                        onPressed: notifier.toggleSortOrder,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: CrispySpacing.xs),
          // ── Filter row ────────────────────────────────────────
          Row(
            children: [
              Text(
                'Filter:',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: CrispySpacing.sm),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // HD filter chip
                      Padding(
                        padding: const EdgeInsets.only(right: CrispySpacing.xs),
                        child: FilterChip(
                          label: const Text('HD'),
                          selected: filter.hdOnly,
                          onSelected: (_) => notifier.toggleHd(),
                        ),
                      ),
                      // HDR filter chip
                      Padding(
                        padding: const EdgeInsets.only(right: CrispySpacing.xs),
                        child: FilterChip(
                          label: const Text('HDR'),
                          selected: filter.hdrOnly,
                          onSelected: (_) => notifier.toggleHdr(),
                        ),
                      ),
                      // Clear all (visible when any filter is active)
                      if (hasActiveFilter)
                        TextButton.icon(
                          onPressed: notifier.reset,
                          icon: const Icon(Icons.clear_all, size: 16),
                          label: const Text('Clear'),
                          style: TextButton.styleFrom(
                            foregroundColor: cs.onSurfaceVariant,
                            padding: const EdgeInsets.symmetric(
                              horizontal: CrispySpacing.sm,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
