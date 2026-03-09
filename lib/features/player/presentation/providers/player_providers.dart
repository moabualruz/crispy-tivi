import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/cache_service.dart';
import '../../../../core/providers/toggle_notifier.dart';
import '../../data/adaptive_buffer.dart';
import '../../data/player_service.dart';
import '../../domain/crispy_player.dart';
import '../../domain/entities/playback_state.dart';
import 'player_mode_provider.dart';

export 'cursor_providers.dart';
export 'osd_providers.dart';
export 'playback_session_provider.dart';
export 'player_mode_provider.dart';
export 'player_settings_providers.dart';

/// Global [PlayerService] provider — single instance.
final playerServiceProvider = Provider<PlayerService>((ref) {
  final cache = ref.watch(cacheServiceProvider);
  final bufferManager = AdaptiveBufferManager(cacheService: cache)..init();
  final service = PlayerService(bufferManager: bufferManager);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provides the [CrispyPlayer] for the Video widget.
final playerProvider = Provider<CrispyPlayer>((ref) {
  return ref.watch(playerServiceProvider).player;
});

/// Stream-based provider of [PlaybackState] snapshots.
final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  final service = ref.watch(playerServiceProvider);
  return service.stateStream;
});

// ─────────────────────────────────────────────────────────────
//  Playback Selectors — surgical rebuild providers
// ─────────────────────────────────────────────────────────────

/// Derived provider: playback status only.
/// Rebuilds only when status changes (not on position/
/// volume updates). Requires PlaybackState == (BUG-17).
final playbackStatusProvider = Provider<PlaybackStatus>((ref) {
  return ref.watch(
    playbackStateProvider.select((s) => s.value?.status ?? PlaybackStatus.idle),
  );
});

/// Derived provider: playback position only.
/// Updates at ~4 Hz (throttled by PlayerServiceBase).
final playbackPositionProvider = Provider<Duration>((ref) {
  return ref.watch(
    playbackStateProvider.select((s) => s.value?.position ?? Duration.zero),
  );
});

/// Derived provider: volume only.
final playbackVolumeProvider = Provider<double>((ref) {
  return ref.watch(playbackStateProvider.select((s) => s.value?.volume ?? 1.0));
});

/// Tracks the stream URL that has been fully synced (seek-to-position,
/// watch history recording, etc.) by [PlayerFullscreenOverlay._syncSession].
///
/// Survives fullscreen ↔ mini-player transitions so the overlay
/// does not re-seek to saved position on re-mount. Cleared when
/// the player goes idle.
class LastSyncedStreamUrlNotifier extends Notifier<String?> {
  @override
  String? build() {
    ref.listen(playerModeProvider.select((s) => s.mode), (prev, next) {
      if (next == PlayerMode.idle) state = null;
    });
    return null;
  }

  void set(String url) => state = url;
}

final lastSyncedStreamUrlProvider =
    NotifierProvider<LastSyncedStreamUrlNotifier, String?>(
      LastSyncedStreamUrlNotifier.new,
    );

/// Whether a player backend handoff is currently in progress.
///
/// Set to `true` by [PlayerHandoffManager] while switching between
/// backends (e.g. media_kit → AndroidHdrPlayer). The
/// [HandoffOverlay] watches this to show a brief loading indicator.
final handoffInProgressProvider =
    NotifierProvider<HandoffInProgressNotifier, bool>(
      HandoffInProgressNotifier.new,
    );

/// Simple boolean notifier for handoff state.
class HandoffInProgressNotifier extends ToggleNotifier {}

/// Whether the TV guide split-screen is active.
///
/// When true, the player shrinks to 50% width (left half) and
/// a live EPG guide grid fills the right half. Only meaningful
/// on large layouts (landscape).
final guideSplitProvider = NotifierProvider<GuideSplitNotifier, bool>(
  GuideSplitNotifier.new,
);

/// Toggle notifier for guide split-screen state.
class GuideSplitNotifier extends ToggleNotifier {}

// ─────────────────────────────────────────────────────────────
//  Buffer cache range provider — 4Hz throttled polling
// ─────────────────────────────────────────────────────────────

/// Polls [PlayerService.getCacheRanges] every 250ms (4Hz).
///
/// Returns normalized `(start, end)` pairs for the
/// [BufferRangePainter] on the seek bar. Auto-disposes when
/// no widgets watch it.
final bufferRangesProvider =
    NotifierProvider.autoDispose<BufferRangesNotifier, List<(double, double)>>(
      BufferRangesNotifier.new,
    );

/// Notifier that polls cache ranges at 250ms intervals.
class BufferRangesNotifier extends Notifier<List<(double, double)>> {
  Timer? _timer;

  @override
  List<(double, double)> build() {
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _poll());
    ref.onDispose(() => _timer?.cancel());
    return const [];
  }

  void _poll() {
    final service = ref.read(playerServiceProvider);
    final ranges = service.getCacheRanges();
    if (!_rangesEqual(state, ranges)) {
      state = ranges;
    }
  }

  static bool _rangesEqual(List<(double, double)> a, List<(double, double)> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].$1 != b[i].$1 || a[i].$2 != b[i].$2) return false;
    }
    return true;
  }
}
