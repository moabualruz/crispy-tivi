import 'package:flutter/material.dart';

/// Elevation shadow presets for CrispyTivi.
///
/// Matches `.ai/docs/project-specs/design_system.md §1.6`. Use these instead of
/// raw `BoxShadow` or `elevation` values.
///
/// ```dart
/// decoration: BoxDecoration(
///   boxShadow: CrispyElevation.level1,
/// ),
/// ```
abstract final class CrispyElevation {
  /// Level 0 — flat, no shadow (backgrounds).
  static const List<BoxShadow> level0 = [];

  /// Level 1 — subtle lift (cards, sidebar).
  static const List<BoxShadow> level1 = [
    BoxShadow(
      color: Color(0x4D000000), // black 30%
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
  ];

  /// Level 2 — medium lift (modals, dropdowns).
  static const List<BoxShadow> level2 = [
    BoxShadow(
      color: Color(0x61000000), // black 38%
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// Level 3 — strong lift (OSD, floating controls).
  static const List<BoxShadow> level3 = [
    BoxShadow(
      color: Color(0x73000000), // black 45%
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}
