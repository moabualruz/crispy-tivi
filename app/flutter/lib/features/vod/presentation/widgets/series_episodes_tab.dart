import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants.dart';
import '../providers/vod_service_providers.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/loading_state_widget.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../player/domain/entities/watch_history_entry.dart';
import '../../domain/entities/vod_item.dart';
import '../../domain/utils/episode_utils.dart';
import '../providers/vod_providers.dart';
import 'episode_tile.dart';
import 'series_episode_fetcher.dart';

/// Estimated height of a single [EpisodeTile] row.
/// Used to compute the scroll offset for auto-centering
/// the up-next episode.
const double _kEpisodeTileHeight = 88.0;

/// Episodes tab for the series detail screen.
///
/// Episode data is driven by [seriesEpisodesProvider] (passed in
/// as [episodesAsync]) — no episode state lives in the parent
/// widget's setState. Only the selected season index is kept as
/// local UI state in [SeriesDetailScreen].
///
/// On first data load the list auto-scrolls to centre the
/// "up next" episode (the episode immediately after the last
/// watched one).
class SeriesEpisodesTab extends ConsumerStatefulWidget {
  const SeriesEpisodesTab({
    super.key,
    required this.series,
    required this.episodesAsync,
    required this.seasons,
    required this.selectedSeason,
    required this.filtered,
    required this.onSeasonChanged,
    required this.onPlay,
    required this.onEpMenu,
    required this.cs,
    required this.tt,
  });

  /// The parent series (used for the series ID key and retry).
  final VodItem series;

  /// The async episode fetch result from [seriesEpisodesProvider].
  final AsyncValue<EpisodeFetchResult> episodesAsync;

  /// Available season numbers (derived from [episodesAsync]).
  final List<int> seasons;

  /// Currently selected season number.
  final int? selectedSeason;

  /// Episodes filtered to the selected season.
  final List<VodItem> filtered;

  /// Called when the user picks a different season.
  final ValueChanged<int?> onSeasonChanged;

  /// Called to play an episode.
  final void Function(VodItem) onPlay;

  /// Called to show the episode context menu.
  final void Function(BuildContext, VodItem) onEpMenu;

  /// Current color scheme.
  final ColorScheme cs;

  /// Current text theme.
  final TextTheme tt;

  @override
  ConsumerState<SeriesEpisodesTab> createState() => _SeriesEpisodesTabState();
}

class _SeriesEpisodesTabState extends ConsumerState<SeriesEpisodesTab> {
  final ScrollController _scrollController = ScrollController();

  /// The stream URL of the last-watched episode when the auto-scroll
  /// was last triggered. Used to avoid re-scrolling on every rebuild.
  String? _lastScrolledTo;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// FE-SRD-03: Toggles the watched state for a single episode.
  ///
  /// If the episode is already watched (>= 95% progress), the history
  /// entry is deleted. Otherwise a completed entry (100%) is written.
  /// Invalidates [episodeProgressMapProvider] so the tile refreshes.
  Future<void> _toggleWatched(
    BuildContext context,
    VodItem ep,
    Map<String, double> pMap,
  ) async {
    final historyService = ref.read(watchHistoryServiceProvider);
    final cacheService = ref.read(cacheServiceProvider);
    final id = WatchHistoryService.deriveId(ep.streamUrl);
    final currentProgress = pMap[ep.streamUrl] ?? 0.0;
    final isWatched = currentProgress >= kCompletionThreshold;

    if (isWatched) {
      await historyService.delete(id);
    } else {
      final existing = await historyService.getById(id);
      final durationMs =
          existing != null && existing.durationMs > 0 ? existing.durationMs : 1;
      final entry = WatchHistoryEntry(
        id: id,
        mediaType: 'episode',
        name: ep.name,
        streamUrl: ep.streamUrl,
        posterUrl: ep.posterUrl,
        positionMs: durationMs,
        durationMs: durationMs,
        lastWatched: DateTime.now(),
        seriesId: widget.series.id,
        seasonNumber: ep.seasonNumber,
        episodeNumber: ep.episodeNumber,
      );
      await cacheService.saveWatchHistory(entry);
    }

    // Refresh the progress map so the tile re-renders.
    ref.invalidate(episodeProgressMapProvider(widget.series.id));
    ref.invalidate(lastWatchedEpisodeIdProvider(widget.series.id));

    if (context.mounted) {
      final msg = isWatched ? 'Marked as unwatched' : 'Marked as watched';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  /// Scrolls the list so that the episode at [index] is vertically
  /// centred in the viewport.
  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    final viewportHeight = _scrollController.position.viewportDimension;
    final targetOffset =
        index * _kEpisodeTileHeight -
        (viewportHeight / 2) +
        (_kEpisodeTileHeight / 2);
    final clampedOffset = targetOffset.clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      clampedOffset,
      duration: CrispyAnimation.slow,
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.episodesAsync.isLoading) {
      return const LoadingStateWidget();
    }
    if (widget.episodesAsync.hasError) {
      return _errorBody(
        widget.episodesAsync.error.toString(),
        onRetry:
            () => ref.invalidate(
              seriesEpisodesProvider((
                seriesId: widget.series.id,
                sourceId: widget.series.sourceId,
              )),
            ),
      );
    }

    final pMap =
        ref.watch(episodeProgressMapProvider(widget.series.id)).asData?.value ??
        {};
    final lastId =
        ref.watch(lastWatchedEpisodeIdProvider(widget.series.id)).asData?.value;

    final upNextIdx = upNextIndex(widget.filtered, pMap, lastId);

    // Auto-scroll once per unique last-watched episode to avoid
    // re-scrolling every rebuild.
    if (upNextIdx >= 0 && lastId != _lastScrolledTo) {
      _lastScrolledTo = lastId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToIndex(upNextIdx);
      });
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        if (widget.seasons.length > 1) _seasonSelector(),
        const SliverToBoxAdapter(child: SizedBox(height: CrispySpacing.sm)),
        _episodeList(context, pMap, lastId, upNextIdx),
        const SliverToBoxAdapter(child: SizedBox(height: CrispySpacing.xl)),
      ],
    );
  }

  Widget _errorBody(String error, {required VoidCallback onRetry}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: widget.cs.error),
          const SizedBox(height: CrispySpacing.sm),
          Text('Failed to load episodes', style: widget.tt.titleMedium),
          const SizedBox(height: CrispySpacing.xs),
          Text(
            error,
            style: widget.tt.bodySmall?.copyWith(color: widget.cs.error),
          ),
          const SizedBox(height: CrispySpacing.md),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _seasonSelector() {
    final allEpisodes = widget.episodesAsync.value?.episodes ?? [];
    final cache = ref.read(cacheServiceProvider);
    final countBySeason = cache.episodeCountBySeason(allEpisodes);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.md),
        child: Row(
          children: [
            Text('Season', style: widget.tt.titleSmall),
            const SizedBox(width: CrispySpacing.md),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: CrispySpacing.md,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(CrispyRadius.none),
                  border: Border.all(
                    color: widget.cs.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: DropdownButton<int>(
                  value: widget.selectedSeason,
                  underline: const SizedBox.shrink(),
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(CrispyRadius.none),
                  items:
                      widget.seasons
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                countBySeason.containsKey(s)
                                    ? 'Season $s · ${countBySeason[s]} Episodes'
                                    : 'Season $s',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: widget.onSeasonChanged,
                ),
              ),
            ),
            const SizedBox(width: CrispySpacing.sm),
            Text(
              '${widget.filtered.length} episodes',
              style: widget.tt.bodySmall?.copyWith(
                color: widget.cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _episodeList(
    BuildContext context,
    Map<String, double> pMap,
    String? lastId,
    int upNextIdx,
  ) {
    // FE-SRD-11: Use two-column grid on large (TV/desktop ≥ 1200dp)
    // breakpoint; single-column list otherwise.
    final isLarge = context.isLarge;

    if (isLarge) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.md),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: CrispySpacing.md,
            mainAxisSpacing: 0,
            // Match the single-column tile height so the grid rows
            // have the same visual rhythm as the list layout.
            mainAxisExtent: _kEpisodeTileHeight * 1.5,
          ),
          delegate: SliverChildBuilderDelegate((ctx, i) {
            final ep = widget.filtered[i];
            final epId = ep.streamUrl;
            return EpisodeTile(
              episode: ep,
              progress: pMap[epId],
              isLastWatched: lastId == epId,
              isUpNext: i == upNextIdx,
              onTap: () => widget.onPlay(ep),
              onLongPress: () => widget.onEpMenu(ctx, ep),
              onToggleWatched: () => _toggleWatched(ctx, ep, pMap),
            );
          }, childCount: widget.filtered.length),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((ctx, i) {
        final ep = widget.filtered[i];
        final epId = ep.streamUrl;
        return EpisodeTile(
          episode: ep,
          progress: pMap[epId],
          isLastWatched: lastId == epId,
          isUpNext: i == upNextIdx,
          onTap: () => widget.onPlay(ep),
          onLongPress: () => widget.onEpMenu(ctx, ep),
          onToggleWatched: () => _toggleWatched(ctx, ep, pMap),
        );
      }, childCount: widget.filtered.length),
    );
  }
}
