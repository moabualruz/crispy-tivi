import 'package:flutter/material.dart';

import 'package:crispy_tivi/l10n/l10n_extension.dart';

import '../theme/crispy_radius.dart';
import '../theme/crispy_spacing.dart';

/// Data-driven list of keyboard shortcuts displayed in the overlay.
const _shortcuts = [
  (key: 'Space', description: 'Play / Pause'),
  (key: 'F / F11', description: 'Toggle fullscreen'),
  (key: 'M', description: 'Toggle mute'),
  (key: '\u2190 \u2192', description: 'Seek \u00b110s'),
  (key: '\u2191 \u2193', description: 'Volume \u00b15%'),
  (key: 'N', description: 'Next channel'),
  (key: 'P', description: 'Previous channel'),
  (key: 'G', description: 'Toggle EPG'),
  (key: '/', description: 'Search'),
  (key: '1\u20139', description: 'Jump to tab'),
  (key: 'Esc', description: 'Back / Close'),
  (key: '?', description: 'This help'),
];

/// Shows a dialog listing available keyboard shortcuts.
///
/// Called from [AppShell] when the user presses "?" (Shift+Slash)
/// on desktop/web.
void showKeyboardShortcutsOverlay(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) {
      final cs = Theme.of(context).colorScheme;
      final tt = Theme.of(context).textTheme;
      return AlertDialog(
        backgroundColor: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CrispyRadius.lg),
        ),
        title: Text(context.l10n.keyboardShortcuts, style: tt.headlineSmall),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final s in _shortcuts)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: CrispySpacing.xs,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: CrispySpacing.sm,
                            vertical: CrispySpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(
                              CrispyRadius.sm,
                            ),
                          ),
                          child: Text(
                            s.key,
                            style: tt.labelMedium?.copyWith(
                              fontFamily: 'monospace',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(width: CrispySpacing.md),
                      Expanded(
                        child: Text(
                          s.description,
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonClose),
          ),
        ],
      );
    },
  );
}
