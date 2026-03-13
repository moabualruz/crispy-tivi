import 'package:flutter/material.dart';

import '../theme/crispy_radius.dart';

/// A [FilterChip] whose background color is harmonized to a seed color.
///
/// When [baseColor] is omitted a deterministic hue is derived from [label]
/// so that the same label string always produces the same chip color across
/// sessions and rebuilds.
///
/// The chip adapts to the ambient [ThemeData.brightness] — dark/light tones
/// are computed from [ColorScheme.fromSeed] so the chip always contrasts
/// correctly against its background.
///
/// ```dart
/// HarmonizedChip(
///   label: 'Action',
///   onTap: () => _filterByGenre('Action'),
/// )
/// ```
class HarmonizedChip extends StatelessWidget {
  /// Creates a [HarmonizedChip].
  ///
  /// [label] is required. [baseColor] may be null — the color is then derived
  /// deterministically from [label].
  const HarmonizedChip({
    super.key,
    required this.label,
    this.baseColor,
    this.onTap,
  });

  /// Text displayed inside the chip.
  final String label;

  /// Optional explicit seed color. When null, [colorForLabel] is used.
  final Color? baseColor;

  /// Called when the chip is tapped. When null the chip is non-interactive.
  final VoidCallback? onTap;

  /// Returns a deterministic [Color] derived from [label]'s hash code.
  ///
  /// The hue is spread evenly across 360 ° with medium saturation and
  /// lightness so the generated color is always legible before harmonization
  /// through [ColorScheme.fromSeed].
  static Color colorForLabel(String label) {
    final hash = label.hashCode.abs();
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.5, 0.5).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final seedColor = baseColor ?? colorForLabel(label);
    final chipScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Theme.of(context).brightness,
    );

    return FilterChip(
      label: Text(label),
      onSelected: onTap != null ? (_) => onTap!() : null,
      backgroundColor: chipScheme.primaryContainer,
      labelStyle: TextStyle(color: chipScheme.onPrimaryContainer),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CrispyRadius.sm),
      ),
      // Audited: chip rows are space-constrained; chip itself is >= 32px tall
      // with internal padding meeting 44px touch target via row spacing.
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
