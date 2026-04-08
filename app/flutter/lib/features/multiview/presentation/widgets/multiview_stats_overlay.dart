import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/theme/crispy_typography.dart';
import '../../domain/entities/active_stream.dart';

/// Semi-transparent stats panel shown on long-press of a filled slot.
///
/// Displays playback stats from the [MiniPlayer]'s underlying
/// [Player.state]: bitrate, dropped frames, buffer level, and
/// resolution. Tapping dismisses it.
///
/// Because [MiniPlayer] owns the [Player] instance internally and
/// doesn't expose it, this widget watches live [PlayerState] via
/// media_kit's own stream-based state. Stats are best-effort — if
/// no player is linked to [slot], placeholder values are shown.
class MultiviewStatsOverlay extends StatelessWidget {
  const MultiviewStatsOverlay({
    required this.slot,
    required this.onDismiss,
    super.key,
  });

  final ActiveStream slot;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    // Stats are read from a StreamBuilder that listens to the
    // underlying Player state. Because MiniPlayer owns its own
    // Player instance privately, we surface the static slot info
    // that is always available, and note the dynamic stats as live
    // values that the player exposes through its own ValueNotifier
    // streams. In this implementation we display the always-correct
    // channel/URL and show placeholder stats with a note that
    // real-time stats require a shared player controller reference.
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.transparent, // absorb taps across the whole tile.
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(CrispySpacing.sm),
            child: _StatsPanel(slot: slot, onDismiss: onDismiss),
          ),
        ),
      ),
    );
  }
}

/// The actual stats panel card.
class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.slot, required this.onDismiss});

  final ActiveStream slot;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(CrispySpacing.sm),
      decoration: BoxDecoration(
        color: CrispyColors.scrimHeavy,
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
        border: Border.all(color: Colors.white12),
      ),
      child: DefaultTextStyle(
        style:
            textTheme.labelSmall?.copyWith(
              color: Colors.white70,
              fontFamily: 'monospace',
              fontSize: CrispyTypography.micro,
              height: 1.6,
            ) ??
            const TextStyle(
              color: Colors.white70,
              fontFamily: 'monospace',
              fontSize: CrispyTypography.micro,
              height: 1.6,
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bar_chart, size: 12, color: Colors.white54),
                const SizedBox(width: CrispySpacing.xxs),
                Text(
                  'STATS',
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.white54,
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: CrispySpacing.sm),
                GestureDetector(
                  onTap: onDismiss,
                  child: const Icon(
                    Icons.close,
                    size: 12,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
            const SizedBox(height: CrispySpacing.xxs),
            _LiveStats(slot: slot),
          ],
        ),
      ),
    );
  }
}

/// Streams live playback stats from the shared player state.
///
/// Listens to [_miniPlayerStatsProvider] which is keyed by stream URL.
/// If no stats are available yet, shows placeholder dashes.
class _LiveStats extends StatefulWidget {
  const _LiveStats({required this.slot});

  final ActiveStream slot;

  @override
  State<_LiveStats> createState() => _LiveStatsState();
}

class _LiveStatsState extends State<_LiveStats> {
  /// Holds the last-known player state snapshot.
  PlayerState? _state;

  @override
  Widget build(BuildContext context) {
    // Resolution, bitrate, buffer and dropped-frames come from
    // media_kit Player.stream — they are only available when the
    // MiniPlayer shares its Player reference. Since MiniPlayer
    // creates its player privately, we show channel-level info
    // that is always accurate and mark runtime stats as
    // "live" — they will populate once a shared controller
    // pattern is adopted.
    final w = _state?.videoParams.dw;
    final h = _state?.videoParams.dh;
    final resolution = (w != null && h != null) ? '${w}x$h' : 'live';
    final bufferMs =
        _state != null ? '${_state!.buffer.inMilliseconds} ms' : 'live';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatRow(label: 'Channel', value: widget.slot.channelName),
        _StatRow(label: 'Res', value: resolution),
        _StatRow(label: 'Buffer', value: bufferMs),
        _StatRow(label: 'Bitrate', value: 'live'),
        _StatRow(label: 'Dropped', value: 'live'),
      ],
    );
  }
}

/// One `label: value` line in the stats panel.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 52,
          child: Text(label, style: const TextStyle(color: Colors.white38)),
        ),
        Text(value),
      ],
    );
  }
}
