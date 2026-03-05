import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crispy_tivi/core/domain/entities/media_item.dart';
import 'package:crispy_tivi/core/domain/entities/media_type.dart';
import 'package:crispy_tivi/core/domain/media_source.dart';
import 'package:crispy_tivi/core/navigation/app_routes.dart';
import 'package:crispy_tivi/core/theme/crispy_radius.dart';
import 'package:crispy_tivi/core/theme/crispy_spacing.dart';
import 'package:crispy_tivi/core/utils/duration_formatter.dart';
import 'package:crispy_tivi/core/widgets/focus_wrapper.dart';
import '../widgets/watched_indicator.dart';

/// Shared series navigation screen for Emby and Jellyfin.
///
/// Displays seasons as horizontal tabs and episodes as a vertical list
/// within the selected season. Tapping an episode navigates to the
/// media item details screen.
///
/// Callers provide server-specific data via constructor parameters —
/// see [EmbySeriesScreen] and [JellyfinSeriesScreen] for concrete usage.
class MediaServerSeriesScreen extends ConsumerStatefulWidget {
  const MediaServerSeriesScreen({
    required this.seriesId,
    required this.title,
    required this.scaffoldKey,
    required this.serverType,
    required this.heroTagPrefix,
    required this.seasonsProvider,
    required this.episodesProvider,
    required this.streamUrlProvider,
    super.key,
  });

  /// The series item ID on the media server.
  final String seriesId;

  /// Display title shown in the AppBar.
  final String title;

  /// Key applied to the [Scaffold] for widget-test targeting.
  final Key scaffoldKey;

  /// The media server type — passed to the details route.
  final MediaServerType serverType;

  /// Prefix for the hero transition tag (e.g. `'emby_series_'`).
  final String heroTagPrefix;

  /// Returns the seasons list for a given series ID.
  ///
  /// Receives [WidgetRef] and the series ID; should watch a seasons
  /// provider and return its [AsyncValue].
  final AsyncValue<List<MediaItem>> Function(WidgetRef ref, String seriesId)
  seasonsProvider;

  /// Returns the episodes list for a given (seriesId, seasonId) pair.
  ///
  /// Receives [WidgetRef], the series ID, and the season ID; should watch
  /// an episodes provider and return its [AsyncValue].
  final AsyncValue<List<MediaItem>> Function(
    WidgetRef ref,
    String seriesId,
    String seasonId,
  )
  episodesProvider;

  /// Resolves the playback stream URL for an item ID.
  final Future<String> Function(WidgetRef ref, String itemId) streamUrlProvider;

  @override
  ConsumerState<MediaServerSeriesScreen> createState() =>
      _MediaServerSeriesScreenState();
}

class _MediaServerSeriesScreenState
    extends ConsumerState<MediaServerSeriesScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  int _selectedSeasonIndex = 0;

  /// Currently selected season ID.
  String? _selectedSeasonId;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  /// Rebuilds the [TabController] whenever the season list changes length.
  void _syncTabController(List<MediaItem> seasons) {
    final newLength = seasons.isEmpty ? 1 : seasons.length;
    if (_tabController?.length != newLength) {
      _tabController?.dispose();
      _tabController = TabController(
        length: newLength,
        vsync: this,
        initialIndex: _selectedSeasonIndex.clamp(0, newLength - 1),
      );
      _tabController!.addListener(() {
        if (!_tabController!.indexIsChanging) {
          setState(() {
            _selectedSeasonIndex = _tabController!.index;
            _selectedSeasonId =
                seasons.isNotEmpty ? seasons[_tabController!.index].id : null;
          });
        }
      });
    }
    // Set initial season ID when first available.
    if (_selectedSeasonId == null && seasons.isNotEmpty) {
      _selectedSeasonId = seasons.first.id;
    }
  }

  void _navigateToEpisode(MediaItem episode) {
    if (episode.type == MediaType.episode ||
        episode.type == MediaType.movie ||
        episode.type == MediaType.unknown) {
      context.push(
        AppRoutes.mediaServerDetails,
        extra: {
          'item': episode,
          'serverType': widget.serverType,
          'getStreamUrl':
              (String itemId) => widget.streamUrlProvider(ref, itemId),
          'heroTag': '${widget.heroTagPrefix}${episode.id}',
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final seasonsAsync = widget.seasonsProvider(ref, widget.seriesId);

    return seasonsAsync.when(
      loading:
          () => Scaffold(
            appBar: AppBar(title: Text(widget.title)),
            body: const Center(child: CircularProgressIndicator()),
          ),
      error:
          (error, _) => Scaffold(
            appBar: AppBar(title: Text(widget.title)),
            body: Center(child: Text('Failed to load seasons: $error')),
          ),
      data: (seasons) {
        _syncTabController(seasons);

        final tabController = _tabController;
        if (tabController == null) return const SizedBox.shrink();

        return Scaffold(
          key: widget.scaffoldKey,
          appBar: AppBar(
            title: Text(widget.title, overflow: TextOverflow.ellipsis),
            bottom:
                seasons.isEmpty
                    ? null
                    : TabBar(
                      controller: tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: seasons.map((s) => Tab(text: s.name)).toList(),
                    ),
          ),
          body:
              seasons.isEmpty
                  ? const _EmptySeriesPlaceholder()
                  : _EpisodesPane(
                    seriesId: widget.seriesId,
                    seasonId: _selectedSeasonId ?? seasons.first.id,
                    onEpisodeTap: _navigateToEpisode,
                    episodesProvider: widget.episodesProvider,
                  ),
        );
      },
    );
  }
}

// ── Episodes pane ──────────────────────────────────────────────────────

/// Vertical list of episodes for the selected season.
class _EpisodesPane extends ConsumerWidget {
  const _EpisodesPane({
    required this.seriesId,
    required this.seasonId,
    required this.onEpisodeTap,
    required this.episodesProvider,
  });

  final String seriesId;
  final String seasonId;
  final ValueChanged<MediaItem> onEpisodeTap;
  final AsyncValue<List<MediaItem>> Function(
    WidgetRef ref,
    String seriesId,
    String seasonId,
  )
  episodesProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodesAsync = episodesProvider(ref, seriesId, seasonId);

    return episodesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, _) => Center(child: Text('Failed to load episodes: $error')),
      data:
          (episodes) =>
              episodes.isEmpty
                  ? const _EmptySeriesPlaceholder()
                  : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CrispySpacing.md,
                      vertical: CrispySpacing.sm,
                    ),
                    itemCount: episodes.length,
                    separatorBuilder:
                        (_, _) => const SizedBox(height: CrispySpacing.sm),
                    itemBuilder:
                        (context, index) => _EpisodeRow(
                          episode: episodes[index],
                          onTap: () => onEpisodeTap(episodes[index]),
                        ),
                  ),
    );
  }
}

// ── Episode row ────────────────────────────────────────────────────────

/// Single episode row with thumbnail, badge, title, runtime, and watched
/// indicator. Wrapped in [FocusWrapper] for TV D-pad support.
class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({required this.episode, required this.onTap});

  final MediaItem episode;
  final VoidCallback onTap;

  /// Builds the `S01E03` badge text from metadata fields.
  String? _episodeBadge() {
    final s = episode.metadata['parentIndex'];
    final e = episode.metadata['index'];
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
    final duration = DurationFormatter.humanShortMs(episode.durationMs);
    final releaseDate = episode.releaseDate;

    return FocusWrapper(
      onSelect: onTap,
      borderRadius: CrispyRadius.md,
      scaleFactor: 1.03,
      padding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(CrispyRadius.md)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Thumbnail ──────────────────────────────────────
              SizedBox(
                width: 128,
                height: 72,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (episode.logoUrl != null)
                      Image.network(
                        episode.logoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _ThumbPlaceholder(cs: cs),
                      )
                    else
                      _ThumbPlaceholder(cs: cs),
                    // Episode badge (S01E03) — top-left overlay.
                    if (badge != null)
                      Positioned(
                        top: CrispySpacing.xs,
                        left: CrispySpacing.xs,
                        child: _EpisodeBadge(label: badge, cs: cs),
                      ),
                    // Watched indicator — progress bar at bottom.
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: WatchedIndicator(
                        isWatched: episode.isWatched,
                        isInProgress: episode.isInProgress,
                        watchProgress: episode.watchProgress,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Metadata ───────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CrispySpacing.sm,
                    vertical: CrispySpacing.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        episode.name,
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: CrispySpacing.xxs),
                      // Air date · runtime
                      if (releaseDate != null || duration != null)
                        Text(
                          [
                            if (releaseDate != null)
                              '${releaseDate.year}-'
                                  '${releaseDate.month.toString().padLeft(2, '0')}-'
                                  '${releaseDate.day.toString().padLeft(2, '0')}',
                            if (duration != null) duration,
                          ].join('  ·  '),
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      if (episode.overview != null) ...[
                        const SizedBox(height: CrispySpacing.xxs),
                        Text(
                          episode.overview!,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Watched checkmark ───────────────────────────────
              if (episode.isWatched)
                Padding(
                  padding: const EdgeInsets.all(CrispySpacing.sm),
                  child: Icon(Icons.check_circle, size: 18, color: cs.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────────────

/// Episode badge pill (e.g. `S01E03`).
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

/// Placeholder shown when an episode has no artwork.
class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Icon(
        Icons.play_circle_outline,
        color: cs.onSurfaceVariant,
        size: 32,
      ),
    );
  }
}

/// Shown when there are no seasons or episodes to display.
class _EmptySeriesPlaceholder extends StatelessWidget {
  const _EmptySeriesPlaceholder();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.tv_off,
            size: 48,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: CrispySpacing.sm),
          Text(
            'No episodes found',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
