import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Reusable CrispyTivi brand logo widget.
///
/// Renders the SVG logo tinted to the given [color] (defaults to
/// `colorScheme.primary`). Works at any size from 16 px nav icons
/// to 120 px splash screens.
class CrispyLogo extends StatelessWidget {
  /// Creates a CrispyTivi logo widget.
  const CrispyLogo({
    super.key,
    this.size = 48,
    this.color,
    this.semanticLabel = 'CrispyTivi logo',
  });

  /// The height (and bounding width) of the logo in logical pixels.
  final double size;

  /// Override color. Defaults to `colorScheme.primary` when null.
  final Color? color;

  /// Accessibility label read by screen readers.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.primary;

    return Semantics(
      label: semanticLabel,
      child: SvgPicture.asset(
        'assets/logo.svg',
        height: size,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
      ),
    );
  }
}
