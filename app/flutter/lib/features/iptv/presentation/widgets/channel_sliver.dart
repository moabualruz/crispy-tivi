import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/channel.dart';
import '../providers/channel_providers.dart';
import 'channel_reorderable_list.dart';
import 'channel_sliver_item.dart';

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

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) {
          final ch = channels[i];
          return ChannelSliverItem(
            key: ValueKey(ch.id),
            channel: ch,
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            onFocus: onFocus,
            onMiddleClick: onMiddleClick,
            onToggleFavorite: onToggleFavorite,
            autofocus: i == 0,
          );
        },
        childCount: channels.length,
        // Channel items are ConsumerWidgets — state lives in
        // Riverpod providers, not widget State. No need to keep
        // off-screen items alive in memory.
        addAutomaticKeepAlives: false,
      ),
    );
  }
}
