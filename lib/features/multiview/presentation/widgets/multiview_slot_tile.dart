import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../domain/entities/active_stream.dart';
import 'empty_slot.dart';
import 'video_slot.dart';

/// A single cell in the multi-view grid.
///
/// Wraps [FocusWrapper] to handle:
/// - Single tap/Enter → select audio focus (or open channel picker).
/// - Double-tap / [onMaximize] callback → maximize (FE-MV-03).
/// - Enter key when focused → audio focus / picker (via FocusWrapper).
///
/// TV "Press Enter to maximize" hint is shown when the slot is
/// focused and filled.
class MultiviewSlotTile extends StatefulWidget {
  const MultiviewSlotTile({
    required this.index,
    required this.slot,
    required this.isAudioFocus,
    required this.colorScheme,
    required this.onSelect,
    this.onLongPress,
    this.onMaximize,
    // FE-MV-08: notifies parent when this slot gains/loses focus.
    this.onFocused,
    super.key,
  });

  final int index;
  final ActiveStream? slot;
  final bool isAudioFocus;
  final ColorScheme colorScheme;
  final VoidCallback onSelect;
  final VoidCallback? onLongPress;
  final VoidCallback? onMaximize;

  /// Called when focus changes. [focused] is true when gained.
  final ValueChanged<bool>? onFocused;

  @override
  State<MultiviewSlotTile> createState() => _MultiviewSlotTileState();
}

class _MultiviewSlotTileState extends State<MultiviewSlotTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Double-tap maximizes the slot.
      onDoubleTap: widget.onMaximize,
      child: FocusWrapper(
        autofocus: widget.index == 0,
        borderRadius: CrispyRadius.tv,
        scaleFactor: 1.0,
        semanticLabel:
            widget.slot != null
                ? 'Slot ${widget.index + 1}: ${widget.slot!.channelName}'
                : 'Empty slot ${widget.index + 1}',
        onSelect: widget.onSelect,
        onLongPress: widget.onLongPress,
        // Listen to focus changes to show the TV maximize hint
        // and to route digit keys to this slot (FE-MV-08).
        onFocusChange: (focused) {
          if (mounted) {
            setState(() => _focused = focused);
            widget.onFocused?.call(focused);
          }
        },
        // Enter key on a filled slot: first press = audio focus,
        // double-press pattern is handled at the GestureDetector level.
        // For TV, we also support a dedicated "maximize" via long-press on
        // the FocusWrapper (mapped to onLongPress which calls startPlayback).
        child: Stack(
          children: [
            // Slot border + content.
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(CrispyRadius.tv),
                border: Border.all(
                  color:
                      widget.isAudioFocus
                          ? widget.colorScheme.primary
                          : Colors.white24,
                  width: widget.isAudioFocus ? 3 : 1,
                ),
              ),
              child:
                  widget.slot != null
                      ? VideoSlot(
                        index: widget.index,
                        stream: widget.slot!,
                        isAudioFocus: widget.isAudioFocus,
                      )
                      : const EmptySlot(),
            ),

            // TV hint overlay: "Press Enter to maximize" (FE-MV-03).
            if (_focused && widget.slot != null && widget.onMaximize != null)
              Positioned(
                bottom: CrispySpacing.xs,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _focused ? 1.0 : 0.0,
                    duration: CrispyAnimation.fast,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CrispySpacing.sm,
                        vertical: CrispySpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: CrispyColors.scrimMid,
                        borderRadius: BorderRadius.circular(CrispyRadius.tv),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.open_in_full,
                            size: 12,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: CrispySpacing.xxs),
                          Text(
                            'Double-tap to maximize',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
