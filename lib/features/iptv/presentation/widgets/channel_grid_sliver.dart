import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/channel.dart';
import 'channel_grid_item.dart';

/// A sliver that renders the channel list as a responsive grid.
///
/// Cross-axis count adapts to screen width:
/// - < 360 dp  → 2 columns
/// - < 600 dp  → 3 columns
/// - < 900 dp  → 4 columns
/// - ≥ 900 dp  → 5 columns
///
/// Spec: FE-TV-07.
class ChannelGridSliver extends ConsumerWidget {
  const ChannelGridSliver({
    super.key,
    required this.channels,
    required this.onTap,
  });

  final List<Channel> channels;
  final void Function(Channel) onTap;

  /// Returns the grid cross-axis count based on available width.
  static int _crossAxisCount(double width) {
    if (width < 360) return 2;
    if (width < 600) return 3;
    if (width < 900) return 4;
    return 5;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Select only entries to avoid rebuilds on unrelated EPG changes.
    ref.watch(epgProvider.select((s) => s.entries));
    final epgState = ref.read(epgProvider);
    final playingUrl = ref.watch(
      playbackSessionProvider.select((s) => s.streamUrl),
    );

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final crossCount = _crossAxisCount(width);
        const itemHeight = 110.0;

        return SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: CrispySpacing.md,
            vertical: CrispySpacing.sm,
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossCount,
              mainAxisExtent: itemHeight,
              crossAxisSpacing: CrispySpacing.sm,
              mainAxisSpacing: CrispySpacing.sm,
            ),
            delegate: SliverChildBuilderDelegate((ctx, i) {
              final ch = channels[i];
              final nowPlaying = epgState.getNowPlaying(ch.id);
              return ChannelGridItem(
                channel: ch,
                onTap: () => onTap(ch),
                currentProgram: nowPlaying?.title,
                isPlaying: ch.streamUrl == playingUrl,
                autofocus: i == 0,
              );
            }, childCount: channels.length),
          ),
        );
      },
    );
  }
}
