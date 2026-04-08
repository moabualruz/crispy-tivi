import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/player_mode.dart';

export '../../domain/entities/player_mode.dart';

/// State for the player mode system.
class PlayerModeState {
  const PlayerModeState({
    this.mode = PlayerMode.idle,
    this.previewRect,
    this.hostRoute,
    this.currentRoute,
    this.originRoute,
    this.isRectOnlyUpdate = false,
  });

  /// Current display mode.
  final PlayerMode mode;

  /// Where the video appears in preview mode (global
  /// coordinates relative to the AppShell Stack).
  final Rect? previewRect;

  /// Which route/screen owns the current preview or
  /// fullscreen session. Used to restore preview on
  /// fullscreen exit.
  final String? hostRoute;

  /// Current GoRouter path, updated by AppShell on every
  /// build (shell routes) and by [_reportRoute] for
  /// non-shell routes. Used by [PermanentVideoLayer] to
  /// hide the video when navigating away from the host.
  final String? currentRoute;

  /// The route the user was on when [enterFullscreen] was
  /// called. Snapshotted from [currentRoute] at the moment
  /// of transition. Cleared on exit. Screens can read this
  /// to restore focus/scroll position on return.
  final String? originRoute;

  /// Whether this state update only changed the preview
  /// rect (no mode transition). When true, the video
  /// layer should snap to the new position instead of
  /// animating — avoids desync with sidebar animations
  /// where the Platform View lags behind.
  final bool isRectOnlyUpdate;

  /// Whether the video should be visible in preview mode.
  /// True when [currentRoute] matches [hostRoute].
  bool get isOnHostRoute {
    if (hostRoute == null || currentRoute == null) return true;
    return currentRoute!.startsWith(hostRoute!);
  }

  PlayerModeState copyWith({
    PlayerMode? mode,
    Rect? previewRect,
    String? hostRoute,
    String? currentRoute,
    String? originRoute,
    bool clearPreviewRect = false,
    bool clearHostRoute = false,
    bool clearOriginRoute = false,
    bool isRectOnlyUpdate = false,
  }) {
    return PlayerModeState(
      mode: mode ?? this.mode,
      previewRect: clearPreviewRect ? null : (previewRect ?? this.previewRect),
      hostRoute: clearHostRoute ? null : (hostRoute ?? this.hostRoute),
      currentRoute: currentRoute ?? this.currentRoute,
      originRoute: clearOriginRoute ? null : (originRoute ?? this.originRoute),
      isRectOnlyUpdate: isRectOnlyUpdate,
    );
  }
}

/// Controls the player display mode.
///
/// Screens call [enterPreview], [enterFullscreen], etc.
/// to transition the single video surface between modes.
/// [PermanentVideoLayer] in AppShell reads this state to
/// position/size the Video widget via AnimatedPositioned.
class PlayerModeNotifier extends Notifier<PlayerModeState> {
  /// Valid transitions between player modes.
  ///
  /// Every mode except [PlayerMode.idle] as a target from idle
  /// requires active media. The only invalid transition is
  /// idle -> background (no media to background).
  static const _validTransitions = {
    PlayerMode.idle: {PlayerMode.preview, PlayerMode.fullscreen},
    PlayerMode.preview: {
      PlayerMode.fullscreen,
      PlayerMode.background,
      PlayerMode.idle,
    },
    PlayerMode.fullscreen: {
      PlayerMode.preview,
      PlayerMode.background,
      PlayerMode.idle,
    },
    PlayerMode.background: {
      PlayerMode.preview,
      PlayerMode.fullscreen,
      PlayerMode.idle,
    },
  };

  /// Throws [StateError] if transitioning from [from] to [to]
  /// is not a valid player mode transition.
  void _validateTransition(PlayerMode from, PlayerMode to) {
    if (from == to) return;
    final allowed = _validTransitions[from] ?? const {};
    if (!allowed.contains(to)) {
      throw StateError('Invalid PlayerMode transition: $from -> $to');
    }
  }

  @override
  PlayerModeState build() => const PlayerModeState();

  /// Show video in a screen-specific preview area.
  void enterPreview(Rect rect, {String? hostRoute}) {
    _validateTransition(state.mode, PlayerMode.preview);
    state = PlayerModeState(
      mode: PlayerMode.preview,
      previewRect: rect,
      hostRoute: hostRoute ?? state.hostRoute,
    );
  }

  /// Expand video to fill the entire screen with OSD.
  ///
  /// Snapshots [currentRoute] into [originRoute] so screens
  /// can verify/restore state when the user returns.
  void enterFullscreen({String? hostRoute}) {
    // Skip redundant state emission when already in fullscreen
    // at the same host route — prevents re-triggering transitions
    // (e.g. channel_list_screen calls enterFullscreen immediately,
    // then startPlayback calls it again after play() completes).
    if (state.mode == PlayerMode.fullscreen &&
        (hostRoute == null || hostRoute == state.hostRoute)) {
      return;
    }
    _validateTransition(state.mode, PlayerMode.fullscreen);
    state = state.copyWith(
      mode: PlayerMode.fullscreen,
      hostRoute: hostRoute,
      originRoute: state.currentRoute,
    );
  }

  /// Routes that support in-app video preview (mini PiP corner).
  /// All other routes show only the MiniPlayerBar (audio continues).
  static const _kPreviewRoutes = {'/tv', '/epg'};

  /// Collapse from fullscreen back to the preview area.
  ///
  /// When a screen-specific preview rect exists, transitions to
  /// [PlayerMode.preview] at that rect. Otherwise, if [screenSize]
  /// is provided AND the host route supports video preview (TV or
  /// EPG), enters a mini PiP corner. All other screens fall back
  /// to [PlayerMode.background] (audio only, MiniPlayerBar shows).
  void exitToPreview({Size? screenSize}) {
    if (state.previewRect != null) {
      _validateTransition(state.mode, PlayerMode.preview);
      state = state.copyWith(mode: PlayerMode.preview, clearOriginRoute: true);
    } else if (screenSize != null &&
        _kPreviewRoutes.contains(state.hostRoute)) {
      _validateTransition(state.mode, PlayerMode.preview);
      _enterMiniPipCorner(screenSize);
    } else {
      _validateTransition(state.mode, PlayerMode.background);
      state = state.copyWith(
        mode: PlayerMode.background,
        clearOriginRoute: true,
      );
    }
  }

  /// Positions the video as a small 16:9 PiP in the bottom-right
  /// corner, above the [MiniPlayerBar] (60 dp + padding).
  ///
  /// Size: ~18% of screen width, clamped to 120–200 dp.
  /// Reference: YouTube mini player ~160 dp, VLC ~200 dp.
  void _enterMiniPipCorner(Size screenSize) {
    final pipWidth = (screenSize.width * 0.18).clamp(120.0, 200.0);
    final pipHeight = pipWidth * (9.0 / 16.0);
    const padding = 16.0;
    const miniBarHeight = 76.0; // 60 bar + 16 spacing
    final rect = Rect.fromLTWH(
      screenSize.width - pipWidth - padding,
      screenSize.height - pipHeight - miniBarHeight,
      pipWidth,
      pipHeight,
    );
    state = state.copyWith(
      mode: PlayerMode.preview,
      previewRect: rect,
      clearOriginRoute: true,
    );
  }

  /// Keep audio playing but hide the video surface.
  void exitToBackground() {
    _validateTransition(state.mode, PlayerMode.background);
    state = state.copyWith(mode: PlayerMode.background);
  }

  /// Stop everything — no video, no audio.
  void setIdle() {
    state = const PlayerModeState();
  }

  /// Update the preview rect (e.g. after layout change,
  /// scroll, or window resize).
  void updatePreviewRect(Rect rect) {
    if (state.previewRect != rect) {
      state = state.copyWith(previewRect: rect, isRectOnlyUpdate: true);
    }
  }

  /// Stops video preview if navigating away from the host
  /// screen, then updates the current route.
  ///
  /// Call this (with [stopPlayback]) before [GoRouter.go] so
  /// the platform view is removed before the new route's
  /// first frame renders.
  ///
  /// On web, [AnimatedOpacity] does not reliably hide HTML
  /// platform views — we must fully remove the element by
  /// transitioning to idle.
  ///
  /// [stopPlayback] is called only when leaving the host
  /// screen in preview mode. Pass [PlayerService.stop].
  void stopPreviewIfLeavingRoute(
    String targetRoute, {
    required void Function() stopPlayback,
  }) {
    if (state.mode == PlayerMode.preview &&
        state.hostRoute != null &&
        !targetRoute.startsWith(state.hostRoute!)) {
      stopPlayback();
    }
    updateCurrentRoute(targetRoute);
  }

  /// Track the current GoRouter path. Called by AppShell
  /// on every build so [PermanentVideoLayer] can hide
  /// the video when navigating away from the host screen.
  ///
  /// When navigating away from the host screen while in
  /// preview mode, transitions to idle. This fully removes
  /// the WebHlsVideo widget from the tree — Flutter opacity
  /// does not reliably hide platform views on web, so we
  /// must remove the element rather than just fading it.
  ///
  /// Background mode is intentionally cross-screen
  /// (audio-only) and is NOT terminated here.
  ///
  /// Note: callers should invoke [PlayerService.stop] before
  /// calling this when leaving preview, to halt media_kit
  /// playback in addition to the state transition.
  void updateCurrentRoute(String path) {
    if (state.currentRoute == path) return;

    final isLeavingHost =
        state.mode == PlayerMode.preview &&
        state.hostRoute != null &&
        !path.startsWith(state.hostRoute!);

    if (isLeavingHost) {
      state = const PlayerModeState();
      return;
    }

    state = state.copyWith(currentRoute: path);
  }
}

/// Global player mode provider.
final playerModeProvider =
    NotifierProvider<PlayerModeNotifier, PlayerModeState>(
      PlayerModeNotifier.new,
    );
