import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants.dart';
import '../../../vod/domain/entities/vod_item.dart';
import '../../data/watch_history_service.dart';
import '../../domain/entities/playback_state.dart';
import 'player_providers.dart';

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
//  Notifier
// ─────────────────────────────────────────────────────────────

/// Tracks VOD watch progress and emits completion events.
///
/// Business logic only — no `setState`, no widget refs.
/// The [PlayerHistoryMixin] starts/stops this tracker and
/// mirrors [completionEvent] into widget UI state via
/// `setState`.
///
/// Responsibilities:
/// - Subscribes to [playbackStateProvider] to track position /
///   duration high-watermarks.
/// - Persists progress to [WatchHistoryService] every 5 s
///   (continuous) and on an explicit [saveNow] call.
/// - Detects completion at [kCompletionThreshold] and emits a
///   [CompletionEvent] via state.
/// - Resolves the next episode from the session episode list.
class PlaybackProgressNotifier extends Notifier<PlaybackProgressState> {
  ProviderSubscription<AsyncValue<PlaybackState>>? _positionSub;
  Timer? _periodicSaveTimer;
  Timer? _completionPollTimer;
  DateTime? _lastSaveTime;
  bool _completionFired = false;

  @override
  PlaybackProgressState build() {
    ref.onDispose(_cancel);
    return const PlaybackProgressState();
  }

  // ── Public API ───────────────────────────────────────────

  /// Starts tracking for the current session.
  ///
  /// Call when a new VOD stream URL is active.  Pass the
  /// initial [startPositionMs] to seed the high-watermark so
  /// resume-seek is counted.
  void startTracking({int startPositionMs = 0}) {
    _cancel();
    _completionFired = false;
    state = PlaybackProgressState(maxPositionMs: startPositionMs);

    _subscribeToPosition();
    _startPeriodicSave();
    _startCompletionPoll();
  }

  /// Stops all timers and subscriptions.
  void stopTracking() => _cancel();

  /// Clears the pending completion event (e.g. user dismissed
  /// the overlay or started the next episode).
  void clearCompletionEvent() {
    state = state.copyWith(clearCompletionEvent: true);
  }

  /// Saves the current high-watermark to [WatchHistoryService].
  ///
  /// Safe to call from [dispose] — uses [ref.read] which is
  /// valid even when the notifier is being torn down.
  void saveNow() {
    if (state.maxPositionMs <= 0 || state.maxDurationMs <= 0) return;
    final session = ref.read(playbackSessionProvider);
    _persist(session);
  }

  // ── Pure helpers ────────────────────────────────────────

  /// Returns the next episode after the currently-playing one,
  /// or `null` when there is none.
  static VodItem? findNextEpisode(PlaybackSessionState session) {
    final episodes = session.episodeList;
    if (episodes == null || session.episodeNumber == null) return null;
    final idx = episodes.indexWhere(
      (e) => e.episodeNumber == session.episodeNumber,
    );
    if (idx >= 0 && idx < episodes.length - 1) return episodes[idx + 1];
    return null;
  }

  // ── Private ─────────────────────────────────────────────

  void _subscribeToPosition() {
    _positionSub = ref.listen<AsyncValue<PlaybackState>>(
      playbackStateProvider,
      (_, next) {
        final ps = next.value;
        if (ps == null) return;

        bool updated = false;
        int pos = state.maxPositionMs;
        int dur = state.maxDurationMs;

        if (ps.position.inMilliseconds > pos) {
          pos = ps.position.inMilliseconds;
          updated = true;
        }
        if (ps.duration.inMilliseconds > dur) {
          dur = ps.duration.inMilliseconds;
          updated = true;
        }

        if (updated && pos > 0 && dur > 0) {
          state = state.copyWith(maxPositionMs: pos, maxDurationMs: dur);
          final now = DateTime.now();
          if (_lastSaveTime == null ||
              now.difference(_lastSaveTime!).inSeconds >= 5) {
            _lastSaveTime = now;
            final session = ref.read(playbackSessionProvider);
            _persist(session);
          }
        }
      },
      fireImmediately: true,
    );
  }

  void _startPeriodicSave() {
    _periodicSaveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final session = ref.read(playbackSessionProvider);
      _persist(session);
    });
  }

  void _startCompletionPoll() {
    _completionPollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_completionFired) {
        timer.cancel();
        return;
      }
      final asyncState = ref.read(playbackStateProvider);
      final ps = asyncState.value;
      if (ps == null || ps.status == PlaybackStatus.paused) return;
      if (ps.duration.inMilliseconds <= 0) return;
      if (ps.progress < kCompletionThreshold) return;

      _completionFired = true;
      timer.cancel();

      final session = ref.read(playbackSessionProvider);
      if (session.mediaType == 'episode' && session.episodeList != null) {
        final next = findNextEpisode(session);
        if (next != null) {
          state = state.copyWith(completionEvent: NextEpisodeAvailable(next));
          return;
        }
      }
      if (!session.isLive) {
        state = state.copyWith(completionEvent: const ContentFinished());
      }
    });
  }

  void _persist(PlaybackSessionState session) {
    if (state.maxPositionMs <= 0 || state.maxDurationMs <= 0) return;
    final id = WatchHistoryService.deriveId(session.streamUrl);
    ref
        .read(watchHistoryServiceProvider)
        .record(
          id: id,
          mediaType: session.mediaType ?? 'movie',
          name: session.channelName ?? 'Unknown',
          streamUrl: session.streamUrl,
          posterUrl:
              session.posterUrl ??
              session.seriesPosterUrl ??
              session.channelLogoUrl,
          seriesPosterUrl: session.seriesPosterUrl,
          positionMs: state.maxPositionMs,
          durationMs: state.maxDurationMs,
          seriesId: session.seriesId,
          seasonNumber: session.seasonNumber,
          episodeNumber: session.episodeNumber,
        );
  }

  void _cancel() {
    _positionSub?.close();
    _positionSub = null;
    _periodicSaveTimer?.cancel();
    _periodicSaveTimer = null;
    _completionPollTimer?.cancel();
    _completionPollTimer = null;
  }
}

// ─────────────────────────────────────────────────────────────
//  Provider
// ─────────────────────────────────────────────────────────────

/// Provider for [PlaybackProgressNotifier].
///
/// Lifecycle is managed by [PlayerHistoryMixin] via
/// [PlaybackProgressNotifier.startTracking] and
/// [PlaybackProgressNotifier.stopTracking].
final playbackProgressProvider =
    NotifierProvider<PlaybackProgressNotifier, PlaybackProgressState>(
      PlaybackProgressNotifier.new,
    );
