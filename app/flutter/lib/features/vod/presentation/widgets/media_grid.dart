import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_spacing.dart';
import 'vod_search_sort_bar.dart';

/// A generic sliver grid for media poster cards (movies, series, etc.).
///
/// Callers supply an [itemBuilder] that produces each card widget.
/// The grid handles layout, spacing, and density; all item-specific
/// logic (context menus, overlays, navigation) lives in [itemBuilder].
///
/// Typical usage:
/// ```dart
/// MediaGrid(
///   items: movies,
///   density: _density,
///   tagPrefix: 'grid_movies',
///   itemBuilder: (context, item) => MyCard(item: item),
/// )
/// ```
class MediaGrid<T> extends StatelessWidget {
  const MediaGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.maxExtent,
    this.crossSpacingExtra = CrispySpacing.xs,
    this.mainSpacingExtra = CrispySpacing.sm,
    this.semanticIndexCallback,
  });

  /// The data items to display.
  final List<T> items;

  /// Builds the widget for a single [item].
  ///
  /// The builder receives the item (NOT an index) — index-aware
  /// logic (e.g. autofocus on first item) must be handled inside
  /// the caller's closure.
  final Widget Function(BuildContext context, T item, bool autofocus)
  itemBuilder;

  /// Maximum card extent passed to [SliverGridDelegateWithMaxCrossAxisExtent].
  final double maxExtent;

  /// Flat extra space added to the hover-gap formula for cross-axis spacing.
  ///
  /// - VOD movies grid uses [CrispySpacing.xs] (tighter).
  /// - Series grid uses [CrispySpacing.sm] (slightly looser).
  final double crossSpacingExtra;

  /// Flat extra space added to the hover-gap formula for main-axis spacing.
  ///
  /// - VOD movies grid uses [CrispySpacing.sm].
  /// - Series grid uses [CrispySpacing.md].
  final double mainSpacingExtra;

  /// Optional semantic index callback forwarded to [SliverChildBuilderDelegate].
  final SemanticIndexCallback? semanticIndexCallback;

  @override
  Widget build(BuildContext context) {
    final double crossSpacing =
        (maxExtent * (CrispyAnimation.hoverScale - 1.0)) + crossSpacingExtra;
    final double mainSpacing =
        (maxExtent * 1.5 * (CrispyAnimation.hoverScale - 1.0)) +
        mainSpacingExtra;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.md),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxExtent,
          childAspectRatio: 2 / 3,
          mainAxisSpacing: mainSpacing,
          crossAxisSpacing: crossSpacing,
        ),
        delegate: SliverChildBuilderDelegate(
          (ctx, i) => itemBuilder(context, items[i], i == 0),
          childCount: items.length,
          semanticIndexCallback: semanticIndexCallback ?? (_, index) => index,
        ),
      ),
    );
  }
}

/// Convenience factory that computes [maxExtent] from a [VodGridDensity]
/// and the current screen width.
///
/// Use this overload for VOD movie grids where density is user-selectable.
class VodDensityMediaGrid<T> extends StatelessWidget {
  const VodDensityMediaGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.density = VodGridDensity.standard,
    this.crossSpacingExtra = CrispySpacing.xs,
    this.mainSpacingExtra = CrispySpacing.sm,
    this.semanticIndexCallback,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item, bool autofocus)
  itemBuilder;
  final VodGridDensity density;
  final double crossSpacingExtra;
  final double mainSpacingExtra;
  final SemanticIndexCallback? semanticIndexCallback;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return MediaGrid<T>(
      items: items,
      itemBuilder: itemBuilder,
      maxExtent: density.maxCardExtent(w),
      crossSpacingExtra: crossSpacingExtra,
      mainSpacingExtra: mainSpacingExtra,
      semanticIndexCallback: semanticIndexCallback,
    );
  }
}
