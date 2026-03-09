import 'package:flutter/material.dart';

import '../theme/crispy_radius.dart';

/// Thin progress bar showing watch completion (0.0–1.0).
///
/// Wraps [LinearProgressIndicator] with rounded corners and
/// design-token colors. Use for VOD/series watch progress only —
/// do not use for buffering or loading indicators.
class WatchProgressBar extends StatelessWidget {
  const WatchProgressBar({
    required this.value,
    this.height = 3.0,
    this.fillColor,
    this.backgroundColor,
    super.key,
  });

  /// Fill ratio in range 0.0–1.0.
  final double value;

  /// Bar height in logical pixels (defaults to 3.0).
  final double height;

  /// Fill color; defaults to [ColorScheme.primary].
  final Color? fillColor;

  /// Track color; defaults to [ColorScheme.surfaceContainerHighest].
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(CrispyRadius.progressBar),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        color: fillColor ?? colorScheme.primary,
        backgroundColor: backgroundColor ?? colorScheme.surfaceContainerHighest,
      ),
    );
  }
}
