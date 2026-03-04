import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/crispy_colors.dart';
import '../theme/crispy_spacing.dart';

/// A cinematic [SliverAppBar] with a hero-animated backdrop image,
/// a Netflix-style bottom vignette gradient, and a positioned
/// title/metadata column anchored to the bottom-left.
///
/// Usage:
/// ```dart
/// CustomScrollView(slivers: [
///   CinematicHeroBanner(
///     heroTag: item.id,
///     image: SmartImage(...),
///     titleColumn: Column(children: [...]),
///   ),
///   // ... other slivers
/// ])
/// ```
class CinematicHeroBanner extends StatelessWidget {
  const CinematicHeroBanner({
    required this.heroTag,
    required this.image,
    required this.titleColumn,
    this.expandedHeight = 500.0,
    this.actions = const [],
    super.key,
  });

  /// Tag passed to the [Hero] widget wrapping [image].
  final String heroTag;

  /// The backdrop/poster image widget (e.g. [SmartImage] or
  /// [Image.network]). It is wrapped in a [Hero] automatically.
  final Widget image;

  /// Content rendered in the bottom-left overlay (title + chips).
  final Widget titleColumn;

  /// Collapsed height / expanded height of the [SliverAppBar].
  final double expandedHeight;

  /// Optional icon buttons placed in the AppBar's [actions] slot
  /// (visible when the banner is collapsed/pinned).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      leading: Padding(
        padding: const EdgeInsets.all(CrispySpacing.sm),
        child: Container(
          color: Colors.black54,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      actions: actions,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Hero-animated backdrop image
            Hero(tag: heroTag, child: image),

            // Netflix-style bottom vignette
            const DecoratedBox(
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
            ),

            // Title / metadata overlay (bottom-left)
            Positioned(
              left: CrispySpacing.lg,
              right: CrispySpacing.lg,
              bottom: CrispySpacing.lg,
              child: titleColumn,
            ),
          ],
        ),
      ),
    );
  }
}
