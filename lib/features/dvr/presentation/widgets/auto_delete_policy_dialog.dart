import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../domain/entities/recording.dart';

/// Shows the [AutoDeletePolicyDialog] for [recording] and returns
/// a copy of [recording] with the updated policy, or `null` if
/// the user cancelled.
Future<Recording?> showAutoDeletePolicyDialog({
  required BuildContext context,
  required Recording recording,
}) {
  return showDialog<Recording>(
    context: context,
    builder: (_) => AutoDeletePolicyDialog(recording: recording),
  );
}

/// Dialog for changing the [AutoDeletePolicy] of a [Recording].
///
/// Presents all policy options as a segmented list and, for
/// [AutoDeletePolicy.keepN], shows an episode-count stepper.
class AutoDeletePolicyDialog extends StatefulWidget {
  /// Creates an [AutoDeletePolicyDialog].
  const AutoDeletePolicyDialog({super.key, required this.recording});

  /// The recording whose policy is being edited.
  final Recording recording;

  @override
  State<AutoDeletePolicyDialog> createState() => _AutoDeletePolicyDialogState();
}

class _AutoDeletePolicyDialogState extends State<AutoDeletePolicyDialog> {
  late AutoDeletePolicy _policy;
  late int _keepCount;

  @override
  void initState() {
    super.initState();
    _policy = widget.recording.autoDeletePolicy;
    _keepCount = widget.recording.keepEpisodeCount;
  }

  void _save() {
    Navigator.pop(
      context,
      widget.recording.copyWith(
        autoDeletePolicy: _policy,
        keepEpisodeCount: _keepCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('Auto-Delete Policy'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose when episodes of "${widget.recording.programName}" '
              'are automatically removed.',
              style: tt.bodyMedium,
            ),
            const SizedBox(height: CrispySpacing.md),
            ...AutoDeletePolicy.values.map(
              (p) => _PolicyOption(
                policy: p,
                selected: _policy == p,
                cs: cs,
                tt: tt,
                onTap: () => setState(() => _policy = p),
              ),
            ),
            if (_policy == AutoDeletePolicy.keepN) ...[
              const SizedBox(height: CrispySpacing.sm),
              _EpisodeStepper(
                count: _keepCount,
                onDecrement:
                    _keepCount > 1 ? () => setState(() => _keepCount--) : null,
                onIncrement:
                    _keepCount < 99 ? () => setState(() => _keepCount++) : null,
                tt: tt,
                cs: cs,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Apply')),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Internal helpers
// ─────────────────────────────────────────────────────────

class _PolicyOption extends StatelessWidget {
  const _PolicyOption({
    required this.policy,
    required this.selected,
    required this.cs,
    required this.tt,
    required this.onTap,
  });

  final AutoDeletePolicy policy;
  final bool selected;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? cs.primary : cs.onSurfaceVariant;
    return Semantics(
      button: true,
      label: 'Select policy',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: CrispySpacing.xs,
            horizontal: CrispySpacing.xs,
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: color,
              ),
              const SizedBox(width: CrispySpacing.sm),
              Icon(policy.icon, size: 20, color: color),
              const SizedBox(width: CrispySpacing.sm),
              Text(
                policy.label,
                style: tt.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodeStepper extends StatelessWidget {
  const _EpisodeStepper({
    required this.count,
    required this.onDecrement,
    required this.onIncrement,
    required this.tt,
    required this.cs,
  });

  final int count;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: CrispySpacing.xl),
        Text('Keep latest', style: tt.bodyMedium),
        const SizedBox(width: CrispySpacing.sm),
        IconButton.outlined(
          iconSize: 16,
          visualDensity: VisualDensity.compact,
          onPressed: onDecrement,
          icon: const Icon(Icons.remove),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.sm),
          child: Text(
            '$count',
            style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton.outlined(
          iconSize: 16,
          visualDensity: VisualDensity.compact,
          onPressed: onIncrement,
          icon: const Icon(Icons.add),
        ),
        const SizedBox(width: CrispySpacing.sm),
        Text('episodes', style: tt.bodyMedium),
      ],
    );
  }
}
