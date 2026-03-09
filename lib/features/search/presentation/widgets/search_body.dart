import 'package:flutter/material.dart';

import '../../../../core/domain/entities/media_item.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../core/widgets/loading_state_widget.dart';
import '../../../../core/widgets/source_selector_bar.dart';
import '../../domain/entities/search_filter.dart';
import '../../domain/entities/search_state.dart';
import '../widgets/content_type_filter_row.dart';
import '../widgets/grouped_results_list.dart';
import '../widgets/recent_searches_list.dart';
import '../widgets/search_result_widgets.dart';

/// Minimum logical width (dp) for search results to switch to a grid layout.
const double kSearchWideScreenBreakpoint = 840.0;

/// Number of grid columns on wide screens.
const int kSearchWideScreenGridColumns = 2;

/// Minimum total result count to show the Best Match card (FE-SR-03).
const int kSearchBestMatchMinResults = 2;

/// Main body of the search screen: filter row, active-filters bar, and
/// the content area (recent searches / loading / results / empty state).
class SearchBody extends StatelessWidget {
  const SearchBody({
    required this.state,
    required this.isContentLoaded,
    required this.onToggleContentType,
    required this.onClearFilters,
    required this.onSelectRecent,
    required this.onRemoveRecent,
    required this.onClearHistory,
    required this.onItemTap,
    required this.onItemFavorite,
    required this.onItemDetails,
    super.key,
  });

  final SearchState state;

  /// Whether channel or VOD data has loaded. When false, the
  /// no-results state shows a "still loading" hint instead of
  /// the definitive "no results found" message.
  final bool isContentLoaded;
  final void Function(SearchContentType) onToggleContentType;
  final VoidCallback onClearFilters;
  final void Function(dynamic) onSelectRecent;
  final void Function(String) onRemoveRecent;
  final VoidCallback onClearHistory;
  final Future<void> Function(MediaItem) onItemTap;
  final void Function(MediaItem) onItemFavorite;
  final void Function(MediaItem) onItemDetails;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Source filter bar (hidden when ≤1 source).
        const SourceSelectorBar(),

        // Content type filter chips.
        ContentTypeFilterRow(
          filter: state.filter,
          onToggle: onToggleContentType,
        ),

        // Active filters indicator.
        if (state.filter.hasActiveFilters)
          SearchActiveFiltersBar(filter: state.filter, onClear: onClearFilters),

        // Main content.
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    // Show recent searches when no query.
    if (!state.hasQuery) {
      return RecentSearchesList(
        entries: state.recentSearches,
        onSelect: onSelectRecent,
        onRemove: onRemoveRecent,
        onClearAll: onClearHistory,
      );
    }

    // Show loading state.
    if (state.isLoading) {
      return const LoadingStateWidget();
    }

    // Show error state.
    if (state.error != null) {
      return ErrorStateWidget(message: 'Error: ${state.error}');
    }

    // Show no-results state.
    if (state.hasNoResults) {
      // When content data hasn't loaded yet, the empty result is
      // misleading — show a "still loading" hint instead (FE-SR-15).
      if (!isContentLoaded) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: CrispySpacing.md),
              Text(
                'Loading content data...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: CrispySpacing.xs),
              Text(
                'Search will run automatically once data is ready',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }

      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: CrispySpacing.md),
            Text(
              'No results found for "${state.query}"',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            // FE-SR-04: "No results" count label.
            const SizedBox(height: CrispySpacing.xs),
            Text(
              'No results',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (state.filter.hasActiveFilters) ...[
              const SizedBox(height: CrispySpacing.sm),
              TextButton(
                onPressed: onClearFilters,
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      );
    }

    // S-13: wide-screen grid vs narrow list.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= kSearchWideScreenBreakpoint;

    // FE-SR-04: result count label shown above the results list.
    final totalCount = state.results.totalCount;
    final countLabel = totalCount == 1 ? '1 result' : '$totalCount results';

    // FE-SR-03: determine best match — first item when total >= threshold.
    final allResults = state.results.all;
    final hasBestMatch = allResults.length >= kSearchBestMatchMinResults;
    final bestMatch = hasBestMatch ? allResults.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CrispySpacing.md,
            vertical: CrispySpacing.xs,
          ),
          child: Text(
            countLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        // FE-SR-03: Best Match featured card above regular results.
        if (bestMatch != null)
          SearchBestMatchCard(
            item: bestMatch,
            onTap: () => onItemTap(bestMatch),
            onDetails: () => onItemDetails(bestMatch),
          ),
        Expanded(
          child: GroupedResultsList(
            results: state.results,
            onItemTap: onItemTap,
            onItemFavorite: onItemFavorite,
            onItemDetails: onItemDetails,
            columns: isWide ? kSearchWideScreenGridColumns : 1,
          ),
        ),
      ],
    );
  }
}
