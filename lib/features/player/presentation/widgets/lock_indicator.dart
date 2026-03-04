import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';

/// Full-screen semi-transparent overlay shown when the
/// touch lock is active.
///
/// Displays a pulsing padlock icon centred on screen to
/// indicate the player is locked. Instructs the user to
/// long-press 2 s to unlock.
///
/// The overlay absorbs all pointer events so no child
/// gesture handlers fire while locked.
class LockIndicator extends StatefulWidget {
  const LockIndicator({required this.onUnlockAttempt, super.key});

  /// Called when the user completes a 2-second long-press.
  /// The parent widget is responsible for setting
  /// `isLocked = false` in response.
  final VoidCallback onUnlockAttempt;

  @override
  State<LockIndicator> createState() => _LockIndicatorState();
}

class _LockIndicatorState extends State<LockIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: CrispyAnimation.livePulse,
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: CrispyAnimation.focusCurve),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // Long-press tracking — the OS 500 ms threshold fires
  // [_onLongPressEnd] which calls [onUnlockAttempt].
  void _onLongPressEnd(LongPressEndDetails _) {
    widget.onUnlockAttempt();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Absorb all non-lock gestures.
      onTap: () {},
      onLongPressEnd: _onLongPressEnd,
      child: Container(
        color: Colors.black.withValues(alpha: 0.35),
        alignment: Alignment.center,
        child: _LockIcon(pulseAnim: _pulseAnim),
      ),
    );
  }
}

/// Pulsing padlock icon with "Hold to unlock" hint.
class _LockIcon extends AnimatedWidget {
  const _LockIcon({required Animation<double> pulseAnim})
    : super(listenable: pulseAnim);

  @override
  Widget build(BuildContext context) {
    final scale = (listenable as Animation<double>).value;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.all(CrispySpacing.md),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(CrispyRadius.md),
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: CrispySpacing.sm),
        Text(
          'Screen locked',
          style: textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: CrispySpacing.xs),
        Text(
          'Hold to unlock',
          style: textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}
