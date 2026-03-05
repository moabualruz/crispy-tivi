import 'package:flutter/material.dart';

import '../../../../../core/theme/crispy_spacing.dart';

/// Center controls -- Netflix style.
///
/// Skip back 10s (48px), play/pause (60px hero),
/// skip forward 10s (48px). 56px gap between icons.
/// Only shown for VOD (not live streams).
class OsdCenterControls extends StatelessWidget {
  const OsdCenterControls({
    required this.isPlaying,
    required this.isLive,
    required this.onPlayPause,
    this.onSeekBack,
    this.onSeekForward,
    super.key,
  });

  final bool isPlaying;
  final bool isLive;
  final VoidCallback onPlayPause;
  final VoidCallback? onSeekBack;
  final VoidCallback? onSeekForward;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Skip back 10s (VOD only, 48px)
        if (onSeekBack != null)
          OsdCenterButton(
            icon: Icons.replay_10_rounded,
            semanticLabel: 'Skip back 10 seconds',
            size: CrispySpacing.xxl, // 48
            onTap: onSeekBack!,
          ),

        if (onSeekBack != null) const SizedBox(width: 56),

        // Play / Pause (hero -- largest, 60px)
        OsdCenterButton(
          icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          semanticLabel: isPlaying ? 'Pause' : 'Play',
          size: 60,
          onTap: onPlayPause,
        ),

        if (onSeekForward != null) const SizedBox(width: 56),

        // Skip forward 10s (VOD only, 48px)
        if (onSeekForward != null)
          OsdCenterButton(
            icon: Icons.forward_10_rounded,
            semanticLabel: 'Skip forward 10 seconds',
            size: CrispySpacing.xxl, // 48
            onTap: onSeekForward!,
          ),
      ],
    );
  }
}

/// Individual center button with circular background.
class OsdCenterButton extends StatelessWidget {
  const OsdCenterButton({
    required this.icon,
    required this.size,
    required this.onTap,
    this.semanticLabel,
    super.key,
  });

  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 20,
      height: size + 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.35),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onTap,
        tooltip: semanticLabel,
        icon: Icon(icon, color: Colors.white, size: size),
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return Colors.white.withValues(alpha: 0.25);
            }
            if (states.contains(WidgetState.hovered)) {
              return Colors.white.withValues(alpha: 0.15);
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
  }
}
