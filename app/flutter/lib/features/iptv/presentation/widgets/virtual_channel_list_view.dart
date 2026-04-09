import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/channel.dart';
import 'channel_sliver_item.dart';

/// Viewport-windowed vertical channel list for large layouts.
///
/// Keeps full scroll extent while only mounting rows intersecting the
/// viewport plus overscan.
class VirtualChannelListView extends ConsumerWidget {
  const VirtualChannelListView({
    super.key,
    required this.channels,
    required this.controller,
    required this.onTap,
    this.onDoubleTap,
    this.onFocus,
    this.onMiddleClick,
    this.onReorder,
    this.onToggleFavorite,
  });

  static const double rowExtent = 72.0;
  static const int overscanRows = 10;

  final List<Channel> channels;
  final ScrollController controller;
  final void Function(Channel) onTap;
  final void Function(Channel)? onDoubleTap;
  final void Function(Channel)? onFocus;
  final void Function(Channel)? onMiddleClick;
  final void Function(int, int)? onReorder;
  final void Function(Channel)? onToggleFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalHeight = channels.length * rowExtent;

    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final offset = controller.hasClients ? controller.offset : 0.0;
            final firstRow = ((offset / rowExtent).floor() - overscanRows)
                .clamp(0, channels.length);
            final lastRow = (((offset + constraints.maxHeight) / rowExtent)
                        .ceil() +
                    overscanRows)
                .clamp(0, channels.length);

            return SingleChildScrollView(
              controller: controller,
              child: SizedBox(
                height: totalHeight,
                child: Stack(
                  children: [
                    for (var index = firstRow; index < lastRow; index++)
                      Positioned(
                        top: index * rowExtent,
                        left: 0,
                        right: 0,
                        height: rowExtent,
                        child: ChannelSliverItem(
                          key: ValueKey(channels[index].id),
                          channel: channels[index],
                          onTap: onTap,
                          onDoubleTap: onDoubleTap,
                          onFocus: onFocus,
                          onMiddleClick: onMiddleClick,
                          onToggleFavorite: onToggleFavorite,
                          autofocus: index == 0,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
