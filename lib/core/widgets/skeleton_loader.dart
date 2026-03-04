import 'package:flutter/material.dart';

import '../theme/crispy_animation.dart';
import '../theme/crispy_radius.dart';

/// Shimmer loading placeholder per `.ai/docs/project-specs/design_system.md §2.3`.
///
/// Displays a pulsing opacity animation (0.4↔0.7) to indicate
/// loading. Use the specific variants for common patterns:
/// - [SkeletonLine] — text line placeholder
/// - [SkeletonCard] — image card placeholder
/// - [SkeletonAvatar] — circular avatar placeholder
class SkeletonLoader extends StatefulWidget {
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

  /// Corner rounding. Defaults to [CrispyRadius.sm] (0).
  final double borderRadius;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: CrispyAnimation.skeletonPulse,
    )..repeat(reverse: true);

    _opacity = Tween<double>(
      begin: 0.4,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;

    return AnimatedBuilder(
      animation: _opacity,
      builder:
          (context, child) => Opacity(opacity: _opacity.value, child: child),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.zero,
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

/// Card / image skeleton with 2:3 aspect ratio by default.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({this.width = 140, this.aspectRatio = 2 / 3, super.key});

  final double width;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      width: width,
      height: width / aspectRatio,
      borderRadius: CrispyRadius.md,
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
