// FE-TV-02: Channel number jump (direct dial) overlay for Live TV.
//
// Displays the accumulated digit string while the user types a channel
// number on the keyboard. The overlay auto-dismisses 1.5 s after the last
// key press (controlled by the parent via [digits] becoming empty).
import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/glass_surface.dart';

/// Glassmorphic HUD that shows the digits typed so far during
/// a direct-dial channel-number jump (FE-TV-02).
///
/// Position this widget inside a [Stack] at the desired screen corner.
/// Pass the accumulated [digits] string from the parent's state.
/// When [digits] is empty the widget renders nothing (zero-size).
///
/// ### Usage
///
/// ```dart
/// Stack(
///   children: [
///     mainLayout,
///     Positioned(
///       top: CrispySpacing.xl,
///       right: CrispySpacing.xl,
///       child: ChannelNumberJumpOverlay(digits: _dialDigits),
///     ),
///   ],
/// )
/// ```
class ChannelNumberJumpOverlay extends StatelessWidget {
  const ChannelNumberJumpOverlay({super.key, required this.digits});

  /// The accumulated digit string (e.g. `"12"`). When empty the
  /// widget collapses to nothing.
  final String digits;

  @override
  Widget build(BuildContext context) {
    if (digits.isEmpty) return const SizedBox.shrink();

    final crispyColors = Theme.of(context).crispyColors;
    final tt = Theme.of(context).textTheme;

    return GlassSurface(
      borderRadius: CrispyRadius.md,
      blurSigma: crispyColors.glassBlur,
      tintColor: crispyColors.glassTint,
      borderColor: Colors.white.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.xl,
        vertical: CrispySpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            digits,
            style: tt.displayLarge?.copyWith(
              color: CrispyColors.textHigh,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
          ),
          const SizedBox(height: CrispySpacing.xs),
          Text(
            'Channel',
            style: tt.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}
