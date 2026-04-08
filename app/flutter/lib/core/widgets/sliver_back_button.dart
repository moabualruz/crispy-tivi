import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/crispy_colors.dart';
import '../theme/crispy_spacing.dart';

/// A [Padding] + [Container] + [IconButton] back-button widget
/// designed for use as the `leading:` of a [SliverAppBar].
///
/// Defaults mirror the cinematic hero banner style (black-54
/// background, high-emphasis white icon). Callers can override
/// [backgroundColor] and [iconColor] to match their surface palette.
///
/// ```dart
/// SliverAppBar(
///   leading: SliverBackButton(),
///   // ...
/// )
/// ```
class SliverBackButton extends StatelessWidget {
  const SliverBackButton({
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    super.key,
  });

  /// Called when the button is tapped.
  ///
  /// Defaults to [GoRouter.pop] when null.
  final VoidCallback? onPressed;

  /// Background color of the button container.
  ///
  /// Defaults to [Colors.black54].
  final Color? backgroundColor;

  /// Color of the [Icons.arrow_back] icon.
  ///
  /// Defaults to [CrispyColors.textHigh].
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(CrispySpacing.sm),
      child: Container(
        color: backgroundColor ?? Colors.black54,
        child: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: iconColor ?? CrispyColors.textHigh,
          ),
          tooltip: 'Back',
          onPressed: onPressed ?? () => context.pop(),
        ),
      ),
    );
  }
}
