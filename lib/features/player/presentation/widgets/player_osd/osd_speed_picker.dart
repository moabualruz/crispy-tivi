import 'package:flutter/material.dart';

import '../../../../../core/theme/crispy_radius.dart';
import '../../../../../core/widgets/focus_wrapper.dart';

/// Speed button that shows the current speed label
/// when not at the default 1.0x. Grayed out for live
/// streams.
class OsdSpeedButton extends StatelessWidget {
  const OsdSpeedButton({
    required this.speed,
    required this.isLive,
    this.onPressed,
    this.order,
    super.key,
  });

  final double speed;
  final bool isLive;
  final VoidCallback? onPressed;

  /// Focus traversal order within the OSD bar.
  final double? order;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDefault = (speed - 1.0).abs() < 0.01;
    final enabled = onPressed != null;
    final color =
        !enabled
            ? Colors.white24
            : isDefault
            ? Colors.white
            : cs.primary;

    Widget button = Tooltip(
      message: isLive ? 'Speed (live)' : 'Speed',
      child: Material(
        color: Colors.transparent,
        child: FocusWrapper(
          onSelect: onPressed,
          borderRadius: CrispyRadius.tv,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.speed_rounded, color: color, size: 22),
                if (!isDefault) ...[
                  const SizedBox(width: 2),
                  Text(
                    '${speed}x',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
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

/// Cycles through standard playback speeds.
void cyclePlaybackSpeed({
  required double currentSpeed,
  required void Function(double) setSpeed,
}) {
  const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  final currentIdx = speeds.indexWhere((s) => (s - currentSpeed).abs() < 0.01);
  final nextIdx = (currentIdx + 1) % speeds.length;
  setSpeed(speeds[nextIdx]);
}
