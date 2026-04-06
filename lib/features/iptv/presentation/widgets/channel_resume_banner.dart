import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../providers/iptv_service_providers.dart';
import '../../domain/entities/channel.dart';
import '../providers/channel_providers.dart';

/// Resume last-watched channel banner sliver.
///
/// Watches [favoritesHistoryProvider] for the last
/// channel ID and shows a tappable card if found.
class ChannelResumeBanner extends ConsumerWidget {
  const ChannelResumeBanner({
    super.key,
    required this.state,
    required this.onResume,
  });

  /// Current channel list state (used to look up
  /// the channel by ID).
  final ChannelListState state;

  /// Called when the user taps the resume card.
  final void Function(Channel channel) onResume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histState = ref.watch(favoritesHistoryProvider);
    final lastId = histState.lastChannelId;
    if (lastId == null || state.channels.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final lastCh = state.channels.where((c) => c.id == lastId).firstOrNull;
    if (lastCh == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CrispySpacing.md,
          vertical: CrispySpacing.xs,
        ),
        // TV-T20: explicit borderRadius using design token (was missing).
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CrispyRadius.tvSm),
          ),
          child: ListTile(
            leading: const Icon(Icons.play_circle_fill),
            title: Text(
              'Resume: ${lastCh.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onResume(lastCh),
          ),
        ),
      ),
    );
  }
}
