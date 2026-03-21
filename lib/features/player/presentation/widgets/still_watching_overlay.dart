import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/glass_surface.dart';

/// "Are You Still Watching?" prompt shown after
/// [kStillWatchingThreshold] consecutive auto-advances
/// without user interaction (J-20).
///
/// Pauses playback and presents two options:
/// - "Continue Watching" → resumes binge, resets counter
/// - "I'm Done" → dismisses and stops auto-advance
class StillWatchingOverlay extends StatelessWidget {
  const StillWatchingOverlay({
    required this.episodeCount,
    required this.onContinue,
    required this.onDone,
    super.key,
  });

  /// Number of consecutive auto-advanced episodes.
  final int episodeCount;

  /// Called when user chooses to continue watching.
  final VoidCallback onContinue;

  /// Called when user chooses to stop.
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: GlassSurface(
            borderRadius: CrispyRadius.lg,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(CrispySpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.pause_circle_outline,
                      size: 64,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: CrispySpacing.md),
                    Text(
                      'Are You Still Watching?',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: CrispySpacing.sm),
                    Text(
                      '$episodeCount episodes played automatically',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: CrispySpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        autofocus: true,
                        onPressed: onContinue,
                        child: const Text('Continue Watching'),
                      ),
                    ),
                    const SizedBox(height: CrispySpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onDone,
                        child: const Text("I'm Done"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
