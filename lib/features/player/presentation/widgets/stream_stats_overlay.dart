import 'dart:async';

import 'package:crispy_tivi/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/theme/crispy_typography.dart';
import '../../../../core/widgets/sparkline.dart';
import '../providers/player_providers.dart';

/// Maximum number of rolling sparkline samples.
const _maxSamples = 30;

/// "Nerd Stats" overlay showing real-time stream
/// diagnostic info.
///
/// Polls [PlayerService.streamInfo] every 1 second so
/// values are always fresh from the actual player
/// backend. Toggle via [streamStatsVisibleProvider].
/// Positioned top-right of the player viewport.
class StreamStatsOverlay extends ConsumerStatefulWidget {
  /// Creates a stream stats overlay.
  const StreamStatsOverlay({super.key});

  @override
  ConsumerState<StreamStatsOverlay> createState() => _StreamStatsOverlayState();
}

class _StreamStatsOverlayState extends ConsumerState<StreamStatsOverlay> {
  Timer? _refreshTimer;
  Map<String, String> _stats = {};
  bool _copied = false;

  /// Rolling buffer duration samples (seconds).
  final _bufferSamples = <double>[];

  /// Rolling FPS samples.
  final _fpsSamples = <double>[];

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refresh(),
    );
    // Immediate first read.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    final visible = ref.read(streamStatsVisibleProvider);
    if (!visible) return;

    final info = ref.read(playerServiceProvider).streamInfo;

    // Collect sparkline samples from stream info.
    _collectSample(_bufferSamples, _parseBufferSeconds(info['Buffer']));
    _collectSample(_fpsSamples, _parseFps(info['FPS']));

    // Only rebuild when the stats map actually changed
    // or sparkline data changed (every cycle).
    if (mounted) {
      setState(() => _stats = info);
    }
  }

  void _collectSample(List<double> samples, double value) {
    samples.add(value);
    if (samples.length > _maxSamples) {
      samples.removeAt(0);
    }
  }

  static double _parseBufferSeconds(String? raw) {
    if (raw == null) return 0;
    // Format: "3s" or "12s"
    final digits = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(digits) ?? 0;
  }

  static double _parseFps(String? raw) {
    if (raw == null) return 0;
    return double.tryParse(raw) ?? 0;
  }

  void _copyToClipboard() {
    final buf =
        StringBuffer()
          ..writeln('CrispyTivi Stream Stats')
          ..writeln('=${'=' * 30}');
    for (final e in _stats.entries) {
      buf.writeln('${e.key}: ${e.value}');
    }
    buf.writeln('=${'=' * 30}');
    buf.writeln(
      'Timestamp: '
      '${DateTime.now().toIso8601String()}',
    );

    Clipboard.setData(ClipboardData(text: buf.toString()));

    if (mounted) {
      setState(() => _copied = true);
    }
    // Reset copied indicator after 2 seconds.
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = ref.watch(streamStatsVisibleProvider);
    if (!visible) {
      return const SizedBox.shrink();
    }

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned(
      top: MediaQuery.paddingOf(context).top + CrispySpacing.lg,
      right: CrispySpacing.md,
      child: Container(
        padding: const EdgeInsets.all(CrispySpacing.sm),
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.80),
          borderRadius: BorderRadius.zero,
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row with copy button.
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.l10n.playerStreamStats,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                _CopyButton(copied: _copied, onPressed: _copyToClipboard),
              ],
            ),
            const SizedBox(height: CrispySpacing.xs),
            Divider(
              height: 1,
              color: colorScheme.onSurface.withValues(alpha: 0.15),
            ),
            const SizedBox(height: CrispySpacing.xs),

            // Info badges row.
            _BadgeRow(stats: _stats),
            const SizedBox(height: CrispySpacing.xs),

            // Buffer sparkline.
            if (_bufferSamples.length >= 2) ...[
              _SparklineRow(
                label: context.l10n.playerStreamStatsBuffer,
                samples: _bufferSamples,
                minValue: 0,
                maxValue: 30,
                lowThreshold: 2,
                highThreshold: 10,
                valueLabel: _stats['Buffer'] ?? '',
              ),
              const SizedBox(height: CrispySpacing.xs),
            ],

            // FPS sparkline.
            if (_fpsSamples.length >= 2) ...[
              _SparklineRow(
                label: context.l10n.playerStreamStatsFps,
                samples: _fpsSamples,
                minValue: 0,
                maxValue: 60,
                lowThreshold: 20,
                highThreshold: 50,
                valueLabel: _stats['FPS'] ?? '',
              ),
              const SizedBox(height: CrispySpacing.xs),
            ],

            // Stats rows.
            ..._stats.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        e.key,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.67),
                          fontSize: CrispyTypography.micro,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontSize: CrispyTypography.micro,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row showing a sparkline with label and current value.
class _SparklineRow extends StatelessWidget {
  const _SparklineRow({
    required this.label,
    required this.samples,
    required this.minValue,
    required this.maxValue,
    required this.lowThreshold,
    required this.highThreshold,
    required this.valueLabel,
  });

  final String label;
  final List<double> samples;
  final double minValue;
  final double maxValue;
  final double lowThreshold;
  final double highThreshold;
  final String valueLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.67),
              fontSize: CrispyTypography.micro,
              fontFamily: 'monospace',
            ),
          ),
        ),
        Sparkline(
          samples: List.of(samples),
          minValue: minValue,
          maxValue: maxValue,
          lowThreshold: lowThreshold,
          highThreshold: highThreshold,
          width: 80,
          height: 24,
        ),
        const SizedBox(width: CrispySpacing.xs),
        Text(
          valueLabel,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface,
            fontSize: CrispyTypography.micro,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Row of info badges: resolution, codec, interlace.
class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.stats});

  final Map<String, String> stats;

  @override
  Widget build(BuildContext context) {
    final badges = <String>[];

    // Resolution badge.
    final resolution = stats['Resolution'];
    if (resolution != null && resolution != 'N/A') {
      badges.add(_resolutionLabel(resolution));
    }

    // Codec badge.
    final codec = stats['Video Codec'];
    if (codec != null && codec != 'N/A') {
      badges.add(_formatCodecName(codec));
    }

    // Interlace badge.
    final pixFmt = stats['Pixel Format'] ?? '';
    if (pixFmt.contains('interlace') || pixFmt.endsWith('i')) {
      badges.add('Interlaced');
    }

    // Stream type badge.
    final streamType = stats['Stream Type'];
    if (streamType != null) {
      badges.add(streamType);
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: badges.map(_buildBadge).toList(),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white70,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Maps resolution string to friendly label.
  static String _resolutionLabel(String resolution) {
    // Parse "WxH" format.
    final parts = resolution.split('\u00D7');
    if (parts.length == 2) {
      final h = int.tryParse(parts[1]) ?? 0;
      if (h >= 2160) return '4K';
      if (h >= 1080) return '1080p';
      if (h >= 720) return '720p';
      if (h >= 480) return '480p';
      if (h > 0) return 'SD';
    }
    return resolution;
  }

  /// Normalizes codec name to friendly form.
  static String _formatCodecName(String codec) {
    final upper = codec.toUpperCase();
    if (upper.contains('HEVC') || upper.contains('H265')) return 'HEVC';
    if (upper.contains('H264') || upper.contains('AVC')) return 'H.264';
    if (upper.contains('AV1')) return 'AV1';
    if (upper.contains('VP9')) return 'VP9';
    if (upper.contains('VP8')) return 'VP8';
    return codec;
  }
}

/// Small copy-to-clipboard button for the stats
/// overlay header.
class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.copied, required this.onPressed});

  final bool copied;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 24,
      height: 24,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 14,
        tooltip:
            copied
                ? context.l10n.playerStreamStatsCopied
                : context.l10n.playerStreamStatsCopy,
        onPressed: onPressed,
        icon: Icon(
          copied ? Icons.check : Icons.copy_outlined,
          color:
              copied
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.6),
          size: 14,
        ),
      ),
    );
  }
}
