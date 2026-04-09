import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../providers/duplicate_detection_service.dart';
import '../../domain/entities/channel.dart';
import '../providers/channel_epg_provider.dart';
import '../providers/channel_providers.dart';
import '../providers/smart_group_providers.dart';
import 'channel_context_menu.dart';
import 'channel_list_item.dart';
import 'channel_swipe_actions.dart';

/// A single channel row in the sliver list that watches
/// both batch XMLTV EPG and on-demand per-channel EPG.
///
/// Extracted from [ChannelSliver] so each row can independently
/// watch [channelEpgProvider] without causing the entire list to
/// rebuild when one channel's on-demand EPG resolves.
class ChannelSliverItem extends ConsumerWidget {
  const ChannelSliverItem({
    super.key,
    required this.channel,
    required this.onTap,
    this.onDoubleTap,
    this.onFocus,
    this.onMiddleClick,
    this.onToggleFavorite,
    this.autofocus = false,
  });

  final Channel channel;
  final void Function(Channel) onTap;
  final void Function(Channel)? onDoubleTap;
  final void Function(Channel)? onFocus;
  final void Function(Channel)? onMiddleClick;
  final void Function(Channel)? onToggleFavorite;
  final bool autofocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ch = channel;
    final program = ref.watch(channelProgramSnapshotProvider(ch.id));
    final isPlaying = ref.watch(
      playbackSessionProvider.select((s) => s.streamUrl == ch.streamUrl),
    );

    final item = ClipRect(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CrispySpacing.md,
          vertical: CrispySpacing.xs,
        ),
        child: ChannelListItem(
          channel: ch,
          currentProgram: program.currentTitle,
          programProgress: program.currentProgress,
          nextProgramLabel: program.nextProgramLabel,
          isPlaying: isPlaying,
          onTap: () => onTap(ch),
          onDoubleTap: onDoubleTap != null ? () => onDoubleTap!(ch) : null,
          onFocus: onFocus != null ? () => onFocus!(ch) : null,
          onMiddleClick:
              onMiddleClick != null ? () => onMiddleClick!(ch) : null,
          autofocus: autofocus,
          isDuplicate: ref.watch(isChannelDuplicateProvider(ch.id)),
          isInSmartGroup: ref.watch(isChannelInSmartGroupProvider(ch.id)),
          onLongPress:
              () => showChannelContextMenu(
                context: context,
                ref: ref,
                channel: ch,
              ),
          onToggleFavorite:
              onToggleFavorite != null
                  ? () => onToggleFavorite!(ch)
                  : () => ref
                      .read(channelListProvider.notifier)
                      .toggleFavorite(ch.id),
        ),
      ),
    );

    return ChannelSwipeActions(
      channel: ch,
      onHidden:
          () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${ch.name} hidden'),
              duration: CrispyAnimation.snackBarDuration,
            ),
          ),
      child: item,
    );
  }
}
