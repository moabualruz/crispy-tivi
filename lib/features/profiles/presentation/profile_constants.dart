import 'package:flutter/material.dart';

import '../../../core/theme/crispy_spacing.dart';

/// Avatar container size (width and height) used in profile tiles.
const double kProfileAvatarSize = 80.0;

/// Fixed width of a single profile tile in the selection grid.
const double kProfileTileWidth = 120.0;

/// Shared avatar color palette used by profile selection and management screens.
///
/// FE-PM-01: Expanded to 33 colors (one per icon) covering the new categories.
const List<Color> kProfileAvatarColors = [
  // People
  Color(0xFF6C5CE7),
  Color(0xFFE17055),
  Color(0xFF00CEC9),
  Color(0xFFFDAB3D),
  Color(0xFFE84393),
  Color(0xFF0984E3),
  // Animals
  Color(0xFF20BF6B),
  Color(0xFF786FA6),
  Color(0xFFFF6348),
  Color(0xFF63CDDA),
  Color(0xFFA29BFE),
  Color(0xFF55EFC4),
  // Sports
  Color(0xFFD63031),
  Color(0xFF00B894),
  Color(0xFFF9CA24),
  Color(0xFF6AB04C),
  Color(0xFFEB4D4B),
  Color(0xFF7ED6DF),
  // Tech
  Color(0xFF4834D4),
  Color(0xFF22A6B3),
  Color(0xFF535C68),
  Color(0xFF30336B),
  Color(0xFFBE2EDD),
  Color(0xFF009432),
  // Nature
  Color(0xFF1E9E3D),
  Color(0xFF795548),
  Color(0xFFFF9800),
  Color(0xFF03A9F4),
  Color(0xFF2196F3),
  // Entertainment
  Color(0xFFE91E63),
  Color(0xFF9C27B0),
  Color(0xFFF44336),
  Color(0xFF607D8B),
];

// FE-PM-01: Expanded avatar library — 33 themed icons in 6 categories.

/// Category labels for the avatar picker grid sections.
const List<String> kProfileAvatarCategories = [
  'People',
  'Animals',
  'Sports',
  'Tech',
  'Nature',
  'Entertainment',
];

/// Number of icons in each category (index-aligned with
/// [kProfileAvatarCategories]).
const List<int> kProfileAvatarCategoryCounts = [6, 6, 6, 6, 5, 4];

/// Predefined avatar icons shared across profile selection and management.
///
/// Organized into 6 themed categories (FE-PM-01):
///   0–5   : People
///   6–11  : Animals
///   12–17 : Sports
///   18–23 : Tech
///   24–28 : Nature
///   29–32 : Entertainment
const List<IconData> kProfileAvatarIcons = [
  // ── People ──
  Icons.person,
  Icons.face,
  Icons.face_2,
  Icons.face_3,
  Icons.child_care,
  Icons.elderly,

  // ── Animals ──
  Icons.pets,
  Icons.cruelty_free,
  Icons.set_meal,
  Icons.egg_alt,
  Icons.pest_control_rodent,
  Icons.flutter_dash,

  // ── Sports ──
  Icons.sports_soccer,
  Icons.sports_basketball,
  Icons.sports_tennis,
  Icons.sports_football,
  Icons.sports_esports,
  Icons.sports_motorsports,

  // ── Tech ──
  Icons.computer,
  Icons.smartphone,
  Icons.tv,
  Icons.headphones,
  Icons.gamepad,
  Icons.camera,

  // ── Nature ──
  Icons.local_florist,
  Icons.terrain,
  Icons.wb_sunny,
  Icons.ac_unit,
  Icons.water_drop,

  // ── Entertainment ──
  Icons.movie,
  Icons.music_note,
  Icons.live_tv,
  Icons.mic,
];

/// Returns the avatar gradient for [color], darkening toward the bottom-right.
///
/// Used consistently across profile tiles and avatar pickers.
LinearGradient profileAvatarGradient(Color color) => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [color, Color.lerp(color, Colors.black, 0.3)!],
);

/// Accent color palette for per-profile theme overrides (FE-PM-08).
///
/// 12 distinct, accessible colors that work well on dark backgrounds.
const List<Color> kProfileAccentColors = [
  Color(0xFF3B82F6), // Blue (default)
  Color(0xFFE50914), // Netflix Red
  Color(0xFF00BFA5), // Teal
  Color(0xFFFF6D00), // Orange
  Color(0xFFAA00FF), // Purple
  Color(0xFF00C853), // Green
  Color(0xFFE84393), // Pink
  Color(0xFFFFD600), // Yellow
  Color(0xFF00B0FF), // Light Blue
  Color(0xFFFF6348), // Coral
  Color(0xFF63CDDA), // Cyan
  Color(0xFFD1D5DB), // Gray
];

/// A palette of colored swatches for picking a per-profile accent color.
///
/// Shows [kProfileAccentColors] as a Wrap of circular swatches.
/// [selectedColor] is highlighted with a white ring and a check icon.
/// Passing null as [selectedColor] highlights the first implicit "none" swatch.
class ProfileAccentColorPicker extends StatelessWidget {
  const ProfileAccentColorPicker({
    required this.selectedColor,
    required this.onSelected,
    super.key,
  });

  /// The currently selected accent color, or null for "no override".
  final Color? selectedColor;

  /// Called when the user taps a swatch.
  ///
  /// Passes null when the user selects the "no override" (default) swatch.
  final ValueChanged<Color?> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: CrispySpacing.sm,
      runSpacing: CrispySpacing.sm,
      children: [
        // "Default" swatch — uses the dashed outline style to signal
        // "no override, follow global theme".
        _AccentSwatch(
          color: null,
          isSelected: selectedColor == null,
          onTap: () => onSelected(null),
          borderColor: colorScheme.onSurfaceVariant,
        ),
        ...kProfileAccentColors.map(
          (color) => _AccentSwatch(
            color: color,
            isSelected:
                selectedColor != null &&
                selectedColor!.toARGB32() == color.toARGB32(),
            onTap: () => onSelected(color),
            borderColor: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// A single circular swatch in [ProfileAccentColorPicker].
class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.borderColor,
  });

  final Color? color;
  final bool isSelected;
  final VoidCallback onTap;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    const size = 36.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color ?? Colors.transparent,
          border: Border.all(
            color:
                isSelected ? Colors.white : borderColor.withValues(alpha: 0.4),
            width: isSelected ? 3 : 1,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
        child:
            color == null
                ? Icon(
                  Icons.block,
                  size: 18,
                  color: borderColor.withValues(alpha: 0.6),
                )
                : isSelected
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : null,
      ),
    );
  }
}
