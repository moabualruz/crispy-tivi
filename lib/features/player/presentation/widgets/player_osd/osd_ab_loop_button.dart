import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/player_providers.dart';
import 'osd_shared.dart';

/// A-B loop toggle button for the OSD controls bar.
///
/// Tap cycle (PS-18):
///   1st tap — sets point A at current position.
///             Button shows "A" with amber colour.
///   2nd tap — sets point B at current position,
///             activates the loop.
///             Button shows "A·B" with green colour.
///   3rd tap — clears the loop and returns to idle.
///             Button shows "A·B" in white (inactive).
///
/// Only meaningful for VOD ([isLive] = false).
/// When [isLive] is true the button is disabled.
class OsdAbLoopButton extends ConsumerWidget {
  const OsdAbLoopButton({required this.isLive, this.order, super.key});

  /// Whether the current stream is live TV.
  /// The button is disabled for live streams.
  final bool isLive;

  /// Optional focus traversal order within the OSD bar.
  final double? order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isLive) return const SizedBox.shrink();

    final loopState = ref.watch(abLoopProvider);

    final (icon, tooltip, color) = switch (loopState.phase) {
      AbLoopPhase.idle => (_AbIcon.idle, 'Set loop start (A)', Colors.white),
      AbLoopPhase.aSet => (_AbIcon.aSet, 'Set loop end (B)', Colors.amber),
      AbLoopPhase.abSet => (
        _AbIcon.abSet,
        'Clear A-B loop',
        Colors.greenAccent,
      ),
    };

    Widget button = Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: () {
          final progress = ref.read(
            playbackStateProvider.select((s) => s.value?.progress ?? 0.0),
          );
          ref.read(abLoopProvider.notifier).advance(progress);
          // Keep OSD visible after interaction.
          ref.read(osdStateProvider.notifier).show();
        },
        icon: _AbLoopIcon(icon: icon, color: color),
        // Shrink-wrap to avoid adding extra width in the
        // controls row on narrow screens.
        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          ),
          minimumSize: const WidgetStatePropertyAll(Size.zero),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return Colors.white.withValues(alpha: 0.2);
            }
            if (states.contains(WidgetState.hovered)) {
              return Colors.white.withValues(alpha: 0.1);
            }
            return Colors.transparent;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return const BorderSide(color: Colors.white, width: 2);
            }
            return BorderSide.none;
          }),
        ),
      ),
    );

    if (order != null) {
      button = FocusTraversalOrder(
        order: NumericFocusOrder(order!),
        child: button,
      );
    }

    return button;
  }
}

// ─────────────────────────────────────────────────────────────
//  Icon phase enum
// ─────────────────────────────────────────────────────────────

enum _AbIcon { idle, aSet, abSet }

// ─────────────────────────────────────────────────────────────
//  Custom A-B icon widget
// ─────────────────────────────────────────────────────────────

/// Renders the A-B label as a small text widget styled to match
/// [OsdIconButton] at 22 px.
class _AbLoopIcon extends StatelessWidget {
  const _AbLoopIcon({required this.icon, required this.color});

  final _AbIcon icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = switch (icon) {
      _AbIcon.idle => 'A·B',
      _AbIcon.aSet => 'A',
      _AbIcon.abSet => 'A·B',
    };

    return SizedBox(
      width: 22,
      height: 22,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
