import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../providers/player_providers.dart';

/// Dialog for setting or cancelling a sleep timer.
///
/// Shows the currently active countdown when a timer is
/// running, and offers preset durations as well as a
/// cancel button.
class SleepTimerDialog extends ConsumerWidget {
  const SleepTimerDialog({super.key});

  /// Preset durations in minutes (0 = cancel).
  static const _presets = [15, 30, 45, 60, 90, 120];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(playerServiceProvider);
    final remaining = ref.watch(
      playbackStateProvider.select((async) => async.value?.sleepTimerRemaining),
    );
    final isActive = remaining != null && remaining > Duration.zero;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: 'Sleep Timer dialog',
      child: Dialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(CrispySpacing.md),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Title ──
                Text(
                  'Sleep Timer',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: CrispySpacing.sm),

                // ── Active countdown banner ──
                if (isActive) ...[
                  Semantics(
                    liveRegion: true,
                    label:
                        'Timer active. Stopping in '
                        '${DurationFormatter.sleepTimer(remaining)}',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: CrispySpacing.sm,
                        horizontal: CrispySpacing.md,
                      ),
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timer,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: CrispySpacing.sm),
                          Expanded(
                            child: Text(
                              'Stopping in '
                              '${DurationFormatter.sleepTimer(remaining)}',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: CrispySpacing.sm),

                  // Cancel current timer button
                  Semantics(
                    button: true,
                    label: 'Cancel sleep timer',
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          service.cancelSleepTimer();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.timer_off),
                        label: const Text('Cancel Timer'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          side: BorderSide(color: colorScheme.error),
                          shape: const RoundedRectangleBorder(),
                        ),
                      ),
                    ),
                  ),
                  Divider(
                    color: colorScheme.outline.withValues(alpha: 0.12),
                    height: CrispySpacing.lg,
                  ),
                ],

                // ── Preset options ──
                SizedBox(
                  width: 300,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        _presets.map((minutes) {
                          return Semantics(
                            button: true,
                            label: 'Set sleep timer to $minutes minutes',
                            child: ListTile(
                              title: Text(
                                '$minutes minutes',
                                style: TextStyle(color: colorScheme.onSurface),
                              ),
                              leading: Icon(
                                Icons.timer_outlined,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.70,
                                ),
                              ),
                              onTap: () {
                                service.setSleepTimer(
                                  Duration(minutes: minutes),
                                );
                                Navigator.of(context).pop();
                              },
                              shape: const RoundedRectangleBorder(),
                              hoverColor: colorScheme.onSurface.withValues(
                                alpha: 0.10,
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),

                const SizedBox(height: CrispySpacing.sm),
                Semantics(
                  button: true,
                  label: 'Close sleep timer dialog',
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
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
