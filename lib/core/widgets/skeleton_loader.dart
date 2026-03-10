import 'package:flutter/material.dart';

import '../theme/crispy_radius.dart';
import '../theme/crispy_spacing.dart';
import 'shimmer_wrapper.dart';

/// Shimmer loading placeholder per `.ai/docs/project-specs/design_system.md §2.3`.
///
/// Displays a gradient sweep shimmer animation to indicate loading.
/// Use the specific variants for common patterns:
/// - [SkeletonLine] — text line placeholder
/// - [SkeletonCard] — image card placeholder with optional title/subtitle
/// - [SkeletonAvatar] — circular avatar placeholder
/// - [SkeletonGrid] — responsive grid of skeleton cards
/// - [SkeletonRow] — horizontal scrolling row of skeleton cards
class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    required this.width,
    required this.height,
    this.borderRadius = CrispyRadius.sm,
    super.key,
  });

  /// Width of the skeleton block.
  final double width;

  /// Height of the skeleton block.
  final double height;

  /// Corner rounding. Defaults to [CrispyRadius.sm].
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;

    return ShimmerWrapper(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Single-line text skeleton.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({
    this.width = double.infinity,
    this.height = 16,
    super.key,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      width: width,
      height: height,
      borderRadius: CrispyRadius.xs,
    );
  }
}

/// Card / image skeleton with optional title and subtitle lines.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    this.width = 140,
    this.aspectRatio = 2 / 3,
    this.showTitle = false,
    this.showSubtitle = false,
    this.borderRadius,
    super.key,
  });

  final double width;
  final double aspectRatio;

  /// Show a title line placeholder below the image area.
  final bool showTitle;

  /// Show a shorter subtitle line below the title.
  final bool showSubtitle;

  /// Custom border radius. Defaults to [CrispyRadius.md].
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? CrispyRadius.md;
    final imageHeight = width / aspectRatio;

    if (!showTitle && !showSubtitle) {
      return SkeletonLoader(
        width: width,
        height: imageHeight,
        borderRadius: radius,
      );
    }

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SkeletonLoader(
            width: width,
            height: imageHeight,
            borderRadius: radius,
          ),
          if (showTitle) ...[
            const SizedBox(height: CrispySpacing.xs),
            SkeletonLoader(
              width: width * 0.8,
              height: 12,
              borderRadius: CrispyRadius.xs,
            ),
          ],
          if (showSubtitle) ...[
            const SizedBox(height: CrispySpacing.xs),
            SkeletonLoader(
              width: width * 0.6,
              height: 8,
              borderRadius: CrispyRadius.xs,
            ),
          ],
        ],
      ),
    );
  }
}

/// Circular avatar skeleton.
class SkeletonAvatar extends StatelessWidget {
  const SkeletonAvatar({this.size = 48, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      width: size,
      height: size,
      borderRadius: CrispyRadius.full,
    );
  }
}

/// A responsive grid of [SkeletonCard] items.
///
/// Use as a loading placeholder for grid-based content screens
/// (channel list, VOD browser, etc.).
class SkeletonGrid extends StatelessWidget {
  const SkeletonGrid({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 3,
    this.aspectRatio = 16 / 9,
    this.showTitle = true,
    this.padding = const EdgeInsets.all(CrispySpacing.md),
  });

  final int itemCount;
  final int crossAxisCount;
  final double aspectRatio;
  final bool showTitle;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    // Account for title/subtitle height in the child aspect ratio.
    final titleExtra = showTitle ? (CrispySpacing.xs + 12) : 0.0;
    final effectiveRatio = aspectRatio / (1 + titleExtra * aspectRatio / 100);

    return GridView.builder(
      padding: padding,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: CrispySpacing.sm,
        crossAxisSpacing: CrispySpacing.sm,
        childAspectRatio: effectiveRatio,
      ),
      itemCount: itemCount,
      itemBuilder:
          (_, _) => SkeletonCard(
            width: double.infinity,
            aspectRatio: aspectRatio,
            showTitle: showTitle,
          ),
    );
  }
}

/// A horizontal row of [SkeletonCard] items.
///
/// Use as a loading placeholder for horizontal scroll sections
/// on the home screen.
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({
    super.key,
    this.itemCount = 5,
    this.cardWidth = 160,
    this.aspectRatio = 16 / 9,
    this.showTitle = true,
  });

  final int itemCount;
  final double cardWidth;
  final double aspectRatio;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final imageHeight = cardWidth / aspectRatio;
    final titleExtra = showTitle ? (CrispySpacing.xs + 12) : 0.0;
    final totalHeight = imageHeight + titleExtra;

    return SizedBox(
      height: totalHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.md),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(width: CrispySpacing.sm),
        itemBuilder:
            (_, _) => SkeletonCard(
              width: cardWidth,
              aspectRatio: aspectRatio,
              showTitle: showTitle,
            ),
      ),
    );
  }
}
