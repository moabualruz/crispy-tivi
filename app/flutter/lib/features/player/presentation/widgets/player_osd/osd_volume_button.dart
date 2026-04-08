import 'package:flutter/material.dart';

import '../../../../../core/theme/crispy_animation.dart';
import 'osd_shared.dart';

/// Volume button with hover/focus-activated slider.
///
/// Shows a mute/volume icon that toggles mute on press.
/// When hovered or focused (keyboard nav), expands to reveal
/// a horizontal volume slider.
///
/// When [maxVolume] > 100, the slider range extends beyond
/// 100% and a white tick mark is drawn at the 100% position.
class OsdVolumeButton extends StatefulWidget {
  const OsdVolumeButton({
    required this.volume,
    required this.isMuted,
    required this.onVolumeChange,
    required this.onToggleMute,
    this.maxVolume = 100,
    super.key,
  });

  final double volume;
  final bool isMuted;
  final ValueChanged<double> onVolumeChange;
  final VoidCallback onToggleMute;

  /// Maximum volume percentage (100–300).
  final int maxVolume;

  @override
  State<OsdVolumeButton> createState() => _OsdVolumeButtonState();
}

class _OsdVolumeButtonState extends State<OsdVolumeButton> {
  bool _showSlider = false;
  bool _isFocused = false;

  bool get _sliderVisible => _showSlider || _isFocused;

  double get _maxNormalized => widget.maxVolume / 100.0;

  IconData get _volumeIcon {
    if (widget.isMuted || widget.volume <= 0) {
      return Icons.volume_off_rounded;
    }
    if (widget.volume < 0.5) {
      return Icons.volume_down_rounded;
    }
    return Icons.volume_up_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _showSlider = true),
      onExit: (_) => setState(() => _showSlider = false),
      child: Focus(
        onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
        skipTraversal: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OsdIconButton(
              icon: _volumeIcon,
              tooltip: 'Volume',
              onPressed: widget.onToggleMute,
            ),
            AnimatedContainer(
              duration: CrispyAnimation.fast,
              width: _sliderVisible ? 80 : 0,
              curve: Curves.easeInOut,
              child:
                  _sliderVisible
                      ? _buildSliderWithMarker()
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderWithMarker() {
    final showMarker = widget.maxVolume > 100;

    return Stack(
      alignment: Alignment.center,
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: widget.volume.clamp(0.0, _maxNormalized),
            max: _maxNormalized,
            onChanged: widget.onVolumeChange,
            semanticFormatterCallback: (v) => 'Volume ${(v * 100).round()}%',
          ),
        ),
        // 100% tick mark when boost is active.
        if (showMarker)
          Positioned(
            // 12px padding on each side from slider's overlay.
            left: 12 + (80 - 24) * (1.0 / _maxNormalized),
            child: IgnorePointer(
              child: Container(
                width: 2,
                height: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
      ],
    );
  }
}
