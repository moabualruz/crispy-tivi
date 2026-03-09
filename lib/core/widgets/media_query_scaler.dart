import 'package:flutter/material.dart';

/// Scales the entire UI by [scale] factor for distance viewing on TV.
///
/// Wraps the child in a [FittedBox] with an enlarged [MediaQuery] so
/// all widgets render larger. Only active when [enable] is `true`
/// (typically on Android TV form factor).
///
/// Useful for distance viewing on Android TV.
class MediaQueryScaler extends StatelessWidget {
  const MediaQueryScaler({
    required this.child,
    required this.enable,
    this.scale = 1.3,
    super.key,
  });

  final Widget child;

  /// Whether scaling is active. When `false`, returns [child] directly.
  final bool enable;

  /// The scale multiplier applied to the entire UI.
  final double scale;

  @override
  Widget build(BuildContext context) {
    if (!enable) return child;
    final mediaQuery = MediaQuery.of(context);
    final screenSize = MediaQuery.sizeOf(context) * scale;

    final scaledMedia = mediaQuery.copyWith(
      size: screenSize,
      padding: mediaQuery.padding * scale,
      viewInsets: mediaQuery.viewInsets * scale,
      viewPadding: mediaQuery.viewPadding * scale,
      devicePixelRatio: mediaQuery.devicePixelRatio * scale,
    );

    return FittedBox(
      alignment: Alignment.center,
      child: SizedBox(
        width: screenSize.width,
        height: screenSize.height,
        child: MediaQuery(data: scaledMedia, child: child),
      ),
    );
  }
}
