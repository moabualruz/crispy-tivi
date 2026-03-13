import 'package:flutter/material.dart';

import '../theme/crispy_spacing.dart';
import 'shimmer_wrapper.dart';

/// Skeleton shimmer list row placeholder matching list row shape.
///
/// Renders a leading circle (avatar placeholder) and rectangular
/// text line placeholders (title + subtitle) with a shimmer animation.
///
/// ```dart
/// SkeletonListRowWidget()
/// SkeletonListRowWidget(showLeadingCircle: false, textLines: 1)
/// ```
class SkeletonListRowWidget extends StatelessWidget {
  /// Creates a skeleton list row placeholder.
  const SkeletonListRowWidget({
    this.showLeadingCircle = true,
    this.textLines = 2,
    super.key,
  });

  /// Whether to show a circular leading placeholder. Default: true.
  final bool showLeadingCircle;

  /// Number of text line placeholders to show. Default: 2.
  final int textLines;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseColor = cs.surfaceContainerHighest;

    return ShimmerWrapper(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CrispySpacing.md,
          vertical: CrispySpacing.sm,
        ),
        child: Row(
          children: [
            if (showLeadingCircle) ...[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: baseColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: CrispySpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < textLines; i++) ...[
                    if (i > 0) const SizedBox(height: CrispySpacing.xs),
                    Container(
                      height: i == 0 ? 14 : 10,
                      // First line wider, subsequent lines shorter
                      width: i == 0 ? double.infinity : 120,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
