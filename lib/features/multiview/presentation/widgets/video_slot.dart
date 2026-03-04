import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../domain/entities/active_stream.dart';
import '../providers/multiview_providers.dart';
import 'mini_player.dart';

/// Named widget for an occupied multi-view slot.
///
/// Shows a [MiniPlayer] with a channel-name overlay and
/// keyboard-focusable remove / swap buttons for TV D-pad
/// navigation.
class VideoSlot extends ConsumerStatefulWidget {
  /// Creates a video slot for [stream] at grid [index].
  const VideoSlot({
    super.key,
    required this.index,
    required this.stream,
    required this.isAudioFocus,
  });

  /// Grid index of this slot (0-based).
  final int index;

  /// The stream currently playing in this slot.
  final ActiveStream stream;

  /// Whether this slot has audio focus.
  final bool isAudioFocus;

  @override
  ConsumerState<VideoSlot> createState() => _VideoSlotState();
}

class _VideoSlotState extends ConsumerState<VideoSlot> {
  /// Whether the slot is hovered (shows action buttons).
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MiniPlayer(
            key: ValueKey(widget.stream.url),
            stream: widget.stream,
            isAudioActive: widget.isAudioFocus,
          ),

          // Channel name overlay.
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: CrispySpacing.sm,
                vertical: CrispySpacing.xs,
              ),
              decoration: const BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.zero,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isAudioFocus) ...[
                    Icon(Icons.volume_up, size: 14, color: colorScheme.primary),
                    const SizedBox(width: CrispySpacing.xs),
                  ],
                  Text(
                    widget.stream.channelName,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action buttons: swap + remove.
          // Always visible on TV (no hover); shown on hover for mouse.
          Positioned(
            top: 8,
            right: 8,
            child: AnimatedOpacity(
              opacity: _hovered ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Swap button — opens slot picker to swap with another slot.
                  FocusWrapper(
                    borderRadius: CrispyRadius.sm,
                    semanticLabel:
                        'Swap ${widget.stream.channelName} with another slot',
                    onSelect: () => _showSwapPicker(context),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(color: Colors.black54),
                      child: const Icon(
                        Icons.swap_horiz,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: CrispySpacing.xs),
                  // Remove button.
                  FocusWrapper(
                    borderRadius: CrispyRadius.sm,
                    semanticLabel: 'Remove ${widget.stream.channelName}',
                    onSelect: () {
                      ref
                          .read(multiViewProvider.notifier)
                          .removeSlot(widget.index);
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(color: Colors.black54),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows a dialog listing all other occupied slots to swap with.
  void _showSwapPicker(BuildContext context) {
    final session = ref.read(multiViewProvider);
    final otherSlots = <int>[];
    for (var i = 0; i < session.slots.length; i++) {
      if (i != widget.index && session.slots[i] != null) {
        otherSlots.add(i);
      }
    }

    if (otherSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No other channels to swap with'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Swap with…'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  otherSlots.map((targetIndex) {
                    final targetStream = session.slots[targetIndex]!;
                    return ListTile(
                      leading: const Icon(Icons.swap_horiz),
                      title: Text(targetStream.channelName),
                      subtitle: Text('Slot ${targetIndex + 1}'),
                      onTap: () {
                        ref
                            .read(multiViewProvider.notifier)
                            .swapSlots(widget.index, targetIndex);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }
}
