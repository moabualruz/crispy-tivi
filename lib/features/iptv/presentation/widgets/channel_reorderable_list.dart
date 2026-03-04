import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../application/duplicate_detection_service.dart';
import '../../domain/entities/channel.dart';
import 'channel_list_item.dart';

/// Reorderable channel list wrapped in a
/// [SliverToBoxAdapter].
///
/// Displays drag handles and a scale-up proxy
/// decorator while dragging.
class ChannelReorderableList extends ConsumerWidget {
  const ChannelReorderableList({
    super.key,
    required this.channels,
    required this.onReorder,
  });

  final List<Channel> channels;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverToBoxAdapter(
      child: ReorderableListView.builder(
        // TV-T22: shrinkWrap is required here because this list is nested
        // inside a [SliverToBoxAdapter] within a [CustomScrollView].
        // Without shrinkWrap, ReorderableListView expands to fill all
        // available height and conflicts with the outer scrollable, producing
        // a "Viewport was given unbounded height" error.
        //
        // Performance note: shrinkWrap forces the list to lay out ALL items
        // up-front (no lazy rendering). For large channel lists (500+) this
        // is acceptable because the reorder screen is a bounded admin action,
        // not a browsing surface. If the list grows to thousands of items,
        // consider switching to a custom [SliverReorderableList].
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: channels.length,
        onReorder: (oldIndex, newIndex) {
          if (newIndex > oldIndex) newIndex--;
          onReorder(oldIndex, newIndex);
        },
        proxyDecorator: _proxyDecorator,
        itemBuilder: (context, index) {
          final channel = channels[index];
          return Padding(
            key: ValueKey(channel.id),
            padding: const EdgeInsets.symmetric(
              horizontal: CrispySpacing.md,
              vertical: CrispySpacing.xs,
            ),
            child: Row(
              children: [
                // Drag handle
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(right: CrispySpacing.sm),
                    child: Icon(
                      Icons.drag_handle,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                // Channel item
                Expanded(
                  child: ChannelListItem(
                    channel: channel,
                    onTap: null,
                    isDuplicate: ref.watch(
                      isChannelDuplicateProvider(channel.id),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final scale = Tween<double>(begin: 1.0, end: 1.05).animate(
          CurvedAnimation(parent: animation, curve: CrispyAnimation.focusCurve),
        );
        return Transform.scale(
          scale: scale.value,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.zero,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
