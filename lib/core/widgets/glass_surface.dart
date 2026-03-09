import 'dart:ui';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/crispy_animation.dart';
import '../theme/crispy_colors.dart';
import '../theme/crispy_radius.dart';
import '../theme/theme_provider.dart';

/// A translucent, blurred surface that implements the glassmorphism
/// design pattern from `.ai/docs/project-specs/design_system.md §2.1`.
///
/// Use for OSD overlays, floating panels, and modal backdrops.
///
/// ```dart
/// GlassSurface(
///   borderRadius: CrispyRadius.lg,
///   child: Padding(
///     padding: EdgeInsets.all(CrispySpacing.md),
///     child: Text('Hello'),
///   ),
/// )
/// ```
class GlassSurface extends ConsumerWidget {
  const GlassSurface({
    required this.child,
    this.borderRadius = CrispyRadius.lg,
    this.blurSigma,
    this.tintColor,
    this.borderColor,
    this.padding,
    super.key,
  });

  /// Content inside the glass surface.
  final Widget child;

  /// Corner radius. Defaults to [CrispyRadius.lg] (0).
  final double borderRadius;

  /// Blur intensity. Defaults to [CrispyColors.glassBlur] (20).
  final double? blurSigma;

  /// Surface tint. Defaults to theme's [CrispyColors.glassTint].
  final Color? tintColor;

  /// Border color. Defaults to subtle white edge.
  final Color? borderColor;

  /// Internal padding.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crispy = Theme.of(context).crispyColors;
    final glassOpacity = ref.watch(themeProvider.select((s) => s.glassOpacity));
    final baseSigma = blurSigma ?? crispy.glassBlur;
    final sigma = baseSigma * glassOpacity;
    final tint = tintColor ?? crispy.glassTint;
    final border = borderColor ?? Colors.white10;

    // Skip expensive BackdropFilter on desktop/web where GPU
    // blur causes high CPU/GPU spikes with multiple surfaces.
    // Also skip on Android TV form factor (width >= 1200dp) to
    // protect weaker TV SoC GPU budget during video playback.
    final isTvFormFactor =
        defaultTargetPlatform == TargetPlatform.android &&
        MediaQuery.sizeOf(context).width >= 1200;
    final useBlur =
        !kIsWeb && _isMobilePlatform && sigma >= 0.5 && !isTvFormFactor;

    final radius = BorderRadius.circular(borderRadius);

    if (!useBlur) {
      return AnimatedContainer(
        duration: CrispyAnimation.fast,
        decoration: BoxDecoration(
          color: tint,
          border: Border.all(color: border),
          borderRadius: radius,
        ),
        padding: padding,
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: AnimatedContainer(
          duration: CrispyAnimation.fast,
          decoration: BoxDecoration(
            color: tint,
            border: Border.all(color: border),
            borderRadius: radius,
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }

  /// True on Android and iOS only.
  static bool get _isMobilePlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}
