import 'package:flutter/material.dart';

import '../theme/crispy_colors.dart';

/// A bottom-vignette gradient overlay used in cinematic hero banners.
///
/// Three variants are provided:
///
/// - **[VignetteGradient.new]** — 5-stop cinematic vignette using the fixed
///   [CrispyColors.vignetteStart] / [CrispyColors.vignetteEnd] tokens,
///   suitable for dark hero areas where the background is always black
///   (e.g. [CinematicHeroBanner]).
///
/// - **[VignetteGradient.surfaceAdaptive]** — 5-stop vignette that blends
///   into the theme's current surface color, suitable for areas where the
///   card/surface color varies (e.g. series hero header).
///
/// - **[VignetteGradient.surfaceScrim]** — 2-stop soft scrim that fades
///   from transparent to 92% surface opacity. Useful for text-legibility
///   overlays that need a lighter, shorter gradient (e.g. VOD featured hero).
///
/// Usage:
/// ```dart
/// Stack(
///   fit: StackFit.expand,
///   children: [
///     HeroImage(),
///     const VignetteGradient(),              // fixed dark vignette
///     VignetteGradient.surfaceAdaptive(),    // blends into surface color
///     // or inside Positioned.fill:
///     Positioned.fill(child: VignetteGradient.surfaceScrim()),
///   ],
/// )
/// ```
class VignetteGradient extends StatelessWidget {
  /// Creates a bottom vignette that fades to pure black.
  ///
  /// The gradient uses five stops:
  /// `[transparent → transparent → vignetteStart → vignetteEnd → black]`
  /// at positions `[0.0, 0.3, 0.6, 0.85, 1.0]`.
  const VignetteGradient({super.key}) : _variant = _Variant.dark;

  /// Creates a bottom vignette that fades to the current [ColorScheme.surface].
  ///
  /// This variant reads [Theme.of(context)] to resolve the surface color at
  /// build time, making it suitable for widgets that respect dynamic theming.
  ///
  /// The gradient uses five stops:
  /// `[surface(0%) → surface(0%) → vignetteStart → vignetteEnd → surface]`
  /// at positions `[0.0, 0.3, 0.6, 0.85, 1.0]`.
  const VignetteGradient.surfaceAdaptive({super.key})
    : _variant = _Variant.surfaceAdaptive;

  /// Creates a lightweight 2-stop scrim that fades from transparent to
  /// the current [ColorScheme.surface] at 92% opacity.
  ///
  /// The gradient starts at the 40% mark to preserve image clarity in the
  /// upper portion while providing enough contrast for overlaid text at the
  /// bottom. Use this inside [Positioned.fill] for full-stack coverage.
  ///
  /// Stops: `[transparent → surface(92%)]` at `[0.4, 1.0]`.
  const VignetteGradient.surfaceScrim({super.key})
    : _variant = _Variant.surfaceScrim;

  final _Variant _variant;

  @override
  Widget build(BuildContext context) {
    switch (_variant) {
      case _Variant.surfaceAdaptive:
        final surface = Theme.of(context).colorScheme.surface;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                surface.withValues(alpha: 0),
                surface.withValues(alpha: 0),
                CrispyColors.vignetteStart,
                CrispyColors.vignetteEnd,
                surface,
              ],
              stops: const [0.0, 0.3, 0.6, 0.85, 1.0],
            ),
          ),
        );

      case _Variant.surfaceScrim:
        final surface = Theme.of(context).colorScheme.surface;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.4, 1.0],
              colors: [Colors.transparent, surface.withValues(alpha: 0.92)],
            ),
          ),
        );

      case _Variant.dark:
        return const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.transparent,
                CrispyColors.vignetteStart,
                CrispyColors.vignetteEnd,
                Colors.black,
              ],
              stops: [0.0, 0.3, 0.6, 0.85, 1.0],
            ),
          ),
        );
    }
  }
}

enum _Variant { dark, surfaceAdaptive, surfaceScrim }
