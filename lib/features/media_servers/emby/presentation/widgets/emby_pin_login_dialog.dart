import 'package:flutter/material.dart';

import 'package:crispy_tivi/core/theme/crispy_radius.dart';
import 'package:crispy_tivi/core/theme/crispy_spacing.dart';

/// Numpad overlay dialog for Emby PIN-based login (FE-EB-03).
///
/// Displays a 3×4 numeric keypad and a PIN display row. The caller
/// receives the entered PIN string via [onConfirm] when the user
/// presses "OK".
///
/// Usage:
/// ```dart
/// final pin = await showEmbypinLoginDialog(context);
/// if (pin != null) { ... }
/// ```
class EmbyPinLoginDialog extends StatefulWidget {
  const EmbyPinLoginDialog({super.key});

  @override
  State<EmbyPinLoginDialog> createState() => _EmbyPinLoginDialogState();
}

class _EmbyPinLoginDialogState extends State<EmbyPinLoginDialog> {
  String _pin = '';

  static const int _maxLength = 8;

  void _append(String digit) {
    if (_pin.length >= _maxLength) return;
    setState(() => _pin += digit);
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _confirm() {
    if (_pin.isEmpty) return;
    Navigator.of(context).pop(_pin);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Dialog(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(CrispyRadius.tv)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CrispySpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter PIN',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: CrispySpacing.md),
            // ── PIN display ───────────────────────────────────────────
            _PinDisplay(pin: _pin, maxLength: _maxLength),
            const SizedBox(height: CrispySpacing.md),
            // ── Numpad ────────────────────────────────────────────────
            _Numpad(
              onDigit: _append,
              onBackspace: _backspace,
              onConfirm: _pin.isNotEmpty ? _confirm : null,
            ),
            const SizedBox(height: CrispySpacing.md),
            // ── Cancel ────────────────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── PIN display row ───────────────────────────────────────────────────────

class _PinDisplay extends StatelessWidget {
  const _PinDisplay({required this.pin, required this.maxLength});

  final String pin;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.md,
        vertical: CrispySpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: const BorderRadius.all(Radius.circular(CrispyRadius.tv)),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(maxLength, (i) {
          final filled = i < pin.length;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.xs),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    filled ? cs.primary : cs.onSurface.withValues(alpha: 0.2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Numpad ────────────────────────────────────────────────────────────────

class _Numpad extends StatelessWidget {
  const _Numpad({
    required this.onDigit,
    required this.onBackspace,
    required this.onConfirm,
  });

  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onConfirm;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in _rows) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children:
                row
                    .map((d) => _NumpadKey(label: d, onTap: () => onDigit(d)))
                    .toList(),
          ),
          const SizedBox(height: CrispySpacing.xs),
        ],
        // Bottom row: backspace | 0 | confirm
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NumpadKey(
              icon: Icons.backspace_outlined,
              onTap: onBackspace,
              semanticLabel: 'Backspace',
            ),
            _NumpadKey(label: '0', onTap: () => onDigit('0')),
            _NumpadKey(
              icon: Icons.check,
              onTap: onConfirm,
              semanticLabel: 'Confirm',
              filled: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _NumpadKey extends StatelessWidget {
  const _NumpadKey({
    this.label,
    this.icon,
    this.semanticLabel,
    required this.onTap,
    this.filled = false,
  }) : assert(
         label != null || icon != null,
         '_NumpadKey requires either label or icon',
       );

  final String? label;
  final IconData? icon;
  final String? semanticLabel;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Widget inner =
        icon != null
            ? Icon(
              icon,
              size: 22,
              color:
                  filled
                      ? cs.onPrimary
                      : onTap != null
                      ? cs.onSurface
                      : cs.onSurface.withValues(alpha: 0.3),
            )
            : Text(
              label!,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color:
                    onTap != null
                        ? cs.onSurface
                        : cs.onSurface.withValues(alpha: 0.3),
              ),
            );

    final bg = filled ? cs.primary : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.all(CrispySpacing.xs),
      child: Material(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(CrispyRadius.tv)),
        child: InkWell(
          borderRadius: const BorderRadius.all(
            Radius.circular(CrispyRadius.tv),
          ),
          onTap: onTap,
          child: Semantics(
            label: semanticLabel,
            button: true,
            child: SizedBox(width: 64, height: 56, child: Center(child: inner)),
          ),
        ),
      ),
    );
  }
}

/// Shows the [EmbyPinLoginDialog] and returns the entered PIN or `null`
/// if the user cancelled.
Future<String?> showEmbyPinLoginDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const EmbyPinLoginDialog(),
  );
}
