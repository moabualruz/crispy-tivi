import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../vod/domain/entities/vod_item.dart';
import '../providers/playback_progress_provider.dart';
import '../providers/playback_session_provider.dart';
import 'player_fullscreen_overlay.dart';

/// UI-only watch-history mixin for [PlayerFullscreenOverlay].
///
/// Bridges [PlaybackProgressNotifier] (business logic provider)
/// to widget UI state.  This mixin owns only:
///   - The two UI-visible flags ([nextEpisodeToShow] /
///     [showMovieCompletion]) that drive overlay rendering.
///   - The [playNextEpisode] callback that updates session state
///     and resets the overlay.
///
/// All position tracking, persistence, and completion detection
/// is in [PlaybackProgressNotifier].
mixin PlayerHistoryMixin on ConsumerState<PlayerFullscreenOverlay> {
  // ── UI state exposed to build() ──────────────────────────
  VodItem? nextEpisodeToShow;
  bool showMovieCompletion = false;

  // ── Lifecycle ────────────────────────────────────────────

  /// Called by [_PlayerFullscreenOverlayState.dispose] to flush
  /// the final position.
  void disposeHistory() {
    // Flush position on dispose — provider may already be tearing
    // down, so guard with try/catch.
    try {
      ref.read(playbackProgressProvider.notifier).saveNow();
    } catch (_) {
      // ref invalid during dispose — swallowed intentionally.
    }
  }

  /// Resets all UI completion state when a new stream starts.
  void resetHistoryState() {
    nextEpisodeToShow = null;
    showMovieCompletion = false;
  }

  // ── Session start ────────────────────────────────────────

  /// Starts VOD progress tracking for the given [session].
  ///
  /// Wires [PlaybackProgressNotifier] and subscribes to
  /// completion events so the overlay rebuilds via [setState].
  void recordWatchHistory(PlaybackSessionState session) {
    // Seed high-watermark from saved resume position.
    final startMs = session.startPosition?.inMilliseconds ?? 0;
    ref
        .read(playbackProgressProvider.notifier)
        .startTracking(startPositionMs: startMs);

    // Mirror completion events into widget UI state.
    ref.listenManual(
      playbackProgressProvider.select((s) => s.completionEvent),
      (_, event) {
        if (event == null || !mounted) return;
        if (event is NextEpisodeAvailable) {
          setState(() => nextEpisodeToShow = event.next);
        } else if (event is ContentFinished) {
          setState(() => showMovieCompletion = true);
        }
      },
    );
  }

  // ── Direct save (called from dispose) ───────────────────

  /// Saves the current position.  Delegates to the provider.
  void savePosition(PlaybackSessionState session) {
    ref.read(playbackProgressProvider.notifier).saveNow();
  }

  // ── Next-episode navigation ──────────────────────────────

  /// Starts playback of [next] and resets the completion UI.
  void playNextEpisode(VodItem next) {
    final session = ref.read(playbackSessionProvider);
    final channelName = session.channelName ?? '';
    final seriesName =
        channelName.contains(' — ')
            ? channelName.split(' — ').first
            : channelName;

    setState(() => nextEpisodeToShow = null);
    ref.read(playbackProgressProvider.notifier).clearCompletionEvent();

    ref
        .read(playbackSessionProvider.notifier)
        .startPlayback(
          streamUrl: next.streamUrl,
          channelName: '$seriesName — ${next.name}',
          channelLogoUrl: next.posterUrl ?? session.channelLogoUrl,
          mediaType: 'episode',
          seriesId: next.seriesId,
          seasonNumber: next.seasonNumber,
          episodeNumber: next.episodeNumber,
          posterUrl: next.posterUrl ?? session.posterUrl,
          seriesPosterUrl: session.seriesPosterUrl,
          episodeList: session.episodeList,
        );
  }
}
