import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../player/data/watch_history_service.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/vod_item.dart';

/// Launches episode playback with optional resume
/// dialog.
///
/// Checks watch history for a saved position. If the
/// user hasn't finished (< 95%), prompts to resume.
Future<void> playEpisode({
  required BuildContext context,
  required WidgetRef ref,
  required VodItem episode,
  required VodItem series,
  required List<VodItem> episodeList,
}) async {
  final id = WatchHistoryService.deriveId(episode.streamUrl);
  final h = await ref.read(watchHistoryServiceProvider).getById(id);

  Duration? startPos;
  if (h != null && h.positionMs > 0 && h.durationMs > 0) {
    final prog = h.progress.clamp(0.0, 1.0);
    if (prog < kCompletionThreshold && context.mounted) {
      final resume = await showResumeDialog(
        context,
        DurationFormatter.clock(Duration(milliseconds: h.positionMs)),
      );
      if (resume) {
        startPos = Duration(milliseconds: h.positionMs);
      }
    }
  }
  if (!context.mounted) return;

  ref
      .read(playbackSessionProvider.notifier)
      .startPlayback(
        streamUrl: episode.streamUrl,
        channelName: '${series.name} — ${episode.name}',
        channelLogoUrl: episode.posterUrl ?? series.posterUrl,
        isLive: false,
        startPosition: startPos,
        mediaType: 'episode',
        seriesId: episode.seriesId,
        seasonNumber: episode.seasonNumber,
        episodeNumber: episode.episodeNumber,
        posterUrl: episode.posterUrl ?? series.posterUrl,
        seriesPosterUrl: series.posterUrl,
        episodeList: episodeList,
      );
}

/// Shows a resume-or-start-over dialog.
///
/// [formattedPosition] is a pre-formatted string describing
/// the resume point (e.g. "1:23:45" or "12:34 / 1:30:00").
/// Returns `true` if the user chose to resume.
Future<bool> showResumeDialog(
  BuildContext ctx,
  String formattedPosition,
) async {
  final r = await showDialog<bool>(
    context: ctx,
    builder:
        (c) => AlertDialog(
          title: const Text('Resume Playback?'),
          content: Text('Resume from $formattedPosition?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Start Over'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Resume'),
            ),
          ],
        ),
  );
  return r ?? false;
}
