import 'package:flutter/material.dart';

import '../theme/crispy_spacing.dart';

/// The four TV remote color buttons (mapped to F1-F4 keyboard keys).
enum TvColorButton {
  /// Red button (F1).
  red,

  /// Green button (F2).
  green,

  /// Yellow button (F3).
  yellow,

  /// Blue button (F4).
  blue,
}

/// Action associated with a [TvColorButton].
class ColorButtonAction {
  /// Creates a color button action.
  const ColorButtonAction({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  /// Text label shown in the legend bar.
  final String label;

  /// Callback when the color button is pressed.
  final VoidCallback onPressed;

  /// Optional icon shown before the label.
  final IconData? icon;
}

/// Horizontal footer bar showing color-coded button labels for TV remotes.
///
/// Displays up to 4 colored dots with labels indicating available
/// color button actions on the current screen.
///
/// ```dart
/// TvColorButtonLegend(
///   colorButtonMap: {
///     TvColorButton.red: ColorButtonAction(label: 'Delete', onPressed: _delete),
///     TvColorButton.green: ColorButtonAction(label: 'Add', onPressed: _add),
///   },
/// )
/// ```
class TvColorButtonLegend extends StatelessWidget {
  /// Creates a TV color button legend bar.
  const TvColorButtonLegend({required this.colorButtonMap, super.key});

  /// Map of color buttons to their actions.
  final Map<TvColorButton, ColorButtonAction> colorButtonMap;

  static const _dotColors = {
    TvColorButton.red: Color(0xFFE53935),
    TvColorButton.green: Color(0xFF43A047),
    TvColorButton.yellow: Color(0xFFFDD835),
    TvColorButton.blue: Color(0xFF1E88E5),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.md,
        vertical: CrispySpacing.sm,
      ),
      decoration: BoxDecoration(color: cs.surfaceContainer),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final entry in colorButtonMap.entries) ...[
            if (entry.key != colorButtonMap.entries.first.key)
              const SizedBox(width: CrispySpacing.lg),
            _ColorButtonItem(
              color: _dotColors[entry.key]!,
              action: entry.value,
              textStyle: tt.labelMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _ColorButtonItem extends StatelessWidget {
  const _ColorButtonItem({
    required this.color,
    required this.action,
    this.textStyle,
  });

  final Color color;
  final ColorButtonAction action;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: CrispySpacing.xs),
        if (action.icon != null) ...[
          Icon(action.icon, size: 16),
          const SizedBox(width: CrispySpacing.xxs),
        ],
        Text(action.label, style: textStyle),
      ],
    );
  }
}
