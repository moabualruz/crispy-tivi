import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/cache_service.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../domain/entities/thumbnail_sprite.dart';

/// Floating thumbnail preview shown above seek bar on hover.
///
/// Displays either:
/// - A thumbnail from a sprite sheet (if available)
/// - A timestamp-only fallback (if no thumbnails)
class ThumbnailPreviewPopup extends ConsumerWidget {
  const ThumbnailPreviewPopup({
    required this.position,
    required this.region,
    this.showTimestamp = true,
    super.key,
  });

  /// The video position being previewed.
  final Duration position;

  /// The thumbnail region to display (null for timestamp-only mode).
  final ThumbnailRegion? region;

  /// Whether to show the timestamp below the thumbnail.
  final bool showTimestamp;

  /// Thumbnail width in pixels.
  static const double thumbnailWidth = 160;

  /// Thumbnail height in pixels (16:9 aspect ratio).
  static const double thumbnailHeight = 90;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final backend = ref.read(crispyBackendProvider);
    final posMs = position.inMilliseconds;

    return AnimatedOpacity(
      opacity: 1.0,
      duration: CrispyAnimation.fast,
      curve: CrispyAnimation.enterCurve,
      child: GlassSurface(
        borderRadius: CrispyRadius.sm,
        padding: const EdgeInsets.all(CrispySpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thumbnail or placeholder
            if (region != null)
              _ThumbnailFromSprite(region: region!)
            else
              _ThumbnailPlaceholder(colorScheme: colorScheme),

            // Timestamp
            if (showTimestamp) ...[
              const SizedBox(height: CrispySpacing.xs),
              Text(
                backend.formatPlaybackDuration(posMs, posMs),
                style: textTheme.labelSmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders a thumbnail from a sprite sheet region.
///
/// Uses widget-based clipping to extract the correct tile
/// from the sprite sheet — the image is offset so the
/// desired region aligns with the visible viewport.
class _ThumbnailFromSprite extends StatelessWidget {
  const _ThumbnailFromSprite({required this.region});

  final ThumbnailRegion region;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        width: ThumbnailPreviewPopup.thumbnailWidth,
        height: ThumbnailPreviewPopup.thumbnailHeight,
        child: Builder(
          builder: (context) {
            final scaleX = ThumbnailPreviewPopup.thumbnailWidth / region.width;
            final scaleY =
                ThumbnailPreviewPopup.thumbnailHeight / region.height;
            return ClipRect(
              child: Transform.translate(
                offset: Offset(-region.x * scaleX, -region.y * scaleY),
                child: Image.network(
                  region.imageUrl,
                  fit: BoxFit.none,
                  filterQuality: FilterQuality.medium,
                  width: null,
                  height: null,
                  errorBuilder:
                      (context, error, stackTrace) => Container(
                        color: Colors.black26,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white38,
                          size: 32,
                        ),
                      ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Placeholder shown when no thumbnail is available.
class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ThumbnailPreviewPopup.thumbnailWidth,
      height: ThumbnailPreviewPopup.thumbnailHeight,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_outlined, color: Colors.white38, size: 32),
          const SizedBox(height: CrispySpacing.xs),
          Text(
            'No preview',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: Colors.white38),
          ),
        ],
      ),
    );
  }
}

/// Timestamp-only popup for when thumbnails are unavailable.
///
/// Displays a simple glassmorphic pill with the timestamp.
class TimestampOnlyPopup extends ConsumerWidget {
  const TimestampOnlyPopup({required this.position, super.key});

  final Duration position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final backend = ref.read(crispyBackendProvider);
    final posMs = position.inMilliseconds;

    return AnimatedOpacity(
      opacity: 1.0,
      duration: CrispyAnimation.fast,
      curve: CrispyAnimation.enterCurve,
      child: GlassSurface(
        borderRadius: CrispyRadius.sm,
        padding: const EdgeInsets.symmetric(
          horizontal: CrispySpacing.sm,
          vertical: CrispySpacing.xs,
        ),
        child: Text(
          backend.formatPlaybackDuration(posMs, posMs),
          style: textTheme.labelMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
