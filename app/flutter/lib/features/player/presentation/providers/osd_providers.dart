import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/toggle_notifier.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/utils/input_mode_notifier.dart';

// ─────────────────────────────────────────────────────────────
//  OSD Visibility — 3-state machine
// ─────────────────────────────────────────────────────────────

/// OSD visibility state: visible → fading → hidden.
enum OsdState { visible, fading, hidden }

/// Whether the OSD overlay is currently visible (compat shim).
final osdVisibleProvider = Provider<bool>((ref) {
  final state = ref.watch(osdStateProvider);
  return state != OsdState.hidden;
});

/// Full OSD state provider.
final osdStateProvider = NotifierProvider<OsdStateNotifier, OsdState>(
  OsdStateNotifier.new,
);

/// Controls OSD visibility with 3 states and timers.
///
/// Supports pause-pinning (OSD stays visible when paused),
/// freeze/unfreeze for hover lock, and input-adaptive timeouts.
class OsdStateNotifier extends Notifier<OsdState> {
  Timer? _hideTimer;
  Timer? _fadeTimer;

  /// Whether playback is currently paused.
  bool _isPaused = false;

  /// Whether the timer is frozen due to mouse hover over controls.
  bool _frozen = false;

  /// When the current hide timer was started (used for freeze tracking).
  DateTime? _timerStartedAt;

  /// Remaining time when the timer was frozen.
  Duration? _remainingWhenFrozen;

  /// Current auto-hide timeout (input-adaptive).
  Duration _timeout = CrispyAnimation.osdAutoHide;

  static const _fadeDuration = CrispyAnimation.osdHide;

  @override
  OsdState build() {
    ref.onDispose(() {
      _hideTimer?.cancel();
      _fadeTimer?.cancel();
    });
    return OsdState.visible;
  }

  /// Shows the OSD and resets the auto-hide timer.
  ///
  /// When paused, OSD is shown but no auto-hide timer is started.
  void show() {
    _frozen = false;
    _remainingWhenFrozen = null;
    _hideTimer?.cancel();
    _fadeTimer?.cancel();
    state = OsdState.visible;
    if (!_isPaused) {
      _resetTimer();
    }
  }

  /// Hides the OSD immediately.
  void hide() {
    _hideTimer?.cancel();
    _fadeTimer?.cancel();
    state = OsdState.hidden;
  }

  /// Toggles the OSD visibility.
  void toggle() {
    if (state != OsdState.hidden) {
      hide();
    } else {
      show();
    }
  }

  /// Called when playback playing state changes.
  ///
  /// When paused, cancels timers so OSD stays visible indefinitely.
  /// When resumed, restarts the timer if OSD is currently visible.
  void onPlaybackStateChanged(bool isPlaying) {
    _isPaused = !isPlaying;
    if (_isPaused) {
      // Pause: cancel timers so OSD stays pinned.
      _hideTimer?.cancel();
      _fadeTimer?.cancel();
      _timerStartedAt = null;
      _remainingWhenFrozen = null;
      if (state == OsdState.fading) {
        state = OsdState.visible;
      }
    } else {
      // Resume: restart timer if OSD is visible and not frozen.
      if (state != OsdState.hidden && !_frozen) {
        _resetTimer();
      }
    }
  }

  /// Freezes the auto-hide timer while the mouse hovers over controls.
  ///
  /// Records remaining time so it can be restored on [unfreezeTimer].
  void freezeTimer() {
    if (_frozen) return;
    _frozen = true;
    if (_timerStartedAt != null && _hideTimer != null) {
      final elapsed = DateTime.now().difference(_timerStartedAt!);
      final remaining = _timeout - elapsed;
      _remainingWhenFrozen = remaining.isNegative ? Duration.zero : remaining;
    }
    _hideTimer?.cancel();
    _fadeTimer?.cancel();
  }

  /// Unfreezes the timer after the mouse leaves controls.
  ///
  /// Restores remaining time (or full timeout when paused stays pinned).
  void unfreezeTimer() {
    if (!_frozen) return;
    _frozen = false;
    if (_isPaused) {
      // Paused: OSD stays pinned, don't restart.
      return;
    }
    if (state != OsdState.hidden) {
      final delay = _remainingWhenFrozen ?? _timeout;
      _remainingWhenFrozen = null;
      _timerStartedAt = DateTime.now();
      _hideTimer?.cancel();
      _hideTimer = Timer(delay, () {
        state = OsdState.fading;
        _fadeTimer?.cancel();
        _fadeTimer = Timer(_fadeDuration, () {
          state = OsdState.hidden;
        });
      });
    }
  }

  /// Updates the auto-hide timeout based on the active [InputMode].
  ///
  /// - [InputMode.mouse] / [InputMode.touch] → 4 seconds
  /// - [InputMode.keyboard] / [InputMode.gamepad] → 6 seconds
  void updateTimeout(InputMode mode) {
    final next = switch (mode) {
      InputMode.keyboard || InputMode.gamepad => const Duration(seconds: 6),
      InputMode.mouse || InputMode.touch => CrispyAnimation.osdAutoHide,
    };
    _timeout = next;
  }

  void _resetTimer() {
    _hideTimer?.cancel();
    _timerStartedAt = DateTime.now();
    _hideTimer = Timer(_timeout, () {
      state = OsdState.fading;
      _fadeTimer?.cancel();
      _fadeTimer = Timer(_fadeDuration, () {
        state = OsdState.hidden;
      });
    });
  }
}

/// Syncs input mode changes to OSD timeout.
final osdTimeoutSyncProvider = Provider<void>((ref) {
  final mode = ref.watch(inputModeProvider);
  ref.read(osdStateProvider.notifier).updateTimeout(mode);
});

// ─────────────────────────────────────────────────────────────
//  Touch lock state
// ─────────────────────────────────────────────────────────────

/// Whether the player touch/gesture lock is active.
///
/// When `true`, all gestures except a 2-second long-press
/// are ignored by [PlayerGestureMixin] and the
/// [LockIndicator] overlay is shown.
final playerLockedProvider = NotifierProvider<PlayerLockedNotifier, bool>(
  PlayerLockedNotifier.new,
);

/// Notifier backing [playerLockedProvider].
class PlayerLockedNotifier extends ToggleNotifier {
  /// Sets the lock state explicitly.
  void setLocked({required bool value}) => state = value;
}

// ─────────────────────────────────────────────────────────────
//  FE-PS-19: Video zoom scale (pinch-to-zoom)
// ─────────────────────────────────────────────────────────────

/// Pinch-to-zoom scale for the video surface.
///
/// Clamped to 1.0–3.0 by [PlayerGestureMixin]. The video
/// surface in [PermanentVideoLayer] reads this to apply
/// [Transform.scale]. Resets to 1.0 when playback stops
/// or the player session changes.
final videoZoomScaleProvider = NotifierProvider<VideoZoomNotifier, double>(
  VideoZoomNotifier.new,
);

/// Notifier for the video zoom scale.
class VideoZoomNotifier extends Notifier<double> {
  @override
  double build() => 1.0;

  /// Updates the zoom scale (expected range: 1.0–3.0).
  void setScale(double scale) => state = scale;

  /// Resets zoom to 1.0.
  void reset() => state = 1.0;
}
