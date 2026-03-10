import 'dart:ui';

import 'package:flutter/material.dart';

import 'smart_image.dart';

/// A full-bleed backdrop that optionally blurs a network image behind [child].
///
/// When [imageUrl] is null or fails to load, the widget simply renders [child]
/// on a transparent background so callers never need to guard the null case.
///
/// ```dart
/// BlurBackdrop(
///   imageUrl: item.posterUrl,
///   child: DetailPanel(item: item),
/// )
/// ```
class BlurBackdrop extends StatelessWidget {
  /// Creates a [BlurBackdrop].
  ///
  /// [imageUrl] may be null — the backdrop is omitted in that case.
  const BlurBackdrop({
    super.key,
    required this.imageUrl,
    this.sigma = 20.0,
    this.opacity = 0.3,
    required this.child,
  });

  /// Network URL for the backdrop image. Null → no backdrop rendered.
  final String? imageUrl;

  /// Gaussian blur radius applied to the backdrop image.
  ///
  /// Higher values produce a more aggressive blur. Defaults to `20.0`.
  final double sigma;

  /// Opacity of the blurred backdrop layer (0.0–1.0). Defaults to `0.3`.
  final double opacity;

  /// Widget rendered on top of the blurred backdrop.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl != null)
          Positioned.fill(
            child: Semantics(
              label: 'Blurred backdrop image',
              child: Opacity(
                opacity: opacity,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: SmartImage(
                    imageUrl: imageUrl!,
                    // Decorative backdrop — no title needed for placeholder.
                    title: '',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        child,
      ],
    );
  }
}
