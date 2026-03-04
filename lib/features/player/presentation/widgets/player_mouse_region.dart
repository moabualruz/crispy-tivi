import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_providers.dart';

/// Isolated wrapper that handles mouse cursor visibility
/// and hover-to-show-OSD. Changes to
/// [mouseCursorVisibleProvider] only rebuild this widget,
/// not the entire player screen.
class PlayerMouseRegion extends ConsumerStatefulWidget {
  const PlayerMouseRegion({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PlayerMouseRegion> createState() => _PlayerMouseRegionState();
}

class _PlayerMouseRegionState extends ConsumerState<PlayerMouseRegion> {
  /// Throttle mouse-move callbacks to 10Hz max.
  DateTime _lastMouseMove = DateTime(0);

  @override
  Widget build(BuildContext context) {
    final cursorVisible = ref.watch(mouseCursorVisibleProvider);

    return MouseRegion(
      cursor:
          cursorVisible ? SystemMouseCursors.basic : SystemMouseCursors.none,
      onHover: (_) {
        // Throttle to 10Hz to avoid 60+ provider
        // notifications per second during mouse movement.
        final now = DateTime.now();
        if (now.difference(_lastMouseMove).inMilliseconds < 100) {
          return;
        }
        _lastMouseMove = now;
        ref.read(mouseCursorVisibleProvider.notifier).onMouseMove();
        ref.read(osdStateProvider.notifier).show();
      },
      child: widget.child,
    );
  }
}
