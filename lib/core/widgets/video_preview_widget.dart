import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/crispy_colors.dart';
import '../theme/crispy_radius.dart';
import 'focus_wrapper.dart';
import 'ui_auto_scale.dart';
import '../../features/player/presentation/providers/player_providers.dart';

/// Transparent placeholder that marks where the video preview
/// should appear in TV/EPG/channel layouts.
///
/// The actual video is rendered by [PermanentVideoLayer] in
/// AppShell at the same position. This widget measures its
/// global rect after layout and reports it to
/// [playerModeProvider] so the video layer can position itself.
///
/// Uses [LayoutBuilder] to detect constraint changes every
/// frame during the side-nav AnimatedContainer animation,
/// ensuring the video layer stays in sync.
class VideoPreviewWidget extends ConsumerStatefulWidget {
  const VideoPreviewWidget({this.onTap, super.key});

  /// Called when the user taps to expand to fullscreen.
  final VoidCallback? onTap;

  @override
  ConsumerState<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends ConsumerState<VideoPreviewWidget> {
  final _key = GlobalKey();
  BoxConstraints? _lastConstraints;

  void _reportRect() {
    final context = _key.currentContext;
    final box = context?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final scale = UiAutoScale.of(context!);
      final position = box.localToGlobal(Offset.zero) / scale;
      final size = box.size;
      ref
          .read(playerModeProvider.notifier)
          .updatePreviewRect(
            Rect.fromLTWH(position.dx, position.dy, size.width, size.height),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playbackStateProvider).value;
    final isPlaying = state?.isPlaying ?? false;
    final isBuffering = state?.isBuffering ?? false;
    final colorScheme = Theme.of(context).colorScheme;
    final isIdle = !isPlaying && !isBuffering;

    // LayoutBuilder triggers a rebuild on every constraint
    // change (e.g. during the nav rail's 150ms resize anim).
    // The post-frame callback then reports the updated rect.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints != _lastConstraints) {
          _lastConstraints = constraints;
          WidgetsBinding.instance.addPostFrameCallback((_) => _reportRect());
        }

        return AspectRatio(
          key: _key,
          aspectRatio: 16 / 9,
          child: FocusWrapper(
            onSelect: isIdle ? null : widget.onTap,
            borderRadius: CrispyRadius.tv,
            child: Container(
              // Transparent — the video shows through from
              // PermanentVideoLayer behind this widget.
              color: Colors.transparent,
              child: Stack(
                children: [
                  // Idle overlay (covers transparent area with icon).
                  if (isIdle)
                    Container(
                      color: Colors.black87,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.live_tv,
                        size: 48,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),

                  // Buffering indicator.
                  if (isBuffering)
                    const Center(
                      child: CircularProgressIndicator(
                        color: CrispyColors.textHigh,
                        strokeWidth: 2,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
