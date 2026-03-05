import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../../../core/widgets/loading_state_widget.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../player/data/watch_history_service.dart';
import '../../../player/domain/entities/watch_history_entry.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/utils/cw_filter_utils.dart';

// ── FE-FAV-10: Up Next tab ────────────────────────────────────

/// FE-FAV-10: "Up Next" unified queue.
///
/// Combines:
/// - Continue-watching items (partially watched movies/episodes).
/// - Next unwatched episodes from series in watch history.
///
/// Sorted by [WatchHistoryEntry.lastWatched] descending.
class UpNextTab extends ConsumerWidget {
  const UpNextTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continueMovies = ref.watch(continueWatchingMoviesProvider);
    final continueSeries = ref.watch(continueWatchingSeriesProvider);

    final isLoading = continueMovies.isLoading || continueSeries.isLoading;

    if (isLoading) {
      return const LoadingStateWidget();
    }

    final movies = continueMovies.value ?? const [];
    final series = continueSeries.value ?? const [];
    final combined = mergeDedupSort(movies, series);

    if (combined.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(CrispySpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.queue_play_next, size: 64),
              SizedBox(height: CrispySpacing.md),
              Text(
                'Nothing queued up. Browse channels or VOD to get started.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(CrispySpacing.md),
      itemCount: combined.length,
      itemBuilder: (context, index) {
        final entry = combined[index];
        return UpNextItem(
          entry: entry,
          onPlay: () {
            ref
                .read(playbackSessionProvider.notifier)
                .startPlayback(
                  streamUrl: entry.streamUrl,
                  channelName: entry.name,
                  posterUrl: entry.posterUrl,
                  startPosition:
                      entry.positionMs > 0
                          ? Duration(milliseconds: entry.positionMs)
                          : Duration.zero,
                );
          },
        );
      },
    );
  }
}

// ── Up Next item ──────────────────────────────────────────────

/// A single item in the "Up Next" tab.
///
/// Shows thumbnail, title, episode label, progress bar (if partially
/// watched), and a "Resume" / "Play" button.
class UpNextItem extends StatelessWidget {
  const UpNextItem({super.key, required this.entry, required this.onPlay});

  final WatchHistoryEntry entry;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final isPartial =
        entry.progress > 0 && entry.progress < kCompletionThreshold;
    final buttonLabel = isPartial ? 'Resume' : 'Play';
    final hasPoster = entry.posterUrl != null && entry.posterUrl!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: CrispySpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CrispyRadius.md),
      ),
      child: FocusWrapper(
        onSelect: onPlay,
        borderRadius: CrispyRadius.md,
        child: InkWell(
          onTap: onPlay,
          borderRadius: BorderRadius.circular(CrispyRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(CrispySpacing.sm),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(CrispyRadius.sm),
                  child: SizedBox(
                    width: 80,
                    height: 54,
                    child:
                        hasPoster
                            ? SmartImage(
                              itemId: entry.id,
                              title: entry.name,
                              imageUrl: entry.posterUrl,
                              imageKind: 'poster',
                              fit: BoxFit.cover,
                              icon: Icons.movie_outlined,
                            )
                            : Container(
                              color: cs.surfaceContainerHighest,
                              child: Icon(
                                entry.mediaType == 'episode'
                                    ? Icons.live_tv_outlined
                                    : Icons.movie_outlined,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                  ),
                ),
                const SizedBox(width: CrispySpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (entry.episodeLabel != null) ...[
                        const SizedBox(height: CrispySpacing.xxs),
                        Text(
                          entry.episodeLabel!,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (isPartial) ...[
                        const SizedBox(height: CrispySpacing.xs),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            CrispyRadius.full,
                          ),
                          child: LinearProgressIndicator(
                            value: entry.progress,
                            minHeight: 3,
                            backgroundColor: cs.surfaceContainerHighest,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: CrispySpacing.sm),
                FilledButton.tonal(
                  onPressed: onPlay,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CrispySpacing.sm,
                      vertical: CrispySpacing.xs,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPartial
                            ? Icons.play_arrow_rounded
                            : Icons.play_circle_outline_rounded,
                        size: 16,
                      ),
                      const SizedBox(width: CrispySpacing.xxs),
                      Text(buttonLabel, style: tt.labelSmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
