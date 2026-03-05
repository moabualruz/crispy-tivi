import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_spacing.dart';

/// Direction indicator for double-tap seek.
enum SeekDirection { forward, backward }

/// Swipe gesture type for volume/brightness.
enum SwipeType { volume, brightness }

// ─────────────────────────────────────────────────────────────
//  GestureRingOverlay
// ─────────────────────────────────────────────────────────────

/// Animated arc ring shown during brightness/volume swipes.
///
/// Replaces the text-only [SwipeIndicator] with a polished
/// [CustomPainter] arc that fills proportionally (0.0 → 1.0),
/// a central icon (sun or volume), and a 1.5 s fade-out after
/// the gesture ends.
///
/// Positioned on the left or right half depending on
/// [swipeType]:
/// - [SwipeType.brightness] → left half
/// - [SwipeType.volume] → right half
class GestureRingOverlay extends StatefulWidget {
  const GestureRingOverlay({
    required this.isSwiping,
    required this.swipeType,
    required this.value,
    required this.isInPip,
    super.key,
  });

  /// Whether a swipe gesture is currently active.
  final bool isSwiping;

  /// Which gesture type is active (volume or brightness).
  final SwipeType? swipeType;

  /// Current level in range 0.0–1.0.
  final double value;

  final bool isInPip;

  @override
  State<GestureRingOverlay> createState() => _GestureRingOverlayState();
}

class _GestureRingOverlayState extends State<GestureRingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: CrispyAnimation.skeletonPulse,
      value: widget.isSwiping ? 1.0 : 0.0,
    );
    _opacity = CurvedAnimation(parent: _fade, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(GestureRingOverlay old) {
    super.didUpdateWidget(old);
    if (widget.isSwiping && !old.isSwiping) {
      // Gesture started — snap fully visible.
      _fade.value = 1.0;
    } else if (!widget.isSwiping && old.isSwiping) {
      // Gesture ended — fade out over 1.5 s using slow curve.
      _fade.animateTo(
        0.0,
        duration: CrispyAnimation.slow,
        curve: CrispyAnimation.exitCurve,
      );
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isInPip) return const SizedBox.shrink();
    if (widget.swipeType == null && !widget.isSwiping) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isBrightness = widget.swipeType == SwipeType.brightness;

    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) {
        if (_opacity.value <= 0.001) return const SizedBox.shrink();
        return Opacity(
          opacity: _opacity.value,
          child: _RingPanel(
            value: widget.value,
            isBrightness: isBrightness,
            colorScheme: colorScheme,
          ),
        );
      },
    );
  }
}

/// Centered panel with the arc ring and icon.
class _RingPanel extends StatelessWidget {
  const _RingPanel({
    required this.value,
    required this.isBrightness,
    required this.colorScheme,
  });

  final double value;
  final bool isBrightness;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 96,
        height: 96,
        child: CustomPaint(
          painter: _RingPainter(
            value: value.clamp(0.0, 1.0),
            arcColor: colorScheme.primary,
            trackColor: colorScheme.surface.withValues(alpha: 0.40),
          ),
          child: Center(
            child: Icon(
              isBrightness
                  ? Icons.brightness_6_outlined
                  : Icons.volume_up_outlined,
              color: colorScheme.onSurface,
              size: CrispySpacing.xl,
            ),
          ),
        ),
      ),
    );
  }
}

/// [CustomPainter] that draws a circular track and a
/// proportionally-filled arc on top.
class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.arcColor,
    required this.trackColor,
  });

  /// Fill ratio 0.0–1.0.
  final double value;
  final Color arcColor;
  final Color trackColor;

  static const double _strokeWidth = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - _strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint =
        Paint()
          ..color = trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth
          ..strokeCap = StrokeCap.round;

    final arcPaint =
        Paint()
          ..color = arcColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth
          ..strokeCap = StrokeCap.round;

    // Full-circle track.
    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);

    // Arc starts at the top (-π/2) and sweeps clockwise.
    if (value > 0) {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.arcColor != arcColor ||
      old.trackColor != trackColor;
}

/// Brightness dimming overlay controlled by vertical
/// swipe on the left half of the screen.
class BrightnessOverlay extends StatelessWidget {
  const BrightnessOverlay({
    required this.brightnessNotifier,
    required this.isInPip,
    super.key,
  });

  final ValueNotifier<double> brightnessNotifier;
  final bool isInPip;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: brightnessNotifier,
      builder: (_, brightness, _) {
        if (brightness <= 0 || isInPip) {
          return const SizedBox.shrink();
        }
        return IgnorePointer(
          child: Container(color: Colors.black.withValues(alpha: brightness)),
        );
      },
    );
  }
}

/// Branded loading/reconnecting overlay shown when the player is
/// buffering or retrying a stream connection.
///
/// Shows a channel logo (when available), channel name, spinner,
/// and a reconnection counter on retry attempts.
class BufferingIndicator extends StatelessWidget {
  const BufferingIndicator({
    required this.isBuffering,
    required this.retryCount,
    required this.isInPip,
    this.channelName,
    this.channelLogoUrl,
    super.key,
  });

  final bool isBuffering;
  final int retryCount;
  final bool isInPip;

  /// Optional channel name shown below the spinner.
  final String? channelName;

  /// Optional channel logo URL shown above the spinner.
  final String? channelLogoUrl;

  @override
  Widget build(BuildContext context) {
    if (!isBuffering || isInPip) {
      return const SizedBox.shrink();
    }
    final hasLogo = channelLogoUrl != null && channelLogoUrl!.isNotEmpty;
    final hasName = channelName != null && channelName!.isNotEmpty;

    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Channel logo
            if (hasLogo)
              Padding(
                padding: const EdgeInsets.only(bottom: CrispySpacing.lg),
                child: Image.network(
                  channelLogoUrl!,
                  width: 72,
                  height: 72,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            // Spinner
            const CircularProgressIndicator(color: Colors.white),
            // Channel name
            if (hasName) ...[
              const SizedBox(height: CrispySpacing.md),
              Text(
                retryCount > 0
                    ? 'Reconnecting to ${channelName!}...'
                    : 'Connecting to ${channelName!}...',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            // Retry counter
            if (retryCount > 0) ...[
              const SizedBox(height: CrispySpacing.xs),
              Text(
                'Attempt $retryCount of 5',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Seek direction indicator shown after double-tap or
/// keyboard seek.
///
/// Displays the configured [seekStepSeconds] so the user
/// knows how many seconds each tap skips.
class SeekIndicator extends StatelessWidget {
  const SeekIndicator({
    required this.direction,
    required this.isInPip,
    this.seekStepSeconds = 10,
    super.key,
  });

  final SeekDirection? direction;
  final bool isInPip;

  /// Seek step in seconds shown in the label (e.g. "+10s").
  final int seekStepSeconds;

  @override
  Widget build(BuildContext context) {
    if (direction == null || isInPip) {
      return const SizedBox.shrink();
    }
    final label =
        direction == SeekDirection.forward
            ? '+${seekStepSeconds}s'
            : '-${seekStepSeconds}s';
    return Positioned(
      left: direction == SeekDirection.backward ? CrispySpacing.xl : null,
      right: direction == SeekDirection.forward ? CrispySpacing.xl : null,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: CrispySpacing.lg,
            vertical: CrispySpacing.md,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.zero,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                direction == SeekDirection.forward
                    ? Icons.fast_forward
                    : Icons.fast_rewind,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: CrispySpacing.sm),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen error overlay with retry button.
class ErrorOverlay extends StatelessWidget {
  const ErrorOverlay({
    required this.hasError,
    required this.errorMessage,
    required this.isInPip,
    required this.onRetry,
    super.key,
  });

  final bool hasError;
  final String? errorMessage;
  final bool isInPip;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (!hasError || isInPip) {
      return const SizedBox.shrink();
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 48,
          ),
          const SizedBox(height: CrispySpacing.md),
          Text(
            errorMessage ?? 'Playback error',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: CrispySpacing.md),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
