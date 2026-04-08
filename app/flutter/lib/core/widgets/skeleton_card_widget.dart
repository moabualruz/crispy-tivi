import 'package:flutter/material.dart';

import '../theme/crispy_radius.dart';
import 'shimmer_wrapper.dart';

/// Skeleton shimmer card placeholder matching card layout shape.
///
/// Used as a loading state placeholder for content cards. Wraps a
/// neutral-colored container in [ShimmerWrapper] for the shimmer effect.
///
/// ```dart
/// SkeletonCardWidget(width: 160, height: 200)
/// ```
class SkeletonCardWidget extends StatelessWidget {
  /// Creates a skeleton card placeholder.
  const SkeletonCardWidget({
    required this.width,
    required this.height,
    this.borderRadius,
    super.key,
  });

  /// Card width.
  final double width;

  /// Card height.
  final double height;

  /// Optional border radius. Defaults to [CrispyRadius.sm].
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ShimmerWrapper(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: borderRadius ?? BorderRadius.circular(CrispyRadius.sm),
        ),
      ),
    );
  }
}
