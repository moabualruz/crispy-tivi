import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants.dart';
import '../../data/watch_history_service.dart';
import '../../domain/entities/playback_state.dart';
import '../../domain/segment_skip_config.dart';
import '../../domain/utils/skip_segment_utils.dart';
import 'player_providers.dart';
import 'playback_progress_state.dart';
import 'playback_session_provider.dart';

export 'playback_progress_state.dart';

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

  /// Tracks consecutive auto-advances without user interaction.
  /// Resets when the user manually plays, cancels, or presses a button.
  int _consecutiveAutoAdvances = 0;

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

  /// Records an auto-advance (countdown expired without user cancel).
  ///
  /// When the count reaches [kStillWatchingThreshold], emits a
  /// [StillWatchingPrompt] instead of the normal [NextEpisodeAvailable]
  /// on the next completion.
  void recordAutoAdvance() => _consecutiveAutoAdvances++;

  /// Resets the auto-advance counter (user interacted — pressed
  /// cancel, manually selected an episode, or confirmed "Still Watching").
  void resetAutoAdvanceCounter() => _consecutiveAutoAdvances = 0;

  /// Saves the current high-watermark to [WatchHistoryService].
  ///
  /// Safe to call from [dispose] — uses [ref.read] which is
  /// valid even when the notifier is being torn down.
  void saveNow() {
    if (state.maxPositionMs <= 0 || state.maxDurationMs <= 0) return;
    final session = ref.read(playbackSessionProvider);
    _persist(session);
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

  /// Seconds before end at which the static next-up trigger fires.
  static const _kStaticNextUpSeconds = 32;

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

      final nextUpMode = ref.read(nextUpModeProvider);

      // NextUpMode.off: only fire at kCompletionThreshold for
      // content-finished state (watch history), never for next-up.
      // NextUpMode.static: fire at 32s before end.
      // NextUpMode.smart: fire when position enters an outro segment.
      final bool shouldFire;
      switch (nextUpMode) {
        case NextUpMode.off:
          shouldFire = ps.progress >= kCompletionThreshold;
        case NextUpMode.static:
          final remainingMs =
              ps.duration.inMilliseconds - ps.position.inMilliseconds;
          shouldFire =
              remainingMs <= _kStaticNextUpSeconds * 1000 && ps.progress >= 0.5;
        case NextUpMode.smart:
          shouldFire = _isInOutroSegment(ps);
      }

      if (!shouldFire) return;

      _completionFired = true;
      timer.cancel();

      final session = ref.read(playbackSessionProvider);

      // For NextUpMode.off, only mark content as finished — never
      // show the next-up overlay.
      if (nextUpMode == NextUpMode.off) {
        if (!session.isLive && ps.progress >= kCompletionThreshold) {
          state = state.copyWith(completionEvent: const ContentFinished());
        }
        return;
      }

      if (session.mediaType == 'episode' && session.episodeList != null) {
        final next = findNextEpisode(session);
        if (next != null) {
          // Check if "Still Watching?" prompt should appear instead
          // of the normal next-episode countdown.
          if (_consecutiveAutoAdvances >= kStillWatchingThreshold) {
            state = state.copyWith(
              completionEvent: StillWatchingPrompt(
                next,
                _consecutiveAutoAdvances,
              ),
            );
          } else {
            state = state.copyWith(completionEvent: NextEpisodeAvailable(next));
          }
          return;
        }
      }
      if (!session.isLive) {
        state = state.copyWith(completionEvent: const ContentFinished());
      }
    });
  }

  /// Whether the current position is inside an outro/credits segment.
  bool _isInOutroSegment(PlaybackState ps) {
    if (ps.skipSegments.isEmpty) {
      // No segment data — fall back to static 32s trigger.
      final remainingMs =
          ps.duration.inMilliseconds - ps.position.inMilliseconds;
      return remainingMs <= _kStaticNextUpSeconds * 1000 && ps.progress >= 0.5;
    }
    for (final seg in ps.skipSegments) {
      if (!seg.containsPosition(ps.position)) continue;
      final type = inferSegmentType(seg, ps.skipSegments);
      if (type == SegmentType.outro) return true;
    }
    return false;
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
          sourceId: session.sourceId,
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
