import 'package:flutter/material.dart';

import '../../../../../core/domain/entities/media_item.dart';
import '../../../../../core/theme/crispy_radius.dart';
import '../../../../../core/theme/crispy_spacing.dart';

/// Quality overlay badges (4K, HDR variants, Dolby) rendered in the
/// bottom-right corner of a media server poster card.
///
/// Reads quality hints from [MediaItem.metadata] keys set by
/// [MediaServerSource._mapToMediaItem]:
///   - `'videoWidth'`  / `'videoHeight'` → 4K detection (≥3840 × 2160)
///   - `'videoRange'`  → HDR / Dolby Vision string from server
///
/// Only displayed when at least one quality signal is present.
/// Shows at most two badges to avoid visual clutter — 4K first, then
/// the most prominent HDR/Dolby variant.
class MediaItemQualityBadge extends StatelessWidget {
  const MediaItemQualityBadge({required this.item, super.key});

  /// The media item whose quality metadata is inspected.
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final badges = _resolveBadges(context);
    if (badges.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: CrispySpacing.xs,
      right: CrispySpacing.xs,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < badges.length; i++) ...[
            if (i > 0) const SizedBox(width: CrispySpacing.xxs),
            badges[i],
          ],
        ],
      ),
    );
  }

  List<Widget> _resolveBadges(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final result = <Widget>[];

    // ── 4K detection ─────────────────────────────────────────────────
    final width = item.metadata['videoWidth'] as int?;
    final height = item.metadata['videoHeight'] as int?;
    final is4k =
        (width != null && width >= 3840) || (height != null && height >= 2160);

    if (is4k) {
      result.add(_QualityPill(label: '4K', color: cs.secondary));
    }

    // ── HDR / Dolby range ─────────────────────────────────────────────
    final videoRange = (item.metadata['videoRange'] as String?)?.toUpperCase();

    if (videoRange != null) {
      if (videoRange.contains('DOVI') || videoRange.contains('DOLBYVISION')) {
        result.add(_QualityPill(label: 'DV', color: cs.primary));
      } else if (videoRange.contains('HDR10PLUS') ||
          videoRange.contains('HDR10+')) {
        result.add(_QualityPill(label: 'HDR10+', color: cs.tertiary));
      } else if (videoRange.contains('HDR10')) {
        result.add(_QualityPill(label: 'HDR10', color: cs.tertiary));
      } else if (videoRange.contains('HLG')) {
        result.add(_QualityPill(label: 'HLG', color: cs.tertiary));
      } else if (videoRange.contains('HDR')) {
        result.add(_QualityPill(label: 'HDR', color: cs.tertiary));
      }
    }

    return result;
  }
}

/// Single pill badge for a quality label.
class _QualityPill extends StatelessWidget {
  const _QualityPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.xs,
        vertical: CrispySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.87),
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          height: 1.2,
        ),
      ),
    );
  }
}
