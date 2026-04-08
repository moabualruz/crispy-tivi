import 'package:flutter/material.dart';

/// Computes a TV scale factor based on physical pixel width.
///
/// Returns a multiplier for text and UI elements on TV screens:
/// - 1080p (1920px): 1.0x (baseline)
/// - 1440p (2560px): ~1.25x (interpolated)
/// - 4K (3840px): ~1.5x (interpolated)
/// - Above 4K: capped at 1.5x
///
/// Interpolation is linear between breakpoints for smooth
/// scaling across non-standard resolutions.
double computeTvScaleFactor(double physicalWidth) {
  if (physicalWidth <= 1920) return 1.0;
  if (physicalWidth <= 2560) {
    return 1.0 + (physicalWidth - 1920) / (2560 - 1920) * 0.25;
  }
  if (physicalWidth <= 3840) {
    return 1.25 + (physicalWidth - 2560) / (3840 - 2560) * 0.25;
  }
  return 1.5;
}

/// Widget that applies resolution-based text scaling for TV displays.
///
/// Derives the physical pixel width from [MediaQuery] and applies
/// [computeTvScaleFactor] as a [TextScaler] override. At 1080p the
/// scale factor is 1.0 (no change). At 4K it reaches 1.5x.
///
/// Wrap this around TV/large layout content in [ScreenTemplate] so
/// all text and scaled widgets grow proportionally on higher-resolution
/// displays.
///
/// ```dart
/// TvScaleFactor(child: MyTvLayout())
/// ```
class TvScaleFactor extends StatelessWidget {
  /// Creates a TV scale factor wrapper.
  const TvScaleFactor({required this.child, super.key});

  /// The widget subtree to scale.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final physicalWidth = mq.size.width * mq.devicePixelRatio;
    final factor = computeTvScaleFactor(physicalWidth);

    if (factor == 1.0) return child;

    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.linear(factor)),
      child: child,
    );
  }
}
