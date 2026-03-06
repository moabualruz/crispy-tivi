import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/ui_auto_scale.dart';
import '../../../player/presentation/providers/player_providers.dart';

/// Minimum PIP overlay width (px).
const double _kEpgPipMinWidth = 160.0;

/// Maximum PIP overlay width (px).
const double _kEpgPipMaxWidth = 280.0;

/// Fraction of screen width used for PIP overlay size.
const double _kEpgPipWidthFraction = 0.35;

/// Floating mini-player placeholder on mobile EPG screens.
///
/// Transparent window that marks where the video appears
/// via [PermanentVideoLayer]. Reports its global rect to
/// [playerModeProvider] so the video layer can position
/// itself.
class EpgMobileVideoOverlay extends ConsumerStatefulWidget {
  const EpgMobileVideoOverlay({this.onTap, super.key});

  /// Called when the user taps the overlay to go fullscreen.
  final VoidCallback? onTap;

  @override
  ConsumerState<EpgMobileVideoOverlay> createState() =>
      _EpgMobileVideoOverlayState();
}

class _EpgMobileVideoOverlayState extends ConsumerState<EpgMobileVideoOverlay> {
  final _key = GlobalKey();
  bool _rectReportPending = false;

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

    final isActive = isPlaying || isBuffering;
    if (!isActive) return const SizedBox.shrink();

    // Report rect once after layout (not on every rebuild).
    if (!_rectReportPending) {
      _rectReportPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _rectReportPending = false;
        _reportRect();
      });
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final pipWidth = (screenWidth * _kEpgPipWidthFraction).clamp(
      _kEpgPipMinWidth,
      _kEpgPipMaxWidth,
    );
    // Derive height from 16:9 aspect ratio.
    final pipHeight = pipWidth * 9 / 16;

    return Positioned(
      key: _key,
      right: CrispySpacing.md,
      bottom: CrispySpacing.md,
      width: pipWidth,
      height: pipHeight,
      child: GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(CrispyRadius.sm),
          child: Container(
            // Transparent — video shows through from
            // PermanentVideoLayer behind.
            color: Colors.transparent,
            child: Stack(
              children: [
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
      ),
    );
  }
}
