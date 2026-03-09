import 'dart:async';
import 'dart:math' as math;

import '../../domain/crispy_player.dart';

/// Dynamically shifts mpv `sub-pos` when the OSD bottom bar
/// is visible, preventing subtitles from being obscured.
///
/// When controls appear, subtitles animate upward by the bar
/// height + padding. When controls hide, subtitles return to
/// the user's configured position.
class SubtitlePositionManager {
  SubtitlePositionManager({required CrispyPlayer player}) : _player = player;

  final CrispyPlayer _player;

  /// User's configured vertical position (0=top, 100=bottom).
  int _userPosition = 100;

  /// Current animated sub-pos value.
  double _currentPos = 100;

  /// Target sub-pos value being animated toward.
  double _targetPos = 100;

  /// Animation timer for smooth transitions.
  Timer? _animTimer;

  /// Step interval (~60fps).
  static const _stepInterval = Duration(milliseconds: 16);

  /// Pixel padding above the bar.
  static const _padding = 16.0;

  /// Exposed for testing.
  double get currentPos => _currentPos;

  /// Updates the user's base subtitle position preference.
  void updateUserPosition(int position) {
    _userPosition = position;
    // If not currently shifted (OSD hidden), update immediately.
    if ((_targetPos - _currentPos).abs() < 0.5) {
      _currentPos = position.toDouble();
      _targetPos = position.toDouble();
    }
  }

  /// Called when OSD visibility changes.
  ///
  /// [visible] should be `true` when the OSD is fully shown
  /// (not fading). When the OSD starts fading or is hidden,
  /// subtitles animate back to [_userPosition].
  void onOsdVisibilityChanged({
    required bool visible,
    required double barHeightPx,
    required double videoHeightPx,
    double zoomScale = 1.0,
  }) {
    if (videoHeightPx <= 0) return;

    if (visible) {
      final target = calculateShiftedPosition(
        userPosition: _userPosition,
        barHeightPx: barHeightPx,
        videoHeightPx: videoHeightPx,
        zoomScale: zoomScale,
      );
      _targetPos = target.toDouble();
    } else {
      _targetPos = _userPosition.toDouble();
    }

    _animateTo(_targetPos);
  }

  /// Calculates the target sub-pos when OSD is visible.
  ///
  /// Pure function for testability. Returns the mpv sub-pos
  /// value (0=top, 100=bottom) shifted upward by the bar
  /// height + padding, adjusted for zoom scale.
  static int calculateShiftedPosition({
    required int userPosition,
    required double barHeightPx,
    required double videoHeightPx,
    double zoomScale = 1.0,
  }) {
    if (videoHeightPx <= 0) return userPosition;
    final effectiveHeight = videoHeightPx * zoomScale;
    final shiftPercent = (barHeightPx + _padding) / effectiveHeight * 100;
    return math.max(0, (userPosition - shiftPercent).round());
  }

  /// Number of animation steps: _animDuration / _stepInterval.
  static const _totalSteps =
      200 ~/ 16; // _animDuration.inMilliseconds ~/ _stepInterval.inMilliseconds

  void _animateTo(double target) {
    _animTimer?.cancel();

    final startPos = _currentPos;
    final delta = target - startPos;
    if (delta.abs() < 0.5) {
      // Close enough — snap.
      _currentPos = target;
      _player.setProperty('sub-pos', '${target.round()}');
      return;
    }

    var step = 0;

    _animTimer = Timer.periodic(_stepInterval, (timer) {
      step++;
      final t = (step / _totalSteps).clamp(0.0, 1.0);

      // Ease-out curve: 1 - (1-t)^2
      final eased = 1 - (1 - t) * (1 - t);

      _currentPos = startPos + delta * eased;
      _player.setProperty('sub-pos', '${_currentPos.round()}');

      if (step >= _totalSteps) {
        _currentPos = target;
        _player.setProperty('sub-pos', '${target.round()}');
        timer.cancel();
      }
    });
  }

  /// Disposes animation resources.
  void dispose() {
    _animTimer?.cancel();
  }
}
