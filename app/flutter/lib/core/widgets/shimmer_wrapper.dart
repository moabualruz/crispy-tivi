import 'package:flutter/material.dart';

import '../theme/crispy_animation.dart';

/// Wraps a child widget in a left-to-right gradient sweep shimmer effect.
///
/// Used by skeleton loading placeholders to indicate content is loading.
/// Respects `MediaQuery.disableAnimations` for reduced motion accessibility.
///
/// ```dart
/// ShimmerWrapper(
///   child: Container(
///     width: 200,
///     height: 100,
///     color: Colors.grey,
///   ),
/// )
/// ```
class ShimmerWrapper extends StatefulWidget {
  const ShimmerWrapper({super.key, required this.child});

  final Widget child;

  @override
  State<ShimmerWrapper> createState() => _ShimmerWrapperState();
}

class _ShimmerWrapperState extends State<ShimmerWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: CrispyAnimation.skeletonPulse,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    if (disableAnimations) return widget.child;

    final cs = Theme.of(context).colorScheme;
    final baseColor = cs.surfaceContainerHighest;
    final highlightColor = cs.surfaceContainerLow;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                (value - 0.3).clamp(0.0, 1.0),
                value.clamp(0.0, 1.0),
                (value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
