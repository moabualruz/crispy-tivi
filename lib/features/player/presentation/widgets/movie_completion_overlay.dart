import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import 'player_osd/osd_shared.dart';

/// Overlay shown when a movie (non-episode VOD) reaches 95% completion.
///
/// Displays a Netflix-inspired post-play card positioned bottom-right,
/// offering the viewer options to watch again or browse for more content.
class MovieCompletionOverlay extends StatelessWidget {
  const MovieCompletionOverlay({
    required this.currentTitle,
    required this.onWatchAgain,
    required this.onBrowseMore,
    super.key,
  });

  final String currentTitle;
  final VoidCallback onWatchAgain;
  final VoidCallback onBrowseMore;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      right: CrispySpacing.lg,
      bottom: safeBottom + kOsdBottomBarHeight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(CrispySpacing.md),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(CrispyRadius.md),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.movie, color: colorScheme.primary, size: 20),
                  const SizedBox(width: CrispySpacing.sm),
                  Text(
                    'Finished',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CrispySpacing.md),

              // Current movie title
              Text(
                currentTitle,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: CrispySpacing.md),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onWatchAgain,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.onSurface,
                        side: BorderSide(
                          color: colorScheme.onSurface.withValues(alpha: 0.54),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: CrispySpacing.md,
                        ),
                      ),
                      child: const Text('Watch Again'),
                    ),
                  ),
                  const SizedBox(width: CrispySpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: onBrowseMore,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: CrispySpacing.md,
                        ),
                      ),
                      child: const Text('Browse More'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
