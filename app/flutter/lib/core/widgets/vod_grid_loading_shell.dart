import 'package:flutter/material.dart';

import '../theme/crispy_spacing.dart';
import 'skeleton_loader.dart';

/// Skeleton loading grid for VOD poster content.
///
/// Renders a [GridView] of [SkeletonCard] items using
/// [SliverGridDelegateWithMaxCrossAxisExtent] so the column count
/// is automatically responsive to the available width.
///
/// Use this as a drop-in loading placeholder wherever a VOD
/// poster grid is displayed while data is being fetched.
///
/// ```dart
/// if (state.isLoading) {
///   return const VodGridLoadingShell();
/// }
/// ```
///
/// Parameters mirror [GridView.builder] delegate fields so callers
/// can match the exact grid geometry of the real content grid.
class VodGridLoadingShell extends StatelessWidget {
  /// Creates a VOD grid loading skeleton.
  const VodGridLoadingShell({
    super.key,
    this.itemCount = 12,
    this.maxCrossAxisExtent = 200,
    this.childAspectRatio = 2 / 3,
    this.mainAxisSpacing = CrispySpacing.sm,
    this.crossAxisSpacing = CrispySpacing.xs,
    this.padding = const EdgeInsets.all(CrispySpacing.md),
  });

  /// Number of skeleton cards to render.
  final int itemCount;

  /// Maximum width of each skeleton card column.
  /// Matches the equivalent [SliverGridDelegateWithMaxCrossAxisExtent]
  /// parameter on the real content grid.
  final double maxCrossAxisExtent;

  /// Card width-to-height ratio. Defaults to 2:3 (portrait poster).
  final double childAspectRatio;

  /// Vertical gap between skeleton card rows.
  final double mainAxisSpacing;

  /// Horizontal gap between skeleton card columns.
  final double crossAxisSpacing;

  /// Padding around the entire grid.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCrossAxisExtent,
        childAspectRatio: childAspectRatio,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
      ),
      itemCount: itemCount,
      itemBuilder: (_, _) => const SkeletonCard(),
    );
  }
}
