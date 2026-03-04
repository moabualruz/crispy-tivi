import 'package:flutter/material.dart';

import '../../../../../core/theme/crispy_radius.dart';
import '../../../../../core/theme/crispy_spacing.dart';
import '../../../domain/entities/playback_state.dart';

/// Displays small pill badges for video/audio format info
/// in the OSD top bar (4K, HDR10, Dolby Vision, Atmos, …).
///
/// Only rendered when at least one badge is active.
/// Uses [colorScheme.tertiary] for HDR/HLG badges and
/// [colorScheme.primary] for Dolby badges.
class FormatBadgeRow extends StatelessWidget {
  const FormatBadgeRow({
    required this.colorScheme,
    this.is4k = false,
    this.videoFormat,
    this.audioFormat,
    super.key,
  });

  final ColorScheme colorScheme;
  final bool is4k;
  final VideoFormat? videoFormat;
  final AudioFormat? audioFormat;

  @override
  Widget build(BuildContext context) {
    final badges = _buildBadgeList();
    if (badges.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < badges.length; i++) ...[
          if (i > 0) const SizedBox(width: CrispySpacing.xs),
          badges[i],
        ],
      ],
    );
  }

  List<Widget> _buildBadgeList() {
    final result = <Widget>[];

    if (is4k) {
      result.add(
        _Badge(label: '4K', color: Colors.white.withValues(alpha: 0.15)),
      );
    }

    if (videoFormat != null) {
      switch (videoFormat!) {
        case VideoFormat.dolbyVision:
          result.add(
            _Badge(
              label: 'Dolby Vision',
              color: colorScheme.primary.withValues(alpha: 0.85),
            ),
          );
        case VideoFormat.hdr10Plus:
          result.add(
            _Badge(
              label: 'HDR10+',
              color: colorScheme.tertiary.withValues(alpha: 0.85),
            ),
          );
        case VideoFormat.hdr10:
          result.add(
            _Badge(
              label: 'HDR10',
              color: colorScheme.tertiary.withValues(alpha: 0.85),
            ),
          );
        case VideoFormat.hdr:
          result.add(
            _Badge(
              label: 'HDR',
              color: colorScheme.tertiary.withValues(alpha: 0.85),
            ),
          );
        case VideoFormat.hlg:
          result.add(
            _Badge(
              label: 'HLG',
              color: colorScheme.tertiary.withValues(alpha: 0.85),
            ),
          );
        case VideoFormat.sdr:
          break;
      }
    }

    if (audioFormat != null) {
      switch (audioFormat!) {
        case AudioFormat.dolbyAtmos:
          result.add(
            _Badge(
              label: 'Atmos',
              color: colorScheme.primary.withValues(alpha: 0.85),
            ),
          );
        case AudioFormat.dolbyDigitalPlus:
          result.add(
            _Badge(
              label: 'DD+',
              color: colorScheme.primary.withValues(alpha: 0.70),
            ),
          );
        case AudioFormat.dolbyDigital:
          result.add(
            _Badge(
              label: 'DD',
              color: colorScheme.primary.withValues(alpha: 0.70),
            ),
          );
        case AudioFormat.dtsX:
          result.add(
            _Badge(label: 'DTS:X', color: Colors.white.withValues(alpha: 0.15)),
          );
        case AudioFormat.dts:
          result.add(
            _Badge(label: 'DTS', color: Colors.white.withValues(alpha: 0.15)),
          );
        case AudioFormat.trueHd:
          result.add(
            _Badge(
              label: 'TrueHD',
              color: Colors.white.withValues(alpha: 0.15),
            ),
          );
        case AudioFormat.standard:
          break;
      }
    }

    return result;
  }
}

/// Single pill badge.
class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

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
        color: color,
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          height: 1.2,
        ),
      ),
    );
  }
}
