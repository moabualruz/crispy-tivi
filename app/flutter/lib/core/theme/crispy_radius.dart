import 'package:flutter/material.dart';

/// Consistent border-radius scale for CrispyTivi.
///
/// Matches `the project design system documentation §1.7`. Always use these tokens
/// instead of raw `BorderRadius.circular(N)`.
///
/// ```dart
/// borderRadius: BorderRadius.circular(CrispyRadius.md),
/// ```
abstract final class CrispyRadius {
  /// 0 px — no radius.
  static const double none = 0.0;

  /// TV Default Sharp Radius (2px)
  static const double tv = 2.0;

  /// Extra small radius for badges (1px)
  static const double tvSm = 1.0;

  // Legacy variable mappings (migrating to tv)
  static const double xs = tvSm;
  static const double sm = tv;
  static const double md = tv;
  static const double lg = tv;
  static const double xl = tv;
  static const double full = tv;

  /// 1.5 px — thin progress bars and seek bars.
  ///
  /// Applied to player OSD progress/seek bars (3 px tall tracks).
  static const double progressBar = 1.5;

  // ── Convenience constructors ──────────────────────────────

  /// Uniform radius for all corners.
  static BorderRadius all(double radius) => BorderRadius.circular(radius);

  /// Top-only radius (for bottom sheets, cards docked at bottom).
  static BorderRadius top(double radius) => BorderRadius.only(
    topLeft: Radius.circular(radius),
    topRight: Radius.circular(radius),
  );

  /// Bottom-only radius.
  static BorderRadius bottom(double radius) => BorderRadius.only(
    bottomLeft: Radius.circular(radius),
    bottomRight: Radius.circular(radius),
  );
}
