import 'package:flutter/material.dart';

import 'package:crispy_tivi/core/theme/crispy_radius.dart';
import 'package:crispy_tivi/core/theme/crispy_spacing.dart';

/// A tappable poster card with an image, bottom gradient title scrim,
/// and an optional overlay widget (e.g. a progress bar or badge).
///
/// Used by Emby and Jellyfin home screen rows (Continue Watching,
/// Next Up, Collections) to display a consistent card shape.
///
/// The card fills its parent's constraints. Wrap it in a
/// [SizedBox] with explicit width/height when used inside a
/// [HorizontalScrollRow] or similar fixed-dimension parent.
class MediaServerPosterCard extends StatelessWidget {
  /// Creates a [MediaServerPosterCard].
  const MediaServerPosterCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.onTap,
    this.fallbackIcon = Icons.movie_outlined,
    this.semanticLabel,
    this.titleMaxLines = 1,
    this.overlay,
  });

  /// Remote URL for the poster image. May be null — shows [fallbackIcon].
  final String? imageUrl;

  /// Primary title displayed in the bottom gradient scrim.
  final String title;

  /// Called when the card is tapped.
  final VoidCallback onTap;

  /// Icon shown in the fallback placeholder when [imageUrl] is null
  /// or fails to load.
  final IconData fallbackIcon;

  /// Semantics label for accessibility / testing. Defaults to [title]
  /// when null.
  final String? semanticLabel;

  /// Maximum lines for the title text in the scrim.
  final int titleMaxLines;

  /// Optional widget drawn on top of the image (e.g. a
  /// [WatchedIndicator] or a child-count badge). Positioned to fill
  /// the card bounds — use [Positioned] inside a [Stack] if needed.
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: semanticLabel ?? title,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(CrispyRadius.tv),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Poster image ─────────────────────────────────────
              if (imageUrl != null)
                Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, _, _) => ColoredBox(
                        color: cs.surfaceContainerHigh,
                        child: Icon(fallbackIcon, color: cs.onSurfaceVariant),
                      ),
                )
              else
                ColoredBox(
                  color: cs.surfaceContainerHigh,
                  child: Icon(fallbackIcon, color: cs.onSurfaceVariant),
                ),

              // ── Optional overlay (progress bar, badge, etc.) ─────
              if (overlay != null) overlay!,

              // ── Bottom gradient + title scrim ────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(
                    CrispySpacing.xs,
                    CrispySpacing.lg,
                    CrispySpacing.xs,
                    CrispySpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        cs.surface.withValues(alpha: 0.85),
                        cs.surface.withValues(alpha: 0),
                      ],
                    ),
                  ),
                  child: Text(
                    title,
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: titleMaxLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
