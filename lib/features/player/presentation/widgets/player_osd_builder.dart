import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/utils/stream_url_actions.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../iptv/presentation/providers/channel_providers.dart';
import 'player_osd.dart';
import 'sleep_timer_dialog.dart';

/// Builds the [PlayerOsd] with favourite state and all
/// action callbacks. Extracted from [PlayerScreen] to
/// keep the screen file thin.
class PlayerOsdBuilder extends StatelessWidget {
  const PlayerOsdBuilder({
    required this.streamUrl,
    required this.isLive,
    required this.channelList,
    required this.currentChannelIndex,
    required this.onBack,
    required this.onToggleFullscreen,
    required this.onEnterPip,
    required this.onToggleZapOverlay,
    required this.onOpenExternal,
    super.key,
  });

  final String streamUrl;
  final bool isLive;
  final List<Channel>? channelList;
  final int currentChannelIndex;
  final VoidCallback onBack;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onEnterPip;
  final VoidCallback? onToggleZapOverlay;
  final VoidCallback? onOpenExternal;

  @override
  Widget build(BuildContext context) {
    // Find current channel to track favourite state.
    Channel? currentChannel;
    if (channelList != null && currentChannelIndex < channelList!.length) {
      currentChannel = channelList![currentChannelIndex];
    }

    return Consumer(
      builder: (context, ref, _) {
        final isFav = ref.watch(
          channelListProvider.select(
            (s) =>
                currentChannel != null &&
                s.channels.any(
                  (c) => c.id == currentChannel!.id && c.isFavorite,
                ),
          ),
        );

        // RTL guard: media playback controls always stay LTR
        // per Material Design guidelines — play/pause, seek bar,
        // skip controls refer to media direction, not text direction.
        return Directionality(
          textDirection: TextDirection.ltr,
          child: PlayerOsd(
            streamUrl: streamUrl,
            channelEpgId: currentChannel?.id,
            isFavorite: isFav,
            onBack: onBack,
            onFavorite:
                currentChannel != null
                    ? () {
                      ref
                          .read(channelListProvider.notifier)
                          .toggleFavorite(currentChannel!.id);
                    }
                    : null,
            onEnterPip: onEnterPip,
            onSleepTimer: () {
              showDialog(
                context: context,
                builder: (_) => const SleepTimerDialog(),
              );
            },
            onToggleFullscreen: onToggleFullscreen,
            onSearch:
                () => context.push(AppRoutes.tv, extra: {'openSearch': true}),
            onChannelList: onToggleZapOverlay,
            onRecordings: () => context.push(AppRoutes.dvr),
            onCopyUrl: () => copyStreamUrl(context, streamUrl),
            onOpenExternal: onOpenExternal,
          ),
        );
      },
    );
  }
}
