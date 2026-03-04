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

  // ── Scales ─────────────────────────────────────────────────

  /// Scale multiplier when a card is focused or hovered.
  static const double hoverScale = 1.1;
}
