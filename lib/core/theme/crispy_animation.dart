import 'package:flutter/material.dart';

/// Animation duration and curve constants for CrispyTivi.
///
/// Matches `.ai/docs/project-specs/design_system.md §4`. Never use raw
/// `Duration(milliseconds: N)` or `Curves.X` in feature code.
///
/// ```dart
/// AnimatedContainer(
///   duration: CrispyAnimation.normal,
///   curve: CrispyAnimation.enterCurve,
/// )
/// ```
abstract final class CrispyAnimation {
  // ── Durations ──────────────────────────────────────────────

  /// 150 ms — focus changes, hover effects, micro-interactions.
  static const Duration fast = Duration(milliseconds: 150);

  /// 300 ms — page transitions, modal open, standard animations.
  static const Duration normal = Duration(milliseconds: 300);

  /// 500 ms — complex transitions, staggered lists.
  static const Duration slow = Duration(milliseconds: 500);

  // ── Curves ─────────────────────────────────────────────────

  /// Enter animations (elements appearing).
  static const Curve enterCurve = Curves.easeOutCubic;

  /// Exit animations (elements disappearing).
  static const Curve exitCurve = Curves.easeIn;

  /// Focus ring and hover effects.
  static const Curve focusCurve = Curves.ease;

  /// Bouncy effects (notifications, badges).
  static const Curve bounceCurve = Curves.easeOutBack;

  /// Modal open (subtle overshoot).
  static const Curve modalCurve = Curves.easeOutQuint;

  // ── OSD-specific ───────────────────────────────────────────

  /// OSD slide-up + fade in.
  static const Duration osdShow = Duration(milliseconds: 200);

  /// OSD fade out.
  static const Duration osdHide = Duration(milliseconds: 300);

  /// Time before OSD auto-hides after last interaction (V2: 4s).
  static const Duration osdAutoHide = Duration(seconds: 4);

  // ── Skeleton loading ───────────────────────────────────────

  /// Shimmer pulse cycle duration.
  static const Duration skeletonPulse = Duration(milliseconds: 1500);

  // ── Live badge ─────────────────────────────────────────────

  /// LIVE indicator pulse cycle.
  static const Duration livePulse = Duration(seconds: 2);

  // ── Player seek ────────────────────────────────────────────

  /// Seek step for skip-back / skip-forward actions.
  static const Duration seekStep = Duration(seconds: 10);

  // ── Feedback / UI ──────────────────────────────────────────

  /// Duration for brief snackbar / notification messages (2 s).
  static const Duration snackBarDuration = Duration(seconds: 2);

  /// Duration for longer toast / informational messages (3 s).
  static const Duration toastDuration = Duration(seconds: 3);

  /// Auto-advance interval for hero banner carousels (8 s).
  static const Duration heroAdvanceInterval = Duration(seconds: 8);

  /// Delay before a trailer starts on a featured (auto-cycling) hero (2 s).
  ///
  /// Shorter than [trailerDelay] because the featured hero cycles every 8 s
  /// and needs the trailer to begin quickly.
  static const Duration trailerDelayFeatured = Duration(seconds: 2);

  /// Delay before a trailer starts on a static hero banner card (3 s).
  static const Duration trailerDelay = Duration(seconds: 3);

  // ── Scales ─────────────────────────────────────────────────

  /// Scale multiplier when a card is focused or hovered.
  static const double hoverScale = 1.1;
}
