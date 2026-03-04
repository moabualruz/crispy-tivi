import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../providers/player_providers.dart';

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
    // Only rebuild when the stats map actually changed.
    if (_mapsEqual(_stats, info)) return;
    if (mounted) {
      setState(() => _stats = info);
    }
  }

  /// Shallow equality check for string maps.
  static bool _mapsEqual(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
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
        constraints: const BoxConstraints(maxWidth: 320),
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
                    'Stream Stats',
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
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontSize: 10,
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
        tooltip: copied ? 'Copied!' : 'Copy stats',
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
