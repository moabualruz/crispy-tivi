import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../domain/entities/vod_item.dart';
import '../../domain/utils/episode_utils.dart';
import '../providers/vod_providers.dart';

/// Button that finds and plays the next unwatched
/// episode. Falls back to replaying the first if
/// all are watched.
class PlayNextEpisodeButton extends ConsumerWidget {
  const PlayNextEpisodeButton({
    super.key,
    required this.episodes,
    required this.seriesId,
    required this.onPlay,
  });

  final List<VodItem> episodes;
  final String seriesId;
  final void Function(VodItem) onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(episodeProgressMapProvider(seriesId));
    final progressMap = progressAsync.asData?.value ?? {};

    final (:next, :isReplay) = findNextEpisode(episodes, progressMap);
    final nextEpisode = next;
    if (nextEpisode == null) {
      return const SizedBox.shrink();
    }
    final epLabel = formatEpisodeLabel(
      nextEpisode.seasonNumber,
      nextEpisode.episodeNumber,
    );

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Subtitle: "S02 E05 · Episode Title" (or just the label/title alone).
    final subtitleParts = <String>[
      if (epLabel.isNotEmpty) epLabel,
      if (nextEpisode.name.isNotEmpty) nextEpisode.name,
    ];
    final subtitle = subtitleParts.join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: CrispySpacing.sm),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => onPlay(nextEpisode),
          icon: Icon(
            isReplay ? Icons.replay : Icons.play_arrow_rounded,
            color: colorScheme.surface,
          ),
          label: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isReplay ? 'Replay' : 'Play Next',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.surface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.surface.withValues(alpha: 0.75),
                  ),
                ),
            ],
          ),
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.onSurface,
            shape: const RoundedRectangleBorder(),
            padding: const EdgeInsets.symmetric(
              horizontal: CrispySpacing.md,
              vertical: CrispySpacing.sm,
            ),
          ),
        ),
      ),
    );
  }
}
