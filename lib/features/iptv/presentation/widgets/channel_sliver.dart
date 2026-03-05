import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/date_format_utils.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../application/duplicate_detection_service.dart';
import '../../domain/entities/channel.dart';
import '../providers/channel_providers.dart';
import 'channel_context_menu.dart';
import 'channel_list_item.dart';
import 'channel_reorderable_list.dart';
import 'channel_swipe_actions.dart';

/// A sliver that renders the channel list in both mobile and TV
/// layouts.
///
/// Mobile usage — no TV callbacks:
/// ```dart
/// ChannelSliver(channels: chs, onTap: _onChannelTap)
/// ```
///
/// TV usage — with focus/double-tap/middle-click callbacks:
/// ```dart
/// ChannelSliver(
///   channels: chs,
///   onTap: _onChannelTapped,
///   onDoubleTap: _onChannelFullscreen,
///   onFocus: _onChannelFocused,
///   onMiddleClick: _onChannelFullscreen,
///   onReorder: widget.onReorder,
/// )
/// ```
class ChannelSliver extends ConsumerWidget {
  const ChannelSliver({
    super.key,
    required this.channels,
    required this.onTap,
    this.onDoubleTap,
    this.onFocus,
    this.onMiddleClick,
    this.onReorder,
    this.onToggleFavorite,
  });

  final List<Channel> channels;

  /// Called when the user taps a channel row.
  final void Function(Channel) onTap;

  /// TV-only: called on double-tap to enter fullscreen.
  final void Function(Channel)? onDoubleTap;

  /// TV-only: called when focus moves to a channel row (D-pad).
  final void Function(Channel)? onFocus;

  /// TV-only: called on middle-click to enter fullscreen.
  final void Function(Channel)? onMiddleClick;

  /// Required when reorder mode is active. If `null`, reorder mode
  /// is treated as inactive even if the provider says otherwise.
  final void Function(int, int)? onReorder;

  /// Optional override for the favorite toggle. If `null`, the
  /// widget falls back to the provider notifier directly.
  final void Function(Channel)? onToggleFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isReorderMode = ref.watch(
      channelListProvider.select((s) => s.isReorderMode),
    );

    if (isReorderMode && onReorder != null) {
      return ChannelReorderableList(channels: channels, onReorder: onReorder!);
    }

    // Select only entries to avoid rebuilding on unrelated EPG
    // state changes.
    ref.watch(epgProvider.select((s) => s.entries));
    final epgState = ref.read(epgProvider);
    final playingUrl = ref.watch(
      playbackSessionProvider.select((s) => s.streamUrl),
    );

    return SliverList(
      delegate: SliverChildBuilderDelegate((ctx, i) {
        final ch = channels[i];
        final nowPlaying = epgState.getNowPlaying(ch.id);
        final nextEntry = epgState.getNextProgram(ch.id);
        final nextLabel =
            nextEntry != null
                ? 'Next: ${nextEntry.title} · '
                    '${formatHHmmLocal(nextEntry.startTime)}'
                : null;
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
              autofocus: i == 0,
              isDuplicate: ref.watch(isChannelDuplicateProvider(ch.id)),
              onLongPress:
                  () => showChannelContextMenu(
                    context: ctx,
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
        // FE-TV-11: wrap with swipe actions on compact (mobile)
        // layout. On tablet / TV the widget passes through unchanged.
        return ChannelSwipeActions(
          channel: ch,
          onHidden:
              () => ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text('${ch.name} hidden'),
                  duration: const Duration(seconds: 2),
                ),
              ),
          child: item,
        );
      }, childCount: channels.length),
    );
  }
}
