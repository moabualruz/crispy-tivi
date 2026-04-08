import 'package:flutter/material.dart';

import '../theme/crispy_spacing.dart';

// ─────────────────────────────────────────────────────────────
//  DensityMode — grid spacing density control
// ─────────────────────────────────────────────────────────────

/// Grid density options that adjust spacing and column counts.
///
/// Persisted in settings via [kGridDensityKey].
enum DensityMode {
  /// More items, smaller cards, tighter spacing.
  compact,

  /// Default balanced spacing.
  comfortable,

  /// Fewer items, larger cards, generous spacing.
  spacious,
}

/// Convenience getters for [DensityMode] layout values.
extension DensityModeExtension on DensityMode {
  /// Grid spacing (mainAxisSpacing / crossAxisSpacing).
  double get gridSpacing => switch (this) {
    DensityMode.compact => CrispySpacing.xs,
    DensityMode.comfortable => CrispySpacing.sm,
    DensityMode.spacious => CrispySpacing.md,
  };

  /// Column count adjustment relative to the responsive default.
  ///
  /// Add this to the base `crossAxisCount`:
  /// - `compact`: +1 column (smaller cards, more visible)
  /// - `comfortable`: 0 (default)
  /// - `spacious`: −1 column (larger cards, fewer visible)
  int get columnCountAdjustment => switch (this) {
    DensityMode.compact => 1,
    DensityMode.comfortable => 0,
    DensityMode.spacious => -1,
  };

  /// Human-readable label for UI display.
  String get label => switch (this) {
    DensityMode.compact => 'Compact',
    DensityMode.comfortable => 'Comfortable',
    DensityMode.spacious => 'Spacious',
  };

  /// Icon representing this density mode.
  IconData get icon => switch (this) {
    DensityMode.compact => Icons.density_small,
    DensityMode.comfortable => Icons.density_medium,
    DensityMode.spacious => Icons.density_large,
  };
}
