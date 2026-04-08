import 'package:flutter/material.dart';

import '../../../../core/domain/entities/media_item.dart';
import '../../../../core/domain/entities/media_type.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../domain/entities/search_filter.dart';

// ── FE-SR-03: Best Match Card ─────────────────────────────────────────────────

/// Height of the best-match poster image area.
const double _kBestMatchPosterHeight = 120.0;

/// Width of the best-match poster image area.
const double _kBestMatchPosterWidth = 80.0;

/// Featured "Best Match" card shown above the regular results list (FE-SR-03).
///
/// Displayed when there is a high-confidence top result (total results >=
/// threshold). Shows poster, title, year, match type and a "Play" button.
/// Tapping the card navigates to the item detail screen.
class SearchBestMatchCard extends StatelessWidget {
  const SearchBestMatchCard({
    required this.item,
    required this.onTap,
    required this.onDetails,
    super.key,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final year = item.year;
    final matchType = _matchTypeLabel(item);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.md,
        vertical: CrispySpacing.sm,
      ),
      child: Semantics(
        button: true,
        label: 'View details',
        child: InkWell(
          onTap: onDetails,
          borderRadius: BorderRadius.circular(CrispyRadius.md),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(CrispyRadius.md),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(CrispyRadius.md),
                    bottomLeft: Radius.circular(CrispyRadius.md),
                  ),
                  child: SizedBox(
                    width: _kBestMatchPosterWidth,
                    height: _kBestMatchPosterHeight,
                    child: SmartImage(
                      title: item.name,
                      imageUrl: item.logoUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: (_kBestMatchPosterWidth * 2).toInt(),
                      memCacheHeight: (_kBestMatchPosterHeight * 2).toInt(),
                    ),
                  ),
                ),
                const SizedBox(width: CrispySpacing.md),
                // Info + actions
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: CrispySpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // "Best Match" label
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: CrispySpacing.xs,
                            vertical: CrispySpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(
                              CrispyRadius.xs,
                            ),
                          ),
                          child: Text(
                            'Best Match',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: CrispySpacing.xs),
                        // Title
                        Text(
                          item.name,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Year + match type
                        Row(
                          children: [
                            if (year != null) ...[
                              Text(
                                '$year',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: CrispySpacing.xs),
                              Text(
                                '•',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: CrispySpacing.xs),
                            ],
                            Text(
                              matchType,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: CrispySpacing.sm),
                        // Play button
                        FilledButton.icon(
                          onPressed: onTap,
                          style: FilledButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                              horizontal: CrispySpacing.md,
                              vertical: CrispySpacing.xs,
                            ),
                            // Audited: compact action button in search result card;
                            // space-constrained inline control.
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('Play'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: CrispySpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Returns a human-readable label for the media type (FE-SR-03).
  String _matchTypeLabel(MediaItem item) {
    switch (item.type) {
      case MediaType.channel:
        return 'Live Channel';
      case MediaType.movie:
        return 'Movie';
      case MediaType.series:
        return 'Series';
      case MediaType.episode:
        return 'Episode';
      case MediaType.folder:
        return 'Folder';
      default:
        return 'Media';
    }
  }
}

// ── Active Filters Bar ────────────────────────────────────────────────────────

/// Horizontal bar showing the currently active search filters with a
/// "Clear" button. Hidden when no filters are active.
class SearchActiveFiltersBar extends StatelessWidget {
  const SearchActiveFiltersBar({
    required this.filter,
    required this.onClear,
    super.key,
  });

  final SearchFilter filter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final filters = <String>[];
    if (filter.category != null) filters.add(filter.category!);
    if (filter.yearMin != null || filter.yearMax != null) {
      final yearRange = '${filter.yearMin ?? "..."}-${filter.yearMax ?? "..."}';
      filters.add(yearRange);
    }
    if (filter.searchInDescription) filters.add('Include descriptions');

    if (filters.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.md,
        vertical: CrispySpacing.xs,
      ),
      color: colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 16, color: colorScheme.primary),
          const SizedBox(width: CrispySpacing.sm),
          Expanded(
            child: Text(
              filters.join(' • '),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.sm),
              minimumSize: Size.zero,
              // Audited: compact "Clear" button in search history header;
              // space-constrained inline control.
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
