import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../providers/pip_provider.dart';
import '../providers/player_providers.dart';

/// Browser-style PiP overlay controls shown on mouse hover.
///
/// Displays play/pause, restore, and close buttons over
/// the video surface when the desktop PiP window is active.
/// Controls auto-hide after 2 seconds of no mouse movement.
class PipOverlay extends ConsumerStatefulWidget {
  const PipOverlay({super.key});

  @override
  ConsumerState<PipOverlay> createState() => _PipOverlayState();
}

class _PipOverlayState extends ConsumerState<PipOverlay> {
  bool _showControls = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onHover(PointerEvent _) {
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    _resetHideTimer();
  }

  void _onExit(PointerEvent _) {
    _hideTimer?.cancel();
    setState(() => _showControls = false);
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  Future<void> _onRestore() async {
    await ref.read(pipProvider.notifier).exitPip();
  }

  Future<void> _onClose() async {
    final playerService = ref.read(playerServiceProvider);
    await playerService.stop();
    await ref.read(pipProvider.notifier).exitPip();
  }

  void _onPlayPause() {
    final playerService = ref.read(playerServiceProvider);
    playerService.playOrPause();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: _onHover,
      onExit: _onExit,
      child: AnimatedOpacity(
        opacity: _showControls ? 1.0 : 0.0,
        duration: CrispyAnimation.fast,
        child: IgnorePointer(
          ignoring: !_showControls,
          child: Container(
            color: Colors.black54,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PipButton(
                      icon: Icons.play_arrow,
                      activeIcon: Icons.pause,
                      onPressed: _onPlayPause,
                    ),
                    const SizedBox(width: 16),
                    _PipButton(
                      icon: Icons.open_in_full,
                      onPressed: _onRestore,
                      tooltip: 'Restore',
                    ),
                    const SizedBox(width: 16),
                    _PipButton(
                      icon: Icons.close,
                      onPressed: _onClose,
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PipButton extends ConsumerWidget {
  const _PipButton({
    required this.icon,
    this.activeIcon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final IconData? activeIcon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying =
        ref.watch(playbackStateProvider).value?.isPlaying ?? false;

    final effectiveIcon = activeIcon != null && isPlaying ? activeIcon! : icon;

    final button = IconButton(
      icon: Icon(effectiveIcon, color: Colors.white, size: 28),
      onPressed: onPressed,
      splashRadius: 20,
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
