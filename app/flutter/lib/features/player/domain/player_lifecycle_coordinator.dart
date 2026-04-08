import 'entities/playback_state.dart';
import 'entities/player_mode.dart';

/// Pure validation utility for player mode + playback status
/// combinations.
///
/// This is a stateless class with static methods — no state,
/// no providers. It cross-checks [PlayerMode] and
/// [PlaybackStatus] to enforce consistency between the display
/// layer (mode) and the media layer (status).
class PlayerLifecycleCoordinator {
  PlayerLifecycleCoordinator._();

  /// Whether the [mode] and [status] combination is valid.
  ///
  /// Invalid combinations:
  /// - fullscreen + idle (can't show fullscreen with no media)
  /// - preview + idle (can't show preview with no media)
  static bool isValidCombination(PlayerMode mode, PlaybackStatus status) {
    if (mode == PlayerMode.fullscreen && status == PlaybackStatus.idle) {
      return false;
    }
    if (mode == PlayerMode.preview && status == PlaybackStatus.idle) {
      return false;
    }
    return true;
  }

  /// Whether the mini-player bar should be visible.
  ///
  /// True when mode is [PlayerMode.background] AND status
  /// indicates active media (playing, paused, or buffering).
  static bool shouldShowMiniPlayer(PlayerMode mode, PlaybackStatus status) {
    if (mode != PlayerMode.background) return false;
    return status == PlaybackStatus.playing ||
        status == PlaybackStatus.paused ||
        status == PlaybackStatus.buffering;
  }

  /// Whether the video surface should be mounted in the
  /// widget tree.
  ///
  /// True when mode is [PlayerMode.preview] or
  /// [PlayerMode.fullscreen].
  static bool shouldMountSurface(PlayerMode mode, PlaybackStatus status) {
    return mode == PlayerMode.preview || mode == PlayerMode.fullscreen;
  }

  /// Whether the video surface should be visible (not just
  /// mounted).
  ///
  /// True when [shouldMountSurface] AND status is not idle.
  static bool shouldShowSurface(PlayerMode mode, PlaybackStatus status) {
    return shouldMountSurface(mode, status) && status != PlaybackStatus.idle;
  }
}
