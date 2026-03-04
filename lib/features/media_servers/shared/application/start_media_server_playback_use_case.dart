import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants.dart';
import '../../../../core/domain/entities/media_item.dart';
import '../../../../features/player/data/watch_history_service.dart';
import '../../../../features/player/presentation/providers/player_providers.dart';

/// Resolves a stream URL, checks watch-history for a resume
/// position, and starts playback via [PlaybackSessionNotifier].
///
/// Extracted from `MediaItemDetailsScreen._navigateToPlayer` to
/// make the logic independently testable (MSB-12).
class StartMediaServerPlaybackUseCase {
  /// Creates a use case bound to [ref] and [context].
  ///
  /// [ref] is used to read providers; [context] is used only to
  /// show a [SnackBar] on error and must be checked for
  /// [BuildContext.mounted] by the caller before awaiting.
  const StartMediaServerPlaybackUseCase({
    required this.ref,
    required this.context,
  });

  /// Provider ref for accessing [PlaybackSessionNotifier] and
  /// [WatchHistoryService].
  final WidgetRef ref;

  /// Build context for displaying error snack-bars.
  final BuildContext context;

  /// Execute the use case.
  ///
  /// [item] — the media item to play.
  /// [resumeFromPosition] — whether to resume from a saved position.
  /// [getStreamUrl] — optional callback to resolve the stream URL
  ///   (used when the item does not carry a pre-resolved URL).
  /// [onLoadingChanged] — called with `true` when loading begins
  ///   and `false` when it finishes, regardless of outcome.
  Future<void> execute({
    required MediaItem item,
    required bool resumeFromPosition,
    Future<String> Function(String itemId)? getStreamUrl,
    ValueChanged<bool>? onLoadingChanged,
  }) async {
    onLoadingChanged?.call(true);

    try {
      // Resolve stream URL.
      final String streamUrl;
      if (getStreamUrl != null) {
        streamUrl = await getStreamUrl(item.id);
      } else if (item.streamUrl != null) {
        streamUrl = item.streamUrl!;
      } else {
        throw Exception('No stream URL available');
      }

      if (!context.mounted) return;

      // Check for resume position.
      Duration? startPosition;
      if (resumeFromPosition && item.playbackPositionMs != null) {
        startPosition = Duration(milliseconds: item.playbackPositionMs!);
      } else if (resumeFromPosition) {
        final id = WatchHistoryService.deriveId(streamUrl);
        final history = await ref.read(watchHistoryServiceProvider).getById(id);
        if (history != null &&
            history.positionMs > 0 &&
            history.durationMs > 0) {
          final progress = (history.positionMs / history.durationMs).clamp(
            0.0,
            1.0,
          );
          if (progress < kCompletionThreshold) {
            startPosition = Duration(milliseconds: history.positionMs);
          }
        }
      }

      if (!context.mounted) return;

      ref
          .read(playbackSessionProvider.notifier)
          .startPlayback(
            streamUrl: streamUrl,
            isLive: false,
            channelName: item.name,
            channelLogoUrl: item.logoUrl,
            startPosition: startPosition,
          );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load stream: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      onLoadingChanged?.call(false);
    }
  }
}
