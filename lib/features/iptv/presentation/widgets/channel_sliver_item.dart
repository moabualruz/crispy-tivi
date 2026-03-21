import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/date_format_utils.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../application/duplicate_detection_service.dart';
import '../../domain/entities/channel.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
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

    // Read from batch XMLTV data already loaded in epgProvider.
    // Do NOT use channelEpgProvider here — it triggers individual
    // HTTP API calls per channel, flooding the server when 20+
    // channels are visible. Short EPG API is reserved for the
    // player OSD only (single active channel).
    final epgState = ref.watch(epgProvider);
    final nowPlaying = epgState.getNowPlaying(ch.id);
    final nextEntry = epgState.getNextProgram(ch.id);
    assert(() {
      debugPrint('[EPG-PERF] ChannelSliverItem.build: ${ch.name}');
      return true;
    }());

    final nextLabel =
        nextEntry != null
            ? 'Next: ${nextEntry.title} · '
                '${formatHHmmLocal(nextEntry.startTime)}'
            : null;

    final playingUrl = ref.watch(
      playbackSessionProvider.select((s) => s.streamUrl),
    );

    final item = ClipRect(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CrispySpacing.md,
          vertical: CrispySpacing.xs,
        ),
        child: ChannelListItem(
          channel: ch,
          currentProgram: nowPlaying?.title,
          programProgress:
              nowPlaying != null && nowPlaying.isLive
                  ? nowPlaying.progress
                  : null,
          nextProgramLabel: nextLabel,
          isPlaying: ch.streamUrl == playingUrl,
          onTap: () => onTap(ch),
          onDoubleTap: onDoubleTap != null ? () => onDoubleTap!(ch) : null,
          onFocus: onFocus != null ? () => onFocus!(ch) : null,
          onMiddleClick:
              onMiddleClick != null ? () => onMiddleClick!(ch) : null,
          autofocus: autofocus,
          isDuplicate: ref.watch(isChannelDuplicateProvider(ch.id)),
          isInSmartGroup:
              ref.watch(smartGroupChannelIdsProvider).value?.contains(ch.id) ??
              false,
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
