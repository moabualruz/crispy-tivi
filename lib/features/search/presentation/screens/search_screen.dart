import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/entities/media_item.dart';
import '../../../../core/domain/entities/media_type.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/testing/test_keys.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../core/widgets/source_selector_bar.dart';
import '../../../../core/widgets/loading_state_widget.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../favorites/presentation/providers/favorites_controller.dart';
import '../../../iptv/presentation/providers/channel_providers.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../vod/domain/entities/vod_item.dart';
import '../../../vod/presentation/providers/vod_providers.dart';
import '../../../voice_search/presentation/widgets/voice_search_button.dart';
import '../../domain/constants/search_source_key.dart';
import '../../domain/entities/search_filter.dart';
import '../../domain/entities/search_state.dart';
import '../providers/search_providers.dart';
import '../widgets/content_type_filter_row.dart';
import '../widgets/grouped_results_list.dart';
import '../widgets/recent_searches_list.dart';
import '../widgets/search_filter_sheet.dart';
import '../widgets/tv_search_panel.dart';

// ── UI dimension constants ────────────────────────────────────────────────────

/// Diameter of the active-filter indicator dot on the filter icon.
const double _kFilterDotSize = 8.0;

/// Inset of the active-filter dot from the top-right corner of the icon button.
const double _kFilterDotInset = 8.0;

/// Duration for brief informational snackbars (e.g. favorite toggled).
const Duration _kSnackBarShort = CrispyAnimation.snackBarDuration;

// ── Wide-screen grid breakpoint ───────────────────────────────────────────────

/// Minimum logical width (dp) for search results to switch to a grid layout.
const double _kWideScreenBreakpoint = 840.0;

/// Number of grid columns on wide screens.
const int _kWideScreenGridColumns = 2;

/// Minimum total result count to show the Best Match card (FE-SR-03).
///
/// We require at least 2 results so the card doesn't duplicate the only item.
const int _kBestMatchMinResults = 2;

/// Enhanced search screen with filtering, grouped results, and history.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Sync text field with state on initialization.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(searchControllerProvider);
      if (state.query.isNotEmpty) {
        _searchController.text = state.query;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // S-18: cancellation is handled inside SearchNotifier.search()
    // via Timer debounce — a new call cancels the pending timer.
    ref.read(searchControllerProvider.notifier).search(query);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchControllerProvider.notifier).clearSearch();
    _focusNode.requestFocus();
  }

  void _showFilterSheet() {
    final state = ref.read(searchControllerProvider);
    showSearchFilterSheet(
      context: context,
      filter: state.filter,
      categories: state.availableCategories,
      onApply: (filter) {
        ref.read(searchControllerProvider.notifier).updateFilter(filter);
      },
      onClear: () {
        ref.read(searchControllerProvider.notifier).clearFilters();
      },
    );
  }

  void _onVoiceResult(String text) {
    if (text.isNotEmpty) {
      _searchController.text = text;
      ref.read(searchControllerProvider.notifier).search(text);
    }
  }

  void _onVoicePartialResult(String text) {
    // Update text field with partial results for visual feedback.
    if (text.isNotEmpty) {
      _searchController.text = text;
    }
  }

  void _onItemFavorite(MediaItem item) {
    final channel = item.metadata['channel'];
    if (channel is Channel) {
      ref.read(favoritesControllerProvider.notifier).toggleFavorite(channel);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Toggled favorite: ${item.name}'),
          duration: _kSnackBarShort,
        ),
      );
    }
  }

  void _onItemDetails(MediaItem item) {
    final vodItem = item.metadata['vodItem'];
    if (vodItem is VodItem) {
      context.push(AppRoutes.vodDetails, extra: {'item': vodItem});
    }
  }

  /// FE-SR-09: navigate to the EPG timeline, select the matched
  /// channel and scroll to the programme's airing time slot.
  void _navigateToEpgEntry(MediaItem item) {
    final entry = item.metadata['epgEntry'];
    final channel = item.metadata['channel'];
    if (entry == null) {
      // Fall back to EPG screen root when entry is missing.
      context.push(AppRoutes.epg);
      return;
    }

    // Pre-select channel + focus time in the EPG provider so the
    // screen auto-scrolls to the right position on mount.
    final epgNotifier = ref.read(epgProvider.notifier);
    if (channel != null) {
      epgNotifier.selectChannel((channel as dynamic).id as String);
    }
    epgNotifier.setFocusedTime((entry as dynamic).startTime as DateTime);
    if (entry != null) {
      epgNotifier.selectEntry(entry as dynamic);
    }
    context.push(AppRoutes.epg);
  }

  Future<void> _onItemTap(MediaItem item) async {
    final sourceKey = item.metadata['source'] as String? ?? '';

    // FE-SR-09: EPG results navigate to the timeline, not the player.
    if (sourceKey == SearchSourceKey.iptvEpg) {
      _navigateToEpgEntry(item);
      return;
    }

    // IPTV / Local VOD — play directly
    if (sourceKey.startsWith(SearchSourceKey.iptv)) {
      ref
          .read(playbackSessionProvider.notifier)
          .startPlayback(
            streamUrl: item.streamUrl ?? '',
            channelName: item.name,
            channelLogoUrl: item.logoUrl,
            isLive: item.type == MediaType.channel,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // FE-SR-08: On TV (large layout) render the two-panel keyboard+results
    // layout instead of the standard search bar + body.
    if (context.isLarge) {
      return Scaffold(
        key: TestKeys.searchScreen,
        body: TvSearchPanel(
          onItemTap: _onItemTap,
          onItemFavorite: _onItemFavorite,
          onItemDetails: _onItemDetails,
        ),
      );
    }

    return Scaffold(
      key: TestKeys.searchScreen,
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          autofocus: true,
          style: textTheme.titleMedium,
          decoration: InputDecoration(
            hintText: 'Search movies, shows, channels...',
            labelText: 'Search',
            border: InputBorder.none,
            hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
            suffixIcon:
                state.query.isNotEmpty
                    ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _clearSearch,
                      tooltip: 'Clear search',
                    )
                    : null,
          ),
          onChanged: _onSearchChanged,
        ),
        actions: [
          // Voice search button.
          VoiceSearchButton(
            onResult: _onVoiceResult,
            onPartialResult: _onVoicePartialResult,
          ),
          // Filter button with badge if filters are active.
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: _showFilterSheet,
                tooltip: 'Advanced filters',
              ),
              if (state.filter.hasActiveFilters)
                Positioned(
                  right: _kFilterDotInset,
                  top: _kFilterDotInset,
                  child: Container(
                    width: _kFilterDotSize,
                    height: _kFilterDotSize,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      // S-07: body content extracted to _SearchBody
      body: FocusTraversalGroup(
        child: _SearchBody(
          state: state,
          isContentLoaded:
              ref.watch(
                channelListProvider.select((s) => s.channels.isNotEmpty),
              ) ||
              ref.watch(vodProvider.select((s) => s.items.isNotEmpty)),
          onToggleContentType: (type) {
            ref.read(searchControllerProvider.notifier).toggleContentType(type);
          },
          onClearFilters: () {
            ref.read(searchControllerProvider.notifier).clearFilters();
          },
          onSelectRecent: (entry) {
            _searchController.text = entry.query;
            ref
                .read(searchControllerProvider.notifier)
                .selectRecentSearch(entry);
          },
          onRemoveRecent: (id) {
            ref.read(searchControllerProvider.notifier).removeFromHistory(id);
          },
          onClearHistory: () {
            ref.read(searchControllerProvider.notifier).clearHistory();
          },
          onItemTap: _onItemTap,
          onItemFavorite: _onItemFavorite,
          onItemDetails: _onItemDetails,
        ),
      ),
    );
  }
}

// ── S-07: Extracted search body ───────────────────────────────────────────────

/// Main body of the search screen: filter row, active-filters bar, and
/// the content area (recent searches / loading / results / empty state).
class _SearchBody extends StatelessWidget {
  const _SearchBody({
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
          _ActiveFiltersBar(filter: state.filter, onClear: onClearFilters),

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
    final isWide = screenWidth >= _kWideScreenBreakpoint;

    // FE-SR-04: result count label shown above the results list.
    final totalCount = state.results.totalCount;
    final countLabel = totalCount == 1 ? '1 result' : '$totalCount results';

    // FE-SR-03: determine best match — first item when total >= threshold.
    final allResults = state.results.all;
    final hasBestMatch = allResults.length >= _kBestMatchMinResults;
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
          _BestMatchCard(
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
            columns: isWide ? _kWideScreenGridColumns : 1,
          ),
        ),
      ],
    );
  }
}

// ── FE-SR-03: Best Match Card ─────────────────────────────────────────────────

/// Height of the best-match poster image area.
const double _kBestMatchPosterHeight = 120.0;

/// Width of the best-match poster image area.
const double _kBestMatchPosterWidth = 80.0;

/// Featured "Best Match" card shown above the regular results list (FE-SR-03).
///
/// Displayed when there is a high-confidence top result (total results >=
/// [_kBestMatchMinResults]). Shows poster, title, year, match type and a
/// "Play" button. Tapping the card navigates to the item detail screen.
class _BestMatchCard extends StatelessWidget {
  const _BestMatchCard({
    required this.item,
    required this.onTap,
    required this.onDetails,
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
                  child:
                      item.logoUrl != null
                          ? Image.network(
                            item.logoUrl!,
                            width: _kBestMatchPosterWidth,
                            height: _kBestMatchPosterHeight,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (ctx, err, st) =>
                                    _posterPlaceholder(colorScheme),
                          )
                          : _posterPlaceholder(colorScheme),
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

  Widget _posterPlaceholder(ColorScheme colorScheme) {
    return Container(
      width: _kBestMatchPosterWidth,
      height: _kBestMatchPosterHeight,
      color: colorScheme.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Icon(
        Icons.movie_outlined,
        color: colorScheme.onSurfaceVariant,
        size: 32,
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

class _ActiveFiltersBar extends StatelessWidget {
  const _ActiveFiltersBar({required this.filter, required this.onClear});

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
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
