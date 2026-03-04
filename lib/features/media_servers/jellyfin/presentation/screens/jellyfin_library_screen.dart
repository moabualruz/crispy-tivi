import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crispy_tivi/core/constants.dart';
import 'package:crispy_tivi/core/domain/entities/media_item.dart';
import 'package:crispy_tivi/core/domain/entities/media_type.dart';
import 'package:crispy_tivi/core/domain/media_source.dart';
import 'package:crispy_tivi/core/navigation/app_routes.dart';
import 'package:crispy_tivi/core/theme/crispy_radius.dart';
import 'package:crispy_tivi/core/theme/crispy_spacing.dart';
import 'package:crispy_tivi/core/utils/format_utils.dart';
import 'package:crispy_tivi/core/widgets/context_menu_builders.dart';
import 'package:crispy_tivi/core/widgets/context_menu_panel.dart';
import '../../../shared/presentation/screens/paginated_library_screen.dart';
import '../../../shared/presentation/widgets/media_server_item_card.dart';
import '../providers/jellyfin_providers.dart';

/// Jellyfin library screen with grid/list view toggle (FE-JF-09) and
/// sort/filter toolbar (FE-JF-08).
///
/// FE-JF-08: Collapsible filter toolbar above the grid with:
///   - Sort: Name, Date Added, Year, Rating, Runtime.
///   - Filter chips: genre list, watched/unwatched toggle, HDR chip.
///   - Local [NotifierProvider] state — not persisted.
///
/// FE-JF-09: Grid/list toggle in the AppBar.
class JellyfinLibraryScreen extends ConsumerStatefulWidget {
  const JellyfinLibraryScreen({
    required this.parentId,
    required this.title,
    super.key,
  });

  final String parentId;
  final String title;

  @override
  ConsumerState<JellyfinLibraryScreen> createState() =>
      _JellyfinLibraryScreenState();
}

class _JellyfinLibraryScreenState extends ConsumerState<JellyfinLibraryScreen> {
  bool _isGrid = true;

  // FE-JF-08: local filter state — managed directly, not through a
  // provider family, to avoid ProviderScope complexity in bottom sheets.
  JellyfinLibraryFilter _filter = const JellyfinLibraryFilter();

  @override
  Widget build(BuildContext context) {
    // FE-JF-08: rebuild when filter changes (setState drives this).
    final filter = _filter;

    return PaginatedMediaLibraryScreen(
      title: widget.title,
      initialDataProvider: jellyfinPaginatedItemsProvider(widget.parentId),
      loadMoreItems: (startIndex) async {
        final source = ref.read(jellyfinSourceProvider);
        if (source == null) throw Exception('No Jellyfin source connected');
        final result = await source.getLibraryFiltered(
          widget.parentId,
          startIndex: startIndex,
          limit: kMediaServerPageSize,
          sortBy: filter.sortField.apiValue,
          sortOrder: filter.sortOrder,
          genres:
              filter.selectedGenres.isNotEmpty
                  ? filter.selectedGenres.join(',')
                  : null,
          isHdr: filter.hdrOnly ? true : null,
        );
        return result.items;
      },
      itemBuilder:
          _isGrid
              ? (context, item) => MediaServerItemCard(
                item: item,
                serverType: MediaServerType.jellyfin,
                getStreamUrl:
                    (itemId) =>
                        ref.read(jellyfinStreamUrlProvider(itemId).future),
                heroPrefix: 'jellyfin',
              )
              : (context, item) => _JellyfinListRow(
                item: item,
                onTap: () => _navigateItem(context, item),
                // JF-FE-10: long-press opens context menu in list mode.
                onLongPress: () => _showItemContextMenu(context, item),
              ),
      childAspectRatio: _isGrid ? 2 / 3 : 6,
      maxCrossAxisExtent: _isGrid ? 200 : 4000,
      appBarActions: [
        // FE-JF-08: sort/filter toggle with active-filter indicator.
        _FilterBadgeButton(
          filter: _filter,
          onTap: () => _showFilterSheet(context),
        ),
        // FE-JF-09: grid/list toggle.
        IconButton(
          tooltip: _isGrid ? 'Switch to list view' : 'Switch to grid view',
          icon: Icon(_isGrid ? Icons.view_list : Icons.grid_view),
          onPressed: () => setState(() => _isGrid = !_isGrid),
        ),
      ],
    );
  }

  // FE-JF-08: Show the sort/filter bottom sheet.
  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet<JellyfinLibraryFilter?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(CrispyRadius.md),
          topRight: Radius.circular(CrispyRadius.md),
        ),
      ),
      builder: (ctx) => _JellyfinFilterSheet(initialFilter: _filter),
    ).then((updatedFilter) {
      if (updatedFilter != null && mounted) {
        setState(() => _filter = updatedFilter);
      }
    });
  }

  /// [JF-FE-10] Long-press context menu for Jellyfin list-row items.
  void _showItemContextMenu(BuildContext context, MediaItem item) {
    final cs = Theme.of(context).colorScheme;
    final isPlayable =
        item.type != MediaType.folder && item.type != MediaType.series;

    void showStub(String message) {
      Navigator.of(context, rootNavigator: true).maybePop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }

    showContextMenuPanel(
      context: context,
      sections: buildMediaServerItemContextMenu(
        itemName: item.name,
        colorScheme: cs,
        isWatched: item.isWatched,
        isFavorite: false,
        onPlay: () => _navigateItem(context, item),
        onViewDetails: () {
          context.push(
            AppRoutes.mediaServerDetails,
            extra: {
              'item': item,
              'serverType': MediaServerType.jellyfin,
              'getStreamUrl':
                  (String itemId) =>
                      ref.read(jellyfinStreamUrlProvider(itemId).future),
              'heroTag': 'jellyfin_${item.id}',
            },
          );
        },
        onToggleWatched:
            isPlayable
                ? () => showStub(
                  '"${item.name}" marked as '
                  '${item.isWatched ? 'unwatched' : 'watched'}',
                )
                : null,
        onToggleFavorite:
            isPlayable
                ? () => showStub('Favorite toggled for "${item.name}"')
                : null,
      ),
    );
  }

  void _navigateItem(BuildContext context, MediaItem item) {
    if (item.type == MediaType.series) {
      // JF-FE-12: Series → dedicated season+episode navigator.
      context.push(AppRoutes.jellyfinSeries(item.id, title: item.name));
    } else if (item.type == MediaType.folder || item.type == MediaType.season) {
      context.push(
        '/jellyfin/library/${item.id}'
        '?title=${Uri.encodeComponent(item.name)}',
      );
    } else {
      context.push(
        AppRoutes.mediaServerDetails,
        extra: {
          'item': item,
          'serverType': MediaServerType.jellyfin,
          'getStreamUrl':
              (String itemId) =>
                  ref.read(jellyfinStreamUrlProvider(itemId).future),
          'heroTag': 'jellyfin_${item.id}',
        },
      );
    }
  }
}

// ── FE-JF-08: Filter badge button ────────────────────────────────────────

/// AppBar action button that shows a dot badge when active filters are set.
class _FilterBadgeButton extends StatelessWidget {
  const _FilterBadgeButton({required this.filter, required this.onTap});

  // FE-JF-08: filter state used to show active-filter dot.
  final JellyfinLibraryFilter filter;
  final VoidCallback onTap;

  bool get _isActive =>
      filter.selectedGenres.isNotEmpty ||
      filter.watchedOnly ||
      filter.unwatchedOnly ||
      filter.hdrOnly ||
      filter.sortField != JellyfinSortField.name;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          tooltip: 'Sort & Filter',
          icon: const Icon(Icons.tune),
          onPressed: onTap,
        ),
        if (_isActive)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

// ── FE-JF-08: Sort/Filter bottom sheet ───────────────────────────────────

/// Bottom sheet for Jellyfin library sort and filter controls.
///
/// Returns the updated [JellyfinLibraryFilter] via [Navigator.pop] when
/// the user taps Apply or resets.
class _JellyfinFilterSheet extends StatefulWidget {
  const _JellyfinFilterSheet({required this.initialFilter});

  final JellyfinLibraryFilter initialFilter;

  @override
  State<_JellyfinFilterSheet> createState() => _JellyfinFilterSheetState();
}

class _JellyfinFilterSheetState extends State<_JellyfinFilterSheet> {
  late JellyfinLibraryFilter _filter;

  // FE-JF-08: well-known genres for the filter chip list.
  static const List<String> _commonGenres = [
    'Action',
    'Adventure',
    'Animation',
    'Comedy',
    'Crime',
    'Documentary',
    'Drama',
    'Fantasy',
    'Horror',
    'Mystery',
    'Romance',
    'Science Fiction',
    'Thriller',
  ];

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  void _setSortField(JellyfinSortField field) {
    setState(() {
      if (_filter.sortField == field) {
        // Toggle sort direction when re-selecting the same field.
        _filter = _filter.copyWith(sortDescending: !_filter.sortDescending);
      } else {
        _filter = _filter.copyWith(sortField: field, sortDescending: false);
      }
    });
  }

  void _toggleGenre(String genre) {
    final genres = Set<String>.from(_filter.selectedGenres);
    if (genres.contains(genre)) {
      genres.remove(genre);
    } else {
      genres.add(genre);
    }
    setState(() => _filter = _filter.copyWith(selectedGenres: genres));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder:
          (ctx, scrollController) => Padding(
            padding: const EdgeInsets.all(CrispySpacing.md),
            child: ListView(
              controller: scrollController,
              children: [
                // ── Header ─────────────────────────────────────
                Row(
                  children: [
                    Text(
                      'Sort & Filter',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        // FE-JF-08: reset all filters.
                        Navigator.of(
                          context,
                        ).pop(const JellyfinLibraryFilter());
                      },
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                const SizedBox(height: CrispySpacing.md),

                // ── Sort ────────────────────────────────────────
                Text(
                  'Sort by',
                  style: tt.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: CrispySpacing.sm),
                Wrap(
                  spacing: CrispySpacing.sm,
                  runSpacing: CrispySpacing.xs,
                  children:
                      JellyfinSortField.values.map((field) {
                        final isSelected = _filter.sortField == field;
                        return FilterChip(
                          // FE-JF-08: sort chip with direction arrow.
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(field.label),
                              if (isSelected) ...[
                                const SizedBox(width: CrispySpacing.xxs),
                                Icon(
                                  _filter.sortDescending
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  size: 14,
                                  color: cs.onSecondaryContainer,
                                ),
                              ],
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (_) => _setSortField(field),
                        );
                      }).toList(),
                ),
                const SizedBox(height: CrispySpacing.lg),

                // ── Status ──────────────────────────────────────
                Text(
                  'Status',
                  style: tt.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: CrispySpacing.sm),
                Wrap(
                  spacing: CrispySpacing.sm,
                  runSpacing: CrispySpacing.xs,
                  children: [
                    // FE-JF-08: watched-only chip.
                    FilterChip(
                      label: const Text('Watched'),
                      selected: _filter.watchedOnly,
                      onSelected:
                          (v) => setState(() {
                            _filter = _filter.copyWith(
                              watchedOnly: v,
                              unwatchedOnly: v ? false : _filter.unwatchedOnly,
                            );
                          }),
                    ),
                    // FE-JF-08: unwatched-only chip.
                    FilterChip(
                      label: const Text('Unwatched'),
                      selected: _filter.unwatchedOnly,
                      onSelected:
                          (v) => setState(() {
                            _filter = _filter.copyWith(
                              unwatchedOnly: v,
                              watchedOnly: v ? false : _filter.watchedOnly,
                            );
                          }),
                    ),
                    // FE-JF-08: HDR chip.
                    FilterChip(
                      label: const Text('HDR'),
                      avatar: const Icon(Icons.hdr_on, size: 16),
                      selected: _filter.hdrOnly,
                      onSelected:
                          (v) => setState(
                            () => _filter = _filter.copyWith(hdrOnly: v),
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: CrispySpacing.lg),

                // ── Genre ───────────────────────────────────────
                Text(
                  'Genre',
                  style: tt.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: CrispySpacing.sm),
                Wrap(
                  spacing: CrispySpacing.sm,
                  runSpacing: CrispySpacing.xs,
                  children:
                      _commonGenres.map((genre) {
                        final isSelected = _filter.selectedGenres.contains(
                          genre,
                        );
                        return FilterChip(
                          // FE-JF-08: genre filter chip.
                          label: Text(genre),
                          selected: isSelected,
                          onSelected: (_) => _toggleGenre(genre),
                        );
                      }).toList(),
                ),
                const SizedBox(height: CrispySpacing.xl),

                // ── Apply ────────────────────────────────────────
                FilledButton(
                  // FE-JF-08: pop with updated filter so screen rebuilds.
                  onPressed: () => Navigator.of(context).pop(_filter),
                  child: const Text('Apply'),
                ),
                const SizedBox(height: CrispySpacing.md),
              ],
            ),
          ),
    );
  }
}

// ── List-row item ─────────────────────────────────────────────────────────

/// Compact list-mode row for a Jellyfin library item.
///
/// Shows: thumbnail poster | title + year + duration.
/// Supports [onLongPress] for the JF-FE-10 context menu.
class _JellyfinListRow extends StatelessWidget {
  const _JellyfinListRow({
    required this.item,
    required this.onTap,
    this.onLongPress,
  });

  final MediaItem item;
  final VoidCallback onTap;

  /// [JF-FE-10] Optional long-press callback for context menu.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final year = item.year;
    final durationMs = item.durationMs;
    final durationText = formatDurationMs(durationMs);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
        onTap: onTap,
        // JF-FE-10: long-press opens context menu panel.
        onLongPress: onLongPress,
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(CrispyRadius.tv),
                bottomLeft: Radius.circular(CrispyRadius.tv),
              ),
              child: SizedBox(
                width: 48,
                height: double.infinity,
                child:
                    item.logoUrl != null
                        ? Image.network(
                          item.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _PlaceholderThumb(cs: cs),
                        )
                        : _PlaceholderThumb(cs: cs),
              ),
            ),
            const SizedBox(width: CrispySpacing.sm),
            // Title + metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.name,
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (year != null || durationText != null) ...[
                    const SizedBox(height: CrispySpacing.xxs),
                    Text(
                      [
                        if (year != null) year.toString(),
                        if (durationText != null) durationText,
                      ].join('  ·  '),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: CrispySpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderThumb extends StatelessWidget {
  const _PlaceholderThumb({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.movie, color: cs.onSurfaceVariant, size: 28),
    );
  }
}
