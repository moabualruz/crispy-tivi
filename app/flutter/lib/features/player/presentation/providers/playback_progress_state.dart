import '../../../vod/domain/entities/vod_item.dart';
import 'playback_session_state.dart';

// ─────────────────────────────────────────────────────────────
//  Completion event
// ─────────────────────────────────────────────────────────────

/// Signals a content-completion event from [PlaybackProgressNotifier].
///
/// Widgets observe this to show the next-episode prompt or the
/// movie-completion overlay — keeping UI-state decisions out of
/// the business-logic layer.
sealed class CompletionEvent {
  const CompletionEvent();
}

/// The current VOD episode finished and [next] is available.
final class NextEpisodeAvailable extends CompletionEvent {
  const NextEpisodeAvailable(this.next);

  /// The episode to play after the current one.
  final VodItem next;
}

/// A movie (or the last episode) finished — no next item.
final class ContentFinished extends CompletionEvent {
  const ContentFinished();
}

/// The user has auto-advanced [count] episodes without interaction.
///
/// Shown after [kStillWatchingThreshold] consecutive auto-advances
/// per J-20. Pauses playback until user responds.
final class StillWatchingPrompt extends CompletionEvent {
  const StillWatchingPrompt(this.next, this.count);

  /// The episode that would play next if user continues.
  final VodItem next;

  /// Number of consecutive auto-advances that triggered this prompt.
  final int count;
}

/// Number of consecutive auto-advances before showing "Still Watching?".
const int kStillWatchingThreshold = 3;

// ─────────────────────────────────────────────────────────────
//  State
// ─────────────────────────────────────────────────────────────

/// Immutable snapshot of the playback progress tracker.
class PlaybackProgressState {
  const PlaybackProgressState({
    this.completionEvent,
    this.maxPositionMs = 0,
    this.maxDurationMs = 0,
  });

  /// Non-null when the content has reached [kCompletionThreshold].
  final CompletionEvent? completionEvent;

  /// Highest observed playback position in milliseconds.
  final int maxPositionMs;

  /// Highest observed total duration in milliseconds.
  final int maxDurationMs;

  PlaybackProgressState copyWith({
    CompletionEvent? completionEvent,
    bool clearCompletionEvent = false,
    int? maxPositionMs,
    int? maxDurationMs,
  }) {
    return PlaybackProgressState(
      completionEvent:
          clearCompletionEvent
              ? null
              : (completionEvent ?? this.completionEvent),
      maxPositionMs: maxPositionMs ?? this.maxPositionMs,
      maxDurationMs: maxDurationMs ?? this.maxDurationMs,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Pure helper (no provider deps)
// ─────────────────────────────────────────────────────────────

/// Returns the next episode after the currently-playing one,
/// or `null` when there is none.
VodItem? findNextEpisode(PlaybackSessionState session) {
  final episodes = session.episodeList;
  if (episodes == null || session.episodeNumber == null) return null;
  final idx = episodes.indexWhere(
    (e) => e.episodeNumber == session.episodeNumber,
  );
  if (idx >= 0 && idx < episodes.length - 1) return episodes[idx + 1];
  return null;
}
