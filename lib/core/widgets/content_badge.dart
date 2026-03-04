import 'package:flutter/material.dart';

import '../theme/crispy_radius.dart';
import '../theme/crispy_spacing.dart';

/// Semantic category for a content status badge.
///
/// Used with [ContentStatusBadge] to produce correctly-colored
/// pill overlays on VOD poster cards and channel items.
enum ContentBadge {
  /// A new episode has been added to this series.
  newEpisode,

  /// A new season has been added to this series.
  newSeason,

  /// Content is currently being recorded (DVR).
  recording,

  /// Catchup/timeshift availability expires soon.
  expiringSoon,
}

/// A small pill-shaped status badge for VOD poster cards.
///
/// Renders a compact overlay pill whose color and label are
/// driven by the [badge] value. The `recording` variant adds
/// a pulsing dot before the label.
///
/// ```dart
/// ContentStatusBadge(badge: ContentBadge.newEpisode)
/// ContentStatusBadge(badge: ContentBadge.recording)
/// ```
class ContentStatusBadge extends StatelessWidget {
  const ContentStatusBadge({super.key, required this.badge});

  /// The badge type to render.
  final ContentBadge badge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final (bgColor, fgColor, label, showDot) = switch (badge) {
      ContentBadge.newEpisode => (cs.tertiary, cs.onTertiary, 'NEW EP', false),
      ContentBadge.newSeason => (
        cs.tertiary,
        cs.onTertiary,
        'NEW SEASON',
        false,
      ),
      ContentBadge.recording => (cs.error, cs.onError, 'REC', true),
      ContentBadge.expiringSoon => (
        cs.errorContainer,
        cs.onErrorContainer,
        'EXPIRES',
        false,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.xs,
        vertical: CrispySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fgColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: CrispySpacing.xxs),
          ],
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: fgColor,
              fontWeight: FontWeight.w700,
              fontSize: 9,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
