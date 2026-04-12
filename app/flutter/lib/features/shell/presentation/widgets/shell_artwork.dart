import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/features/shell/domain/shell_models.dart';
import 'package:flutter/material.dart';

class ShellArtwork extends StatelessWidget {
  const ShellArtwork({
    required this.source,
    required this.borderRadius,
    this.overlay,
    super.key,
  });

  final ArtworkSource? source;
  final BorderRadius borderRadius;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          DecoratedBox(
            decoration: CrispyShellRoles.artworkFallbackDecoration(),
          ),
          if (source != null)
            Image(
              image: source!.provider(),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              frameBuilder: (
                BuildContext context,
                Widget child,
                int? frame,
                bool wasSynchronouslyLoaded,
              ) {
                if (wasSynchronouslyLoaded || frame != null) {
                  return child;
                }
                return const SizedBox.expand();
              },
              errorBuilder:
                  (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) => const SizedBox.expand(),
            ),
          if (overlay != null) Positioned.fill(child: overlay!),
        ],
      ),
    );
  }
}

class ArtworkTitleSafeOverlay extends StatelessWidget {
  const ArtworkTitleSafeOverlay({required this.decoration, super.key});

  final Decoration decoration;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(decoration: decoration);
  }
}

class ArtworkMetadataChip extends StatelessWidget {
  const ArtworkMetadataChip({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: CrispyShellRoles.infoPlateDecoration(),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CrispyOverhaulTokens.small,
          vertical: CrispyOverhaulTokens.compact,
        ),
        child: child,
      ),
    );
  }
}
