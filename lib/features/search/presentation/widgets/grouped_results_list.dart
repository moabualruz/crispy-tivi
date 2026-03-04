import 'package:flutter/material.dart';

import '../../../../core/domain/entities/media_item.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../domain/entities/grouped_search_results.dart';
import 'enhanced_search_result_card.dart';

/// Displays search results grouped by content type
/// with section headers.
///
/// When [columns] is greater than 1, each section switches to a
/// two-column layout suitable for wide screens (tablets / desktops).
class GroupedResultsList extends StatelessWidget {
  const GroupedResultsList({
    super.key,
    required this.results,
    required this.onItemTap,
    this.onItemFavorite,
    this.onItemDetails,
    this.columns = 1,
  });

  final GroupedSearchResults results;
  final void Function(MediaItem item) onItemTap;

  /// Called when "Add to Favorites" is tapped on a
  /// result item. Null disables the action.
  final void Function(MediaItem item)? onItemFavorite;

  /// Called when "View Details" is tapped on a result
  /// item. Null disables the action.
  final void Function(MediaItem item)? onItemDetails;

  /// Number of columns to use for result items.
  ///
  /// Defaults to 1 (single-column list). Set to 2 on wide screens.
  final int columns;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Channels section
        if (results.channels.isNotEmpty)
          _ResultSection(
            title: 'Channels',
            icon: Icons.live_tv,
            count: results.channels.length,
            items: results.channels,
            onItemTap: onItemTap,
            onItemFavorite: onItemFavorite,
            columns: columns,
          ),

        // Movies section
        if (results.movies.isNotEmpty)
          _ResultSection(
            title: 'Movies',
            icon: Icons.movie,
            count: results.movies.length,
            items: results.movies,
            onItemTap: onItemTap,
            onItemFavorite: onItemFavorite,
            onItemDetails: onItemDetails,
            columns: columns,
          ),

        // Series section
        if (results.series.isNotEmpty)
          _ResultSection(
            title: 'Series',
            icon: Icons.tv,
            count: results.series.length,
            items: results.series,
            onItemTap: onItemTap,
            onItemFavorite: onItemFavorite,
            onItemDetails: onItemDetails,
            columns: columns,
          ),

        // EPG Programs section
        if (results.epgPrograms.isNotEmpty)
          _ResultSection(
            title: 'Programs',
            icon: Icons.schedule,
            count: results.epgPrograms.length,
            items: results.epgPrograms,
            onItemTap: onItemTap,
            columns: columns,
          ),

        // Media Server section
        if (results.mediaServerItems.isNotEmpty)
          _ResultSection(
            title: 'Media Library',
            icon: Icons.video_library,
            count: results.mediaServerItems.length,
            items: results.mediaServerItems,
            onItemTap: onItemTap,
            onItemDetails: onItemDetails,
            columns: columns,
          ),

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: CrispySpacing.xl)),
      ],
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.title,
    required this.icon,
    required this.count,
    required this.items,
    required this.onItemTap,
    this.onItemFavorite,
    this.onItemDetails,
    this.columns = 1,
  });

  final String title;
  final IconData icon;
  final int count;
  final List<MediaItem> items;
  final void Function(MediaItem item) onItemTap;
  final void Function(MediaItem item)? onItemFavorite;
  final void Function(MediaItem item)? onItemDetails;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SliverMainAxisGroup(
      slivers: [
        // Section header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(
              left: CrispySpacing.md,
              right: CrispySpacing.md,
              top: CrispySpacing.md,
              bottom: CrispySpacing.sm,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.primary),
                const SizedBox(width: CrispySpacing.sm),
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: CrispySpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CrispySpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(CrispyRadius.none),
                  ),
                  child: Text(
                    count.toString(),
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Section items — single-column list or wide-screen grid.
        if (columns > 1)
          SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: 3.5,
              crossAxisSpacing: CrispySpacing.sm,
              mainAxisSpacing: CrispySpacing.xs,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return EnhancedSearchResultCard(
                item: item,
                onTap: () => onItemTap(item),
                onFavorite:
                    onItemFavorite != null ? () => onItemFavorite!(item) : null,
                onDetails:
                    onItemDetails != null ? () => onItemDetails!(item) : null,
              );
            },
          )
        else
          SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return EnhancedSearchResultCard(
                item: item,
                onTap: () => onItemTap(item),
                onFavorite:
                    onItemFavorite != null ? () => onItemFavorite!(item) : null,
                onDetails:
                    onItemDetails != null ? () => onItemDetails!(item) : null,
              );
            },
          ),
      ],
    );
  }
}
