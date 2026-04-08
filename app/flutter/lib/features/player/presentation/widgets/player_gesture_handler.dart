import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_providers.dart';
import 'player_fullscreen_overlay.dart';
import 'player_gesture_overlays.dart';
import 'player_seek_utils.dart';

// FE-PS-19: Pinch-to-zoom constants.
const double _kZoomMin = 1.0;
const double _kZoomMax = 3.0;

/// Gesture handling mixin for [PlayerFullscreenOverlay].
///
/// Provides horizontal/vertical drag handling, scroll-wheel volume,
/// double-tap seek, brightness control via vertical swipe, and
/// long-press speed boost / scrub seek for touch input.
///
/// FE-PS-19: Also provides pinch-to-zoom via [onScaleUpdate] — scale
/// is clamped to [_kZoomMin]..[_kZoomMax]. Double-tap resets to 1.0.
mixin PlayerGestureMixin on ConsumerState<PlayerFullscreenOverlay> {
  // ── Gesture state ──
  SeekDirection? seekDirection;
  Timer? seekIndicatorTimer;
  double swipeDelta = 0;
  bool isSwiping = false;
  SwipeType? swipeType;
  final brightnessNotifier = ValueNotifier<double>(0.0);
  DateTime lastSwipeUpdate = DateTime(0);
  PointerDeviceKind lastPointerKind = PointerDeviceKind.touch;
  static const rightEdgeThreshold = 60.0;

  // FE-PS-19: Pinch-to-zoom state.
  double zoomScale = 1.0;
  double _zoomBase = 1.0;
  bool isPinching = false;
  Timer? _zoomIndicatorTimer;

  // ── Long-press / scrub constants ──
  /// Pixels of horizontal drag before switching to scrub mode.
  static const double _scrubActivationThreshold = 20.0;

  /// Milliseconds of seek per pixel of horizontal drag.
  /// 300 px ≈ 30 s at this ratio.
  static const int _scrubMsPerPx = 100;

  // ── Long-press state ──
  double? _savedSpeed;
  bool _isLongPressSeeking = false;

  void disposeGestures() {
    seekIndicatorTimer?.cancel();
    _zoomIndicatorTimer?.cancel();
    brightnessNotifier.dispose();
  }

  // FE-PS-19: Pinch-to-zoom handlers ─────────────────────────

  /// Whether the zoom percentage HUD should be visible.
  bool get showZoomIndicator => isPinching || zoomScale != 1.0;

  /// Human-readable zoom percentage, e.g. "150%".
  String get zoomPercentLabel => '${(zoomScale * 100).round()}%';

  /// Called when a scale gesture begins. Records the base scale.
  void onScaleStart(ScaleStartDetails details) {
    if (ref.read(playerLockedProvider)) return;
    if (details.pointerCount < 2) return;
    _zoomBase = zoomScale;
    setState(() => isPinching = true);
    _zoomIndicatorTimer?.cancel();
  }

  /// Called on every scale update. Clamps scale and rebuilds.
  void onScaleUpdate(ScaleUpdateDetails details) {
    if (!isPinching) return;
    if (details.pointerCount < 2) return;
    final newScale = (_zoomBase * details.scale).clamp(_kZoomMin, _kZoomMax);
    if (newScale != zoomScale) {
      setState(() => zoomScale = newScale);
      // Sync to provider so PermanentVideoLayer applies the scale.
      ref.read(videoZoomScaleProvider.notifier).setScale(newScale);
    }
  }

  /// Called when the scale gesture ends. Hides the indicator
  /// after a short delay so the user can see the final value.
  void onScaleEnd(ScaleEndDetails details) {
    if (!isPinching) return;
    setState(() => isPinching = false);
    _zoomIndicatorTimer?.cancel();
    _zoomIndicatorTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() {});
    });
  }

  /// Double-tap reset: reverts zoom to 1.0 when already zoomed.
  ///
  /// Called by the double-tap handler in [PlayerFullscreenOverlay]
  /// before the seek logic runs — only resets, does NOT seek.
  bool tryResetZoomOnDoubleTap() {
    if (zoomScale == 1.0) return false;
    setState(() => zoomScale = 1.0);
    ref.read(videoZoomScaleProvider.notifier).reset();
    _zoomIndicatorTimer?.cancel();
    return true;
  }

  void onPointerSignal(PointerSignalEvent event, bool isInPip) {
    // Lock check: scroll-wheel volume is blocked when locked.
    if (ref.read(playerLockedProvider)) return;
    if (event is PointerScrollEvent && !isInPip) {
      final svc = ref.read(playerServiceProvider);
      final d = event.scrollDelta.dy > 0 ? -0.05 : 0.05;
      svc.setVolume((svc.state.volume + d).clamp(0.0, 1.0));
      ref.read(osdStateProvider.notifier).show();
    }
  }

  void onDoubleTapDown(TapDownDetails d) {
    // Lock check: double-tap seek is blocked when locked.
    if (ref.read(playerLockedProvider)) return;
    // FE-PS-19: double-tap resets zoom first (doesn't seek).
    if (tryResetZoomOnDoubleTap()) return;
    final w = MediaQuery.sizeOf(context).width;
    triggerDoubleTapSeek(d.globalPosition.dx > w / 2);
  }

  void triggerDoubleTapSeek(bool forward) {
    final stepSeconds = ref.read(seekStepSecondsProvider);
    final step = Duration(seconds: stepSeconds);
    seekRelative(ref, forward ? step : -step);
    showSeekIndicator(forward);
  }

  /// Shows the seek direction indicator for 800ms.
  /// Used by both double-tap seek and keyboard seek.
  void showSeekIndicator(bool forward) {
    seekIndicatorTimer?.cancel();
    setState(() {
      seekDirection = forward ? SeekDirection.forward : SeekDirection.backward;
    });
    seekIndicatorTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => seekDirection = null);
    });
  }

  void onSwipeStart(DragStartDetails d) {
    // Lock check: swipe gestures are blocked when locked.
    if (ref.read(playerLockedProvider)) return;
    final w = MediaQuery.sizeOf(context).width;
    swipeType =
        d.globalPosition.dx > w / 2 ? SwipeType.volume : SwipeType.brightness;
    isSwiping = true;
    swipeDelta = 0;
  }

  void onSwipeUpdate(DragUpdateDetails d) {
    if (!isSwiping) return;
    swipeDelta += d.primaryDelta ?? 0;

    final now = DateTime.now();
    if (now.difference(lastSwipeUpdate).inMilliseconds < 50) return;
    lastSwipeUpdate = now;

    final h = MediaQuery.sizeOf(context).height;
    final delta = -swipeDelta / (h * 0.6);

    if (swipeType == SwipeType.volume) {
      final svc = ref.read(playerServiceProvider);
      svc.setVolume((svc.state.volume + delta).clamp(0.0, 1.0));
    } else {
      brightnessNotifier.value = (brightnessNotifier.value - delta).clamp(
        0.0,
        0.7,
      );
    }
    swipeDelta = 0;
  }

  // ── Long-press gestures (touch only) ──

  /// Touch long-press start: boosts playback speed to 2×.
  void onLongPressStart(LongPressStartDetails details) {
    // Long-press is blocked when locked (unlock is handled
    // by LockIndicator's own GestureDetector).
    if (ref.read(playerLockedProvider)) return;
    // Only for touch input, not mouse.
    if (lastPointerKind == PointerDeviceKind.mouse) return;
    final svc = ref.read(playerServiceProvider);
    // Save current speed and boost to 2x.
    _savedSpeed = svc.state.speed;
    _isLongPressSeeking = false;
    svc.setSpeed(2.0);
  }

  /// Touch long-press move: switches to scrub seek when
  /// horizontal drag exceeds 20px threshold.
  void onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_savedSpeed == null) return;
    // If horizontal drag exceeds threshold, switch to scrub seek.
    if (!_isLongPressSeeking &&
        details.offsetFromOrigin.dx.abs() > _scrubActivationThreshold) {
      _isLongPressSeeking = true;
      // Restore normal speed when switching to scrub mode.
      final svc = ref.read(playerServiceProvider);
      svc.setSpeed(_savedSpeed!);
    }
    if (_isLongPressSeeking) {
      final svc = ref.read(playerServiceProvider);
      final seekDelta = Duration(
        milliseconds: (details.offsetFromOrigin.dx * _scrubMsPerPx).round(),
      );
      final basePos = svc.state.position;
      final target = basePos + seekDelta;
      svc.seek(target < Duration.zero ? Duration.zero : target);
    }
  }

  /// Touch long-press end: restores speed if in boost mode.
  void onLongPressEnd(LongPressEndDetails details) {
    if (_savedSpeed != null) {
      if (!_isLongPressSeeking) {
        // Was in speed-boost mode — restore original speed.
        ref.read(playerServiceProvider).setSpeed(_savedSpeed!);
      }
      _savedSpeed = null;
      _isLongPressSeeking = false;
    }
  }
}
